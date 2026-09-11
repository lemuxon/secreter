import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/auth/current_user_provider.dart';
import '../../domain/entities/found_user.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_remote_datasource.dart';
import '../../../../core/observability/handled_error.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;
  final CurrentUserProvider userProvider;

  SearchRepositoryImpl({
    required this.remoteDataSource,
    required this.userProvider,
  });

  @override
  Future<Either<Failure, FoundUser?>> findByUsername(String username) async {
    try {
      final found = await remoteDataSource.findByUsername(username);
      // Kendini bulduysan null gibi davran (sohbet açılamaz)
      if (found != null && found.uid == userProvider.currentUid) {
        return const Left(ValidationFailure('err_self_chat'));
      }
      return Right(found);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('findByUsername', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, String>> getOrCreateDirectChat(String username) async {
    try {
      final chatId = await remoteDataSource.getOrCreateDirectChat(username);
      return Right(chatId);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('getOrCreateDirectChat', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }
}
