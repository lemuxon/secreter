import 'package:shared_preferences/shared_preferences.dart';

import '../core/di/injection.dart';
import '../core/observability/handled_error.dart';
import '../core/privacy/privacy_controller.dart';
import '../core/security/pin_hasher.dart';
import '../core/security/secure_store.dart';

/// Uygulama kilidi, ekran görüntüsü ve kilit tercihleri.
///
/// ── BU SÜRÜMDE DÜZELTİLEN ÜÇ SORUN ──
///
/// 1. KİLİT BAYRAĞI DÜZ METİNDEYDİ. `lock_enabled` SharedPreferences'ta
///    (şifrelenmemiş XML) tutuluyordu. Cihaza erişen biri PIN'i bilmeden
///    bu bayrağı `false` yapıp UYGULAMA KİLİDİNİ TAMAMEN DEVRE DIŞI
///    bırakabiliyordu. Tüm kilit ayarları artık secure storage'da.
///
/// 2. ZAYIF PIN KARMASI. Tek tur SHA-256 + zaman damgası tuzu kullanılıyordu;
///    kısa PIN'ler anında kırılabiliyordu. Artık [PinHasher] (PBKDF2,
///    150k tur, kriptografik tuz).
///
/// 3. İKİ AYRI GİZLİLİK SİSTEMİ. Paylaşım tercihleri hem burada
///    (SharedPreferences) hem `PrivacySettings` (Hive) içinde tutuluyordu
///    ve BİRBİRİNDEN HABERSİZDİ: kullanıcı ayarlar ekranından bir anahtarı
///    kapatıyor ama diğer sistem hâlâ açık sanıp veri göndermeye devam
///    ediyordu. Paylaşım tercihleri artık YALNIZCA `PrivacySettings`
///    üzerinden yönetilir; buradaki metotlar ona köprüdür.
class PrivacyService {
  // Secure storage anahtarları (hepsi şifreli depoda)
  static const _pinHashKey = 'app_lock_pin_hash';
  static const _decoyPinHashKey = 'app_lock_decoy_pin_hash';
  static const _lockEnabledKey = 'app_lock_enabled';
  static const _biometricEnabledKey = 'app_lock_biometric';
  static const _autoLockMinutesKey = 'app_lock_auto_minutes';
  static const _blockScreenshotKey = 'app_block_screenshot';
  static const _panicKey = 'panic_gesture_enabled';
  static const _failedAttemptsKey = 'app_lock_failed_attempts';
  static const _lockoutUntilKey = 'app_lock_lockout_until';

  /// Eski SharedPreferences anahtarları (tek seferlik taşıma için)
  static const _legacyLockEnabled = 'lock_enabled';
  static const _legacyBiometric = 'biometric_enabled';
  static const _legacyAutoLock = 'auto_lock_minutes';
  static const _legacyScreenshot = 'block_screenshot';
  static const _legacyPinSalt = 'app_lock_pin_salt';
  static const _legacyHideNotif = 'hide_notif_content';
  static const _hideNotifContentKey = 'hide_notif_content_secure';

  /// Kaç yanlış denemeden sonra geçici kilitleme başlar.
  static const int maxAttempts = 5;

  /// Kilitleme süresi (deneme sayısına göre artar).
  static Duration _lockoutFor(int attempts) {
    final over = attempts - maxAttempts;
    if (over < 0) return Duration.zero;
    // 30s, 1dk, 2dk, 4dk... en fazla 15dk
    final seconds = (30 * (1 << over.clamp(0, 5))).clamp(30, 900);
    return Duration(seconds: seconds);
  }

  // ─────────────────────────────────────────
  // TEK SEFERLİK TAŞIMA (düz metin → secure)
  // ─────────────────────────────────────────

  static bool _migrated = false;

  /// Eski SharedPreferences tercihlerini secure storage'a taşı.
  /// Uygulama açılışında bir kez çağrılır (idempotent).
  static Future<void> migrateLegacyPrefs() async {
    if (_migrated) return;
    _migrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      Future<void> move(String legacyKey, String secureKey) async {
        if (!prefs.containsKey(legacyKey)) return;
        if (await SecureStore.read(secureKey) != null) {
          await prefs.remove(legacyKey);
          return;
        }
        final v = prefs.get(legacyKey);
        if (v is bool) {
          await SecureStore.write(secureKey, v ? '1' : '0');
        } else if (v is int) {
          await SecureStore.write(secureKey, v.toString());
        }
        // Düz metin kopyayı SİL — saldırganın oynayabileceği yüzey kalmasın.
        await prefs.remove(legacyKey);
      }

      await move(_legacyLockEnabled, _lockEnabledKey);
      await move(_legacyBiometric, _biometricEnabledKey);
      await move(_legacyAutoLock, _autoLockMinutesKey);
      await move(_legacyScreenshot, _blockScreenshotKey);
      await move(_legacyHideNotif, _hideNotifContentKey);

      // Eski PIN karmasını (tek tur SHA-256) doğrulanabilir biçimde sarmala:
      // tuz ayrı anahtardaydı, artık karmanın içine gömülür. Kullanıcı bir
      // sonraki başarılı girişte otomatik olarak PBKDF2'ye yükseltilir.
      final oldSalt = await SecureStore.read(_legacyPinSalt);
      final oldHash = await SecureStore.read(_pinHashKey);
      if (oldSalt != null && oldHash != null && !oldHash.contains(':legacy:')) {
        if (PinHasher.needsUpgrade(oldHash)) {
          await SecureStore.write(
              _pinHashKey, PinHasher.wrapLegacy(oldHash, oldSalt));
          final oldDecoy = await SecureStore.read(_decoyPinHashKey);
          if (oldDecoy != null && PinHasher.needsUpgrade(oldDecoy)) {
            await SecureStore.write(
                _decoyPinHashKey, PinHasher.wrapLegacy(oldDecoy, oldSalt));
          }
        }
        await SecureStore.delete(_legacyPinSalt);
      }
    } catch (e, s) {
      // ⚠️ İKİ YÖNLÜ KAYIP, İKİSİ DE SESSİZ:
      //   1. Taşıma yarıda kalırsa ayar SecureStore'a yazılmamış olur →
      //      uygulama kilidi KAPALI okunur ve kullanıcı kilidin durduğunu
      //      sanar.
      //   2. Düz metin kopya silinemezse, kaldırılmak istenen saldırı
      //      yüzeyi (şifrelenmemiş XML'deki güvenlik ayarları) yerinde
      //      kalır.
      reportHandled(
          'Gizlilik tercihleri taşınamadı — KİLİT AYARI KAYBOLABİLİR', e,
          stack: s);
    }
  }

  // ─────────────────────────────────────────
  // SECURE STORAGE YARDIMCILARI
  // ─────────────────────────────────────────

  static Future<bool> _getBool(String key, [bool def = false]) async {
    final v = await SecureStore.read(key);
    if (v == null) return def;
    return v == '1';
  }

  static Future<void> _setBool(String key, bool val) =>
      SecureStore.writeOrThrow(key: key, value: val ? '1' : '0');

  static Future<int> _getInt(String key, int def) async {
    final v = await SecureStore.read(key);
    return v == null ? def : (int.tryParse(v) ?? def);
  }

  static Future<void> _setInt(String key, int val) =>
      SecureStore.writeOrThrow(key: key, value: val.toString());

  // ─────────────────────────────────────────
  // PIN
  // ─────────────────────────────────────────

  /// PIN belirle / değiştir.
  static Future<void> setPin(String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN en az 4 hane olmalı');
    }
    await SecureStore.writeOrThrow(
        key: _pinHashKey, value: await PinHasher.hash(pin));
    await _setBool(_lockEnabledKey, true);
    await _resetAttempts();
  }

  /// Girilen PIN doğru mu? (gerçek PIN)
  ///
  /// Başarılı girişte eski/zayıf karma sessizce PBKDF2'ye yükseltilir.
  static Future<bool> verifyPin(String pin) async {
    final stored = await SecureStore.read(_pinHashKey);
    if (stored == null) return false;
    final ok = await PinHasher.verify(pin, stored);
    if (ok) {
      await _resetAttempts();
      if (PinHasher.needsUpgrade(stored)) {
        await SecureStore.write(_pinHashKey, await PinHasher.hash(pin));
      }
    } else {
      await _recordFailure();
    }
    return ok;
  }

  /// Sahte (decoy) PIN belirle — makul inkâr edilebilirlik.
  ///
  /// ⚠️ Eski kod, tuz yoksa SESSİZCE HİÇBİR ŞEY YAPMIYORDU (`if (salt == null)
  /// return;`). Yani gerçek PIN kurulmadan sahte PIN ayarlanmak istendiğinde
  /// arayüz "kaydedildi" diyor ama özellik kurulmuyordu — zorlama altında
  /// kullanılacak bir güvenlik özelliğinin sessiz başarısızlığı. Artık
  /// bağımsız çalışır ve başarısızlıkta istisna fırlatır.
  static Future<void> setDecoyPin(String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN en az 4 hane olmalı');
    }
    final real = await SecureStore.read(_pinHashKey);
    if (real != null && await PinHasher.verify(pin, real)) {
      // Sahte PIN gerçek PIN'le aynı olamaz — yoksa panik modu tetiklenemez.
      throw ArgumentError('err_decoy_same_as_real');
    }
    await SecureStore.writeOrThrow(
        key: _decoyPinHashKey, value: await PinHasher.hash(pin));
  }

  static Future<bool> isDecoyPin(String pin) async {
    final stored = await SecureStore.read(_decoyPinHashKey);
    if (stored == null) return false;
    return PinHasher.verify(pin, stored);
  }

  static Future<bool> hasDecoyPin() async =>
      await SecureStore.read(_decoyPinHashKey) != null;

  static Future<void> clearDecoyPin() async {
    await SecureStore.delete(_decoyPinHashKey);
  }

  /// PIN ve kilidi tamamen kaldır.
  static Future<void> removePin() async {
    await SecureStore.delete(_pinHashKey);
    await SecureStore.delete(_decoyPinHashKey);
    await SecureStore.delete(_legacyPinSalt);
    await _setBool(_lockEnabledKey, false);
    await _setBool(_biometricEnabledKey, false);
    await _resetAttempts();
  }

  // ─────────────────────────────────────────
  // KABA KUVVET KORUMASI
  // ─────────────────────────────────────────

  static Future<void> _recordFailure() async {
    final attempts = (await _getInt(_failedAttemptsKey, 0)) + 1;
    await _setInt(_failedAttemptsKey, attempts);
    final wait = _lockoutFor(attempts);
    if (wait > Duration.zero) {
      await SecureStore.writeOrThrow(
        key: _lockoutUntilKey,
        value: DateTime.now().toUtc().add(wait).toIso8601String(),
      );
    }
  }

  static Future<void> _resetAttempts() async {
    await SecureStore.delete(_failedAttemptsKey);
    await SecureStore.delete(_lockoutUntilKey);
  }

  /// Şu an geçici kilitliyse kalan süre; değilse [Duration.zero].
  static Future<Duration> lockoutRemaining() async {
    final raw = await SecureStore.read(_lockoutUntilKey);
    if (raw == null) return Duration.zero;
    final until = DateTime.tryParse(raw);
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  static Future<int> failedAttempts() => _getInt(_failedAttemptsKey, 0);

  // ─────────────────────────────────────────
  // KİLİT TERCİHLERİ (secure storage)
  // ─────────────────────────────────────────

  static Future<bool> isLockEnabled() => _getBool(_lockEnabledKey);

  static Future<bool> isBiometricEnabled() => _getBool(_biometricEnabledKey);
  static Future<void> setBiometricEnabled(bool v) =>
      _setBool(_biometricEnabledKey, v);

  /// Otomatik kilit süresi (dakika, 0 = anında)
  static Future<int> getAutoLockMinutes() => _getInt(_autoLockMinutesKey, 0);
  static Future<void> setAutoLockMinutes(int m) =>
      _setInt(_autoLockMinutesKey, m);

  /// Ekran görüntüsü engelleme.
  ///
  /// VARSAYILAN AÇIK: MainActivity FLAG_SECURE'ü açılışta zaten set ediyor;
  /// varsayılanı `false` bırakmak, arayüzde "kapalı" görünürken korumanın
  /// açık olması gibi tutarsız bir duruma yol açıyordu.
  static Future<bool> isScreenshotBlocked() =>
      _getBool(_blockScreenshotKey, true);
  static Future<void> setScreenshotBlocked(bool v) =>
      _setBool(_blockScreenshotKey, v);

  /// Panik jesti (başlığa uzun basınca sahte moda geç)
  static Future<bool> isPanicEnabled() => _getBool(_panicKey);
  static Future<void> setPanicEnabled(bool on) => _setBool(_panicKey, on);

  /// Bildirim içeriğini gizle (sadece "yeni mesaj" göster).
  /// VARSAYILAN AÇIK — gizlilik uygulamasında içerik kilit ekranına düşmemeli.
  static Future<bool> isNotificationContentHidden() =>
      _getBool(_hideNotifContentKey, true);
  static Future<void> setNotificationContentHidden(bool v) =>
      _setBool(_hideNotifContentKey, v);

  // ─────────────────────────────────────────
  // PAYLAŞIM TERCİHLERİ — TEK KAYNAK: PrivacySettings (Hive)
  //
  // Bu metotlar geriye dönük uyum için var; artık kendi kopyalarını
  // TUTMUYOR, tek doğruluk kaynağını okuyorlar.
  // ─────────────────────────────────────────

  static PrivacySettingsReader? get _reader {
    try {
      return getIt.isRegistered<PrivacySettingsReader>()
          ? getIt<PrivacySettingsReader>()
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Son görülme gizli mi? (= çevrimiçi paylaşımı kapalı mı)
  static Future<bool> isLastSeenHidden() async =>
      !(_reader?.current.sharePresence ?? false);

  static Future<bool> isReadReceiptsHidden() async =>
      !(_reader?.current.sendReadReceipts ?? false);

  static Future<bool> isTypingHidden() async =>
      !(_reader?.current.sendTypingIndicator ?? false);
}
