import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:gizli_chat/core/security/security_alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🛡️ GÜVENLİK UYARILARI — kullanıcıya görünürlük
///
/// §4p yutulan hataları GELİŞTİRİCİYE görünür kıldı. Ama bazı
/// başarısızlıklar bir güvenlik SÖZÜNÜ bozuyor ve bunu bilmesi gereken
/// kişi kullanıcı: grup anahtarı rotasyonu başarısız olursa, gruptan
/// ATILAN üye eski anahtarla sonraki mesajları çözmeye devam edebilir.
/// Kullanıcı ise "onu attım, artık okuyamaz" sanır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('grup anahtarı rotasyonu bayrağı', () {
    test('varsayılan olarak uyarı YOKTUR', () async {
      expect(await SecurityAlerts.groupKeyRotationFailed('g1'), isFalse);
    });

    test('başarısızlık kaydedilir ve okunur', () async {
      await SecurityAlerts.setGroupKeyRotationFailed('g1', true);
      expect(await SecurityAlerts.groupKeyRotationFailed('g1'), isTrue);
    });

    test('BAŞARILI rotasyon uyarıyı TEMİZLER', () async {
      // ⚠️ Bu olmazsa uyarı sonsuza kadar kalır ve kullanıcı gerçek bir
      // uyarıyı da görmezden gelmeye başlar.
      await SecurityAlerts.setGroupKeyRotationFailed('g1', true);
      await SecurityAlerts.setGroupKeyRotationFailed('g1', false);
      expect(await SecurityAlerts.groupKeyRotationFailed('g1'), isFalse);
    });

    test('bayrak SOHBETE ÖZELDİR (bir grubun uyarısı diğerine sızmaz)',
        () async {
      await SecurityAlerts.setGroupKeyRotationFailed('g1', true);
      expect(await SecurityAlerts.groupKeyRotationFailed('g2'), isFalse);
    });
  });

  group('şifresiz grup bayrağı', () {
    test('varsayılan olarak uyarı YOKTUR', () async {
      expect(await SecurityAlerts.groupSendsPlaintext('g1'), isFalse);
    });

    test('şifresiz durum kaydedilir', () async {
      await SecurityAlerts.setGroupSendsPlaintext('g1', true);
      expect(await SecurityAlerts.groupSendsPlaintext('g1'), isTrue);
    });

    test('şifreleme çalışınca bayrak TEMİZLENİR', () async {
      // Anahtarlar yayınlanınca grup şifrelenmeye başlar; bant kalıcı
      // olsaydı kullanıcı bir süre sonra onu da görmezden gelirdi.
      await SecurityAlerts.setGroupSendsPlaintext('g1', true);
      await SecurityAlerts.setGroupSendsPlaintext('g1', false);
      expect(await SecurityAlerts.groupSendsPlaintext('g1'), isFalse);
    });

    test('bayrak SOHBETE ÖZELDİR', () async {
      await SecurityAlerts.setGroupSendsPlaintext('g1', true);
      expect(await SecurityAlerts.groupSendsPlaintext('g2'), isFalse);
    });
  });

  group('doğrulama önerisi', () {
    test('varsayılan olarak KAPATILMAMIŞTIR (öneri gösterilir)', () async {
      expect(await SecurityAlerts.verifyPromptDismissed('c1'), isFalse);
    });

    test('kapatma kalıcıdır', () async {
      await SecurityAlerts.dismissVerifyPrompt('c1');
      expect(await SecurityAlerts.verifyPromptDismissed('c1'), isTrue);
    });

    test('kapatma SOHBETE ÖZELDİR', () async {
      await SecurityAlerts.dismissVerifyPrompt('c1');
      expect(await SecurityAlerts.verifyPromptDismissed('c2'), isFalse);
    });
  });

  group('metinler çevrilebilir', () {
    String tr(String k, String lang) => AppLocalizations(Locale(lang)).t(k);

    test('uyarı ve öneri metinleri tr + en tanımlı', () {
      const keys = [
        'sec_rotation_failed',
        'sec_rotation_retry',
        'sec_rotation_fixed',
        'sec_verify_prompt',
        'sec_verify_later',
        'sec_group_plaintext',
      ];
      for (final k in keys) {
        expect(tr(k, 'tr'), isNot(k), reason: '$k → tr yok');
        expect(tr(k, 'en'), isNot(k), reason: '$k → en yok');
      }
    });
  });
}
