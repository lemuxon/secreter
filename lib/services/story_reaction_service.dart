import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/di/injection.dart';
import '../features/messaging/domain/usecases/send_text_message.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'direct_chat_service.dart';

/// ❤️ HİKÂYE TEPKİLERİ ve YANITLARI
///
/// TASARIM:
///  1. TEPKİLER hikâye dokümanında `reactions` haritasında tutulur
///     (uid -> emoji). Harita, her kullanıcının TEK tepkisi olmasını
///     yapısal olarak garanti eder.
///  2. YANITLAR normal mesaj altyapısını kullanır: hikâye sahibiyle olan
///     birebir sohbete düşer, böylece şifreleme/bildirim/okundu hazır gelir.
///
/// ── BU SÜRÜMDE DÜZELTİLEN KRİTİK HATA ──
/// Yanıtlar eski `ChatService.sendTextMessage` motorunu kullanıyordu. O
/// motor `reactions` alanını LİSTE olarak yazıyor, yeni mesajlaşma katmanı
/// ise HARİTA olarak okuyor. Sonuç: hikâyeye yanıt gönderildiği anda
/// alıcının sohbet ekranı tip hatasıyla TAMAMEN açılamıyordu. Artık yanıt
/// da yeni katmandan (SendTextMessage use-case) geçer — tek şema, tek yol.
class StoryReactionService {
  static final _db = FirebaseFirestore.instance;

  /// Hızlı tepki seçenekleri.
  static const quickReactions = ['❤️', '😂', '😮', '😢', '👏', '🔥'];

  /// Hikâye yanıtı işareti — alıntı balonunun hangi hikâyeye ait olduğunu taşır.
  static const storyReplyMarker = 'story:';

  /// Tepki bırak (aynı emojiye tekrar basmak tepkiyi KALDIRIR).
  static Future<void> react({
    required String storyId,
    required String emoji,
  }) async {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    try {
      final doc = _db.collection('stories').doc(storyId);
      final snap = await doc.get();
      final current = (snap.data()?['reactions'] as Map?)?[uid]?.toString();

      // Tek alanlık güncelleme: tüm haritayı okuyup yazmadığımız için
      // eşzamanlı tepkiler birbirini EZMEZ.
      await doc.set({
        'reactions': {
          uid: current == emoji ? FieldValue.delete() : emoji,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Hikâye tepkisi kaydedilemedi: $e');
      rethrow;
    }
  }

  /// Bu kullanıcının bu hikâyeye verdiği tepki (yoksa null).
  static String? myReaction(Map<String, dynamic>? reactions, String uid) =>
      reactions?[uid]?.toString();

  /// Hikâyenin tüm tepkileri — sahibi için özet.
  static Stream<Map<String, String>> watchReactions(String storyId) =>
      _db.collection('stories').doc(storyId).snapshots().map((d) {
        final raw = (d.data()?['reactions'] as Map?) ?? const {};
        return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
      });

  /// Hikâyeye YANIT gönder — hikâye sahibiyle olan sohbete mesaj olarak.
  ///
  /// Hata durumunda çeviri anahtarı taşıyan bir istisna fırlatır.
  static Future<void> reply({
    required String ownerUid,
    required String ownerUsername,
    required String text,
    required String storyPreview,
    String? storyId,
  }) async {
    final myUid = AuthService.currentUid;
    if (myUid == null) throw Exception('not_signed_in');
    // Kendi hikâyene yanıt anlamsız — sessizce çık (hata değil)
    if (ownerUid == myUid) return;

    // Hikâye sahibini bul: önce UID (güvenilir), sonra kullanıcı adı.
    // Eski kod adı önce deniyordu; ad değişmişse yanıt başarısız oluyordu.
    UserModel? user = await AuthService.getUserProfile(ownerUid);
    if (user == null) {
      final cleanName = ownerUsername.trim().replaceAll('@', '').toLowerCase();
      if (cleanName.isNotEmpty) {
        user = await AuthService.findUserByUsername(cleanName);
      }
    }
    if (user == null) throw Exception('story_owner_not_found');

    final chatId = await DirectChatService.getOrCreate(user);

    // Yanıt, hikâye alıntısı olarak işaretlenir; arayüz bunu alıntı
    // balonu olarak çizer ve dokununca ilgili hikâyeye gider.
    final preview = storyId != null
        ? '$storyReplyMarker$storyId:$storyPreview'
        : storyPreview;

    final result = await getIt<SendTextMessage>()(
      SendTextParams(
        chatId: chatId,
        text: text,
        replyToId: storyId == null ? null : 'story_$storyId',
        replyToPreview: preview,
      ),
    );

    result.fold(
      (failure) => throw Exception(failure.message),
      (_) => null,
    );
  }
}
