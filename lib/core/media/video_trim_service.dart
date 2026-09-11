import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 🎬 VİDEO KIRPMA KÖPRÜSÜ
///
/// Kırpma işini Android'in yerleşik `MediaExtractor` + `MediaMuxer`
/// ikilisi yapar (bkz. `VideoTrimmer.kt`). Bu tercih bilinçlidir:
/// `ffmpeg_kit_flutter` APK'ya 30–80 MB eklerdi ve uygulama zaten
/// ~103 MB. Yerleşik çözüm ek boyut getirmez, yeniden kodlama yapmaz —
/// bu yüzden hem çok hızlıdır hem de kalite kaybı olmaz.
class VideoTrimService {
  static const _channel = MethodChannel('com.gizlichat.app/media');

  /// Videonun süresi. Okunamazsa [Duration.zero].
  static Future<Duration> duration(String path) async {
    try {
      final ms = await _channel.invokeMethod<int>('videoDuration', {
        'src': path,
      });
      return Duration(milliseconds: ms ?? 0);
    } on PlatformException catch (e) {
      debugPrint('Video süresi okunamadı: ${e.message}');
      return Duration.zero;
    } on MissingPluginException {
      // iOS/desktop: köprü yok — kırpma devre dışı kalır.
      return Duration.zero;
    }
  }

  /// Videoyu [start]–[end] aralığına kırp.
  ///
  /// Dönüş: kırpılmış dosya. Kırpma başarısız olursa `null` döner ve
  /// çağıran taraf ORİJİNALİ göndermelidir — kullanıcı videosunu
  /// kaybetmemeli.
  static Future<File?> trim({
    required String srcPath,
    required Duration start,
    required Duration end,
  }) async {
    if (end <= start) return null;
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final dst = '${dir.path}/trim_$stamp.mp4';

      final out = await _channel.invokeMethod<String>('trimVideo', {
        'src': srcPath,
        'dst': dst,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
      });
      if (out == null) return null;

      final file = File(out);
      if (!await file.exists() || await file.length() == 0) return null;
      return file;
    } on PlatformException catch (e) {
      debugPrint('Video kırpılamadı: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('Video kırpma hatası: $e');
      return null;
    }
  }

  /// Bu platformda kırpma destekleniyor mu?
  static bool get isSupported => Platform.isAndroid;
}
