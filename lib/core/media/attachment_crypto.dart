import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// 🔐 EK (MEDYA) ŞİFRELEME
///
/// ── ÇÖZDÜĞÜ SORUN ──
/// Fotoğraf, video, sesli mesaj ve dosyalar Firebase Storage'a DÜZ olarak
/// yükleniyordu. Yani metin uçtan uca şifreliyken, çoğu zaman metinden
/// DAHA HASSAS olan medya sunucuda tamamen açıktı: altyapıya erişebilen
/// herkes (Firebase konsolu dâhil) her fotoğrafı ve ses kaydını
/// görebiliyordu.
///
/// ── ÇÖZÜM ──
/// Her ek için rastgele 256-bit anahtar üretilir, dosya AES-256-GCM ile
/// CİHAZDA şifrelenir, Storage'a yalnızca şifreli baytlar yüklenir.
/// Anahtar mesajın E2EE'li içeriğinde taşınır (bkz. [AttachmentRef]);
/// yani anahtarı yalnızca sohbetin tarafları görebilir.
///
/// GCM ayrıca BÜTÜNLÜK sağlar: sunucuda değiştirilen bir dosya sessizce
/// bozuk görüntü olarak açılmaz, çözme HATA verir.
///
/// ── BÜYÜK DOSYALAR ──
/// Şifreleme/çözme ARKA PLAN isolate'inde yapılır; 50 MB'lık bir video ana
/// thread'de işlenirse arayüz saniyelerce donar (ANR).
class AttachmentCrypto {
  // NOT: AES örneği isolate İÇİNDE kurulur — isolate'ler bellek paylaşmaz,
  // dışarıdaki bir örnek oraya geçemez.

  /// Rastgele 256-bit ek anahtarı.
  static String newKey() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => r.nextInt(256)));
  }

  /// Dosyayı şifrele → yüklenecek baytlar.
  static Future<Uint8List> encryptFile(File file, String base64Key) async {
    final bytes = await file.readAsBytes();
    return encryptBytes(bytes, base64Key);
  }

  /// Baytları şifrele. Çıktı: `nonce(12) || ciphertext || mac(16)`.
  ///
  /// Tek parça biçim, indirme tarafında ek üst veri gerektirmemesi için
  /// seçildi — Storage nesnesi kendi kendine yeterlidir.
  static Future<Uint8List> encryptBytes(
      Uint8List bytes, String base64Key) async {
    return compute(
      _encryptIsolate,
      _CryptoJob(bytes: bytes, key: _decodeKey(base64Key)),
    );
  }

  /// Şifreli baytları çöz. Anahtar yanlış/veri bozuksa İSTİSNA fırlatır.
  static Future<Uint8List> decryptBytes(
      Uint8List bytes, String base64Key) async {
    return compute(
      _decryptIsolate,
      _CryptoJob(bytes: bytes, key: _decodeKey(base64Key)),
    );
  }

  static Uint8List _decodeKey(String base64Key) {
    final k = base64Url.decode(base64Url.normalize(base64Key));
    if (k.length != 32) {
      throw ArgumentError('Ek anahtarı 32 bayt olmalı (${k.length})');
    }
    return Uint8List.fromList(k);
  }

  /// Test/doğrulama için senkron olmayan yardımcı — isolate kullanmaz.
  @visibleForTesting
  static Future<Uint8List> encryptBytesInline(
          Uint8List bytes, String base64Key) =>
      _encryptIsolate(_CryptoJob(bytes: bytes, key: _decodeKey(base64Key)));

  @visibleForTesting
  static Future<Uint8List> decryptBytesInline(
          Uint8List bytes, String base64Key) =>
      _decryptIsolate(_CryptoJob(bytes: bytes, key: _decodeKey(base64Key)));
}

class _CryptoJob {
  final Uint8List bytes;
  final Uint8List key;
  const _CryptoJob({required this.bytes, required this.key});
}

Future<Uint8List> _encryptIsolate(_CryptoJob job) async {
  final algo = AesGcm.with256bits();
  final box = await algo.encrypt(
    job.bytes,
    secretKey: SecretKey(job.key),
    nonce: algo.newNonce(),
  );
  final out = BytesBuilder(copy: false)
    ..add(box.nonce)
    ..add(box.cipherText)
    ..add(box.mac.bytes);
  return out.toBytes();
}

Future<Uint8List> _decryptIsolate(_CryptoJob job) async {
  const nonceLen = 12;
  const macLen = 16;
  if (job.bytes.length < nonceLen + macLen) {
    throw ArgumentError('Şifreli ek çok kısa');
  }
  final algo = AesGcm.with256bits();
  final nonce = job.bytes.sublist(0, nonceLen);
  final cipher = job.bytes.sublist(nonceLen, job.bytes.length - macLen);
  final mac = job.bytes.sublist(job.bytes.length - macLen);

  final clear = await algo.decrypt(
    SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
    secretKey: SecretKey(job.key),
  );
  return Uint8List.fromList(clear);
}

/// Mesaj içeriğinde taşınan ek göndergesi.
///
/// Medya mesajlarında `content` alanı (zaten E2EE'lidir) bu göndergeyi
/// taşır; böylece ek anahtarı sunucuya ASLA düz gitmez.
///
/// Biçim: `ATT1|<anahtar>|<açıklama>`
/// Açıklama (caption) şu an boş; ileride altyazı eklenirse aynı zarf
/// kullanılabilir.
class AttachmentRef {
  static const _prefix = 'ATT1|';

  final String key;
  final String caption;

  const AttachmentRef({required this.key, this.caption = ''});

  String encode() => '$_prefix$key|$caption';

  /// Çözülmüş içerikten ek göndergesi çıkar; değilse null.
  static AttachmentRef? tryParse(String content) {
    if (!content.startsWith(_prefix)) return null;
    final rest = content.substring(_prefix.length);
    final sep = rest.indexOf('|');
    if (sep <= 0) return null;
    return AttachmentRef(
      key: rest.substring(0, sep),
      caption: rest.substring(sep + 1),
    );
  }

  static bool isAttachment(String content) => content.startsWith(_prefix);
}
