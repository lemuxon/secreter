import 'package:cloud_firestore/cloud_firestore.dart';

/// #1 KENDINI IMHA EDEN MESAJLAR — sohbet-genelinde süre ayarı.
/// Ayar chat belgesine yazilir (`disappearSeconds`), böylece HER IKI TARAF
/// ayni ayari gorur ve gonderdikleri mesajlara ayni süre uygulanir.
/// 0/null = kapali. Mesaja `expiresAt` bu süreden hesaplanir; süresi dolan
/// mesaj hem gizlenir (isExpired filtresi) hem de sunucudan silinir.
class DisappearingService {
  static final _db = FirebaseFirestore.instance;

  static const Map<String, int> presets = {
    'off_word': 0,
    'one_hour': 3600,
    'one_day': 86400,
    'one_week': 604800,
  };

  static String labelFor(int? seconds) {
    if (seconds == null || seconds == 0) return 'off_word';
    for (final e in presets.entries) {
      if (e.value == seconds) return e.key;
    }
    return '${seconds ~/ 3600} hours_short';
  }

  /// Sohbetin süresini canli izle (0 -> null döner).
  static Stream<int?> watch(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((d) {
      final v = d.data()?['disappearSeconds'];
      if (v is num && v > 0) return v.toInt();
      return null;
    });
  }

  /// Süreyi ayarla (her iki taraf icin).
  static Future<void> set(String chatId, int seconds) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .update({'disappearSeconds': seconds});
  }
}
