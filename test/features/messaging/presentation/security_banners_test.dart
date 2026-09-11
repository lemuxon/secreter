import 'package:flutter/material.dart';
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
      supportedLocales: const [Locale('tr'), Locale('en')],
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
    testWidgets('iki bant da AYNI yüksekliktedir', (tester) async {
      // ⚠️ Sohbet ekranı bantları üst üste dizerken bu sabite dayanıyor;
      // biri farklı olsaydı bantlar mesaj listesiyle çakışırdı.
      await tester.pumpWidget(_wrap(Column(children: [
        GroupKeyRotationBanner(onRetry: () {}),
        VerifyPromptBanner(onOpen: () {}, onDismiss: () {}),
        const GroupPlaintextBanner(),
      ])));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(GroupKeyRotationBanner)).height,
          kSecurityBannerHeight);
      expect(tester.getSize(find.byType(VerifyPromptBanner)).height,
          kSecurityBannerHeight);
      expect(tester.getSize(find.byType(GroupPlaintextBanner)).height,
          kSecurityBannerHeight);
    });
  });
}
