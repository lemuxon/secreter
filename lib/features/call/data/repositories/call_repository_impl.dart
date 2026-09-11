import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/auth/current_user_provider.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasources/call_remote_datasource.dart';
import '../../../../core/observability/handled_error.dart';

/// ⚠️ ÇAĞRI DOKÜMANINI **OKUR**, OLUŞTURMAZ — bkz. [CallRepository].
///
/// `calls`'a yazan tek yer `lib/services/call_service.dart`. Ölü yazma
/// yolu §4aj'de kaldırıldı; gerekçesi sözleşme dosyasında.

/// CallRepository implementasyonu — dinleme + reddetme.
class CallRepositoryImpl implements CallRepository {
  final CallRemoteDataSource remoteDataSource;
  final CurrentUserProvider userProvider;

  // ⚠️ `uuid` alanı BİLEREK YOK: çağrı kimliğini üreten taraf artık
  // yalnızca `CallService`. Buraya bir üreteç geri konursa, bu katmanın
  // yeniden bir doküman OLUŞTURABİLECEĞİ anlamına gelir — §4u tam
  // oradan çıkmıştı.
  CallRepositoryImpl({
    required this.remoteDataSource,
    required this.userProvider,
  });

  @override
  Stream<Either<Failure, CallEntity?>> watchIncomingCall() {
    final myUid = userProvider.currentUid;
    if (myUid == null) {
      return Stream.value(const Left(AuthFailure()));
    }
    // (bkz. conversation_repository_impl) handleError hatayi yutuyordu.
    return remoteDataSource
        .watchIncomingCall(myUid)
        .map<Either<Failure, CallEntity?>>((call) => Right(call))
        .transform(
      StreamTransformer<Either<Failure, CallEntity?>,
          Either<Failure, CallEntity?>>.fromHandlers(
        handleError: (e, st, sink) {
          reportHandled('watchIncomingCall', e, stack: st);
          sink.add(const Left(ServerFailure()));
        },
      ),
    );
  }

  @override
  Stream<Either<Failure, CallEntity>> watchCall(String callId) {
    return remoteDataSource
        .watchCall(callId)
        .map<Either<Failure, CallEntity>>((call) => Right(call))
        .transform(
      StreamTransformer<Either<Failure, CallEntity>,
          Either<Failure, CallEntity>>.fromHandlers(
        handleError: (e, st, sink) {
          reportHandled('watchCall', e, stack: st);
          sink.add(const Left(ServerFailure()));
        },
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> updateStatus(
      String callId, CallStatus status) async {
    try {
      await remoteDataSource.updateStatus(callId, status);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('updateStatus', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }
}
