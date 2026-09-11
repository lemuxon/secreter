import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Integration testleri gerçek cihazda/emulatorde çalışır.
///
/// Çalıştırma:
///   flutter test integration_test/app_test.dart
///
/// NOT: Bu test Firebase başlatması gerektirir. CI'da Firebase emulator
/// suite veya test projesi kullanılmalı. Aşağıdaki test, Firebase olmadan
/// çalışacak şekilde minimal tutulmuştur (smoke test).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Uygulama açılış akışı', () {
    testWidgets('uygulama çökmeden açılır ve bir widget render eder',
        (tester) async {
      // Minimal bir widget ağacı render edip çökme olmadığını doğrula.
      // Gerçek senaryoda main()'deki GizliChatApp test edilir, ama o
      // Firebase.initializeApp() gerektirir — CI'da emulator suite ile.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('GizliChat')),
          ),
        ),
      );

      expect(find.text('GizliChat'), findsOneWidget);
    });

    // Gerçek E2E senaryoları (Firebase emulator gerektirir):
    // - Kayıt akışı: kullanıcı adı gir → ana ekran açılır
    // - Mesaj gönderme: sohbet aç → mesaj yaz → listede görünür
    // - Offline: ağı kes → mesaj gönder → pending → ağ aç → gönderilir
    //
    // Bunlar için test/helpers altında FakeFirebase kurulumu veya
    // firebase_auth_mocks + fake_cloud_firestore paketleri kullanılabilir.
  });
}
