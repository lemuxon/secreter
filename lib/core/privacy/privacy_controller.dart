import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../di/injection.dart';
import '../observability/crash_reporter.dart';
import 'privacy_settings.dart';
import '../../core/observability/handled_error.dart';

/// Gizlilik ayarlarını yönetir (Hive'da kalıcı).
///
/// Telemetri onayı değiştiğinde CrashReporter'a anında yansıtır —
/// kullanıcı kapatırsa veri akışı hemen durur.
class PrivacyController extends StateNotifier<PrivacySettings> {
  static const _boxName = 'privacy_settings';
  static const _key = 'settings';

  final CrashReporter _crashReporter;

  PrivacyController(this._crashReporter) : super(const PrivacySettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      final raw = box.get(_key);
      if (raw != null) {
        state = PrivacySettings.fromMap(Map<String, dynamic>.from(raw));
        // Onayı reporter'a uygula
        await _crashReporter.setConsent(state.crashReportingConsent);
      }
    } catch (e, s) {
      // Varsayılan (gizlilik-önce) kalır — ama sessiz kalma.
      // ⚠️ Kullanıcının KENDİ SEÇİMLERİ o oturumda hiç uygulanmaz:
      // ayarlar ekranı varsayılanları gösterir ve kullanıcı ayarlarının
      // durduğunu sanır. Varsayılan gizlilik-önce olduğu için yön
      // güvenlidir, ama "sessiz kalma" yorumu bugüne kadar yalnızca
      // hata ayıklama konsoluna yazmakla yerine getiriliyordu.
      reportHandled('Gizlilik ayarları okunamadı — VARSAYILANA DÜŞÜLDÜ', e,
          stack: s);
    }
    // Senkron okuyucu HER DURUMDA `state` ile hizalanır. Try içindeyken,
    // okuma yarıda hata verirse okuyucu hiç başlatılmıyor ve
    // repository'ler ayarların yanlış kopyasını görüyordu.
    getIt<PrivacySettingsReader>().update(state);
  }

  Future<void> _persist() async {
    // ── SIRALAMA KRİTİK ──
    // Senkron okuyucu ÖNCE güncellenir. Eskiden `put` ile aynı try
    // bloğundaydı: Hive hata verdiğinde (kutu açılamadı, disk dolu,
    // şifreleme anahtarı sorunu) okuyucu GÜNCELLENMİYOR ve kullanıcının
    // seçimi O OTURUMDA HİÇ uygulanmıyordu. Sonuç: arayüzde "okundu
    // bilgisi kapalı" yazarken uygulama okundu bilgisi göndermeye devam
    // ediyordu — üstelik hiçbir iz bırakmadan. Gizlilik odaklı bir
    // uygulamada kabul edilemez.
    getIt<PrivacySettingsReader>().update(state);
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      await box.put(_key, state.toMap());
    } catch (e, s) {
      // Kalıcılaştırma başarısız: ayar bu oturumda geçerli ama yeniden
      // başlatınca varsayılana (gizlilik-önce) döner. Sessiz yutmak,
      // "ayarım kaydedilmiyor" şikâyetini izsiz bırakırdı.
      // ⚠️ §4j ile aynı sınıf: kullanıcı ayarı değiştirdiğini görür,
      // yeniden başlatınca varsayılana döner.
      reportHandled('Gizlilik ayarı kaydedilemedi', e, stack: s);
    }
  }

  Future<void> setReadReceipts(bool value) async {
    state = state.copyWith(sendReadReceipts: value);
    await _persist();
  }

  Future<void> setTypingIndicator(bool value) async {
    state = state.copyWith(sendTypingIndicator: value);
    await _persist();
  }

  Future<void> setPresence(bool value) async {
    state = state.copyWith(sharePresence: value);
    await _persist();
  }

  Future<void> setCoarseTimestamps(bool value) async {
    state = state.copyWith(coarseTimestamps: value);
    await _persist();
  }

  /// Telemetri onayı — reporter'a anında yansır
  Future<void> setCrashReportingConsent(bool value) async {
    state = state.copyWith(crashReportingConsent: value);
    await _crashReporter.setConsent(value);
    await _persist();
  }

  /// Tek dokunuşla maksimum gizlilik
  Future<void> applyMaxPrivacy() async {
    state = PrivacySettings.maxPrivacy();
    await _crashReporter.setConsent(false);
    await _persist();
  }
}

final privacyControllerProvider =
    StateNotifierProvider<PrivacyController, PrivacySettings>(
  (ref) => PrivacyController(getIt<CrashReporter>()),
);

/// Senkron erişim gerekenler için (örn. repository içinde) basit okuyucu.
/// Not: repository'ler getIt'ten okuyabilsin diye DI'a da kaydedilir.
class PrivacySettingsReader {
  PrivacySettings _current = const PrivacySettings();
  PrivacySettings get current => _current;
  void update(PrivacySettings s) => _current = s;
}
