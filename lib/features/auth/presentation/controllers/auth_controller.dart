import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../../../services/auth_service.dart';
import '../../domain/repositories/auth_repository.dart';

/// Kayıt ekranının durumu (kullanıcı adı kontrolü + kayıt akışı).
class AuthState extends Equatable {
  final bool checkingUsername;
  final bool? usernameAvailable; // null = henüz kontrol edilmedi
  final bool registering;
  final String? error;
  final bool registered; // başarı bayrağı (ekran navigasyonu için)

  const AuthState({
    this.checkingUsername = false,
    this.usernameAvailable,
    this.registering = false,
    this.error,
    this.registered = false,
  });

  AuthState copyWith({
    bool? checkingUsername,
    bool? usernameAvailable,
    bool? registering,
    String? error,
    bool? registered,
    bool clearAvailable = false,
    bool clearError = false,
  }) {
    return AuthState(
      checkingUsername: checkingUsername ?? this.checkingUsername,
      usernameAvailable:
          clearAvailable ? null : (usernameAvailable ?? this.usernameAvailable),
      registering: registering ?? this.registering,
      error: clearError ? null : (error ?? this.error),
      registered: registered ?? this.registered,
    );
  }

  @override
  List<Object?> get props =>
      [checkingUsername, usernameAvailable, registering, error, registered];
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthController()
      : _repo = getIt<AuthRepository>(),
        super(const AuthState());

  /// Kullanıcı adı müsaitlik kontrolü (canlı)
  Future<void> checkUsername(String value) async {
    final v = value.trim();
    if (v.length < 3) {
      state = state.copyWith(clearAvailable: true, clearError: true);
      return;
    }
    // 🐞 BİÇİM KONTROLÜ BURADA YOKTU. Kural yalnızca `register()` içinde
    // çalışıyordu; kullanıcı Türkçe karakterli bir ad yazıyor, yazarken
    // hiçbir uyarı görmüyor, "Kaydet"e basınca reddediliyordu. Artık
    // yazarken görünür — ve ağa hiç çıkılmaz (gereksiz okuma da olmaz).
    if (!AuthService.isValidUsernameFormat(v)) {
      state = state.copyWith(
        checkingUsername: false,
        clearAvailable: true,
        error: 'err_username_format',
      );
      return;
    }
    state = state.copyWith(checkingUsername: true, clearError: true);
    final result = await _repo.isUsernameAvailable(v);
    result.fold(
      (failure) => state =
          state.copyWith(checkingUsername: false, error: failure.message),
      (available) => state =
          state.copyWith(checkingUsername: false, usernameAvailable: available),
    );
  }

  /// Kayıt ol
  Future<void> register(String username) async {
    state = state.copyWith(registering: true, clearError: true);
    final result = await _repo.register(username.trim());
    result.fold(
      (failure) =>
          state = state.copyWith(registering: false, error: failure.message),
      (_) => state = state.copyWith(registering: false, registered: true),
    );
  }

  void resetError() => state = state.copyWith(clearError: true);
}

final authControllerProvider =
    StateNotifierProvider.autoDispose<AuthController, AuthState>(
  (ref) => AuthController(),
);
