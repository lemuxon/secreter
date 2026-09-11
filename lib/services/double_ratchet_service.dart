import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Double Ratchet — simetrik zincir + ATLANAN MESAJ ANAHTARI desteği.
///
/// Her mesaj için ayrı bir mesaj anahtarı türetilir (forward secrecy):
/// bir anahtar ele geçse bile diğer mesajlar güvende kalır.
///
/// ⚠️ BURADA DÜZELTİLEN KRİTİK TASARIM HATASI:
/// Eski sürüm zinciri her çözmede TAM BİR ADIM ilerletiyor ve mesaj
/// numarasını (`num`) hiç kullanmıyordu. Gerçek ağda mesajlar sırasız
/// gelir veya kaybolur; böyle bir durumda zincir kalıcı olarak
/// senkronizasyonunu kaybediyor ve SONRAKİ TÜM MESAJLAR çözülemez hâle
/// geliyordu. Artık:
///   • Paketteki mesaj numarası okunur.
///   • Beklenenden ileri bir numara gelirse, aradaki anahtarlar türetilip
///     `skipped` haritasında SAKLANIR (geç gelen mesaj sonra çözülebilir).
///   • Geçmişte kalmış bir numara gelirse anahtar `skipped`ten alınır ve
///     kullanıldıktan sonra silinir (tek kullanım).
///
/// ── SÜRÜM 3: DH RATCHET (post-compromise security) ──
///
/// v2 yalnızca simetrik zincirdi: saldırgan cihazdaki zincir anahtarını
/// bir kez ele geçirirse o sohbetin SONRAKİ TÜM mesajlarını süresiz
/// okuyabiliyordu (forward secrecy vardı, break-in recovery yoktu).
///
/// v3'te taraflar karşılıklı mesajlaştıkça yeni DH çiftleri üretir; her
/// yön değişiminde kök anahtardan yeni zincirler türetilir. Saldırgan bir
/// anlık durumu ele geçirse bile, karşı taraf bir kez cevap yazdığında
/// yeni DH sırrını bilemediği için dışarıda kalır.
///
/// ⚠️ v2 YOLU KALDIRILMADI. Sahadaki oturumlarda kök anahtar YOKTUR;
/// onları v3'e çevirmenin bir yolu da yoktur (kök anahtar X3DH anında
/// türetilir). Eski oturumlar v2'de çalışmaya devam eder — aksi halde
/// mevcut kullanıcıların tüm sohbetleri çözülemez hâle gelirdi.
class DoubleRatchetService {
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
  static final _aesGcm = AesGcm.with256bits();
  static final _x25519 = X25519();

  /// Bu istemcinin desteklediği ratchet sürümü. Anahtar paketinde
  /// yayınlanır; karşı taraf buna bakarak v3 oturum kurup kurmayacağına
  /// karar verir (eski istemciye v3 göndermek sohbeti kırardı).
  static const int currentVersion = 3;

  /// Bir zincir adımı atlamak için üst sınır. Kötü niyetli bir gönderen
  /// `num: 2_000_000_000` yazarak istemciyi milyarlarca HKDF turuna
  /// zorlayabilir (hizmet dışı bırakma). Sınır bunu engeller.
  static const int maxSkip = 1000;

  /// Zincir anahtarından (yeniZincir, mesajAnahtarı) türet.
  static Future<RatchetStep> _ratchet(List<int> chainKey) async {
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(chainKey),
      nonce: Uint8List(32),
      info: utf8.encode('SECRETER-Ratchet-v2'),
    );
    final bytes = await derived.extractBytes();
    return RatchetStep(
      newChainKey: bytes.sublist(0, 32),
      messageKey: bytes.sublist(32, 64),
    );
  }

  /// Mesajı şifrele. Zinciri bir adım ilerletir.
  static Future<EncryptResult> encrypt({
    required List<int> chainKey,
    required String plaintext,
    required int messageNumber,
  }) async {
    final step = await _ratchet(chainKey);
    final box = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(step.messageKey),
      nonce: _aesGcm.newNonce(),
    );

    final packet = {
      'v': 2,
      'n': base64.encode(box.nonce),
      'c': base64.encode(box.cipherText),
      'm': base64.encode(box.mac.bytes),
      'num': messageNumber,
    };

    return EncryptResult(
      ciphertext: base64.encode(utf8.encode(jsonEncode(packet))),
      newChainKey: step.newChainKey,
    );
  }

  /// Mesajı çöz.
  ///
  /// [chainKey] alma zincirinin GÜNCEL durumu, [chainIndex] bu zincirin
  /// kaçıncı mesajda olduğu, [skipped] daha önce atlanmış mesaj
  /// anahtarları (numara -> base64 anahtar).
  ///
  /// Dönen [DecryptResult] zincirin YENİ durumunu ve güncellenmiş
  /// `skipped` haritasını taşır; çağıran bunu kalıcılaştırmalıdır.
  static Future<DecryptResult?> decrypt({
    required List<int> chainKey,
    required int chainIndex,
    required Map<String, String> skipped,
    required String encryptedPacket,
  }) async {
    try {
      final packetJson = utf8.decode(base64.decode(encryptedPacket));
      final decoded = jsonDecode(packetJson);
      if (decoded is! Map) return null;

      final nonceB64 = decoded['n'];
      final cipherB64 = decoded['c'];
      final macB64 = decoded['m'];
      if (nonceB64 is! String || cipherB64 is! String || macB64 is! String) {
        return null;
      }
      final rawNum = decoded['num'];
      final messageNumber = rawNum is int ? rawNum : chainIndex;
      if (messageNumber < 0) return null;

      final box = SecretBox(
        base64.decode(cipherB64),
        nonce: base64.decode(nonceB64),
        mac: Mac(base64.decode(macB64)),
      );

      final newSkipped = Map<String, String>.from(skipped);

      // ── DURUM 1: GEÇMİŞTE KALMIŞ MESAJ (sırasız/geç geldi) ──
      // Anahtarı daha önce saklamışsak buradan çözülür; zincir OLDUĞU
      // YERDE kalır. Eskiden bu mesajlar kalıcı olarak kayıptı.
      if (messageNumber < chainIndex) {
        final saved = newSkipped.remove(messageNumber.toString());
        if (saved == null) return null; // anahtar yok (zaten kullanılmış)
        final clear = await _aesGcm.decrypt(
          box,
          secretKey: SecretKey(base64.decode(saved)),
        );
        return DecryptResult(
          plaintext: utf8.decode(clear),
          newChainKey: chainKey,
          newChainIndex: chainIndex,
          skipped: newSkipped,
        );
      }

      // ── DURUM 2: İLERİDEKİ MESAJ (aradakiler kaybolmuş/gecikmiş) ──
      // Aradaki anahtarları türetip SAKLA, sonra hedef anahtarla çöz.
      if (messageNumber - chainIndex > maxSkip) return null;

      var walkKey = chainKey;
      var walkIndex = chainIndex;
      while (walkIndex < messageNumber) {
        final step = await _ratchet(walkKey);
        newSkipped[walkIndex.toString()] = base64.encode(step.messageKey);
        walkKey = step.newChainKey;
        walkIndex++;
      }

      final target = await _ratchet(walkKey);
      final clear = await _aesGcm.decrypt(
        box,
        secretKey: SecretKey(target.messageKey),
      );

      // Atlanan anahtar haritası sınırsız büyümesin (bellek + depo)
      if (newSkipped.length > maxSkip) {
        final keys = newSkipped.keys.toList()
          ..sort(
              (a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
        for (final k in keys.take(newSkipped.length - maxSkip)) {
          newSkipped.remove(k);
        }
      }

      return DecryptResult(
        plaintext: utf8.decode(clear),
        newChainKey: target.newChainKey,
        newChainIndex: messageNumber + 1,
        skipped: newSkipped,
      );
    } catch (_) {
      // Yanlış anahtar / kurcalanmış veri / bozuk paket
      return null;
    }
  }

  // ═════════════════════════════════════════
  // SÜRÜM 3 — DH RATCHET
  // ═════════════════════════════════════════

  /// Yeni bir DH çifti üret (base64 özel, base64 açık).
  static Future<(String priv, String pub)> newDhKeyPair() async {
    final kp = await _x25519.newKeyPair();
    final priv = await kp.extractPrivateKeyBytes();
    final pub = await kp.extractPublicKey();
    return (base64.encode(priv), base64.encode(pub.bytes));
  }

  /// X25519: kendi özel anahtarımız × karşı tarafın açık anahtarı.
  static Future<List<int>> dh(String privB64, String pubB64) async {
    final kp = await _x25519.newKeyPairFromSeed(base64.decode(privB64));
    final shared = await _x25519.sharedSecretKey(
      keyPair: kp,
      remotePublicKey: SimplePublicKey(
        base64.decode(pubB64),
        type: KeyPairType.x25519,
      ),
    );
    final bytes = await shared.extractBytes();
    // Düşük mertebeli nokta: ortak sır tamamen sıfırsa karşı taraf
    // geçersiz açık anahtar göndermiş demektir (X3DH'te de kontrol edilir).
    if (bytes.every((b) => b == 0)) {
      throw StateError('DH ortak sırrı sıfır — geçersiz açık anahtar');
    }
    return bytes;
  }

  /// KDF_RK: (kök anahtar, DH çıktısı) → (yeni kök anahtar, zincir anahtarı).
  /// HKDF tuzu olarak MEVCUT kök anahtar kullanılır (Signal deseni).
  ///
  /// Oturum kurulumunda (bootstrap) da gerekli olduğu için herkese açık.
  static Future<(List<int> root, List<int> chain)> kdfRoot(
    List<int> rootKey,
    List<int> dhOut,
  ) async {
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(dhOut),
      nonce: rootKey,
      info: utf8.encode('SECRETER-DHRatchet-v3'),
    );
    final b = await derived.extractBytes();
    return (b.sublist(0, 32), b.sublist(32, 64));
  }

  /// Atlanan anahtar kimliği. Mesaj numarası TEK BAŞINA YETMEZ: her DH
  /// adımında numaralar sıfırlanır, yani "5" farklı zincirlerde farklı
  /// mesajlardır. Zincirin DH açık anahtarı da kimliğe girer.
  static String skippedKey(String dhPub, int n) => '$dhPub|$n';

  /// [from]'dan [until]'a kadar mesaj anahtarlarını türetip sakla.
  static Future<(List<int>, int)> _skipTo({
    required List<int> chainKey,
    required int from,
    required int until,
    required String dhPub,
    required Map<String, String> skipped,
  }) async {
    var ck = chainKey;
    var i = from;
    while (i < until) {
      final step = await _ratchet(ck);
      skipped[skippedKey(dhPub, i)] = base64.encode(step.messageKey);
      ck = step.newChainKey;
      i++;
    }
    return (ck, i);
  }

  /// Atlanan anahtar haritası sınırsız büyümesin (bellek + güvenli depo).
  static void _pruneSkipped(Map<String, String> skipped) {
    if (skipped.length <= maxSkip) return;
    final keys = skipped.keys.toList();
    for (final k in keys.take(skipped.length - maxSkip)) {
      skipped.remove(k);
    }
  }

  /// v3 şifreleme. Gönderme zincirini bir adım ilerletir; DH adımı ATMAZ
  /// (DH adımı yalnızca karşı taraftan YENİ bir DH anahtarı görülünce
  /// atılır — Signal deseni).
  static Future<DhEncryptResult> encryptV3({
    required List<int> sendChainKey,
    required String dhsPub,
    required int sendCounter,
    required int prevSendCount,
    required String plaintext,
  }) async {
    final step = await _ratchet(sendChainKey);
    final box = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(step.messageKey),
      nonce: _aesGcm.newNonce(),
    );

    final packet = {
      'v': 3,
      'dh': dhsPub,
      'pn': prevSendCount,
      'num': sendCounter,
      'n': base64.encode(box.nonce),
      'c': base64.encode(box.cipherText),
      'm': base64.encode(box.mac.bytes),
    };

    return DhEncryptResult(
      ciphertext: base64.encode(utf8.encode(jsonEncode(packet))),
      newSendChainKey: step.newChainKey,
      newSendCounter: sendCounter + 1,
    );
  }

  /// Bir paketin v3 (DH ratchet) olup olmadığını söyler.
  static bool isV3Packet(String encryptedPacket) {
    try {
      final decoded = jsonDecode(utf8.decode(base64.decode(encryptedPacket)));
      return decoded is Map && decoded['v'] == 3 && decoded['dh'] is String;
    } catch (_) {
      return false;
    }
  }

  /// v3 çözme. Gerekirse DH ratchet adımını atar ve TÜM durumu döndürür;
  /// çağıran bunu kalıcılaştırmak zorundadır.
  static Future<DhDecryptResult?> decryptV3({
    required List<int> rootKey,
    required String dhsPriv,
    required String dhsPub,
    required String? dhrPub,
    required List<int> sendChainKey,
    required List<int> recvChainKey,
    required int sendCounter,
    required int recvCounter,
    required int prevSendCount,
    required Map<String, String> skipped,
    required String encryptedPacket,
  }) async {
    try {
      final decoded = jsonDecode(utf8.decode(base64.decode(encryptedPacket)));
      if (decoded is! Map) return null;

      final headerDh = decoded['dh'];
      final nonceB64 = decoded['n'];
      final cipherB64 = decoded['c'];
      final macB64 = decoded['m'];
      if (headerDh is! String ||
          headerDh.isEmpty ||
          nonceB64 is! String ||
          cipherB64 is! String ||
          macB64 is! String) {
        return null;
      }
      final num = decoded['num'];
      final pn = decoded['pn'];
      if (num is! int || num < 0 || pn is! int || pn < 0) return null;

      final box = SecretBox(
        base64.decode(cipherB64),
        nonce: base64.decode(nonceB64),
        mac: Mac(base64.decode(macB64)),
      );

      final newSkipped = Map<String, String>.from(skipped);

      // ── DURUM 1: DAHA ÖNCE ATLANMIŞ MESAJ ──
      // Zincir OLDUĞU YERDE kalır; hiçbir şey ilerlemez.
      final saved = newSkipped.remove(skippedKey(headerDh, num));
      if (saved != null) {
        final clear = await _aesGcm.decrypt(
          box,
          secretKey: SecretKey(base64.decode(saved)),
        );
        return DhDecryptResult(
          plaintext: utf8.decode(clear),
          rootKey: rootKey,
          dhsPriv: dhsPriv,
          dhsPub: dhsPub,
          dhrPub: dhrPub,
          sendChainKey: sendChainKey,
          recvChainKey: recvChainKey,
          sendCounter: sendCounter,
          recvCounter: recvCounter,
          prevSendCount: prevSendCount,
          skipped: newSkipped,
          ratcheted: false,
        );
      }

      var rk = rootKey;
      var cks = sendChainKey;
      var ckr = recvChainKey;
      var dsPriv = dhsPriv;
      var dsPub = dhsPub;
      var drPub = dhrPub;
      var ns = sendCounter;
      var nr = recvCounter;
      var pnOut = prevSendCount;
      var ratcheted = false;

      // ── DURUM 2: KARŞI TARAF YENİ DH ANAHTARI GÖNDERDİ ──
      if (headerDh != drPub) {
        // Önce ESKİ alma zincirinin kalan anahtarlarını sakla; yoksa
        // yolda olan mesajlar kalıcı olarak kaybolurdu.
        if (drPub != null && ckr.isNotEmpty) {
          if (pn - nr > maxSkip) return null;
          final (ck2, nr2) = await _skipTo(
            chainKey: ckr,
            from: nr,
            until: pn,
            dhPub: drPub,
            skipped: newSkipped,
          );
          ckr = ck2;
          nr = nr2;
        }

        // DH RATCHET ADIMI — break-in recovery burada gerçekleşir.
        pnOut = ns;
        ns = 0;
        nr = 0;
        drPub = headerDh;

        final (rk1, ckr1) = await kdfRoot(rk, await dh(dsPriv, drPub));
        rk = rk1;
        ckr = ckr1;

        // Kendi DH çiftimizi YENİLE: bundan sonraki gönderimlerimiz
        // saldırganın bilmediği bir sırdan türer.
        final (freshPriv, freshPub) = await newDhKeyPair();
        dsPriv = freshPriv;
        dsPub = freshPub;

        final (rk2, cks1) = await kdfRoot(rk, await dh(dsPriv, drPub));
        rk = rk2;
        cks = cks1;

        ratcheted = true;
      }

      if (ckr.isEmpty) return null; // alma zinciri yok — çözülemez
      if (num < nr) return null; // tekrar/eskimiş mesaj
      if (num - nr > maxSkip) return null;

      // Bu noktada drPub == headerDh (ya ratchet adiminda atandi ya da
      // zaten esitti); null olamaz, bu yuzden headerDh kullaniliyor.
      final (ck3, nr3) = await _skipTo(
        chainKey: ckr,
        from: nr,
        until: num,
        dhPub: headerDh,
        skipped: newSkipped,
      );
      ckr = ck3;
      nr = nr3;

      final target = await _ratchet(ckr);
      final clear = await _aesGcm.decrypt(
        box,
        secretKey: SecretKey(target.messageKey),
      );

      _pruneSkipped(newSkipped);

      return DhDecryptResult(
        plaintext: utf8.decode(clear),
        rootKey: rk,
        dhsPriv: dsPriv,
        dhsPub: dsPub,
        dhrPub: drPub,
        sendChainKey: cks,
        recvChainKey: target.newChainKey,
        sendCounter: ns,
        recvCounter: num + 1,
        prevSendCount: pnOut,
        skipped: newSkipped,
        ratcheted: ratcheted,
      );
    } catch (_) {
      // Yanlış anahtar / kurcalanmış veri / bozuk paket
      return null;
    }
  }
}

class RatchetStep {
  final List<int> newChainKey;
  final List<int> messageKey;
  RatchetStep({required this.newChainKey, required this.messageKey});
}

class EncryptResult {
  final String ciphertext;
  final List<int> newChainKey;
  EncryptResult({required this.ciphertext, required this.newChainKey});
}

class DecryptResult {
  final String plaintext;
  final List<int> newChainKey;
  final int newChainIndex;
  final Map<String, String> skipped;
  DecryptResult({
    required this.plaintext,
    required this.newChainKey,
    required this.newChainIndex,
    required this.skipped,
  });
}

class DhEncryptResult {
  final String ciphertext;
  final List<int> newSendChainKey;
  final int newSendCounter;
  DhEncryptResult({
    required this.ciphertext,
    required this.newSendChainKey,
    required this.newSendCounter,
  });
}

/// v3 çözme sonucu — oturum durumunun TAMAMI (DH adımı atılmış olabilir).
class DhDecryptResult {
  final String plaintext;
  final List<int> rootKey;
  final String dhsPriv;
  final String dhsPub;
  final String? dhrPub;
  final List<int> sendChainKey;
  final List<int> recvChainKey;
  final int sendCounter;
  final int recvCounter;
  final int prevSendCount;
  final Map<String, String> skipped;

  /// Bu çözmede DH adımı atıldı mı? (test ve tanılama için)
  final bool ratcheted;

  DhDecryptResult({
    required this.plaintext,
    required this.rootKey,
    required this.dhsPriv,
    required this.dhsPub,
    required this.dhrPub,
    required this.sendChainKey,
    required this.recvChainKey,
    required this.sendCounter,
    required this.recvCounter,
    required this.prevSendCount,
    required this.skipped,
    required this.ratcheted,
  });
}
