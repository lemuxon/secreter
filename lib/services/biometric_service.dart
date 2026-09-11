import 'package:local_auth/local_auth.dart';

/// Parmak izi / yüz tanıma kimlik doğrulaması
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Cihaz biyometrik destekliyor mu?
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Kayıtlı biyometrik türlerini al (parmak izi, yüz...)
  static Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Biyometrik doğrulama iste.
  ///
  /// [reason] ÇEVRİLMİŞ metin olmalıdır. Eski imza varsayılan olarak
  /// `'biometric_prompt'` çeviri ANAHTARINI geçiyordu; çağıranlar
  /// çevirmediğinde kullanıcı sistem diyalogunda ham anahtarı görüyordu.
  /// Varsayılan artık okunabilir bir metin ve parametre zorunlu tutuluyor.
  static Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason.isEmpty ? 'Kimliğini doğrula' : reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          // Cihaz PIN/desen'ine de izin ver: `biometricOnly: true`,
          // parmak izi kaydı olmayan kullanıcıları TAMAMEN dışlıyordu.
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
