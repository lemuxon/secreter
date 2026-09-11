import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/auth/current_user_provider.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/repositories/group_repository.dart';
import '../datasources/group_remote_datasource.dart';
import '../models/group_model.dart';
import '../../../messaging/data/datasources/message_remote_datasource.dart';
import '../../../../services/group_key_service.dart';
import '../../../../services/username_resolver.dart';
import '../../../../core/observability/app_logger.dart';
import '../../../../core/observability/handled_error.dart';
import '../../../../core/security/security_alerts.dart';

/// GroupRepository implementasyonu.
class GroupRepositoryImpl implements GroupRepository {
  final GroupRemoteDataSource remoteDataSource;
  final CurrentUserProvider userProvider;

  GroupRepositoryImpl({
    required this.remoteDataSource,
    required this.userProvider,
  });

  @override
  Stream<Either<Failure, GroupEntity>> watchGroup(String chatId) {
    return remoteDataSource
        .watchGroup(chatId)
        .asyncMap<Either<Failure, GroupEntity>>((group) async {
      // ── METADATA GİZLİLİĞİ (2. aşama) ──
      // Üye adları sohbet dokümanında tutulmuyor; üye listesi
      // çizilmeden ÖNCE uid'ler toplu çözülür ki
      // `GroupMemberEntity.displayName` senkron yolda hazır adı
      // bulsun (yoksa liste önce uid kısaltmalarıyla çizilirdi).
      await UsernameResolver.warm(group.members.map((m) => m.uid));
      return Right(group);
    }).handleError((Object error, StackTrace st) {
      reportHandled('watchGroup', error, stack: st);
      return const Left<Failure, GroupEntity>(ServerFailure());
    });
  }

  @override
  Future<Either<Failure, String>> getOrCreateInviteCode(String chatId) async {
    try {
      final group = await remoteDataSource.getGroup(chatId);
      if (group?.inviteCode != null) {
        return Right(group!.inviteCode!);
      }
      final code = remoteDataSource.generateInviteCode();
      await remoteDataSource.setInviteCode(chatId, code);
      return Right(code);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('getOrCreateInviteCode', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, String>> resetInviteCode(String chatId) async {
    try {
      final group = await remoteDataSource.getGroup(chatId);
      if (group?.inviteCode != null) {
        await remoteDataSource.deleteInviteCode(group!.inviteCode!);
      }
      final code = remoteDataSource.generateInviteCode();
      await remoteDataSource.setInviteCode(chatId, code);
      return Right(code);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('resetInviteCode', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, String>> joinByInviteCode(String code) async {
    try {
      // Yapıştırılan kodu temizle: boşluk, tire, satır sonu, görünmez
      // karakterler. Kod üreticisi YALNIZCA harf/rakam üretiyor
      // (`generateInviteCode`), yani atılan hiçbir karakter meşru olamaz.
      // Buluşma kodunda aynı eksik gerçek bir hataya yol açmıştı: uygulama
      // kendi kopyaladığı biçimi kabul etmiyordu (bkz. §4r).
      //
      // ⚠️ BÜYÜK/KÜÇÜK HARF DEĞİŞTİRİLMEZ — grup kodu alfabesi karışık
      // durumludur (`aB3x...`), harf durumunu bozmak kodu geçersiz yapardı.
      final clean = code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final chatId = await remoteDataSource.resolveInviteCode(clean);
      if (chatId == null) {
        return const Left(ValidationFailure('err_invite_invalid'));
      }

      final group = await remoteDataSource.getGroup(chatId);
      if (group == null) {
        return const Left(ValidationFailure('err_group_not_found'));
      }

      final myUid = userProvider.currentUid!;
      if (group.isBanned(myUid)) {
        return const Left(AuthFailure('err_banned_from_group'));
      }
      if (group.memberIds.contains(myUid)) {
        return Right(chatId); // Zaten üye
      }

      // Ad YAZILMAZ (§4o): üyelik yalnızca uid ile tutulur.
      final newMember = GroupMemberModel(
        uid: myUid,
        role: MemberRole.member,
        joinedAt: DateTime.now(),
      );

      // ⚠️ `arrayUnion` + `increment` KULLANILMAZ — üçünün idempotentlik
      // davranışı farklıydı ve hızlı iki dokunuş "bir üye, iki
      // `members` girdisi, sayaç 2 fazla" üretiyordu. Gerekçe:
      // `GroupRemoteDataSource.addMemberToArray` (§4an).
      await remoteDataSource.addMemberToArray(
        chatId,
        myUid,
        memberEntry: newMember.toMap(),
      );
      // Yeni üyeye grup anahtarının dağıtılabilmesi için üye listesi
      // önbelleği tazelenmeli (bayat liste = anahtarsız üye).
      MessageRemoteDataSourceImpl.invalidateMemberCache(chatId);

      return Right(chatId);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('joinByInviteCode', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setMemberRole({
    required String chatId,
    required GroupMemberEntity member,
    required MemberRole newRole,
  }) async {
    return _updateMemberInArray(chatId, member, {'role': newRole.name});
  }

  @override
  Future<Either<Failure, Unit>> setMemberMuted({
    required String chatId,
    required GroupMemberEntity member,
    required bool muted,
  }) async {
    return _updateMemberInArray(chatId, member, {'isMuted': muted});
  }

  @override
  Future<Either<Failure, Unit>> kickMember({
    required String chatId,
    required GroupMemberEntity member,
  }) async {
    return _removeMember(chatId, member, ban: false);
  }

  @override
  Future<Either<Failure, Unit>> banMember({
    required String chatId,
    required GroupMemberEntity member,
  }) async {
    return _removeMember(chatId, member, ban: true);
  }

  @override
  Future<Either<Failure, Unit>> updateGroupInfo({
    required String chatId,
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['groupName'] = name;
      if (description != null) data['description'] = description;
      if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
      if (data.isNotEmpty) {
        await remoteDataSource.updateGroup(chatId, data);
      }
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('updateGroupInfo', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setOnlyAdminsCanPost({
    required String chatId,
    required bool value,
  }) async {
    try {
      await remoteDataSource.updateGroup(chatId, {'onlyAdminsCanPost': value});
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('setOnlyAdminsCanPost', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, String>> createChannel({
    required String name,
    required String description,
  }) async {
    try {
      final myUid = userProvider.currentUid!;
      final chatId = remoteDataSource.newGroupId();

      final owner = GroupMemberModel(
        uid: myUid,
        role: MemberRole.owner,
        joinedAt: DateTime.now(),
      );

      final channel = GroupModel(
        id: chatId,
        type: GroupChatType.channel,
        memberIds: [myUid],
        groupName: name,
        description: description,
        adminId: myUid,
        members: [owner],
        onlyAdminsCanPost: true,
        memberCount: 1,
      );

      await remoteDataSource.createGroup(channel);
      return Right(chatId);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('createChannel', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, String>> createGroup({
    required String name,
    required List<({String uid, String username})> members,
  }) async {
    try {
      final myUid = userProvider.currentUid!;
      final chatId = remoteDataSource.newGroupId();

      // Owner (oluşturan) + seçili üyeler.
      // ── ADLAR SUNUCUYA GİTMEZ (§4o) ──
      // Çağıran adları biliyor (kullanıcı onları arayarak seçti); bu
      // bilgi YERELDE çözümleyiciye tohumlanır. Böylece grup ekranı
      // adları gösterirken tek bir ek okuma bile yapmaz, ama sohbet
      // dokümanına hiçbir ad yazılmaz.
      for (final m in members) {
        UsernameResolver.seed(m.uid, m.username);
      }

      final owner = GroupMemberModel(
        uid: myUid,
        role: MemberRole.owner,
        joinedAt: DateTime.now(),
      );
      final memberModels = members
          .map((m) => GroupMemberModel(
                uid: m.uid,
                role: MemberRole.member,
                joinedAt: DateTime.now(),
              ))
          .toList();

      final allMembers = [owner, ...memberModels];
      final memberIds = allMembers.map((m) => m.uid).toList();

      final group = GroupModel(
        id: chatId,
        type: GroupChatType.group,
        memberIds: memberIds,
        groupName: name,
        adminId: myUid,
        members: allMembers,
        onlyAdminsCanPost: false,
        memberCount: allMembers.length,
      );

      await remoteDataSource.createGroup(group);
      return Right(chatId);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('createGroup', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteGroup(String chatId) async {
    try {
      await remoteDataSource.deleteGroup(chatId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('deleteGroup', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> leaveGroup(String chatId) async {
    try {
      final myUid = userProvider.currentUid!;
      final group = await remoteDataSource.getGroup(chatId);
      if (group == null) {
        return const Left(ValidationFailure('err_group_not_found'));
      }

      // ── 🐞 AYRILIRKEN HANGİ ALANLARA DOKUNULABİLİR ──
      //
      // Kuraldaki `isSelfLeave()` yalnızca
      // ['memberIds','memberUsernames','members','memberCount']
      // değişimine izin verir. Eski kod `adminUids` ve `mutedUids` de
      // yazıyordu; `arrayRemove` bir şey çıkarmadığında dizi değişmediği
      // için çoğu durumda fark edilmiyordu — ama kişi GERÇEKTEN o
      // dizideyse alan değişir, `onlyChanges` düşer ve **ayrılma tamamen
      // reddedilir.** Yani SUSTURULMUŞ bir üye gruptan çıkamıyordu.
      // *Kural testi: "🐞 SUSTURULMUŞ üye ayrılırken mutedUids'e
      // DOKUNAMAZ".*
      //
      // `mutedUids`e hiç dokunulmuyor. Kalan girdi zararsızdır —
      // `canPost()` zaten üyelik de ister — ve ayrılıp yeniden katılarak
      // susturmadan KAÇILAMAMASI doğru davranıştır.
      // `adminUids` sunucuda TÜRETİLMİŞ düz dizidir (`_flatRoleFields`:
      // rol owner ya da admin). Domain'deki karşılığı `canModerate`,
      // `adminId` yedeğini de kapsar.
      final amAdmin = group.canModerate(myUid);
      final extra = <String, dynamic>{
        // Yönetici kendini `adminUids`ten ÇIKARMAK ZORUNDA: `isAdmin()`
        // üyelik değil yalnızca bu diziye bakar, yani kalırsa ayrıldığı
        // gruba yönetici olarak hükmetmeye devam eder. Bu yol kuralda
        // `isAdmin()` dalından geçtiği için izinlidir.
        if (amAdmin) 'adminUids': FieldValue.arrayRemove([myUid]),
      };

      await remoteDataSource.removeMemberFromArray(chatId, myUid, extra: extra);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('leaveGroup', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  /// Array içindeki bir üyeyi güncelle (sil + güncel hali ekle)
  ///
  /// ⚠️ DÜZ DİZİLER DE GÜNCELLENİR — bu bir kolaylık değil, GÜVENLİĞİN
  /// ÇALIŞMASI İÇİN ŞARTTIR.
  ///
  /// Firestore güvenlik kurallarında döngü yoktur: `members` dizisindeki
  /// nesnelerin `role`/`isMuted` alanları kural tarafından OKUNAMAZ. Bu
  /// yüzden rol ve susturma bilgisi ayrıca düz `adminUids` / `mutedUids`
  /// dizilerinde tutulur ve kurallar bunları kullanır. Bu diziler
  /// yazılmazsa susturma ve "yalnızca yöneticiler gönderebilir" ayarı
  /// sunucuda HİÇ uygulanmaz (sadece arayüzde görünür) — değiştirilmiş
  /// bir istemci ikisini de kolayca aşar.
  /// ⚠️ DEĞİŞİKLİK **UID ile** ve İŞLEM içinde uygulanır.
  ///
  /// Eskiden diziyi okuyup tamamını geri yazıyordu ve arada işlem
  /// yoktu: okuma ile yazma arasında biri gruba katılırsa, geri
  /// yazılan liste onu içermediği için **yeni üye siliniyordu**
  /// (`memberIds`te durur, `members`ten düşerdi). §4ak'de kapatılan
  /// tutarsızlığın ekleme yarışıyla oluşan hâli — gerekçe:
  /// `GroupRemoteDataSource.updateMemberFields` (§4an).
  Future<Either<Failure, Unit>> _updateMemberInArray(
    String chatId,
    GroupMemberEntity member,
    Map<String, dynamic> changes,
  ) async {
    try {
      final bulundu = await remoteDataSource.updateMemberFields(
          chatId, member.uid, changes);
      if (!bulundu) {
        // `memberIds` ile `members` ayrışmış: kişi üye ama dizide
        // girdisi yok. Uydurma bir girdi yazmak (özellikle `joinedAt`)
        // veriyi kirletir; sessiz kalmak da §4ah'nin ölçütünü ihlal
        // eder — kullanıcı rolü değiştirdiğini sanır, değişmemiştir.
        reportHandled(
            'Üye `members` dizisinde bulunamadı — rol/susturma '
            'uygulanmadı',
            StateError('member_entry_missing'),
            context: {'sohbet': Redact.id(chatId)});
        return const Left(ValidationFailure('err_group_update'));
      }
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('_updateMemberInArray', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  /// Üyelik değiştikten sonra çalışır.
  ///
  /// ── NEDEN GRUP ANAHTARI ROTASYONA GİRMELİ ──
  /// Grup mesajları "sender key" ile uçtan uca şifrelenir ve her üye bu
  /// anahtarın bir kopyasına sahiptir. Ayrılan/atılan bir üye anahtarı
  /// BİLDİĞİ için, rotasyon olmadan gruptan çıktıktan SONRAKİ mesajları da
  /// çözebilirdi. Rotasyon, ileri gizliliği (forward secrecy) üyelik
  /// sınırında da korur.
  ///
  /// Ayrıca üye önbelleği geçersiz kılınır: bayat liste, yeni üyeye
  /// anahtarın hiç dağıtılmamasına yol açar.
  ///
  /// ⚠️ BU YALNIZCA BU CİHAZIN ZİNCİRİNİ YENİLER. Her üyenin ayrı bir
  /// gönderen zinciri vardır; diğer üyelerin zincirleri, kendi
  /// cihazlarında `GroupKeyService.syncMembership` ile — bir sonraki
  /// gönderimden hemen önce — rotasyona girer. Buradaki çağrı, ATAN
  /// kişinin zincirini beklemeden yenilemek içindir.
  Future<void> _afterMembershipChange(String chatId) async {
    try {
      MessageRemoteDataSourceImpl.invalidateMemberCache(chatId);
      await GroupKeyService.rotate(chatId);
      // Önceki bir başarısızlık varsa artık geçerli değil.
      await SecurityAlerts.setGroupKeyRotationFailed(chatId, false);
    } catch (e, s) {
      // ⚠️ İLERİ GİZLİLİK SESSİZCE BOZULUR: rotasyon başarısız olursa
      // gruptan ATILAN üye eski anahtarla SONRAKİ mesajları da
      // çözebilir. Kullanıcı arayüzde her şeyin yolunda olduğunu görür.
      reportHandled('Grup anahtarı rotasyonu başarısız', e,
          stack: s, context: {'sohbet': Redact.id(chatId)});
      // ⚠️ BUNU BİLMESİ GEREKEN KİŞİ KULLANICI.
      // Telemetriye yazmak geliştiriciyi haberdar eder ama kullanıcı
      // "onu attım, artık okuyamaz" sanmaya devam eder — yanlış bir
      // güvenlik hissi. Sohbet ekranı bu bayrağı uyarı bandı olarak
      // gösterir ve tekrar deneme sunar.
      await SecurityAlerts.setGroupKeyRotationFailed(chatId, true);
    }
  }

  // ⚠️ `_flatRoleFields` BURADAN KALDIRILDI (§4an).
  // Türetme artık `GroupRemoteDataSourceImpl.flatRoleFields` içinde,
  // işlemin okuduğu HAM haritalar üzerinde yapılıyor. Burada bir kopya
  // bırakmak, aynı diziyi iki yerde hesaplamak olurdu — kural motoru
  // `adminUids`e baktığı için ayrışma doğrudan yetki hatası demektir
  // (§4u/§4aj'nin dersi).

  Future<Either<Failure, Unit>> _removeMember(
    String chatId,
    GroupMemberEntity member, {
    required bool ban,
  }) async {
    try {
      // ⚠️ ÜYE **UID İLE** ÇIKARILIR — birebir harita eşleşmesiyle değil.
      // Eskiden `arrayRemove([memberModel.toMap()])` kullanılıyordu ve
      // harita arayüzün anlık görüntüsünden kuruluyordu: rol, susturma
      // ya da eski ad araya giren bir değişiklikle kaymışsa eşleşme
      // bozulur, `members` dizisi olduğu gibi kalır ve atılan kişi
      // listede görünmeye devam ederdi — hatasız. Gerekçe:
      // `GroupRemoteDataSource.removeMemberFromArray` (§4ak).
      final extra = <String, dynamic>{
        // Kuralların okuduğu düz dizilerden de çıkar; aksi halde atılan
        // bir yönetici sunucuda yönetici sayılmaya devam ederdi
        // (`isAdmin()` üyelik değil YALNIZCA `adminUids`e bakar).
        'adminUids': FieldValue.arrayRemove([member.uid]),
        'mutedUids': FieldValue.arrayRemove([member.uid]),
        if (ban) 'bannedIds': FieldValue.arrayUnion([member.uid]),
      };

      await remoteDataSource.removeMemberFromArray(chatId, member.uid,
          extra: extra);
      await _afterMembershipChange(chatId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('_removeMember', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }
}
