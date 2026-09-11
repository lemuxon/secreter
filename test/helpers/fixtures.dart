import 'package:gizli_chat/features/messaging/domain/entities/message_entity.dart';
import 'package:gizli_chat/features/messaging/data/models/message_model.dart';

/// Testlerde kullanılan örnek veriler.
/// Tek yerde tanımlanır, her test bunları kullanır (DRY).
class TestFixtures {
  static const chatId = 'user1_user2';
  static const myUid = 'user1';
  static const otherUid = 'user2';

  static MessageEntity textMessage({
    String id = 'msg1',
    String content = 'Merhaba',
    String senderId = myUid,
    bool isDeleted = false,
    MessageDeliveryStatus status = MessageDeliveryStatus.sent,
  }) {
    return MessageEntity(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderUsername: 'kullanici1',
      content: content,
      type: MessageContentType.text,
      timestamp: DateTime(2026, 1, 1, 12, 0),
      status: status,
      isDeleted: isDeleted,
    );
  }

  static MessageModel textMessageModel({
    String id = 'msg1',
    String content = 'Merhaba',
    String senderId = myUid,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderUsername: 'kullanici1',
      content: content,
      type: MessageContentType.text,
      timestamp: DateTime(2026, 1, 1, 12, 0),
    );
  }

  static List<MessageModel> messageList() => [
        textMessageModel(id: 'msg1', content: 'Birinci'),
        textMessageModel(id: 'msg2', content: 'İkinci', senderId: otherUid),
        textMessageModel(id: 'msg3', content: 'Üçüncü'),
      ];

  /// Firestore map formatında örnek mesaj
  static Map<String, dynamic> messageMap({
    String id = 'msg1',
    String content = 'Merhaba',
  }) =>
      {
        'id': id,
        'senderId': myUid,
        'senderUsername': 'kullanici1',
        'content': content,
        'type': 'text',
        'timestamp': '2026-01-01T12:00:00.000',
        'status': 'sent',
        'isDeleted': false,
        'isEdited': false,
        'isE2EE': false,
      };
}
