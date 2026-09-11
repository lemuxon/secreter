import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/message_repository.dart';

/// Metin mesajı gönderme use case'i.
/// İş kuralı: boş mesaj gönderilemez, maks 4096 karakter.
class SendTextMessage implements UseCase<Unit, SendTextParams> {
  final MessageRepository repository;
  SendTextMessage(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SendTextParams params) async {
    // Domain validasyonu — UI'a güvenmeyiz
    final trimmed = params.text.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('err_message_empty'));
    }
    if (trimmed.length > 4096) {
      return const Left(ValidationFailure('err_message_too_long'));
    }

    return repository.sendTextMessage(
      chatId: params.chatId,
      text: trimmed,
      replyToId: params.replyToId,
      replyToPreview: params.replyToPreview,
      disappearAfterSeconds: params.disappearAfterSeconds,
    );
  }
}

class SendTextParams extends Equatable {
  final String chatId;
  final String text;
  final String? replyToId;
  final String? replyToPreview;
  final int? disappearAfterSeconds;

  const SendTextParams({
    required this.chatId,
    required this.text,
    this.replyToId,
    this.replyToPreview,
    this.disappearAfterSeconds,
  });

  @override
  List<Object?> get props =>
      [chatId, text, replyToId, replyToPreview, disappearAfterSeconds];
}
