import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/observability/handled_error.dart';

/// 🚫 ENGELLEME VE ŞİKÂYET
///
/// **Engelleme** artık `users/{uid}/private/blocks` GİZLİ alt dokümanında
/// tutulur (eskiden herkese açık kullanıcı dokümanındaki `blockedUids`
/// alanındaydı — yani kimi engellediğin tüm kullanıcılara görünüyordu).
///
/// **Sunucu tarafı uygulama:** Arama başlatma artık güvenlik kuralındaki
/// `notBlockedBy()` koşuluyla SUNUCUDA engellenir; engellenen kişi
/// değiştirilmiş bir istemciyle bile seni arayamaz. Arayüzdeki gizleme
/// (sohbeti listeden kaldırma vb.) bunun üstüne gelen kolaylıktır.
///
/// **Dürüst sınır:** Grup/kanal mesajları kural düzeyinde kişi bazlı
/// engelleme içermez; engellenen biri ortak bir grupta hâlâ yazabilir
/// (istemci onun mesajlarını gizler).
///
/// **Şikâyet** `reports` koleksiyonuna yazılır; içerik değil, yalnızca
/// şikâyet eden/edilen kimlikleri, sebep ve zaman gönderilir. Şikâyetler
/// hiçbir istemci tarafından OKUNAMAZ (yalnızca konsoldan incelenir).
class BlockService {
  static final _db = FirebaseFirestore.instance;

  /// Engel listesi GİZLİ alt dokümanda tutulur.
  ///
  /// ⚠️ Eskiden `users/{uid}.blockedUids` alanındaydı ve o doküman giriş
  /// yapmış HERKES tarafından okunabiliyordu — yani "kimi engellediğin"
  /// tüm kullanıcılara açıktı (ciddi bir gizlilik sızıntısı, özellikle
  /// tacizciyi engellediğinde ona görünmesi). Artık yalnızca sahibi okur;
  /// güvenlik kuralları `notBlockedBy()` içinde kural motorundan okur
  /// (bu istemci erişimi değildir).
  static DocumentReference<Map<String, dynamic>> _blocks(String uid) =>
      _db.doc('users/$uid/private/blocks');

  static Set<String> _read(Map<String, dynamic>? data) =>
      ((data?['uids'] as List?) ?? const []).map((e) => e.toString()).toSet();

  /// Engellenen kullanıcıların canlı listesi.
  static Stream<Set<String>> watchBlocked(String myUid) =>
      _blocks(myUid).snapshots().map((d) => _read(d.data()));

  static Future<Set<String>> getBlocked(String myUid) async {
    try {
      final d = await _blocks(myUid).get();
      return _read(d.data());
    } catch (e, s) {
      // ⚠️ ENGEL SESSİZCE KALKAR: boş küme "kimseyi engellemedim"
      // anlamına gelir; engellenen kişinin içeriği arayüzde yeniden
      // görünür ve kullanıcı engelin durduğunu sanar. Sunucu tarafı
      // (`notBlockedBy()`) aramayı yine reddeder — yani koruma tamamen
      // düşmez — ama arayüzdeki gizleme kaybolur ve tacizciyi engelleyen
      // biri için bu tek başına ciddi bir kırılmadır.
      reportHandled('Engelli listesi okunamadı — ENGEL GİZLEMESİ YOK', e,
          stack: s);
      return {};
    }
  }

  static Future<void> block(String myUid, String otherUid) =>
      _blocks(myUid).set({
        'uids': FieldValue.arrayUnion([otherUid]),
      }, SetOptions(merge: true));

  static Future<void> unblock(String myUid, String otherUid) =>
      _blocks(myUid).set({
        'uids': FieldValue.arrayRemove([otherUid]),
      }, SetOptions(merge: true));

  /// Karşı taraf BENİ engellemiş mi?
  ///
  /// Artık karşı tarafın gizli dokümanı okunamaz (doğru davranış).
  /// Engelin fiilen uygulanması SUNUCUDA yapılır: güvenlik kuralları
  /// `notBlockedBy()` ile arama başlatmayı reddeder. Bu metot yalnızca
  /// arayüz ipucu içindir ve erişemezse "engellenmemiş" varsayar.
  static Future<bool> amIBlockedBy(String otherUid, String myUid) async {
    try {
      final d = await _blocks(otherUid).get();
      return _read(d.data()).contains(myUid);
    } catch (_) {
      return false; // okuma izni yok — sunucu kuralı asıl kapıdır
    }
  }

  /// İki yönlü kontrol: ben mi engelledim, o mu beni engelledi?
  static Future<bool> isBlockedEitherWay(String myUid, String otherUid) async {
    final mine = await getBlocked(myUid);
    if (mine.contains(otherUid)) return true;
    return amIBlockedBy(otherUid, myUid);
  }

  /// Sikayet sebepleri — CEVIRI ANAHTARI olarak saklanir; arayuzde
  /// kullanicinin diline cevrilir, sunucuda dilden bagimsiz kalir.
  static const reportReasons = <String>[
    'report_spam',
    'report_harassment',
    'report_illegal',
    'report_impersonation',
    'report_other',
  ];

  /// Şikâyet gönder. Mesaj İÇERİĞİ gönderilmez — yalnızca kimlikler,
  /// sebep ve isteğe bağlı kısa açıklama.
  static Future<void> report({
    required String reporterUid,
    required String reportedUid,
    required String reason,
    String? note,
    String? chatId,
  }) async {
    await _db.collection('reports').add({
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'reason': reason,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (chatId != null) 'chatId': chatId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'open',
    });
  }
}

/// Engellenen kullanıcılar — arayüzün her yerinden okunabilsin diye.
final blockedUsersProvider =
    StreamProvider.family<Set<String>, String>((ref, myUid) {
  return BlockService.watchBlocked(myUid);
});
