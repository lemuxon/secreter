import 'package:flutter/services.dart';

/// Native güvenlik fonksiyonlarına method channel köprüsü.
/// MainActivity.kt'deki "com.gizlichat.app/security" kanalıyla konuşur.
class NativeSecurityBridge {
  static const _channel = MethodChannel('com.gizlichat.app/security');

  /// FLAG_SECURE ETIKET-TABANLI referans sayimi.
  /// Birden fazla ekran ayni anda korumayi isteyebilir ( or. DM ekrani +
  /// tam-ekran foto + kullanici tercihi). Herhangi bir "tutucu" etiket varsa
  /// bayrak ACIK kalir; ancak TUM tutucular birakilinca kapanir. Bu, eski
  /// hataliyi (foto kapaninca global korumanin kapanmasi) tamamen cozer.
  static final Set<String> _holders = {};

  static Future<void> acquire(String tag) async {
    final wasEmpty = _holders.isEmpty;
    _holders.add(tag);
    if (wasEmpty) await _setNative(true);
  }

  static Future<void> release(String tag) async {
    if (!_holders.remove(tag)) return;
    if (_holders.isEmpty) await _setNative(false);
  }

  static Future<void> _setNative(bool enable) async {
    try {
      await _channel.invokeMethod('setSecureFlag', {'enable': enable});
    } catch (_) {
      // iOS'ta veya kanal yoksa sessizce geç
    }
  }

  /// Native debugger bağlı mı?
  static Future<bool> isDebuggerAttached() async {
    try {
      return await _channel.invokeMethod<bool>('isDebuggerAttached') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Frida portu açık mı? (hooking tespiti)
  static Future<bool> isFridaDetected() async {
    try {
      return await _channel.invokeMethod<bool>('checkFridaPort') ?? false;
    } catch (_) {
      return false;
    }
  }
}
