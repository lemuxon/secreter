import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/multi_account_service.dart';
import '../../../../services/key_management_service.dart';
import '../../../../services/notification_service.dart';
import '../../domain/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/observability/handled_error.dart';

/// AuthRepository implementasyonu.
///
/// Hassas kripto/Firebase mantığını YENİDEN YAZMAZ; savaşta denenmiş
/// servisleri (AuthService, KeyManagementService, MultiAccountService)
/// orkestre eder. Bu, "pragmatik Clean Architecture": çalışan motoru
/// koru, etrafına temiz sözleşme geçir.
class AuthRepositoryImpl implements AuthRepository {
  @override
  bool get isLoggedIn => AuthService.currentUid != null;

  @override
  String? get currentUserId => AuthService.currentUid;

  @override
  Future<Either<Failure, bool>> isUsernameAvailable(String username) async {
    try {
      final available = await AuthService.isUsernameAvailable(username);
      return Right(available);
    } catch (e, s) {
      reportHandled('Kullanıcı adı kontrol edilemedi', e, stack: s);
      return const Left(ServerFailure('err_username_check'));
    }
  }

  @override
  Future<Either<Failure, Unit>> register(String username) async {
    try {
      // 1) Anonim auth + kullanıcı adı (AuthService doğrulama da yapar)
      final error = await AuthService.register(username);
      if (error != null) return Left(ValidationFailure(error));

      // 2) Hesabı çoklu-hesap deposuna kaydet
      final uid = AuthService.currentUid;
      final encKey = await AuthService.getEncryptionKey();
      final pw = await AuthService.getAccountPassword();
      if (uid != null && encKey != null) {
        await MultiAccountService.saveAccount(SavedAccount(
          uid: uid,
          username: username.toLowerCase(),
          encryptionKey: encKey,
          password: pw ?? '',
        ));
      }

      // 3) E2EE anahtar paketini üret ve sunucuya yükle
      await KeyManagementService.generateAndUploadKeys();

      // 4) Push bildirimlerini başlat — ARKA PLANDA.
      // DONMA KÖKÜ: initialize() içinde FCM getToken() var; TEMİZ KURULUMDA
      // cihaz Play Services'e kaydolana dek 10-30 sn bloke edebiliyor.
      // Kayıt akışı bunu BEKLEMEZ; token gelince kullanıcı dokümanına
      // kendisi yazılır (hata olursa sessizce loglanır).
      unawaited(NotificationService.initialize().catchError((e) {
        debugPrint('Bildirim başlatma ertelendi/başarısız: $e');
      }));

      return const Right(unit);
    } catch (e, s) {
      reportHandled('Kayıt başarısız', e, stack: s);
      return const Left(UnexpectedFailure('err_register'));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await AuthService.signOut();
      return const Right(unit);
    } catch (e, s) {
      reportHandled('Çıkış başarısız', e, stack: s);
      return const Left(UnexpectedFailure('err_logout'));
    }
  }
}
