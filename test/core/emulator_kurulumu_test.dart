import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/emulator_kurulumu.dart';

/// 🧪 Emülatör modunun KAPALI olduğunu ve açılırsa doğru adrese
/// gittiğini ölçer.
///
/// Asıl korunan şey ikinci grup: `--dart-define` sürüm derlemesinde de
/// geçerlidir ve `USE_EMULATOR=true` ile çıkılan bir APK sessizce
/// tamamen çalışmaz hâle gelir.
void main() {
  group('varsayılan — bayrak verilmeden', () {
    test('emülatör modu KAPALI', () {
      // Testler --dart-define olmadan koşar: varsayılan false olmalı.
      // Bu değer true'ya kayarsa normal derlemeler de emülatöre gider.
      expect(kEmulatorKullan, isFalse);
      expect(emulatorEtkinMi, isFalse);
    });

    test('sürümde izin bayrağı da KAPALI', () {
      expect(kEmulatorSurumdeIzinli, isFalse);
    });

    test('bağlanma çağrısı kapalıyken hata atmaz', () async {
      // Firebase başlatılmamış bir ortamda bile güvenle çağrılabilmeli;
      // main.dart savunmacı boot kuralı bunu gerektiriyor.
      await expectLater(emulatoreBagla(), completes);
    });
  });

  group('host çözümü', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Android → 10.0.2.2 (emülatörden ana makineye)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(cozulmusEmulatorHost, '10.0.2.2');
    });

    test('Android dışı → localhost', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(cozulmusEmulatorHost, 'localhost');
    });
  });
}
