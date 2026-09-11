import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/di/injection.dart';
import '../core/auth/current_user_provider.dart';

/// ⏰ ZAMANLANMIS MESAJLAR — istemci tarafı.
/// Kayit `scheduledMessages` koleksiyonuna yazilir; sunucudaki dakikalik
/// Cloud Function (sendScheduledMessages) zamani gelince gercek mesaja
/// donusturur — uygulama KAPALIYKEN de gonderilir.
/// NOT (bilinçli ödün): sunucu cihazdaki E2EE zincirini isletemedigi icin
/// zamanlanmis mesajlar DUZ METIN gonderilir (grup/duzenlenen mesaj gibi).
class ScheduledMessageService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('scheduledMessages');

  /// Mesaji ileri bir tarihe planla.
  static Future<void> schedule({
    required String chatId,
    required String content,
    required DateTime sendAt,
  }) async {
    final userProvider = getIt<CurrentUserProvider>();
    final uid = userProvider.currentUid;
    if (uid == null) throw StateError('Oturum yok');
    await _col.add({
      'chatId': chatId,
      'senderId': uid,
      // `senderUsername` YAZILMAZ — metadata gizliliği: gönderen adının
      // sunucuda düz durması, içerik şifreliyken bile sosyal grafiği
      // açık ediyordu. Ad gösterim anında uid'den çözülür.
      'content': content,
      'sendAt': sendAt.toUtc().toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Bu sohbetteki KENDI bekleyen zamanlanmislarim (canli).
  /// (Iki esitlik filtresi — bilesik indeks gerektirmez; siralama istemcide.)
  static Stream<List<ScheduledItem>> watchForChat(String chatId) {
    final uid = getIt<CurrentUserProvider>().currentUid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('chatId', isEqualTo: chatId)
        .where('senderId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((d) => ScheduledItem.fromDoc(d.id, d.data()))
          .whereType<ScheduledItem>()
          .toList()
        ..sort((a, b) => a.sendAt.compareTo(b.sendAt));
      return items;
    });
  }

  /// Planlanan mesaji gonderilmeden iptal et.
  static Future<void> cancel(String id) => _col.doc(id).delete();
}

class ScheduledItem {
  final String id;
  final String content;
  final DateTime sendAt;
  const ScheduledItem(
      {required this.id, required this.content, required this.sendAt});

  static ScheduledItem? fromDoc(String id, Map<String, dynamic> m) {
    final t = DateTime.tryParse(m['sendAt'] ?? '');
    if (t == null) return null;
    return ScheduledItem(
      id: id,
      content: (m['content'] ?? '') as String,
      sendAt: t.toLocal(),
    );
  }
}
