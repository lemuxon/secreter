import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'crash_reporter.dart';

/// CrashReporter'ın Firebase Crashlytics implementasyonu.
///
/// GİZLİLİK TASARIMI:
/// - Varsayılan olarak KAPALI. Sadece kullanıcı onayıyla açılır.
/// - Hata mesajları gönderilmeden önce PII (UID, kullanıcı adı, içerik,
///   token, e-posta) regex'lerle temizlenir.
/// - Hiçbir custom key'e hassas veri yazılmaz.
///
/// ⚠️ DÜRÜST NOT: Crashlytics verisi Google sunucularına gider. Bir
/// anonimlik uygulaması için bu bir ödünleşmedir. Maksimum mahremiyet
/// isteyenler için: (a) telemetriyi tamamen kapalı bırak, (b) self-host
/// Sentry'ye geç (bu soyutlama sayesinde tek dosya değişir). Sağlayıcı
/// seçimi kullanıcı/operatör kararıdır.
class CrashlyticsReporter implements CrashReporter {
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  bool _consent = false;

  /// ARIZA EMNIYETI: Android tarafinda Crashlytics Gradle eklentisi eksikse
  /// platform cagrilari "build ID missing" ile FATAL firlatir (release'te
  /// yasandi). Ilk basarisizlikta raporlayici KENDINI KAPATIR — uygulama
  /// hicbir kosulda telemetri yuzunden etkilenmez. Eklenti kurulunca
  /// otomatik normal calisir.
  bool _broken = false;

  Future<void> _safe(Future<void> Function() op) async {
    if (_broken) return;
    try {
      await op();
    } catch (e) {
      _broken = true;
      debugPrint('CrashReporter devre dışı (platform hatası): $e');
    }
  }

  @override
  Future<void> initialize({required bool consentGiven}) async {
    _consent = consentGiven;
    // Debug modunda asla toplama (geliştirme gürültüsü + gizlilik)
    final enabled = consentGiven && !kDebugMode;
    await _safe(() => _crashlytics.setCrashlyticsCollectionEnabled(enabled));
  }

  @override
  Future<void> setConsent(bool consentGiven) async {
    _consent = consentGiven;
    await _safe(() => _crashlytics
        .setCrashlyticsCollectionEnabled(consentGiven && !kDebugMode));
  }

  @override
  void recordFlutterError(Object error, StackTrace stack) {
    if (!_consent || _broken) return;
    final scrubbed = FlutterErrorDetails(
      exception: _ScrubbedException(_scrub(error.toString())),
      stack: stack,
    );
    _safe(() async => _crashlytics.recordFlutterError(scrubbed));
  }

  @override
  Future<void> recordError(Object error, StackTrace? stack,
      {bool fatal = false}) async {
    if (!_consent || _broken) return;
    await _safe(() => _crashlytics.recordError(
          _ScrubbedException(_scrub(error.toString())),
          stack,
          fatal: fatal,
        ));
  }

  @override
  void log(String breadcrumb) {
    if (!_consent || _broken) return;
    _safe(() async => _crashlytics.log(_scrub(breadcrumb)));
  }

  /// Hata metnindeki olası PII'yi maskele.
  /// Mükemmel değil ama yaygın sızıntı kalıplarını yakalar.
  String _scrub(String input) {
    var s = input;
    // E-posta
    s = s.replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), '<email>');
    // Firebase UID benzeri (20-32 alfanümerik)
    s = s.replaceAll(RegExp(r'\b[A-Za-z0-9]{20,32}\b'), '<id>');
    // Base64 token benzeri uzun diziler
    s = s.replaceAll(RegExp(r'\b[A-Za-z0-9+/=]{40,}\b'), '<token>');
    // chatId kalıbı: uid_uid
    s = s.replaceAll(
        RegExp(r'\b[A-Za-z0-9]{6,}_[A-Za-z0-9]{6,}\b'), '<chatId>');
    return s;
  }
}

/// Orijinal exception tipini sızdırmadan temizlenmiş mesaj taşır.
class _ScrubbedException implements Exception {
  final String message;
  _ScrubbedException(this.message);
  @override
  String toString() => message;
}
