import 'package:equatable/equatable.dart';

/// Tek bir güvenlik tehdidi türü.
enum SecurityThreat {
  rootedOrJailbroken, // Cihaz root'lu / jailbreak'li
  emulator, // Emulator üzerinde çalışıyor
  developerMode, // Geliştirici modu açık
  hookingFramework, // Frida / Xposed / Magisk tespit edildi
  debuggerAttached, // Debugger bağlı
}

extension SecurityThreatInfo on SecurityThreat {
  /// Başlık ÇEVİRİ ANAHTARI.
  ///
  /// ⚠️ Burada sabit Türkçe metin döndürülüyordu ve bu metinler
  /// `SecurityWarningScreen`'de doğrudan gösteriliyordu — yani uygulama
  /// 8 dil desteklemesine rağmen güvenlik uyarıları HER DİLDE Türkçe
  /// görünüyordu. Domain katmanında `BuildContext` olmadığı için (ve
  /// olmaması gerektiği için) anahtar döndürülür; çeviriyi sunum katmanı
  /// `context.tr(...)` ile yapar. Bu, projedeki `Failure.message`
  /// deseniyle aynıdır.
  String get titleKey {
    switch (this) {
      case SecurityThreat.rootedOrJailbroken:
        return 'threat_root_t';
      case SecurityThreat.emulator:
        return 'threat_emulator_t';
      case SecurityThreat.developerMode:
        return 'threat_devmode_t';
      case SecurityThreat.hookingFramework:
        return 'threat_hook_t';
      case SecurityThreat.debuggerAttached:
        return 'threat_debugger_t';
    }
  }

  /// Açıklama ÇEVİRİ ANAHTARI.
  String get descriptionKey {
    switch (this) {
      case SecurityThreat.rootedOrJailbroken:
        return 'threat_root_d';
      case SecurityThreat.emulator:
        return 'threat_emulator_d';
      case SecurityThreat.developerMode:
        return 'threat_devmode_d';
      case SecurityThreat.hookingFramework:
        return 'threat_hook_d';
      case SecurityThreat.debuggerAttached:
        return 'threat_debugger_d';
    }
  }

  /// Bu tehdit uygulamayı engellemeli mi, yoksa sadece uyarı mı?
  /// Root ve hooking ciddi; emulator/dev mode genelde uyarı.
  bool get isCritical {
    switch (this) {
      case SecurityThreat.rootedOrJailbroken:
      case SecurityThreat.hookingFramework:
      case SecurityThreat.debuggerAttached:
        return true;
      case SecurityThreat.emulator:
      case SecurityThreat.developerMode:
        return false;
    }
  }
}

/// Güvenlik taraması sonucu.
class SecurityCheckResult extends Equatable {
  final List<SecurityThreat> threats;

  const SecurityCheckResult(this.threats);

  const SecurityCheckResult.safe() : threats = const [];

  bool get isSafe => threats.isEmpty;
  bool get hasCriticalThreat => threats.any((t) => t.isCritical);
  List<SecurityThreat> get criticalThreats =>
      threats.where((t) => t.isCritical).toList();
  List<SecurityThreat> get warnings =>
      threats.where((t) => !t.isCritical).toList();

  @override
  List<Object?> get props => [threats];
}

/// Güvenlik kontrolü soyutlaması.
///
/// ⚠️ ÖNEMLİ: Bu kontroller mutlak güvenlik sağlamaz. Kararlı bir saldırgan
/// (Magisk Hide, Frida gadget, yeniden paketleme) bunları atlatabilir.
/// Bu, sıradan tehditleri eleyen bir "yükseltme bariyeri"dir, tek başına
/// güvenlik garantisi değildir.
abstract class SecurityService {
  /// Tam güvenlik taraması yap
  Future<SecurityCheckResult> performSecurityCheck();

  /// Sadece kritik tehdit var mı? (hızlı kontrol)
  Future<bool> hasCriticalThreat();
}
