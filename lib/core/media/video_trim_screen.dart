import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../i18n/app_localizations.dart';
import '../../utils/app_theme.dart';
import 'video_trim_service.dart';

/// 🎬 VİDEO KIRPMA EKRANI
///
/// Video göndermeden önce açılır: kullanıcı başlangıç/bitiş noktalarını
/// sürükleyerek yalnızca istediği bölümü gönderir.
///
/// ── NEDEN ÖNEMLİ ──
/// Uzun videolar hem yüklemeyi dakikalarca sürdürüyor hem depolama
/// giderini büyütüyordu; kullanıcının tek çaresi 500 MB sınırına
/// takılmaktı. Artık 10 dakikalık bir kayıttan 15 saniyelik bölümü
/// gönderebilir.
///
/// ── DAVRANIŞ ──
///  • Aralık DEĞİŞTİRİLMEDİYSE kırpma yapılmaz (gereksiz işlem yok).
///  • Kırpma başarısız olursa ORİJİNAL video gönderilir — kullanıcı
///    videosunu asla kaybetmez.
class VideoTrimScreen extends StatefulWidget {
  final String path;

  const VideoTrimScreen({super.key, required this.path});

  /// Kırpma ekranını aç.
  ///
  /// DÖNÜŞ: gönderilecek dosyanın yolu (kırpılmış veya orijinal),
  /// kullanıcı vazgeçerse `null`.
  static Future<String?> open(BuildContext context, String path) {
    return Navigator.of(context).push<String>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VideoTrimScreen(path: path),
    ));
  }

  @override
  State<VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends State<VideoTrimScreen> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _working = false;

  Duration _total = Duration.zero;
  double _startMs = 0;
  double _endMs = 0;

  /// Kaynak dosya boyutu — kırpma sonrası tahmini boyut için.
  int _srcBytes = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ctrl = VideoPlayerController.file(File(widget.path));
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
      _srcBytes = await File(widget.path).length();

      // Süre önce oynatıcıdan; o veremezse native çözücüden.
      var total = ctrl.value.duration;
      if (total == Duration.zero) {
        total = await VideoTrimService.duration(widget.path);
      }

      if (!mounted) return;
      setState(() {
        _total = total;
        _startMs = 0;
        _endMs = total.inMilliseconds.toDouble();
        _ready = true;
      });
      await ctrl.setLooping(true);
      await ctrl.play();
      ctrl.addListener(_onTick);
    } catch (e) {
      if (!mounted) return;
      // Önizleme açılamadıysa kırpma sunmanın anlamı yok: orijinali gönder.
      Navigator.of(context).pop(widget.path);
    }
  }

  /// Seçili aralığın dışına çıkınca başa sar — kullanıcı yalnızca
  /// GÖNDERECEĞİ bölümü izler.
  void _onTick() {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final posMs = ctrl.value.position.inMilliseconds;
    if (posMs > _endMs || posMs < _startMs - 250) {
      ctrl.seekTo(Duration(milliseconds: _startMs.round()));
    }
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    super.dispose();
  }

  Duration get _selected => Duration(milliseconds: (_endMs - _startMs).round());

  bool get _trimmed => _startMs > 500 || _endMs < _total.inMilliseconds - 500;

  /// Kırpma sonrası TAHMİNİ boyut (bit hızı sabit varsayılır).
  String get _estimatedSize {
    if (_total.inMilliseconds == 0 || _srcBytes == 0) return '';
    final ratio = (_endMs - _startMs) / _total.inMilliseconds;
    final bytes = (_srcBytes * ratio).round();
    final mb = bytes / (1024 * 1024);
    return mb >= 1
        ? '~${mb.toStringAsFixed(1)} MB'
        : '~${(bytes / 1024).round()} KB';
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _send() async {
    // Aralık değişmediyse kırpma YAPMA — gereksiz işlem ve kalite riski.
    if (!_trimmed) {
      Navigator.of(context).pop(widget.path);
      return;
    }

    setState(() => _working = true);
    await _ctrl?.pause();

    final out = await VideoTrimService.trim(
      srcPath: widget.path,
      start: Duration(milliseconds: _startMs.round()),
      end: Duration(milliseconds: _endMs.round()),
    );

    if (!mounted) return;
    setState(() => _working = false);

    if (out == null) {
      // Kırpma başarısız: kullanıcı videosunu kaybetmesin, orijinali gönder.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('video_trim_failed'))),
      );
      Navigator.of(context).pop(widget.path);
      return;
    }
    Navigator.of(context).pop(out.path);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          context.tr('video_trim_title'),
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
      ),
      body: !_ready || ctrl == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: ctrl.value.aspectRatio == 0
                          ? 16 / 9
                          : ctrl.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(ctrl),
                          if (_working)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.primary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── ARALIK SEÇİCİ ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  color: AppTheme.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_fmt(Duration(milliseconds: _startMs.round()))}'
                            '  –  '
                            '${_fmt(Duration(milliseconds: _endMs.round()))}',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          Text(
                            '${_fmt(_selected)}'
                            '${_estimatedSize.isEmpty ? '' : '  ·  $_estimatedSize'}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      RangeSlider(
                        min: 0,
                        // clamp(int, int) `num` döndürür; RangeSlider double
                        // ister. Ayrıca max asla 0 olmamalı (Slider hata verir).
                        max: _total.inMilliseconds
                            .toDouble()
                            .clamp(1.0, 24 * 60 * 60 * 1000.0),
                        values: RangeValues(_startMs, _endMs),
                        activeColor: AppTheme.primary,
                        inactiveColor: AppTheme.textSecondary.withValues(
                          alpha: 0.3,
                        ),
                        onChanged: _working
                            ? null
                            : (v) {
                                // En az 1 saniyelik seçim — 0 uzunlukta
                                // kırpma bozuk dosya üretirdi.
                                if (v.end - v.start < 1000) return;
                                setState(() {
                                  _startMs = v.start;
                                  _endMs = v.end;
                                });
                                ctrl.seekTo(
                                    Duration(milliseconds: v.start.round()));
                              },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _working
                                ? null
                                : () => ctrl.value.isPlaying
                                    ? ctrl.pause().then((_) => setState(() {}))
                                    : ctrl.play().then((_) => setState(() {})),
                            icon: Icon(
                              ctrl.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _working ? null : _send,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: const Color(0xFF04141C),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 12),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text(context.tr('send')),
                          ),
                        ],
                      ),
                      if (_trimmed)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            context.tr('video_trim_keyframe_note'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
