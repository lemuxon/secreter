import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/rehandshake_service.dart';

/// ⚖️ ÇAKIŞAN EL SIKIŞMA — İKİ TARAF AYNI ANDA ONARMAYA KALKARSA
///
/// ── NEDEN KRİTİK ──
/// Sessiz el sıkışma (§4cc) ölü oturumu onarır. Ama iki taraf da aynı
/// anda ölü oturum tespit edip yayımlarsa, her biri diğerininkini
/// benimser ve **farklı oturumlarda** kalır. Sohbet tamamen kırılır —
/// yani onarım mekanizması, onarmaya çalıştığı şeyi bozar.
///
/// Hakem bu yüzden DETERMİNİSTİK olmak zorunda: iki istemci de aynı
/// cevabı vermezse ya ikisi kendininkinde kalır ya da ikisi diğerine
/// geçer; her iki durumda da oturumlar ayrışır.
///
/// Kural: uid'i sözlükbilimsel olarak KÜÇÜK olan kazanır.
void main() {
  group('hakem deterministik', () {
    test('her çiftte TAM BİR taraf kazanır', () {
      const uidler = ['a', 'b', 'uidAlice', 'uidBob', 'A', '0', 'zz'];
      for (final x in uidler) {
        for (final y in uidler) {
          if (x == y) continue;
          final xKazanir = RehandshakeService.benimkiKazanir(
              benYayimladim: true, benimUid: x, gonderenUid: y);
          final yKazanir = RehandshakeService.benimkiKazanir(
              benYayimladim: true, benimUid: y, gonderenUid: x);
          expect(xKazanir, isNot(yKazanir),
              reason: '$x/$y: ikisi de kazanırsa oturumlar AYRIŞIR, '
                  'ikisi de kaybederse onarım hiç olmaz');
        }
      }
    });

    test('küçük uid kazanır', () {
      expect(
        RehandshakeService.benimkiKazanir(
            benYayimladim: true, benimUid: 'abc', gonderenUid: 'abd'),
        isTrue,
      );
      expect(
        RehandshakeService.benimkiKazanir(
            benYayimladim: true, benimUid: 'abd', gonderenUid: 'abc'),
        isFalse,
      );
    });

    test('karar RASTGELE DEĞİL — tekrar aynı sonucu verir', () {
      for (var i = 0; i < 5; i++) {
        expect(
          RehandshakeService.benimkiKazanir(
              benYayimladim: true, benimUid: 'u1', gonderenUid: 'u2'),
          isTrue,
        );
      }
    });
  });

  group('çakışma YOKSA hakemlik yapılmaz', () {
    test('ben yayımlamadıysam gelen başlık HER ZAMAN benimsenir', () {
      // ⚠️ Asıl senaryo bu: genelde tek taraf bozuktur. Burada "kazanmak"
      // isteseydik onarım hiç olmazdı.
      expect(
        RehandshakeService.benimkiKazanir(
            benYayimladim: false, benimUid: 'aaa', gonderenUid: 'zzz'),
        isFalse,
        reason: 'uid küçük olsa bile, yayımlamadıysam ortada çakışma yok',
      );
    });

    test('uid bilinmiyorsa gelen benimsenir', () {
      // Bilinmeyen durumda onarımı ENGELLEMEK, kırık sohbeti kırık
      // bırakmak demektir; güvenli taraf benimsemektir.
      expect(
        RehandshakeService.benimkiKazanir(
            benYayimladim: true, benimUid: '', gonderenUid: 'u2'),
        isFalse,
      );
      expect(
        RehandshakeService.benimkiKazanir(
            benYayimladim: true, benimUid: 'u1', gonderenUid: ''),
        isFalse,
      );
    });
  });

  test('🔴 İKİ TARAF DA YAYIMLADI — tek bir oturumda buluşurlar', () {
    // Senaryoyu birebir kur: A ve B aynı anda yayımladı.
    const a = 'uidAlice';
    const b = 'uidBob'; // 'uidAlice' < 'uidBob'

    final aKendindeKalir = RehandshakeService.benimkiKazanir(
        benYayimladim: true, benimUid: a, gonderenUid: b);
    final bKendindeKalir = RehandshakeService.benimkiKazanir(
        benYayimladim: true, benimUid: b, gonderenUid: a);

    expect(aKendindeKalir, isTrue, reason: 'A kendi oturumunda kalmalı');
    expect(bKendindeKalir, isFalse, reason: "B, A'nınkini benimsemeli");
    // Sonuç: ikisi de A'nın oturumunda. Ayrışma yok.
  });
}
