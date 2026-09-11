import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/features/messaging/data/models/message_model.dart';
import 'package:gizli_chat/features/messaging/domain/entities/message_entity.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('MessageModel serileştirme', () {
    test('fromMap doğru parse eder', () {
      // arrange
      final map = TestFixtures.messageMap(content: 'Test mesajı');

      // act
      final model = MessageModel.fromMap(map, TestFixtures.chatId);

      // assert
      expect(model.id, 'msg1');
      expect(model.content, 'Test mesajı');
      expect(model.type, MessageContentType.text);
      expect(model.chatId, TestFixtures.chatId);
      expect(model.isDeleted, false);
    });

    test('toMap → fromMap round-trip veriyi korur', () {
      // arrange
      final original = TestFixtures.textMessageModel(content: 'Orijinal');

      // act
      final map = original.toMap();
      final restored = MessageModel.fromMap(map, TestFixtures.chatId);

      // assert
      expect(restored.id, original.id);
      expect(restored.content, original.content);
      expect(restored.senderId, original.senderId);
      expect(restored.type, original.type);
    });

    test('eksik alanlar varsayılana düşer (bozuk veri toleransı)', () {
      // arrange — minimal map
      final map = {'id': 'x', 'type': 'text'};

      // act
      final model = MessageModel.fromMap(map, 'chat1');

      // assert — çökmeden varsayılanlar
      expect(model.id, 'x');
      expect(model.content, '');
      expect(model.senderId, '');
      expect(model.isDeleted, false);
    });

    test('copyWithContent sadece içeriği değiştirir', () {
      // arrange
      final original = TestFixtures.textMessageModel(content: 'şifreli');

      // act
      final decrypted = original.copyWithContent('çözülmüş');

      // assert
      expect(decrypted.content, 'çözülmüş');
      expect(decrypted.id, original.id); // diğerleri aynı
      expect(decrypted.senderId, original.senderId);
    });
  });

  group('MessageEntity iş kuralları', () {
    test('isExpired: expiresAt geçmişse true', () {
      final expired = MessageEntity(
        id: 'm',
        chatId: 'c',
        senderId: 's',
        senderUsername: 'u',
        content: 'x',
        type: MessageContentType.text,
        timestamp: DateTime(2020),
        expiresAt: DateTime(2020, 1, 1, 12, 0, 5),
      );
      expect(expired.isExpired, true);
    });

    test('isExpired: expiresAt yoksa false (kalıcı mesaj)', () {
      final msg = TestFixtures.textMessage();
      expect(msg.isExpired, false);
    });

    test('preview: silinen mesaj için doğru metin', () {
      final deleted = TestFixtures.textMessage(isDeleted: true);
      expect(deleted.preview, 'Silinen mesaj');
    });

    test('preview: resim mesajı için emoji', () {
      final image = MessageEntity(
        id: 'm',
        chatId: 'c',
        senderId: 's',
        senderUsername: 'u',
        content: '',
        type: MessageContentType.image,
        timestamp: DateTime(2026),
      );
      expect(image.preview, '🖼️ Fotoğraf');
    });

    test('isSentBy: doğru kullanıcıyı tanır', () {
      final msg = TestFixtures.textMessage(senderId: 'user1');
      expect(msg.isSentBy('user1'), true);
      expect(msg.isSentBy('user2'), false);
    });
  });
}
