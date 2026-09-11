import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gizli_chat/core/error/failures.dart';
import 'package:gizli_chat/features/messaging/domain/usecases/manage_message.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late DeleteMessage deleteUseCase;
  late EditMessage editUseCase;
  late MockMessageRepository mockRepository;

  setUp(() {
    mockRepository = MockMessageRepository();
    deleteUseCase = DeleteMessage(mockRepository);
    editUseCase = EditMessage(mockRepository);
  });

  const chatId = 'user1_user2';
  const messageId = 'msg1';

  group('DeleteMessage', () {
    test('repository deleteMessage çağrılır', () async {
      // arrange
      when(() => mockRepository.deleteMessage(
            chatId: any(named: 'chatId'),
            messageId: any(named: 'messageId'),
          )).thenAnswer((_) async => const Right(unit));

      // act
      final result = await deleteUseCase(const DeleteMessageParams(
        chatId: chatId,
        messageId: messageId,
      ));

      // assert
      expect(result, const Right<Failure, Unit>(unit));
      verify(() => mockRepository.deleteMessage(
            chatId: chatId,
            messageId: messageId,
          )).called(1);
    });
  });

  group('EditMessage', () {
    test('boş yeni metin ValidationFailure döner', () async {
      // act
      final result = await editUseCase(const EditMessageParams(
        chatId: chatId,
        messageId: messageId,
        newText: '  ',
      ));

      // assert
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Başarı dönmemeliydi'),
      );
      verifyNever(() => mockRepository.editMessage(
            chatId: any(named: 'chatId'),
            messageId: any(named: 'messageId'),
            newText: any(named: 'newText'),
          ));
    });

    test('geçerli düzenleme repository\'ye iletilir', () async {
      // arrange
      when(() => mockRepository.editMessage(
            chatId: any(named: 'chatId'),
            messageId: any(named: 'messageId'),
            newText: any(named: 'newText'),
          )).thenAnswer((_) async => const Right(unit));

      // act
      final result = await editUseCase(const EditMessageParams(
        chatId: chatId,
        messageId: messageId,
        newText: 'Düzenlenmiş metin',
      ));

      // assert
      expect(result, const Right<Failure, Unit>(unit));
      verify(() => mockRepository.editMessage(
            chatId: chatId,
            messageId: messageId,
            newText: 'Düzenlenmiş metin',
          )).called(1);
    });
  });
}
