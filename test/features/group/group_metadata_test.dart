import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/features/group/data/models/group_model.dart';
import 'package:gizli_chat/features/group/domain/entities/group_entity.dart';

/// 🕵️ METADATA GİZLİLİĞİ — 2. AŞAMA (grup/kanal tarafı)
///
/// Sohbet dokümanı üye adlarını İKİ yerde taşıyordu: `memberUsernames`
/// dizisi ve `members[].username`. Yalnızca birincisini kaldırmak grup
/// üyelerinin adlarını sunucuda açık bırakırdı.
GroupMemberModel _member({String username = '', String uid = 'uid-1'}) =>
    GroupMemberModel(
      uid: uid,
      username: username,
      role: MemberRole.member,
      joinedAt: DateTime.utc(2026, 9),
    );

void main() {
  setUp(() => GroupMemberEntity.nameResolver = null);
  tearDown(() => GroupMemberEntity.nameResolver = null);

  group('sunucuya yazılan alanlar', () {
    test('grup dokümanı ad dizisi YAZMAZ', () {
      // ⚠️ REGRESYON KORUMASI. Alan geri gelirse grup üyelikleri yine
      // adlarla okunabilir olur.
      final map = GroupModel(
        id: 'g1',
        type: GroupChatType.group,
        memberIds: const ['uid-1', 'uid-2'],
        groupName: 'Ekip',
        members: [_member(uid: 'uid-1'), _member(uid: 'uid-2')],
        memberCount: 2,
      ).toMap();

      expect(map.containsKey('memberUsernames'), isFalse);
    });

    test('YENİ üye haritasında ad alanı HİÇ yoktur', () {
      expect(_member().toMap().containsKey('username'), isFalse);
    });

    test('üye haritası uid ve rolü yazmaya devam eder', () {
      // Dürüstlük notu: bu aşama adı gizler, uid'yi değil — kural motoru
      // üyelik ve yetki denetimini uid ile yapıyor.
      final map = _member(uid: 'uid-7').toMap();
      expect(map['uid'], 'uid-7');
      expect(map['role'], 'member');
    });
  });

  group('geriye uyumluluk', () {
    test('ESKİ üye haritası geri yazılırken ADI DÜŞER (§4ak)', () {
      // ⚠️ BU TEST TERSİNE ÇEVRİLDİ — sebebi önemli.
      //
      // Eskiden "ESKİ üye haritası adıyla BİREBİR geri yazılır" diyordu
      // ve `toMap()` adı KOŞULLU yazıyordu. Gerekçe işlevseldi: üye
      // çıkarma `arrayRemove([m.toMap()])` ile yapılıyor, Firestore
      // dizi elemanını birebir karşılaştırıyordu; adsız harita eski
      // girdiyle eşleşmez ve atılan kişi listede kalırdı.
      //
      // §4ak çıkarmayı **uid ile** yapan bir işleme taşıdı. Birebir
      // eşleşmeye dayanan tek yol oydu — yani koşul artık hiçbir şeyi
      // korumuyor, yalnızca eski adları sunucuda yaşatıyordu
      // (`DEVAM.md` §3b/7). Ad artık hiçbir koşulda yazılmıyor.
      //
      // Sonuç: `members` dizisini yeniden yazan her yol o gruptaki
      // eski adları KENDİLİĞİNDEN temizler.
      final legacy = GroupMemberModel.fromMap({
        'uid': 'uid-1',
        'username': 'ayse',
        'role': 'member',
        'isMuted': false,
        'joinedAt': DateTime.utc(2026, 9).toIso8601String(),
      });
      // Okurken ad korunur (gösterimde yedek olarak kullanılır)…
      expect(legacy.username, 'ayse');
      // …ama sunucuya geri YAZILMAZ.
      expect(legacy.toMap().containsKey('username'), isFalse);
      expect(legacy.toMap(), {
        'uid': 'uid-1',
        'role': 'member',
        'isMuted': false,
        'joinedAt': DateTime.utc(2026, 9).toIso8601String(),
      });
    });

    test('ESKİ grup dokümanındaki ad dizisi okunmaya devam eder', () {
      final g = GroupModel.fromMap(const {
        'id': 'g1',
        'type': 'group',
        'memberIds': ['uid-1', 'uid-2'],
        'memberUsernames': ['ayse', 'mehmet'],
      });
      expect(g.memberUsernames, const ['ayse', 'mehmet']);
    });
  });

  group('üye adı gösterimi', () {
    test('ad uid çözümünden gelir', () {
      GroupMemberEntity.nameResolver = (uid) => 'mehmet';
      expect(_member().displayName, 'mehmet');
    });

    test('çözüm ESKİ addan önce gelir', () {
      GroupMemberEntity.nameResolver = (_) => 'yeni_ad';
      expect(_member(username: 'eski_ad').displayName, 'yeni_ad');
    });

    test('çözüm yoksa eski ad kullanılır', () {
      expect(_member(username: 'ayse').displayName, 'ayse');
    });

    test('hiçbiri yoksa üye ADSIZ görünmez (uid kısaltması)', () {
      expect(_member(uid: 'abcdefghij').displayName, 'abcdef');
    });
  });
}
