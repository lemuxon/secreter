import 'package:cloud_firestore/cloud_firestore.dart';

/// #9 GIZLI SOHBET (incognito) — sohbet-genelinde bayrak.
/// Aktifken: listede onizleme maskelenir ve SOHBETTEN HER CIKISTA tum
/// mesajlar IKI TARAFTAN silinir (iz birakmayan konusma). Bayrak chat
/// belgesine yazilir; iki taraf da ayni modu gorur/degistirebilir.
class IncognitoService {
  static final _db = FirebaseFirestore.instance;

  static Stream<bool> watch(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((d) => d.data()?['incognito'] == true);
  }

  static Future<void> set(String chatId, bool enabled) async {
    await _db.collection('chats').doc(chatId).update({'incognito': enabled});
  }
}
