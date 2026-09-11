import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gizli_chat/core/auth/current_user_provider.dart';
import 'package:gizli_chat/features/group/data/datasources/group_remote_datasource.dart';
import 'package:gizli_chat/features/group/data/models/group_model.dart';
import 'package:gizli_chat/features/group/data/repositories/group_repository_impl.dart';
import 'package:gizli_chat/features/group/domain/entities/group_entity.dart';

class _MockGroupDs extends Mock implements GroupRemoteDataSource {}

class _MockUser extends Mock implements CurrentUserProvider {}

/// 🐞 ÜYE ÇIKARMA — BİREBİR HARİTA EŞLEŞMESİ SESSİZCE BOZULUYORDU
///
/// Çıkarma şöyle yapılıyordu:
///
/// ```dart
/// 'members': FieldValue.arrayRemove([memberModel.toMap()])
/// ```
///
/// Firestore dizi elemanını **birebir** karşılaştırır: `uid`, `role`,
/// `isMuted`, `joinedAt` ve eski girdilerde `username` — hepsi tutmak
/// zorunda. Harita ise arayüzün elindeki anlık görüntüden kuruluyordu.
/// Araya giren herhangi bir değişiklik (başka bir yönetici o kişiyi
/// terfi ettirdi ya da susturdu, girdi eski adıyla duruyor) eşleşmeyi
/// bozar; `memberIds`/`adminUids`/`memberCount` güncellenir ama
/// **`members` dizisi olduğu gibi kalır.** Atılan kişi grup bilgisi
/// ekranında görünmeye devam eder ve **hiçbir hata çıkmaz.**
///
/// `DEVAM.md` §6 bu yüzden "üye atma" için elle test istiyordu.
/// §4ak çıkarmayı **uid ile** yapan bir işleme taşıdı.
GroupMemberModel _member({
  String uid = 'uid-bob',
  String username = '',
  MemberRole role = MemberRole.member,
  bool isMuted = false,
}) =>
    GroupMemberModel(
      uid: uid,
      username: username,
      role: role,
      isMuted: isMuted,
      joinedAt: DateTime.utc(2026, 9),
    );

GroupModel _group({
  List<GroupMemberModel>? members,
  String adminId = 'uid-alice',
}) =>
    GroupModel(
      id: 'g1',
      type: GroupChatType.group,
      memberIds: const ['uid-alice', 'uid-bob'],
      groupName: 'Ekip',
      adminId: adminId,
      members: members ??
          [
            _member(uid: 'uid-alice', role: MemberRole.owner),
            _member(uid: 'uid-bob'),
          ],
      memberCount: 2,
    );

void main() {
  // `_afterMembershipChange` grup anahtarı rotasyonunu tetikliyor ve o
  // da güvenli depoya iniyor; binding olmadan gürültülü uyarı basar.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockGroupDs ds;
  late _MockUser user;
  late GroupRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    ds = _MockGroupDs();
    user = _MockUser();
    repo = GroupRepositoryImpl(remoteDataSource: ds, userProvider: user);

    when(() => user.currentUid).thenReturn('uid-alice');
    when(() =>
            ds.removeMemberFromArray(any(), any(), extra: any(named: 'extra')))
        .thenAnswer((_) async => 1);
    when(() => ds.updateGroup(any(), any())).thenAnswer((_) async {});
    when(() => ds.getGroup(any())).thenAnswer((_) async => _group());
    when(() => ds.addMemberToArray(any(), any(),
        memberEntry: any(named: 'memberEntry'))).thenAnswer((_) async => 3);
    when(() => ds.updateMemberFields(any(), any(), any()))
        .thenAnswer((_) async => true);
    when(() => ds.resolveInviteCode(any())).thenAnswer((_) async => 'g1');
  });

  group('üye çıkarma UID ile yapılır', () {
    test('kickMember uid geçer, HARİTA eşleşmesi kullanmaz', () async {
      await repo.kickMember(chatId: 'g1', member: _member());

      verify(() => ds.removeMemberFromArray('g1', 'uid-bob',
          extra: any(named: 'extra'))).called(1);
    });

    test('🔒 arayüzdeki anlık görüntü BAYAT olsa da aynı çağrı yapılır',
        () async {
      // ⚠️ ASIL REGRESYON KORUMASI. Bu üye sunucuda terfi etmiş,
      // susturulmuş ve eski adıyla duruyor olabilir; eski kod bu
      // haritayı birebir arayıp EŞLEŞTİREMEZDİ. Kimlik `uid`dir.
      await repo.kickMember(
        chatId: 'g1',
        member: _member(
          username: 'bayat_ad',
          role: MemberRole.admin,
          isMuted: true,
        ),
      );

      verify(() => ds.removeMemberFromArray('g1', 'uid-bob',
          extra: any(named: 'extra'))).called(1);
    });

    test('düz diziler de temizlenir (atılan yönetici yönetici kalmasın)',
        () async {
      // `isAdmin()` kuralı ÜYELİĞE değil yalnızca `adminUids`e bakar.
      await repo.kickMember(chatId: 'g1', member: _member());

      final extra = verify(() => ds.removeMemberFromArray('g1', 'uid-bob',
          extra: captureAny(named: 'extra'))).captured.single as Map;
      expect(extra.containsKey('adminUids'), isTrue);
      expect(extra.containsKey('mutedUids'), isTrue);
      expect(extra.containsKey('bannedIds'), isFalse);
    });

    test('banMember ayrıca bannedIds yazar', () async {
      await repo.banMember(chatId: 'g1', member: _member());

      final extra = verify(() => ds.removeMemberFromArray('g1', 'uid-bob',
          extra: captureAny(named: 'extra'))).captured.single as Map;
      expect(extra.containsKey('bannedIds'), isTrue);
    });
  });

  group('gruptan ayrılma — kuralın izin verdiği alanlar', () {
    test('🐞 SUSTURULMUŞ üye ayrılırken mutedUids YAZILMAZ', () async {
      // Kuraldaki `isSelfLeave()` yalnızca
      // ['memberIds','memberUsernames','members','memberCount'] izin
      // verir. `mutedUids` GERÇEKTEN değişirse `onlyChanges` düşer ve
      // ayrılma tamamen reddedilir — susturulmuş üye gruba kilitlenir.
      // *Kural testi: "🐞 SUSTURULMUŞ üye ayrılırken mutedUids'e
      // DOKUNAMAZ".*
      when(() => user.currentUid).thenReturn('uid-bob');
      when(() => ds.getGroup(any())).thenAnswer((_) async => _group(members: [
            _member(uid: 'uid-alice', role: MemberRole.owner),
            _member(uid: 'uid-bob', isMuted: true),
          ]));

      await repo.leaveGroup('g1');

      final extra = verify(() => ds.removeMemberFromArray('g1', 'uid-bob',
          extra: captureAny(named: 'extra'))).captured.single as Map;
      expect(extra.containsKey('mutedUids'), isFalse,
          reason: 'mutedUids yazılırsa ayrılma REDDEDİLİR');
    });

    test('sıradan üye ayrılırken adminUids de YAZMAZ', () async {
      when(() => user.currentUid).thenReturn('uid-bob');

      await repo.leaveGroup('g1');

      final extra = verify(() => ds.removeMemberFromArray('g1', 'uid-bob',
          extra: captureAny(named: 'extra'))).captured.single as Map;
      expect(extra, isEmpty);
    });

    test('🔒 YÖNETİCİ ayrılırken adminUids\'ten ÇIKARILIR', () async {
      // ⚠️ Kalırsa ayrıldığı gruba yönetici olarak hükmetmeye devam
      // eder: `isAdmin()` üyelik denetimi yapmıyor.
      when(() => user.currentUid).thenReturn('uid-alice');

      await repo.leaveGroup('g1');

      final extra = verify(() => ds.removeMemberFromArray('g1', 'uid-alice',
          extra: captureAny(named: 'extra'))).captured.single as Map;
      expect(extra['adminUids'], isA<FieldValue>());
    });
  });

  /// 🐞 §4an — KATILMA VE ROL DEĞİŞİMİ DE İŞLEME TAŞINDI
  ///
  /// Üye ÇIKARMA §4ak'de uid'e taşınmıştı; aynı sınıftaki iki yol
  /// açıkta kalmıştı:
  ///
  ///  • Katılma `arrayUnion` + `increment` kullanıyordu ve üçünün
  ///    idempotentliği FARKLIYDI: `memberIds` idempotent, `members`
  ///    değil (`joinedAt: now` her çağrıda farklı harita üretir),
  ///    `memberCount` değil. Hızlı iki dokunuş → bir üye, İKİ girdi,
  ///    sayaç 2 fazla.
  ///  • Rol/susturma diziyi okuyup tamamını geri yazıyordu, işlem yok:
  ///    arada katılan biri geri yazmada SİLİNİRDİ.
  group('katılma ve rol değişimi işleme taşındı (§4an)', () {
    test('katılma `arrayUnion`/`increment` DEĞİL, işlem kullanır', () async {
      // Katılan kişi HENÜZ ÜYE OLMAMALI; fixture'daki uid'ler zaten
      // üye olduğu için `joinByInviteCode` erken döner ve test
      // yanlışlıkla hiçbir şey ölçmez.
      when(() => user.currentUid).thenReturn('uid-yeni');

      await repo.joinByInviteCode('kod123');

      verify(() => ds.addMemberToArray('g1', 'uid-yeni',
          memberEntry: any(named: 'memberEntry'))).called(1);
      // Eski yol tamamen terk edilmeli: ham `updateGroup` ile üyelik
      // yazılırsa idempotentlik farkı geri gelir.
      verifyNever(() => ds.updateGroup(any(), any()));
    });

    test('rol değişimi UID + alan haritasıyla işleme gider', () async {
      await repo.setMemberRole(
          chatId: 'g1', member: _member(), newRole: MemberRole.admin);

      final degisiklik =
          verify(() => ds.updateMemberFields('g1', 'uid-bob', captureAny()))
              .captured
              .single as Map;
      expect(degisiklik, {'role': 'admin'});
      verifyNever(() => ds.updateGroup(any(), any()));
    });

    test('susturma UID + alan haritasıyla işleme gider', () async {
      await repo.setMemberMuted(chatId: 'g1', member: _member(), muted: true);

      final degisiklik =
          verify(() => ds.updateMemberFields('g1', 'uid-bob', captureAny()))
              .captured
              .single as Map;
      expect(degisiklik, {'isMuted': true});
    });

    test('🔒 girdi BULUNAMAZSA sessizce başarılı DÖNMEZ', () async {
      // `memberIds` ile `members` ayrışmışsa rol değişimi hiçbir şey
      // yapmaz. Sessiz kalmak §4ah'nin ölçütünü ihlal ederdi:
      // kullanıcı rolü değiştirdiğini sanır, değişmemiştir.
      when(() => ds.updateMemberFields(any(), any(), any()))
          .thenAnswer((_) async => false);

      final sonuc = await repo.setMemberRole(
          chatId: 'g1', member: _member(), newRole: MemberRole.admin);

      expect(sonuc.isLeft(), isTrue);
    });
  });
}
