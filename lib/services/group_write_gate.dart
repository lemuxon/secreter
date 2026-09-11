import 'package:cloud_firestore/cloud_firestore.dart';

/// #13 GRUP YAZMA KAPISI — "Sadece yöneticiler gönderebilir" ve susturma
/// ayarlarinin MESAJ EKRANINDA fiilen uygulanmasi. (Ayarlar Grup Bilgisi
/// ekraninda zaten vardi ama giris cubugu kisitlamiyordu.)
/// Chat belgesini izler; kullanicinin yazmasi kisitliysa SEBEP metni,
/// yazabiliyorsa null yayinlar.
class GroupWriteGate {
  static Stream<String?> watchBlockReason(String chatId, String myUid) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((d) {
      final data = d.data();
      if (data == null) return null;
      // Kurucu (adminId) her zaman yazabilir
      if (data['adminId'] == myUid) return null;

      bool isAdmin = false;
      bool isMuted = false;
      final members = data['members'];
      if (members is List) {
        for (final m in members) {
          if (m is Map && m['uid'] == myUid) {
            isAdmin = m['role'] == 'admin';
            isMuted = m['isMuted'] == true;
            break;
          }
        }
      }
      if (isMuted) return 'err_muted_in_group';
      if (data['onlyAdminsCanPost'] == true && !isAdmin) {
        return 'err_admins_only';
      }
      return null;
    }).distinct();
  }
}
