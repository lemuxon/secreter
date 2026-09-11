import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/media/secure_media_cache.dart';
import '../../../../core/observability/handled_error.dart';

/// 🎥 Uygulama-ici video oynatici: oynat/duraklat, ilerleme cubugu,
/// sure gostergesi. Basit ve pilsiz — harici oynaticiya cikilmaz.
class VideoPlayerScreen extends StatefulWidget {
  final String url;

  /// Şifreli ek anahtarı. null ise video ŞİFRESİZDİR (eski mesajlar).
  final String? mediaKey;

  const VideoPlayerScreen({super.key, required this.url, this.mediaKey});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _ctrlOrNull;
  VideoPlayerController get _ctrl => _ctrlOrNull!;
  set _ctrl(VideoPlayerController c) => _ctrlOrNull = c;
  bool _ready = false;
  bool _error = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _hazirla();
  }

  /// 🐞 VİDEO ŞİFRELİ URL'DEN OYNATILMAYA ÇALIŞILIYORDU (§4as).
  ///
  /// `sendMediaMessage` HER medya tipini AES-GCM ile şifreler (görsel,
  /// video, ses, dosya) ve Storage'a `application/octet-stream` yazar.
  /// Eski kod `VideoPlayerController.networkUrl(url)` diyordu; oynatıcı
  /// ŞİFRELİ baytları alıyor ve video HİÇ açılmıyordu. Görseller
  /// çalışıyordu çünkü onlar `SecureMediaImage` üzerinden çözülüyor —
  /// bu yüzden hata yalnızca videoda görünüyordu.
  ///
  /// Artık dosya önce indirilip ÇÖZÜLÜYOR, sonra yerelden oynatılıyor.
  Future<void> _hazirla() async {
    try {
      if (widget.mediaKey != null && widget.mediaKey!.isNotEmpty) {
        final dosya = await SecureMediaCache.instance
            .resolve(widget.url, key: widget.mediaKey, ext: 'mp4');
        _ctrl = VideoPlayerController.file(dosya);
      } else {
        // Eski (şifresiz) mesajlar
        _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      }
      await _ctrl.initialize();
      if (!mounted) return;
      _ctrl.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() => _ready = true);
      await _ctrl.play();
    } catch (e, s) {
      reportHandled('Video açılamadı', e, stack: s);
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    // Çözme sürerken ekrandan çıkılmış olabilir: denetleyici hiç
    // kurulmamış olabileceği için null kontrolü şart.
    _ctrlOrNull?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _error
          ? Center(
              child: Text(context.tr('video_load_fail'),
                  style: const TextStyle(color: Colors.white70)))
          : !_ready
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : GestureDetector(
                  onTap: () => setState(() => _showControls = !_showControls),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _ctrl.value.aspectRatio == 0
                              ? 16 / 9
                              : _ctrl.value.aspectRatio,
                          child: VideoPlayer(_ctrl),
                        ),
                      ),
                      if (_showControls) ...[
                        // oynat/duraklat
                        GestureDetector(
                          onTap: () {
                            _ctrl.value.isPlaying
                                ? _ctrl.pause()
                                : _ctrl.play();
                          },
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _ctrl.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                        // alt bar: konum + slider + sure
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 18,
                          child: Row(
                            children: [
                              Text(_fmt(_ctrl.value.position),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              Expanded(
                                child: Slider(
                                  value:
                                      _ctrl.value.duration.inMilliseconds == 0
                                          ? 0
                                          : _ctrl.value.position.inMilliseconds
                                              .clamp(
                                                  0,
                                                  _ctrl.value.duration
                                                      .inMilliseconds)
                                              .toDouble(),
                                  max: _ctrl.value.duration.inMilliseconds
                                      .toDouble()
                                      .clamp(1, double.infinity),
                                  activeColor: AppTheme.primary,
                                  inactiveColor: Colors.white24,
                                  onChanged: (v) => _ctrl.seekTo(
                                      Duration(milliseconds: v.toInt())),
                                ),
                              ),
                              Text(_fmt(_ctrl.value.duration),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
