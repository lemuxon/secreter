import 'package:cloud_firestore/cloud_firestore.dart';

/// 🔕 SUNUCU-TARAFI sessize alma: push bildirimlerini Cloud Function
/// keser. Chat dokumaninda iki dizi tutulur:
///   mutedBy        -> bu sohbeti susturan kullanicilar
///   muteMentionOk  -> susturmus AMA @bahsetme bildirimi ISTEYENLER
class MuteService {
  static DocumentReference<Map<String, dynamic>> _doc(String chatId) =>
      FirebaseFirestore.instance.collection('chats').doc(chatId);

  static Future<void> setMuted(String chatId, String uid, bool muted) {
    if (muted) {
      return _doc(chatId).update({
        'mutedBy': FieldValue.arrayUnion([uid]),
      });
    }
    // sesi acinca etiket-istisnasi kaydi da temizlenir
    return _doc(chatId).update({
      'mutedBy': FieldValue.arrayRemove([uid]),
      'muteMentionOk': FieldValue.arrayRemove([uid]),
    });
  }

  static Future<void> setMentionOk(String chatId, String uid, bool allow) {
    return _doc(chatId).update({
      'muteMentionOk':
          allow ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }
}
