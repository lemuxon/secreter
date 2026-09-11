import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// 🔐 PIN KARMASI — PBKDF2-HMAC-SHA256
///
/// ⚠️ NEDEN DEĞİŞTİ:
/// Eski kod `sha256('$pin:$salt')` kullanıyordu — TEK TUR. 4–6 haneli bir
/// PIN'in tüm olasılık uzayı (10.000–1.000.000) modern bir GPU'da
/// MİLİSANİYELER içinde taranır. Cihaza erişen biri secure storage'daki
/// tuz+karma çiftini okuyup PIN'i anında bulabiliyordu. Üstelik tuz
/// `DateTime.now().microsecondsSinceEpoch` idi: rastgele değil, TAHMİN
/// EDİLEBİLİR.
///
/// ŞİMDİ:
///  • Tuz `Random.secure()` ile 16 bayt
///  • 150.000 tur PBKDF2-HMAC-SHA256 (kaba kuvveti pratik olarak durdurur)
///  • Türetme ARKA PLAN isolate'inde çalışır (UI donmaz / ANR olmaz)
///  • Karşılaştırma SABİT ZAMANLI (yan kanal sızıntısı yok)
///
/// BİÇİM: `pbkdf2$<tur>$<tuzB64>$<karmaB64>`
/// Sürüm/parametre karmanın içinde taşındığı için tur sayısı ileride
/// artırılabilir; eski karmalar yine doğrulanır.
class PinHasher {
  static const int _iterations = 150000;
  static const int _saltBytes = 16;
  static const int _keyBits = 256;

  /// Yeni PIN için karma üret (yeni tuzla).
  static Future<String> hash(String pin) async {
    final salt = _randomSalt();
    final key = await compute(
      _derive,
      _DeriveRequest(pin: pin, salt: salt, iterations: _iterations),
    );
    return 'pbkdf2\$$_iterations\$${base64.encode(salt)}\$${base64.encode(key)}';
  }

  /// Girilen PIN, saklanan karmayla eşleşiyor mu?
  ///
  /// Eski (tek tur SHA-256) karmaları da doğrular — böylece mevcut
  /// kullanıcılar kilitlerinden kilitlenip kalmaz. Doğrulama başarılıysa
  /// çağıran taraf [needsUpgrade] ile karmayı yenilemelidir.
  static Future<bool> verify(String pin, String stored) async {
    if (stored.isEmpty) return false;

    if (stored.startsWith('pbkdf2\$')) {
      final parts = stored.split('\$');
      if (parts.length != 4) return false;
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations <= 0) return false;
      final Uint8List salt;
      final List<int> expected;
      try {
        salt = Uint8List.fromList(base64.decode(parts[2]));
        expected = base64.decode(parts[3]);
      } catch (_) {
        return false;
      }
      final actual = await compute(
        _derive,
        _DeriveRequest(pin: pin, salt: salt, iterations: iterations),
      );
      return _constantTimeEquals(actual, expected);
    }

    // ── ESKİ BİÇİM (tek tur SHA-256, "pin:salt") ──
    // Yalnızca geriye dönük uyum için. Doğrulanınca karma yükseltilir.
    final legacySalt = _legacySaltOf(stored);
    if (legacySalt == null) return false;
    final digest = await Sha256().hash(utf8.encode('$pin:$legacySalt'));
    final hex =
        digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return _constantTimeEquals(
      utf8.encode(hex),
      utf8.encode(stored.split(':legacy:').first),
    );
  }

  /// Bu karma eski/zayıf biçimde mi? (doğrulamadan sonra yenilenmeli)
  static bool needsUpgrade(String stored) => !stored.startsWith('pbkdf2\$');

  /// Eski karmayı taşımak için: karma + tuz tek dizede birleştirilir.
  /// (Eski şemada tuz ayrı bir anahtarda tutuluyordu.)
  static String wrapLegacy(String legacyHash, String legacySalt) =>
      '$legacyHash:legacy:$legacySalt';

  static String? _legacySaltOf(String stored) {
    final idx = stored.indexOf(':legacy:');
    if (idx == -1) return null;
    return stored.substring(idx + ':legacy:'.length);
  }

  static Uint8List _randomSalt() {
    final r = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltBytes, (_) => r.nextInt(256)),
    );
  }

  /// Sabit zamanlı karşılaştırma — uzunluk farkı dışında zaman sızdırmaz.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class _DeriveRequest {
  final String pin;
  final Uint8List salt;
  final int iterations;
  const _DeriveRequest({
    required this.pin,
    required this.salt,
    required this.iterations,
  });
}

/// Isolate girişi — 150k tur PBKDF2 ana thread'i BLOKLAMAZ.
Future<List<int>> _derive(_DeriveRequest req) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: req.iterations,
    bits: PinHasher._keyBits,
  );
  final key = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(req.pin)),
    nonce: req.salt,
  );
  return key.extractBytes();
}
