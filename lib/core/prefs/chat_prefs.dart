import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sohbet tercihleri: sabitlenmiş + arşivlenmiş sohbetler.
/// Kişisel tercih olduğu için cihazda, HESABA BAĞLI anahtarlarla saklanır
/// (hesap değiştirince karışmaz; karşı tarafı etkilemez).
class ChatPrefs {
  final Set<String> pinned;
  final Set<String> archived;

  /// chatId -> silme zamani. Sohbet, son mesaji bu zamandan ESKIyse gizli
  /// kalir; yeni mesaj gelince (lastMessageTime daha yeni) otomatik gorunur.
  /// Zaman-tabanli oldugu icin uygulama kapatilip acilsa da dogru calisir.
  final Map<String, DateTime> deletedAt;

  /// #17 chatId -> klasor adi ('Is', 'Aile', ...). Kisisel/yerel.
  final Map<String, String> folders;

  /// 🔕 Sessize alinan sohbetler + etiket-istisnasi acik olanlar.
  /// Yerel kopya (UI + on-plan bildirim kapisi); push icin sunucudaki
  /// mutedBy/muteMentionOk dizileri MuteService ile es tutulur.
  final Set<String> muted;
  final Set<String> muteMentionOk;

  const ChatPrefs(
      {this.pinned = const {},
      this.archived = const {},
      this.deletedAt = const {},
      this.folders = const {},
      this.muted = const {},
      this.muteMentionOk = const {}});

  /// Kullanimda olan klasor adlari (alfabetik).
  List<String> get folderNames {
    final set = folders.values.toSet().toList()..sort();
    return set;
  }

  /// Bu sohbet listede gizlensin mi? (silindi VE sonrasinda yeni mesaj yok)
  bool isHidden(String chatId, DateTime? lastMessageTime) {
    final t = deletedAt[chatId];
    if (t == null) return false;
    if (lastMessageTime != null && lastMessageTime.isAfter(t)) return false;
    return true;
  }

  ChatPrefs copyWith(
          {Set<String>? pinned,
          Set<String>? archived,
          Map<String, DateTime>? deletedAt,
          Map<String, String>? folders,
          Set<String>? muted,
          Set<String>? muteMentionOk}) =>
      ChatPrefs(
        pinned: pinned ?? this.pinned,
        archived: archived ?? this.archived,
        deletedAt: deletedAt ?? this.deletedAt,
        folders: folders ?? this.folders,
        muted: muted ?? this.muted,
        muteMentionOk: muteMentionOk ?? this.muteMentionOk,
      );
}

class ChatPrefsNotifier extends StateNotifier<ChatPrefs> {
  final String uid;
  ChatPrefsNotifier(this.uid) : super(const ChatPrefs()) {
    _load();
  }

  String get _pinKey => 'pinned_chats_$uid';
  String get _arcKey => 'archived_chats_$uid';
  String get _delKey => 'deleted_chats_$uid';
  String get _folderKey => 'chat_folders_$uid';
  String get _muteKey => 'muted_chats_$uid';
  String get _muteMentionKey => 'mute_mention_ok_$uid';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final delRaw = p.getStringList(_delKey) ?? const [];
    final deletedAt = <String, DateTime>{};
    for (final e in delRaw) {
      final idx = e.indexOf('|');
      if (idx > 0) {
        final t = DateTime.tryParse(e.substring(idx + 1));
        if (t != null) deletedAt[e.substring(0, idx)] = t;
      }
    }
    // #17 klasorler: 'chatId|klasor' listesi
    final folders = <String, String>{};
    for (final e in (p.getStringList(_folderKey) ?? const [])) {
      final i = e.indexOf('|');
      if (i > 0) folders[e.substring(0, i)] = e.substring(i + 1);
    }
    state = ChatPrefs(
      pinned: (p.getStringList(_pinKey) ?? const []).toSet(),
      archived: (p.getStringList(_arcKey) ?? const []).toSet(),
      deletedAt: deletedAt,
      folders: folders,
      muted: (p.getStringList(_muteKey) ?? const []).toSet(),
      muteMentionOk: (p.getStringList(_muteMentionKey) ?? const []).toSet(),
    );
  }

  Future<void> togglePin(String chatId) async {
    final pinned = {...state.pinned};
    pinned.contains(chatId) ? pinned.remove(chatId) : pinned.add(chatId);
    state = state.copyWith(pinned: pinned);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_pinKey, pinned.toList());
  }

  /// Sohbeti listeden gizle (tek-tarafli 'sil'). Silme ANI kaydedilir;
  /// sohbet, bu andan SONRA yeni mesaj gelene kadar gizli kalir.
  /// 💾 GERİ YÜKLEME İÇİN: silme işaretini kaldır.
  /// Sohbet "silindi" diye listeden gizlenmişse, yedekten geri yükleme
  /// sonrası tekrar görünür olmalı — aksi halde geri yüklenen mesajlara
  /// ulaşmanın yolu kalmaz.
  /// Birden fazla sohbetin silme işaretini TEK yazma ile kaldır.
  /// (Her sohbet için ayrı diske yazmak geri yüklemeyi yavaşlatıyordu.)
  Future<void> unmarkDeletedAll(Iterable<String> chatIds) async {
    final map = {...state.deletedAt};
    var changed = false;
    for (final id in chatIds) {
      if (map.remove(id) != null) changed = true;
    }
    if (!changed) return;
    state = state.copyWith(deletedAt: map);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _delKey,
      map.entries.map((e) => '${e.key}|${e.value.toIso8601String()}').toList(),
    );
  }

  Future<void> unmarkDeleted(String chatId) async {
    if (!state.deletedAt.containsKey(chatId)) return;
    final map = {...state.deletedAt}..remove(chatId);
    state = state.copyWith(deletedAt: map);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _delKey,
      map.entries.map((e) => '${e.key}|${e.value.toIso8601String()}').toList(),
    );
  }

  Future<void> markDeleted(String chatId) async {
    final map = {...state.deletedAt, chatId: DateTime.now()};
    state = state.copyWith(deletedAt: map);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _delKey,
      map.entries.map((e) => '${e.key}|${e.value.toIso8601String()}').toList(),
    );
  }

  /// #17 Sohbeti klasore ata (null = klasorden cikar).
  Future<void> setFolder(String chatId, String? folder) async {
    final map = {...state.folders};
    if (folder == null || folder.trim().isEmpty) {
      map.remove(chatId);
    } else {
      map[chatId] = folder.trim();
    }
    state = state.copyWith(folders: map);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        _folderKey, map.entries.map((e) => '${e.key}|${e.value}').toList());
  }

  /// 🔕 Sessize al / sesi ac. Susturma kalkarsa etiket-istisnasi da silinir.
  Future<void> toggleMute(String chatId) async {
    final m = {...state.muted};
    final ok = {...state.muteMentionOk};
    if (!m.add(chatId)) {
      m.remove(chatId);
      ok.remove(chatId);
    }
    state = state.copyWith(muted: m, muteMentionOk: ok);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_muteKey, m.toList());
    await p.setStringList(_muteMentionKey, ok.toList());
  }

  /// 🔕 Etiket istisnasi: sessizken @bahsetme bildirimi gelsin mi?
  Future<void> setMuteMentionOk(String chatId, bool allow) async {
    final ok = {...state.muteMentionOk};
    if (allow) {
      ok.add(chatId);
    } else {
      ok.remove(chatId);
    }
    state = state.copyWith(muteMentionOk: ok);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_muteMentionKey, ok.toList());
  }

  Future<void> toggleArchive(String chatId) async {
    final archived = {...state.archived};
    archived.contains(chatId) ? archived.remove(chatId) : archived.add(chatId);
    state = state.copyWith(archived: archived);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_arcKey, archived.toList());
  }
}

final chatPrefsProvider =
    StateNotifierProvider.family<ChatPrefsNotifier, ChatPrefs, String>(
        (ref, uid) => ChatPrefsNotifier(uid));
