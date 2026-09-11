import 'dart:convert';
import 'package:http/http.dart' as http;

/// Giphy API servisi (trend + arama).
///
/// ⚠️ ANAHTAR ARTIK KAYNAK KODA GÖMÜLMÜYOR.
/// Eski sürümde anahtar sabit bir dizeydi; APK'dan trivial olarak
/// çıkarılabiliyordu (üstelik R8 kapalıydı) ve kota hırsızlığına açıktı.
/// Artık derleme zamanında verilir:
///   flutter build apk --dart-define=GIPHY_API_KEY=xxxx
/// Anahtar verilmezse GIF özelliği sessizce KAPALI kalır (çökme yok).
///
/// GİZLİLİK NOTU: Arama sorgusu ve GIF indirmeleri Giphy'ye gider; yani
/// alıcının IP'si de Giphy CDN'ine görünür. [isEnabled] false ise arayüz
/// GIF sekmesini hiç göstermemelidir.
class GiphyService {
  static const String _apiKey =
      String.fromEnvironment('GIPHY_API_KEY', defaultValue: '');

  /// Anahtar tanımlı mı? Arayüz buna göre GIF sekmesini gösterir/gizler.
  static bool get isEnabled => _apiKey.isNotEmpty;

  static const String _base = 'https://api.giphy.com/v1/gifs';
  static const String _baseStickers = 'https://api.giphy.com/v1/stickers';

  /// Sonuç: gösterim/gönderim için sabit-genişlik GIF URL listesi.
  static Future<List<GiphyGif>> trending({int limit = 24}) =>
      _fetch('$_base/trending?api_key=$_apiKey&limit=$limit&rating=g');

  /// #7 Cikartmalar (seffaf/animasyonlu) — ayni yanit yapisi.
  static Future<List<GiphyGif>> trendingStickers({int limit = 24}) =>
      _fetch('$_baseStickers/trending?api_key=$_apiKey&limit=$limit&rating=g');

  static Future<List<GiphyGif>> searchStickers(String query, {int limit = 24}) {
    final q = Uri.encodeQueryComponent(query);
    return _fetch(
        '$_baseStickers/search?api_key=$_apiKey&q=$q&limit=$limit&rating=g');
  }

  static Future<List<GiphyGif>> search(String query, {int limit = 24}) {
    final q = Uri.encodeQueryComponent(query);
    return _fetch('$_base/search?api_key=$_apiKey&q=$q&limit=$limit&rating=g');
  }

  static Future<List<GiphyGif>> _fetch(String url) async {
    if (!isEnabled) return const [];
    // TIMEOUT ŞART: eski kod zaman aşımı olmadan bekliyordu; kötü ağda
    // GIF paneli sonsuza kadar yükleniyor gibi kalıyordu.
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Giphy hatası: ${res.statusCode}');
    }
    final data = jsonDecode(res.body)['data'] as List? ?? [];
    return data
        .map((e) {
          final images = e['images'] as Map<String, dynamic>? ?? {};
          final fixed = images['fixed_width'] as Map<String, dynamic>? ?? {};
          final url = fixed['url'] as String? ?? '';
          final w = int.tryParse(fixed['width']?.toString() ?? '') ?? 200;
          final h = int.tryParse(fixed['height']?.toString() ?? '') ?? 200;
          return GiphyGif(url: url, width: w, height: h);
        })
        .where((g) => g.url.isNotEmpty)
        .toList();
  }
}

class GiphyGif {
  final String url;
  final int width;
  final int height;
  const GiphyGif(
      {required this.url, required this.width, required this.height});
}
