import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/security/secure_store.dart';
import '../core/security/security_alerts.dart';
import 'double_ratchet_service.dart';
import 'e2ee_session_service.dart';
import '../core/observability/app_logger.dart';
import '../core/observability/handled_error.dart';

/// 👥 GRUP UÇTAN UCA ŞİFRELEME — "Sender Key" deseni
///
/// ── ÇÖZDÜĞÜ SORUN ──
/// Grup ve kanal mesajları sunucuda DÜZ METİN duruyordu. Yani uygulamanın
/// "kimse mesajlarını okuyamaz" iddiası yalnızca birebir sohbetler için
/// geçerliydi; her grup sohbeti Firebase'e (ve konsola erişebilen herkese)
/// tamamen açıktı.
///
/// ── NEDEN İKİLİ (PAIRWISE) ŞİFRELEME KULLANILMIYOR ──
/// N üyeli bir grupta her mesajı N-1 kez ayrı ayrı şifrelemek gerekirdi:
/// 50 kişilik grupta her mesaj için 49 şifreleme + 49 doküman. Signal'in
/// çözümü "sender key"dir ve burada da o uygulanır:
///
///   1. Her üye, her grup için kendine bir GÖNDEREN ZİNCİRİ üretir.
///   2. Bu zinciri, her üyeye MEVCUT İKİLİ E2EE kanalından şifreli yollar
///      (yalnızca bir kez — üyelik değişene kadar).
///   3. Mesajları kendi zincirinden türettiği anahtarla BİR KEZ şifreler.
///   4. Alıcılar, gönderene ait zinciri ilerleterek çözer.
///
/// ── ÖNEMLİ: DAĞITIM AYRI BİR OTURUM KULLANIR ──
/// Anahtar dağıtımı, ikili sohbetin ratchet'ini KULLANMAZ. Kullansaydı
/// dağıtım mesajı karşı tarafın DM alma zincirini ilerletir ve gerçek DM
/// mesajları çözülemez hâle gelirdi. Bu yüzden `kd_<sıralı uid çifti>`
/// adında AYRI bir oturum ad alanı kullanılır.
///
/// ── İLERİ GİZLİLİK (FORWARD SECRECY) ──
/// Gönderen zinciri her mesajda ilerler; geçmiş mesaj anahtarları geri
/// türetilemez. Üyelik değiştiğinde (biri ayrıldı/atıldı) zincir
/// ROTASYONA girer — ayrılan kişi sonraki mesajları okuyamaz.
///
/// ⚠️ ROTASYON HER ÜYENİN KENDİ CİHAZINDA OLMAK ZORUNDADIR. Her üyenin
/// AYRI bir gönderen zinciri vardır ve [rotate] yalnızca çağrıldığı
/// cihazdakini siler. Bu yüzden üyelik farkı gönderim anında
/// [syncMembership] ile her cihazda ayrıca ölçülür; yalnızca üyeyi atan
/// yöneticinin rotasyonuna güvenmek diğer üyelerin zincirlerini olduğu
/// gibi bırakırdı.
class GroupKeyService {
  static final _db = FirebaseFirestore.instance;

  /// Aktif hesap kapsamı (çoklu hesapta anahtarlar karışmasın).
  static String _scope = '_';
  static void setActiveAccount(String? uid) {
    _scope = (uid == null || uid.isEmpty) ? '_' : uid;
  }

  // ── Yerel anahtar adları ──
  static String _sendKey(String chatId) => 'gsk_send_${_scope}_$chatId';
  static String _recvKey(String chatId, String senderId) =>
      'gsk_recv_${_scope}_${chatId}_$senderId';

  /// Bu cihazın en son gördüğü üye listesi (rotasyon tetikleyicisi).
  static String _membersKey(String chatId) => 'gsk_members_${_scope}_$chatId';

  /// İkili anahtar-dağıtım oturumu için AYRI ad alanı.
  static String distSessionId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return 'kd_${ids.join('_')}';
  }

  static CollectionReference<Map<String, dynamic>> _dist(String chatId) =>
      _db.collection('groupKeys').doc(chatId).collection('dist');

  // ─────────────────────────────────────────
  // GÖNDEREN ZİNCİRİ (kendi anahtarım)
  // ─────────────────────────────────────────

  /// Bu grup için kendi gönderen zincirimi al; yoksa üret.
  static Future<_SenderChain> _mySenderChain(String chatId) async {
    final raw = await SecureStore.read(_sendKey(chatId));
    if (raw != null) {
      try {
        return _SenderChain.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (e, s) {
        reportHandled('Grup gönderen zinciri okunamadı, yenileniyor', e,
            stack: s);
      }
    }
    final fresh = _SenderChain(
      chainKey: _randomBytes(32),
      index: 0,
      epoch: DateTime.now().millisecondsSinceEpoch,
    );
    await _saveSenderChain(chatId, fresh);
    return fresh;
  }

  static Future<void> _saveSenderChain(String chatId, _SenderChain c) =>
      SecureStore.writeOrThrow(
          key: _sendKey(chatId), value: jsonEncode(c.toJson()));

  /// Zinciri yenile (üyelik değişiminde ROTASYON).
  ///
  /// Ayrılan/atılan üye eski zinciri bildiği için, rotasyon olmadan
  /// gruptan çıktıktan SONRAKİ mesajları da okuyabilirdi.
  static Future<void> rotate(String chatId) async {
    await SecureStore.delete(_sendKey(chatId));
    // Eski dağıtım kayıtları artık geçersiz; yenisi ilk mesajda yazılır.
    debugPrint('Grup anahtarı rotasyona girdi: $chatId');
  }

  /// Üyelik daraldıysa KENDİ gönderen zincirimi rotasyona sok.
  ///
  /// ── 🐞 KAPATTIĞI AÇIK ──
  /// Sender key deseninde her üyenin AYRI bir gönderen zinciri vardır ve
  /// [rotate] yalnızca çağrıldığı cihazdakini siler. Oysa rotasyon tek bir
  /// yerden tetikleniyordu: üyeyi ATAN yöneticinin cihazından
  /// (`GroupRepositoryImpl._afterMembershipChange`). Sonuç:
  ///
  ///   A, X'i gruptan atar → yalnızca A'nın zinciri yenilenir.
  ///   B, C, D'nin zincirleri OLDUĞU GİBİ kalır ve X — elindeki zincir
  ///   anahtarını ileri sürerek — onların SONRAKİ mesajlarını okumaya
  ///   devam eder.
  ///
  /// Yani sınıf başlığındaki "ayrılan kişi sonraki mesajları okuyamaz"
  /// sözü yalnızca TEK cihazda tutuyordu. Arayüzde hiçbir iz yoktu;
  /// atan kişi "onu attım, artık okuyamaz" sanıyordu.
  ///
  /// ── NEDEN SUNUCUYA ALAN EKLENMEDİ ──
  /// Üyelik değişimi zaten `memberIds` üzerinden görülüyor; ayrı bir
  /// sürüm/epoch alanı yazmak yeni üst veri üretirdi (§4o). Her cihaz
  /// kendi gördüğü listeyi YEREL anlık görüntüyle karşılaştırır —
  /// sunucuya hiçbir şey eklenmez, yeni kural gerekmez ve çevrimdışı
  /// kalmış bir cihaz da döndüğünde farkı görür.
  ///
  /// ── NEDEN GÖNDERİM ANINDA ──
  /// Zincirim yalnızca MESAJ GÖNDERDİĞİMDE bir şey açar. Atılan kişinin
  /// okuyabileceği ilk mesajdan hemen önce rotasyona girmek, ayrı bir
  /// dinleyici ya da arka plan işi olmadan tam zamanında koruma verir.
  ///
  /// ── ROTASYON BAŞARISIZSA KULLANICI DA GÖRÜR ──
  /// Rotasyon tutmazsa [SecurityAlerts] bayrağı KENDİ cihazımda kalkar ve
  /// sohbet ekranı uyarı bandını gösterir. Eskiden bu bant yalnızca üyeyi
  /// atan yöneticinin cihazında çıkabiliyordu.
  ///
  /// ⚠️ Yalnızca ÇIKAN üye rotasyonu tetikler. Üye EKLENMESİ tetiklemez:
  /// zincir ileri doğru ilerlediği için yeni üyeye ulaşan anahtar geçmiş
  /// mesajları zaten açmaz; her eklemede rotasyon ise tüm gruba
  /// gereksiz bir yeniden dağıtım maliyeti bindirirdi.
  ///
  /// Dönüş: zincir rotasyona girdiyse `true`.
  @visibleForTesting
  static Future<bool> syncMembership(
      String chatId, List<String> memberIds) async {
    final current = memberIds.where((u) => u.isNotEmpty).toSet();
    // ⚠️ BOŞ LİSTE BİR ÜYELİK DEĞİL, OKUNAMAMIŞ BİR LİSTEDİR.
    // "Herkes çıkmış" sayılsaydı her arızada rotasyon tetiklenir ve grup
    // anahtarı sürekli yeniden dağıtılırdı.
    if (current.isEmpty) return false;

    final raw = await SecureStore.read(_membersKey(chatId));
    Set<String>? previous;
    if (raw != null) {
      try {
        previous = (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
      } catch (e, s) {
        reportHandled('Grup üyelik anlık görüntüsü okunamadı', e, stack: s);
      }
    }

    final bool rotated;
    if (raw == null) {
      // Bu grubu ilk kez görüyoruz — karşılaştırılacak bir geçmiş yok.
      rotated = false;
    } else if (previous == null) {
      // Anlık görüntü bozuk: kimin çıktığı bilinemiyor. Güvenli taraf
      // ROTASYONDUR; bedeli tek bir yeniden dağıtım, alternatifi ise
      // atılmış bir üyenin okumaya devam etmesidir.
      rotated = true;
    } else {
      rotated = previous.difference(current).isNotEmpty;
    }

    if (rotated) {
      await rotate(chatId);
      // ── ROTASYON GERÇEKTEN OLDU MU? ──
      // `SecureStore.delete` hatayı YUTAR (yalnızca raporlar), yani
      // `rotate()` başarısız olsa bile sessizce döner. Zincir hâlâ
      // duruyorsa ileri gizlilik BOZULMUŞTUR: atılan üye sonraki
      // mesajlarımı okumaya devam eder.
      //
      // Bu uyarı eskiden yalnızca üyeyi ATAN yöneticinin cihazında
      // görünüyordu (`_afterMembershipChange`); diğer üyeler kendi
      // zincirlerinin yenilenmediğini hiç öğrenemiyordu. Artık her cihaz
      // KENDİ rotasyonunun sonucunu görüyor ve sohbet ekranındaki bant
      // "Tekrar dene" ile birlikte orada da çıkıyor.
      final failed = await SecureStore.read(_sendKey(chatId)) != null;
      await SecurityAlerts.setGroupKeyRotationFailed(chatId, failed);
      if (failed) {
        // ⚠️ ANLIK GÖRÜNTÜYÜ GÜNCELLEMEDEN ÇIK. Güncellenirse fark bir
        // daha görülmez ve rotasyon bir daha DENENMEZ; zincir kalıcı
        // olarak bayat kalır ve atılan üye okumaya devam eder. Böyle
        // bırakılınca bir sonraki gönderim aynı farkı görüp yeniden
        // dener — "Tekrar dene" düğmesini beklemeye gerek kalmaz.
        return false;
      }
    }

    final saved = await SecureStore.write(
        _membersKey(chatId), jsonEncode(current.toList()..sort()));
    if (!saved) {
      // Yazılamazsa bir sonraki gönderimde aynı fark yeniden görülür:
      // fazladan bir rotasyon olur, mesaj kaybolmaz. Yine de sessiz
      // kalmamalı — kalıcı bir yazma arızası her mesajı pahalılaştırır.
      reportHandled('Grup üyelik anlık görüntüsü yazılamadı',
          StateError('members_snapshot_write_failed'));
    }
    return rotated;
  }

  // ─────────────────────────────────────────
  // DAĞITIM
  // ─────────────────────────────────────────

  /// Gönderen zincirimi gruptaki diğer üyelere şifreli olarak dağıt.
  ///
  /// Zaten dağıtılmış (aynı epoch) üyeler atlanır — her mesajda yeniden
  /// dağıtmak gereksiz maliyet olurdu.
  ///
  /// Dönüş: dağıtımın en az bir üyeye ulaşıp ulaşmadığı. Hiçbir üyeye
  /// ulaşılamadıysa (kimsenin anahtar paketi yok) çağıran taraf şifreleme
  /// yapmamalı, aksi halde mesajı kimse çözemez.
  static Future<bool> distribute({
    required String chatId,
    required String myUid,
    required List<String> memberIds,
  }) async {
    final chain = await _mySenderChain(chatId);
    final targets = memberIds.where((u) => u != myUid && u.isNotEmpty);
    if (targets.isEmpty) return false;

    var delivered = 0;
    for (final target in targets) {
      try {
        final docId = '${target}__$myUid';
        final ref = _dist(chatId).doc(docId);

        // Aynı epoch zaten dağıtıldıysa tekrar yazma.
        final existing = await ref.get();
        if (existing.exists && existing.data()?['epoch'] == chain.epoch) {
          delivered++;
          continue;
        }

        final sessionId = distSessionId(myUid, target);
        Map<String, dynamic>? header;
        if (!await E2EESessionService.hasSession(sessionId)) {
          final h = await E2EESessionService.initiateSession(
            chatId: sessionId,
            otherUserId: target,
          );
          if (h == null) {
            debugPrint('Grup anahtarı: $target için ikili kanal yok');
            continue; // anahtar paketi yok — bu üyeye ulaşılamıyor
          }
          header = h.toMap();
        }

        final payload = await E2EESessionService.encryptMessage(
          chatId: sessionId,
          plaintext: jsonEncode(chain.toJson()),
        );
        if (payload == null) {
          // v3 (DH ratchet) oturumlarda gönderme zinciri, karşı taraftan
          // İLK MESAJ alınınca kurulur. Oturum kurulmuş ama hiçbir şey
          // çözülememişse burada zincir yoktur. Sessizce atlamak, "grup
          // anahtarı neden ulaşmıyor" sorusunu izsiz bırakırdı.
          debugPrint('Grup anahtarı: $target ile gönderme zinciri henüz yok — '
              'karşı taraftan ilk mesaj beklenmeli');
          continue;
        }

        await ref.set({
          'from': myUid,
          'to': target,
          'chatId': chatId,
          'epoch': chain.epoch,
          'payload': payload,
          if (header != null) 'header': header,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        });
        delivered++;
      } catch (e, s) {
        // ⚠️ GÜVENLİK: anahtarı alamayan üye grup mesajlarını HİÇ
        // okuyamaz. Sessiz kalırsa kullanıcı "mesajlar gelmiyor" der,
        // sebebi hiç bilinmez.
        reportHandled('Grup anahtarı dağıtılamadı', e,
            stack: s, context: {'hedef': Redact.id(target)});
      }
    }
    return delivered > 0;
  }

  /// Bana gönderilmiş anahtar dağıtımlarını çek ve yerelleştir.
  ///
  /// Mesaj çözülemediğinde çağrılır: yeni bir üye anahtarını yeni
  /// göndermiş olabilir.
  static Future<void> pullDistributions({
    required String chatId,
    required String myUid,
  }) async {
    try {
      final snap =
          await _dist(chatId).where('to', isEqualTo: myUid).limit(100).get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final from = (d['from'] ?? '').toString();
        final payload = (d['payload'] ?? '').toString();
        if (from.isEmpty || payload.isEmpty || from == myUid) continue;

        final sessionId = distSessionId(myUid, from);

        // İlk dağıtımda oturum başlığı gelir; onunla ikili kanalı kur.
        final header = d['header'];
        if (header is Map && !await E2EESessionService.hasSession(sessionId)) {
          final h = E2EEInitHeader.fromMap(Map<String, dynamic>.from(header));
          if (!h.isValid) continue;
          await E2EESessionService.establishFromHeader(
            chatId: sessionId,
            header: h,
          );
        }

        final plain = await E2EESessionService.decryptMessage(
          chatId: sessionId,
          ciphertext: payload,
        );
        if (plain == null) continue;

        final chain = _SenderChain.fromJson(
            Map<String, dynamic>.from(jsonDecode(plain) as Map));
        await SecureStore.writeOrThrow(
          key: _recvKey(chatId, from),
          value: jsonEncode(chain.toJson()),
        );
      }
    } catch (e, s) {
      reportHandled('Grup anahtarları alınamadı', e, stack: s);
    }
  }

  // ─────────────────────────────────────────
  // ŞİFRELE / ÇÖZ
  // ─────────────────────────────────────────

  /// Grup mesajını şifrele. Oturum kurulamadıysa null (çağıran düz gönderir).
  static Future<String?> encrypt({
    required String chatId,
    required String myUid,
    required List<String> memberIds,
    required String plaintext,
  }) async {
    try {
      // ⚠️ SIRALAMA KRİTİK: üyelik farkı, dağıtımdan ve zincirin
      // okunmasından ÖNCE ölçülmeli. Biri gruptan çıktıysa zincirim,
      // onun okuyabileceği İLK mesajdan önce rotasyona girer.
      await syncMembership(chatId, memberIds);

      final ok = await distribute(
        chatId: chatId,
        myUid: myUid,
        memberIds: memberIds,
      );
      if (!ok) return null; // kimse çözemez — düz gönderilmeli

      final chain = await _mySenderChain(chatId);
      final step = await DoubleRatchetService.encrypt(
        chainKey: chain.chainKey,
        plaintext: plaintext,
        messageNumber: chain.index,
      );

      await _saveSenderChain(
        chatId,
        chain.copyWith(chainKey: step.newChainKey, index: chain.index + 1),
      );

      // Zarf: hangi gönderenin hangi epoch'undan geldiği açıkça belirtilir.
      // (Bu üst veridir; içerik değildir.)
      return base64.encode(utf8.encode(jsonEncode({
        'v': 1,
        's': myUid,
        'e': chain.epoch,
        'p': step.ciphertext,
      })));
    } catch (e, s) {
      reportHandled('Grup mesajı şifrelenemedi', e, stack: s);
      return null;
    }
  }

  /// Grup mesajını çöz. Anahtar yoksa bir kez dağıtımları çekip tekrar dener.
  static Future<String?> decrypt({
    required String chatId,
    required String myUid,
    required String ciphertext,
    bool retry = true,
  }) async {
    _GroupEnvelope env;
    try {
      final decoded = jsonDecode(utf8.decode(base64.decode(ciphertext)));
      if (decoded is! Map) return null;
      env = _GroupEnvelope.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null; // bu bir grup zarfı değil
    }
    if (env.senderId.isEmpty || env.payload.isEmpty) return null;

    final raw = await SecureStore.read(_recvKey(chatId, env.senderId));
    if (raw == null) {
      if (!retry) return null;
      await pullDistributions(chatId: chatId, myUid: myUid);
      return decrypt(
        chatId: chatId,
        myUid: myUid,
        ciphertext: ciphertext,
        retry: false,
      );
    }

    _SenderChain chain;
    try {
      chain = _SenderChain.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }

    // Gönderen zincirini ROTASYONA soktuysa elimizdeki eski kalmıştır.
    if (env.epoch != chain.epoch) {
      if (!retry) return null;
      await pullDistributions(chatId: chatId, myUid: myUid);
      return decrypt(
        chatId: chatId,
        myUid: myUid,
        ciphertext: ciphertext,
        retry: false,
      );
    }

    final res = await DoubleRatchetService.decrypt(
      chainKey: chain.chainKey,
      chainIndex: chain.index,
      skipped: chain.skipped,
      encryptedPacket: env.payload,
    );
    if (res == null) return null;

    await SecureStore.writeOrThrow(
      key: _recvKey(chatId, env.senderId),
      value: jsonEncode(chain
          .copyWith(
            chainKey: res.newChainKey,
            index: res.newChainIndex,
            skipped: res.skipped,
          )
          .toJson()),
    );
    return res.plaintext;
  }

  /// Metin bir grup zarfı mı? (düz metin/eski mesajları ayırmak için)
  static bool isGroupEnvelope(String value) {
    try {
      final decoded = jsonDecode(utf8.decode(base64.decode(value)));
      return decoded is Map && decoded['v'] == 1 && decoded['s'] is String;
    } catch (_) {
      return false;
    }
  }

  /// Bu hesabın tüm grup anahtarlarını sil (çıkış / hesap silme).
  static Future<void> wipeAccount() async {
    await SecureStore.deleteByPrefix('gsk_send_${_scope}_');
    await SecureStore.deleteByPrefix('gsk_recv_${_scope}_');
    await SecureStore.deleteByPrefix('gsk_members_${_scope}_');
  }

  static List<int> _randomBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }
}

/// Bir üyenin bu gruptaki gönderen/alıcı zinciri.
class _SenderChain {
  final List<int> chainKey;
  final int index;

  /// Rotasyon kimliği — üyelik değişince yenilenir.
  final int epoch;

  /// Sırasız gelen mesajlar için atlanan anahtarlar.
  final Map<String, String> skipped;

  const _SenderChain({
    required this.chainKey,
    required this.index,
    required this.epoch,
    this.skipped = const {},
  });

  Map<String, dynamic> toJson() => {
        'k': base64.encode(chainKey),
        'i': index,
        'e': epoch,
        'skp': skipped,
      };

  factory _SenderChain.fromJson(Map<String, dynamic> j) => _SenderChain(
        chainKey: base64.decode(j['k'] as String),
        index: (j['i'] as num?)?.toInt() ?? 0,
        epoch: (j['e'] as num?)?.toInt() ?? 0,
        skipped: (j['skp'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            const {},
      );

  _SenderChain copyWith({
    List<int>? chainKey,
    int? index,
    int? epoch,
    Map<String, String>? skipped,
  }) =>
      _SenderChain(
        chainKey: chainKey ?? this.chainKey,
        index: index ?? this.index,
        epoch: epoch ?? this.epoch,
        skipped: skipped ?? this.skipped,
      );
}

class _GroupEnvelope {
  final String senderId;
  final int epoch;
  final String payload;

  const _GroupEnvelope({
    required this.senderId,
    required this.epoch,
    required this.payload,
  });

  factory _GroupEnvelope.fromJson(Map<String, dynamic> j) => _GroupEnvelope(
        senderId: (j['s'] ?? '').toString(),
        epoch: (j['e'] as num?)?.toInt() ?? 0,
        payload: (j['p'] ?? '').toString(),
      );
}
