import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/security/app_disguise_service.dart';

/// 🥸 Uygulama kılığı — Dart katmanı.
///
/// Yerli tarafı (PackageManager bileşen durumu) birim testte
/// çalıştırılamaz; burada ölçülen şey KÖPRÜNÜN DÜRÜSTLÜĞÜ: başarısızlık
/// asla "başarılı" gibi raporlanmamalı. Bu özellikte yanlış güven,
/// özelliğin hiç olmamasından tehlikelidir — kullanıcı gizlendiğini
/// sanıp gizlenmemiş olur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.gizlichat.app/security');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(Future<Object?>? Function(MethodCall) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('durum okuma', () {
    test('yerli taraf true derse kılık AÇIK', () async {
      mock((c) async => c.method == 'isDisguised' ? true : null);
      expect(await AppDisguiseService.isDisguised(), isTrue);
    });

    test('yerli taraf null dönerse KAPALI sayılır', () async {
      // Belirsizlikte "gizli" varsaymak yanlış güven üretirdi.
      mock((c) async => null);
      expect(await AppDisguiseService.isDisguised(), isFalse);
    });

    test('platform hatasında KAPALI sayılır, patlamaz', () async {
      mock((c) async => throw PlatformException(code: 'BOOM'));
      expect(await AppDisguiseService.isDisguised(), isFalse);
    });
  });

  group('durum değiştirme', () {
    test('başarılı çağrı true döner ve doğru argümanı geçirir', () async {
      MethodCall? seen;
      mock((c) async {
        seen = c;
        return true;
      });

      expect(await AppDisguiseService.setDisguised(true), isTrue);
      expect(seen?.method, 'setDisguise');
      expect((seen?.arguments as Map)['enabled'], isTrue);
    });

    test('kapatma da iletilir', () async {
      MethodCall? seen;
      mock((c) async {
        seen = c;
        return true;
      });

      await AppDisguiseService.setDisguised(false);
      expect((seen?.arguments as Map)['enabled'], isFalse);
    });

    test('BAŞARISIZLIK sessizce başarı sayılmaz', () async {
      // ⚠️ En kritik davranış: arayüz bunu görüp kullanıcıyı
      // uyarabilmeli.
      mock((c) async => throw PlatformException(code: 'DISGUISE_FAILED'));
      expect(await AppDisguiseService.setDisguised(true), isFalse);
    });

    test('kanal yoksa (Android dışı) false döner', () async {
      mock((c) async => throw MissingPluginException());
      expect(await AppDisguiseService.setDisguised(true), isFalse);
      expect(await AppDisguiseService.isDisguised(), isFalse);
    });
  });
}
