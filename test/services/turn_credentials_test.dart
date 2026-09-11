import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/turn_credentials_service.dart';

void main() {
  group('TurnConfig — ICE yapılandırması', () {
    test('TURN varken iceTransportPolicy MUTLAKA relay olur', () {
      // GÜVENLİK AÇISINDAN EN KRİTİK DAVRANIŞ. 'all'a düşerse WebRTC
      // host/srflx adaylarını da toplar ve cihazın gerçek IP'si karşı
      // tarafa gider — relay kurulmuş olsa bile.
      const cfg = TurnConfig(
        urls: ['turn:ornek:3478'],
        username: 'u',
        credential: 'c',
      );
      final rtc = cfg.toRtcConfiguration();

      expect(rtc['iceTransportPolicy'], 'relay');
      expect(cfg.hasRelay, isTrue);

      final servers = rtc['iceServers'] as List;
      expect(servers, hasLength(1));
      expect((servers.first as Map)['urls'], ['turn:ornek:3478']);
      expect((servers.first as Map)['username'], 'u');
      expect((servers.first as Map)['credential'], 'c');
    });

    test('TURN yokken STUN kalır ve politika all olur', () {
      // Relay yokken 'relay' vermek her aramayı imkânsız kılardı.
      final rtc = TurnConfig.none.toRtcConfiguration();

      expect(rtc['iceTransportPolicy'], 'all');
      expect(TurnConfig.none.hasRelay, isFalse);

      final servers = rtc['iceServers'] as List;
      expect(servers, isNotEmpty);
      for (final srv in servers) {
        expect((srv as Map)['urls'].toString(), startsWith('stun:'));
      }
    });

    test('çoklu URL olduğu gibi aktarılır (UDP/TCP/TLS yedeği)', () {
      // Kısıtlı ağlar UDP'yi kapatır; TCP/443 yedeği olmadan o ağlarda
      // arama hiç kurulmaz.
      const urls = [
        'turn:ornek:3478?transport=udp',
        'turn:ornek:3478?transport=tcp',
        'turns:ornek:5349?transport=tcp',
      ];
      const cfg = TurnConfig(urls: urls, username: 'u', credential: 'c');

      final servers = cfg.toRtcConfiguration()['iceServers'] as List;
      expect((servers.first as Map)['urls'], urls);
    });
  });

  group('TurnConfig — geçerlilik süresi', () {
    test('kalıcı kimlik hiç dolmaz', () {
      const cfg = TurnConfig(urls: ['turn:a:3478'], username: 'u');
      expect(cfg.expiresWithin(const Duration(days: 365)), isFalse);
    });

    test('yakında dolacak kimlik erken tazelenir', () {
      final cfg = TurnConfig(
        urls: const ['turn:a:3478'],
        username: 'u',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      // Arama ORTASINDA dolmasın diye pay bırakılır.
      expect(cfg.expiresWithin(const Duration(minutes: 10)), isTrue);
      expect(cfg.expiresWithin(const Duration(minutes: 1)), isFalse);
    });

    test('süresi geçmiş kimlik her payda dolmuş sayılır', () {
      final cfg = TurnConfig(
        urls: const ['turn:a:3478'],
        username: 'u',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(cfg.expiresWithin(Duration.zero), isTrue);
    });
  });

  group('derleme sabiti yedeği', () {
    test('--dart-define verilmemişse relay YOKTUR', () {
      // Testte SECRETER_TURN_* tanımlı değil. Burada boş olmayan bir
      // yapılandırma dönmesi, kimliksiz relay denemesi demek olurdu:
      // `iceTransportPolicy: relay` + geçersiz kimlik = hiç kurulamayan
      // arama.
      expect(TurnCredentialsService.staticFallback.hasRelay, isFalse);
      expect(TurnCredentialsService.staticFallback.urls, isEmpty);
    });
  });
}
