import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ✏️ TASLAK KORUMA
///
/// Yazıp göndermediğin metin, sohbetten çıkınca kaybolmasın. Sohbeti
/// tekrar açtığında kaldığın yerden devam edersin.
///
/// TASARIM: Tamamen cihaz-yerel (SharedPreferences). Sunucuya
/// gönderilmez — yarım kalmış bir cümle bile veri sızıntısı olmamalı.
/// Bu yüzden taslaklar yedeklenmez ve başka cihaza taşınmaz.
class DraftService {
  static String _key(String chatId) => 'draft_$chatId';

  /// Bellek içi önbellek: her tuş vuruşunda diske gitmemek için.
  static final Map<String, String> _cache = {};

  /// Sohbetin taslağını oku (yoksa boş metin).
  static Future<String> get(String chatId) async {
    final cached = _cache[chatId];
    if (cached != null) return cached;
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_key(chatId)) ?? '';
      _cache[chatId] = v;
      return v;
    } catch (e) {
      debugPrint('Taslak okunamadı: $e');
      return '';
    }
  }

  /// Taslağı kaydet. Boş metin → kaydı sil (gereksiz yer tutmasın).
  static Future<void> save(String chatId, String text) async {
    final t = text.trim();
    if (_cache[chatId] == t) return; // değişmemiş, diske yazma
    _cache[chatId] = t;
    try {
      final p = await SharedPreferences.getInstance();
      if (t.isEmpty) {
        await p.remove(_key(chatId));
      } else {
        await p.setString(_key(chatId), t);
      }
    } catch (e) {
      debugPrint('Taslak kaydedilemedi: $e');
    }
  }

  /// Mesaj gönderildi → taslağı temizle.
  static Future<void> clear(String chatId) => save(chatId, '');
}
