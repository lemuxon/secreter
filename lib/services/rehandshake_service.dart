import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/observability/handled_error.dart';
import 'e2ee_session_service.dart';

/// 🤝 SESSİZ YENİDEN EL SIKIŞMA (§4cc)
///
/// ── NEDEN VAR ──
/// Oturum bozulduğunda kurtarma yolu şuydu: kendi oturumumu sıfırla, ve
/// **kullanıcı bir şey yazınca** X3DH baştan kurulup başlık gitsin.
/// Yani onarım kullanıcının yazmasını bekliyordu.
///
/// Bu, gerçek kullanımda eziyet üretiyor: karşı taraf üç saat sonra
/// dönüp mesajlarının "çözülemedi" olduğunu görüyor ve konuşmanın
/// tamamı yeniden anlatılıyor. WhatsApp ve Signal böyle davranmaz —
/// çözme başarısız olunca istemci karşı tarafı yeni oturuma **kendisi**
/// zorlar, kullanıcıdan bir şey beklemez.
///
/// ── NASIL ÇALIŞIYOR ──
/// Oturum ölü tespit edilince:
///   1. kendi oturumumuzu sıfırlarız,
///   2. X3DH'i BAŞLATIRIZ (karşı tarafın açık paketiyle) ve
///   3. init başlığını `handshakes/{chatId}/init/{benimUid}` altına
///      yayımlarız — sohbete görünür hiçbir mesaj düşmez.
///
/// Karşı tarafın istemcisi bunu uygulama genelinde dinler ve
/// `ensureSessionFromHeader` ile kendi tarafını onarır. Onarım
/// **o sohbeti açmasını bile gerektirmez.**
///
/// ── REPLAY KORUMASI BEDAVA GELİYOR ──
/// `ensureSessionFromHeader` yalnızca EFEMERAL anahtar değişmişse
/// oturumu yeniler (§4ax). Aynı belge tekrar tekrar okunsa bile ikinci
/// kezinde efemeral aynıdır → hiçbir şey yapılmaz. Yani ayrı bir
/// "en son ne zaman uyguladım" durumu tutmaya gerek yok.
///
/// ⚠️ KİM YAZABİLİR: yalnızca sohbetin üyesi ve yalnızca KENDİ adına
/// (güvenlik kuralı). Yabancı bir hesap başkasının oturumunu
/// sıfırlatamaz.
class RehandshakeService {
  RehandshakeService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Koleksiyon adı — koleksiyon-grubu sorgusu da bunu kullanır.
  static const String altKoleksiyon = 'init';

  static CollectionReference<Map<String, dynamic>> _ref(String chatId) =>
      _db.collection('handshakes').doc(chatId).collection(altKoleksiyon);

  /// Bu çalıştırmada zaten yayımlanmış sohbetler.
  ///
  /// ⚠️ Her başarısız çözmede yeniden yayımlamak, karşı tarafın oturumunu
  /// sürekli sıfırlatır ve iki taraf birbirini kovalar. Sohbet başına bir
  /// kez yeter; uygulama yeniden açılınca küme boşalır.
  static final Set<String> _yayimlanan = {};

  /// Hesap değişti — kümeyi düşür (önceki hesabın sohbetleri sayılmasın).
  static void setActiveAccount(String? uid) => _yayimlanan.clear();

  /// Ölü oturumu onarmak için sessiz el sıkışma yayımla.
  ///
  /// [chatId] birebir sohbet, [otherUserId] karşı taraf. Karşı tarafın
  /// anahtar paketi yoksa (henüz uygulamayı açmamış) sessizce vazgeçilir.
  static Future<void> yayinla({
    required String chatId,
    required String otherUserId,
    required String myUid,
  }) async {
    if (otherUserId.isEmpty || myUid.isEmpty) return;
    if (!_yayimlanan.add(chatId)) return;

    try {
      // Oturumu SIFIRDAN kur — başlatıcı biziz.
      final header = await E2EESessionService.initiateSession(
        chatId: chatId,
        otherUserId: otherUserId,
      );
      if (header == null) {
        // Karşı tarafın anahtar paketi yok; yayımlanacak bir şey yok.
        _yayimlanan.remove(chatId);
        return;
      }

      await _ref(chatId).doc(myUid).set({
        'from': myUid,
        'to': otherUserId,
        'header': header.toMap(),
        'ts': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, s) {
      // Yayımlanamazsa eski davranışa düşeriz (kullanıcı yazınca onarım).
      // Sessiz kalmaz: bu yol çalışmıyorsa "mesajlar çözülemiyor"
      // şikâyeti geri gelir ve sebebi görünmez olurdu.
      _yayimlanan.remove(chatId);
      reportHandled('Sessiz el sıkışma yayımlanamadı', e, stack: s);
    }
  }

  /// 📡 BANA GELEN EL SIKIŞMALARI DİNLE — uygulama genelinde, TEK akış.
  ///
  /// ⚠️ Sohbet başına dinleyici AÇILMAZ. Onarımın değeri, karşı tarafın
  /// o sohbeti açmasını beklememesinde; sohbet ekranına bağlanan bir
  /// dinleyici bu değeri tamamen yok ederdi.
  ///
  /// ⚠️ SORGU KISITI İZNİN KENDİSİDİR. `list` kuralı belgeye değil
  /// SORGUYA bakar: `to == ben` kısıtı olmadan sorgunun tamamı
  /// reddedilir (§4bq'da birebir aynısı yaşandı).
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> dinle(
      String myUid) {
    return _db
        .collectionGroup(altKoleksiyon)
        .where('to', isEqualTo: myUid)
        .snapshots()
        .listen((snap) async {
      for (final d in snap.docChanges) {
        if (d.type == DocumentChangeType.removed) continue;
        await _uygula(d.doc);
      }
    }, onError: (Object e, StackTrace s) {
      reportHandled('El sıkışma dinleyicisi düştü', e, stack: s);
    });
  }

  static Future<void> _uygula(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      // `handshakes/{chatId}/init/{fromUid}` → chatId iki seviye yukarıda.
      final chatId = doc.reference.parent.parent?.id;
      final ham = doc.data()?['header'];
      if (chatId == null || chatId.isEmpty || ham is! Map) return;

      final header = E2EEInitHeader.fromMap(
        Map<String, dynamic>.from(ham),
      );
      if (!header.isValid) return;

      // Aynı başlık tekrar gelirse burası hiçbir şey yapmaz: yenileme
      // yalnızca EFEMERAL değiştiyse olur (§4ax). Replay koruması bu.
      await E2EESessionService.ensureSessionFromHeader(
        chatId: chatId,
        header: header,
      );
    } catch (e, s) {
      reportHandled('El sıkışma uygulanamadı', e, stack: s);
    }
  }
}
