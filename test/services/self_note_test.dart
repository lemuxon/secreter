import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/encryption_service.dart';
import 'package:gizli_chat/services/self_note_service.dart';

/// 🗒️ KENDİNE MESAJ — ŞİFRELEME KAPISI
///
/// ── NEDEN BU TEST VAR ──
/// Özellik tam olarak şu tuzak yüzünden ertelenmişti: `uid_uid`
/// sohbetinde "karşı taraf" boş çıkar, sohbet GRUP sanılır, üye sayısı 1
/// olduğu için "dejenere grup" dalına düşer ve mesaj **DÜZ METİN**
/// gider. Yani özellik *çalışıyor görünür*, notlar sunucuda açıkta
/// durur. Hiçbir hata da çıkmaz.
///
/// Bu dosya iki şeyi kilitler:
///   1. Sohbet TANIMA doğru (yanlış tanınırsa yanlış dala düşer),
///   2. Zarf gerçekten şifreli ve düz metni TAŞIMIYOR.
void main() {
  group('kendine sohbet tanıma', () {
    test('uid_uid biçimi kendine sohbettir', () {
      expect(SelfNoteService.isSelfChat('u1_u1', 'u1'), isTrue);
      expect(SelfNoteService.selfChatId('u1'), 'u1_u1');
    });

    test('başka birebir sohbet kendine sohbet DEĞİLDİR', () {
      // ⚠️ Yanlış pozitif, normal bir sohbeti simetrik anahtara
      // yönlendirir: karşı taraf o mesajı ASLA çözemez.
      expect(SelfNoteService.isSelfChat('u1_u2', 'u1'), isFalse);
      expect(SelfNoteService.isSelfChat('u2_u1', 'u1'), isFalse);
    });

    test('BAŞKASININ kendine sohbeti benim sayılmaz', () {
      expect(SelfNoteService.isSelfChat('u2_u2', 'u1'), isFalse);
    });

    test('oturum yokken kendine sohbet sayılmaz', () {
      // uid null iken true dönseydi, oturumsuz bir yol şifrelemeye
      // kalkar ve anahtar bulunamadığı için mesaj hiç gitmezdi.
      expect(SelfNoteService.isSelfChat('u1_u1', null), isFalse);
      expect(SelfNoteService.isSelfChat('u1_u1', ''), isFalse);
    });

    test('grup/kanal kimliği kendine sohbet değildir', () {
      expect(SelfNoteService.isSelfChat('abc123', 'u1'), isFalse);
    });
  });

  group('zarf biçimi', () {
    test('kendi zarfını tanır', () {
      expect(SelfNoteService.isSelfEnvelope('sn1.v2.a.b.c'), isTrue);
    });

    test('BAŞKA zarfları kendine ait sanmaz', () {
      // Yanlış tanıma, grup zarfını simetrik çözücüye yollar: not
      // "çözülemedi" görünür.
      expect(SelfNoteService.isSelfEnvelope('v2.a.b.c'), isFalse);
      expect(SelfNoteService.isSelfEnvelope('eyJ2IjoxfQ=='), isFalse);
      expect(SelfNoteService.isSelfEnvelope(''), isFalse);
      expect(SelfNoteService.isSelfEnvelope('sn1'), isFalse);
    });
  });

  // ── ANAHTAR TÜRETİMİ ──
  //
  // ⚠️ HESAP BURADA İKİNCİ KEZ YAZILMAZ — servisin kendi fonksiyonu
  // çağrılır. Kopya bir uygulama, `info` etiketi ya da tuz değişince
  // yine geçerdi; oysa o değişiklik VAR OLAN TÜM NOTLARI okunamaz
  // yapar. Altın vektör de bunun için: parametreler kayarsa test
  // gürültülü biçimde düşer.
  group('anahtar türetimi', () {
    Future<String> turet(String hesapAnahtari, String uid) =>
        SelfNoteService.deriveKey(hesapAnahtari, uid);

    test('🔒 ALTIN VEKTÖR — türetme parametreleri SABİT', () async {
      // Bu değer değişirse: HKDF girdilerinden biri (tuz, info etiketi,
      // uzunluk) değişmiş demektir ve kullanıcıların ESKİ NOTLARI artık
      // çözülemez. Sürüm yükseltmek gerekiyorsa `info`ya yeni bir sürüm
      // ekle ve eski zarfları eski anahtarla çözmeye devam et —
      // bu satırı güncellemek tek başına veri KAYBIDIR.
      final k = await SelfNoteService.deriveKey('sabit-hesap-anahtari', 'uid1');
      expect(k, 'i28dfYoJ8-3Y6Yg5y4wRYU-E-Wb9Ldf-sXQWSXEjvDU=');
    });

    test('hesap anahtarı DOĞRUDAN kullanılmaz', () async {
      // Bir anahtarın iki iş görmesi, birinin açığa çıkmasını
      // diğerinin de açığa çıkması yapar.
      final hesap = EncryptionService.generateKey();
      expect(await turet(hesap, 'u1'), isNot(equals(hesap)));
    });

    test('aynı cihazdaki iki hesap AYNI anahtarı üretmez', () async {
      // Tuz uid: aksi halde aynı hesap anahtarını paylaşan iki kayıt
      // birbirinin notlarını çözebilirdi.
      final hesap = EncryptionService.generateKey();
      expect(await turet(hesap, 'u1'), isNot(equals(await turet(hesap, 'u2'))));
    });

    test('aynı girdi HER ZAMAN aynı anahtarı verir', () async {
      // Belirlenimci olmazsa dünkü notlar bugün çözülemezdi.
      final hesap = EncryptionService.generateKey();
      expect(await turet(hesap, 'u1'), await turet(hesap, 'u1'));
    });

    test('türetilmiş anahtarla gidiş-dönüş çalışır', () async {
      final anahtar = await turet(EncryptionService.generateKey(), 'u1');
      final sifreli = await EncryptionService.encrypt('gizli not', anahtar);
      expect(await EncryptionService.decrypt(sifreli, anahtar), 'gizli not');
    });

    test('🔴 ZARF DÜZ METNİ TAŞIMAZ', () async {
      // Asıl korunan şey bu: özelliğin ilk hâli notu sunucuya açıkta
      // yazıyordu.
      const not = 'banka sifrem 1234';
      final anahtar = await turet(EncryptionService.generateKey(), 'u1');
      final sifreli = await EncryptionService.encrypt(not, anahtar);
      expect(sifreli, isNot(contains(not)));
      expect(sifreli, isNot(contains('banka')));
      expect(sifreli, isNot(contains('1234')));
    });

    test('YANLIŞ anahtar çözemez', () async {
      final a = await turet(EncryptionService.generateKey(), 'u1');
      final b = await turet(EncryptionService.generateKey(), 'u1');
      final sifreli = await EncryptionService.encrypt('not', a);
      await expectLater(
        EncryptionService.decrypt(sifreli, b),
        throwsA(isA<Object>()),
      );
    });
  });
}
