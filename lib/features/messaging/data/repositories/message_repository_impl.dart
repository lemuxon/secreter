import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/media/attachment_crypto.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/auth/current_user_provider.dart';
import '../../../../core/privacy/privacy_controller.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';
import '../datasources/message_remote_datasource.dart';
import '../datasources/message_local_datasource.dart';
import '../datasources/encryption_datasource.dart';
import '../datasources/message_sync_service.dart';
import '../models/message_model.dart';
import 'package:flutter/foundation.dart';
import '../../../../services/backup_restore_service.dart';
import '../../../../services/username_resolver.dart';
import '../../../../core/observability/handled_error.dart';

/// MessageRepository'nin somut implementasyonu (v10: offline-aware).
///
/// Sorumluluğu: remote (Firestore) + local (Hive cache) + encryption +
/// network durumunu birleştirip, exception'ları Failure'a çevirmek.
///
/// Offline stratejisi (cache-then-network):
/// - watchMessages: önce cache'i yayınlar (anında), sonra ağdan gelenle günceller
/// - sendText: online → direkt gönder; offline → pending kuyruğuna ekle
class MessageRepositoryImpl implements MessageRepository {
  final MessageRemoteDataSource remoteDataSource;
  final MessageLocalDataSource localDataSource;
  final EncryptionDataSource encryptionDataSource;
  final NetworkInfo networkInfo;
  final MessageSyncService syncService;
  final CurrentUserProvider userProvider;
  final PrivacySettingsReader privacyReader;
  final Uuid uuid;

  MessageRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.encryptionDataSource,
    required this.networkInfo,
    required this.syncService,
    required this.userProvider,
    required this.privacyReader,
    required this.uuid,
  });

  @override
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(
      String chatId) async* {
    // ⚠️ `currentUid` HER YAYIMDA yeniden okunur, akış kurulurken BİR KEZ
    // değil (§4bh).
    //
    // 🐞 GERÇEK KULLANICIDA GÖRÜLDÜ: *"ilk ekrana girince tüm mesajlar
    // gecikmeli olarak silinmiş gibi göründü, sonra geç güncellendi."*
    //
    // Sebep: Firebase Auth kaydedilmiş oturumu ASENKRON geri yükler.
    // Ekran ondan önce açılırsa `currentUid` NULL yakalanıyor ve o akışın
    // TÜM ömrü boyunca null kalıyordu. Sonucu:
    //   • `isFromMe` her mesaj için FALSE olur → KENDİ mesajlarımız
    //     "karşıdan gelmiş" sayılıp çözülmeye kalkılır ve başarısız olur
    //     (gönderenin şifreli metnini ratchet zaten çözemez; düz metni
    //     önbellekten gelir),
    //   • çözülemeyen mesaj arayüzde ortalanmış GRİ BİLGİ KUTUSU olarak
    //     çizilir → bütün sohbet "silinmiş" gibi görünür,
    //   • `deletedFor` süzgeci de çalışmaz.
    // Ekran yeniden kurulduğunda (uid oturmuş olarak) kendiliğinden
    // düzeliyordu; "geç güncellendi" izleniminin sebebi buydu.
    //
    // Aynı sınıf hata §4bd'de hesap KAPSAMINDA vardı; burası ikinci yeri.

    // 1. ÖNCE: cache'teki mesajları anında yayınla (offline'da bile çalışır)
    try {
      final myUid = userProvider.currentUid;
      final cached = await localDataSource.getCachedMessages(chatId);
      if (cached.isNotEmpty) {
        final decrypted = await _decryptMessages(chatId, cached, myUid);
        final merged = _mergeRestored(chatId, decrypted);
        yield Right<Failure, List<MessageEntity>>(merged);
      }
    } catch (_) {
      // Cache yoksa sorun değil, ağdan gelecek
    }

    // 2. SONRA: ağdan canlı dinle, geleni cache'le ve yayınla
    yield* remoteDataSource.watchMessages(chatId).asyncMap((messages) async {
      try {
        // Gelen mesajları cache'e yaz — ARKA PLANDA.
        // BLOKLAMA: bu bir "sonraki açılış için hızlandırma" işlemi;
        // canlı güncellemeyi disk yazmasına bağlamak yanlıştı. Yazma
        // yavaşlarsa mesajlar ekrana düşmüyordu.
        unawaited(localDataSource
            .cacheMessages(chatId, messages)
            .catchError((e) => debugPrint('Önbelleğe yazılamadı: $e')));

        // Her yayımda TAZE oku: oturum bu arada oturmuş olabilir.
        final myUid = userProvider.currentUid;
        final decrypted = await _decryptMessages(chatId, messages, myUid);
        // 💾 YEDEKTEN GERİ YÜKLENENLERİ BİRLEŞTİR (yalnız bu cihazda).
        // Sunucudaki mesaj kazanır; yedekten gelen kopyalar elenir.
        final merged = _mergeRestored(chatId, decrypted);
        return Right<Failure, List<MessageEntity>>(merged);
      } catch (e, s) {
        reportHandled('Mesajlar çözülemedi', e, stack: s);
        return const Left<Failure, List<MessageEntity>>(
            EncryptionFailure('err_decrypt_messages'));
      }
    }).transform(
      // HATA: handleError donen degeri AKISA EKLEMEZ — hatayi yutar.
      // Sonuc: sunucu sorgusu hata verince (dizin/izin/ag) hicbir sey
      // yayilmiyor, sohbet ekrani SONSUZ "yukleniyor" kaliyordu
      // (yeni acilan kanallarda net gorulur). transform ile hata da
      // bir deger olarak yayilir.
      StreamTransformer<Either<Failure, List<MessageEntity>>,
          Either<Failure, List<MessageEntity>>>.fromHandlers(
        handleError: (e, st, sink) {
          reportHandled('watchMessages', e, stack: st);
          sink.add(const Left(ServerFailure()));
        },
      ),
    );
  }

  /// Mesaj listesini çöz (cache ve ağ için ortak)
  // PERFORMANS: cozulmus metin memo'su (id -> plain). Ayni mesaj her
  // emisyonda yeniden decrypt/await zincirine girmesin (senkron kisa devre).
  final Map<String, String> _plainMemo = {};
  static const int _memoCap = 3000;
  // Süresi dolup silinmesi tetiklenen mesajlar (tekrar denenmesin)
  final Set<String> _expiredHandled = {};

  /// Hesap değişiminde çağrılır: bu repository lazy singleton olduğu için
  /// önbellekler ÖNCEKİ hesabın verisini taşıyordu (çoklu hesapta düz metin
  /// sızıntısı riski).
  void clearCaches() {
    _plainMemo.clear();
    _kayipMemo.clear();
    _gorulenBaslik.clear();
    _expiredHandled.clear();
  }

  /// 🔑 Düz metin önbellek anahtarı.
  ///
  /// Önbellek yalnızca mesaj kimliğiyle anahtarlanıyordu. Bir mesaj
  /// düzenlendiğinde alıcı, önbellekteki ESKİ metni okumaya devam ediyor
  /// ve düzenlemeyi HİÇ görmüyordu. Düzenleme damgası anahtara girince
  /// yeni içerik yeniden çözülür.
  ///
  /// Damga, Firestore'a yazılan ISO-8601 UTC dizesinin AYNISIDIR; böylece
  /// gönderen kendi yazdığı anahtarı akıştan geri okuduğunda da bulur
  /// (bulamazsa kendi şifreli mesajını çözmeye kalkar ve "çözülemedi"
  /// görürdü — ratchet tek yönlüdür).
  static String _plainKey(String messageId, DateTime? editedAt) =>
      editedAt == null
          ? messageId
          : '$messageId#${editedAt.toUtc().toIso8601String()}';

  /// Bir mesajın memo'daki TÜM sürümlerini düşür.
  void _forgetPlainMemo(String messageId) {
    _kayipMemo.remove(messageId);
    _kayipMemo.removeWhere((k) => k.startsWith('$messageId#'));
    _plainMemo.remove(messageId);
    _plainMemo.removeWhere((k, _) => k.startsWith('$messageId#'));
  }

  /// Çözülmüş metni memo'ya al — LRU benzeri budamayla.
  ///
  /// `clear()` tüm memo'yu atıp her mesajı yeniden çözmeye zorluyordu;
  /// ratchet zaten ilerlediği için bu yalnızca gereksiz güvenli-depo
  /// okuması demekti.
  /// Çözülemeyen mesajların memo anahtarları (§4az).
  ///
  /// ── NEDEN AYRI TUTULUYOR ──
  /// İki uç da yanlıştı:
  ///  • Başarısızlığı önbelleğe ALMAK: oturum sonradan onarılsa bile
  ///    (§4av/§4ax yeniden el sıkışması) mesaj, uygulama yeniden
  ///    başlayana kadar "çözülemiyor" kalır — kurtarma çalışır ama
  ///    kullanıcı çalıştığını göremez.
  ///  • Hiç ALMAMAK: her Firestore anlık görüntüsünde bozuk mesajların
  ///    TAMAMI yeniden çözülmeye kalkılır (güvenli depo okuması +
  ///    ratchet denemesi). Bozuk mesajı çok olan sohbette bu takılma
  ///    demektir.
  ///
  /// Orta yol: başarısızlık önbelleğe alınır AMA ayrıca işaretlenir;
  /// karşı taraftan BAŞLIK taşıyan bir mesaj geldiği anda (yani
  /// kurtarmanın mümkün hâle geldiği tek an) işaretliler atılır.
  final Set<String> _kayipMemo = {};

  /// Başlığı DAHA ÖNCE görülmüş mesajlar (§4az). Başlık mesaj
  /// belgesinde kalıcı olduğu için "yeni mi" ayrımı bu kümeyle
  /// yapılır; yoksa kurtarma penceresi hiç kapanmazdı.
  final Set<String> _gorulenBaslik = {};

  void _rememberPlain(String id, String plain) {
    if (plain == EncryptionDataSource.lostMarker) {
      _kayipMemo.add(id);
    } else {
      _kayipMemo.remove(id);
    }
    if (_plainMemo.length > _memoCap) {
      for (final k in _plainMemo.keys.take(_memoCap ~/ 4).toList()) {
        _plainMemo.remove(k);
      }
    }
    _plainMemo[id] = plain;
  }

  /// Medya önizlemesi — yalnızca TÜR, içerik/dosya adı YOK.
  ///
  /// `message.preview` dosya adını içeriyordu ("📎 pasaport-tarama.pdf");
  /// bu, sohbet listesinde ve sunucuda okunabilir hassas üst veriydi.
  static String _mediaPreview(MessageContentType type) => switch (type) {
        MessageContentType.image => '🖼️ Fotoğraf',
        MessageContentType.video => '🎬 Video',
        MessageContentType.voice => '🎤 Sesli mesaj',
        MessageContentType.file => '📎 Dosya',
        MessageContentType.gif => '🎬 GIF',
        MessageContentType.poll => '📊 Anket',
        _ => '🔒 Mesaj',
      };

  /// Grup anahtar dağıtımı için üye listesi (kısa süreli önbellekli).
  ///
  /// ── ⚠️ BURASI ARIZAYI YUTMAZ — C-06'NIN YAN KAPISIYDI ──
  /// Eskiden hata yakalanıp `const []` dönülüyordu. Boş liste, şifreleme
  /// katmanında bir ARIZA olarak değil bir DURUM olarak okunuyordu:
  /// `encrypt()` içindeki `memberIds.length < 2` dalı "dejenere grup"
  /// sayıp mesajı **ŞİFRESİZ** gönderiyordu. Yani geçici bir Firestore
  /// okuma hatası, grup mesajının sunucuya düz metin gitmesine yetiyordu —
  /// tam olarak C-06'nın ("şifreleme hatası sessizce DÜZ METNE düşüyordu")
  /// §4x'te kapatılan davranışı, başka bir kapıdan.
  ///
  /// Artık istisna YUKARI GİDER. Üç çağıran da (`sendTextMessage`,
  /// `sendMediaMessage`, `editMessage`) `ServerException`ı kullanıcıya
  /// görünen bir `ServerFailure`a çevirir ve mesaj GÖNDERİLMEZ.
  /// §4x'in ilkesi: şifreli sanılan bir mesajın açıkta gitmesindense
  /// gönderilmemesi yeğdir; kullanıcı tekrar deneyebilir.
  Future<List<String>> _membersOf(String chatId) =>
      remoteDataSource.memberIds(chatId);

  /// 💾 Geri yüklenen (yedekten gelen) mesajları canlı listeye ekler.
  ///
  /// Tekilleştirme: aynı gönderen + aynı zaman + aynı içerik ise sunucudaki
  /// kayıt kazanır, yedek kopyası elenir. Böylece geri yükleme çift
  /// mesaj üretmez ve tekrar tekrar yapılabilir.
  /// ⚠️ SENKRON: akışı BEKLETMEZ. Önbellek henüz yüklenmediyse canlı
  /// liste olduğu gibi döner ve yükleme arka planda başlatılır.
  /// (Eskiden burada `await` vardı ve canlı güncellemeleri tıkıyordu.)
  List<MessageEntity> _mergeRestored(String chatId, List<MessageEntity> live) {
    try {
      final restored = BackupRestoreService.getRestoredSync(chatId);
      if (restored == null) {
        BackupRestoreService.preload(chatId); // arka planda
        return live;
      }
      if (restored.isEmpty) return live;

      String sig(MessageEntity m) =>
          '${m.senderId}|${m.timestamp.toIso8601String()}|${m.content}';
      final seen = live.map(sig).toSet();

      final extra = restored.where((r) => !seen.contains(sig(r))).toList();
      if (extra.isEmpty) return live;

      final all = [...live, ...extra]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return all;
    } catch (e) {
      debugPrint('Geri yükleme birleştirilemedi: $e');
      return live;
    }
  }

  Future<List<MessageEntity>> _decryptMessages(
      String chatId, List<MessageModel> rawMessages, String? myUid) async {
    // ── ÖNCE ÖNBELLEĞİ ISIT (§4bi) ──
    // Aksi hâlde her mesaj için ayrı güvenli-depo okuması yapılır; 200
    // mesajlık sohbette 200 platform çağrısı demektir ve sohbet önce
    // saniyelerce "yükleniyor", sonra mesajlar geç dolduğu için SİLİNMİŞ
    // gibi görünür. İlk çağrıdan sonrası bedava.
    await encryptionDataSource.warmPlaintextCache();

    // ── METADATA GİZLİLİĞİ ──
    // `senderUsername` artık sunucuya YAZILMIYOR; ad burada uid'den
    // çözülür. Tek toplu ısıtma yapılır — bir sohbetin göndereni birkaç
    // kişiden ibaret olduğu için ilk açılıştan sonra ağ isteği olmaz.
    await UsernameResolver.warm(
      rawMessages
          .where((m) => m.senderUsername.isEmpty && m.senderId != myUid)
          .map((m) => m.senderId),
    );
    // ── KURTARMA PENCERESİ (§4az) ──
    // Karşı taraf yeniden el sıkıştıysa başlık taşıyan YENİ bir mesaj
    // gelir; daha önce "çözülemedi" dediklerimiz artık çözülebilir
    // olabilir. Memo yalnızca o anda atılır.
    //
    // ⚠️ "Partide başlık VAR MI" diye sormak YETMEZ, YANLIŞ olur:
    // `e2eeHeader` mesaj belgesinde KALICIDIR. Oturumu başlatan mesaj
    // görünür pencerede durduğu sürece o koşul HER anlık görüntüde
    // doğru çıkar; bozuk mesajların tamamı sürekli yeniden çözülmeye
    // kalkılır ve önbelleğin varlık sebebi ortadan kalkardı.
    // Ölçüt bu yüzden YENİLİK: daha önce görülmemiş bir başlık.
    final yeniBaslikli = rawMessages
        .where((m) => m.e2eeHeader != null && !_gorulenBaslik.contains(m.id))
        .map((m) => m.id)
        .toList(growable: false);
    if (yeniBaslikli.isNotEmpty) {
      _gorulenBaslik.addAll(yeniBaslikli);
      if (_gorulenBaslik.length > _memoCap) _gorulenBaslik.clear();
      for (final k in _kayipMemo) {
        _plainMemo.remove(k);
      }
      _kayipMemo.clear();
    }

    final messages = rawMessages
        .map((m) => m.withResolvedSender(UsernameResolver.cached(m.senderId)))
        .toList(growable: false);

    final decrypted = <MessageEntity>[];
    // Grup/kanal (1-1 değil) → E2EE yok; içerik düz metin, doğrudan gösterilir.
    final isDirect = _extractOtherUserId(chatId, myUid ?? '').isNotEmpty;
    for (final msg in messages) {
      if (msg.isExpired && !msg.isDeleted) {
        // Kendini imha: gizle + sunucudan KALICI sil (bir kez)
        if (_expiredHandled.add(msg.id)) {
          // fire-and-forget; UI'yi bloklamaz
          remoteDataSource.hardDeleteMessage(chatId, msg.id);
          // CİHAZDAKİ DÜZ METNİ DE SİL — aksi halde "kaybolan mesaj"
          // yalnızca sunucudan kayboluyor, cihazda okunabilir kalıyordu.
          _forgetPlainMemo(msg.id);
          // ⚠️ C-07: başarısız olursa "kaybolan mesaj" yalnızca
          // sunucudan kaybolur, CİHAZDA okunabilir kalır. Kullanıcı
          // mesajın yok olduğuna inanır.
          encryptionDataSource.forgetPlaintext(msg.id).catchError((Object e) =>
              reportHandled('Süresi dolan düz metin silinemedi', e));
          // Bellek sızıntısı koruması: küme sınırsız büyümesin.
          if (_expiredHandled.length > 5000) _expiredHandled.clear();
        }
        continue;
      }
      // 'Benden sil': bu kullanici icin gizlenmis mesajlari atla
      if (myUid != null && msg.deletedFor.contains(myUid)) continue;

      // MEDYA MESAJLARI: ek anahtarı şifreli `content` içinde taşınır.
      // Şifresiz (eski) eklerde content boştur → anahtar null kalır ve
      // görüntüleme katmanı eski davranışa döner.
      if (msg.type != MessageContentType.text &&
          !msg.isDeleted &&
          msg.isEncrypted &&
          msg.content.isNotEmpty) {
        final mediaKey = _plainKey(msg.id, msg.editedAt);
        final memo = _plainMemo[mediaKey];
        final plain = memo ??
            await encryptionDataSource.decrypt(
              chatId: chatId,
              ciphertext: msg.content,
              isFromMe: msg.senderId == myUid,
              messageId: mediaKey,
              e2eeHeader: msg.e2eeHeader,
              isGroup: !isDirect,
            );
        _rememberPlain(mediaKey, plain);

        // ── 🐞 ÇÖZÜLEMEYEN MEDYA "BOZUK RESİM" OLARAK GÖRÜNÜYORDU ──
        //
        // GERÇEK KULLANICIDA GÖRÜLDÜ: *"galeri resimleri açılmıyor ama
        // video gelmiş"* — aynı sohbette bazı mesajlar da "çözülemedi"
        // diyordu. İkisi AYNI KÖKTEN geliyordu.
        //
        // Ek anahtarı mesajın ŞİFRELİ `content`i içinde taşınır. İçerik
        // çözülemezse anahtar da çıkmaz; eski kod bu durumda mesajı
        // OLDUĞU GİBİ bırakıyordu. Sonuç: `mediaKey` null kalıyor,
        // `SecureMediaImage` şifresiz sanıp ham URL'i indiriyor ve
        // ŞİFRELİ baytları çözmeye çalışıyordu → kırık resim simgesi.
        //
        // Kullanıcının gördüğü şey "ağ sorunu / bozuk dosya" diyordu;
        // gerçek sebep ise metin mesajlarındakiyle AYNI, yani
        // çözülememiş bir mesaj. Metinde dürüst bir kutu gösteriliyor,
        // medyada gösterilmiyordu.
        //
        // ⚠️ Yalnızca ÇÖZÜLEMEME durumu işaretlenir. Çözülüp de
        // ayrıştırılamayan içerik ESKİ BİÇİMLİ bir ektir; onun davranışı
        // aynen korunur (şifresiz eski mesajlar hâlâ açılmalı).
        if (plain == EncryptionDataSource.lostMarker) {
          decrypted.add(msg.copyWithContent(EncryptionDataSource.lostMarker));
          continue;
        }
        final ref = AttachmentRef.tryParse(plain);
        decrypted.add(ref == null
            ? msg
            : msg.copyWithContent(ref.caption, mediaKey: ref.key));
        continue;
      }

      if (msg.type == MessageContentType.text && !msg.isDeleted) {
        // ŞİFRELİ DEĞİL BAYRAĞINA SAYGI DUY.
        // Sistem mesajları ("📞 Cevapsız çağrı") ve düzenlenmiş mesajlar
        // düz metindir; bu bayrakla işaretlenir ve doğrudan gösterilir.
        if (!msg.isEncrypted) {
          decrypted.add(msg.copyWithContent(msg.content));
          continue;
        }
        // Düzenlenmişse anahtar damgayla değişir → yeni içerik çözülür.
        final key = _plainKey(msg.id, msg.editedAt);
        final memo = _plainMemo[key];
        if (memo != null) {
          decrypted.add(msg.copyWithContent(memo));
          continue;
        }
        final plain = await encryptionDataSource.decrypt(
          chatId: chatId,
          ciphertext: msg.content,
          isFromMe: msg.senderId == myUid,
          messageId: key,
          // Header'i gecir: alici bununla E2EE oturumunu kurar
          e2eeHeader: msg.e2eeHeader,
          // Grup mesajları sender-key zarfıyla gelir.
          isGroup: !isDirect,
        );
        _rememberPlain(key, plain);
        decrypted.add(msg.copyWithContent(plain));
      } else {
        decrypted.add(msg);
      }
    }
    return decrypted;
  }

  @override
  Future<Either<Failure, Unit>> sendTextMessage({
    required String chatId,
    required String text,
    String? replyToId,
    String? replyToPreview,
    int? disappearAfterSeconds,
  }) async {
    try {
      final username = await userProvider.currentUsername;
      final myUid = userProvider.currentUid!;
      final otherUserId = _extractOtherUserId(chatId, myUid);
      final isDirect = otherUserId.isNotEmpty;

      // ŞİFRELE — birebirde X3DH+Ratchet, grup/kanalda SENDER KEY.
      //
      // ⚠️ Eskiden grup/kanal içeriği hiç şifrelenmiyor, sunucuda DÜZ METİN
      // duruyordu. Artık grup mesajları da uçtan uca şifrelenir; anahtar
      // dağıtımı için üye listesi gerekir.
      final encResult = await encryptionDataSource.encrypt(
        chatId: chatId,
        otherUserId: otherUserId,
        plaintext: text,
        memberIds: isDirect ? const [] : await _membersOf(chatId),
      );

      // METADATA GİZLİLİĞİ: kaba zaman damgası açıksa dakikaya yuvarla
      // (saniye hassasiyeti zamanlama korelasyonu/analizini kolaylaştırır)
      // SIRALAMA DUZELTME: zaman damgasi TAM HASSAS saklanir (mikrosaniye),
      // boylece ayni dakikadaki mesajlar dogru siralanir. Ekranda zaten yalnizca
      // SS:dd gosterildigi icin gizlilik korunur; yalnizca Firestore'daki ham
      // deger dakika-alti hassasiyet tasir (istenirse per-chat sayacla gizlenebilir).
      final now = DateTime.now();
      final online = await networkInfo.isConnected;

      final message = MessageModel(
        id: uuid.v4(),
        chatId: chatId,
        senderId: myUid,
        senderUsername: username ?? '',
        content: encResult.ciphertext,
        type: MessageContentType.text,
        timestamp: now,
        // Offline ise "sending" durumunda — UI saat ikonu gösterir
        status:
            online ? MessageDeliveryStatus.sent : MessageDeliveryStatus.sending,
        isEncrypted: encResult.isEncrypted,
        replyToId: replyToId,
        replyToPreview: replyToPreview,
        disappearAfterSeconds: disappearAfterSeconds,
        expiresAt: disappearAfterSeconds != null
            ? now.add(Duration(seconds: disappearAfterSeconds))
            : null,
        // E2EE oturum basligini mesajla birlikte ilet (alici oturumu kurar).
        // Bu olmadan alici mesaji cozemez -> "cozulemedi".
        e2eeHeader: encResult.e2eeHeader,
      );

      // E2EE ratchet TEK YÖNLÜDÜR; gönderen kendi şifreli mesajını çözemez.
      // Düz metni messageId ile sakla — decrypt() kendi mesajlarımız için
      // (isFromMe) bu kayıttan okur.
      //
      // NOT: Artık statik servis değil, enjekte edilen encryptionDataSource
      // üzerinden çağrılıyor. Doğrudan statik çağrı, repository'yi platform
      // kanalına bağlıyor ve BİRİM TESTLERİNİ "Binding has not yet been
      // initialized" hatasıyla düşürüyordu (Dependency Inversion ihlali).
      await encryptionDataSource.cachePlaintext(message.id, text);

      // Her durumda cache'e yaz (UI anında gösterir — optimistic update)
      await localDataSource.cacheMessage(chatId, message);

      if (online) {
        try {
          await remoteDataSource.sendMessage(chatId, message);
        } on ServerException catch (e) {
          // ── MESAJ KAYBINI ÖNLE ──
          // Yorum "ağ hatası → pending'e ekle" diyordu ama kod bunu
          // YAPMIYORDU: gönderim patlayınca mesaj yalnızca Left olarak
          // dönüyor ve KALICI OLARAK KAYBOLUYORDU. Artık kuyruğa alınır.
          debugPrint('Gönderim başarısız, kuyruğa alınıyor: ${e.message}');
          await localDataSource.addPendingMessage(message);
          return Left(ServerFailure(e.message));
        }
      } else {
        // Offline: pending kuyruğuna ekle, bağlanınca gönderilecek
        await localDataSource.addPendingMessage(message);
      }

      // SON MESAJ + ROZET her durumda güncellenir (Firestore çevrimdışı
      // yazmaları kendisi kuyruklar).
      //
      // ⚠️ GİZLİLİK: önizlemeye ASLA içerik yazılmaz. Eski kod şifresiz
      // sohbetlerde (grup/kanal) mesajın TAM METNİNİ `chats.lastMessage`
      // alanına düz yazıyordu — yani içerik şifrelenmiş olsa bile son
      // mesaj sunucuda açıkta duruyordu.
      await remoteDataSource.updateLastMessage(
        chatId,
        '🔒 Mesaj',
        senderId: myUid,
      );

      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on EncryptionException catch (e) {
      return Left(EncryptionFailure(e.message));
    } catch (e, s) {
      reportHandled('sendTextMessage', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> sendMediaMessage({
    required String chatId,
    required String localFilePath,
    required MessageContentType type,
    String? fileName,
    String? replyToId,
    String? replyToPreview,
    String? mediaSource,
    bool viewOnce = false,
    int? voiceDurationMs,
  }) async {
    try {
      final username = await userProvider.currentUsername;
      final myUid = userProvider.currentUid!;
      final msgId = uuid.v4();
      final file = File(localFilePath);

      // Alt yol tipe göre
      final subPath = switch (type) {
        MessageContentType.image => 'images/$msgId.jpg',
        MessageContentType.voice => 'voice/$msgId.m4a',
        MessageContentType.file => 'files/$msgId-${fileName ?? "file"}',
        MessageContentType.video => 'videos/$msgId.mp4',
        _ => 'media/$msgId',
      };

      final fileSize = await file.length();

      // ── 🔐 EK ŞİFRELEME ──
      //
      // Eskiden fotoğraf/video/ses/dosya Storage'a DÜZ yükleniyordu: metin
      // uçtan uca şifreliyken, çoğu zaman metinden daha hassas olan medya
      // sunucuda tamamen açıktı.
      //
      // Artık her ek için rastgele bir anahtar üretilir, dosya cihazda
      // AES-256-GCM ile şifrelenir ve Storage'a yalnızca şifreli baytlar
      // gider. ANAHTAR, mesajın E2EE'li `content` alanının içinde taşınır —
      // yani sunucu şifreli dosyayı saklar ama açacak anahtarı asla görmez.
      final otherUserId = _extractOtherUserId(chatId, myUid);
      final isDirect = otherUserId.isNotEmpty;

      final attachmentKey = AttachmentCrypto.newKey();
      final encResult = await encryptionDataSource.encrypt(
        chatId: chatId,
        otherUserId: otherUserId,
        plaintext: AttachmentRef(key: attachmentKey).encode(),
        memberIds: isDirect ? const [] : await _membersOf(chatId),
      );

      // Anahtarı güvenle iletemiyorsak (karşı tarafın anahtar paketi yok)
      // dosyayı şifrelemek onu HERKES için okunmaz yapardı.
      final canEncryptMedia = encResult.isEncrypted;

      final String url;
      if (canEncryptMedia) {
        final cipherBytes =
            await AttachmentCrypto.encryptFile(file, attachmentKey);
        url = await remoteDataSource.uploadMediaBytes(
            chatId, cipherBytes, subPath);
      } else {
        debugPrint('Ek şifrelenemedi (anahtar iletilemiyor) — düz yükleniyor');
        url = await remoteDataSource.uploadMedia(chatId, file, subPath);
      }

      final message = MessageModel(
        id: msgId,
        chatId: chatId,
        senderId: myUid,
        senderUsername: username ?? '',
        // Şifreli ek anahtarı burada taşınır (şifresizse boş kalır).
        content: canEncryptMedia ? encResult.ciphertext : '',
        type: type,
        timestamp: DateTime.now(),
        mediaUrl: url,
        // Yerel kopyada anahtar hazır: gönderen kendi medyasını beklemeden
        // görebilsin (kendi şifreli içeriğini çözemez).
        mediaKey: canEncryptMedia ? attachmentKey : null,
        isEncrypted: canEncryptMedia,
        e2eeHeader: encResult.e2eeHeader,
        mediaSource: mediaSource,
        viewOnce: viewOnce,
        voiceDurationMs: voiceDurationMs,
        fileName: fileName,
        fileSizeBytes: fileSize,
        replyToId: replyToId,
        replyToPreview: replyToPreview,
      );

      // Gönderen kendi ek anahtarını sonradan da bulabilsin.
      if (canEncryptMedia) {
        await encryptionDataSource.cachePlaintext(
            msgId, AttachmentRef(key: attachmentKey).encode());
      }

      // Optimistic: UI'da anında görünsün
      await localDataSource.cacheMessage(chatId, message);
      await remoteDataSource.sendMessage(chatId, message);
      // GİZLİLİK: önizleme yalnızca TÜR bilgisi taşır, dosya adı taşımaz.
      await remoteDataSource.updateLastMessage(chatId, _mediaPreview(type),
          senderId: message.senderId);

      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('sendMediaMessage', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getOlderMessages(
      String chatId, DateTime before) async {
    try {
      final myUid = userProvider.currentUid;
      final models = await remoteDataSource.fetchOlder(chatId, before, 50);
      final decrypted = await _decryptMessages(chatId, models, myUid);
      return Right(decrypted);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('getOlderMessages', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteForMe(
      String chatId, List<String> messageIds) async {
    try {
      final myUid = userProvider.currentUid;
      if (myUid == null) return const Left(AuthFailure());
      await remoteDataSource.deleteForMe(chatId, messageIds, myUid);
      // CİHAZDAKİ DÜZ METNİ DE SİL — bu olmadan "sil" yalnızca sunucuda
      // etki ediyor, okunabilir kopya cihazda kalıyordu.
      await _forgetLocal(messageIds);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('deleteForMe', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteForEveryone(
      String chatId, List<String> messageIds) async {
    try {
      await remoteDataSource.deleteForEveryone(chatId, messageIds);
      await _forgetLocal(messageIds);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('deleteForEveryone', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> clearChat(String chatId) async {
    try {
      // Silinecek kimlikleri ÖNCE topla: sunucu temizlendikten sonra
      // hangi düz metinlerin silineceğini öğrenmenin yolu kalmaz.
      List<String> ids = const [];
      try {
        final cached = await localDataSource.getCachedMessages(chatId);
        ids = cached.map((m) => m.id).toList();
      } catch (_) {
        // önbellek okunamadı — sunucu temizliği yine yapılır
      }

      final uid = userProvider.currentUid;
      if (uid == null) return const Left(UnexpectedFailure());
      await remoteDataSource.clearMessages(chatId, uid);

      // Yerel önbellek de boşaltılmalı; aksi halde sohbet yeniden
      // açıldığında mesajlar cihazdan geri gelir.
      try {
        await localDataSource.clearCachedMessages(chatId);
      } catch (e, s) {
        // ⚠️ Sunucu temizlendi ama cihaz temizlenmedi: kullanıcı sohbeti
        // sildiğini sanır, mesajlar yeniden açılışta CİHAZDAN geri gelir.
        reportHandled('Yerel önbellek temizlenemedi (sunucu temizlendi)', e,
            stack: s);
      }
      await _forgetLocal(ids);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('clearChat', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      await remoteDataSource.deleteMessage(chatId, messageId);
      await _forgetLocal([messageId]);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('deleteMessage', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  /// Cihazdaki çözülmüş düz metni ve bellek memo'sunu sil.
  ///
  /// ⚠️ NEDEN KRİTİK: Çözülen her mesajın düz metni güvenli depoda
  /// saklanıyor ama HİÇBİR YERDE silinmiyordu. Bu, "kaybolan mesaj" ve
  /// "herkesten sil" özelliklerini cihazda tamamen ETKİSİZ kılıyordu:
  /// sunucudan silinen mesaj, cihaza erişen biri için okunabilir kalıyordu.
  Future<void> _forgetLocal(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    for (final id in messageIds) {
      _forgetPlainMemo(id);
    }
    try {
      await encryptionDataSource.forgetPlaintexts(messageIds);
    } catch (e, s) {
      // ⚠️ C-07: silinen mesajın çözülmüş metni cihazda kalır.
      reportHandled('Düz metin kopyası silinemedi', e, stack: s);
    }
  }

  @override
  Future<Either<Failure, Unit>> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    try {
      final myUid = userProvider.currentUid;
      if (myUid == null) return const Left(AuthFailure());
      final otherUserId = _extractOtherUserId(chatId, myUid);
      final isDirect = otherUserId.isNotEmpty;

      // ── DÜZENLENEN MESAJ ARTIK ŞİFRELENİR ──
      //
      // Eski davranış iki ayrı şekilde bozuktu:
      //  1. Düzenlenen metin Firestore'a DÜZ yazılıyordu — yani mesajı
      //     düzeltmek, onu sunucuya açık göndermek demekti.
      //  2. `isE2EE` bayrağı DEĞİŞTİRİLMİYORDU. Alıcı mesajı hâlâ şifreli
      //     sanıp önbellekteki ESKİ metni gösteriyor, düzenlemeyi hiç
      //     görmüyordu; önbelleği olmayan alıcı ise düz metni çözmeye
      //     çalışıp "çözülemedi" görüyordu.
      //
      // "Ratchet düzenlemeyi desteklemez" gerekçesi yanlıştı: düzenleme
      // yalnızca YENİ bir ratchet mesajıdır. Tek gereken, alıcının onu
      // yeniden çözmesi — bunu önbellek anahtarına düzenleme damgası
      // koyarak sağlıyoruz.
      final enc = await encryptionDataSource.encrypt(
        chatId: chatId,
        otherUserId: otherUserId,
        plaintext: newText,
        memberIds: isDirect ? const [] : await _membersOf(chatId),
      );

      final editedAt = DateTime.now();
      await remoteDataSource.editMessage(
        chatId,
        messageId,
        enc.ciphertext,
        isEncrypted: enc.isEncrypted,
        editedAt: editedAt,
        e2eeHeader: enc.e2eeHeader,
      );

      // ESKİ düz metni cihazdan SİL. Düzenlemenin amacı çoğu zaman
      // yazılanı geri almaktır; eski metnin güvenli depoda kalması bunu
      // boşa çıkarırdı.
      try {
        await encryptionDataSource.forgetPlaintext(messageId);
      } catch (e, s) {
        // ⚠️ Düzenlemenin amacı çoğu zaman yazılanı GERİ ALMAKTIR;
        // eski metin cihazda kalırsa bu boşa çıkar.
        reportHandled('Düzenlenen mesajın eski düz metni silinemedi', e,
            stack: s);
      }
      _forgetPlainMemo(messageId);

      final key = _plainKey(messageId, editedAt);
      await encryptionDataSource.cachePlaintext(key, newText);
      _rememberPlain(key, newText);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('editMessage', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> markAsRead(String chatId) async {
    try {
      final myUid = userProvider.currentUid;
      if (myUid == null) return const Left(AuthFailure());

      // ROZET her zaman sifirlanir — bu KENDI sayacim, gizlilik ayarindan
      // bagimsizdir. (Onceki hata: rozet sifirlama okundu-bilgisine
      // baglanmisti; varsayilan kapali oldugu icin rozet hic silinmiyordu.)
      await remoteDataSource.resetUnread(chatId, myUid);

      // METADATA GİZLİLİĞİ: okundu bilgisi (cift tik + kimler okudu) kapaliysa
      // karsi tarafa "gordum" sinyali gonderme
      if (!privacyReader.current.sendReadReceipts) {
        return const Right(unit);
      }
      await remoteDataSource.markAsRead(chatId, myUid);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('markAsRead', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final myUid = userProvider.currentUid!;
      await remoteDataSource.setReaction(chatId, messageId, myUid, emoji);
      return const Right(unit);
    } catch (e, s) {
      reportHandled('setReaction', e, stack: s);
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> sendGifMessage({
    required String chatId,
    required String gifUrl,
    bool sticker = false,
  }) async {
    try {
      final myUid = userProvider.currentUid!;
      final username = await userProvider.currentUsername;
      final message = MessageModel(
        id: uuid.v4(),
        chatId: chatId,
        senderId: myUid,
        senderUsername: username ?? '',
        content: '',
        type: MessageContentType.gif,
        timestamp: DateTime.now(),
        status: MessageDeliveryStatus.sent,
        isEncrypted: false,
        mediaUrl: gifUrl, // Giphy URL — Storage yuklemesi gerekmez
        mediaSource: sticker ? 'sticker' : null, // #7
      );
      await localDataSource.cacheMessage(chatId, message);
      await remoteDataSource.sendMessage(chatId, message);
      await remoteDataSource.updateLastMessage(chatId, message.preview,
          senderId: myUid);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('sendGifMessage', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> sendPollMessage({
    required String chatId,
    required String question,
    required List<String> options,
  }) async {
    try {
      final myUid = userProvider.currentUid!;
      final username = await userProvider.currentUsername;
      final message = MessageModel(
        id: uuid.v4(),
        chatId: chatId,
        senderId: myUid,
        senderUsername: username ?? '',
        content: question, // onizleme/bildirim icin soru metni
        type: MessageContentType.poll,
        timestamp: DateTime.now(),
        status: MessageDeliveryStatus.sent,
        isEncrypted: false, // toplulastirma icin duz metin (bilincli odun)
        pollOptions: options,
        pollVotes: const {},
      );
      await localDataSource.cacheMessage(chatId, message);
      await remoteDataSource.sendMessage(chatId, message);
      await remoteDataSource.updateLastMessage(chatId, message.preview,
          senderId: myUid);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('sendPollMessage', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> consumeViewOnce({
    required String chatId,
    required String messageId,
    required String mediaUrl,
  }) async {
    try {
      await remoteDataSource.consumeViewOnce(chatId, messageId, mediaUrl);
      return const Right(unit);
    } catch (e, s) {
      reportHandled('consumeViewOnce', e, stack: s);
      return const Left(ServerFailure());
    }
  }

  /// Direkt chat id formatı "uid1_uid2" → karşı tarafı çıkar.
  /// Grup/kanalda E2EE olmadığı için bu sadece direkt sohbetlerde anlamlı.
  String _extractOtherUserId(String chatId, String myUid) {
    final parts = chatId.split('_');
    if (parts.length == 2) {
      return parts.firstWhere((id) => id != myUid, orElse: () => '');
    }
    return ''; // Grup/kanal — E2EE atlanır
  }
}
