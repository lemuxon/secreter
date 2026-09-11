import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/auth_service.dart';

/// Kullanıcı adı BİÇİM kuralı.
///
/// 🐞 GERÇEK KULLANICIDA GÖRÜLDÜ (2026-09-10): "hesap ekle"den kaydolmaya
/// çalışan biri "nick hatalı" hatası aldı. Sebep, adında TÜRKÇE KARAKTER
/// olmasıydı — kural `^[a-zA-Z0-9_]{3,20}$`, yani ASCII.
///
/// ⚠️ ASCII KISITI BİLİNÇLİDİR, gevşetilmemeli: kullanıcı adı kişilerin
/// birbirini tanıdığı kimliktir ve "ı/i", "İ/I" gibi homograf çiftleri
/// TAKLİT yüzeyi açar. Sorun kuralda değil, anlatımdaydı:
///   • mesaj yalnızca "harf/rakam" diyordu (Türkçe konuşan ş/ğ/ı'yı da
///     harf sayar) → artık "(a-z, 0-9, _)" yazıyor, 16 dilde,
///   • kural YALNIZCA `register()` içindeydi → canlı kontrol biçime hiç
///     bakmıyordu, kişi ancak "Kaydet"e basınca reddediliyordu.
void main() {
  group('kabul edilenler', () {
    for (final ad in ['ali', 'ayse', 'user_1', 'ABC', 'a_1', 'x' * 20]) {
      test('"$ad" geçerli', () {
        expect(AuthService.isValidUsernameFormat(ad), isTrue);
      });
    }

    test('baştaki/sondaki boşluk kırpılır', () {
      expect(AuthService.isValidUsernameFormat('  ali  '), isTrue);
    });
  });

  group('TÜRKÇE KARAKTERLER reddedilir (taklit yüzeyi)', () {
    for (final ad in ['özlem', 'ayşe', 'çağrı', 'gülşah', 'ismail_İ']) {
      test('"$ad" reddedilir', () {
        expect(AuthService.isValidUsernameFormat(ad), isFalse,
            reason: 'homograf taklidini önlemek için ASCII zorunlu');
      });
    }
  });

  group('diğer reddedilenler', () {
    test('3 karakterden kısa', () {
      expect(AuthService.isValidUsernameFormat('ab'), isFalse);
    });

    test('20 karakterden uzun', () {
      expect(AuthService.isValidUsernameFormat('x' * 21), isFalse);
    });

    test('boşluk içeren', () {
      expect(AuthService.isValidUsernameFormat('ali veli'), isFalse);
    });

    test('nokta/tire içeren', () {
      expect(AuthService.isValidUsernameFormat('ali.veli'), isFalse);
      expect(AuthService.isValidUsernameFormat('ali-veli'), isFalse);
    });

    test('emoji içeren', () {
      expect(AuthService.isValidUsernameFormat('ali😀'), isFalse);
    });

    test('boş', () {
      expect(AuthService.isValidUsernameFormat(''), isFalse);
      expect(AuthService.isValidUsernameFormat('   '), isFalse);
    });
  });
}
