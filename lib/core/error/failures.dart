import 'package:equatable/equatable.dart';

/// Tüm hataların temel sınıfı.
/// Repository katmanı exception fırlatmak yerine Either<Failure, T> döndürür;
/// böylece hata yönetimi tip-güvenli ve açık olur.
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Ağ / sunucu hatası (Firestore, Storage erişimi başarısız)
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'err_server']);
}

/// İnternet bağlantısı yok
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'err_network']);
}

/// Yetkilendirme hatası (oturum yok, izin yok)
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'err_auth']);
}

/// Şifreleme / çözme hatası
class EncryptionFailure extends Failure {
  const EncryptionFailure([super.message = 'err_crypto']);
}

/// Lokal önbellek / veritabanı hatası
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'err_cache']);
}

/// Doğrulama hatası (geçersiz girdi)
class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'err_invalid']);
}

/// Beklenmeyen hata
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'err_unexpected']);
}
