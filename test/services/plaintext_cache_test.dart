import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/e2ee_session_service.dart';

/// Çözülmüş düz metnin cihazdaki yaşam döngüsü.
///
/// Ratchet tek yönlü olduğu için okunabilir metin cihazda tutulmak
/// ZORUNDA. Kritik olan, mesaj silindiğinde/süresi dolduğunda bu kopyanın
/// DA silinmesi — aksi halde "kaybolan mesaj" bir yanılsamadır (C-07).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    E2EESessionService.clearMemoryCache();
    E2EESessionService.setActiveAccount('u1');
  });

  const rev1 = 'm1#2026-08-18T20:00:00.000Z';
  const rev2 = 'm1#2026-08-18T21:30:00.000Z';

  test('düz metin yazılır ve okunur', () async {
    await E2EESessionService.cachePlaintext('m1', 'orijinal');
    expect(await E2EESessionService.getPlaintext('m1'), 'orijinal');
  });

  test('forgetPlaintext DÜZENLEME SÜRÜMLERİNİ de siler', () async {
    // ⚠️ REGRESYON KORUMASI: düzenlenen mesajın metni "<id>#<zaman>"
    // anahtarıyla saklanır. Yalnızca ham kimliği silmek, mesaj
    // silindikten sonra düzenlenmiş metnin cihazda OKUNABİLİR
    // kalmasına yol açardı.
    await E2EESessionService.cachePlaintext('m1', 'orijinal');
    await E2EESessionService.cachePlaintext(rev1, 'ilk düzeltme');
    await E2EESessionService.cachePlaintext(rev2, 'ikinci düzeltme');
    await E2EESessionService.cachePlaintext('m2', 'başka mesaj');

    await E2EESessionService.forgetPlaintext('m1');

    expect(await E2EESessionService.getPlaintext('m1'), isNull);
    expect(await E2EESessionService.getPlaintext(rev1), isNull,
        reason: 'düzenlenmiş metin cihazda kalmamalı');
    expect(await E2EESessionService.getPlaintext(rev2), isNull);
    expect(await E2EESessionService.getPlaintext('m2'), 'başka mesaj',
        reason: 'başka mesajlara dokunulmamalı');
  });

  test('benzer kimlikli mesaj yanlışlıkla silinmez', () async {
    // "m1" silinirken "m10" da gitmemeli — önek eşleşmesi '#' ile
    // sınırlandırılmıştır.
    await E2EESessionService.cachePlaintext('m1', 'bir');
    await E2EESessionService.cachePlaintext('m10', 'on');

    await E2EESessionService.forgetPlaintext('m1');

    expect(await E2EESessionService.getPlaintext('m1'), isNull);
    expect(await E2EESessionService.getPlaintext('m10'), 'on');
  });

  test('toplu silme sürümleri de kapsar', () async {
    await E2EESessionService.cachePlaintext('m1', 'bir');
    await E2EESessionService.cachePlaintext(rev1, 'bir düzeltme');
    await E2EESessionService.cachePlaintext('m2', 'iki');

    await E2EESessionService.forgetPlaintexts(['m1', 'm2']);

    expect(await E2EESessionService.getPlaintext('m1'), isNull);
    expect(await E2EESessionService.getPlaintext(rev1), isNull);
    expect(await E2EESessionService.getPlaintext('m2'), isNull);
  });

  test('wipeAllPlaintexts hepsini siler', () async {
    await E2EESessionService.cachePlaintext('m1', 'bir');
    await E2EESessionService.cachePlaintext(rev1, 'bir düzeltme');

    await E2EESessionService.wipeAllPlaintexts();

    expect(await E2EESessionService.getPlaintext('m1'), isNull);
    expect(await E2EESessionService.getPlaintext(rev1), isNull);
  });

  test('hesap kapsamı ayrıdır — başka hesabın metni görünmez', () async {
    await E2EESessionService.cachePlaintext('m1', 'u1 metni');

    E2EESessionService.setActiveAccount('u2');
    expect(await E2EESessionService.getPlaintext('m1'), isNull,
        reason: 'çoklu hesapta düz metin sızıntısı olmamalı');

    E2EESessionService.setActiveAccount('u1');
    expect(await E2EESessionService.getPlaintext('m1'), 'u1 metni');
  });
}
