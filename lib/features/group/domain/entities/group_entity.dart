import 'package:equatable/equatable.dart';

enum GroupChatType { direct, group, channel }

enum MemberRole { owner, admin, member }

/// Grup üyesi (rol + kısıtlama)
class GroupMemberEntity extends Equatable {
  /// 🕵️ uid → görünen ad çözümleyici (METADATA GİZLİLİĞİ 2. AŞAMA).
  /// `ConversationEntity.nameResolver` ile aynı gerekçe: ad artık sohbet
  /// dokümanında tutulmadığı için gösterim anında uid'den çözülür.
  static String? Function(String uid)? nameResolver;

  final String uid;

  /// ⚠️ ESKİ DOKÜMAN YEDEĞİ — yeni üyelerde BOŞ gelir.
  /// Sunucuya artık yazılmaz; gösterim için [displayName] kullanın.
  final String username;

  final MemberRole role;
  final bool isMuted;
  final DateTime joinedAt;

  const GroupMemberEntity({
    required this.uid,
    this.username = '',
    this.role = MemberRole.member,
    this.isMuted = false,
    required this.joinedAt,
  });

  /// Arayüzde gösterilecek ad. Önce canlı çözüm, sonra eski dokümandaki
  /// değer; hiçbiri yoksa uid'nin kısaltması (ad hiç boş kalmasın).
  String get displayName {
    final resolved = nameResolver?.call(uid);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    if (username.isNotEmpty) return username;
    return uid.length > 6 ? uid.substring(0, 6) : uid;
  }

  bool get canModerate => role == MemberRole.owner || role == MemberRole.admin;

  GroupMemberEntity copyWith({MemberRole? role, bool? isMuted}) =>
      GroupMemberEntity(
        uid: uid,
        username: username,
        role: role ?? this.role,
        isMuted: isMuted ?? this.isMuted,
        joinedAt: joinedAt,
      );

  @override
  List<Object?> get props => [uid, username, role, isMuted];
}

/// Grup/kanal/direkt sohbet domain temsili
class GroupEntity extends Equatable {
  final String id;
  final GroupChatType type;
  final List<String> memberIds;

  /// ⚠️ ESKİ DOKÜMAN YEDEĞİ — yeni gruplarda BOŞ gelir (bkz. §4o).
  final List<String> memberUsernames;

  final String? groupName;
  final String? description;
  final String? avatarUrl;
  final String? adminId;
  final List<GroupMemberEntity> members;
  final String? inviteCode;
  final List<String> bannedIds;
  final bool onlyAdminsCanPost;
  final int memberCount;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  const GroupEntity({
    required this.id,
    required this.type,
    required this.memberIds,
    this.memberUsernames = const [],
    this.groupName,
    this.description,
    this.avatarUrl,
    this.adminId,
    this.members = const [],
    this.inviteCode,
    this.bannedIds = const [],
    this.onlyAdminsCanPost = false,
    this.memberCount = 0,
    this.lastMessage,
    this.lastMessageTime,
  });

  bool get isChannel => type == GroupChatType.channel;
  bool get isGroup => type == GroupChatType.group;

  /// Bir kullanıcının rolünü bul (iş kuralı domain'de)
  MemberRole roleOf(String uid) {
    for (final m in members) {
      if (m.uid == uid) return m.role;
    }
    if (uid == adminId) return MemberRole.owner;
    return MemberRole.member;
  }

  /// Kullanıcı mesaj gönderebilir mi?
  bool canPost(String uid) {
    if (type == GroupChatType.channel || onlyAdminsCanPost) {
      final role = roleOf(uid);
      return role == MemberRole.owner || role == MemberRole.admin;
    }
    for (final m in members) {
      if (m.uid == uid && m.isMuted) return false;
    }
    return true;
  }

  /// Kullanıcı moderasyon yapabilir mi?
  bool canModerate(String uid) {
    final role = roleOf(uid);
    return role == MemberRole.owner || role == MemberRole.admin;
  }

  bool isBanned(String uid) => bannedIds.contains(uid);

  @override
  List<Object?> get props => [
        id,
        type,
        memberIds,
        memberUsernames,
        groupName,
        description,
        avatarUrl,
        adminId,
        members,
        inviteCode,
        bannedIds,
        onlyAdminsCanPost,
        memberCount,
        lastMessage,
        lastMessageTime,
      ];
}
