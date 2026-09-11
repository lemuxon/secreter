import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/e2ee_session_service.dart';

/// E2EE anahtar KAPSAMININ hesap yaşam döngüsüyle ilişkisi.
///
/// 🐞 REGRESYON: Gönderilen mesajların düz metni `_accountScope` ön ekiyle
/// saklanır (`e2ee_plain_<scope>_<messageId>`). Kapsam yalnızca
/// `main.dart` açılışında ve `switchAccount`ta ayarlanıyordu —
/// `register()` ayarlamıyor, `signOut()` de sıfırlamıyordu.
///
/// Sonuç iki türlü bozuluyordu:
///
///  1. Yeni hesapta gönderilen mesajın düz metni YANLIŞ ön ekle yazılıyor;
///     uygulama yeniden açılınca `main.dart` kapsamı doğru uid'e çekiyor
///     ve kayıt ERİŞİLEMEZ oluyor. Gönderen kendi mesajını "bu mesaj
///     cihazda çözülemiyor" olarak görüyordu.
///  2. "Hesap ekle" akışı signOut + register olduğu için yeni hesabın
///     verisi ESKİ hesabın ön ekiyle yazılıyordu — kapsamlamanın
///     önlemek için var olduğu sızıntının ta kendisi.
///
/// Buradaki testler kapsamın kendisinin doğru davrandığını sabitler;
/// `AuthService` statik Firebase tekillerine bağlı olduğu için
/// `register()`/`signOut()` doğrudan test edilemiyor (bkz. DEVAM.md).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    E2EESessionService.clearMemoryCache();
  });

  test('düz metin YAZILDIĞI kapsamda okunur', () async {
    E2EESessionService.setActiveAccount('hesapA');
    await E2EESessionService.cachePlaintext('m1', 'A gizli');

    expect(await E2EESessionService.getPlaintext('m1'), 'A gizli');
  });

  test('BAŞKA hesabın kapsamından okunamaz', () async {
    E2EESessionService.setActiveAccount('hesapA');
    await E2EESessionService.cachePlaintext('m1', 'A gizli');

    E2EESessionService.setActiveAccount('hesapB');

    expect(await E2EESessionService.getPlaintext('m1'), isNull,
        reason: 'hesaplar arası düz metin sızıntısı olmamalı');
  });

  test('YANLIŞ kapsamda yazılan metin, doğru kapsamda KAYBOLUR', () async {
    // Hatanın somut ölçüsü: kayıt sırasında kapsam ayarlanmazsa metin
    // "önceki hesabın" (ya da '_') ön ekiyle yazılır. Açılışta main.dart
    // kapsamı gerçek uid'e çeker ve kayıt erişilemez olur.
    E2EESessionService.setActiveAccount(null); // kayıt sırasındaki hâl
    await E2EESessionService.cachePlaintext('m1', 'yeni hesabın mesajı');

    // Uygulama yeniden açıldı: main.dart doğru uid'i kurar.
    E2EESessionService.setActiveAccount('yeniHesap');

    expect(await E2EESessionService.getPlaintext('m1'), isNull,
        reason: 'kendi mesajını "çözülemiyor" gösteren yol tam olarak budur');
  });

  test('kapsam DOĞRU kurulduysa yeniden açılışta metin durur', () async {
    // Düzeltmenin sağladığı hâl: register() kapsamı kendisi kurar.
    E2EESessionService.setActiveAccount('yeniHesap');
    await E2EESessionService.cachePlaintext('m1', 'yeni hesabın mesajı');

    // Yeniden açılış: main.dart aynı uid'i kurar.
    E2EESessionService.setActiveAccount(null);
    E2EESessionService.setActiveAccount('yeniHesap');

    expect(await E2EESessionService.getPlaintext('m1'), 'yeni hesabın mesajı',
        reason: 'aynı kapsamda yazılan metin yeniden açılışta okunabilmeli');
  });

  test('null kapsam, önceki hesabın kapsamından AYRIDIR', () async {
    // signOut() kapsamı null'a düşürmezse, sonraki register() eski uid'in
    // ön ekiyle yazmaya devam eder.
    E2EESessionService.setActiveAccount('eskiHesap');
    await E2EESessionService.cachePlaintext('m1', 'eski hesabın mesajı');

    E2EESessionService.setActiveAccount(null); // signOut()

    expect(await E2EESessionService.getPlaintext('m1'), isNull,
        reason: 'çıkıştan sonra eski hesabın metni görünmemeli');
  });

  test('kapsam değişimi BELLEK önbelleğini de temizler', () async {
    E2EESessionService.setActiveAccount('hesapA');
    await E2EESessionService.cachePlaintext('m1', 'A gizli');
    // Belleğe alınmış olabilir; kapsam değişince taşınmamalı.
    E2EESessionService.setActiveAccount('hesapB');
    expect(await E2EESessionService.getPlaintext('m1'), isNull);
    E2EESessionService.setActiveAccount('hesapA');
    expect(await E2EESessionService.getPlaintext('m1'), 'A gizli',
        reason: 'kendi kapsamına dönünce metin yine okunabilmeli');
  });
}
