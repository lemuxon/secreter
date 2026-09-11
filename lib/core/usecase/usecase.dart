import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../error/failures.dart';

/// Tüm use case'lerin temel arayüzü.
/// Her use case tek bir iş yapar (Single Responsibility).
///
/// [T] dönüş tipi, [Params] girdi parametreleri.
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Stream döndüren use case'ler için (örn. canlı mesaj akışı)
abstract class StreamUseCase<T, Params> {
  Stream<Either<Failure, T>> call(Params params);
}

/// Parametre gerektirmeyen use case'ler için
class NoParams extends Equatable {
  const NoParams();
  @override
  List<Object?> get props => [];
}
