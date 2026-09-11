import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/exceptions.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'self_note_service.dart';
import 'username_resolver.dart';
import '../core/observability/handled_error.dart';

/// Birebir (1-1) sohbet dokümanını oluşturur veya mevcut olanı döndürür.
///
/// Eski `ChatService` motorundan devralınan TEK canlı sorumluluk budur;
/// mesaj gönderme/okuma tamamen `features/messaging` katmanına taşındı
/// (eski motor iki farklı şema yazıyor ve düz metin önizleme sızdırıyordu).
///
/// ── DÜZELTİLEN YARIŞ DURUMU ──
/// Eski kod `get()` → yoksa `set()` yapıyordu. İki kullanıcı aynı anda
/// sohbeti açtığında ikisi de "yok" görüp `set()` çağırıyor ve biri
/// diğerinin alanlarını EZİYORDU. Artık `set(merge: true)` kullanılıyor:
/// doküman varsa alanlar birleştirilir, kimse ezilmez.
class DirectChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Birebir sohbet kimliği: sıralı uid'lerin birleşimi.
  /// Deterministik olması, iki tarafın AYNI dokümanı bulmasını sağlar.
  static String directChatId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  /// 🗒️ KENDİNE SOHBET ("Notlarım") — oluştur/bul.
  ///
  /// Kimlik yine `sıralı uid'ler` biçimindedir (`uid_uid`), yani var
  /// olan sorgular, kurallar ve sohbet listesi hiç değişmeden çalışır.
  ///
  /// ⚠️ İÇERİK ŞİFRELEMESİ AYRI BİR YOLDAN GİDER
  /// (`SelfNoteService`): iki taraf aynı kişi olduğu için ne X3DH ne de
  /// grup sender-key'i işler. O yol olmadan bu sohbet "dejenere grup"
  /// sayılır ve notlar sunucuya DÜZ METİN yazılırdı.
  static Future<String> getOrCreateSelfChat() async {
    final myUid = AuthService.currentUid;
    if (myUid == null) {
      throw const AuthException('err_session_missing');
    }
    final chatId = SelfNoteService.selfChatId(myUid);
    try {
      await _db.collection('chats').doc(chatId).set({
        'id': chatId,
        'type': 'direct',
        'memberIds': [myUid],
        'memberCount': 1,
        'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
      return chatId;
    } on FirebaseException catch (e) {
      // Doküman zaten varsa yazma reddedilse bile sohbet açılabilmeli.
      if (e.code == 'permission-denied') {
        final snap = await _db.collection('chats').doc(chatId).get();
        if (snap.exists) return chatId;
      }
      reportHandled('Kendine sohbet oluşturulamadı', e);
      throw const ServerException('err_chat_create');
    }
  }

  /// Sohbeti oluştur/bul ve kimliğini döndür.
  static Future<String> getOrCreate(UserModel otherUser) async {
    final myUid = AuthService.currentUid;
    if (myUid == null) {
      throw const AuthException('err_session_missing');
    }
    if (otherUser.uid == myUid) {
      throw const ServerException('err_self_chat');
    }

    final chatId = directChatId(myUid, otherUser.uid);
    final ids = [myUid, otherUser.uid]..sort();

    // Karşı tarafın adını ZATEN biliyoruz (kullanıcı onu arayıp buldu).
    // Yerel çözümleyiciye tohumla: sohbet listesi başlığı sunucuya hiç
    // ad yazılmadan, ek okuma da yapılmadan doğru görünsün.
    UsernameResolver.seed(otherUser.uid, otherUser.username);

    try {
      // merge:true → varsa üzerine yazmaz, yoksa oluşturur (yarış güvenli).
      // lastMessageTime BAŞLANGIÇTA yazılır: sohbet listesi bu alanla
      // orderBy yapıyor ve alanı olmayan dokümanlar sonuçtan DÜŞÜYOR —
      // yani alan olmadan yeni sohbet hiç görünmüyordu.
      await _db.collection('chats').doc(chatId).set({
        'id': chatId,
        'type': 'direct',
        'memberIds': ids,
        // ⚠️ `memberUsernames` BİLEREK YOK (§4o): iki tarafın adını yan
        // yana yazmak, içerik şifreli olsa bile sosyal grafiği sunucuda
        // adlarıyla okunur bırakıyordu. Başlıktaki ad artık uid'den
        // yerelde çözülür.
        'memberCount': ids.length,
        'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
      return chatId;
    } on FirebaseException catch (e) {
      // ── KURAL ↔ İSTEMCİ UYUŞMAZLIĞI (giderildi) ──
      //
      // Bu yedek, `memberUsernames` yazımının kural tarafından
      // reddedilmesi yüzünden eklenmişti: doküman farklı bir ad
      // listesiyle oluşmuşsa çağrı permission-denied alıyor ve o sohbet
      // KALICI OLARAK açılamıyordu — her denemede aynı hata.
      //
      // Alan §4o ile tamamen kaldırıldı, yani o özel sebep artık yok.
      // Yedek KORUNUYOR: sohbet zaten varsa, yazma başka bir sebeple
      // reddedilse bile açılabilir olması yeterlidir. Sohbeti tamamen
      // erişilemez yapmaktan kıyaslanamayacak kadar iyidir.
      if (e.code == 'permission-denied') {
        try {
          final snap = await _db.collection('chats').doc(chatId).get();
          if (snap.exists) return chatId;
        } catch (_) {
          // okuma da başarısızsa aşağıdaki hataya düş
        }
      }
      reportHandled('Sohbet oluşturulamadı', e);
      throw const ServerException('err_chat_create');
    }
  }
}
