import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../media/secure_media_cache.dart';
import '../../utils/app_theme.dart';
import '../observability/handled_error.dart';

/// 🖼️ ŞİFRELİ MEDYA GÖSTERİCİ
///
/// `CachedNetworkImage` yalnızca DÜZ (şifresiz) URL'leri açabilir. Ekler
/// artık uçtan uca şifreli olduğu için görüntü, önce indirilip çözülmeli
/// ve YEREL dosyadan çizilmelidir.
///
/// Bu widget iki durumu da tek yerde ele alır:
///  • [mediaKey] varsa → indir + çöz + `Image.file`
///  • yoksa (eski mesajlar) → eskisi gibi `CachedNetworkImage`
///
/// Böylece çağrı yerleri tek satırda değiştirilebildi ve geçmiş mesajlar
/// bozulmadı.
class SecureMediaImage extends StatefulWidget {
  final String url;
  final String? mediaKey;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  /// Görüntü GERÇEKTEN çizilebilir hâle geldiğinde BİR KEZ çağrılır.
  ///
  /// Tek görüntülük medya için şarttır: "görüldü" sayımı zamana değil,
  /// çözmenin başarısına bağlanmalı. Aksi hâlde açılmayan bir fotoğraf
  /// da tüketilir ve kullanıcı hiç görmediği hakkını kaybeder (§4ba).
  final VoidCallback? onLoaded;

  const SecureMediaImage({
    super.key,
    required this.url,
    this.mediaKey,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.onLoaded,
  });

  @override
  State<SecureMediaImage> createState() => _SecureMediaImageState();
}

class _SecureMediaImageState extends State<SecureMediaImage> {
  Future<File>? _future;

  /// `onLoaded` yalnızca BİR KEZ ateşlenir; `build` birçok kez çalışır.
  bool _bildirildi = false;

  /// Çizim sırasında setState/callback çağırmak yasak → kareden sonra.
  void _yuklendiBildir() {
    if (_bildirildi || widget.onLoaded == null) return;
    _bildirildi = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoaded!();
    });
  }

  /// Hata bir kez raporlanır; `build` defalarca çalışır.
  bool _hataBildirildi = false;

  void _hataBildir(Object? hata) {
    if (_hataBildirildi) return;
    _hataBildirildi = true;
    reportHandled('Şifreli medya açılamadı', hata ?? StateError('bos_sonuc'));
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant SecureMediaImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.mediaKey != widget.mediaKey) {
      _bildirildi = false;
      _hataBildirildi = false;
      _start();
    }
  }

  void _start() {
    if (widget.mediaKey == null || widget.mediaKey!.isEmpty) {
      _future = null;
      return;
    }
    _future = SecureMediaCache.instance.resolve(
      widget.url,
      key: widget.mediaKey,
      ext: 'img',
    );
  }

  Widget get _loading =>
      widget.placeholder ??
      Container(
        width: widget.width,
        height: widget.height,
        color: AppTheme.surface,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primary),
          ),
        ),
      );

  Widget get _error =>
      widget.errorWidget ??
      Container(
        width: widget.width,
        height: widget.height,
        color: AppTheme.surface,
        child: const Center(
          child:
              Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // ESKİ (şifresiz) mesajlar — davranış aynen korunur.
    if (_future == null) {
      return CachedNetworkImage(
        imageUrl: widget.url,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        placeholder: (_, __) => _loading,
        errorWidget: (_, __, ___) => _error,
        imageBuilder: (context, provider) {
          _yuklendiBildir();
          return Image(
            image: provider,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
          );
        },
      );
    }

    return FutureBuilder<File>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _loading;
        if (snap.hasError || !snap.hasData) {
          // ⚠️ SESSİZ KIRIK RESİM. Kullanıcı yalnızca bir simge görür;
          // indirme mi düştü, anahtar mı yanlış, dosya mı kurcalanmış —
          // hiçbiri bilinmezdi. "Resimler açılmıyor" şikâyetinin
          // teşhisini bu eksiklik tıkadı.
          // URL raporlanmaz: Storage yolu sohbet kimliğini taşır.
          _hataBildir(snap.error);
          return _error;
        }
        _yuklendiBildir();
        return Image.file(
          snap.data!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          // Çözülmüş dosya diskte; bellekte tekrar tutmaya gerek yok.
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _error,
        );
      },
    );
  }
}
