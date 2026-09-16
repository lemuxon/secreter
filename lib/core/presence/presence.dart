import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import 'package:flutter/widgets.dart';
import '../i18n/app_localizations.dart';
import '../di/injection.dart';
import '../privacy/privacy_controller.dart';

/// Kullanıcı varlık durumu: çevrimiçi / son görülme / yazıyor.
class PresenceInfo {
  final bool online;
  final DateTime? lastSeen;
  final String? typingIn; // yazmakta olduğu chatId (yoksa null)

  const PresenceInfo({
    this.online = false,
    this.lastSeen,
    this.typingIn,
  });

  factory PresenceInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PresenceInfo();
    return PresenceInfo(
      online: map['online'] == true,
      lastSeen: DateTime.tryParse(map['lastSeen'] ?? ''),
      typingIn: map['typingIn'],
    );
  }
}

/// Varlık durumu yazıcıları (kendi durumumu güncelle).
class PresenceService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> setOnline(bool online) async {
    final uid = AuthService.currentUid;
    if (uid == null) return;

    // 🔒 GİZLİLİK AYARI: "Çevrimiçi durumunu paylaş" kapalıysa sunucuya
    // HİÇ yazma — kullanıcı hep çevrimdışı görünür.
    // (Bu kontrol eksikti: ayar kapatılsa bile durum yazılmaya devam
    // ediyordu, yani anahtar hiçbir işe yaramıyordu.)
    if (!getIt<PrivacySettingsReader>().current.sharePresence) {
      // Daha önce yazılmış durumu da temizle
      try {
        await _db.collection('users').doc(uid).set({
          'online': false,
          'typingIn': null,
        }, SetOptions(merge: true));
      } catch (_) {}
      return;
    }

    try {
      await _db.collection('users').doc(uid).set({
        'online': online,
        'lastSeen': DateTime.now().toUtc().toIso8601String(),
        if (!online) 'typingIn': null,
      }, SetOptions(merge: true));
    } catch (_) {
      // Varlık güncellemesi kritik değil; sessiz geç
    }
  }

  /// Yazıyor durumu: chatId ver = yazıyor, null = durdu.
  static Future<void> setTyping(String? chatId) async {
    final uid = AuthService.currentUid;
    if (uid == null) return;

    // 🔒 GİZLİLİK AYARI: "Yazıyor göstergesi" kapalıysa gönderme.
    // Durdurma sinyali (null) yine gönderilir — aksi halde önceden
    // yazılmış "yazıyor" durumu ekranda takılı kalabilir.
    if (chatId != null &&
        !getIt<PrivacySettingsReader>().current.sendTypingIndicator) {
      return;
    }
    try {
      await _db.collection('users').doc(uid).set({
        'typingIn': chatId,
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

/// Bir kullanıcının varlık durumunu canlı izler.
final presenceProvider =
    StreamProvider.family<PresenceInfo, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => PresenceInfo.fromMap(doc.data()));
});

/// Başlıktaki varlık satırının TÜRÜ.
///
/// ⚠️ Eskiden çağıran taraf bunu **metni Türkçe dizeyle karşılaştırarak**
/// anlıyordu (`text == 'yazıyor...'`). İki şekilde birden kırıktı: metin
/// yanlış anahtardan geldiği için karşılaştırma HİÇ tutmuyordu, ve
/// tutsaydı bile yalnızca Türkçede tutardı — diğer 15 dilde "yazıyor" ve
/// "çevrimiçi" vurgusu sessizce kayboluyordu. Tür artık metinden değil,
/// verinin kendisinden geliyor.
enum PresenceKind { typing, online, lastSeen, none }

/// Varlık satırı: ne yazacağı VE nasıl vurgulanacağı.
class PresenceLabel {
  final String text;
  final PresenceKind kind;

  const PresenceLabel(this.text, this.kind);

  static const empty = PresenceLabel('', PresenceKind.none);

  /// "yazıyor" ve "çevrimiçi" vurgulanır; "son görülme" nötr kalır.
  bool get vurgulu =>
      kind == PresenceKind.typing || kind == PresenceKind.online;
}

/// Varlık satırını biçimlendir ("yazıyor..." / "çevrimiçi" /
/// "son görülme 14:32").
PresenceLabel presenceLabel(BuildContext context, PresenceInfo p,
    {String? forChatId}) {
  if (forChatId != null && p.typingIn == forChatId) {
    // 🪤 ESKİDEN `typing_indicator` OKUNUYORDU — o bir AYAR BAŞLIĞIDIR
    // ("Yazıyor göstergesi" / "Typing indicator"), durum metni değil.
    // Sohbet başlığında "Yazıyor göstergesi..." yazıyordu: hem yanlış
    // hem de dar başlık alanına sığmayacak kadar uzun.
    return PresenceLabel(
        '${context.tr('presence_typing')}...', PresenceKind.typing);
  }
  if (p.online) {
    return PresenceLabel(context.tr('online_now'), PresenceKind.online);
  }
  final t = p.lastSeen;
  if (t == null) return PresenceLabel.empty;
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final hm = '${two(t.hour)}:${two(t.minute)}';
  final isToday =
      t.year == now.year && t.month == now.month && t.day == now.day;
  if (isToday) {
    return PresenceLabel(
        '${context.tr('last_seen')} $hm', PresenceKind.lastSeen);
  }
  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday = t.year == yesterday.year &&
      t.month == yesterday.month &&
      t.day == yesterday.day;
  if (isYesterday) {
    // 📏 "son görülme" ÖN EKİ BİLEREK YOK. "son görülme dün 14:32"
    // Almanca/Yunanca/Portekizcede başlık payını aşıyordu; "dün 14:32"
    // ismin altında zaten son görülme olarak okunur (WhatsApp da böyle
    // yazar). Tarih biçiminde ön ek KALIYOR: yalnız "28.02" ne olduğu
    // belirsiz kalırdı.
    return PresenceLabel(
        '${context.tr('yesterday')} $hm', PresenceKind.lastSeen);
  }
  return PresenceLabel(
      '${context.tr('last_seen')} ${two(t.day)}.${two(t.month)}',
      PresenceKind.lastSeen);
}
