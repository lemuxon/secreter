import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🎭 SAHTE (DECOY) SOHBET İÇERİĞİ — sahte PIN girilince gorunecek,
/// kullanicinin KENDI hazirladigi zararsiz sohbetler. Bos bir decoy
/// ekrani suphe cektigi icin, inandiriciligi kullanici saglar.
/// Tamamen YEREL + duz (hassas bilgi degil; amac sahte gorunmek).
class DecoyChat {
  final String name;
  final List<DecoyMessage> messages;
  const DecoyChat({required this.name, required this.messages});

  Map<String, dynamic> toJson() => {
        'name': name,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory DecoyChat.fromJson(Map<String, dynamic> j) => DecoyChat(
        name: (j['name'] ?? '').toString(),
        messages: ((j['messages'] as List?) ?? const [])
            .map((e) => DecoyMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DecoyMessage {
  final String text;
  final bool mine;
  const DecoyMessage({required this.text, required this.mine});

  Map<String, dynamic> toJson() => {'text': text, 'mine': mine};

  factory DecoyMessage.fromJson(Map<String, dynamic> j) => DecoyMessage(
        text: (j['text'] ?? '').toString(),
        mine: j['mine'] == true,
      );
}

final decoyContentProvider =
    StateNotifierProvider<DecoyContentNotifier, List<DecoyChat>>(
  (ref) => DecoyContentNotifier(),
);

class DecoyContentNotifier extends StateNotifier<List<DecoyChat>> {
  DecoyContentNotifier() : super(const []) {
    _load();
  }

  static const _key = 'decoy_chats_v1';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) {
      state = _seed();
      return;
    }
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => DecoyChat.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list.isEmpty ? _seed() : list;
    } catch (_) {
      state = _seed();
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(state.map((c) => c.toJson()).toList()));
  }

  /// Ilk acilista makul, zararsiz ornek sohbetler (inandiricilik icin).
  List<DecoyChat> _seed() => const [
        DecoyChat(name: 'Market', messages: [
          DecoyMessage(text: 'Ekmek de alır mısın?', mine: false),
          DecoyMessage(text: 'Tamam aldım', mine: true),
        ]),
        DecoyChat(name: 'Kargo', messages: [
          DecoyMessage(text: 'Gönderiniz dağıtıma çıkmıştır.', mine: false),
        ]),
      ];

  Future<void> addChat(String name) async {
    state = [...state, DecoyChat(name: name.trim(), messages: const [])];
    await _save();
  }

  Future<void> removeChat(int index) async {
    final l = [...state]..removeAt(index);
    state = l;
    await _save();
  }

  Future<void> addMessage(int chatIndex, String text, bool mine) async {
    final l = [...state];
    final c = l[chatIndex];
    l[chatIndex] = DecoyChat(
      name: c.name,
      messages: [...c.messages, DecoyMessage(text: text.trim(), mine: mine)],
    );
    state = l;
    await _save();
  }
}
