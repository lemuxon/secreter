/// Kilitlenme/hata raporlama soyutlaması.
///
/// Sağlayıcıdan bağımsız: arkasında Crashlytics, Sentry (hatta self-host
/// Sentry) veya hiçbir şey (NoOp) olabilir. Sağlayıcı değişse bile
/// uygulama kodu değişmez.
///
/// GİZLİLİK: Tüm raporlama kullanıcı ONAYINA bağlıdır (opt-in). Onay
/// verilmeden hiçbir veri cihazdan çıkmaz.
abstract class CrashReporter {
  /// Raporlamayı başlat (onay verildiyse aktif olur)
  Future<void> initialize({required bool consentGiven});

  /// Kullanıcı onayını güncelle (ayarlardan)
  Future<void> setConsent(bool consentGiven);

  /// Flutter framework hatası kaydet
  void recordFlutterError(Object error, StackTrace stack);

  /// Genel (async) hata kaydet
  Future<void> recordError(Object error, StackTrace? stack,
      {bool fatal = false});

  /// Bağlam kırıntısı ekle (PII İÇERMEMELİ)
  void log(String breadcrumb);
}
