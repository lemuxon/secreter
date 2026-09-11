import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/conversation_entity.dart';
import '../repositories/conversation_repository.dart';

/// Kullanıcının sohbetlerini canlı dinle
class WatchConversations
    implements StreamUseCase<List<ConversationEntity>, NoParams> {
  final ConversationRepository repository;
  WatchConversations(this.repository);

  @override
  Stream<Either<Failure, List<ConversationEntity>>> call(NoParams params) {
    return repository.watchConversations();
  }
}
