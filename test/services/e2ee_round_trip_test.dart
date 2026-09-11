import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/security/secure_store.dart';
import 'package:gizli_chat/services/double_ratchet_service.dart';
import 'package:gizli_chat/services/e2ee_session_service.dart';

/// 🔴 EKSİK OLAN KAPI: İKİ TARAFLI EL SIKIŞMA (§4bb).
///
/// ── NEDEN YAZILDI ──
/// Şifreleme katmanı aylarca değişti (v2→v3 DH ratchet, hesap kapsamı,
/// oturum kurtarma, başlık taşıma) ve her değişiklik KENDİ parçasının
/// testiyle doğrulandı. Ama 422 testin HİÇBİRİ şu zinciri denemiyordu:
///
///     A oturumu başlatır → B başlıktan kurar → B CEVAP yazar
///                        → A o cevabı çözebilir mi?
///
///     $ grep -rl "establishFromHeader\|initiateSession" test/
///     (sonuç yok)
///
/// Kullanıcı dört turdur "karşı taraf bana yazamıyor" diyordu ve her
/// turda borunun başka bir parçasına bakılmıştı. Boru uçtan uca hiç
/// akıtılmamıştı.
///
/// ── NEDEN OTURUMLAR ELLE KURULUYOR ──
/// `initiateSession` Firestore'dan anahtar paketi çeker, `claimPreKey`
/// Cloud Function'ını çağırır. Birim testinde bunlar yok. Bu yüzden
/// İKİ TARAFIN BOOTSTRAP'I, üretim kodundaki adımların BİREBİR aynısıyla
/// burada kurulur (bkz. `initiateSession` / `establishFromHeader` v3
/// dalları). Sınanan şey bootstrap sonrası sözleşmedir: zincirler
/// birbirine oturuyor mu?
///
/// İki cihaz, aynı `chatId` altında farklı HESAP KAPSAMIYLA temsil edilir
/// (`setActiveAccount`), çünkü oturumlar `e2ee_session_{kapsam}_{chatId}`
/// anahtarıyla saklanır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const chatId = 'sohbet';
  const alice = 'alice';
  const bob = 'bob';

  String oturumAnahtari(String kapsam) => 'e2ee_session_${kapsam}_$chatId';

  /// Üretimdeki X3DH çıktısını taklit eder: iki tarafta da AYNI sır.
  List<int> ortakSir() => List<int>.generate(32, (i) => (i * 7 + 13) % 256);

  /// `initiateSession` (v3) ve `establishFromHeader` (v3) bootstrap'larını
  /// birebir kurar ve iki oturumu da depoya yazar.
  Future<void> ikiTarafiKur() async {
    FlutterSecureStorage.setMockInitialValues({});

    final sir = ortakSir();

    // B'nin imzalı ön-anahtar çifti — A bunu paketten alır, B'de özel
    // yarısı durur.
    final (bobSpkPriv, bobSpkPub) = await DoubleRatchetService.newDhKeyPair();

    // ── A (BAŞLATAN) — initiateSession v3 dalı ──
    final (aliceDhsPriv, aliceDhsPub) =
        await DoubleRatchetService.newDhKeyPair();
    final dhOut = await DoubleRatchetService.dh(aliceDhsPriv, bobSpkPub);
    final (rk, cks) = await DoubleRatchetService.kdfRoot(sir, dhOut);

    final aliceOturum = SessionState(
      sendingChainKey: cks,
      receivingChainKey: const [], // alma zinciri HENÜZ yok
      sendCounter: 0,
      recvCounter: 0,
      skipped: const {},
      peerIdentityKey: 'BOB_KIMLIK',
      rootKey: rk,
      dhsPriv: aliceDhsPriv,
      dhsPub: aliceDhsPub,
      dhrPub: bobSpkPub,
      // §4be: başlatan taraf gönderdiği başlığı SAKLAR ve oturum
      // onaylanana kadar her mesajla yeniden gönderir.
      pendingHeader: const {'ik': 'ALICE_KIMLIK', 'ek': 'ALICE_EFEMERAL'},
    );

    // ── B (CEVAPLAYAN) — establishFromHeader v3 dalı ──
    // İKİ zincir de BOŞ, `dhrPub` YOK. Alma zinciri, A'nın ilk mesajı
    // çözülürken atılan DH adımında kurulur.
    final bobOturum = SessionState(
      sendingChainKey: const [],
      receivingChainKey: const [],
      sendCounter: 0,
      recvCounter: 0,
      skipped: const {},
      peerIdentityKey: 'ALICE_KIMLIK',
      peerEphemeralKey: 'ALICE_EFEMERAL',
      rootKey: sir,
      dhsPriv: bobSpkPriv,
      dhsPub: bobSpkPub,
      // B de kendi başlığını taşıyor: ÇAPRAZ el sıkışma durumu. Testin
      // "onaylanınca susar" iddiası ancak böyle gerçekten ölçülür —
      // aksi hâlde null zaten başlık YOKLUĞUNDAN gelirdi.
      pendingHeader: const {'ik': 'BOB_KIMLIK', 'ek': 'BOB_EFEMERAL'},
    );

    await SecureStore.write(
        oturumAnahtari(alice), jsonEncode(aliceOturum.toJson()));
    await SecureStore.write(
        oturumAnahtari(bob), jsonEncode(bobOturum.toJson()));
  }

  Future<String?> sifrele(String kapsam, String metin) async {
    E2EESessionService.setActiveAccount(kapsam);
    return E2EESessionService.encryptMessage(chatId: chatId, plaintext: metin);
  }

  Future<String?> coz(String kapsam, String paket) async {
    E2EESessionService.setActiveAccount(kapsam);
    return E2EESessionService.decryptMessage(chatId: chatId, ciphertext: paket);
  }

  setUp(ikiTarafiKur);

  group('tek yön: başlatan → cevaplayan', () {
    test('A şifreler, B çözer', () async {
      final paket = await sifrele(alice, 'merhaba');
      expect(paket, isNotNull, reason: 'başlatanın gönderme zinciri hazır');

      expect(await coz(bob, paket!), 'merhaba');
    });

    test('A arka arkaya üç mesaj → B hepsini çözer', () async {
      final p1 = await sifrele(alice, 'bir');
      final p2 = await sifrele(alice, 'iki');
      final p3 = await sifrele(alice, 'üç');

      expect(await coz(bob, p1!), 'bir');
      expect(await coz(bob, p2!), 'iki');
      expect(await coz(bob, p3!), 'üç');
    });
  });

  group('🔴 ÇİFT YÖN — asıl sınanmayan yer', () {
    test('B cevap yazar, A onu ÇÖZEBİLMELİ', () async {
      // 1) A yazar, B okur → B'nin alma zinciri ve `dhrPub`ı kurulur.
      final p1 = await sifrele(alice, 'selam');
      expect(await coz(bob, p1!), 'selam');

      // 2) B cevap yazar → DH adımı atıp KENDİ gönderme zincirini kurmalı.
      final p2 = await sifrele(bob, 'sana da selam');
      expect(p2, isNotNull,
          reason: 'B, A\'nın mesajını çözdükten sonra yazabilmeli — null '
              'dönerse çağıran katman mesajı DÜZ METİN gönderir');

      // 3) A cevabı çözer → A'nın alma zinciri B'nin yeni DH anahtarıyla
      //    kurulmalı. ZİNCİRLER BURADA EŞLEŞMİYORSA sohbet tek yönlü olur.
      expect(await coz(alice, p2!), 'sana da selam');
    });

    test('karşılıklı sohbet bozulmadan sürer', () async {
      final a1 = await sifrele(alice, 'a1');
      expect(await coz(bob, a1!), 'a1');

      final b1 = await sifrele(bob, 'b1');
      expect(await coz(alice, b1!), 'b1');

      final a2 = await sifrele(alice, 'a2');
      expect(await coz(bob, a2!), 'a2');

      final b2 = await sifrele(bob, 'b2');
      expect(await coz(alice, b2!), 'b2');
    });
  });

  group('⚠️ CEVAPLAYAN HENÜZ OKUMADAN YAZARSA', () {
    test('gönderme zinciri yokken şifreleme NULL döner', () async {
      // Bu, `encryptMessage`'ın belgelenmiş davranışı. TEHLİKESİ şu:
      // çağıran katman (`encryption_datasource_impl`) null görünce
      // mesajı `isEncrypted: false` ile DÜZ METİN gönderiyor.
      //
      // Yani "karşı taraf sana yazmadan önce sen yazarsan mesajın
      // şifresiz gider" gibi sessiz bir yol var.
      final paket = await sifrele(bob, 'once ben yazdim');

      expect(paket, isNull,
          reason: 'cevaplayanın gönderme zinciri ilk gelen mesajla '
              'kurulur; o gelmeden şifreleyemez');
    });
  });

  group('🔴 TEK SEFERLİK ÇÖZME — uygulamanın kırılgan yeri', () {
    test('AYNI paket İKİNCİ kez çözülemez', () async {
      final paket = await sifrele(alice, 'bir kere');

      expect(await coz(bob, paket!), 'bir kere');

      // Ratchet ilerledi; aynı şifreli metin artık çözülemez.
      expect(await coz(bob, paket), isNull,
          reason: 'ratchet tek yönlüdür — bu davranış DOĞRU, ama bedeli '
              'şu: arayüz her Firestore anlık görüntüsünde TÜM listeyi '
              'yeniden çözmeye kalkıyor ve bunu yalnızca düz metin '
              'önbelleği engelliyor. Önbellek BİR KEZ ıskalarsa o mesaj '
              'KALICI olarak çözülemez hâle gelir.');
    });

    test('çözülen mesaj düz metin önbelleğine YAZILIR', () async {
      // Önbellek, yukarıdaki tek-seferlik kısıtının tek telafisi.
      final paket = await sifrele(alice, 'saklanmali');
      E2EESessionService.setActiveAccount(bob);
      await E2EESessionService.decryptMessage(
          chatId: chatId, ciphertext: paket!);

      // NOT: `decryptMessage` önbelleğe yazmaz; yazan üst katmandır
      // (`encryption_datasource_impl` → `cachePlaintext`). Bu testin
      // amacı o sınırı GÖRÜNÜR kılmak: kripto katmanı kendi başına
      // hiçbir şey saklamıyor.
      expect(await E2EESessionService.getPlaintext('herhangi-bir-id'), isNull,
          reason: 'kripto katmanı düz metni KENDİ saklamaz — sorumluluk '
              'üst katmanda, ve orası ıskalarsa mesaj gider');
    });
  });

  group('🔴 ÇAPRAZ EL SIKIŞMA — başlık onaya kadar tekrarlanır (§4be)', () {
    // 🐞 Başlık eskiden YALNIZCA ilk mesaja ekleniyordu. İki taraf da aynı
    // anda yazmaya başlarsa her biri KENDİ oturumunu kurar ve diğerinin
    // başlığını kimlik değişmediği için yok sayar. Sonraki mesajlarda
    // başlık olmadığı için onarılacak malzeme kalmaz: sohbet tek yönlü
    // donar. Kullanıcıda defalarca görüldü.

    test('oturum ONAYLANMADIKÇA başlık verilir', () async {
      E2EESessionService.setActiveAccount(alice);
      final baslik = await E2EESessionService.pendingInitHeader(chatId);
      expect(baslik, isNotNull,
          reason: 'onaylanmamış oturumda başlık her mesajla gitmeli — '
              'tıkanan tarafın yeniden kurmak için buna ihtiyacı var');
      expect(baslik!['ik'], 'ALICE_KIMLIK');
    });

    test('🔴 karşı taraftan mesaj ÇÖZÜLÜNCE başlık artık gönderilmez',
        () async {
      // Onay = karşı taraftan en az bir mesajı çözebilmek. B, A'nın
      // mesajını çözer → B'nin oturumu onaylanır.
      final p1 = await sifrele(alice, 'selam');
      expect(await coz(bob, p1!), 'selam');

      E2EESessionService.setActiveAccount(bob);
      expect(await E2EESessionService.pendingInitHeader(chatId), isNull,
          reason: 'çözebildiysek iki taraf aynı zincirde; başlığı '
              'tekrarlamak gereksiz bant genişliği olurdu');
    });

    test('A hâlâ onaylanmamışsa başlığı TAŞIMAYA devam eder', () async {
      // A yalnızca gönderdi, henüz B'den bir şey çözmedi.
      await sifrele(alice, 'bir');
      await sifrele(alice, 'iki');

      E2EESessionService.setActiveAccount(alice);
      expect(await E2EESessionService.pendingInitHeader(chatId), isNotNull,
          reason: 'tek taraflı gönderim onay sayılmaz — karşı taraf hâlâ '
              'tıkalı olabilir ve başlığa ihtiyaç duyar');
    });

    test('oturum yoksa başlık da yoktur', () async {
      E2EESessionService.setActiveAccount('bosluk');
      expect(await E2EESessionService.pendingInitHeader(chatId), isNull);
    });

    test('başlık ve onay diske YAZILIR ve geri OKUNUR', () async {
      // Uygulama yeniden başlayınca onay durumu kaybolursa başlık
      // sonsuza dek tekrarlanır (ya da hiç tekrarlanmaz).
      final s = SessionState(
        sendingChainKey: const [1],
        receivingChainKey: const [2],
        sendCounter: 0,
        recvCounter: 0,
        skipped: const {},
        pendingHeader: const {'ik': 'K', 'ek': 'E'},
        onaylandi: true,
      );
      final geri = SessionState.fromJson(s.toJson());
      expect(geri.pendingHeader, {'ik': 'K', 'ek': 'E'});
      expect(geri.onaylandi, isTrue);
    });
  });

  group('sırasız teslim', () {
    test('2. mesaj 1.den ÖNCE gelirse ikisi de çözülür', () async {
      final p1 = await sifrele(alice, 'birinci');
      final p2 = await sifrele(alice, 'ikinci');

      // Sıra bozuk: önce ikinci gelir.
      expect(await coz(bob, p2!), 'ikinci');
      // Atlanan anahtar saklandıysa birinci de çözülebilmeli.
      expect(await coz(bob, p1!), 'birinci',
          reason: 'atlanan mesaj anahtarları saklanmazsa geç gelen mesaj '
              'kalıcı olarak çözülemez');
    });
  });
}
