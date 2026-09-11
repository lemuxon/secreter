import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'app_logger.dart';
import 'crash_reporter.dart';

/// 🔦 YUTULAN HATALARI GÖRÜNÜR KILAR.
///
/// ── NEDEN VAR ──
/// Bu projede bulunan büyük hataların ORTAK ÖZELLİĞİ sessiz olmalarıydı:
/// şifreleme düz metne düşüyordu (C-06), kimlik değişimi tüm mesajları
/// çözülemez yapıyordu (§4e), gizlilik ayarı uygulanmıyordu (§4j), gelen
/// arama tamamen kırıktı (§4m), `claimPreKey` üretimde hiç yoktu (§4n).
/// Hiçbiri ÇÖKMEDİ — bu yüzden aylarca görünmediler.
///
/// Oysa hata görünürlüğü YALNIZCA çökmeler için kuruluydu: `CrashReporter`
/// sadece `FlutterError.onError` ve Zone'un yakalanmamış hata kancasına
/// bağlıydı. **Yakalanan** hiçbir hata telemetriye ulaşmıyordu; hepsi
/// `debugPrint` ile üretimde kimsenin okumadığı konsola yazılıyordu.
/// (`AppLogger` soyutlaması da kayıtlıydı ama HİÇ kullanılmıyordu.)
///
/// Bu fonksiyon o boşluğu kapatır: "çökmüyor ama çalışmıyor" sınıfı
/// artık raporlanabilir.
///
/// ── ⚠️ TELEMETRİYE HAM HATA METNİ GİTMEZ ──
/// Bu bir gizlilik uygulaması ve hata metinleri metadata sızdırır:
///
///     [cloud_firestore/permission-denied] ... /chats/uidA_uidB/messages/m1
///
/// Böyle bir satırı Crashlytics'e yollamak, sohbet dokümanından
/// kullanıcı adlarını kaldırmak (§4o) için harcanan işi tek hamlede
/// geri verirdi. Bu yüzden dışarı YALNIZCA iki şey çıkar:
///   1. `what` — geliştiricinin yazdığı SABİT etiket (değişken içermez)
///   2. hatanın imzası — `FirebaseException.code` (ör. `permission-denied`)
///      ya da tip adı. Kodlar tanımlayıcı değildir.
/// Ham metin ve `context` yalnızca CİHAZDAKİ hata ayıklama konsoluna
/// yazılır, cihazdan çıkmaz.
///
/// Raporlama ayrıca kullanıcı ONAYINA bağlıdır (varsayılan KAPALI);
/// onay yoksa `CrashReporter` zaten hiçbir şey göndermez.
///
/// ── ARIZA-EMNİYETLİ ──
/// Telemetri hiçbir koşulda uygulamayı bozamaz: her şey try/catch içinde
/// ve DI hazır değilse konsola düşer. Bir hatayı raporlarken hata
/// fırlatmak, düzeltmeye çalıştığımız sorunun ta kendisi olurdu.
///
/// ── KULLANIM ──
/// ```dart
/// } catch (e, s) {
///   reportHandled('Grup anahtarı rotasyonu başarısız', e, stack: s);
/// }
/// ```
/// `what` SABİT bir dize olmalı — içine chatId/uid/ad koyma. Bunlar
/// gerekiyorsa `context`e koy; orası cihazdan çıkmaz.
void reportHandled(
  String what,
  Object error, {
  StackTrace? stack,
  Map<String, Object?>? context,
}) {
  // 1) Yerel: geliştiricinin gördüğü tam ayrıntı (cihazdan çıkmaz).
  try {
    if (GetIt.I.isRegistered<AppLogger>()) {
      GetIt.I<AppLogger>().error(what, error: error, stackTrace: stack);
    } else {
      debugPrint('$what: $error');
    }
    if (context != null && context.isNotEmpty && kDebugMode) {
      debugPrint('  bağlam: $context');
    }
  } catch (_) {
    // Günlükleme bile başarısızsa yapacak bir şey yok; akışı kırma.
  }

  // 2) Uzak: yalnızca etiket + hata imzası, onaya bağlı.
  try {
    if (!GetIt.I.isRegistered<CrashReporter>()) return;
    GetIt.I<CrashReporter>().recordError(
      _HandledSignal(what, errorSignature(error)),
      stack,
      fatal: false,
    );
  } catch (_) {
    // Raporlayıcı arızalıysa uygulama etkilenmemeli.
  }
}

/// Hatanın TANIMLAYICI İÇERMEYEN imzası.
///
/// `FirebaseException` için `code` alınır (`permission-denied`,
/// `unavailable`, `failed-precondition` …) — bunlar sabit sözlükten gelir
/// ve kullanıcıya ait veri taşımaz. Diğer her şey için yalnızca tip adı.
/// Serbest metin ASLA dahil edilmez.
@visibleForTesting
String errorSignature(Object error) {
  if (error is FirebaseException) {
    final code = error.code;
    return code.isEmpty ? '${error.runtimeType}' : '${error.runtimeType}/$code';
  }
  return '${error.runtimeType}';
}

/// Telemetriye giden nesne. `toString()` dışarı çıkan TEK metindir.
class _HandledSignal implements Exception {
  final String what;
  final String signature;

  const _HandledSignal(this.what, this.signature);

  @override
  String toString() => '$what [$signature]';
}
