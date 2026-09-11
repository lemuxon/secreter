import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/message_entity.dart';
import '../models/message_model.dart';
import '../../../../core/media/upload_progress.dart';
import '../../../../core/observability/handled_error.dart';

/// Mesajların uzak veri kaynağı (Firestore + Storage).
///
/// SADECE ham veri erişimi yapar — şifreleme, iş kuralı YOK.
/// Hata durumunda exception fırlatır (repository bunları Failure'a çevirir).
abstract class MessageRemoteDataSource {
  Stream<List<MessageModel>> watchMessages(String chatId);

  /// Verilen zamandan ESKI mesajlari sayfali getir (pagination).
  Future<List<MessageModel>> fetchOlder(
      String chatId, DateTime before, int limit);
  Future<void> sendMessage(String chatId, MessageModel message);
  Future<String> uploadMedia(String chatId, File file, String subPath);

  /// ŞİFRELİ ek yükle. Baytlar zaten AES-GCM ile şifrelenmiştir; Storage
  /// yalnızca anlamsız veri saklar.
  Future<String> uploadMediaBytes(
      String chatId, Uint8List bytes, String subPath);
  Future<void> deleteMessage(String chatId, String messageId);

  /// Süresi dolan mesaji sunucudan KALICI sil (kendini imha temizligi).
  Future<void> hardDeleteMessage(String chatId, String messageId);

  /// Sohbetteki TUM mesajlari sil (her iki taraf icin — Firestore).
  /// Sohbeti temizle — YALNIZCA [uid] için (§4aw).
  ///
  /// Kendi mesajları silinir, karşı tarafınkiler `deletedFor` ile
  /// gizlenir. "Her iki taraftan sil" BİLEREK yapılmaz; bkz. gövdedeki
  /// gerekçe.
  Future<void> clearMessages(String chatId, String uid);

  /// 'Benden sil' (tek/toplu): mesajlari yalnizca bu kullanici icin gizle.
  Future<void> deleteForMe(String chatId, List<String> messageIds, String uid);

  /// 'Herkesten sil' (toplu): soft-delete (isDeleted + placeholder).
  Future<void> deleteForEveryone(String chatId, List<String> messageIds);

  /// Düzenlenen içeriği yaz.
  ///
  /// [content] artık ŞİFRELİ olabilir; [isEncrypted] bunu söyler ve
  /// alıcının çözme yoluna girmesini sağlar. Şifrelenemediyse false
  /// yazılır — böylece arayüz yanıltıcı kilit simgesi göstermez.
  Future<void> editMessage(
    String chatId,
    String messageId,
    String content, {
    required bool isEncrypted,
    required DateTime editedAt,
    Map<String, dynamic>? e2eeHeader,
  });

  /// Reaksiyon ekle/degistir/kaldir. emoji bos ise kaldirir.
  Future<void> setReaction(
      String chatId, String messageId, String userId, String emoji);

  /// Tek goruntuluk: Storage dosyasini sil + mesajda mediaUrl'i temizle.
  Future<void> consumeViewOnce(
      String chatId, String messageId, String mediaUrl);
  Future<void> markAsRead(String chatId, String currentUserId);

  /// Yalnizca KENDI okunmamis rozetimi sifirla (gizlilikten bagimsiz).
  Future<void> resetUnread(String chatId, String currentUserId);
  Future<void> updateLastMessage(String chatId, String preview,
      {String? senderId});

  /// Sohbetin üye kimlikleri (grup E2EE anahtar dağıtımı için).
  /// Kısa süreli önbellek kullanır; her mesajda ekstra okuma yapılmaz.
  Future<List<String>> memberIds(String chatId);
}

class MessageRemoteDataSourceImpl implements MessageRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final Uuid uuid;

  MessageRemoteDataSourceImpl({
    required this.firestore,
    required this.storage,
    required this.uuid,
  });

  // updateLastMessage icin uye onbellegi (chatId -> uyeler, zaman)
  static final Map<String, _CachedMembers> _memberCache = {};

  CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) =>
      firestore.collection('chats').doc(chatId).collection('messages');

  @override
  Stream<List<MessageModel>> watchMessages(String chatId) {
    try {
      // PAGINATION: tum gecmis degil, yalnizca SON 100 mesaj canli izlenir
      // (10.000+ mesajli sohbetlerde acilis ve maliyet icin kritik).
      // Daha eskiler kaydirinca fetchOlder ile sayfa sayfa yuklenir.
      return _messagesRef(chatId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          // HATA DUZELTME: Firestore, dinleyici baglaninca once BOS bir
          // cache-snapshot yayinlayabiliyor; bu, ekranda cache'ten gelen
          // mesajlari bir anligina silip tekrar getiriyordu ("gorulup
          // kaybolma"). Bos + cache'ten gelen snapshot'lari atla. GERCEK
          // sunucu-bos (ornegin sohbet temizleme) yine gecer.
          .where((snapshot) =>
              !(snapshot.metadata.isFromCache && snapshot.docs.isEmpty))
          .map((snapshot) => snapshot.docs.reversed
              .map((doc) => MessageModel.fromMap(doc.data(), chatId))
              .toList());
    } catch (e, s) {
      reportHandled('Mesajlar dinlenemedi', e, stack: s);
      throw const ServerException('err_load_messages');
    }
  }

  @override
  Future<void> sendMessage(String chatId, MessageModel message) async {
    try {
      await _messagesRef(chatId).doc(message.id).set(message.toMap());
    } catch (e, s) {
      reportHandled('Mesaj gönderilemedi', e, stack: s);
      throw const ServerException('err_send_message');
    }
  }

  @override
  Future<String> uploadMedia(String chatId, File file, String subPath) async {
    try {
      final ref = storage.ref().child('chats/$chatId/$subPath');
      // 📊 YÜKLEME İLERLEMESİ
      // `putFile` bir UploadTask döndürür; olaylarını dinleyerek
      // yüzdeyi arayüze bildiriyoruz. Kullanıcı büyük dosyada ne
      // kadar kaldığını görür.
      final task = ref.putFile(file);
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          UploadProgress.instance
              .update(snap.bytesTransferred / snap.totalBytes);
        }
      });
      await task;
      UploadProgress.instance.finish();
      return await ref.getDownloadURL();
    } catch (e, s) {
      reportHandled('Medya yüklenemedi', e, stack: s);
      throw const ServerException('err_media_upload');
    }
  }

  @override
  Future<List<MessageModel>> fetchOlder(
      String chatId, DateTime before, int limit) async {
    try {
      final snap = await _messagesRef(chatId)
          .orderBy('timestamp', descending: true)
          .startAfter([before.toIso8601String()])
          .limit(limit)
          .get();
      // desc geldi -> asc dondur
      return snap.docs.reversed
          .map((doc) => MessageModel.fromMap(doc.data(), chatId))
          .toList();
    } catch (e, s) {
      reportHandled('Eski mesajlar yüklenemedi', e, stack: s);
      throw const ServerException('err_load_messages');
    }
  }

  @override
  Future<void> deleteForMe(
      String chatId, List<String> messageIds, String uid) async {
    try {
      const chunk = 400;
      for (var i = 0; i < messageIds.length; i += chunk) {
        final batch = firestore.batch();
        for (final id in messageIds.skip(i).take(chunk)) {
          batch.update(_messagesRef(chatId).doc(id), {
            'deletedFor': FieldValue.arrayUnion([uid]),
          });
        }
        await batch.commit();
      }
    } catch (e, s) {
      reportHandled('Mesaj silinemedi', e, stack: s);
      throw const ServerException('err_delete_message');
    }
  }

  @override
  Future<void> deleteForEveryone(String chatId, List<String> messageIds) async {
    try {
      const chunk = 400;
      for (var i = 0; i < messageIds.length; i += chunk) {
        final batch = firestore.batch();
        for (final id in messageIds.skip(i).take(chunk)) {
          batch.update(_messagesRef(chatId).doc(id), {
            'isDeleted': true,
            'content': '',
            'mediaUrl': null,
            'type': MessageContentType.deleted.name,
          });
        }
        await batch.commit();
      }
    } catch (e, s) {
      reportHandled('Mesaj silinemedi', e, stack: s);
      throw const ServerException('err_delete_message');
    }
  }

  @override
  Future<void> clearMessages(String chatId, String uid) async {
    try {
      final msgs = await _messagesRef(chatId).get();
      // ── 🐞 §4aw: "SOHBETİ TEMİZLE" HER BİREBİR SOHBETTE KIRIKTI ──
      //
      // Eski kod her mesaj BELGESİNİ siliyordu. Kural ise şunu diyor:
      //   allow delete: if member() && (senderId == uid || isChatAdmin())
      // Birebir sohbette YÖNETİCİ YOKTUR; yani karşı tarafın mesajları
      // silinemez ve toplu yazma TÜMDEN reddedilirdi. Kullanıcı her
      // seferinde "Temizlenemedi" görüyordu.
      //
      // ⚠️ DÜZELTME KURALI GEVŞETMEK DEĞİL. "Karşı tarafın mesajlarını
      // da sil" izni, bir sohbetin TARAFINA diğerinin geçmişini tek
      // taraflı yok etme yetkisi verirdi — söylediklerinin kaydını
      // silmek isteyen biri için hazır bir araç. Bu yüzden temizleme
      // "yalnızca BENDE" anlamına gelir; kendi mesajlarım silinir,
      // karşı tarafın mesajları benden GİZLENİR (`deletedFor`).
      // (WhatsApp/Signal'deki "Clear chat" de budur.)
      final benimkiler = <DocumentReference>[];
      final digerleri = <DocumentReference>[];
      for (final d in msgs.docs) {
        final gonderen = (d.data()['senderId'] ?? '').toString();
        (gonderen == uid ? benimkiler : digerleri).add(d.reference);
      }
      const parca = 400; // batch limiti (500) güvenliği
      for (var i = 0; i < digerleri.length; i += parca) {
        final batch = firestore.batch();
        for (final ref in digerleri.skip(i).take(parca)) {
          batch.update(ref, {
            'deletedFor': FieldValue.arrayUnion([uid]),
          });
        }
        await batch.commit();
      }
      for (var i = 0; i < benimkiler.length; i += parca) {
        final batch = firestore.batch();
        for (final ref in benimkiler.skip(i).take(parca)) {
          batch.delete(ref);
        }
        await batch.commit();
      }
      await _sonMesajiTemizle(chatId);
    } catch (e, s) {
      reportHandled('Sohbet temizlenemedi', e, stack: s);
      throw const ServerException('err_clear_chat');
    }
  }

  /// Son mesaj önizlemesini temizle.
  ///
  /// ⚠️ `lastMessageTime` SİLİNMEZ — konuşma listesi bu alanla `orderBy`
  /// yapar ve Firestore, alanı OLMAYAN belgeleri sonucun dışında bırakır;
  /// silinseydi sohbet HERKESİN listesinden kaybolurdu.
  ///
  /// ⚠️ ÖNİZLEME ORTAK BİR ALAN. Temizleme "yalnızca bende" olsa da bu
  /// tek satır karşı tarafta da boşalır. Bilinçli ödünleşim: alternatif,
  /// kullanıcıya sohbeti temizledikten SONRA listede hâlâ eski mesajın
  /// metnini göstermekti. Karşı tarafın mesajları duruyor; yalnızca
  /// önizleme, o kişi yeni mesaj yazana kadar boş görünür.
  Future<void> _sonMesajiTemizle(String chatId) async {
    await firestore.collection('chats').doc(chatId).update({
      'lastMessage': '',
      'lastMessageSenderId': FieldValue.delete(),
    });
  }

  @override
  Future<void> hardDeleteMessage(String chatId, String messageId) async {
    try {
      await _messagesRef(chatId).doc(messageId).delete();
    } catch (_) {
      // temizlik best-effort; sessizce gec
    }
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _messagesRef(chatId).doc(messageId).update({
        'isDeleted': true,
        'content': '',
        'mediaUrl': null,
        'type': MessageContentType.deleted.name,
      });
    } catch (e, s) {
      reportHandled('Mesaj silinemedi', e, stack: s);
      throw const ServerException('err_delete_message');
    }
  }

  @override
  Future<void> editMessage(
    String chatId,
    String messageId,
    String content, {
    required bool isEncrypted,
    required DateTime editedAt,
    Map<String, dynamic>? e2eeHeader,
  }) async {
    try {
      await _messagesRef(chatId).doc(messageId).update({
        'content': content,
        'isEdited': true,
        // UTC: yerel saat yazmak saat dilimleri arasında sıralamayı ve
        // önbellek anahtarını bozardı (diğer alanlarla aynı kural).
        'editedAt': editedAt.toUtc().toIso8601String(),
        'isE2EE': isEncrypted,
        // Oturum bu düzenlemeyle kurulduysa başlık da taşınmalı; yoksa
        // alıcı oturumu kuramaz ve düzenlemeyi çözemez.
        if (e2eeHeader != null) 'e2eeHeader': e2eeHeader,
      });
    } catch (e, s) {
      reportHandled('Mesaj düzenlenemedi', e, stack: s);
      throw const ServerException('err_edit_message');
    }
  }

  @override
  Future<void> setReaction(
      String chatId, String messageId, String userId, String emoji) async {
    try {
      final ref = _messagesRef(chatId).doc(messageId);
      if (emoji.isEmpty) {
        await ref.update({'reactions.$userId': FieldValue.delete()});
      } else {
        await ref.update({'reactions.$userId': emoji});
      }
    } catch (e, s) {
      reportHandled('Reaksiyon güncellenemedi', e, stack: s);
      throw const ServerException('err_reaction');
    }
  }

  @override
  Future<void> consumeViewOnce(
      String chatId, String messageId, String mediaUrl) async {
    try {
      // ── STORAGE SİLME İSTEMCİDE DEĞİL, SUNUCUDA ──
      //
      // Burada `storage.delete()` ÇAĞIRMIYORUZ; çağırsak da çalışmazdı:
      // `storage.rules` sohbet medyası için `allow update, delete: if
      // false;` diyor. Bu bir eksiklik değil, BİLİNÇLİ tasarım — kuralı
      // istemciye açmak, herhangi bir sohbet üyesinin başkasının
      // medyasını silebilmesi demek olurdu.
      //
      // Dosyayı, aşağıdaki `mediaUrl` temizliğini gören Cloud Function
      // siler (`cleanupSoftDeletedMedia`, ÜRETİMDE ETKİN):
      //     before.mediaUrl && !after.mediaUrl && after.viewOnce === true
      // Admin SDK kuralları atladığı için silme orada gerçekten olur.
      //
      // ⚠️ Eskiden burada başarısız olmaya mahkûm bir `delete()` denemesi
      // vardı, hatası `catch (_) {}` ile yutuluyordu ve yanındaki yorum
      // "gercekten sil" diyordu. Bu ölü kod, denetimde "tek gönderimlik
      // medya sunucuda kalıyor" diye YANLIŞ bir sonuca götürdü.
      // 2) Dokumanda mediaUrl'i temizle -> her iki tarafta "goruntulendi"
      await _messagesRef(chatId).doc(messageId).update({'mediaUrl': ''});
    } catch (e, s) {
      reportHandled('Görüntüleme tamamlanamadı', e, stack: s);
      throw const ServerException('err_view_once');
    }
  }

  @override
  Future<void> markAsRead(String chatId, String currentUserId) async {
    try {
      // HATA DUZELTME: Firestore AYNI SORGUDA iki farkli alanda esitsizlik
      // (isNotEqualTo) kabul etmez — eski sorgu calisma aninda patliyordu ve
      // okundu isaretleme sessizce basarisiz oluyordu. Tek esitsizlik +
      // istemci tarafinda filtre kullaniyoruz.
      // HIZ: tum koleksiyonu degil, yalnizca SON 50 mesaji oku
      // (esitsizlik+orderBy kisiti nedeniyle senderId filtresi istemcide).
      final docs = await _messagesRef(chatId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final batch = firestore.batch();
      var count = 0;
      for (final doc in docs.docs) {
        final data = doc.data();
        if (data['senderId'] == currentUserId) continue;
        final alreadyRead = data['status'] == MessageDeliveryStatus.read.name;
        final readBy = (data['readBy'] as List?)?.cast<String>() ?? const [];
        final inReadBy = readBy.contains(currentUserId);
        if (alreadyRead && inReadBy) continue;
        batch.update(doc.reference, {
          'status': MessageDeliveryStatus.read.name,
          // Grup "kimler okudu" icin okuyan listesine ekle
          'readBy': FieldValue.arrayUnion([currentUserId]),
        });
        count++;
        if (count >= 400) break; // Firestore batch limiti guvenligi (500)
      }
      if (count > 0) await batch.commit();
    } catch (e, s) {
      reportHandled('Okundu işaretlenemedi', e, stack: s);
      throw const ServerException('err_mark_read');
    }
  }

  @override
  Future<void> resetUnread(String chatId, String currentUserId) async {
    try {
      await firestore
          .collection('chats')
          .doc(chatId)
          .update({'unreadCounts.$currentUserId': 0});
    } catch (e, s) {
      reportHandled('Rozet sıfırlanamadı', e, stack: s);
      throw const ServerException('err_mark_read');
    }
  }

  @override
  Future<void> updateLastMessage(String chatId, String preview,
      {String? senderId}) async {
    try {
      final ref = firestore.collection('chats').doc(chatId);
      final update = <String, dynamic>{
        'lastMessage': preview,
        // UTC: yerel saat yazmak, farklı saat dilimlerindeki kullanıcılarda
        // sıralamayı bozuyordu (ISO dizeleri sözlükbilimsel karşılaştırılır
        // ve sohbet listesi bu alanla orderBy yapar).
        'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
        // Bildirim: kendi mesajimiza bildirim gostermemek icin gonderen kaydi
        if (senderId != null) 'lastMessageSenderId': senderId,
      };
      // OKUNMAMIS SAYACI: gonderen haric tum uyelerin sayacini artir
      // (rozet: sohbet listesinde yuvarlak icinde birikmis mesaj sayisi).
      if (senderId != null) {
        for (final uid in await memberIds(chatId)) {
          if (uid != senderId) {
            update['unreadCounts.$uid'] = FieldValue.increment(1);
          }
        }
      }
      await ref.update(update);
    } catch (e, s) {
      reportHandled('Son mesaj güncellenemedi', e, stack: s);
      throw const ServerException('err_server');
    }
  }

  @override
  Future<String> uploadMediaBytes(
      String chatId, Uint8List bytes, String subPath) async {
    try {
      final ref = storage.ref().child('chats/$chatId/$subPath');
      // İçerik türü BİLEREK 'application/octet-stream': şifreli baytlar
      // zaten görüntü değildir ve gerçek türü belirtmek sunucuya gereksiz
      // üst veri sızdırır.
      final task = ref.putData(
        bytes,
        SettableMetadata(contentType: 'application/octet-stream'),
      );
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          UploadProgress.instance
              .update(snap.bytesTransferred / snap.totalBytes);
        }
      });
      await task;
      UploadProgress.instance.finish();
      return await ref.getDownloadURL();
    } catch (e, s) {
      reportHandled('Şifreli medya yüklenemedi', e, stack: s);
      throw const ServerException('err_media_upload');
    }
  }

  @override
  Future<List<String>> memberIds(String chatId) async {
    // PERFORMANS: üye listesi 5 dk önbellekte tutulur; her mesaj
    // gönderiminde ekstra bir Firestore okuması yapılmaz.
    final cached = _memberCache[chatId];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 5)) {
      return cached.members;
    }
    try {
      final chat = await firestore.collection('chats').doc(chatId).get();
      final members =
          (chat.data()?['memberIds'] as List?)?.cast<String>() ?? const [];
      _memberCache[chatId] = _CachedMembers(members, DateTime.now());
      return members;
    } catch (e, s) {
      reportHandled('Üyeler alınamadı', e, stack: s);
      throw const ServerException('err_server');
    }
  }

  /// Üye önbelleğini geçersiz kıl (üye eklendi/çıkarıldı).
  ///
  /// Bayat üyelik, grup anahtarının YENİ üyeye dağıtılmamasına veya
  /// AYRILAN üyeye dağıtılmaya devam edilmesine yol açar — bu yüzden
  /// üyelik değişiminde çağrılması güvenlik açısından önemlidir.
  static void invalidateMemberCache(String chatId) =>
      _memberCache.remove(chatId);

  static void clearMemberCache() => _memberCache.clear();
}

class _CachedMembers {
  final List<String> members;
  final DateTime at;
  const _CachedMembers(this.members, this.at);
}
