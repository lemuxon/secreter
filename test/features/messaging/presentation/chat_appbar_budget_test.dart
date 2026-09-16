import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';
import 'package:gizli_chat/features/messaging/presentation/screens/messaging_screen.dart';

/// 📏 SOHBET BAŞLIĞI GENİŞLİK BÜTÇESİ
///
/// ── NEDEN VAR ──
/// Saha raporu: *"'Son görülme....' yazıyor ama metin sığmadığından
/// tamamen okunmuyor. İnsanlar son görülme aktifliğini göremiyor."*
///
/// Kök neden bir çizim hatası değil, **aritmetik**: başlık çubuğundaki
/// her sabit genişlikli düğme, başlığın ve alt satırın payından düşüyor.
/// Dört 48dp'lik düğmeyle 360dp'lik bir telefonda geriye 54dp kalıyordu
/// ve `TextOverflow.ellipsis` bilginin TAMAMINI yutuyordu — kullanıcı
/// saati hiç göremiyordu.
///
/// ── NEDEN BÖYLE ÖLÇÜLÜYOR ──
/// `MessagingScreen`i widget testinde ayağa kaldırmak Firestore,
/// Riverpod ve E2EE oturumu ister (aynı gerekçe `security_banners.dart`
/// için de geçerliydi). Bütçe bunun yerine ekranın KULLANDIĞI
/// sabitlerden okunuyor: düğme eklenirse `kAppBarFixedWidth` büyür ve
/// bu kapı düşer.
///
/// ⚠️ Ölçü, gerçek `IconButton` genişliğine bağlı. İlk test onu
/// varsaymıyor, **çiziyor ve ölçüyor** — Flutter'ın yoğunluk
/// davranışı değişirse sabit sessizce yalan söylemesin.
void main() {
  testWidgets('kAppBarIconSize gerçek IconButton genişliğiyle örtüşür',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.call),
                onPressed: () {},
                visualDensity: kAppBarIconDensity,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(IconButton)).width, kAppBarIconSize,
        reason: 'sabit, çizilen düğmeyle uyuşmuyor — bütçe hesabı yanlış '
            'temele oturuyor demektir');
  });

  test('alt satır hiçbir dilde okunmaz boyuta düşmez', () {
    expect(kAppBarBaslikPayi, greaterThan(0));

    double genislik(String s) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: const TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      return tp.width;
    }

    // ⚠️ Test ortamında yedek font kullanılıyor ve her glif 1em genişlikte
    // çiziliyor (gerçek Roboto'da Latin harfler ~0.5em). Buradaki ölçüm
    // gerçeğin ÜST SINIRI; oran bu yüzden yarıya iniyor.
    const testFontuAbartmaOrani = 2.0;

    // Alt satır artık KIRPILMIYOR — `FittedBox(scaleDown)` sığmayanı
    // küçültüyor. Ölçülecek şey "sığıyor mu" değil, **ne kadar küçülmek
    // zorunda kaldığı**: kırpma bilgiyi yok ederdi, küçülmenin tabanı var.
    const tabanPunto = 11.0;
    const dogalPunto = 12.0;

    final basarisiz = <String, String>{};
    for (final dil in AppLocalizations.keysByLanguage.keys) {
      final v = AppLocalizations.valuesFor(dil);
      // `presenceLabel`in ürettiği BEŞ biçimin birebir karşılığı.
      final adaylar = <String>[
        '${v['last_seen']} 14:32',
        '${v['yesterday']} 14:32',
        '${v['last_seen']} 28.02',
        v['online_now']!,
        '${v['presence_typing']}...',
      ];
      for (final aday in adaylar) {
        final w = genislik(aday) / testFontuAbartmaOrani;
        if (w <= kAppBarBaslikPayi) continue;
        final etkinPunto = dogalPunto * kAppBarBaslikPayi / w;
        if (etkinPunto < tabanPunto) {
          basarisiz['$dil "$aday"'] = etkinPunto.toStringAsFixed(1);
        }
      }
    }

    expect(basarisiz, isEmpty,
        reason: 'bu satırlar başlık payına (${kAppBarBaslikPayi}dp) sığmak '
            'için ${tabanPunto}dp altına küçülüyor: $basarisiz — ya metni '
            'kısalt ya da başlık çubuğundan bir düğme çıkar');
  });

  test('başlık payı, bilinen kırık değerin en az iki katı', () {
    // Sayısal alt sınır, "bir düğme daha eklesem ne olur" sorusunu
    // tahminden ölçüme çevirir. 54dp bilinen KIRIK değerdi.
    const bilinenKirikPay = 54.0;
    expect(kAppBarBaslikPayi, greaterThanOrEqualTo(bilinenKirikPay * 2),
        reason: 'başlık çubuğuna düğme eklenmiş olabilir; alt satır yine '
            'okunmaz hâle gelir');
  });
}
