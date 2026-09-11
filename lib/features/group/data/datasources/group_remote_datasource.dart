import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/exceptions.dart';
import '../models/group_model.dart';
import '../../../../core/observability/handled_error.dart';
import '../../../../services/auth_service.dart';

/// Grup/kanal uzak veri kaynağı.
abstract class GroupRemoteDataSource {
  Stream<GroupModel> watchGroup(String chatId);
  Future<GroupModel?> getGroup(String chatId);
  Future<void> updateGroup(String chatId, Map<String, dynamic> data);

  /// Üyeyi `members` dizisinden **UID ile** çıkar (işlem içinde).
  ///
  /// Dönüş: çıkarma sonrası kalan üye sayısı; üye zaten yoksa `null`.
  /// [extra] ile aynı işleme ek alanlar yazılabilir (yasak, yönetici
  /// dizisi vb.).
  Future<int?> removeMemberFromArray(
    String chatId,
    String uid, {
    Map<String, dynamic> extra = const {},
  });

  /// Üyeyi **UID ile** ekle (işlem içinde, idempotent).
  ///
  /// [memberEntry] verilirse `members` dizisine de eklenir — ama
  /// yalnızca o uid'e ait girdi YOKSA. Dönüş: işlem sonrası üye sayısı.
  Future<int> addMemberToArray(
    String chatId,
    String uid, {
    Map<String, dynamic>? memberEntry,
  });

  /// Bir üyenin `members` girdisindeki alanları **UID ile** güncelle
  /// (işlem içinde). Kuralların okuduğu düz diziler yeniden türetilir.
  ///
  /// Dönüş: girdi bulunup güncellendiyse `true`.
  Future<bool> updateMemberFields(
    String chatId,
    String uid,
    Map<String, dynamic> changes,
  );

  /// Açık kanala kendini ekle — OKUMASIZ (§4bn).
  ///
  /// `addMemberToArray` işlem içinde önce `tx.get` yapar; kural üye
  /// olmayanın sohbet dokümanını OKUMASINA izin vermediği için katılma
  /// daha yazmaya gelmeden reddediliyordu.
  Future<void> joinChannel(String chatId);

  Future<void> setInviteCode(String chatId, String code);
  Future<void> deleteInviteCode(String code);
  Future<String?> resolveInviteCode(String code);
  Future<void> createGroup(GroupModel group);
  Future<void> deleteGroup(String chatId);
  String newGroupId();
  String generateInviteCode();
}

class GroupRemoteDataSourceImpl implements GroupRemoteDataSource {
  final FirebaseFirestore firestore;
  GroupRemoteDataSourceImpl({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _chats =>
      firestore.collection('chats');
  CollectionReference<Map<String, dynamic>> get _invites =>
      firestore.collection('inviteCodes');

  @override
  Stream<GroupModel> watchGroup(String chatId) {
    try {
      return _chats
          .doc(chatId)
          .snapshots()
          .map((doc) => GroupModel.fromMap(doc.data() ?? {}));
    } catch (e, s) {
      reportHandled('Grup dinlenemedi', e, stack: s);
      throw const ServerException('err_group_load');
    }
  }

  @override
  Future<GroupModel?> getGroup(String chatId) async {
    try {
      final doc = await _chats.doc(chatId).get();
      if (!doc.exists) return null;
      return GroupModel.fromMap(doc.data()!);
    } catch (e, s) {
      reportHandled('Grup alınamadı', e, stack: s);
      throw const ServerException('err_group_load');
    }
  }

  @override
  Future<void> updateGroup(String chatId, Map<String, dynamic> data) async {
    try {
      await _chats.doc(chatId).update(data);
    } catch (e, s) {
      reportHandled('Grup güncellenemedi', e, stack: s);
      throw const ServerException('err_group_update');
    }
  }

  /// 🐞 NEDEN `arrayRemove` DEĞİL DE İŞLEM (§4ak)
  ///
  /// Üye çıkarma şöyleydi:
  ///
  /// ```dart
  /// 'members': FieldValue.arrayRemove([memberModel.toMap()])
  /// ```
  ///
  /// Firestore dizi elemanını **birebir** karşılaştırır: `uid`, `role`,
  /// `isMuted`, `joinedAt` ve (eski girdilerde) `username` — hepsi
  /// tutmak zorunda. Harita arayüzün elindeki anlık görüntüden
  /// kuruluyordu, yani araya giren HERHANGİ bir değişiklik (başka bir
  /// yönetici o kişiyi terfi ettirdi, susturdu ya da girdi eski adıyla
  /// duruyor) eşleşmeyi bozardı.
  ///
  /// Bozulunca ne olur: `memberIds`, `adminUids`, `mutedUids` ve
  /// `memberCount` güncellenir ama **`members` dizisi olduğu gibi
  /// kalır.** Atılan kişi grup bilgisi ekranında görünmeye devam eder,
  /// sayaç listeyle tutmaz — ve **hiçbir hata çıkmaz.**
  ///
  /// Kimlik `uid`dir; eşleşme de ona göre yapılmalı. İşlem kullanılıyor
  /// çünkü diziyi okuyup geri yazmak, `arrayRemove`un atomikliğini
  /// kaybettirir: eşzamanlı bir katılma sessizce ezilirdi.
  ///
  /// Ayrıca `memberCount` **artırım değil, gerçek uzunluk** olarak
  /// yazılır — daha önce kaymışsa kendini onarır.
  @override
  Future<int?> removeMemberFromArray(
    String chatId,
    String uid, {
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      return await firestore.runTransaction<int?>((tx) async {
        final ref = _chats.doc(chatId);
        final snap = await tx.get(ref);
        if (!snap.exists) return null;

        final raw = (snap.data()?['members'] as List?) ?? const [];
        final kalan = raw
            .whereType<Map>()
            .where((m) => (m['uid'] ?? '').toString() != uid)
            .map((m) => Map<String, dynamic>.from(m)
              // ── ESKİ ADLARI DA TEMİZLE (`DEVAM.md` §3b/7) ──
              // 2. aşamadan (§4o) önce yazılmış girdiler `username`
              // taşımaya devam ediyordu: yeni üyeler adsız yazılıyor
              // ama eskiler yerinde kalıyordu. Toplu temizlik o zaman
              // BİLEREK yapılmamıştı, çünkü `arrayRemove` birebir
              // eşleşme istiyordu ve adı silmek üye çıkarmayı sessizce
              // kırardı. Çıkarma artık uid ile yapıldığı için o engel
              // yok; dizi zaten yeniden yazılıyorken adlar da düşer.
              ..remove('username'))
            .toList();

        if (kalan.length == raw.length) {
          // Üye `members` içinde yok. Yine de diğer alanlar yazılmalı:
          // dizi ile `memberIds` daha önce ayrışmış olabilir ve bu
          // çağrı tam da onu düzeltiyor olabilir.
          tx.update(ref, {
            'memberIds': FieldValue.arrayRemove([uid]),
            ...extra,
          });
          return null;
        }

        tx.update(ref, {
          'memberIds': FieldValue.arrayRemove([uid]),
          'members': kalan,
          'memberCount': kalan.length,
          ...extra,
        });
        return kalan.length;
      });
    } catch (e, s) {
      reportHandled('Üye çıkarılamadı', e, stack: s);
      throw const ServerException('err_group_update');
    }
  }

  /// Kuralların okuduğu DÜZ dizileri `members`ten türet.
  ///
  /// ⚠️ TEK YER. Bu türetme bir zamanlar repository'de (varlıklar
  /// üzerinde) yapılıyordu; işlem içinde ham haritalarla çalışmak
  /// gerekince ikinci bir kopya çıkacaktı. Aynı diziyi iki yerde
  /// hesaplamak, bu projenin defalarca bedelini ödediği desendir
  /// (§4u, §4aj) — kural motoru `adminUids`e bakıyor, yani ayrışma
  /// doğrudan yetki hatası demek.
  static Map<String, dynamic> flatRoleFields(
      List<Map<String, dynamic>> members) {
    final admins = <String>[];
    final muted = <String>[];
    for (final m in members) {
      final uid = (m['uid'] ?? '').toString();
      if (uid.isEmpty) continue;
      final role = (m['role'] ?? '').toString();
      if (role == 'owner' || role == 'admin') admins.add(uid);
      if (m['isMuted'] == true) muted.add(uid);
    }
    return {'adminUids': admins, 'mutedUids': muted};
  }

  static List<Map<String, dynamic>> _readMembers(Map<String, dynamic>? data) =>
      ((data?['members'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  /// 🐞 NEDEN `arrayUnion` DEĞİL DE İŞLEM (§4an)
  ///
  /// Katılma şöyleydi:
  ///
  /// ```dart
  /// 'memberIds': FieldValue.arrayUnion([myUid]),
  /// 'members':   FieldValue.arrayUnion([newMember.toMap()]),
  /// 'memberCount': FieldValue.increment(1),
  /// ```
  ///
  /// Üç işlemin **idempotentlik davranışı farklıydı** ve bu fark
  /// sessizce tutarsızlık üretiyordu:
  ///
  /// * `memberIds` arrayUnion → idempotent (aynı uid iki kez eklenmez)
  /// * `members` arrayUnion → **idempotent DEĞİL**: harita
  ///   `joinedAt: DateTime.now()` taşıyor, yani ikinci çağrıda farklı
  ///   bir eleman olur ve **aynı kişi listede iki kez** görünür
  /// * `memberCount` increment → **idempotent DEĞİL**: iki kez artar
  ///
  /// "Zaten üye mi" kontrolü vardı ama okuma ile yazma arasında
  /// yapılıyordu; hızlı iki dokunuş ya da bir yeniden deneme aradan
  /// geçiyordu. Sonuç: bir üye, iki `members` girdisi ve sayaç 2 fazla.
  ///
  /// İşlem hem yarışı kapatır hem de `memberCount`u **gerçek uzunluğa**
  /// yazar — daha önce kaymışsa kendini onarır (§4ak'deki çıkarma
  /// yoluyla aynı ilke).
  @override
  Future<int> addMemberToArray(
    String chatId,
    String uid, {
    Map<String, dynamic>? memberEntry,
  }) async {
    try {
      return await firestore.runTransaction<int>((tx) async {
        final ref = _chats.doc(chatId);
        final snap = await tx.get(ref);
        if (!snap.exists) throw const ServerException('err_group_not_found');

        final data = snap.data() ?? {};
        final ids = ((data['memberIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();

        // ⚠️ ZATEN ÜYEYSE HİÇ YAZMA.
        //
        // İki sebep, ikisi de gerçek:
        //  1. Sayaç kayması buradan geliyordu. Kanal aramasında zaten
        //     üye olunan bir kanala dokunmak `increment(1)` çalıştırıyor
        //     ve `memberCount` her dokunuşta bir artıyordu — kod bunu
        //     "kural gereği geçer" diye NORMAL sayıyordu.
        //  2. Kural `isSelfJoin()` eklenen kümenin TAM OLARAK {ben}
        //     olmasını istiyor. Zaten üyeyken yazmak, eklenen küme boş
        //     olduğu için `permission-denied` ile REDDEDİLİRDİ — ve
        //     kanal ekranı o hatayı "bu kanaldan yasaklısın" diye
        //     gösteriyor. Yani yazmak yalnızca gereksiz değil,
        //     YANILTICI bir hata üretirdi.
        if (ids.contains(uid)) return ids.length;

        ids.add(uid);
        final update = <String, dynamic>{
          'memberIds': ids,
          'memberCount': ids.length,
        };

        if (memberEntry != null) {
          final members = _readMembers(data);
          final zatenVar =
              members.any((m) => (m['uid'] ?? '').toString() == uid);
          if (!zatenVar) {
            members.add(memberEntry);
            update['members'] = members;
          }
        }

        tx.update(ref, update);
        return ids.length;
      });
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      // ⚠️ `permission-denied` OLDUĞU GİBİ GEÇER — sarmalanmaz.
      // Kanal katılmasında bu kodun tek meşru sebebi YASAKLI olmaktır
      // (`isSelfJoin()` → `!(uid in bannedIds)`), ve kanal ekranı buna
      // bakıp kullanıcıya doğru mesajı gösteriyor. Genel bir
      // `ServerException`a çevirmek o ayrımı yok eder ve kullanıcı
      // "bir şeyler ters gitti" görürdü.
      if (e.code == 'permission-denied') rethrow;
      reportHandled('Üye eklenemedi', e);
      throw const ServerException('err_group_update');
    } catch (e, s) {
      reportHandled('Üye eklenemedi', e, stack: s);
      throw const ServerException('err_group_update');
    }
  }

  /// 🐞 NEDEN İŞLEM (§4an)
  ///
  /// Rol/susturma değişimi diziyi okuyup **tamamını** geri yazıyordu ve
  /// arada işlem yoktu. Okuma ile yazma arasında biri gruba katılırsa,
  /// geri yazılan liste onu içermediği için **yeni üye silinirdi** —
  /// `memberIds`te durur, `members`ten düşerdi. §4ak'de kapatılan
  /// tutarsızlığın aynısı, bu sefer ekleme yarışıyla.
  @override
  Future<bool> updateMemberFields(
    String chatId,
    String uid,
    Map<String, dynamic> changes,
  ) async {
    try {
      return await firestore.runTransaction<bool>((tx) async {
        final ref = _chats.doc(chatId);
        final snap = await tx.get(ref);
        if (!snap.exists) return false;

        final members = _readMembers(snap.data());
        var bulundu = false;
        for (final m in members) {
          if ((m['uid'] ?? '').toString() == uid) {
            m.addAll(changes);
            bulundu = true;
            break;
          }
        }
        if (!bulundu) return false;

        tx.update(ref, {
          'members': members,
          ...flatRoleFields(members),
        });
        return true;
      });
    } catch (e, s) {
      reportHandled('Üye güncellenemedi', e, stack: s);
      throw const ServerException('err_group_update');
    }
  }

  @override
  Future<void> joinChannel(String chatId) async {
    // ── NEDEN OKUMASIZ ──
    //
    // 🐞 GERÇEK KULLANICIDA GÖRÜLDÜ: yeni kurulan bir kanala arama
    // üzerinden katılmaya çalışan herkes *"bu kanaldan yasaklandınız"*
    // alıyordu. Gerçekte kimse yasaklı değildi.
    //
    // Sebep: `addMemberToArray` bir işlem içinde önce `tx.get(ref)`
    // yapıyor. Kural ise:
    //
    //     allow get: if signedIn() && request.auth.uid in
    //                   resource.data.memberIds;
    //
    // Yani üye OLMAYAN katılma dokümanı okuyamaz ve istek yazmaya
    // gelmeden `permission-denied` alır. Kanal ekranı bu kodu
    // "yasaklısın" diye yorumladığı için hata YANILTICIYDI.
    //
    // Okuma kısıtı bilinçli (§4o: üye olmayan kanalın üye listesini ve
    // son mesajını görmesin) — o yüzden kuralı gevşetmek yerine
    // istemciyi okumasız hâle getiriyoruz. `arrayUnion` zaten
    // idempotenttir; sayaç da `increment` ile gider. Kuralın
    // `isSelfJoin()` şartları bu iki alanla tam olarak karşılanır.
    final uid = AuthService.currentUid;
    if (uid == null) throw const ServerException('err_session_missing');
    try {
      await _chats.doc(chatId).update({
        'memberIds': FieldValue.arrayUnion([uid]),
        'memberCount': FieldValue.increment(1),
      });
    } on FirebaseException catch (e) {
      // ⚠️ `permission-denied` burada ARTIK tek anlamlı değil:
      // yasaklı olmak DA, zaten üye olmak DA bu kodu üretir (ikinci
      // durumda eklenen küme boş kalır ve `isSelfJoin()` tutmaz).
      // Ayrımı çağıran katman yapar; burada olduğu gibi geçer.
      if (e.code == 'permission-denied') rethrow;
      reportHandled('Kanala katılınamadı', e);
      throw const ServerException('err_group_update');
    }
  }

  @override
  Future<void> setInviteCode(String chatId, String code) async {
    try {
      await _chats.doc(chatId).update({'inviteCode': code});

      // ⚠️ `ownerUid` ZORUNLUDUR — kural onsuz REDDEDER (§4bm).
      //
      // 🐞 GERÇEK KULLANICIDA GÖRÜLDÜ: grup ya da kanal kurulurken
      // "Davet kodu işlenemedi" hatası. Sebep, kod ile kuralın
      // uyuşmamasıydı:
      //
      //     allow create: if signedIn() && !exists(...)
      //       && request.resource.data.ownerUid == request.auth.uid;
      //
      // Buradan yalnızca `chatId` yazılıyordu; `ownerUid` null kalınca
      // eşitlik tutmuyor ve yazma `permission-denied` alıyordu. Kural
      // doğruydu (sahibi olmayan kod silinemesin diye kondu), eksik olan
      // istemciydi.
      //
      // Sahiplik alanı, `deleteInviteCode`'un da şartı: onsuz yazılan
      // eski kodlar SİLİNEMEZ ve yetim kalır.
      final sahip = AuthService.currentUid;
      if (sahip == null) throw const ServerException('err_session_missing');

      await _invites.doc(code).set({
        'chatId': chatId,
        'ownerUid': sahip,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, s) {
      reportHandled('Davet kodu ayarlanamadı', e, stack: s);
      throw const ServerException('err_invite_code');
    }
  }

  @override
  Future<void> deleteInviteCode(String code) async {
    try {
      await _invites.doc(code).delete();
    } catch (e, s) {
      reportHandled('Davet kodu silinemedi', e, stack: s);
      throw const ServerException('err_invite_code');
    }
  }

  @override
  Future<String?> resolveInviteCode(String code) async {
    try {
      final doc = await _invites.doc(code).get();
      if (!doc.exists) return null;
      return doc.data()!['chatId'] as String?;
    } catch (e, s) {
      reportHandled('Davet kodu çözülemedi', e, stack: s);
      throw const ServerException('err_invite_code');
    }
  }

  @override
  Future<void> deleteGroup(String chatId) async {
    try {
      // Once mesajlari toplu sil (Firestore alt koleksiyonu otomatik silmez),
      // sonra sohbet belgesini kaldir.
      final msgs = await _chats.doc(chatId).collection('messages').get();
      const chunk = 400; // batch limiti (500) guvenligi
      for (var i = 0; i < msgs.docs.length; i += chunk) {
        final batch = firestore.batch();
        for (final d in msgs.docs.skip(i).take(chunk)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
      await _chats.doc(chatId).delete();
    } catch (e, s) {
      reportHandled('Grup silinemedi', e, stack: s);
      throw const ServerException('err_group_delete');
    }
  }

  @override
  Future<void> createGroup(GroupModel group) async {
    try {
      await _chats.doc(group.id).set(group.toMap());
    } catch (e, s) {
      reportHandled('Grup oluşturulamadı', e, stack: s);
      throw const ServerException('err_group_create');
    }
  }

  @override
  String newGroupId() => _chats.doc().id;

  @override
  String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
