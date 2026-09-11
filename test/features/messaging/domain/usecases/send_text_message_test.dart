import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gizli_chat/core/error/failures.dart';
import 'package:gizli_chat/features/messaging/domain/usecases/send_text_message.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late SendTextMessage useCase;
  late MockMessageRepository mockRepository;

  setUp(() {
    mockRepository = MockMessageRepository();
    useCase = SendTextMessage(mockRepository);
  });

  const chatId = 'user1_user2';

  group('SendTextMessage', () {
    test('boş mesaj gönderilmeye çalışılırsa ValidationFailure döner',
        () async {
      // act
      final result = await useCase(const SendTextParams(
        chatId: chatId,
        text: '   ', // sadece boşluk
      ));

      // assert
      expect(result, isA<Left<Failure, Unit>>());
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Başarı dönmemeliydi'),
      );
      // Repository hiç çağrılmamalı (validasyon önce)
      verifyNever(() => mockRepository.sendTextMessage(
            chatId: any(named: 'chatId'),
            text: any(named: 'text'),
          ));
    });

    test('4096 karakterden uzun mesaj ValidationFailure döner', () async {
      // arrange
      final longText = 'a' * 4097;

      // act
      final result = await useCase(SendTextParams(
        chatId: chatId,
        text: longText,
      ));

      // assert
      expect(result, isA<Left<Failure, Unit>>());
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Başarı dönmemeliydi'),
      );
    });

    test('geçerli mesaj repository\'ye iletilir ve başarı döner', () async {
      // arrange
      when(() => mockRepository.sendTextMessage(
            chatId: any(named: 'chatId'),
            text: any(named: 'text'),
            replyToId: any(named: 'replyToId'),
            replyToPreview: any(named: 'replyToPreview'),
            disappearAfterSeconds: any(named: 'disappearAfterSeconds'),
          )).thenAnswer((_) async => const Right(unit));

      // act
      final result = await useCase(const SendTextParams(
        chatId: chatId,
        text: 'Geçerli mesaj',
      ));

      // assert
      expect(result, const Right<Failure, Unit>(unit));
      verify(() => mockRepository.sendTextMessage(
            chatId: chatId,
            text: 'Geçerli mesaj',
            replyToId: null,
            replyToPreview: null,
            disappearAfterSeconds: null,
          )).called(1);
    });

    test('mesajın baş/son boşlukları temizlenir', () async {
      // arrange
      when(() => mockRepository.sendTextMessage(
            chatId: any(named: 'chatId'),
            text: any(named: 'text'),
            replyToId: any(named: 'replyToId'),
            replyToPreview: any(named: 'replyToPreview'),
            disappearAfterSeconds: any(named: 'disappearAfterSeconds'),
          )).thenAnswer((_) async => const Right(unit));

      // act
      await useCase(const SendTextParams(
        chatId: chatId,
        text: '  boşluklu mesaj  ',
      ));

      // assert — repository'ye temizlenmiş hali gitmeli
      verify(() => mockRepository.sendTextMessage(
            chatId: chatId,
            text: 'boşluklu mesaj', // trim'lenmiş
            replyToId: null,
            replyToPreview: null,
            disappearAfterSeconds: null,
          )).called(1);
    });

    test('repository hata dönerse hata yukarı iletilir', () async {
      // arrange
      when(() => mockRepository.sendTextMessage(
            chatId: any(named: 'chatId'),
            text: any(named: 'text'),
            replyToId: any(named: 'replyToId'),
            replyToPreview: any(named: 'replyToPreview'),
            disappearAfterSeconds: any(named: 'disappearAfterSeconds'),
          )).thenAnswer((_) async => const Left(ServerFailure()));

      // act
      final result = await useCase(const SendTextParams(
        chatId: chatId,
        text: 'Mesaj',
      ));

      // assert
      expect(result, isA<Left<Failure, Unit>>());
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Hata dönmeliydi'),
      );
    });
  });
}
