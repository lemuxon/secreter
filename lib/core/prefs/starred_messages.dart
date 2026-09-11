import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ⭐ YILDIZLI MESAJLAR — kisisel favoriler (WhatsApp tarzi).
/// Yildizlar KISISELDIR ve cihazda uid-bazli saklanir; karsi taraf gormez,
/// sunucuya yazilmaz (E2EE ile uyumlu: yildiz aninda cozulmus onizleme
/// yerel olarak kaydedilir, liste ekrani bu anlik goruntuden beslenir).
class StarredMessage {
  final String chatId;
  final String messageId;
  final String chatTitle;
  final bool isGroup;
  final String sender;
  final String preview;
  final DateTime timestamp;
  final DateTime starredAt;

  const StarredMessage({
    required this.chatId,
    required this.messageId,
    required this.chatTitle,
    required this.isGroup,
    required this.sender,
    required this.preview,
    required this.timestamp,
    required this.starredAt,
  });

  Map<String, dynamic> toMap() => {
        'c': chatId,
        'm': messageId,
        't': chatTitle,
        'g': isGroup,
        's': sender,
        'p': preview,
        'ts': timestamp.toIso8601String(),
        'sa': starredAt.toIso8601String(),
      };

  static StarredMessage? fromMap(Map<String, dynamic> m) {
    try {
      return StarredMessage(
        chatId: m['c'] as String,
        messageId: m['m'] as String,
        chatTitle: (m['t'] ?? '') as String,
        isGroup: (m['g'] ?? false) as bool,
        sender: (m['s'] ?? '') as String,
        preview: (m['p'] ?? '') as String,
        timestamp: DateTime.tryParse(m['ts'] ?? '') ?? DateTime.now(),
        starredAt: DateTime.tryParse(m['sa'] ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

class StarredNotifier extends StateNotifier<List<StarredMessage>> {
  final String uid;
  StarredNotifier(this.uid) : super(const []) {
    _load();
  }

  String get _key => 'starred_msgs_$uid';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? const [];
    final items = <StarredMessage>[];
    for (final e in raw) {
      try {
        final m = StarredMessage.fromMap(jsonDecode(e) as Map<String, dynamic>);
        if (m != null) items.add(m);
      } catch (_) {
        // bozuk kayit atlanir
      }
    }
    // En yeni yildizlanan en ustte
    items.sort((a, b) => b.starredAt.compareTo(a.starredAt));
    if (mounted) state = items;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        _key, state.map((m) => jsonEncode(m.toMap())).toList());
  }

  bool isStarred(String messageId) =>
      state.any((m) => m.messageId == messageId);

  Future<void> add(StarredMessage m) async {
    if (isStarred(m.messageId)) return;
    state = [m, ...state];
    await _persist();
  }

  Future<void> remove(String messageId) async {
    state = state.where((m) => m.messageId != messageId).toList();
    await _persist();
  }
}

final starredProvider =
    StateNotifierProvider.family<StarredNotifier, List<StarredMessage>, String>(
        (ref, uid) => StarredNotifier(uid));
