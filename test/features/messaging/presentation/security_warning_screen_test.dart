import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';
import 'package:gizli_chat/core/security/security_service.dart';
import 'package:gizli_chat/features/security/presentation/security_warning_screen.dart';

/// Ekran metinleri artık `context.tr(...)` ile çevrildiği için testler de
/// yerelleştirmeyi KURMAK zorunda. Eskiden test sabit Türkçe dizeler
/// arıyordu; metinler i18n'e taşınınca üç test kırılmıştı.
///
/// NOT: `DefaultMaterialLocalizations` yalnızca İngilizce destekler ve
/// `tr` locale ile widget ağacı hata fırlatıyor. Uygulamanın kendi
/// kullandığı `flutter_localizations` global delegeleri kullanılmalı.
Widget _wrap(Widget child, {String lang = 'tr'}) => MaterialApp(
      locale: Locale(lang),
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

/// Ekranı kur ve rota geçiş animasyonu bitene kadar bekle.
///
/// `pumpWidget` tek başına yalnızca İLK kareyi çizer; MaterialApp'in
/// Navigator'ı home rotasını bir geçiş içinde kurduğu için içerik henüz
/// ağaçta olmayabiliyor ve `find.text` boş dönüyordu.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(_wrap(screen));
  await tester.pumpAndSettle();
}

/// Testin çeviri tablosuyla senkron kalması için metni anahtardan çöz.
String tr(String key, {String lang = 'tr'}) =>
    AppLocalizations(Locale(lang)).t(key);

void main() {
  group('SecurityWarningScreen', () {
    testWidgets('kritik tehditte "devam et" butonu GÖSTERİLMEZ',
        (tester) async {
      const result = SecurityCheckResult([SecurityThreat.rootedOrJailbroken]);

      await _pump(
        tester,
        SecurityWarningScreen(result: result, onContinueAnyway: (_) {}),
      );

      expect(find.text(tr('sec_risk_title')), findsOneWidget);
      expect(find.text(tr('understood_continue')), findsNothing);
      expect(find.text(tr('threat_root_t')), findsOneWidget);
    });

    testWidgets('sadece uyarıda "devam et" butonu GÖSTERİLİR', (tester) async {
      const result = SecurityCheckResult([SecurityThreat.emulator]);

      await _pump(
        tester,
        SecurityWarningScreen(result: result, onContinueAnyway: (_) {}),
      );

      expect(find.text(tr('sec_warn_title')), findsOneWidget);
      expect(find.text(tr('understood_continue')), findsOneWidget);
    });

    testWidgets('"devam et" butonuna basılınca callback çalışır',
        (tester) async {
      var callbackCalled = false;
      const result = SecurityCheckResult([SecurityThreat.emulator]);

      await _pump(
        tester,
        SecurityWarningScreen(
          result: result,
          onContinueAnyway: (_) => callbackCalled = true,
        ),
      );

      await tester.tap(find.text(tr('understood_continue')));
      await tester.pump();

      expect(callbackCalled, true);
    });

    testWidgets('callback verilmezse buton hiç çizilmez', (tester) async {
      const result = SecurityCheckResult([SecurityThreat.emulator]);

      await _pump(tester, const SecurityWarningScreen(result: result));

      expect(find.text(tr('understood_continue')), findsNothing);
    });

    testWidgets('birden fazla tehdit hepsi listelenir', (tester) async {
      const result = SecurityCheckResult([
        SecurityThreat.emulator,
        SecurityThreat.developerMode,
      ]);

      await _pump(tester, const SecurityWarningScreen(result: result));

      expect(find.text(tr('threat_emulator_t')), findsOneWidget);
      expect(find.text(tr('threat_devmode_t')), findsOneWidget);
    });
  });
}
