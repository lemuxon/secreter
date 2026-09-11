import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/security/secure_store.dart';

/// 🙈 GIZLENEN MESAJLAR — yildiz gibi KISISEL/yerel: 'chatId|msgId'
/// anahtarlari uid-bazli saklanir; karsi taraf ve sunucu bilmez.
/// Mesajin kendisi silinmez; yalnizca bu cihazda listeden saklanir.
final hiddenMessagesProvider =
    StateNotifierProvider.family<HiddenMessagesNotifier, Set<String>, String>(
  (ref, uid) => HiddenMessagesNotifier(uid),
);

class HiddenMessagesNotifier extends StateNotifier<Set<String>> {
  final String uid;
  HiddenMessagesNotifier(this.uid) : super(const {}) {
    _load();
  }

  String get _key => 'hidden_msgs_$uid';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = (p.getStringList(_key) ?? const []).toSet();
  }

  bool isHidden(String chatId, String messageId) =>
      state.contains('$chatId|$messageId');

  Future<void> toggle(String chatId, String messageId) async {
    final s = {...state};
    final k = '$chatId|$messageId';
    if (!s.add(k)) s.remove(k);
    state = s;
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, s.toList());
  }
}

/// 🙈 Gizli-mesaj SIFRESI — sohbet kilidiyle ayni guvenlik deseni:
/// tuzlu SHA-256 ozeti guvenli depoda (asla duz metin yok).
class HiddenLockService {
  static const _secure = SecureStore.instance;
  static String _hashKey(String uid) => 'hidden_pin_hash_$uid';
  static String _saltKey(String uid) => 'hidden_pin_salt_$uid';

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$pin:$salt')).toString();

  static Future<bool> hasPin(String uid) async =>
      (await _secure.read(key: _hashKey(uid))) != null;

  static Future<void> setPin(String uid, String pin) async {
    final salt = base64Url
        .encode(List.generate(16, (_) => Random.secure().nextInt(256)));
    await _secure.write(key: _saltKey(uid), value: salt);
    await _secure.write(key: _hashKey(uid), value: _hash(pin, salt));
  }

  static Future<bool> verify(String uid, String pin) async {
    final salt = await _secure.read(key: _saltKey(uid));
    final hash = await _secure.read(key: _hashKey(uid));
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }
}
