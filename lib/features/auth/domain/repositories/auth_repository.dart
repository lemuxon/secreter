import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

/// Kimlik doğrulama veri erişiminin sözleşmesi.
///
/// NOT: Anonim auth + şifreleme anahtarı üretimi gibi hassas mantık
/// `AuthService` motorunda kalır; bu repository onu temiz bir arayüz
/// arkasına alır (uygulamanın geri kalanı statik servise değil, bu
/// sözleşmeye bağımlı olur).
abstract class AuthRepository {
  /// Oturum açık mı (senkron — currentUid üzerinden)
  bool get isLoggedIn;

  /// Mevcut kullanıcı UID'i
  String? get currentUserId;

  /// Kullanıcı adı müsait mi
  Future<Either<Failure, bool>> isUsernameAvailable(String username);

  /// Kayıt: anonim auth + kullanıcı adı + E2EE anahtarları + hesap kaydı.
  /// Başarılıysa Right(unit); doğrulama hatası varsa Left(ValidationFailure).
  Future<Either<Failure, Unit>> register(String username);

  /// Oturumu kapat
  Future<Either<Failure, Unit>> signOut();
}
