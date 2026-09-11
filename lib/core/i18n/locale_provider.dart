import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🌐 SECRETER dil altyapisi — kullanicinin sectigi dil KALICI saklanir
/// ve MaterialApp.locale'i suren tek kaynaktir. Deger degisince tum
/// arayuz otomatik yeniden cizilir (Localizations InheritedWidget).
///
/// Desteklenen 16 dil (dil kodu + native ad):
class AppLanguages {
  static const List<({String code, String native, String flag})> all = [
    (code: 'tr', native: 'Türkçe', flag: '🇹🇷'),
    (code: 'en', native: 'English', flag: '🇬🇧'),
    (code: 'ru', native: 'Русский', flag: '🇷🇺'),
    (code: 'ar', native: 'العربية', flag: '🇸🇦'),
    (code: 'zh', native: '中文', flag: '🇨🇳'),
    (code: 'fr', native: 'Français', flag: '🇫🇷'),
    (code: 'pt', native: 'Português', flag: '🇵🇹'),
    (code: 'uk', native: 'Українська', flag: '🇺🇦'),
    (code: 'it', native: 'Italiano', flag: '🇮🇹'),
    (code: 'el', native: 'Ελληνικά', flag: '🇬🇷'),
    (code: 'ja', native: '日本語', flag: '🇯🇵'),
    (code: 'ko', native: '한국어', flag: '🇰🇷'),
    (code: 'pl', native: 'Polski', flag: '🇵🇱'),
    (code: 'sv', native: 'Svenska', flag: '🇸🇪'),
    (code: 'fi', native: 'Suomi', flag: '🇫🇮'),
    (code: 'de', native: 'Deutsch', flag: '🇩🇪'),
  ];

  static List<Locale> get locales => all.map((l) => Locale(l.code)).toList();
}

/// Secili dil (null = henuz secilmedi -> ilk acilista dil ekrani gosterilir).
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  static const _key = 'app_locale_code';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString(_key);
    if (code != null && code.isNotEmpty) {
      state = Locale(code);
    }
  }

  /// Kullanici dil sectiginde cagirilir (kalici + aninda uygular).
  Future<void> setLocale(String code) async {
    state = Locale(code);
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, code);
  }

  /// Daha once dil secilmis mi? (ilk acilis kontrolu)
  Future<bool> hasChosen() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString(_key);
    return code != null && code.isNotEmpty;
  }
}
