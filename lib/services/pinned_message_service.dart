import 'package:cloud_firestore/cloud_firestore.dart';

/// #2 MESAJ SABITLEME — sohbet-genelinde tek sabit mesaj.
/// Chat belgesine yazilir: pinnedMessageId + pinnedPreview.
/// E2EE (birebir) mesajlarda sunucuya MASKELI onizleme yazilir
/// ('🔒 Mesaj') — banner gercek metni cihazdaki cozulmus listeden bulur.
class PinnedMessageService {
  static final _db = FirebaseFirestore.instance;

  static Stream<PinnedInfo?> watch(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((d) {
      final id = d.data()?['pinnedMessageId'];
      if (id is! String || id.isEmpty) return null;
      return PinnedInfo(
        messageId: id,
        preview: (d.data()?['pinnedPreview'] ?? '') as String,
      );
    });
  }

  static Future<void> pin(
      String chatId, String messageId, String preview) async {
    await _db.collection('chats').doc(chatId).update({
      'pinnedMessageId': messageId,
      'pinnedPreview': preview,
    });
  }

  static Future<void> unpin(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'pinnedMessageId': FieldValue.delete(),
      'pinnedPreview': FieldValue.delete(),
    });
  }
}

class PinnedInfo {
  final String messageId;
  final String preview;
  const PinnedInfo({required this.messageId, required this.preview});
}
