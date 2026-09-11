import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🏷️ KISI ETIKETLERI — kullanici adini DEGISTIRMEDEN, yalnizca SENIN
/// cihazinda gorunen takma ad (otherUid -> etiket). Karsi taraf ve
/// sunucu bilmez; hesap-bazli saklanir.
final userAliasesProvider = StateNotifierProvider.family<UserAliasesNotifier,
    Map<String, String>, String>(
  (ref, uid) => UserAliasesNotifier(uid),
);

class UserAliasesNotifier extends StateNotifier<Map<String, String>> {
  final String uid;
  UserAliasesNotifier(this.uid) : super(const {}) {
    _load();
  }

  String get _key => 'user_alias_$uid';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final e in (p.getStringList(_key) ?? const [])) {
      final i = e.indexOf('|');
      if (i > 0) map[e.substring(0, i)] = e.substring(i + 1);
    }
    state = map;
  }

  Future<void> setAlias(String otherUid, String? alias) async {
    final map = {...state};
    if (alias == null || alias.trim().isEmpty) {
      map.remove(otherUid);
    } else {
      map[otherUid] = alias.trim();
    }
    state = map;
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        _key, map.entries.map((e) => '${e.key}|${e.value}').toList());
  }
}
