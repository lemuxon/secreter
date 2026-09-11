import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/deep_link_service.dart';

/// Derin bağlantı = DIŞARIDAN kontrol edilen girdi.
///
/// C-11'de bu akış uygulama kilidini atlıyordu; ayrıca doğrulanmamış kod
/// doğrudan Firestore doküman kimliği olarak kullanılıyordu ('..', '/',
/// çok uzun değerler → ArgumentError). Biçim kapısı bu yüzden var.
void main() {
  group('geçerli davet bağlantısı', () {
    test('kod çıkarılır', () {
      expect(
        DeepLinkService.parseInviteCode(Uri.parse('gizlichat://join/ABC123')),
        'ABC123',
      );
    });

    test('izin verilen alfabe: harf, rakam, alt çizgi, tire', () {
      for (final code in ['abcd', 'A1_b-2', '0000', 'a' * 64]) {
        expect(
          DeepLinkService.parseInviteCode(Uri.parse('gizlichat://join/$code')),
          code,
          reason: 'geçerli sayılmalıydı: $code',
        );
      }
    });
  });

  group('reddedilen bağlantılar', () {
    test('BAŞKA şema/host yoksayılır', () {
      // Başka bir uygulamanın (ya da tarayıcının) gönderdiği bağlantı
      // bizim davet akışımızı tetikleyemez.
      for (final u in [
        'https://join/ABC123',
        'gizlichat://baska/ABC123',
        'http://gizlichat/join/ABC123',
      ]) {
        expect(DeepLinkService.parseInviteCode(Uri.parse(u)), isNull,
            reason: 'reddedilmeliydi: $u');
      }
    });

    test('YOL GEZİNME ve ayırıcı karakterler reddedilir', () {
      // Bu değerler Firestore doküman kimliği olarak kullanılıyordu.
      for (final code in ['..', '.', 'a/b', 'a.b', 'a b', 'a%2Fb']) {
        expect(
          DeepLinkService.parseInviteCode(Uri.parse('gizlichat://join/$code')),
          isNull,
          reason: 'reddedilmeliydi: $code',
        );
      }
    });

    test('ÇOK KISA ve ÇOK UZUN kod reddedilir', () {
      expect(
        DeepLinkService.parseInviteCode(Uri.parse('gizlichat://join/abc')),
        isNull,
        reason: '4 karakterden kısa',
      );
      expect(
        DeepLinkService.parseInviteCode(
            Uri.parse('gizlichat://join/${'a' * 65}')),
        isNull,
        reason: '64 karakterden uzun (1500+ bayt ArgumentError üretiyordu)',
      );
    });

    test('kod YOKSA reddedilir', () {
      expect(
        DeepLinkService.parseInviteCode(Uri.parse('gizlichat://join')),
        isNull,
      );
      expect(
        DeepLinkService.parseInviteCode(Uri.parse('gizlichat://join/')),
        isNull,
      );
    });

    test('baştaki/sondaki boşluk kırpılır, iç boşluk reddedilir', () {
      expect(
        DeepLinkService.parseInviteCode(
            Uri.parse('gizlichat://join/${Uri.encodeComponent('  ABC123  ')}')),
        'ABC123',
      );
      expect(
        DeepLinkService.parseInviteCode(
            Uri.parse('gizlichat://join/${Uri.encodeComponent('AB C123')}')),
        isNull,
      );
    });
  });
}
