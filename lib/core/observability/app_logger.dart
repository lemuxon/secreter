import 'package:flutter/foundation.dart';

/// Uygulama günlükleme soyutlaması — **yalnızca hata kaydı**.
///
/// ── NEDEN SADECE `error` VAR ──
/// Bu arayüzde bir zamanlar `debug`/`info`/`warning` de vardı ve HİÇBİRİ
/// çağrılmıyordu; `AppLogger`ın tek kullanıcısı [reportHandled] ve o da
/// yalnızca `error`a iniyor. Çağrılmayan üç metot, arayüze bakan bir
/// sonraki geliştiriciye "burası genel amaçlı bir günlükçü, `logger.info`
/// yazabilirim" diyen ÖLÜ BİR YAZMA YÜZEYİYDİ.
///
/// Bu projede aynı desen üç kez zarar verdi (§4i, §4o, §4t): ölü bir yol
/// bırakıldığında bir sonraki değişiklik onu canlı sanıp oraya yazdı.
/// Burada da bedeli somut olurdu — `logger.info('sohbet $chatId açıldı')`
/// gibi bir satır, hiçbir maskeleme kapısından geçmeden tanımlayıcı
/// loglardı. Yüzey daraltıldı: günlüğe bir şey yazmanın TEK yolu
/// [reportHandled] geçidinden geçmektir.
///
/// GİZLİLİK İLKESİ: Bu logger asla mesaj içeriği, kullanıcı adı, chatId
/// veya UID gibi hassas veriyi düz metin loglamaz. [Redact] yardımcısı
/// bu tür değerleri maskeler.
abstract class AppLogger {
  void error(String message, {Object? error, StackTrace? stackTrace});
}

/// Hassas değerleri maskeleme yardımcıları.
class Redact {
  /// UID/chatId gibi tanımlayıcıları kısalt: "a1b2c3d4..." → "a1b2…"
  static String id(String? value) {
    if (value == null || value.isEmpty) return 'null';
    if (value.length <= 4) return '••••';
    return '${value.substring(0, 4)}…';
  }

  /// Kullanıcı adını maskele: "ahmet" → "a••••"
  static String username(String? value) {
    if (value == null || value.isEmpty) return 'null';
    return '${value[0]}${'•' * (value.length - 1).clamp(1, 6)}';
  }

  /// İçeriği asla loglamadan sadece uzunluğunu bildir
  static String content(String? value) {
    if (value == null) return 'null';
    return '<${value.length} karakter>';
  }
}

/// Geliştirme ortamı için konsol logger'ı (sadece debug modunda yazar).
class ConsoleLogger implements AppLogger {
  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    // ⚠️ Üretimde konsola YAZMA. Yığın izi ve hata metni tanımlayıcı
    // taşıyabilir; `adb logcat` cihazdaki başka uygulamalara da açıktır.
    if (!kDebugMode) return;
    debugPrint('❌ ERROR: $message${error == null ? '' : ' {error: $error}'}');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }
}
