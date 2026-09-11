import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'security_service.dart';
import 'native_security_bridge.dart';
import '../observability/handled_error.dart';

/// SecurityService'in somut implementasyonu.
///
/// safe_device paketini kullanır:
/// - emulator + root/jailbreak + geliştirici modu (donanım kontrolü)
///
/// ⚠️ Bu tespitler atlatılabilir (Magisk Hide vb.). Savunmanın tek
/// katmanı olmamalı — asıl koruma E2EE ve sunucu kurallarındadır.
class SecurityServiceImpl implements SecurityService {
  @override
  Future<SecurityCheckResult> performSecurityCheck() async {
    // Debug modunda kontrolleri atla (geliştirme kolaylığı)
    if (kDebugMode) {
      return const SecurityCheckResult.safe();
    }

    final threats = <SecurityThreat>[];

    // 1. Geliştirici modu (Android) — safe_device ile
    await _run('geliştirici modu', () async {
      if (await SafeDevice.isDevelopmentModeEnable) {
        threats.add(SecurityThreat.developerMode);
      }
    });

    // 2. Emulator
    await _run('emulator', () async {
      if (!await SafeDevice.isRealDevice) {
        threats.add(SecurityThreat.emulator);
      }
    });

    // 4. safe_device ek root kontrolü (çapraz doğrulama)
    await _run('root/jailbreak', () async {
      if (await SafeDevice.isJailBroken &&
          !threats.contains(SecurityThreat.rootedOrJailbroken)) {
        threats.add(SecurityThreat.rootedOrJailbroken);
      }
    });

    // 5. Hooking framework tespiti (Frida/Xposed/Magisk)
    // Native Frida port taraması (MainActivity.kt'deki checkFridaPort)
    await _run('hooking framework', () async {
      final fridaDetected = await NativeSecurityBridge.isFridaDetected();
      final heuristicHook = await _detectHookingFramework();
      if (fridaDetected || heuristicHook) {
        threats.add(SecurityThreat.hookingFramework);
      }
    });

    // 6. Native debugger tespiti
    await _run('debugger', () async {
      if (await NativeSecurityBridge.isDebuggerAttached()) {
        threats.add(SecurityThreat.debuggerAttached);
      }
    });

    return SecurityCheckResult(threats);
  }

  /// Tek bir dedektörü çalıştır.
  ///
  /// Her dedektör AYRI korunur: biri patlarsa taramanın tamamı düşmesin.
  /// Ama hata SESSİZCE YUTULMAZ — kalıcı olarak başarısız olan bir
  /// dedektör, uygulamanın "tehdit yok" demesine yol açar ve eskiden bu
  /// hiçbir yerde görünmüyordu. Güvenlik tarayıcısının sessizce
  /// çalışmaması, tehdit bulmamasıyla aynı şey değildir.
  static Future<void> _run(String name, Future<void> Function() check) async {
    try {
      await check();
    } catch (e, s) {
      // §4j: dedektörün sessizce çökmesi, korumanın hiç çalışmaması
      // demekti ve fark edilmiyordu.
      reportHandled('Güvenlik dedektörü çalışmadı', e,
          stack: s, context: {'dedektör': name});
    }
  }

  @override
  Future<bool> hasCriticalThreat() async {
    final result = await performSecurityCheck();
    return result.hasCriticalThreat;
  }

  /// Hooking framework için sezgisel tespit.
  ///
  /// NOT: Bu basitleştirilmiş bir kontrol. Production'da native katmanda
  /// (Kotlin/C++) şunlar yapılmalı:
  /// - Frida default portu (27042) taraması
  /// - /proc/self/maps içinde frida/xposed kütüphane kontrolü
  /// - Magisk dosya yollarının kontrolü (/sbin/magisk vb.)
  /// Bunlar method channel ile çağrılır. Şimdilik paket kontrollerine
  /// güveniyoruz.
  Future<bool> _detectHookingFramework() async {
    // safe_device geliştirici modu + sanal ortam sinyallerini kontrol eder
    try {
      final isDevMode = await SafeDevice.isDevelopmentModeEnable;
      final isRealDevice = await SafeDevice.isRealDevice;
      // Geliştirici modu + gerçek olmayan cihaz = yüksek hook riski
      return isDevMode && !isRealDevice;
    } catch (_) {
      return false;
    }
  }
}
