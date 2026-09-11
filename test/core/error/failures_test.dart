import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/error/failures.dart';

void main() {
  group('Failure', () {
    test('aynı tip ve mesajdaki failure\'lar eşittir (Equatable)', () {
      const a = ServerFailure('hata');
      const b = ServerFailure('hata');
      expect(a, b); // Equatable sayesinde
    });

    test('farklı mesajdaki failure\'lar eşit değildir', () {
      const a = ServerFailure('hata1');
      const b = ServerFailure('hata2');
      expect(a, isNot(b));
    });

    // Varsayılan mesajlar artık ÇEVİRİ ANAHTARI taşır (sabit Türkçe metin
    // değil): arayüz `context.tr(failure.message)` ile kullanıcının diline
    // çevirir. Test bu sözleşmeyi doğrular — sabit metne dönmek 8 dilde
    // hatalı gösterime yol açar.
    test('varsayılan mesajlar i18n anahtarıdır', () {
      expect(const NetworkFailure().message, 'err_network');
      expect(const AuthFailure().message, 'err_auth');
      expect(const ServerFailure().message, 'err_server');
      expect(const EncryptionFailure().message, 'err_crypto');
      expect(const CacheFailure().message, 'err_cache');
      expect(const ValidationFailure().message, 'err_invalid');
      expect(const UnexpectedFailure().message, 'err_unexpected');
    });

    test('anahtarlar snake_case ve boşluksuz (tr() ile uyumlu)', () {
      const failures = <Failure>[
        ServerFailure(),
        NetworkFailure(),
        AuthFailure(),
        EncryptionFailure(),
        CacheFailure(),
        ValidationFailure(),
        UnexpectedFailure(),
      ];
      for (final f in failures) {
        expect(f.message, matches(r'^[a-z0-9_]+$'),
            reason: '${f.runtimeType} mesajı çeviri anahtarı olmalı');
      }
    });

    test('farklı failure tipleri birbirinden ayrıştırılabilir', () {
      const Failure server = ServerFailure();
      const Failure network = NetworkFailure();

      expect(server, isA<ServerFailure>());
      expect(network, isA<NetworkFailure>());
      expect(server, isNot(isA<NetworkFailure>()));
    });
  });
}
