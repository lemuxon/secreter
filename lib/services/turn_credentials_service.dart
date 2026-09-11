import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Bir aramada kullanılacak TURN yapılandırması.
///
/// [urls] boşsa relay YOKTUR: arama STUN ile P2P kurulur ve taraflar
/// birbirinin IP adresini görür.
@immutable
class TurnConfig {
  final List<String> urls;
  final String? username;
  final String? credential;

  /// Kısa ömürlü kimliğin geçerlilik sonu. Derleme sabitinden gelen
  /// (kalıcı) kimlikte null'dur.
  final DateTime? expiresAt;

  /// Kimlik sunucudan mı üretildi? Yalnızca tanılama/günlük için.
  final bool ephemeral;

  const TurnConfig({
    this.urls = const [],
    this.username,
    this.credential,
    this.expiresAt,
    this.ephemeral = false,
  });

  /// TURN yok — arama STUN'a düşer.
  static const TurnConfig none = TurnConfig();

  bool get hasRelay => urls.isNotEmpty;

  /// Süresi dolmuş (ya da dolmak üzere) mi?
  bool expiresWithin(Duration margin) {
    final exp = expiresAt;
    if (exp == null) return false; // kalıcı kimlik
    return DateTime.now().add(margin).isAfter(exp);
  }

  /// `flutter_webrtc`'nin beklediği ICE yapılandırması.
  ///
  /// `iceTransportPolicy: relay` KRİTİKTİR: yalnızca relay adayları
  /// toplanır, yani cihazın gerçek IP'si karşı tarafa HİÇ gitmez.
  /// TURN yoksa 'all' kullanılır — bağlantı kurulur ama IP görünür.
  Map<String, dynamic> toRtcConfiguration() => {
        'iceServers': [
          if (hasRelay)
            {
              'urls': urls,
              'username': username ?? '',
              'credential': credential ?? '',
            }
          else ...[
            // TURN yokken en azından bağlantı kurulabilsin.
            {'urls': 'stun:stun.l.google.com:19302'},
            {'urls': 'stun:stun1.l.google.com:19302'},
          ],
        ],
        'iceTransportPolicy': hasRelay ? 'relay' : 'all',
        'sdpSemantics': 'unified-plan',
      };
}

/// 🔀 TURN KİMLİK BİLGİSİ SAĞLAYICISI
///
/// İki kaynak, bu sırayla:
///
/// 1. **`getTurnCredentials` Cloud Function** — kısa ömürlü kimlik.
///    Coturn'ün `use-auth-secret` şeması: sır sunucuda kalır, istemci
///    saatlerle ölçülen ve kendiliğinden geçersizleşen bir parola alır.
/// 2. **`--dart-define` sabitleri** — function yoksa/erişilemezse yedek.
///    ⚠️ Bu değerler APK'dan ÇIKARILABİLİR (Giphy anahtarındaki sorunun
///    aynısı, bkz. H-19) ve döndürmek yeni sürüm gerektirir. Yalnızca
///    geçiş dönemi ya da acil durum içindir.
///
/// İkisi de yoksa arama STUN ile kurulur ve **IP gizlenemez**.
class TurnCredentialsService {
  TurnCredentialsService._();

  // ── Derleme zamanı yedeği ──
  // Virgülle AYRILMIŞ liste kabul eder: kısıtlı ağlarda UDP kapalı
  // olabildiği için TCP/TLS(443) yedeği şart.
  static const String _staticUrls =
      String.fromEnvironment('SECRETER_TURN_URL', defaultValue: '');
  static const String _staticUser =
      String.fromEnvironment('SECRETER_TURN_USER', defaultValue: '');
  static const String _staticPass =
      String.fromEnvironment('SECRETER_TURN_PASS', defaultValue: '');

  /// Arama kurulumunu bekletmemek için kısa tutulur; aşılırsa yedeğe
  /// düşülür (aramayı hiç kurmamaktansa IP'si görünen bir arama).
  static const Duration _timeout = Duration(seconds: 6);

  /// Kimliğin arama ORTASINDA dolmaması için erken tazele.
  static const Duration _renewMargin = Duration(minutes: 10);

  /// GEÇİCİ hatadan sonra ne kadar beklenip tekrar denensin.
  static const Duration _retryAfterFailure = Duration(minutes: 2);

  static TurnConfig? _cached;

  /// Dolduğunda önbellek tazelenir. null ise tekrar denemeye gerek yok
  /// (kimlik geçerli ya da sunucuda TURN kesin olarak yapılandırılmamış).
  static DateTime? _retryAt;

  /// Aynı anda iki arama açılırsa function'a tek istek gitsin.
  static Future<TurnConfig>? _inFlight;

  /// Derleme sabitlerinden gelen yapılandırma (yoksa [TurnConfig.none]).
  static TurnConfig get staticFallback {
    final urls = _splitUrls(_staticUrls);
    if (urls.isEmpty) return TurnConfig.none;
    return TurnConfig(
      urls: urls,
      username: _staticUser,
      credential: _staticPass,
    );
  }

  static List<String> _splitUrls(String raw) => raw
      .split(',')
      .map((u) => u.trim())
      .where((u) => u.isNotEmpty)
      .toList(growable: false);

  /// Kullanılabilir yapılandırmayı döndür (gerekiyorsa sunucudan al).
  static Future<TurnConfig> resolve() {
    final cached = _cached;
    final retryDue = _retryAt != null && !DateTime.now().isBefore(_retryAt!);
    if (cached != null && !cached.expiresWithin(_renewMargin) && !retryDue) {
      return Future.value(cached);
    }
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  /// Sonucu beklemeden ısıt. Arama başlarken çağrılır; mikrofon/kamera
  /// izni ve `getUserMedia` zaten zaman aldığı için istek onun ARKASINA
  /// gizlenir ve arama kurulumu gecikmez.
  static void prefetch() {
    resolve().catchError((_) => TurnConfig.none);
  }

  /// Hesap değişimi / çıkış: kimlik o oturuma aitti.
  static void invalidate() {
    _cached = null;
    _retryAt = null;
  }

  static Future<TurnConfig> _fetch() async {
    // Hata GEÇİCİ mi (ağ/zaman aşımı) yoksa sunucunun kesin cevabı mı
    // ("TURN yapılandırılmamış")? Geçici hatada yedeği kalıcı önbelleğe
    // almak, tek bir ağ tökezlemesi yüzünden oturumun KALANINDAKİ tüm
    // aramaları IP'si açık hâle getirirdi.
    var transient = true;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('getTurnCredentials');
      final res =
          await callable.call<Map<String, dynamic>?>().timeout(_timeout);
      final data = res.data;

      if (data != null && data['configured'] == true) {
        final urls = (data['urls'] as List?)
                ?.map((u) => u.toString().trim())
                .where((u) => u.isNotEmpty)
                .toList(growable: false) ??
            const <String>[];
        final username = data['username']?.toString();
        final credential = data['credential']?.toString();
        final expSec = (data['expiresAt'] as num?)?.toInt();

        // Eksik alanla relay kurmaya çalışmak, `iceTransportPolicy:
        // relay` yüzünden aramayı HİÇ kurulamaz yapardı — yedeğe düş.
        if (urls.isNotEmpty &&
            username != null &&
            username.isNotEmpty &&
            credential != null &&
            credential.isNotEmpty) {
          final cfg = TurnConfig(
            urls: urls,
            username: username,
            credential: credential,
            expiresAt: expSec == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(expSec * 1000),
            ephemeral: true,
          );
          _cached = cfg;
          _retryAt = null;
          return cfg;
        }
        // Sunucu cevap verdi ama yükü bozuk: tekrar denemek düzeltmez.
        transient = false;
        debugPrint('TURN: sunucu eksik alan döndürdü — yedeğe düşülüyor');
      } else {
        // Sunucuda TURN yapılandırılmamış. Beklenen bir durum, hata değil.
        transient = false;
        debugPrint('TURN: sunucuda yapılandırılmamış');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('TURN kimliği alınamadı (${e.code}): ${e.message}');
    } on TimeoutException {
      debugPrint('TURN kimliği alınamadı: zaman aşımı');
    } catch (e) {
      debugPrint('TURN kimliği alınamadı: $e');
    }

    // Yedeği önbelleğe al: her aramada başarısız bir function çağrısı
    // yapıp kurulumu geciktirmenin anlamı yok. Geçici hatada kısa bir
    // süre sonra yeniden denenir, kesin cevapta hiç denenmez.
    final fallback = staticFallback;
    _cached = fallback;
    _retryAt = transient ? DateTime.now().add(_retryAfterFailure) : null;
    return fallback;
  }
}
