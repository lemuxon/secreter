import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../core/di/injection.dart';
import '../features/conversations/domain/entities/conversation_entity.dart';
import '../features/conversations/domain/usecases/conversation_usecases.dart';
import '../features/messaging/domain/entities/message_entity.dart';
import '../features/messaging/domain/usecases/manage_message.dart';
import '../features/messaging/domain/usecases/watch_messages.dart';
import '../core/usecase/usecase.dart';

/// 💾 ŞİFRELİ YEDEK
///
/// SORUN: Telefon kaybolursa/bozulursa E2EE anahtarları da gider ve
/// geçmiş mesajlar KALICI olarak okunamaz hâle gelir. Bu, gizlilik
/// uygulamalarının bilinen bedelidir — ama kullanıcıya bir çıkış yolu
/// bırakmak gerekir.
///
/// ÇÖZÜM: Cihazın okuyabildiği (çözülmüş) sohbet geçmişi, kullanıcının
/// belirlediği bir PAROLA ile şifrelenip tek dosyaya yazılır. Dosya
/// kullanıcının kendi seçtiği yerde durur (bulut yok, sunucu yok).
///
/// GÜVENLİK TASARIMI
///  • Anahtar parolodan PBKDF2-HMAC-SHA256 ile türetilir (120.000 tur)
///  • Her yedek için rastgele 16 baytlık tuz — aynı parola farklı anahtar
///  • AES-256-GCM: hem şifreler hem BÜTÜNLÜK doğrular (bozulmuş/kurcalanmış
///    dosya sessizce yanlış veri döndürmez, hata verir)
///  • Parola dosyada TUTULMAZ; unutulursa yedek açılamaz (bilinçli)
class BackupService {
  static const _magic = 'SECRETER-BACKUP';
  static const _version = 2;
  static const _iterations = 150000;

  static final AesGcm _aesGcm = AesGcm.with256bits();

  // ---------------------------------------------------------------
  // ANAHTAR TÜRETME
  // ---------------------------------------------------------------
  /// PBKDF2-HMAC-SHA256 — ARKA PLAN isolate'inde.
  ///
  /// ⚠️ Eski sürüm 120.000 turu ANA İSOLATE'te saf Dart döngüsüyle
  /// yürütüyordu: orta seviye bir Android cihazda arayüz saniyelerce
  /// donuyor ve ANR riski doğuyordu. Artık `compute` ile ayrı isolate'te
  /// ve denetlenmiş `cryptography` paketinin PBKDF2 uygulamasıyla.
  static Future<Uint8List> _deriveKey(
      String password, Uint8List salt, int iterations) async {
    final bytes = await compute(
      _kdfIsolate,
      _KdfRequest(password: password, salt: salt, iterations: iterations),
    );
    return Uint8List.fromList(bytes);
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  /// Bir sohbetin TÜM mesajlarını sayfalayarak topla.
  ///
  /// ⚠️ ESKİ HATA: yedek, canlı akışın İLK emisyonunu alıyordu
  /// (`WatchMessages(...).first`). O akış `limit(100)` ile sınırlı olduğu
  /// için yedek sohbet başına EN FAZLA ~100 MESAJ içeriyordu — kullanıcı
  /// "yedeğim var" sanıyor, geri yüklerken geçmişin çoğu YOK oluyordu.
  /// Bu uygulamada başka kurtarma yolu olmadığı için kalıcı veri kaybıydı.
  static Future<List<MessageEntity>> _collectAllMessages(String chatId) async {
    final collected = <String, MessageEntity>{};

    // 1) Canlı pencereden son mesajlar
    try {
      final either = await getIt<WatchMessages>()(chatId)
          .first
          .timeout(const Duration(seconds: 15));
      for (final m in either.fold((_) => const <MessageEntity>[], (l) => l)) {
        collected[m.id] = m;
      }
    } catch (e) {
      debugPrint('Yedek: canlı pencere okunamadı ($chatId): $e');
    }

    // 2) Daha eskileri sayfa sayfa geri git
    var cursor = collected.values.isEmpty
        ? DateTime.now()
        : collected.values
            .map((m) => m.timestamp)
            .reduce((a, b) => a.isBefore(b) ? a : b);

    for (var page = 0; page < 200; page++) {
      List<MessageEntity> older;
      try {
        final res = await getIt<GetOlderMessages>()(
          OlderMessagesParams(chatId: chatId, before: cursor),
        ).timeout(const Duration(seconds: 20));
        older = res.fold((_) => const <MessageEntity>[], (l) => l);
      } catch (e) {
        debugPrint('Yedek: eski sayfa alınamadı ($chatId): $e');
        break;
      }
      if (older.isEmpty) break;

      var added = 0;
      for (final m in older) {
        if (collected.putIfAbsent(m.id, () => m) == m) added++;
      }
      final oldest =
          older.map((m) => m.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
      // İlerleme yoksa döngüyü kır (sonsuz sayfalama koruması).
      if (added == 0 || !oldest.isBefore(cursor)) break;
      cursor = oldest;
    }

    final all = collected.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }

  // ---------------------------------------------------------------
  // YEDEK OLUŞTUR
  // ---------------------------------------------------------------
  /// Tüm sohbetleri toplar, şifreler ve dosyaya yazar.
  /// [onProgress] 0..1 arası ilerleme bildirir.
  static Future<File> create({
    required String password,
    required String myUid,
    required Directory targetDir,
    void Function(double progress, String label)? onProgress,
  }) async {
    onProgress?.call(0.02, 'chats');

    // 1) Sohbet listesi.
    //
    // ⚠️ Akışın İLK emisyonu boş/önbellek anlık görüntüsü olabiliyordu ve
    // yedek SESSİZCE 0 sohbetle üretiliyordu. Artık boş olmayan ilk
    // emisyon beklenir; zaman aşımında hata verilir (sessiz boş yedek yok).
    final conversations = await getIt<WatchConversations>()(const NoParams())
        .map((e) => e.fold<List<ConversationEntity>>((_) => const [], (l) => l))
        .firstWhere((list) => list.isNotEmpty)
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => const <ConversationEntity>[],
        );

    if (conversations.isEmpty) {
      throw const BackupEmptyError();
    }

    // 2) Her sohbetin ÇÖZÜLMÜŞ mesajları (TAMAMI, sayfalanarak)
    final chats = <Map<String, dynamic>>[];
    final failed = <String>[];
    var done = 0;
    for (final c in conversations) {
      List<MessageEntity> msgs = const [];
      try {
        msgs = await _collectAllMessages(c.id);
      } catch (e) {
        // Sessizce boş liste eklemek, kullanıcıya "tam yedek" yanılsaması
        // veriyordu. Başarısız sohbetler kaydedilir ve sonunda bildirilir.
        debugPrint('Yedek: ${c.id} okunamadı ($e)');
        failed.add(c.displayTitle(myUid));
      }

      chats.add({
        'id': c.id,
        'title': c.displayTitle(myUid),
        'isGroup': c.isGroup,
        'isChannel': c.isChannel,
        'messages': msgs
            .map((m) => {
                  'id': m.id,
                  'senderId': m.senderId,
                  'senderUsername': m.senderUsername,
                  'content': m.content,
                  'type': m.type.name,
                  'timestamp': m.timestamp.toIso8601String(),
                  'isDeleted': m.isDeleted,
                  if (m.mediaUrl != null) 'mediaUrl': m.mediaUrl,
                  if (m.fileName != null) 'fileName': m.fileName,
                })
            .toList(),
      });

      done++;
      onProgress?.call(
          0.02 +
              0.88 *
                  (done / (conversations.isEmpty ? 1 : conversations.length)),
          c.displayTitle(myUid));
    }

    // 3) JSON
    final payload = jsonEncode({
      'magic': _magic,
      'version': _version,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'ownerUid': myUid,
      'chatCount': chats.length,
      'messageCount':
          chats.fold<int>(0, (s, c) => s + (c['messages'] as List).length),
      'failedChats': failed,
      'chats': chats,
    });

    onProgress?.call(0.92, 'encrypt');

    // 4) Şifrele (AES-256-GCM, denetlenmiş `cryptography` paketiyle).
    //
    // ⚠️ `package:encrypt`'in GCM yolu bırakıldı: eski koddaki yorum
    // "yanlış parolada bazen ÇÖP VERİ döndürüyor" diyordu — bu, kimlik
    // doğrulama etiketinin GERÇEKTEN doğrulanmadığına işaret ediyor. Öyleyse
    // yedeğin bütünlük koruması yoktu: kurcalanmış bir dosya sessizce
    // yanlış veri döndürebilirdi. `AesGcm` etiketi her zaman doğrular.
    final salt = _randomBytes(16);
    final key = await _deriveKey(password, salt, _iterations);
    final box = await _aesGcm.encrypt(
      utf8.encode(payload),
      secretKey: SecretKey(key),
      nonce: _aesGcm.newNonce(),
    );

    // 5) Zarf: başlık düz (parolasız okunabilir üst veri), gövde şifreli.
    final envelope = jsonEncode({
      'magic': _magic,
      'version': _version,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'iv': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    });

    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(RegExp(r'[:T]'), '-');
    // NÖTR DOSYA ADI: `SECRETER_yedek_*` adı, cihazda uygulamanın varlığını
    // ele veriyordu — makul inkâr edilebilirlik iddiasıyla çelişir.
    final file = File('${targetDir.path}/backup_$stamp.json');
    await file.writeAsString(envelope);
    onProgress?.call(1.0, 'done');
    return file;
  }

  // ---------------------------------------------------------------
  // YEDEK OKU
  // ---------------------------------------------------------------
  /// 1. AŞAMA — Zarfı doğrula (PAROLA GEREKTİRMEZ).
  ///
  /// Dosyanın gerçekten bir SECRETER yedeği olup olmadığı burada anlaşılır.
  /// Böylece kullanıcıdan boşuna parola istenmez.
  static Map<String, dynamic> parseEnvelope(String raw) {
    Map<String, dynamic> env;
    try {
      env = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupFormatError();
    }
    if (env['magic'] != _magic ||
        env['salt'] == null ||
        env['iv'] == null ||
        env['data'] == null) {
      throw const BackupFormatError();
    }
    return env;
  }

  /// 2. AŞAMA — Parolayla çöz.
  ///
  /// AES-GCM kimlik doğrulaması sayesinde yanlış parola veya kurcalanmış
  /// dosya KESİN olarak hata verir (çöp veri dönmez).
  static Future<BackupData> decryptEnvelope(
      Map<String, dynamic> env, String password) async {
    final salt = Uint8List.fromList(base64Decode(env['salt'] as String));
    final iv = base64Decode(env['iv'] as String);

    // Tur sayısı ZARFTAN okunur. Eski kod sabit `_iterations` kullanıyordu;
    // tur sayısını ileride değiştirmek ESKİ yedekleri açılamaz hâle
    // getirirdi (sessiz veri kaybı).
    final iterations = (env['iterations'] as num?)?.toInt() ?? 120000;
    final key = await _deriveKey(password, salt, iterations);

    final macB64 = env['mac'] as String?;
    final data = base64Decode(env['data'] as String);

    String plain;
    try {
      if (macB64 != null) {
        // v2 biçimi: MAC ayrı alanda
        plain = utf8.decode(await _aesGcm.decrypt(
          SecretBox(data, nonce: iv, mac: Mac(base64Decode(macB64))),
          secretKey: SecretKey(key),
        ));
      } else {
        // v1 biçimi (package:encrypt): MAC şifreli metnin SONUNA eklenir.
        if (data.length < 16) throw const BackupFormatError();
        final split = data.length - 16;
        plain = utf8.decode(await _aesGcm.decrypt(
          SecretBox(
            data.sublist(0, split),
            nonce: iv,
            mac: Mac(data.sublist(split)),
          ),
          secretKey: SecretKey(key),
        ));
      }
    } on SecretBoxAuthenticationError {
      throw const BackupPasswordError();
    } on BackupFormatError {
      rethrow;
    } catch (_) {
      throw const BackupPasswordError();
    }

    Map<String, dynamic> map;
    try {
      map = jsonDecode(plain) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupPasswordError();
    }
    if (map['magic'] != _magic) throw const BackupPasswordError();
    return BackupData.fromMap(map);
  }
}

// ---------------------------------------------------------------
// ANAHTAR TÜRETME (isolate)
// ---------------------------------------------------------------
class _KdfRequest {
  final String password;
  final Uint8List salt;
  final int iterations;
  const _KdfRequest({
    required this.password,
    required this.salt,
    required this.iterations,
  });
}

Future<List<int>> _kdfIsolate(_KdfRequest req) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: req.iterations,
    bits: 256,
  );
  final key = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(req.password)),
    nonce: req.salt,
  );
  return key.extractBytes();
}

// ---------------------------------------------------------------
// MODELLER
// ---------------------------------------------------------------
class BackupData {
  final DateTime? createdAt;
  final int chatCount;
  final int messageCount;
  final List<BackupChat> chats;

  /// Yedeği ÜRETEN hesabın uid'i.
  ///
  /// ⚠️ BU ALAN YAZILIYOR AMA OKUNMUYORDU (§4ao). Geri yükleme tamamen
  /// YEREL ve `chatId` ile anahtarlı; birebir sohbet kimliği ise
  /// `sıralı(uid1,uid2)`den türüyor. Yani BAŞKA bir hesabın yedeği geri
  /// yüklendiğinde mesajlar, bu hesabın hiçbir zaman açmayacağı
  /// chatId'lere yazılıyordu: ekran "42 mesaj geri yüklendi" diyor,
  /// kullanıcı sohbetlere bakıyor ve **hiçbir şey yok.** Hata da yok.
  ///
  /// Eski yedeklerde alan bulunmayabilir → `null`, doğrulama atlanır.
  final String? ownerUid;

  const BackupData({
    required this.createdAt,
    required this.chatCount,
    required this.messageCount,
    required this.chats,
    this.ownerUid,
  });

  factory BackupData.fromMap(Map<String, dynamic> m) => BackupData(
        createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()),
        chatCount: (m['chatCount'] as num?)?.toInt() ?? 0,
        messageCount: (m['messageCount'] as num?)?.toInt() ?? 0,
        ownerUid: (m['ownerUid'] as String?)?.trim().isEmpty ?? true
            ? null
            : (m['ownerUid'] as String).trim(),
        chats: ((m['chats'] as List?) ?? const [])
            .map((e) => BackupChat.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  /// Bu yedek [myUid] hesabına ait mi?
  ///
  /// `ownerUid` taşımayan ESKİ yedekler için `true` döner — doğrulama
  /// yapamadığımız bir dosyayı reddetmek, çalışan bir kurtarma yolunu
  /// kırmak olurdu (§4m'nin dersi: yeni alan zorunlu kılınırken eski
  /// kayıtların ne olacağı düşünülmeli).
  bool belongsTo(String myUid) => ownerUid == null || ownerUid == myUid;
}

class BackupChat {
  final String id;
  final String title;
  final bool isGroup;
  final List<BackupMessage> messages;

  const BackupChat({
    required this.id,
    required this.title,
    required this.isGroup,
    required this.messages,
  });

  factory BackupChat.fromMap(Map<String, dynamic> m) => BackupChat(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        isGroup: m['isGroup'] == true || m['isChannel'] == true,
        messages: ((m['messages'] as List?) ?? const [])
            .map((e) => BackupMessage.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

class BackupMessage {
  final String senderUsername;
  final String senderId;
  final String content;
  final String type;
  final DateTime? timestamp;

  const BackupMessage({
    required this.senderUsername,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
  });

  factory BackupMessage.fromMap(Map<String, dynamic> m) => BackupMessage(
        senderUsername: (m['senderUsername'] ?? '').toString(),
        senderId: (m['senderId'] ?? '').toString(),
        content: (m['content'] ?? '').toString(),
        type: (m['type'] ?? 'text').toString(),
        timestamp: DateTime.tryParse((m['timestamp'] ?? '').toString()),
      );
}

class BackupPasswordError implements Exception {
  const BackupPasswordError();
}

class BackupFormatError implements Exception {
  const BackupFormatError();
}

/// Yedeklenecek sohbet bulunamadı — SESSİZCE boş dosya üretmek yerine
/// kullanıcıya bildirilir (eski davranış "yedeğim var" yanılsaması
/// yaratıyordu).
class BackupEmptyError implements Exception {
  const BackupEmptyError();
}
