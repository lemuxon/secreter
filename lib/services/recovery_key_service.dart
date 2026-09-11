import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../core/observability/handled_error.dart';
import 'auth_service.dart';
import 'multi_account_service.dart';

/// 🔑 HESAP KURTARMA ANAHTARI
///
/// ÇÖZDÜĞÜ SORUN: SECRETER telefon numarası veya e-posta istemez. Bedeli:
/// hesabın kimliği ve şifreleme anahtarı YALNIZCA cihazda durur. Telefon
/// kaybolursa geri dönüş yolu yoktur.
///
/// ── BU SÜRÜMDE DÜZELTİLEN İKİ SORUN ──
///
/// 1. ANAHTAR ŞİFRELENMİYORDU. Eski `encode()` uid + kullanıcı adı +
///    şifreleme anahtarı + hesap parolasını DÜZ base64'e koyuyordu.
///    base64 bir kodlamadır, şifreleme DEĞİLDİR. Bu metni (veya ekranda
///    gösterilen QR kodunu) gören herkes — omuz sörfü, ekran görüntüsü,
///    bulut panosu, fotoğraf yedeği — HESABI TAMAMEN DEVRALABİLİYORDU.
///    Artık kullanıcının belirlediği bir parola ile AES-256-GCM
///    (PBKDF2, 150k tur) sarmalanır. Parola olmadan anahtar işe yaramaz.
///
/// 2. AYIRICI KIRILGANLIĞI. Eski `decode()` `RegExp(r'[\s\-]')` ile TÜM
///    tireleri siliyordu. Bu şu an tesadüfen güvenliydi (dış base64,
///    yalnızca `>` veya `~` baytlarında `-` üretir ve JSON yükünde bunlar
///    yok) — ama yüke serbest metin içeren bir alan eklendiği gün
///    anahtarların neredeyse tamamı bozulurdu. Ayırıcı artık base64
///    alfabesinin DIŞINDA (boşluk) ve gruplama yalnızca görsel.
///
/// BİÇİM: `SKP2 <tuz> <nonce> <şifreliVeri> <mac>` (base64Url, boşlukla ayrık)
class RecoveryKeyService {
  static const _magic = 'SKP2';
  static const _legacyMagic = 'SECRETER-KEY-1';
  static const int _iterations = 150000;

  static final _aesGcm = AesGcm.with256bits();

  // ─────────────────────────────────────────
  // ÜRETME
  // ─────────────────────────────────────────

  /// Şu anki hesabın kurtarma anahtarını, verilen PAROLA ile şifreleyerek üret.
  /// Hesap eski sürümden kalmışsa (parola yok) null döner.
  static Future<String?> forCurrentAccount(String passphrase) async {
    final uid = AuthService.currentUid;
    if (uid == null) return null;
    try {
      final accounts = await MultiAccountService.getAccounts();
      SavedAccount? acc;
      for (final a in accounts) {
        if (a.uid == uid) {
          acc = a;
          break;
        }
      }
      if (acc == null || acc.password.isEmpty) return null;
      return encode(acc, passphrase);
    } catch (e, s) {
      // ⚠️ ARIZA, "BU HESAP ESKİ SÜRÜMDEN" DURUMUYLA AYNI SONUCU VERİR.
      // İkisi de `null` döner ve ekran aynı şeyi söyler; oysa biri
      // beklenen bir sınır, diğeri bir arızadır. Telefon kaybolduğunda
      // kurtarma anahtarı TEK geri dönüş yolu olduğu için, üretilemediğini
      // fark etmemek kalıcı hesap kaybı demektir.
      reportHandled('Kurtarma anahtarı üretilemedi — GERİ DÖNÜŞ YOLU YOK', e,
          stack: s);
      return null;
    }
  }

  /// Hesabı parola ile şifreleyerek metne kodla.
  static Future<String> encode(SavedAccount a, String passphrase) async {
    if (passphrase.length < 8) {
      throw const RecoveryKeyError('recovery_pass_too_short');
    }
    final payload = jsonEncode({
      'm': _magic,
      'u': a.uid,
      'n': a.username,
      'k': a.encryptionKey,
      'p': a.password,
    });

    final salt = _randomBytes(16);
    final key = await compute(
      _deriveKey,
      _KdfRequest(passphrase: passphrase, salt: salt, iterations: _iterations),
    );
    final box = await _aesGcm.encrypt(
      utf8.encode(payload),
      secretKey: SecretKey(key),
      nonce: _aesGcm.newNonce(),
    );

    // AYIRICI: boşluk. base64Url alfabesinde bulunmadığı için veriyi
    // asla bozmaz (eski tire ayırıcısının aksine).
    return [
      _magic,
      base64Url.encode(salt),
      base64Url.encode(box.nonce),
      base64Url.encode(box.cipherText),
      base64Url.encode(box.mac.bytes),
    ].join(' ');
  }

  // ─────────────────────────────────────────
  // ÇÖZME
  // ─────────────────────────────────────────

  /// Metinden hesabı çöz. Geçersizse [RecoveryKeyError] fırlatır.
  static Future<SavedAccount> decode(String raw, String passphrase) async {
    final cleaned = raw.trim();

    // ── ESKİ BİÇİM (şifresiz base64) ──
    // Kullanıcılar eski anahtarlarıyla kilitlenip kalmasın: parolasız
    // çözülür ama arayüz "yeni anahtar üret" uyarısı göstermelidir.
    if (!cleaned.startsWith(_magic)) {
      return _decodeLegacy(cleaned);
    }

    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length != 5) {
      throw const RecoveryKeyError('recovery_key_invalid');
    }

    try {
      final salt =
          Uint8List.fromList(base64Url.decode(base64Url.normalize(parts[1])));
      final nonce = base64Url.decode(base64Url.normalize(parts[2]));
      final cipherText = base64Url.decode(base64Url.normalize(parts[3]));
      final mac = base64Url.decode(base64Url.normalize(parts[4]));

      final key = await compute(
        _deriveKey,
        _KdfRequest(
            passphrase: passphrase, salt: salt, iterations: _iterations),
      );

      // GCM kimlik doğrulaması: yanlış parola SESSİZCE çöp veri döndürmez,
      // doğrulama hatası verir.
      final clear = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key),
      );

      final m = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      return _fromPayload(m);
    } on SecretBoxAuthenticationError {
      throw const RecoveryKeyError('recovery_pass_wrong');
    } on RecoveryKeyError {
      rethrow;
    } catch (_) {
      throw const RecoveryKeyError('recovery_key_invalid');
    }
  }

  static SavedAccount _decodeLegacy(String cleaned) {
    // Eski biçimde ayırıcı tireydi; veriyi bozmamak için yalnızca
    // BOŞLUK ve TİRE temizlenir (eski davranışla uyumlu).
    final compact = cleaned.replaceAll(RegExp(r'[\s\-]'), '');
    if (compact.isEmpty) {
      throw const RecoveryKeyError('recovery_key_invalid');
    }
    try {
      final bytes = base64Url.decode(base64Url.normalize(compact));
      final m = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (m['m'] != _legacyMagic) {
        throw const RecoveryKeyError('recovery_key_invalid');
      }
      return _fromPayload(m);
    } on RecoveryKeyError {
      rethrow;
    } catch (_) {
      throw const RecoveryKeyError('recovery_key_invalid');
    }
  }

  static SavedAccount _fromPayload(Map<String, dynamic> m) {
    final uid = (m['u'] ?? '').toString();
    final pw = (m['p'] ?? '').toString();
    if (uid.isEmpty || pw.isEmpty) {
      throw const RecoveryKeyError('recovery_key_invalid');
    }
    return SavedAccount(
      uid: uid,
      username: (m['n'] ?? '').toString(),
      encryptionKey: (m['k'] ?? '').toString(),
      password: pw,
    );
  }

  /// Anahtar eski (şifresiz) biçimde mi? Arayüz uyarı göstermeli.
  static bool isLegacyFormat(String raw) => !raw.trim().startsWith(_magic);

  // ─────────────────────────────────────────
  // GERİ YÜKLEME
  // ─────────────────────────────────────────

  /// Anahtarla hesabı bu cihaza geri yükle ve giriş yap.
  ///
  /// Çözülen hesabı da döndürür; böylece arayüz anahtarı İKİNCİ KEZ
  /// çözmek zorunda kalmaz (eski kod `decode`'u tekrar çağırıyordu:
  /// gereksiz 150k tur PBKDF2 ve parolayı bir kez daha elde tutma riski).
  static Future<RecoveryRestoreResult> restore(
      String raw, String passphrase) async {
    SavedAccount acc;
    try {
      acc = await decode(raw, passphrase);
    } on RecoveryKeyError catch (e) {
      return RecoveryRestoreResult(error: e.key);
    } catch (e) {
      debugPrint('Kurtarma çözülemedi: $e');
      return const RecoveryRestoreResult(error: 'recovery_key_invalid');
    }
    try {
      await MultiAccountService.saveAccount(acc);
      final err = await AuthService.switchAccount(acc);
      return RecoveryRestoreResult(
          error: err, uid: err == null ? acc.uid : null);
    } catch (e) {
      debugPrint('Kurtarma başarısız: $e');
      return const RecoveryRestoreResult(error: 'recovery_failed');
    }
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }
}

class _KdfRequest {
  final String passphrase;
  final Uint8List salt;
  final int iterations;
  const _KdfRequest({
    required this.passphrase,
    required this.salt,
    required this.iterations,
  });
}

/// Isolate girişi — 150k tur PBKDF2 UI'yi dondurmaz.
Future<List<int>> _deriveKey(_KdfRequest req) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: req.iterations,
    bits: 256,
  );
  final key = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(req.passphrase)),
    nonce: req.salt,
  );
  return key.extractBytes();
}

class RecoveryKeyError implements Exception {
  final String key;
  const RecoveryKeyError(this.key);
  @override
  String toString() => key;
}

/// Geri yükleme sonucu: hata çeviri anahtarı ve (başarılıysa) hesap uid'i.
class RecoveryRestoreResult {
  final String? error;
  final String? uid;
  const RecoveryRestoreResult({this.error, this.uid});
  bool get ok => error == null && uid != null;
}
