import 'package:cloud_firestore/cloud_firestore.dart';

/// 📊 Anket oylama — mesaj dokumanindaki pollVotes haritasinda
/// 'uid -> secenek indeksi' tutulur; ayni kullanici tekrar oy verirse
/// SECIMI DEGISIR (tek alanlik atomik guncelleme).
class PollService {
  /// Anketi kapat (yalniz anket sahibi cagirmali — UI garanti eder).
  static Future<void> close(String chatId, String messageId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'pollClosed': true});
  }

  static Future<void> vote(
      String chatId, String messageId, String myUid, int optionIndex) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'pollVotes.$myUid': optionIndex});
  }
}
