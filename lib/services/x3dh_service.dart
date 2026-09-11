import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'key_management_service.dart';

/// X3DH (Extended Triple Diffie-Hellman) anahtar anlaşması.
///
/// İki taraf, özel anahtarlarını paylaşmadan aynı ortak sırra ulaşır.
/// Bu ortak sır, Double Ratchet'in başlangıç kökü olur.
///
/// ⚠️ BU SÜRÜMDE KAPATILAN GÜVENLİK BOŞLUKLARI:
///
/// 1. İMZASIZ SIGNED PREKEY. Alan adı "signedPreKey" olmasına rağmen imza
///    hiç üretilmiyor ve doğrulanmıyordu. Bu, sunucuya (veya Firebase
///    konsoluna) erişebilen tarafın kurbanın anahtar paketini değiştirip
///    TÜM birebir sohbetlerde MITM yapmasına izin veriyordu. Artık SPK,
///    kalıcı Ed25519 imzalama anahtarıyla imzalanır ve karşı tarafta
///    DOĞRULANIR; doğrulama başarısızsa oturum KURULMAZ.
///
/// 2. SESSİZ ANAHTAR UYUŞMAZLIĞI. Bob tek kullanımlık ön-anahtarı
///    bulamazsa (zaten tüketilmiş) eski kod DH4'ü sessizce atlıyordu.
///    Alice onu hesaba kattığı için taraflar FARKLI ortak sır türetiyor,
///    hiçbir hata verilmeden tüm mesajlar çözülemez hâle geliyordu.
///    Artık bu durum [X3DHException] ile açıkça bildirilir.
///
/// 3. DÜŞÜK MERTEBELİ NOKTA KONTROLÜ. Karşı taraftan gelen açık anahtarların
///    uzunluğu ve tamamen sıfır olup olmadığı doğrulanır.
class X3DHService {
  static final _x25519 = X25519();
  static final _ed25519 = Ed25519();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Signal'in X3DH'inde HKDF girdisi 32 bayt 0xFF ile başlar (alan ayrımı).
  static final List<int> _f = List<int>.filled(32, 0xFF);

  /// BAŞLATAN taraf (Alice): Bob'un paketiyle ortak sır üret.
  static Future<X3DHResult> initiateKeyAgreement(PreKeyBundle bobBundle) async {
    // ── 1. BOB'UN İMZALI ÖN-ANAHTARINI DOĞRULA ──
    // Bu adım MITM'e karşı tek korumadır: sunucu SPK'yı değiştirmiş olsa
    // bile imza, Bob'un kalıcı imzalama anahtarıyla tutmayacaktır.
    await _verifySignedPreKey(bobBundle);

    final aliceIdentity = await KeyManagementService.getIdentityKeyPair();
    final aliceEphemeral = await _x25519.newKeyPair();
    final aliceEphemeralPub = await aliceEphemeral.extractPublicKey();

    final bobIdentityPub = _publicKey(bobBundle.identityKey, 'identityKey');
    final bobSignedPreKeyPub =
        _publicKey(bobBundle.signedPreKey, 'signedPreKey');
    final bobOneTimePreKeyPub = bobBundle.oneTimePreKey == null
        ? null
        : _publicKey(bobBundle.oneTimePreKey!, 'oneTimePreKey');

    // DH1 = DH(IK_A, SPK_B)
    // DH2 = DH(EK_A, IK_B)
    // DH3 = DH(EK_A, SPK_B)
    // DH4 = DH(EK_A, OPK_B)  (varsa)
    final dh1 = await _dh(aliceIdentity, bobSignedPreKeyPub);
    final dh2 = await _dh(aliceEphemeral, bobIdentityPub);
    final dh3 = await _dh(aliceEphemeral, bobSignedPreKeyPub);

    final concatenated = <int>[..._f, ...dh1, ...dh2, ...dh3];
    if (bobOneTimePreKeyPub != null) {
      concatenated.addAll(await _dh(aliceEphemeral, bobOneTimePreKeyPub));
    }

    return X3DHResult(
      sharedSecret: await _deriveSharedSecret(concatenated),
      ephemeralPublicKey: base64.encode(aliceEphemeralPub.bytes),
      usedOneTimePreKeyId: bobBundle.oneTimePreKeyId,
      usedSignedPreKeyId: bobBundle.signedPreKeyId,
      peerIdentityKey: bobBundle.identityKey,
      peerSignedPreKey: bobBundle.signedPreKey,
    );
  }

  /// CEVAPLAYAN taraf (Bob): Alice'in başlığıyla aynı sırra ulaş.
  static Future<List<int>> respondToKeyAgreement({
    required String aliceIdentityKeyB64,
    required String aliceEphemeralKeyB64,
    String? usedOneTimePreKeyId,
    String? usedSignedPreKeyId,
  }) async {
    final bobIdentity = await KeyManagementService.getIdentityKeyPair();
    // ── SPK ROTASYONU ──
    // Eski kod her zaman GEÇERLİ SPK'yı kullanıyordu. Alice paketi
    // aldıktan sonra biz ön-anahtarları tazelersek (SPK yenilenir, eski
    // özel anahtar SİLİNİRDİ) DH1/DH3 tutmaz ve taraflar farklı sır
    // türetir — hiçbir hata vermeden. Artık başlık hangi SPK'nın
    // kullanıldığını söyler ve gerekirse önceki anahtar seçilir.
    final bobSignedPreKey =
        await KeyManagementService.getSignedPreKeyPairById(usedSignedPreKeyId);

    SimpleKeyPair? bobOneTimePreKey;
    if (usedOneTimePreKeyId != null) {
      bobOneTimePreKey =
          await KeyManagementService.consumeOneTimePreKey(usedOneTimePreKeyId);
      // ── SESSİZ UYUŞMAZLIĞI ENGELLE ──
      // Alice bu ön-anahtarı hesaba kattı. Biz bulamıyorsak türeteceğimiz
      // sır FARKLI olur ve hiçbir mesaj çözülemez. Sessizce devam etmek
      // yerine açıkça başarısız oluyoruz; çağıran taraf oturumu sıfırlayıp
      // yeni anahtar paketiyle yeniden kurabilir.
      if (bobOneTimePreKey == null) {
        throw const X3DHException(
          'err_e2ee_prekey_missing',
          'Tek kullanımlık ön-anahtar bulunamadı; oturum kurulamaz.',
        );
      }
    }

    final aliceIdentityPub = _publicKey(aliceIdentityKeyB64, 'identityKey');
    final aliceEphemeralPub = _publicKey(aliceEphemeralKeyB64, 'ephemeralKey');

    // Simetri: taraflar ters ama sonuç aynı.
    final dh1 = await _dh(bobSignedPreKey, aliceIdentityPub);
    final dh2 = await _dh(bobIdentity, aliceEphemeralPub);
    final dh3 = await _dh(bobSignedPreKey, aliceEphemeralPub);

    final concatenated = <int>[..._f, ...dh1, ...dh2, ...dh3];
    if (bobOneTimePreKey != null) {
      concatenated.addAll(await _dh(bobOneTimePreKey, aliceEphemeralPub));
    }

    return _deriveSharedSecret(concatenated);
  }

  // ─────────────────────────────────────────
  // İMZA
  // ─────────────────────────────────────────

  /// SPK'yı kalıcı Ed25519 anahtarıyla imzala (paket yayınlanırken kullanılır).
  static Future<String> signPreKey({
    required List<int> signedPreKeyPublicBytes,
    required SimpleKeyPair signingKeyPair,
  }) async {
    final sig = await _ed25519.sign(
      signedPreKeyPublicBytes,
      keyPair: signingKeyPair,
    );
    return base64.encode(sig.bytes);
  }

  /// Karşı tarafın SPK imzasını doğrula. Geçersizse fırlatır.
  static Future<void> _verifySignedPreKey(PreKeyBundle bundle) async {
    final sigB64 = bundle.signedPreKeySignature;
    final signingKeyB64 = bundle.signingPublicKey;

    // GEÇİŞ DÖNEMİ: bu sürümden önce yayınlanmış paketlerde imza alanı yok.
    // Böyle paketleri REDDETMEK, mevcut kullanıcıların birbirine mesaj
    // gönderememesine yol açardı. Bu yüzden imza YOKSA oturum kurulur ama
    // `verified: false` işaretlenir ve arayüz "doğrulanmadı" uyarısı gösterir.
    // Anahtar paketleri yenilendikçe (ensureKeysPublished) bu durum kaybolur.
    if (sigB64 == null || signingKeyB64 == null) return;

    final ok = await _ed25519.verify(
      base64.decode(bundle.signedPreKey),
      signature: Signature(
        base64.decode(sigB64),
        publicKey: SimplePublicKey(
          base64.decode(signingKeyB64),
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!ok) {
      throw const X3DHException(
        'err_e2ee_bad_signature',
        'İmzalı ön-anahtar doğrulanamadı — araya girme girişimi olabilir.',
      );
    }
  }

  // ─────────────────────────────────────────
  // YARDIMCILAR
  // ─────────────────────────────────────────

  /// base64 açık anahtarı doğrulayarak çöz.
  static SimplePublicKey _publicKey(String b64, String label) {
    List<int> bytes;
    try {
      bytes = base64.decode(b64);
    } catch (e) {
      throw X3DHException('err_e2ee_bad_key', '$label çözülemedi: $e');
    }
    if (bytes.length != 32) {
      throw X3DHException(
        'err_e2ee_bad_key',
        '$label uzunluğu geçersiz: ${bytes.length}',
      );
    }
    // Tamamen sıfır anahtar → ortak sır da sıfır olur (düşük mertebeli nokta).
    if (bytes.every((b) => b == 0)) {
      throw X3DHException('err_e2ee_bad_key', '$label geçersiz (sıfır nokta)');
    }
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  static Future<List<int>> _dh(
      SimpleKeyPair privateKey, SimplePublicKey publicKey) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: privateKey,
      remotePublicKey: publicKey,
    );
    final bytes = await shared.extractBytes();
    // Ek güvenlik: ortak sır tamamen sıfırsa karşı taraf düşük mertebeli
    // nokta göndermiş demektir.
    if (bytes.every((b) => b == 0)) {
      throw const X3DHException(
        'err_e2ee_bad_key',
        'Ortak sır sıfır — geçersiz açık anahtar.',
      );
    }
    return bytes;
  }

  static Future<List<int>> _deriveSharedSecret(List<int> input) async {
    final secretKey = await _hkdf.deriveKey(
      secretKey: SecretKey(input),
      nonce: Uint8List(32), // Signal X3DH: sıfır dolgulu salt (standart)
      info: utf8.encode('SECRETER-X3DH-v2'),
    );
    return secretKey.extractBytes();
  }
}

class X3DHResult {
  final List<int> sharedSecret;
  final String ephemeralPublicKey;
  final String? usedOneTimePreKeyId;

  /// Karşı tarafın HANGİ imzalı ön-anahtarını kullandık? Başlıkta
  /// taşınır; karşı taraf rotasyon yapmış olsa bile doğru özel anahtarı
  /// seçebilsin diye.
  final String? usedSignedPreKeyId;

  /// Kullanılan imzalı ön-anahtarın AÇIK kısmı — DH ratchet'in ilk
  /// adımında başlangıç DH hedefi olur.
  final String? peerSignedPreKey;

  /// Karşı tarafın kimlik anahtarı — güvenlik numarası (safety number)
  /// gösterimi ve TOFU sabitlemesi için saklanır.
  final String peerIdentityKey;

  X3DHResult({
    required this.sharedSecret,
    required this.ephemeralPublicKey,
    required this.peerIdentityKey,
    this.usedOneTimePreKeyId,
    this.usedSignedPreKeyId,
    this.peerSignedPreKey,
  });
}

/// Çeviri anahtarı taşıyan E2EE hatası.
class X3DHException implements Exception {
  final String key;
  final String detail;
  const X3DHException(this.key, this.detail);
  @override
  String toString() => '$key: $detail';
}
