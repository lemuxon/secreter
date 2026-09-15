import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'key_management_service.dart';
import 'x3dh_service.dart';
import 'double_ratchet_service.dart';
import '../core/security/secure_store.dart';

/// Bir sohbet için E2EE oturumunu yönetir.
///
/// Oturum durumu (zincir anahtarları, sayaçlar, atlanan mesaj anahtarları)
/// cihazda secure storage'da saklanır — sunucu hiçbir zaman görmez.
///
/// ── BU SÜRÜMDE DÜZELTİLEN ÜÇ ÖNEMLİ SORUN ──
///
/// 1. AYNI ANAHTARLA İKİ YÖN. Eski kod gönderme ve alma zincirini AYNI
///    ortak sırla başlatıyordu; sonuç olarak Alice'in N'inci mesajı ile
///    Bob'un N'inci mesajı ÖZDEŞ mesaj anahtarını kullanıyordu. Artık
///    ortak sırdan yön-bazlı iki ayrı zincir türetilir (HKDF info ayrımı).
///
/// 2. DÜZ METİN SONSUZA KADAR KALIYORDU. Çözülen/gönderilen her mesajın
///    düz metni `e2ee_sent_*` altında saklanıyor ve HİÇBİR yerde
///    silinmiyordu: kaybolan mesajlar, "herkesten sil" ve hesap silme
///    cihazda hiçbir şey temizlemiyordu. Artık tam bir yaşam döngüsü var
///    ([forgetPlaintext], [forgetPlaintexts], [wipeAllPlaintexts]).
///
/// 3. HESAPLAR ARASI KARIŞMA. Anahtarlar yalnızca `chatId` ile
///    isimlendiriliyordu; çoklu hesapta aynı sohbet kimliği farklı
///    hesaplarda çakışıyordu. Artık her anahtar aktif uid ile kapsamlanır.
class E2EESessionService {
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Aktif hesap kimliği — anahtar kapsamı için. Hesap değişiminde
  /// [setActiveAccount] ile güncellenir.
  static String _accountScope = '_';

  static void setActiveAccount(String? uid) {
    final next = (uid == null || uid.isEmpty) ? '_' : uid;
    if (next == _accountScope) return;
    _accountScope = next;
    // Bellekteki düz metinler ÖNCEKİ hesaba aitti; taşınmasın.
    _plainMem.clear();
    _plainWarmed = false; // yeni hesabın önbelleği yeniden ısıtılmalı
  }

  static String _sessionKey(String chatId) =>
      'e2ee_session_${_accountScope}_$chatId';
  static String _sentKey(String messageId) =>
      'e2ee_plain_${_accountScope}_$messageId';
  static String get _plainPrefix => 'e2ee_plain_${_accountScope}_';

  // ─────────────────────────────────────────
  // OTURUM DURUMU
  // ─────────────────────────────────────────

  static Future<SessionState?> _loadSession(String chatId) async {
    final json = await SecureStore.read(_sessionKey(chatId));
    if (json == null) return null;
    try {
      return SessionState.fromJson(
          Map<String, dynamic>.from(jsonDecode(json) as Map));
    } catch (e) {
      // Bozuk oturum kaydı: sessizce null dönmek yerine logla. Oturum
      // sıfırlanacak ve karşı taraf yeni başlık gönderdiğinde kurulacak.
      debugPrint('E2EE oturum durumu okunamadı ($chatId): $e');
      return null;
    }
  }

  static Future<void> _saveSession(String chatId, SessionState state) async {
    await SecureStore.writeOrThrow(
      key: _sessionKey(chatId),
      value: jsonEncode(state.toJson()),
    );
  }

  static Future<bool> hasSession(String chatId) async =>
      await SecureStore.read(_sessionKey(chatId)) != null;

  /// Ortak sırdan yön-bazlı iki zincir türet.
  ///
  /// `initiator` true ise: gönderme = A→B zinciri, alma = B→A zinciri.
  /// false ise tersi. Böylece iki yön ASLA aynı mesaj anahtarını üretmez.
  static Future<(List<int>, List<int>)> _deriveChains(
      List<int> sharedSecret, bool initiator) async {
    Future<List<int>> chain(String label) async {
      final k = await _hkdf.deriveKey(
        secretKey: SecretKey(sharedSecret),
        nonce: List<int>.filled(32, 0),
        info: utf8.encode('SECRETER-chain-$label'),
      );
      return k.extractBytes();
    }

    final a2b = await chain('a2b');
    final b2a = await chain('b2a');
    return initiator ? (a2b, b2a) : (b2a, a2b);
  }

  // ─────────────────────────────────────────
  // OTURUM KURMA
  // ─────────────────────────────────────────

  /// BAŞLATAN taraf: karşı tarafın paketiyle oturum kur.
  /// İlk mesajla gönderilecek X3DH başlığını döndürür.
  /// Karşı tarafın paketi yoksa null döner.
  static Future<E2EEInitHeader?> initiateSession({
    required String chatId,
    required String otherUserId,
  }) async {
    final bundle = await KeyManagementService.fetchPreKeyBundle(otherUserId);
    if (bundle == null) return null;

    // X3DHException burada YUTULMAZ: imza doğrulanamazsa (araya girme
    // olasılığı) veya anahtar bozuksa çağıran taraf bunu kullanıcıya
    // göstermeli, sessizce şifresiz göndermemelidir.
    final x3dh = await X3DHService.initiateKeyAgreement(bundle);

    // ── SÜRÜM SEÇİMİ ──
    // v3 yalnızca karşı taraf da destekliyorsa kurulur. Desteklemeyen
    // bir istemciye v3 paket göndermek, onun zincir türetmesiyle
    // uyuşmadığı için o sohbeti TAMAMEN kırardı.
    final useV3 = bundle.supportsDhRatchet && x3dh.peerSignedPreKey != null;

    // Başlık ÖNCE kurulur: oturuma iliştirilip, karşı taraf onaylayana
    // kadar her mesajla yeniden gönderilecek (§4be).
    final header = E2EEInitHeader(
      identityKey: await KeyManagementService.getMyIdentityPublicKey(),
      ephemeralKey: x3dh.ephemeralPublicKey,
      usedOneTimePreKeyId: x3dh.usedOneTimePreKeyId,
      usedSignedPreKeyId: x3dh.usedSignedPreKeyId,
      ratchetVersion: useV3 ? DoubleRatchetService.currentVersion : 2,
    );
    final headerMap = header.toMap();

    if (useV3) {
      // BAŞLATAN taraf bootstrap'ı (Signal):
      //   RK  = X3DH ortak sırrı
      //   DHr = karşı tarafın imzalı ön-anahtarı (onda özel kısmı var)
      //   DHs = yeni çift → (RK, CKs) = KDF_RK(RK, DH(DHs, DHr))
      // Alma zinciri HENÜZ YOK: karşı taraf kendi DH anahtarıyla cevap
      // verdiğinde ilk DH adımı atılıp kurulacak.
      final (dhsPriv, dhsPub) = await DoubleRatchetService.newDhKeyPair();
      final dhOut =
          await DoubleRatchetService.dh(dhsPriv, x3dh.peerSignedPreKey!);
      final (rk, cks) =
          await DoubleRatchetService.kdfRoot(x3dh.sharedSecret, dhOut);

      await _saveSession(
        chatId,
        SessionState(
          sendingChainKey: cks,
          receivingChainKey: const [],
          sendCounter: 0,
          recvCounter: 0,
          skipped: const {},
          peerIdentityKey: x3dh.peerIdentityKey,
          verified: bundle.isVerifiable,
          rootKey: rk,
          dhsPriv: dhsPriv,
          dhsPub: dhsPub,
          dhrPub: x3dh.peerSignedPreKey,
          pendingHeader: headerMap,
        ),
      );
    } else {
      final (sending, receiving) = await _deriveChains(x3dh.sharedSecret, true);
      await _saveSession(
        chatId,
        SessionState(
          sendingChainKey: sending,
          receivingChainKey: receiving,
          sendCounter: 0,
          recvCounter: 0,
          skipped: const {},
          peerIdentityKey: x3dh.peerIdentityKey,
          verified: bundle.isVerifiable,
          pendingHeader: headerMap,
        ),
      );
    }

    return header;
  }

  /// Oturum ONAYLANMADIYSA gönderilecek başlık; onaylandıysa null.
  ///
  /// Çağıran katman bunu her giden mesaja ekler. Karşı taraf tıkanmışsa
  /// gelen başlıkla kendini onarır (`decrypt` içindeki §4av kurtarması
  /// kimlik denetimine takılmadan oturumu sıfırlayıp yeniden kurar).
  static Future<Map<String, dynamic>?> pendingInitHeader(String chatId) async {
    final s = await _loadSession(chatId);
    if (s == null || s.onaylandi) return null;
    return s.pendingHeader;
  }

  /// CEVAPLAYAN taraf: gelen ilk mesajın başlığıyla oturum kur.
  static Future<void> establishFromHeader({
    required String chatId,
    required E2EEInitHeader header,
  }) async {
    final sharedSecret = await X3DHService.respondToKeyAgreement(
      aliceIdentityKeyB64: header.identityKey,
      aliceEphemeralKeyB64: header.ephemeralKey,
      usedOneTimePreKeyId: header.usedOneTimePreKeyId,
      usedSignedPreKeyId: header.usedSignedPreKeyId,
    );

    if (header.ratchetVersion >= 3) {
      // CEVAPLAYAN taraf bootstrap'ı:
      //   RK  = X3DH ortak sırrı
      //   DHs = karşı tarafın kullandığı İMZALI ÖN-ANAHTAR çiftimiz
      //   DHr = henüz yok; ilk mesajın başlığından gelecek ve o anda
      //         DH adımı atılıp alma zinciri kurulacak.
      //
      // ⚠️ Burada GEÇERLİ SPK değil, gönderenin GERÇEKTEN kullandığı SPK
      // alınmalıdır — bu arada ön-anahtarlarımız tazelenmiş olabilir.
      final spk = await KeyManagementService.getSignedPreKeyPairById(
          header.usedSignedPreKeyId);
      final priv = await spk.extractPrivateKeyBytes();
      final pub = await spk.extractPublicKey();

      await _saveSession(
        chatId,
        SessionState(
          sendingChainKey: const [],
          receivingChainKey: const [],
          sendCounter: 0,
          recvCounter: 0,
          skipped: const {},
          peerIdentityKey: header.identityKey,
          peerEphemeralKey: header.ephemeralKey,
          verified: false,
          rootKey: sharedSecret,
          dhsPriv: base64.encode(priv),
          dhsPub: base64.encode(pub.bytes),
        ),
      );
      return;
    }

    final (sending, receiving) = await _deriveChains(sharedSecret, false);
    await _saveSession(
      chatId,
      SessionState(
        sendingChainKey: sending,
        receivingChainKey: receiving,
        sendCounter: 0,
        recvCounter: 0,
        skipped: const {},
        peerIdentityKey: header.identityKey,
        peerEphemeralKey: header.ephemeralKey,
        verified: false,
      ),
    );
  }

  // ─────────────────────────────────────────
  // ŞİFRELE / ÇÖZ
  // ─────────────────────────────────────────

  static Future<String?> encryptMessage({
    required String chatId,
    required String plaintext,
  }) async {
    final state = await _loadSession(chatId);
    if (state == null) return null;

    // ── v3: DH RATCHET ──
    if (state.isDhRatchet) {
      // Gönderme zinciri henüz yoksa (cevaplayan taraf, karşı taraftan
      // hiç mesaj almamış) şifreleyemeyiz. Bu normal bir durumdur:
      // zincir, ilk gelen mesajla atılan DH adımında kurulur.
      if (state.sendingChainKey.isEmpty) {
        debugPrint('E2EE: gönderme zinciri henüz kurulmadı ($chatId)');
        return null;
      }

      final result = await DoubleRatchetService.encryptV3(
        sendChainKey: state.sendingChainKey,
        dhsPub: state.dhsPub!,
        sendCounter: state.sendCounter,
        prevSendCount: state.prevSendCount,
        plaintext: plaintext,
      );

      await _saveSession(
        chatId,
        state.copyWith(
          sendingChainKey: result.newSendChainKey,
          sendCounter: result.newSendCounter,
        ),
      );
      return result.ciphertext;
    }

    // ── v2: yalnızca simetrik zincir (eski oturumlar) ──
    final result = await DoubleRatchetService.encrypt(
      chainKey: state.sendingChainKey,
      plaintext: plaintext,
      messageNumber: state.sendCounter,
    );

    await _saveSession(
      chatId,
      state.copyWith(
        sendingChainKey: result.newChainKey,
        sendCounter: state.sendCounter + 1,
      ),
    );
    return result.ciphertext;
  }

  /// Gelen mesajı çöz.
  ///
  /// ⚠️ [messageId] VERİLİRSE düz metin, ratchet durumu kalıcılaşmadan
  /// ÖNCE önbelleğe yazılır. Sırası tersine dönerse şu pencere açılır:
  ///
  ///   ratchet ilerledi + kaydedildi → **uygulama ölür** → düz metin
  ///   hiç yazılmadı
  ///
  /// Açılışta mesaj yeniden çözülmeye çalışılır ama zincir o mesajın
  /// ötesine geçmiştir ve anahtar `skipped`e de girmemiştir (atlanmadı,
  /// TÜKETİLDİ). Sonuç: o mesaj **kalıcı olarak** "çözülemedi" olur.
  ///
  /// Ters sırada risk yok: düz metin yazılıp ratchet kaydedilmezse mesaj
  /// önbellekten okunur (çözme yolunun ilk adımı) ve zincir olduğu yerde
  /// kalır.
  static Future<String?> decryptMessage({
    required String chatId,
    required String ciphertext,
    String? messageId,
  }) async {
    final state = await _loadSession(chatId);
    if (state == null) return null;

    // ── v3: DH RATCHET ──
    //
    // Sürüm PAKETTEN okunur, oturumdan değil: oturum v3 kurulmuş olsa
    // bile karşı taraf hâlâ yolda olan bir v2 paketi göndermiş olabilir
    // (ya da tersi). Paketi kendi sürümüyle çözmek tek doğru davranış.
    if (state.isDhRatchet && DoubleRatchetService.isV3Packet(ciphertext)) {
      final result = await DoubleRatchetService.decryptV3(
        rootKey: state.rootKey!,
        dhsPriv: state.dhsPriv!,
        dhsPub: state.dhsPub!,
        dhrPub: state.dhrPub,
        sendChainKey: state.sendingChainKey,
        recvChainKey: state.receivingChainKey,
        sendCounter: state.sendCounter,
        recvCounter: state.recvCounter,
        prevSendCount: state.prevSendCount,
        skipped: state.skipped,
        encryptedPacket: ciphertext,
      );
      if (result == null) return null;

      // ⚠️ RATCHET KAYDINDAN ÖNCE (bkz. imzadaki açıklama).
      if (messageId != null) {
        await cachePlaintext(messageId, result.plaintext);
      }

      await _saveSession(
        chatId,
        state.copyWith(
          rootKey: result.rootKey,
          dhsPriv: result.dhsPriv,
          dhsPub: result.dhsPub,
          dhrPub: result.dhrPub,
          sendingChainKey: result.sendChainKey,
          receivingChainKey: result.recvChainKey,
          sendCounter: result.sendCounter,
          recvCounter: result.recvCounter,
          prevSendCount: result.prevSendCount,
          skipped: result.skipped,
          // ── OTURUM ONAYLANDI (§4be) ──
          // Karşı taraftan bir mesajı çözebildiysek iki taraf aynı
          // zincirdedir; başlığı artık her mesaja eklemeye gerek yok.
          onaylandi: true,
        ),
      );
      return result.plaintext;
    }

    // ── v2: yalnızca simetrik zincir ──
    final result = await DoubleRatchetService.decrypt(
      chainKey: state.receivingChainKey,
      chainIndex: state.recvCounter,
      skipped: state.skipped,
      encryptedPacket: ciphertext,
    );
    if (result == null) return null;

    // ⚠️ RATCHET KAYDINDAN ÖNCE (bkz. imzadaki açıklama).
    if (messageId != null) {
      await cachePlaintext(messageId, result.plaintext);
    }

    await _saveSession(
      chatId,
      state.copyWith(
        receivingChainKey: result.newChainKey,
        recvCounter: result.newChainIndex,
        skipped: result.skipped,
        onaylandi: true, // §4be
      ),
    );
    return result.plaintext;
  }

  static Future<void> resetSession(String chatId) async {
    await SecureStore.delete(_sessionKey(chatId));
  }

  /// Karşı tarafın kimlik anahtarı — güvenlik numarası gösterimi için.
  static Future<String?> peerIdentityKey(String chatId) async =>
      (await _loadSession(chatId))?.peerIdentityKey;

  /// İnsan tarafından karşılaştırılabilir güvenlik numarası.
  /// İki kullanıcı bu numarayı yüz yüze karşılaştırırsa MITM'i tespit eder.
  static Future<String?> safetyNumber(String chatId) async {
    final peer = (await _loadSession(chatId))?.peerIdentityKey;
    if (peer == null || peer.isEmpty) return null;
    return _numberFor(peer);
  }

  /// Güvenlik numarası ekranının ihtiyaç duyduğu her şeyi TEK okumada verir.
  /// Oturum yoksa boş bir bilgi döner (ekran "henüz şifreli oturum yok"
  /// diyebilsin diye null DEĞİL).
  static Future<SafetyInfo> safetyInfo(String chatId) async {
    final state = await _loadSession(chatId);
    final peer = state?.peerIdentityKey;
    return SafetyInfo(
      number: (peer == null || peer.isEmpty) ? null : await _numberFor(peer),
      peerIdentityKey: peer,
      userVerified: state?.userVerified ?? false,
      signatureVerified: state?.verified ?? false,
      previousIdentityKey: state?.changedFrom,
    );
  }

  static Future<String?> _numberFor(String peer) async {
    final mine = await KeyManagementService.getMyIdentityPublicKey();
    if (mine.isEmpty) return null;

    // Sıralı birleştirme: iki tarafta AYNI sonucu üretmesi şart.
    final pair = [mine, peer]..sort();
    final digest = await Sha256().hash(utf8.encode(pair.join('|')));
    final digits = digest.bytes
        .take(15)
        .map((b) => (b % 100).toString().padLeft(2, '0'))
        .join();
    // 5'li gruplar: 12345 67890 ...
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i += 5) {
      if (i > 0) buf.write(' ');
      buf.write(digits.substring(i, (i + 5).clamp(0, digits.length)));
    }
    return buf.toString();
  }

  /// Kullanıcı numarayı karşılaştırdı ve sonucu işaretledi.
  /// Oturum yoksa false döner — işaretlenecek bir şey yoktur.
  static Future<bool> setUserVerified(String chatId, bool value) async {
    final state = await _loadSession(chatId);
    if (state == null) return false;
    await _saveSession(chatId, state.copyWith(userVerified: value));
    return true;
  }

  /// "Kimlik anahtarı değişti" uyarısını kullanıcı gördü → bandı kaldır.
  /// Doğrulama durumu GERİ GELMEZ; kullanıcı numarayı yeniden
  /// karşılaştırmadan sohbet doğrulanmış sayılmamalıdır.
  static Future<void> acknowledgeIdentityChange(String chatId) async {
    final state = await _loadSession(chatId);
    if (state == null || state.changedFrom == null) return;
    await _saveSession(chatId, state.clearChangedFrom());
  }

  /// Gelen X3DH başlığına göre oturumu HAZIRLAR ve karşı tarafın kimlik
  /// anahtarının değişip değişmediğini döndürür.
  ///
  /// Neden yalnızca "oturum var mı" kontrolü YETMEZ: karşı taraf
  /// uygulamayı yeniden kurduğunda yeni bir kimlik anahtarıyla yeni bir
  /// başlık gönderir. Eski davranışta oturum güncellenmediği için o
  /// sohbetteki sonraki TÜM mesajlar sessizce çözülemez hâle geliyordu.
  ///
  /// Yeniden kurulum ile ARAYA GİRME birbirinden ayırt edilemez. Bu
  /// yüzden oturum yeni anahtarla kurulur, kullanıcı doğrulaması DÜŞER
  /// ve değişim kullanıcıya gösterilmek üzere kaydedilir.
  static Future<bool> ensureSessionFromHeader({
    required String chatId,
    required E2EEInitHeader header,
  }) async {
    final existing = await _loadSession(chatId);
    if (existing == null) {
      await establishFromHeader(chatId: chatId, header: header);
      return false;
    }

    final pinned = existing.peerIdentityKey;

    // 🐞 YENİDEN EL SIKIŞMA DA YAKALANMALI (§4ax).
    //
    // Eskiden yalnızca KİMLİK değişimi yenilemeyi tetikliyordu. Ama karşı
    // taraf oturumu YENİDEN KURDUĞUNDA (kendi tarafı bozulduğu için
    // sıfırlayıp yeni bir X3DH başlattığında) kimliği AYNI kalır —
    // değişen EFEMERAL anahtardır. Ayırt edilemediği için yeniden el
    // sıkışma sessizce yok sayılıyor, biz eski (bozuk) zinciri kullanmaya
    // devam ediyor ve sohbet kalıcı olarak ölü kalıyordu.
    //
    // ÖLÇÜLDÜ: kimliğini KORUYAN hesap (eski anahtarları devralan) mesaj
    // alamıyordu; kimliği DEĞİŞEN hesap sorunsuz çalışıyordu — çünkü
    // yalnızca ikincisi bu denetimden geçiyordu.
    final eskiEfemeral = existing.peerEphemeralKey;
    final yenidenElSikisma = eskiEfemeral != null &&
        eskiEfemeral.isNotEmpty &&
        eskiEfemeral != header.ephemeralKey;

    // Aynı anahtar VE aynı efemeral → oturum zaten kurulu. Yeniden kurmak
    // zinciri sıfırlar ve arada kalan mesajları çözülemez yapardı.
    if (!yenidenElSikisma &&
        (pinned == null || pinned.isEmpty || pinned == header.identityKey)) {
      return false;
    }

    await establishFromHeader(chatId: chatId, header: header);
    final fresh = await _loadSession(chatId);
    if (fresh != null) {
      await _saveSession(chatId, fresh.copyWith(changedFrom: pinned));
    }
    return true;
  }

  // ─────────────────────────────────────────
  // DÜZ METİN ÖNBELLEĞİ (yaşam döngüsü YÖNETİLİR)
  //
  // Ratchet tek yönlüdür: gönderen kendi şifreli mesajını çözemez, ve bir
  // şifreli metin yalnızca bir kez çözülebilir. Bu yüzden okunabilir metin
  // cihazda tutulmak ZORUNDA. Kritik olan, mesaj silindiğinde bu kopyanın
  // DA silinmesidir — aksi halde "kaybolan mesaj" özelliği bir yanılsamadır.
  // ─────────────────────────────────────────

  static final Map<String, String> _plainMem = {};
  static const int _plainMemCap = 2000;

  static void _memPut(String id, String plain) {
    if (_plainMem.length >= _plainMemCap) {
      final drop = _plainMem.keys.take(_plainMemCap ~/ 4).toList();
      for (final k in drop) {
        _plainMem.remove(k);
      }
    }
    _plainMem[id] = plain;
  }

  /// Bu hesabın düz metin önbelleğini TEK çağrıyla belleğe ısıt (§4bi).
  ///
  /// Sohbet açılışında her mesaj için ayrı `read()` yapılıyordu; Android'de
  /// her biri bir platform kanalı çağrısı olduğu için sohbet saniyelerce
  /// "yükleniyor" kalıyor, sonra mesajlar geç dolduğu için SİLİNMİŞ gibi
  /// görünüyordu. Isınma bir kez yapılır; sonrası bellekten döner.
  static bool _plainWarmed = false;

  static Future<void> warmPlaintextCache() async {
    if (_plainWarmed) return;
    _plainWarmed = true; // yarışta iki kez çalışmasın
    try {
      final hepsi = await SecureStore.readAll();
      final onek = _plainPrefix;
      for (final e in hepsi.entries) {
        if (e.key.startsWith(onek)) {
          _memPut(e.key.substring(onek.length), e.value);
        }
      }
    } catch (_) {
      // Isınma başarısızsa tek tek okumaya geri düşülür; veri kaybı yok.
      _plainWarmed = false;
    }
  }

  static Future<void> cachePlaintext(String messageId, String plaintext) async {
    _memPut(messageId, plaintext);
    await SecureStore.write(_sentKey(messageId), plaintext);
  }

  static Future<String?> getPlaintext(String messageId) async {
    final mem = _plainMem[messageId];
    if (mem != null) return mem;
    final v = await SecureStore.read(_sentKey(messageId));
    if (v != null) _memPut(messageId, v);
    return v;
  }

  /// Tek bir mesajın düz metnini cihazdan sil.
  ///
  /// ⚠️ DÜZENLEME SÜRÜMLERİ DE SİLİNİR. Düzenlenen mesajın metni
  /// `<mesajId>#<zaman>` anahtarıyla saklanır; yalnızca ham kimliği
  /// silmek, "kaybolan mesaj" ve "herkesten sil" işlemlerinden sonra
  /// düzenlenmiş metnin cihazda OKUNABİLİR kalmasına yol açardı —
  /// C-07 ile birebir aynı sınıf hata.
  static Future<void> forgetPlaintext(String messageId) async {
    final revPrefix = '$messageId#';
    _plainMem.remove(messageId);
    _plainMem.removeWhere((k, _) => k.startsWith(revPrefix));
    await SecureStore.delete(_sentKey(messageId));
    await SecureStore.deleteByPrefix(_sentKey(revPrefix));
  }

  /// Toplu silme (herkesten sil / bende sil / süresi doldu).
  static Future<void> forgetPlaintexts(Iterable<String> messageIds) async {
    for (final id in messageIds) {
      await forgetPlaintext(id);
    }
  }

  /// Bu hesabın TÜM düz metinlerini sil (sohbet temizleme / çıkış).
  static Future<void> wipeAllPlaintexts() async {
    _plainMem.clear();
    await SecureStore.deleteByPrefix(_plainPrefix);
  }

  /// Bu hesabın tüm oturumlarını ve düz metinlerini sil (hesap silme).
  static Future<void> wipeAccount() async {
    _plainMem.clear();
    await SecureStore.deleteByPrefix('e2ee_plain_${_accountScope}_');
    await SecureStore.deleteByPrefix('e2ee_session_${_accountScope}_');
  }

  /// Yalnızca bellekteki kopyaları temizle (uygulama kilitlenince).
  static void clearMemoryCache() => _plainMem.clear();
}

/// Oturum durumu (cihazda saklanır)
class SessionState {
  final List<int> sendingChainKey;
  final List<int> receivingChainKey;
  final int sendCounter;
  final int recvCounter;

  /// Atlanan mesaj anahtarları: "mesajNo" -> base64 anahtar.
  /// Sırasız/geç gelen mesajların çözülebilmesi için gerekir.
  final Map<String, String> skipped;

  /// Karşı tarafın kimlik anahtarı (TOFU sabitlemesi + güvenlik numarası).
  final String? peerIdentityKey;

  /// İmzalı ön-anahtar doğrulanabildi mi?
  final bool verified;

  /// Kullanıcı güvenlik numarasını karşılaştırıp ONAYLADI mı?
  ///
  /// [verified] ile KARIŞTIRILMAMALIDIR: o yalnızca sunucudan gelen
  /// imzalı ön-anahtarın imzasının tutarlı olduğunu söyler. Araya giren
  /// taraf kendi anahtarlarıyla kendi geçerli imzasını üretebileceği
  /// için imza tek başına MITM'e karşı bir şey ifade etmez. Asıl
  /// güvence, İNSANIN başka bir kanaldan yaptığı bu karşılaştırmadır.
  final bool userVerified;

  /// Karşı tarafın ÖNCEKİ kimlik anahtarı — yalnızca anahtar değiştiyse
  /// doludur. Kullanıcı uyarıyı gördüğünde temizlenir.
  final String? changedFrom;

  /// Bu oturumun kurulduğu X3DH EFEMERAL anahtarı (§4ax).
  ///
  /// 🐞 NEDEN GEREKLİ: `ensureSessionFromHeader` oturumu yalnızca karşı
  /// tarafın KİMLİK anahtarı değişince yeniliyordu. Ama karşı taraf
  /// oturumu YENİDEN KURDUĞUNDA (kendi oturumu bozulduğu için sıfırlayıp
  /// yeni bir X3DH başlattığında) kimliği AYNI kalır — yalnızca efemeral
  /// anahtar değişir. Bu ayırt edilemediği için yeniden el sıkışma
  /// SESSİZCE YOK SAYILIYOR ve sohbet kalıcı olarak ölü kalıyordu.
  ///
  /// Eski oturumlarda null'dur; o durumda yenileme yapılmaz (davranış
  /// değişmez), ilk yeniden el sıkışmada dolar.
  final String? peerEphemeralKey;

  // ── DH RATCHET (v3) ──
  //
  // Bu alanlar YALNIZCA v3 oturumlarda doludur. Sahadaki eski
  // oturumlarda kök anahtar YOKTUR ve sonradan türetilemez (X3DH anında
  // üretilir), bu yüzden onlar v2 yolunda çalışmaya devam eder.
  // [isDhRatchet] bu ayrımı yapan TEK ölçüttür.

  /// Kök anahtar (RK). Her DH adımında yenilenir.
  final List<int>? rootKey;

  /// Kendi güncel DH çiftimiz (base64).
  final String? dhsPriv;
  final String? dhsPub;

  /// Karşı tarafın en son gördüğümüz DH açık anahtarı.
  final String? dhrPub;

  /// ÖNCEKİ gönderme zincirinde kaç mesaj gönderdik (PN).
  /// Karşı taraf, zincir değişiminde kalan anahtarları saklamak için
  /// bu sayıya ihtiyaç duyar; yoksa yolda olan mesajlar kaybolur.
  final int prevSendCount;

  SessionState({
    required this.sendingChainKey,
    required this.receivingChainKey,
    required this.sendCounter,
    required this.recvCounter,
    required this.skipped,
    this.peerIdentityKey,
    this.verified = false,
    this.userVerified = false,
    this.changedFrom,
    this.peerEphemeralKey,
    this.rootKey,
    this.dhsPriv,
    this.dhsPub,
    this.dhrPub,
    this.prevSendCount = 0,
    this.pendingHeader,
    this.onaylandi = false,
  });

  /// Bu oturumu kurarken GÖNDERDİĞİMİZ X3DH başlığı.
  ///
  /// Oturum karşı tarafça ONAYLANANA kadar her giden mesaja yeniden
  /// eklenir (§4be). Sebebi: başlık eskiden YALNIZCA ilk mesaja
  /// ekleniyordu; iki taraf da aynı anda oturum başlatırsa ("çapraz el
  /// sıkışma") her biri kendi oturumunu kurar, diğerininkini kimlik
  /// değişmediği için yok sayar ve ortada onarılacak malzeme kalmaz.
  /// Sohbet tek yönlü donar.
  final Map<String, dynamic>? pendingHeader;

  /// Karşı taraftan EN AZ BİR mesajı başarıyla çözdük mü?
  ///
  /// Onay budur: çözebildiysek iki taraf aynı zincirdedir, başlığı
  /// tekrar göndermeye gerek kalmaz.
  final bool onaylandi;

  /// Bu oturum DH ratchet (v3) kullanıyor mu?
  bool get isDhRatchet =>
      rootKey != null &&
      rootKey!.isNotEmpty &&
      dhsPriv != null &&
      dhsPub != null;

  Map<String, dynamic> toJson() => {
        'sck': base64.encode(sendingChainKey),
        'rck': base64.encode(receivingChainKey),
        'sc': sendCounter,
        'rc': recvCounter,
        'skp': skipped,
        'pik': peerIdentityKey,
        'ver': verified,
        'uv': userVerified,
        'cf': changedFrom,
        if (peerEphemeralKey != null) 'pek': peerEphemeralKey,
        if (rootKey != null) 'rk': base64.encode(rootKey!),
        if (dhsPriv != null) 'ds': dhsPriv,
        if (dhsPub != null) 'dp': dhsPub,
        if (dhrPub != null) 'dr': dhrPub,
        'pn': prevSendCount,
        if (pendingHeader != null) 'ph': pendingHeader,
        'ok': onaylandi,
      };

  factory SessionState.fromJson(Map<String, dynamic> json) => SessionState(
        sendingChainKey: base64.decode(json['sck'] as String),
        receivingChainKey: base64.decode(json['rck'] as String),
        sendCounter: (json['sc'] as num?)?.toInt() ?? 0,
        recvCounter: (json['rc'] as num?)?.toInt() ?? 0,
        skipped: (json['skp'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            const {},
        peerIdentityKey: json['pik'] as String?,
        verified: json['ver'] == true,
        userVerified: json['uv'] == true,
        changedFrom: json['cf'] as String?,
        peerEphemeralKey: json['pek'] as String?,
        pendingHeader: (json['ph'] as Map?)?.cast<String, dynamic>(),
        onaylandi: json['ok'] == true,
        rootKey:
            json['rk'] is String ? base64.decode(json['rk'] as String) : null,
        dhsPriv: json['ds'] as String?,
        dhsPub: json['dp'] as String?,
        dhrPub: json['dr'] as String?,
        prevSendCount: (json['pn'] as num?)?.toInt() ?? 0,
      );

  SessionState copyWith({
    List<int>? sendingChainKey,
    List<int>? receivingChainKey,
    int? sendCounter,
    int? recvCounter,
    Map<String, String>? skipped,
    String? peerIdentityKey,
    bool? verified,
    bool? userVerified,
    String? changedFrom,
    String? peerEphemeralKey,
    List<int>? rootKey,
    String? dhsPriv,
    String? dhsPub,
    String? dhrPub,
    int? prevSendCount,
    Map<String, dynamic>? pendingHeader,
    bool? onaylandi,
  }) =>
      SessionState(
        sendingChainKey: sendingChainKey ?? this.sendingChainKey,
        receivingChainKey: receivingChainKey ?? this.receivingChainKey,
        sendCounter: sendCounter ?? this.sendCounter,
        recvCounter: recvCounter ?? this.recvCounter,
        skipped: skipped ?? this.skipped,
        peerIdentityKey: peerIdentityKey ?? this.peerIdentityKey,
        verified: verified ?? this.verified,
        userVerified: userVerified ?? this.userVerified,
        changedFrom: changedFrom ?? this.changedFrom,
        peerEphemeralKey: peerEphemeralKey ?? this.peerEphemeralKey,
        rootKey: rootKey ?? this.rootKey,
        dhsPriv: dhsPriv ?? this.dhsPriv,
        dhsPub: dhsPub ?? this.dhsPub,
        dhrPub: dhrPub ?? this.dhrPub,
        prevSendCount: prevSendCount ?? this.prevSendCount,
        pendingHeader: pendingHeader ?? this.pendingHeader,
        onaylandi: onaylandi ?? this.onaylandi,
      );

  /// [copyWith] null ile alan TEMİZLEYEMEZ (null "değiştirme" demek).
  /// Uyarıyı kapatmak için ayrı bir yol gerekiyor.
  SessionState clearChangedFrom() => SessionState(
        sendingChainKey: sendingChainKey,
        receivingChainKey: receivingChainKey,
        sendCounter: sendCounter,
        recvCounter: recvCounter,
        skipped: skipped,
        peerIdentityKey: peerIdentityKey,
        verified: verified,
        userVerified: userVerified,
        // DH durumunu TAŞI: düşürmek oturumu v2'ye çevirir ve sohbeti
        // çözülemez hâle getirirdi.
        rootKey: rootKey,
        dhsPriv: dhsPriv,
        dhsPub: dhsPub,
        dhrPub: dhrPub,
        prevSendCount: prevSendCount,
      );
}

/// Güvenlik numarası ekranının tek seferde ihtiyaç duyduğu durum.
class SafetyInfo {
  /// 5'li gruplara ayrılmış numara. Şifreli oturum yoksa null.
  final String? number;

  /// Karşı tarafın sabitlenmiş (pinned) kimlik anahtarı.
  final String? peerIdentityKey;

  /// Kullanıcı numarayı karşılaştırıp onayladı mı?
  final bool userVerified;

  /// İmzalı ön-anahtarın imzası doğrulanabildi mi? (Tek başına MITM
  /// güvencesi DEĞİLDİR — bkz. [SessionState.userVerified].)
  final bool signatureVerified;

  /// Doluysa karşı tarafın kimlik anahtarı DEĞİŞMİŞ demektir.
  final String? previousIdentityKey;

  const SafetyInfo({
    this.number,
    this.peerIdentityKey,
    this.userVerified = false,
    this.signatureVerified = false,
    this.previousIdentityKey,
  });

  /// Şifreli oturum kurulmuş mu? (Kurulmadan numara gösterilemez.)
  bool get hasSession => number != null;

  /// Kullanıcıya uyarı bandı gösterilmeli mi?
  bool get identityChanged => previousIdentityKey != null;
}

/// İlk mesajla gönderilen X3DH başlığı
class E2EEInitHeader {
  final String identityKey;
  final String ephemeralKey;
  final String? usedOneTimePreKeyId;

  /// Gönderenin HANGİ imzalı ön-anahtarımızı kullandığı. Bu alan
  /// olmadan, biz ön-anahtarlarımızı tazelemişsek gelen ilk mesajı
  /// yanlış anahtarla karşılar ve sohbeti sessizce kırardık.
  /// Eski istemcilerin başlıklarında bulunmaz (null).
  final String? usedSignedPreKeyId;

  /// Bu oturumun ratchet sürümü. Gönderen, karşı tarafın anahtar
  /// paketindeki `ratchetVersion`a bakarak karar verir; cevaplayan taraf
  /// oturumu AYNI sürümle kurmak zorundadır. Eski başlıklarda yoktur (2).
  final int ratchetVersion;

  E2EEInitHeader({
    required this.identityKey,
    required this.ephemeralKey,
    this.usedOneTimePreKeyId,
    this.usedSignedPreKeyId,
    this.ratchetVersion = 2,
  });

  Map<String, dynamic> toMap() => {
        'identityKey': identityKey,
        'ephemeralKey': ephemeralKey,
        'usedOneTimePreKeyId': usedOneTimePreKeyId,
        'usedSignedPreKeyId': usedSignedPreKeyId,
        'ratchetVersion': ratchetVersion,
      };

  factory E2EEInitHeader.fromMap(Map<String, dynamic> map) => E2EEInitHeader(
        identityKey: (map['identityKey'] ?? '').toString(),
        ephemeralKey: (map['ephemeralKey'] ?? '').toString(),
        usedOneTimePreKeyId: map['usedOneTimePreKeyId'] as String?,
        usedSignedPreKeyId: map['usedSignedPreKeyId'] as String?,
        ratchetVersion: (map['ratchetVersion'] as num?)?.toInt() ?? 2,
      );

  bool get isValid => identityKey.isNotEmpty && ephemeralKey.isNotEmpty;
}
