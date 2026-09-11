import 'package:flutter/material.dart';

/// SECRETER tasarım sistemi — "Buzlu Obsidyen".
///
/// Felsefe: Gizlilik görünür bir malzeme. Obsidyen derinlik + buzlu cam
/// katmanlar. İki tonlu aksan ANLAM taşır:
///   - cyan (primary)  → etkileşim
///   - mint (online)   → güvenlik / doğrulanmış / çevrimiçi
///
/// Eski ekranların bozulmaması için sabit İSİMLERİ korundu, sadece
/// DEĞERLERİ yenilendi. Yeni token'lar (Spacing/Radii/Motion) eklendi.
class AppTheme {
  // ── Çekirdek palet ──
  static const Color primary = Color(0xFF35C2F0); // camgöbeği — etkileşim
  static const Color primaryDark = Color(0xFF1E9FD4);
  static const Color background = Color(0xFF0B0F14); // obsidyen — en derin
  static const Color surface = Color(0xFF151B23); // arduvaz — yükseltilmiş
  static const Color surfaceLight = Color(0xFF1E2730); // buz — kart
  static const Color bubbleSent = Color(0xFF14323F); // cyan-tonlu koyu (benim)
  static const Color bubbleReceived =
      Color(0xFF161D26); // zemine yakın (sessiz)
  static const Color textPrimary =
      Color(0xFFE9EEF3); // yumuşak beyaz (OLED dostu)
  static const Color textSecondary = Color(0xFF7E8C9A); // sis
  static const Color divider = Color(0xFF0C1117); // zemine gömülü
  static const Color online = Color(0xFF34D399); // nane — güvenlik/çevrimiçi
  static const Color danger = Color(0xFFFB6F8D); // kor — yumuşak gül-kırmızı

  // İsteğe bağlı yardımcı tonlar (yeni kod için)
  static const Color secure = online; // E2EE göstergeleri
  static const Color glassTint = Color(0x14FFFFFF); // buzlu cam üst katman

  static ThemeData get darkTheme {
    // M3 tohum-tabanlı şema, sonra marka renklerini sabitliyoruz
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      onPrimary: const Color(0xFF04141C),
      secondary: online,
      surface: surface,
      onSurface: textPrimary,
      error: danger,
      outline: const Color(0xFF2A3743),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,

      // AppBar saydam — buzlu cam overlay üstte render edilir
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF04141C),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF04141C),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      // Tip ölçeği — bilinçli boyut/ağırlık/aralık (Nothing OS / iOS 18 sıkılığı)
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            color: textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0),
        displayMedium: TextStyle(
            color: textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7),
        titleLarge: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4),
        titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 15.5, height: 1.35),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14, height: 1.35),
        labelMedium: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1),
        labelSmall:
            TextStyle(color: textSecondary, fontSize: 11, letterSpacing: 0.2),
      ),
    );
  }
}

/// Boşluk token'ları — tutarlı ritim
class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Köşe yarıçapı token'ları — büyük yarıçaplar (iOS 18 / M3 expressive)
class Radii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double full = 999;
}

/// Hareket token'ları — yaylı his
class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve standard = Curves.easeInOutCubic;
}
