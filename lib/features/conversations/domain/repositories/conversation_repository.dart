import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/conversation_entity.dart';

/// Sohbet listesi veri erişiminin sözleşmesi.
abstract class ConversationRepository {
  /// Mevcut kullanıcının sohbetlerini canlı dinle (son mesaja göre sıralı)
  Stream<Either<Failure, List<ConversationEntity>>> watchConversations();
}
