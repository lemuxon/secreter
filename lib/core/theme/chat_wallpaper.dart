import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sohbet duvar kağıdı preset'i (renk veya gradyan).
class WallpaperPreset {
  final String id;
  final String name;
  final BoxDecoration decoration;
  const WallpaperPreset(this.id, this.name, this.decoration);
}

/// Koyu-tema dostu hazır duvar kağıtları.
const List<WallpaperPreset> chatWallpapers = [
  WallpaperPreset(
    'default',
    'default_word',
    BoxDecoration(color: Color(0xFF0B0F14)),
  ),
  WallpaperPreset(
    'midnight',
    'wp_midnight',
    BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B0F14), Color(0xFF16233A)],
      ),
    ),
  ),
  WallpaperPreset(
    'ocean',
    'wp_ocean',
    BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF07171C), Color(0xFF0E3A44)],
      ),
    ),
  ),
  WallpaperPreset(
    'forest',
    'wp_forest',
    BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A130E), Color(0xFF13301F)],
      ),
    ),
  ),
  WallpaperPreset(
    'sunset',
    'wp_sunset',
    BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A0F14), Color(0xFF3A1E2A)],
      ),
    ),
  ),
  WallpaperPreset(
    'plum',
    'wp_plum',
    BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF120C1A), Color(0xFF2A1E3A)],
      ),
    ),
  ),
  WallpaperPreset(
    'charcoal',
    'wp_charcoal',
    BoxDecoration(color: Color(0xFF07090C)),
  ),
];

BoxDecoration wallpaperDecorationFor(String id) {
  return chatWallpapers
      .firstWhere((w) => w.id == id, orElse: () => chatWallpapers.first)
      .decoration;
}

/// Seçili duvar kağıdını tutar + SharedPreferences'a kalıcı yazar.
final wallpaperProvider = StateNotifierProvider<WallpaperNotifier, String>(
  (ref) => WallpaperNotifier(),
);

class WallpaperNotifier extends StateNotifier<String> {
  WallpaperNotifier() : super('default') {
    _load();
  }

  static const _key = 'chat_wallpaper';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key) ?? 'default';
  }

  Future<void> select(String id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
  }
}

// ============================================================
// SOHBETE ÖZEL FOTOĞRAF ARKA PLANI (#7)
// Galeriden seçilen foto + bulanıklık + karartma; sohbet başına
// SharedPreferences'ta saklanır: 'bg_photo_<chatId>' = path|blur|darken
// ============================================================

class ChatBgPhoto {
  final String path;

  /// Gaussian sigma (0 = yok, ~20 = çok bulanık)
  final double blur;

  /// Karartma opaklığı (0.0 - 0.8)
  final double darken;

  const ChatBgPhoto({required this.path, this.blur = 0, this.darken = 0.25});

  ChatBgPhoto copyWith({String? path, double? blur, double? darken}) =>
      ChatBgPhoto(
        path: path ?? this.path,
        blur: blur ?? this.blur,
        darken: darken ?? this.darken,
      );

  String encode() => '$path|$blur|$darken';

  static ChatBgPhoto? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    return ChatBgPhoto(
      path: parts[0],
      blur: double.tryParse(parts[1]) ?? 0,
      darken: double.tryParse(parts[2]) ?? 0.25,
    );
  }
}

class ChatBgPhotoNotifier extends StateNotifier<ChatBgPhoto?> {
  final String chatId;
  ChatBgPhotoNotifier(this.chatId) : super(null) {
    _load();
  }
  String get _key => 'bg_photo_$chatId';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) state = ChatBgPhoto.decode(p.getString(_key));
  }

  Future<void> save(ChatBgPhoto photo) async {
    state = photo;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, photo.encode());
  }

  Future<void> clear() async {
    state = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}

final chatBgPhotoProvider =
    StateNotifierProvider.family<ChatBgPhotoNotifier, ChatBgPhoto?, String>(
        (ref, chatId) => ChatBgPhotoNotifier(chatId));
