import '../../domain/entities/conversation_entity.dart';

/// Conversation DTO — eski 'chats' koleksiyon şemasıyla uyumlu.
class ConversationModel extends ConversationEntity {
  const ConversationModel({
    required super.id,
    required super.type,
    required super.memberIds,
    super.memberUsernames,
    super.groupName,
    super.avatarUrl,
    super.adminId,
    super.incognito,
    super.lastMessage,
    super.lastMessageSenderId,
    super.unreadCounts,
    super.lastMessageTime,
    super.memberCount,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    return ConversationModel(
      id: map['id'] ?? '',
      type: _parseType(map['type']),
      memberIds: List<String>.from(map['memberIds'] ?? []),
      memberUsernames: List<String>.from(map['memberUsernames'] ?? []),
      groupName: map['groupName'],
      avatarUrl: map['avatarUrl'],
      adminId: map['adminId'],
      incognito: map['incognito'] == true,
      lastMessage: map['lastMessage'],
      lastMessageSenderId: map['lastMessageSenderId'],
      unreadCounts: (map['unreadCounts'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
          const {},
      lastMessageTime: DateTime.tryParse(map['lastMessageTime'] ?? ''),
      memberCount:
          map['memberCount'] ?? (map['memberIds'] as List?)?.length ?? 0,
    );
  }

  static ConversationType _parseType(String? raw) {
    return ConversationType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ConversationType.direct,
    );
  }
}
