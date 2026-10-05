import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';
import 'package:gizli_chat/features/messaging/presentation/widgets/security_banners.dart';

/// 🛡️ GÜVENLİK BANTLARI — ÇİZİM VE DAVRANIŞ
///
/// Bir bandın doğru koşulda ÇIKMASI bir güvenlik özelliğidir. Grup
/// anahtarı rotasyonu başarısız olduğunda bant görünmezse, kullanıcı
/// gruptan attığı kişinin sonraki mesajları hâlâ okuyabildiğini asla
/// öğrenemez — "herhalde çalışıyordur" denecek bir yer değil.
///
/// Cihazda doğrulamak mümkün değildi: rotasyon başarısızlığı elle
/// zorlanamıyor ve debug derlemesi kurmak release'i kaldırmayı, yani
/// cihazdaki hesabı ve E2EE kimliğini SİLMEYİ gerektiriyordu.
Widget _wrap(Widget child, {String lang = 'tr'}) => MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale(lang)],
      home: Scaffold(body: child),
    );

void main() {
  group('grup anahtarı rotasyonu bandı', () {
    testWidgets('uyarı metnini ve tekrar deneme düğmesini gösterir',
        (tester) async {
      await tester.pumpWidget(_wrap(GroupKeyRotationBanner(onRetry: () {})));
      await tester.pumpAndSettle();

      // Ham anahtar DEĞİL, çevrilmiş metin görünmeli.
      expect(find.textContaining('yenilenemedi'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.text('sec_rotation_failed'), findsNothing);
    });

    testWidgets('KAPATMA düğmesi YOKTUR', (tester) async {
      // ⚠️ Bilinçli: kullanıcı bu uyarıyı görmezden gelebilseydi,
      // attığı kişinin hâlâ okuyabildiğini hiç öğrenemezdi.
      await tester.pumpWidget(_wrap(GroupKeyRotationBanner(onRetry: () {})));
      await tester.pumpAndSettle();

      expect(find.text('Şimdi değil'), findsNothing);
    });

    testWidgets('tekrar deneme dokunuşu iletilir', (tester) async {
      var tapped = 0;
      await tester
          .pumpWidget(_wrap(GroupKeyRotationBanner(onRetry: () => tapped++)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tekrar dene'));
      expect(tapped, 1);
    });

    testWidgets('İngilizce dilde çevrilmiş görünür', (tester) async {
      await tester.pumpWidget(
          _wrap(GroupKeyRotationBanner(onRetry: () {}), lang: 'en'));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('could not be renewed'), findsOneWidget);
    });
  });

  group('doğrulama önerisi bandı', () {
    testWidgets('öneri metnini ve kapatma seçeneğini gösterir', (tester) async {
      await tester.pumpWidget(
          _wrap(VerifyPromptBanner(onOpen: () {}, onDismiss: () {})));
      await tester.pumpAndSettle();

      expect(find.textContaining('doğrula'), findsOneWidget);
      expect(find.text('Şimdi değil'), findsOneWidget);
    });

    testWidgets('metne dokunmak güvenlik numarasını AÇAR', (tester) async {
      var opened = 0, dismissed = 0;
      await tester.pumpWidget(_wrap(VerifyPromptBanner(
          onOpen: () => opened++, onDismiss: () => dismissed++)));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('doğrula'));
      expect(opened, 1);
      expect(dismissed, 0, reason: 'yanlışlıkla kapatılmamalı');
    });

    testWidgets('KAPATMA ayrı bir eylemdir', (tester) async {
      var opened = 0, dismissed = 0;
      await tester.pumpWidget(_wrap(VerifyPromptBanner(
          onOpen: () => opened++, onDismiss: () => dismissed++)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Şimdi değil'));
      expect(dismissed, 1);
      expect(opened, 0, reason: 'kapatmak ekranı açmamalı');
    });
  });

  group('şifresiz grup bandı', () {
    testWidgets('şifrelemenin KAPALI olduğunu söyler', (tester) async {
      await tester.pumpWidget(_wrap(const GroupPlaintextBanner()));
      await tester.pumpAndSettle();

      expect(find.textContaining('şifreleme etkin değil'), findsOneWidget);
      expect(find.text('sec_group_plaintext'), findsNothing);
    });

    testWidgets('KAPATILAMAZ (görmezden gelinemez)', (tester) async {
      // Bir güvenlik sözü tutulamıyor; kullanıcı bunu kapatabilseydi
      // şifreli sandığı grupta konuşmaya devam ederdi.
      await tester.pumpWidget(_wrap(const GroupPlaintextBanner()));
      await tester.pumpAndSettle();

      expect(find.text('Şimdi değil'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('İngilizce çevrilmiş görünür', (tester) async {
      await tester.pumpWidget(_wrap(const GroupPlaintextBanner(), lang: 'en'));
      await tester.pumpAndSettle();

      expect(find.textContaining('encryption is off'), findsOneWidget);
    });
  });

  group('yükseklik sözleşmesi', () {
    // ⚠️ Eskiden "hepsi AYNI yükseklikte" ölçülüyordu ve sohbet ekranı
    // buna dayanıyordu. Sözleşme DEĞİŞTİ: her bant kendi yüksekliğini
    // söylüyor, ekran onları topluyor. Ölçülmesi gereken şey artık
    // eşitlik değil, **bildirilen yüksekliğin çizilenle uyuşması** —
    // uyuşmazsa bantlar mesaj listesiyle çakışır ya da araya boşluk
    // girer, ikisi de sessizdir.
    testWidgets('her bant BİLDİRDİĞİ yükseklikte çizilir', (tester) async {
      await tester.pumpWidget(_wrap(Column(children: [
        IdentityChangedBanner(onOpen: () {}),
        GroupKeyRotationBanner(onRetry: () {}),
        VerifyPromptBanner(onOpen: () {}, onDismiss: () {}),
        const GroupPlaintextBanner(),
      ])));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(IdentityChangedBanner)).height,
          IdentityChangedBanner.height);
      expect(tester.getSize(find.byType(GroupKeyRotationBanner)).height,
          GroupKeyRotationBanner.height);
      expect(tester.getSize(find.byType(VerifyPromptBanner)).height,
          VerifyPromptBanner.height);
      expect(tester.getSize(find.byType(GroupPlaintextBanner)).height,
          GroupPlaintextBanner.height);
    });

    test('yükseklik, satır sayısıyla birlikte büyür', () {
      // Satır sayısı artırılıp yükseklik unutulursa metin yine kırpılır;
      // bağın kendisi ölçülüyor.
      expect(VerifyPromptBanner.height,
          bantYuksekligi(VerifyPromptBanner.maxLines));
      expect(GroupPlaintextBanner.height,
          bantYuksekligi(GroupPlaintextBanner.maxLines));
      expect(GroupKeyRotationBanner.height,
          bantYuksekligi(GroupKeyRotationBanner.maxLines));
      expect(IdentityChangedBanner.height,
          bantYuksekligi(IdentityChangedBanner.maxLines));
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // ✂️ KIRPILMA
  //
  // Saha raporu: *"'güvenlik numarası karşılaştırarak bu sohb....'
  // kısmında da öyle"* — bant metni tek satıra sığmadığı için yarısı
  // görünmüyordu.
  //
  // Yarısı görünen bir güvenlik bandı, görünmeyen bir bantla aynı işe
  // yarar: kullanıcı ne istendiğini anlamaz. Bant yüksekliği 38 → 52
  // yapıldı ve metinler iki satıra açıldı.
  // ───────────────────────────────────────────────────────────────────
  group('kırpılma', () {
    // ⚠️ GERÇEK FONT ŞART. Widget testinde varsayılan yedek font her
    // glifi 1em genişlikte çizer — Roboto'da Latin harfler yaklaşık
    // yarısı kadardır. Yedek fontla ölçmek "kırpılıyor" diye YANLIŞ
    // alarm verir (ölçüldü: altı bandın altısı da düşüyordu). Roboto,
    // Flutter SDK'sının önbelleğinden yükleniyor.
    setUpAll(() async {
      // 🪤 FONT DEPODAN OKUNUR, SDK ÖNBELLEĞİNDEN DEĞİL.
      //
      // Önceden
      // `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/` altından
      // okunuyordu. O dizin temiz bir kurulumda BOŞTUR — `flutter pub
      // get` material fontlarını indirmez — ve `flutter precache
      // --universal` de doldurmadı. CI üç çalıştırma boyunca tam bu
      // yüzden düştü. Ayrıca SDK'nın iç önbellek düzeni sürümler
      // arasında değişebilir; teste temel yapılacak bir sözleşme değil.
      //
      // Bkz. `test/fixtures/fonts/README.md` (Roboto, Apache-2.0).
      final dosya = File('test/fixtures/fonts/roboto-regular.ttf');
      expect(dosya.existsSync(), isTrue,
          reason: 'Roboto bulunamadı: ${dosya.absolute.path} — '
              'testler depo kökünden çalıştırılmalı (`flutter test`).');

      final loader = FontLoader('Roboto')
        ..addFont(dosya.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    });

    /// `Text` gerçekten kırpıldı mı? `didExceedMaxLines` bunu doğrudan
    /// söyler — metni gözle karşılaştırmak (`find.text`) kırpılmayı
    /// GÖRMEZ, çünkü widget'ın `data`sı tamdır, yalnızca ÇİZİM kesiktir.
    bool kirpildi(WidgetTester tester, Finder bant) {
      final paragraflar = tester
          .renderObjectList<RenderParagraph>(
              find.descendant(of: bant, matching: find.byType(RichText)))
          .toList();
      expect(paragraflar, isNotEmpty);
      return paragraflar.any((p) => p.didExceedMaxLines);
    }

    /// En dar yaygın telefon. Bantlar ekran genişliğini kaplar.
    const darEkran = Size(360, 800);

    // ⚠️ İKİ DİL YETMEZ. tr+en ölçüp geçmek, bu projede tekrar eden
    // "yeşil ama hiçbir şey kanıtlamayan kapı" desenine düşerdi:
    // Almanca anahtar rotasyonu uyarısı İngilizcenin 1,5 katı, Yunanca
    // şifresizlik uyarısı hepsinden uzun. Kapı 16 dilin TAMAMINI ölçer.
    for (final dil in AppLocalizations.keysByLanguage.keys) {
      testWidgets('[$dil] doğrulama önerisi bandı kırpılmıyor', (tester) async {
        await tester.binding.setSurfaceSize(darEkran);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_wrap(
            VerifyPromptBanner(onOpen: () {}, onDismiss: () {}),
            lang: dil));
        await tester.pumpAndSettle();

        expect(kirpildi(tester, find.byType(VerifyPromptBanner)), isFalse,
            reason: 'öneri metni kesiliyor — kullanıcı ne yapması '
                'gerektiğini okuyamaz');
      });

      testWidgets('[$dil] şifresiz grup bandı kırpılmıyor', (tester) async {
        await tester.binding.setSurfaceSize(darEkran);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_wrap(const GroupPlaintextBanner(), lang: dil));
        await tester.pumpAndSettle();

        expect(kirpildi(tester, find.byType(GroupPlaintextBanner)), isFalse,
            reason: 'şifrelemenin kapalı olduğu uyarısı yarım görünüyor');
      });

      testWidgets('[$dil] kimlik değişimi bandı kırpılmıyor', (tester) async {
        await tester.binding.setSurfaceSize(darEkran);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester
            .pumpWidget(_wrap(IdentityChangedBanner(onOpen: () {}), lang: dil));
        await tester.pumpAndSettle();

        expect(kirpildi(tester, find.byType(IdentityChangedBanner)), isFalse,
            reason: 'araya girme ihtimalini anlatan uyarı yarım görünüyor');
      });

      testWidgets('[$dil] anahtar rotasyonu bandı kırpılmıyor', (tester) async {
        await tester.binding.setSurfaceSize(darEkran);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
            _wrap(GroupKeyRotationBanner(onRetry: () {}), lang: dil));
        await tester.pumpAndSettle();

        expect(kirpildi(tester, find.byType(GroupKeyRotationBanner)), isFalse,
            reason: 'atılan üyenin mesajları okumaya devam ettiği uyarısı '
                'yarım görünüyor');
      });
    }
  });
}
