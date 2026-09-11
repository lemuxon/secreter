import '../../domain/entities/group_entity.dart';

/// GroupMember DTO
class GroupMemberModel extends GroupMemberEntity {
  const GroupMemberModel({
    required super.uid,
    super.username,
    super.role,
    super.isMuted,
    required super.joinedAt,
  });

  /// ── AD HİÇBİR KOŞULDA YAZILMAZ (metadata gizliliği, §4ak) ──
  ///
  /// Bu metot bir süre `username`i **koşullu** yazıyordu: doluysa
  /// (eski girdi) haritaya konurdu. Sebep kozmetik değil işlevseldi —
  /// üye çıkarma `FieldValue.arrayRemove([m.toMap()])` ile yapılıyor ve
  /// Firestore dizi elemanını **birebir** karşılaştırıyordu. Adsız bir
  /// harita, dokümanda adıyla duran eski bir üyeyle eşleşmez ve o kişi
  /// `members` dizisinden hiç çıkarılmazdı.
  ///
  /// §4ak o bağımlılığı kaldırdı: çıkarma artık **uid ile** yapılıyor
  /// (`GroupRemoteDataSource.removeMemberFromArray`). Birebir eşleşmeye
  /// dayanan tek yol oydu, yani koşul artık hiçbir şeyi korumuyor —
  /// yalnızca **eski adları sunucuda yaşatıyordu** (`DEVAM.md` §3b/7).
  ///
  /// Artık ad hiç yazılmadığı için, `members` dizisini yeniden yazan her
  /// yol (üye çıkarma, ayrılma, rol/susturma değişimi) eski adları o
  /// grupta **kendiliğinden temizler.**
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'role': role.name,
        'isMuted': isMuted,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory GroupMemberModel.fromMap(Map<String, dynamic> map) =>
      GroupMemberModel(
        uid: map['uid'] ?? '',
        username: map['username'] ?? '',
        role: MemberRole.values.firstWhere(
          (e) => e.name == map['role'],
          orElse: () => MemberRole.member,
        ),
        isMuted: map['isMuted'] ?? false,
        joinedAt: DateTime.tryParse(map['joinedAt'] ?? '') ?? DateTime.now(),
      );
}

/// Group DTO
class GroupModel extends GroupEntity {
  const GroupModel({
    required super.id,
    required super.type,
    required super.memberIds,
    super.memberUsernames,
    super.groupName,
    super.description,
    super.avatarUrl,
    super.adminId,
    super.members,
    super.inviteCode,
    super.bannedIds,
    super.onlyAdminsCanPost,
    super.memberCount,
    super.lastMessage,
    super.lastMessageTime,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'memberIds': memberIds,
        // ⚠️ `memberUsernames` BİLEREK YOK — üye adları sunucuya
        // yazılmaz (§4o). Güvenlik kuralı da bu alanı taşıyan bir
        // oluşturma isteğini reddeder.
        'groupName': groupName,
        'description': description,
        'avatarUrl': avatarUrl,
        'adminId': adminId,
        'members': members.map((m) => (m as GroupMemberModel).toMap()).toList(),
        'inviteCode': inviteCode,
        'bannedIds': bannedIds,
        // ── GÜVENLİK KURALLARININ OKUDUĞU DÜZ DİZİLER ──
        // Kural motorunda döngü olmadığı için `members` içindeki
        // role/isMuted alanları okunamaz. Susturma ve "yalnızca
        // yöneticiler" ayarının SUNUCUDA uygulanabilmesi bu dizilere
        // bağlıdır; `members` ile birlikte güncel tutulmaları şarttır.
        'adminUids': members
            .where(
                (m) => m.role == MemberRole.owner || m.role == MemberRole.admin)
            .map((m) => m.uid)
            .toList(),
        'mutedUids': members.where((m) => m.isMuted).map((m) => m.uid).toList(),
        'onlyAdminsCanPost': onlyAdminsCanPost,
        'memberCount': memberCount,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime?.toIso8601String(),
      };

  factory GroupModel.fromMap(Map<String, dynamic> map) => GroupModel(
        id: map['id'] ?? '',
        type: GroupChatType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => GroupChatType.direct,
        ),
        memberIds: List<String>.from(map['memberIds'] ?? []),
        memberUsernames: List<String>.from(map['memberUsernames'] ?? []),
        groupName: map['groupName'],
        description: map['description'],
        avatarUrl: map['avatarUrl'],
        adminId: map['adminId'],
        members: (map['members'] as List<dynamic>?)
                ?.map((m) =>
                    GroupMemberModel.fromMap(Map<String, dynamic>.from(m)))
                .toList() ??
            [],
        inviteCode: map['inviteCode'],
        bannedIds: List<String>.from(map['bannedIds'] ?? []),
        onlyAdminsCanPost: map['onlyAdminsCanPost'] ?? false,
        memberCount:
            map['memberCount'] ?? (map['memberIds'] as List?)?.length ?? 0,
        lastMessage: map['lastMessage'],
        lastMessageTime: DateTime.tryParse(map['lastMessageTime'] ?? ''),
      );
}
