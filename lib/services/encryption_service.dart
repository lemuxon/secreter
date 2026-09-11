import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/error/exceptions.dart';
import '../core/observability/handled_error.dart';

/// Uygulama katmanı simetrik şifreleme (AES-256-GCM).
///
/// ⚠️ İKİ KRİTİK HATA BURADA DÜZELTİLDİ:
///
/// 1. SESSİZ DÜZ METİN GERİ DÖNÜŞÜ. Eski kod `catch (e) { return plainText; }`
///    yapıyordu: anahtar bozuksa/kısaysa fonksiyon şifreli metin yerine DÜZ
///    METNİ döndürüyor, çağıran taraf da bunu "şifrelenmiş" sanıp sunucuya
///    yazıyordu. Kullanıcı kilit simgesi görürken içerik açıktı. Artık hata
///    YUTULMAZ — [EncryptionException] fırlatılır.
///
/// 2. KİMLİK DOĞRULAMASIZ CBC. AES-CBC bütünlük sağlamaz; saldırgan
///    şifreli metni değiştirip çözülen içeriği manipüle edebilir
///    (bit-flipping / padding oracle sınıfı saldırılar). AES-GCM hem
///    şifreler hem doğrular: kurcalanmış veri sessizce yanlış sonuç
///    vermez, çözme başarısız olur.
///
/// BİÇİM: `v2.<nonce>.<ciphertext>.<mac>` (hepsi base64Url).
/// Sürüm öneki, eski `<iv>.<ct>` (CBC) kayıtlarını ayırt etmeyi sağlar.
class EncryptionService {
  static const int _keyLength = 32; // 256-bit
  static const String _version = 'v2';

  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// Kriptografik olarak güçlü rastgele anahtar üret (base64Url, 32 bayt).
  static String generateKey() {
    final random = Random.secure();
    final keyBytes = List<int>.generate(_keyLength, (_) => random.nextInt(256));
    return base64Url.encode(keyBytes);
  }

  /// base64/base64Url anahtarı 32 bayta çöz. Geçersizse fırlatır.
  static Uint8List _decodeKey(String base64Key) {
    if (base64Key.isEmpty) {
      throw const EncryptionException('err_crypto');
    }
    List<int> bytes;
    try {
      // `normalize` eksik `=` dolgusunu doğru şekilde ekler; eski kodun
      // elle yaptığı padRight hesabı bazı uzunluklarda hatalıydı.
      bytes = base64Url.decode(base64Url.normalize(base64Key));
    } catch (_) {
      try {
        bytes = base64.decode(base64.normalize(base64Key));
      } catch (e) {
        reportHandled('Şifreleme anahtarı çözülemedi', e);
        throw const EncryptionException('err_crypto');
      }
    }
    if (bytes.length < _keyLength) {
      throw EncryptionException(
        'Şifreleme anahtarı çok kısa: ${bytes.length} bayt (32 gerekli)',
      );
    }
    return Uint8List.fromList(bytes.sublist(0, _keyLength));
  }

  /// Metni şifrele (AES-256-GCM). Başarısızlıkta fırlatır — ASLA düz metin
  /// döndürmez.
  static Future<String> encrypt(String plainText, String base64Key) async {
    final key = SecretKey(_decodeKey(base64Key));
    final box = await _aesGcm.encrypt(
      utf8.encode(plainText),
      secretKey: key,
      nonce: _aesGcm.newNonce(),
    );
    return [
      _version,
      base64Url.encode(box.nonce),
      base64Url.encode(box.cipherText),
      base64Url.encode(box.mac.bytes),
    ].join('.');
  }

  /// Şifreli metni çöz. Başarısızlıkta fırlatır.
  ///
  /// Çağıran taraf, kullanıcıya "çözülemedi" göstermek için istisnayı
  /// yakalamalıdır; sessizce şifreli metni geri döndürmek (eski davranış)
  /// kullanıcıya base64 çöplüğü göstermeye yol açıyordu.
  static Future<String> decrypt(String encryptedText, String base64Key) async {
    final parts = encryptedText.split('.');
    if (parts.length != 4 || parts[0] != _version) {
      throw const EncryptionException('err_crypto');
    }
    final key = SecretKey(_decodeKey(base64Key));
    final box = SecretBox(
      base64Url.decode(base64Url.normalize(parts[2])),
      nonce: base64Url.decode(base64Url.normalize(parts[1])),
      mac: Mac(base64Url.decode(base64Url.normalize(parts[3]))),
    );
    final clear = await _aesGcm.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  }

  /// Metin bu servisin ürettiği bir şifreli paket mi?
  /// (Eski düz metin/CBC kayıtlarını ayırmak için.)
  static bool isCipherText(String value) {
    final parts = value.split('.');
    return parts.length == 4 && parts[0] == _version;
  }
}
