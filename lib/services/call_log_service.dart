import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'username_resolver.dart';

/// 📞 ÇAĞRI GEÇMİŞİ
///
/// Sinyalleşme dokümanları (`calls`) kısa ömürlüdür ve silinir; kalıcı
/// geçmiş `callLogs` koleksiyonunda tutulur. Her kayıt iki tarafı da
/// `participants` dizisinde taşır, böylece tek sorguyla gelen+giden
/// çağrılar listelenir.
class CallLogEntry {
  final String callId;
  final String callerId;
  final String callerUsername;
  final String calleeId;
  final String calleeUsername;
  final String type; // audio | video
  final String status; // ended | missed | rejected
  final DateTime? createdAt;
  final int durationSec;

  /// Kayit IKI TARAFA ait tek dokumandir; silme kisiye ozel olmali.
  /// Bu dizide olan kullanicilar kaydi gormez (karsi taraf etkilenmez).
  final List<String> deletedFor;

  const CallLogEntry({
    required this.callId,
    required this.callerId,
    required this.callerUsername,
    required this.calleeId,
    required this.calleeUsername,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.durationSec,
    this.deletedFor = const [],
  });

  factory CallLogEntry.fromMap(Map<String, dynamic> m) => CallLogEntry(
        callId: (m['callId'] ?? '').toString(),
        callerId: (m['callerId'] ?? '').toString(),
        callerUsername: (m['callerUsername'] ?? '').toString(),
        calleeId: (m['calleeId'] ?? '').toString(),
        calleeUsername: (m['calleeUsername'] ?? '').toString(),
        type: (m['type'] ?? 'audio').toString(),
        status: (m['status'] ?? 'ended').toString(),
        createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()),
        durationSec:
            (m['durationSec'] is num) ? (m['durationSec'] as num).toInt() : 0,
        deletedFor: ((m['deletedFor'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  bool isOutgoing(String myUid) => callerId == myUid;
  bool get isMissed => status == 'missed';
  bool get isRejected => status == 'rejected';

  /// Karşı tarafın adı (listede gösterilecek).
  ///
  /// ⚠️ Önce CANLI çözüm, sonra eski kayıttaki ad. Çağrı geçmişi
  /// KALICIDIR: adları sunucuda tutmak, "kim kimi ne zaman aradı"
  /// bilgisini adlarıyla süresiz saklamak demekti (§4k/§4o'nun
  /// aramalardaki hâli). Alan artık yazılmıyor; eski kayıtlar adsız
  /// kalmasın diye okunmaya devam ediyor.
  String otherName(String myUid) {
    final uid = otherUid(myUid);
    final resolved = UsernameResolver.cached(uid);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final legacy = isOutgoing(myUid) ? calleeUsername : callerUsername;
    if (legacy.isNotEmpty) return legacy;
    return uid.length > 6 ? uid.substring(0, 6) : uid;
  }

  String otherUid(String myUid) => isOutgoing(myUid) ? calleeId : callerId;
}

class CallLogService {
  static final _db = FirebaseFirestore.instance;

  /// 📞 ÇAĞRIYI ARŞİVLE — TEK KAYNAK.
  ///
  /// Sinyalleşme dokümanı (`calls/{callId}`) kısa ömürlüdür; burada kalıcı
  /// kayıt yazılır. Ayrıca cevapsızsa ilgili birebir sohbete sistem mesajı
  /// düşülür.
  ///
  /// NOT: Daha önce bu iş yalnızca `call_remote_datasource.updateStatus`
  /// içindeydi; ancak gerçek arama akışı `CallService` üzerinden doğrudan
  /// Firestore'a yazdığı için oradan HİÇ geçmiyordu — kayıtlar bu yüzden
  /// oluşmuyordu. Artık her iki yol da buraya çağırıyor.
  static Future<void> archive(String callId, String statusName) async {
    try {
      final snap = await _db.collection('calls').doc(callId).get();
      final d = snap.data();
      if (d == null) return;

      final answeredAt = d['answeredAt'];
      final endedAt = d['endedAt'] ?? DateTime.now().toUtc().toIso8601String();

      var durationSec = 0;
      if (answeredAt is String) {
        final a = DateTime.tryParse(answeredAt);
        final e = DateTime.tryParse(endedAt.toString());
        if (a != null && e != null) durationSec = e.difference(a).inSeconds;
      }

      // Cevaplanmadan bittiyse CEVAPSIZ say
      final effective =
          (statusName == 'ended' && answeredAt == null) ? 'missed' : statusName;

      final callerId = (d['callerId'] ?? '').toString();
      final calleeId = (d['calleeId'] ?? '').toString();
      if (callerId.isEmpty || calleeId.isEmpty) return;

      await _db.collection('callLogs').doc(callId).set({
        'callId': callId,
        'callerId': callerId,
        'calleeId': calleeId,
        // ⚠️ ADLAR YAZILMAZ. Çağrı geçmişi kalıcıdır; adları burada
        // tutmak sosyal grafiği süresiz olarak adlarıyla saklamaktı.
        'participants': [callerId, calleeId],
        'type': d['type'] ?? 'audio',
        'status': effective,
        'createdAt': d['createdAt'] ?? endedAt,
        'endedAt': endedAt,
        'durationSec': durationSec,
      }, SetOptions(merge: true));

      // ÇAĞRI KAYDI -> sohbete sistem mesajı (idempotent: id çağrıya bağlı)
      // Hem CEVAPSIZ hem CEVAPLANAN aramalar düşer; eskiden yalnızca
      // cevapsızlar yazılıyordu ve konuşulan aramalar sohbette görünmüyordu.
      final isAnswered = effective == 'ended' && durationSec > 0;
      if (effective == 'missed' || isAnswered) {
        final ids = [callerId, calleeId]..sort();
        final chatId = ids.join('_');
        final msgId = 'call_$callId';
        final now = DateTime.now().toUtc().toIso8601String();
        await _db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(msgId)
            .set({
          'id': msgId,
          'chatId': chatId,
          // KURAL UYUMU: Mesajı YAZAN kişinin kimliği kullanılır.
          // Eskiden her zaman `callerId` yazılıyordu; aranan taraf
          // arşivlediğinde "başkası adına mesaj yazma" sayıldığı için
          // güvenlik kuralı reddediyordu.
          // Görsel olarak fark yok: çağrı bildirimi ORTALI çizilir,
          // gönderen tarafı gösterilmez.
          'senderId': FirebaseAuth.instance.currentUser?.uid ?? callerId,
          // ⚠️ `senderUsername` KALDIRILDI — §4k İHLALİYDİ.
          // §4k gönderen adını mesajlardan kaldırmıştı ama bu yol
          // `MessageModel`i ATLAYIP ham map yazdığı için alanı geri
          // koyuyordu. Model üzerindeki test bunu göremezdi; iki ayrı
          // yazma yolunun aynı şemayı paylaşmasının bedeli.
          // (Çağrı bildirimi ORTALI çizilir, gönderen adı zaten
          // gösterilmez.)
          // İşaretli biçim: arayüzde kullanıcının diline çevrilir.
          // 'call:<tur>:<saniye>'  ·  cevapsızda saniye 0
          'content': effective == 'missed'
              ? '📞 Cevapsız çağrı'
              : '📞 call:${d['type'] ?? 'audio'}:$durationSec',
          'type': 'text',
          'timestamp': now,
          'status': 'sent',
          'isEncrypted': false,
        }, SetOptions(merge: true));
        await _db.collection('chats').doc(chatId).set({
          'lastMessage': effective == 'missed'
              ? '📞 Cevapsız çağrı'
              : '📞 call:${d['type'] ?? 'audio'}:$durationSec',
          'lastMessageTime': now,
          'lastMessageSenderId':
              FirebaseAuth.instance.currentUser?.uid ?? callerId,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Çağrı arşivlenemedi: $e');
    }
  }

  /// Kullanicinin cagri gecmisi.
  ///
  /// DIRENC: birincil sorgu (participants + createdAt sirali) BILESIK
  /// DIZIN ister. Dizin yoksa Firestore hata firlatir ve liste hic gelmez;
  /// bu durumda sirasiz sorguya duser, siralamayi cihazda yapariz.
  static Stream<List<CallLogEntry>> watch(String myUid) {
    final base =
        _db.collection('callLogs').where('participants', arrayContains: myUid);

    List<CallLogEntry> parse(QuerySnapshot<Map<String, dynamic>> s) => s.docs
        .map((d) => CallLogEntry.fromMap(d.data()))
        // kisiye ozel silinenleri gizle
        .where((e) => !e.deletedFor.contains(myUid))
        .toList();

    void sortDesc(List<CallLogEntry> l) => l.sort((a, b) {
          final at = a.createdAt, bt = b.createdAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });

    final controller = StreamController<List<CallLogEntry>>();
    StreamSubscription? sub;
    var fellBack = false;

    // 🕵️ Adlar artık kayıtta DEĞİL, uid'den çözülüyor. Liste çizilmeden
    // ÖNCE toplu ısıtılır ki `otherName` senkron yolda hazır adı bulsun;
    // yoksa geçmiş önce uid kısaltmalarıyla çizilip sonra zıplardı.
    Future<void> emit(List<CallLogEntry> list) async {
      try {
        await UsernameResolver.warm(list.map((e) => e.otherUid(myUid)));
      } catch (_) {
        // Ad çözülemezse liste yine gösterilir (eski ad ya da uid).
      }
      if (!controller.isClosed) controller.add(list);
    }

    void listenFallback() {
      sub = base.limit(200).snapshots().listen(
        (snap) {
          final list = parse(snap);
          sortDesc(list);
          emit(list);
        },
        onError: controller.addError,
      );
    }

    void listenOrdered() {
      sub = base
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .listen(
        (snap) => emit(parse(snap)),
        onError: (e) {
          if (!fellBack) {
            fellBack = true;
            debugPrint('Çağrı geçmişi dizinsiz moda düştü: $e');
            sub?.cancel();
            listenFallback();
          } else {
            controller.addError(e);
          }
        },
      );
    }

    controller.onListen = listenOrdered;
    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close(); // kaynak sizintisi olmasin
    };
    return controller.stream;
  }

  /// Secili kayitlari YALNIZCA bu kullanici icin sil.
  static Future<void> deleteForMe(
      Iterable<String> callIds, String myUid) async {
    final batch = _db.batch();
    for (final id in callIds) {
      batch.set(
        _db.collection('callLogs').doc(id),
        {
          'deletedFor': FieldValue.arrayUnion([myUid])
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------
  // ROZET "GÖRÜLDÜ" DURUMU
  //
  // SORUN: Rozet tüm cevapsız çağrıları sayıyordu; kullanıcı Aramalar
  // sekmesini açsa bile sayı hiç sıfırlanmıyordu.
  // ÇÖZÜM: Sekme açıldığında yerel bir "görüldü zamanı" yazılır; rozet
  // yalnızca bundan SONRAKİ cevapsız çağrıları sayar. (Sunucuya yazma
  // yok — tamamen cihaz-yerel, ücretsiz.)
  // ---------------------------------------------------------------
  static String _seenKey(String uid) => 'calls_seen_at_$uid';
  static DateTime? _seenCache;

  /// Aramalar sekmesi açıldı → rozeti sıfırla.
  static Future<void> markCallsSeen(String myUid) async {
    final now = DateTime.now();
    _seenCache = now;
    final p = await SharedPreferences.getInstance();
    await p.setString(_seenKey(myUid), now.toIso8601String());
  }

  static Future<DateTime?> _seenAt(String myUid) async {
    if (_seenCache != null) return _seenCache;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_seenKey(myUid));
    _seenCache = raw == null ? null : DateTime.tryParse(raw);
    return _seenCache;
  }

  /// Görülmemiş cevapsız çağrı sayısı — sekme rozeti için.
  static Stream<int> watchMissedCount(String myUid) async* {
    final seen = await _seenAt(myUid);
    yield* watch(myUid).map((list) => list.where((c) {
          if (!c.isMissed || c.isOutgoing(myUid)) return false;
          final t = c.createdAt;
          if (seen == null || t == null) return true;
          return t.isAfter(seen);
        }).length);
  }
}
