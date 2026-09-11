import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_hasher.dart';
import 'secure_store.dart';
import '../../core/observability/handled_error.dart';

/// SOHBET KİLİDİ: belirli sohbetlere ayrı PIN. Uygulama kilidinden bağımsız.
///
/// ── BU SÜRÜMDE DÜZELTİLEN İKİ SORUN ──
///
/// 1. KİLİTLİ SOHBET LİSTESİ DÜZ METİNDEYDİ. Liste SharedPreferences'ta
///    (şifrelenmemiş XML) tutuluyordu; cihaza erişen biri PIN'i bilmeden
///    listeden chatId'yi SİLEREK kilidi kaldırabiliyordu. Liste artık
///    secure storage'da.
///
/// 2. ZAYIF KARMA. Tek tur SHA-256 + zaman damgası tuzu yerine [PinHasher]
///    (PBKDF2, 150k tur, kriptografik tuz).
///
/// ⚠️ DÜRÜST SINIR: Sohbet kilidi bir ARAYÜZ kapısıdır; mesaj içeriğini
/// ayrıca şifrelemez. Cihazın kendi disk şifrelemesi ve uygulama kilidi
/// asıl korumadır.
class ChatLockService {
  static const _lockedKey = 'locked_chats_secure';
  static const _legacyLockedKey = 'locked_chats';

  /// Hesap kapsamı — çoklu hesapta listeler karışmasın.
  static String _scope = '_';
  static void setActiveAccount(String? uid) {
    _scope = (uid == null || uid.isEmpty) ? '_' : uid;
  }

  static String get _listKey => '${_lockedKey}_$_scope';
  static String _hashKey(String chatId) => 'chat_pin_${_scope}_$chatId';

  // ─────────────────────────────────────────
  // KİLİTLİ SOHBET LİSTESİ
  // ─────────────────────────────────────────

  static Future<Set<String>> lockedChats() async {
    final raw = await SecureStore.read(_listKey);
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (e, s) {
      // ⚠️ KİLİT SESSİZCE AÇILIR: boş küme dönmek `isLocked()`i her sohbet
      // için `false` yapar — yani liste okunamadığında KİLİTLİ SOHBETLERİN
      // HEPSİ PIN sorulmadan açılır. Kullanıcı kilidin durduğunu sanır.
      // Alternatifi (hepsini kilitli saymak) kullanıcıyı kendi
      // sohbetlerinden kalıcı olarak kilitlerdi; bu yüzden davranış
      // korunuyor ama artık ÖLÇÜLEBİLİR.
      reportHandled('Kilitli sohbet listesi okunamadı — KİLİT UYGULANMIYOR', e,
          stack: s);
      return <String>{};
    }
  }

  static Future<void> _saveList(Set<String> ids) async {
    await SecureStore.writeOrThrow(
        key: _listKey, value: jsonEncode(ids.toList()));
  }

  static Future<bool> isLocked(String chatId) async =>
      (await lockedChats()).contains(chatId);

  /// Eski düz metin listesini secure storage'a taşı (tek seferlik).
  static Future<void> migrateLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getStringList(_legacyLockedKey);
      if (legacy == null || legacy.isEmpty) return;
      final current = await lockedChats();
      await _saveList({...current, ...legacy});
      // Düz metin kopyayı sil — saldırganın oynayabileceği yüzey kalmasın.
      await prefs.remove(_legacyLockedKey);
    } catch (e, s) {
      // ⚠️ Eski DÜZ METİN kilit listesi cihazda kalır — taşımanın
      // amacı tam olarak o yüzeyi kaldırmaktı.
      reportHandled('Sohbet kilidi taşınamadı', e, stack: s);
    }
  }

  // ─────────────────────────────────────────
  // PIN
  // ─────────────────────────────────────────

  static Future<void> setPin(String chatId, String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN en az 4 hane olmalı');
    }
    await SecureStore.writeOrThrow(
        key: _hashKey(chatId), value: await PinHasher.hash(pin));
    final ids = await lockedChats();
    await _saveList({...ids, chatId});
  }

  static Future<bool> verifyPin(String chatId, String pin) async {
    final stored = await SecureStore.read(_hashKey(chatId));
    if (stored == null) return false;
    final ok = await PinHasher.verify(pin, stored);
    if (ok && PinHasher.needsUpgrade(stored)) {
      await SecureStore.write(_hashKey(chatId), await PinHasher.hash(pin));
    }
    return ok;
  }

  static Future<void> removeLock(String chatId) async {
    await SecureStore.delete(_hashKey(chatId));
    final ids = await lockedChats();
    ids.remove(chatId);
    await _saveList(ids);
  }

  /// Hesap silinince/çıkış yapılınca tüm sohbet kilitlerini temizle.
  static Future<void> wipeAll() async {
    final ids = await lockedChats();
    for (final id in ids) {
      await SecureStore.delete(_hashKey(id));
    }
    await SecureStore.delete(_listKey);
  }
}

/// Kilitli sohbetleri reaktif izler (kilit ikonu + menü için).
class LockedChatsNotifier extends StateNotifier<Set<String>> {
  LockedChatsNotifier() : super(const {}) {
    refresh();
  }

  Future<void> refresh() async {
    state = await ChatLockService.lockedChats();
  }

  Future<void> lock(String chatId, String pin) async {
    await ChatLockService.setPin(chatId, pin);
    await refresh();
  }

  Future<void> unlock(String chatId) async {
    await ChatLockService.removeLock(chatId);
    await refresh();
  }
}

final lockedChatsProvider =
    StateNotifierProvider<LockedChatsNotifier, Set<String>>(
        (ref) => LockedChatsNotifier());
