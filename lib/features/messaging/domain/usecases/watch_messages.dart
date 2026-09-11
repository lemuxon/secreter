import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/message_entity.dart';
import '../repositories/message_repository.dart';

/// Bir sohbetteki mesajları canlı dinleme use case'i.
class WatchMessages implements StreamUseCase<List<MessageEntity>, String> {
  final MessageRepository repository;
  WatchMessages(this.repository);

  @override
  Stream<Either<Failure, List<MessageEntity>>> call(String chatId) {
    return repository.watchMessages(chatId);
  }
}
