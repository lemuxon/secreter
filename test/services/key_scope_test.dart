import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/security/secure_store.dart';
import 'package:gizli_chat/services/key_management_service.dart';

/// E2EE KİMLİK anahtarlarının hesap kapsamı (§4au).
///
/// 🐞 ÜRETİM VERİSİNDE ÖLÇÜLDÜ: aynı cihazdaki iki hesabın `keyBundles`
/// belgeleri BİREBİR AYNI `identityKey` ve `signingPublicKey` taşıyordu.
/// Sebep: oturumlar/grup anahtarları/sohbet kilitleri uid ile
/// kapsamlanmışken KİMLİK anahtarları düz sabitlerdi
/// (`e2ee_identity_priv` gibi).
///
/// İKİ AYRI ARIZA:
///  1. Her hesap KENDİ imzalı ön-anahtarını yayımlar ama özel yarısı tek
///     yere yazılır → sonra yayımlayan öncekini EZER → karşı taraf eski
///     ön-anahtarla şifreleyince "bu mesaj cihazda çözülemiyor".
///  2. `keyBundles` giriş yapmış herkese açık; aynı kimlik anahtarı
///     "bu iki hesap aynı kişi" demek. Çoklu hesabın anlamını yok eder.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kimlikPriv = 'e2ee_identity_priv';
  const spkPriv = 'e2ee_spk_priv';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    KeyManagementService.setActiveAccount(null);
  });

  group('göç: kapsamsız dönemden kalan anahtarlar', () {
    Future<void> eskiAnahtarlariKoy() async {
      await SecureStore.write(kimlikPriv, 'ESKİ-KİMLİK');
      await SecureStore.write('e2ee_identity_pub', 'ESKİ-KİMLİK-PUB');
      await SecureStore.write(spkPriv, 'ESKİ-SPK');
      await SecureStore.write('e2ee_spk_id', 'spk_eski');
    }

    test('İLK hesap eski anahtarları DEVRALIR', () async {
      await eskiAnahtarlariKoy();
      KeyManagementService.setActiveAccount('hesapA');

      await KeyManagementService.adoptLegacyKeysIfAny();

      expect(await SecureStore.read('${kimlikPriv}_hesapA'), 'ESKİ-KİMLİK',
          reason: 'tek hesaplı kullanıcının kimliği KORUNMALI — yoksa '
              'çalışan tüm oturumları kırardık');
      expect(await SecureStore.read('${spkPriv}_hesapA'), 'ESKİ-SPK');
    });

    test('devirden sonra ESKİ kayıtlar SİLİNİR', () async {
      await eskiAnahtarlariKoy();
      KeyManagementService.setActiveAccount('hesapA');
      await KeyManagementService.adoptLegacyKeysIfAny();

      expect(await SecureStore.read(kimlikPriv), isNull,
          reason: 'silinmezse İKİNCİ hesap da devralır ve hata geri gelir');
      expect(await SecureStore.read(spkPriv), isNull);
    });

    test('🔴 İKİNCİ hesap aynı anahtarları DEVRALMAZ', () async {
      await eskiAnahtarlariKoy();

      KeyManagementService.setActiveAccount('hesapA');
      await KeyManagementService.adoptLegacyKeysIfAny();

      KeyManagementService.setActiveAccount('hesapB');
      await KeyManagementService.adoptLegacyKeysIfAny();

      expect(await SecureStore.read('${kimlikPriv}_hesapB'), isNull,
          reason: 'hatanın TA KENDİSİ buydu: iki hesap aynı kimliği '
              'paylaşınca mesajlar çözülemiyor ve hesaplar bağlanabilir '
              'hâle geliyor');
    });

    test('kimliği ZATEN olan hesap devralmaya kalkmaz', () async {
      await eskiAnahtarlariKoy();
      KeyManagementService.setActiveAccount('hesapA');
      await SecureStore.write('${kimlikPriv}_hesapA', 'KENDİ-KİMLİĞİ');

      await KeyManagementService.adoptLegacyKeysIfAny();

      expect(await SecureStore.read('${kimlikPriv}_hesapA'), 'KENDİ-KİMLİĞİ',
          reason: 'var olan kimliğin üzerine yazmak, çalışan oturumları '
              'sessizce kırardı');
      expect(await SecureStore.read(kimlikPriv), 'ESKİ-KİMLİK',
          reason: 'devir olmadıysa eskiler de silinmemeli');
    });

    test('devralınacak bir şey yoksa sessizce geçer', () async {
      KeyManagementService.setActiveAccount('hesapA');
      await KeyManagementService.adoptLegacyKeysIfAny();
      expect(await SecureStore.read('${kimlikPriv}_hesapA'), isNull);
    });
  });

  group('kapsam ayrımı', () {
    test('iki hesabın anahtarları BİRBİRİNİ GÖRMEZ', () async {
      KeyManagementService.setActiveAccount('hesapA');
      await SecureStore.write('${kimlikPriv}_hesapA', 'A-KİMLİK');

      KeyManagementService.setActiveAccount('hesapB');
      await SecureStore.write('${kimlikPriv}_hesapB', 'B-KİMLİK');

      expect(await SecureStore.read('${kimlikPriv}_hesapA'), 'A-KİMLİK');
      expect(await SecureStore.read('${kimlikPriv}_hesapB'), 'B-KİMLİK');
      expect(
          await SecureStore.read('${kimlikPriv}_hesapA') ==
              await SecureStore.read('${kimlikPriv}_hesapB'),
          isFalse,
          reason: 'aynı kimlik = hesaplar herkese açık şekilde bağlanabilir');
    });

    test('oturumsuz kapsam (null) ayrı bir alandır', () async {
      KeyManagementService.setActiveAccount(null);
      await SecureStore.write('${kimlikPriv}__', 'OTURUMSUZ');
      KeyManagementService.setActiveAccount('hesapA');
      expect(await SecureStore.read('${kimlikPriv}_hesapA'), isNull);
    });
  });
}
