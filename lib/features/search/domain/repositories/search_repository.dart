import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/found_user.dart';

/// Kullanıcı arama + sohbet başlatma sözleşmesi.
abstract class SearchRepository {
  /// Kullanıcı adıyla ara. Bulunamazsa Right(null).
  Future<Either<Failure, FoundUser?>> findByUsername(String username);

  /// Bu kullanıcıyla direkt sohbeti getir veya oluştur → chatId döner.
  Future<Either<Failure, String>> getOrCreateDirectChat(String username);
}
