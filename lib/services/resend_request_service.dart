import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/observability/handled_error.dart';
import '../core/privacy/message_padding.dart';
import 'e2ee_session_service.dart';

/// ♻️ YENİDEN GÖNDERİM İSTEĞİ (§4cl)
///
/// ── NEDEN VAR ──
/// §4cc oturumu onarıyor ama **içeriği kurtarmıyor.** Kod bunu zaten
/// kabul ediyordu: *"Mesajı KURTARMAZ — sohbetin bundan SONRASINI
/// kurtarır."* Sahada bunun bedeli şu oldu (§4ck):
///
///   SECRET "selam" → testçi B 2 mesaj → ikisi de "çözülemedi"
///   → oturum onarıldı → sonrası çalıştı → **o 2 mesaj kalıcı gitti**
///
/// Gönderenin istemcisi, mesajının okunamadığını HİÇ öğrenmiyordu.
/// Signal bunu retry-receipt ile çözer: alıcı çözemeyince göndericiden
/// o mesajı yeni oturumla tekrar ister. Bu servis o eksiği kapatıyor.
///
/// ── NASIL ÇALIŞIYOR ──
/// 1. Alıcı bir mesajı kalıcı olarak çözemez →
///    `resendRequests/{chatId}/req/{messageId}` altına istek yazar.
/// 2. Gönderenin istemcisi bunu **uygulama genelinde tek akışla** dinler.
/// 3. Gönderen kendi düz metnini yerel kasadan okur
///    (`E2EESessionService.getPlaintext` — gönderim anında saklanıyor),
///    GÜNCEL oturumla yeniden şifreler ve **özgün mesaj belgesini
///    günceller.**
/// 4. İsteği siler.
///
/// ── 🎯 NEDEN YENİ MESAJ DEĞİL, GÜNCELLEME ──
/// Yeni mesaj göndermek, kaybolan metni sohbetin SONUNA atardı ve
/// "çözülemedi" balonu olduğu yerde kalırdı — kullanıcı iki kopya
/// görürdü. Özgün belgeyi güncellemek balonu YERİNDE gerçek metne
/// çevirir. Kural zaten buna izin veriyor: `messages` güncellemesi
/// gönderene açık (`resource.data.senderId == request.auth.uid`), yani
/// mesaj kuralında değişiklik GEREKMEDİ.
///
/// ⚠️ `isEdited` İŞARETLENMEZ. Bu bir düzenleme değil, aynı içeriğin
/// yeniden şifrelenmesi; "düzenlendi" etiketi koymak kullanıcıya yanlış
/// bilgi verirdi.
///
/// ── SINIRI ──
/// Gönderen düz metni kaybettiyse (uygulamayı silip kurmuşsa) kurtarma
/// YOKTUR. O durumda istek sessizce silinir; alıcının arayüzü kalıcı
/// kayıp metnini göstermeye devam eder.
class ResendRequestService {
  ResendRequestService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Koleksiyon adı — koleksiyon-grubu sorgusu da bunu kullanır.
  static const String altKoleksiyon = 'req';

  static CollectionReference<Map<String, dynamic>> _ref(String chatId) =>
      _db.collection('resendRequests').doc(chatId).collection(altKoleksiyon);

  /// Bu çalıştırmada zaten istenen mesajlar (`chatId/messageId`).
  ///
  /// ⚠️ Aynı mesaj için tekrar tekrar istek yazmak, karşı tarafı sürekli
  /// yeniden şifrelemeye zorlar (ratchet boşuna ilerler, kota yanar).
  /// El sıkışmadaki `_yayimlanan` ile aynı gerekçe (§4cc).
  static final Set<String> _istenen = {};

  /// Bu çalıştırmada zaten karşılanan istekler — aynı gerekçe, ters yön.
  static final Set<String> _karsilanan = {};

  static void setActiveAccount(String? uid) {
    _istenen.clear();
    _karsilanan.clear();
  }

  /// 📨 BU MESAJI TEKRAR GÖNDER.
  ///
  /// Geriye `true` dönerse arayüz "tekrarı istendi" diyebilir; `false`
  /// dönerse istek yazılamamıştır ve kayıp kalıcı sayılmalıdır. Arayüzün
  /// doğru metni seçebilmesi için bu ayrım ŞART: "istendi" demek ama
  /// istememiş olmak, kullanıcıyı boş yere bekletirdi.
  static Future<bool> iste({
    required String chatId,
    required String messageId,
    required String otherUserId,
    required String myUid,
  }) async {
    if (chatId.isEmpty ||
        messageId.isEmpty ||
        otherUserId.isEmpty ||
        myUid.isEmpty) {
      return false;
    }
    if (!_istenen.add('$chatId/$messageId')) return true;

    try {
      await _ref(chatId).doc(messageId).set({
        'from': myUid,
        'to': otherUserId,
        'messageId': messageId,
        'ts': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e, s) {
      _istenen.remove('$chatId/$messageId');
      // Sessiz kalmaz: bu yol çalışmıyorsa "mesajlar kayboluyor" şikâyeti
      // geri gelir ve sebebi görünmez olurdu (§4cc ile aynı gerekçe).
      reportHandled('Yeniden gönderim isteği yazılamadı', e, stack: s);
      return false;
    }
  }

  /// 📡 BANA GELEN İSTEKLERİ DİNLE — uygulama genelinde, TEK akış.
  ///
  /// ⚠️ Sohbet başına dinleyici AÇILMAZ: kurtarmanın değeri, gönderenin
  /// o sohbeti açmasını beklememesinde (§4cc'deki aynı ders).
  ///
  /// ⚠️ SORGU KISITI İZNİN KENDİSİDİR. `list` kuralı belgeye değil
  /// SORGUYA bakar: `to == ben` kısıtı olmadan sorgunun tamamı reddedilir
  /// (§4bq).
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> dinle(
      String myUid) {
    return _db
        .collectionGroup(altKoleksiyon)
        .where('to', isEqualTo: myUid)
        .snapshots()
        .listen((snap) async {
      for (final d in snap.docChanges) {
        if (d.type == DocumentChangeType.removed) continue;
        await _karsila(d.doc);
      }
    }, onError: (Object e, StackTrace s) {
      reportHandled('Yeniden gönderim dinleyicisi düştü', e, stack: s);
    });
  }

  static Future<void> _karsila(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    // `resendRequests/{chatId}/req/{messageId}` → chatId iki seviye yukarıda.
    final chatId = doc.reference.parent.parent?.id;
    final messageId = doc.id;
    if (chatId == null || chatId.isEmpty || messageId.isEmpty) return;
    if (!_karsilanan.add('$chatId/$messageId')) return;

    try {
      // Yalnızca KENDİ gönderdiğim mesajın düz metni kasada durur; başka
      // birinin mesajı istenirse burası null döner ve hiçbir şey olmaz.
      final plaintext = await E2EESessionService.getPlaintext(messageId);
      if (plaintext == null) {
        // Kurtarma YOK (ör. uygulama silinip kurulmuş). İsteği bırakmak
        // karşı tarafı süresiz bekletirdi; siliyoruz.
        await _sil(chatId, messageId);
        return;
      }

      final ciphertext = await E2EESessionService.encryptMessage(
        chatId: chatId,
        plaintext: MessagePadding.pad(plaintext),
      );
      if (ciphertext == null) {
        // Oturum durumu okunamadı — isteği BIRAKIYORUZ ki uygulama bir
        // sonraki açılışta tekrar denesin. Silmek kurtarmayı kalıcı
        // olarak imkânsız kılardı.
        _karsilanan.remove('$chatId/$messageId');
        reportHandled('Yeniden şifreleme başarısız — istek bırakıldı',
            StateError('resend_encrypt_failed'));
        return;
      }

      // Oturum henüz onaylanmadıysa başlık da gitmeli; yoksa karşı taraf
      // yeni oturumu kuramaz ve yeniden gönderim de çözülemez (§4be).
      final header = await E2EESessionService.pendingInitHeader(chatId);

      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'content': ciphertext,
        'isE2EE': true,
        if (header != null) 'e2eeHeader': header,
      });

      await _sil(chatId, messageId);
    } catch (e, s) {
      _karsilanan.remove('$chatId/$messageId');
      reportHandled('Yeniden gönderim karşılanamadı', e, stack: s);
    }
  }

  static Future<void> _sil(String chatId, String messageId) async {
    try {
      await _ref(chatId).doc(messageId).delete();
    } catch (e, s) {
      // Silinemezse zarar yok: dedup kümesi tekrar işlenmesini engeller.
      reportHandled('Yeniden gönderim isteği silinemedi', e, stack: s);
    }
  }
}
