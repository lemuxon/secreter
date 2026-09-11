import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Buzlu cam yüzey — tasarımın imza malzemesi.
///
/// `BackdropFilter` ile arkasındaki içeriği bulanıklaştırır, üstüne ince
/// yarı saydam bir katman koyar. AppBar ve mesaj giriş çubuğu gibi
/// "yüzen" yüzeylerde kullanılır.
///
/// ⚠️ PERFORMANS: BackdropFilter GPU maliyetlidir. Sınırlı ve küçük
/// alanlarda kullan (üst/alt çubuklar gibi); uzun listelerde her öğeye
/// uygulama. Düşük donanımda `intensity` düşürülebilir.
class FrostedSurface extends StatelessWidget {
  final Widget child;
  final double intensity; // bulanıklık miktarı (sigma)
  final Color? tint;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  const FrostedSurface({
    super.key,
    required this.child,
    this.intensity = 18,
    this.tint,
    this.borderRadius,
    this.border,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: intensity, sigmaY: intensity),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? AppTheme.surface.withValues(alpha: 0.62),
            borderRadius: radius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Üstte ince bir ayraç çizgisiyle biten buzlu üst çubuk (AppBar altı).
/// Saydam AppBar'ın altında, içeriğin üzerinde "yüzer".
class FrostedTopBar extends StatelessWidget {
  final Widget child;
  final double height;

  const FrostedTopBar({
    super.key,
    required this.child,
    this.height = kToolbarHeight,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return FrostedSurface(
      // PERFORMANS: kaydirma sirasinda HER KAREDE canli blur hesaplanir;
      // sigma 22 orta seviye cihazlarda kare dusurur. 10 = ayni buzlu his,
      // ~yari maliyet.
      intensity: 10,
      tint: AppTheme.background.withValues(alpha: 0.55),
      border: const Border(
        bottom: BorderSide(color: AppTheme.glassTint, width: 0.5),
      ),
      child: SizedBox(
        height: height + topInset,
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: child,
        ),
      ),
    );
  }
}
