import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// #16 ÇEVİRİ SERVİSİ
///
/// ⚠️ GIZLILIK: Ceviri, mesaj metnini UCUNCU TARAF servise gonderir —
/// yani o mesaj icin uctan uca sifreleme korumasi disina cikilir. Bu
/// nedenle ozellik VARSAYILAN KAPALI'dir; ilk kullanimda kullanicidan
/// acik onay alinir (consent) ve onay yerel olarak saklanir.
///
/// Saglayici: Google'in anahtarsiz "gtx" ucu (resmi degil) — basarisiz
/// olursa MyMemory ucretsiz API'sine duser. Ikisi de anahtar istemez.
class TranslationService {
  static const _consentKey = 'translate_consent_v1';

  /// Bellek onbellegi: ayni mesaj tekrar cevrilmesin (hem hiz hem gizlilik:
  /// metin servise yalnizca BIR kez gider).
  static final Map<String, String> _cache = {};

  static Future<bool> hasConsent() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_consentKey) ?? false;
  }

  static Future<void> setConsent(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_consentKey, v);
  }

  static String _key(String text, String target) => '$target::$text';

  /// Metni hedef dile cevir. Onbellekte varsa AG'A CIKMAZ.
  static Future<String> translate(String text, {String target = 'en'}) async {
    // ONAY ZORUNLU: bu metot mesaj metnini ÜÇÜNCÜ TARAFA gönderir.
    // Onay kontrolü yalnızca arayüzde olursa, ileride eklenen bir çağrı
    // yolu sessizce E2EE'nin dışına veri taşıyabilir. Kapı burada.
    if (!await hasConsent()) {
      throw StateError('translate_consent_required');
    }

    final k = _key(text, target);
    final cached = _cache[k];
    if (cached != null) return cached;

    // ⚠️ MyMemory YEDEĞİ KALDIRILDI.
    // Ücretsiz MyMemory ucu, gönderilen metinleri KAMUYA AÇIK bir çeviri
    // belleği korpusuna katar — yani mesaj içeriği kalıcı olarak
    // yayınlanabilir. Bir gizlilik uygulamasında kabul edilemez; ayrıca
    // `langpair=en|$target` sabitti, Türkçe kaynak metinde çeviri
    // zaten bozuk çıkıyordu.
    final out = await _viaGoogleGtx(text, target);
    if (out == null || out.trim().isEmpty) {
      throw Exception('translate_failed');
    }

    // Önbellek sınırı: düz metin RAM'de sınırsız birikmesin.
    if (_cache.length > 200) {
      for (final key in _cache.keys.take(50).toList()) {
        _cache.remove(key);
      }
    }
    _cache[k] = out;
    return out;
  }

  /// Bellekteki çeviri kopyalarını temizle (kilitlenme / çıkış).
  static void clearCache() => _cache.clear();

  static Future<String?> _viaGoogleGtx(String text, String target) async {
    final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx'
        '&sl=auto&tl=$target&dt=t&q=${Uri.encodeQueryComponent(text)}');
    final res = await http.get(url).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    // Yanit: [[["ceviri","kaynak",...],...],...]
    final data = jsonDecode(res.body);
    if (data is! List || data.isEmpty || data[0] is! List) return null;
    final buf = StringBuffer();
    for (final seg in (data[0] as List)) {
      if (seg is List && seg.isNotEmpty && seg[0] is String) {
        buf.write(seg[0] as String);
      }
    }
    final s = buf.toString();
    return s.isEmpty ? null : s;
  }
}
