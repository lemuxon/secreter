import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/found_user.dart';
import '../../domain/repositories/search_repository.dart';

class SearchState extends Equatable {
  final bool searching;
  final FoundUser? result;
  final String? error;
  final bool opening; // sohbet açılıyor
  final String? openedChatId; // başarıyla açılan sohbet (navigasyon için)
  final String? openedUsername;

  const SearchState({
    this.searching = false,
    this.result,
    this.error,
    this.opening = false,
    this.openedChatId,
    this.openedUsername,
  });

  SearchState copyWith({
    bool? searching,
    FoundUser? result,
    String? error,
    bool? opening,
    String? openedChatId,
    String? openedUsername,
    bool clearResult = false,
    bool clearError = false,
    bool clearOpened = false,
  }) {
    return SearchState(
      searching: searching ?? this.searching,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      opening: opening ?? this.opening,
      openedChatId: clearOpened ? null : (openedChatId ?? this.openedChatId),
      openedUsername:
          clearOpened ? null : (openedUsername ?? this.openedUsername),
    );
  }

  @override
  List<Object?> get props =>
      [searching, result, error, opening, openedChatId, openedUsername];
}

class SearchController extends StateNotifier<SearchState> {
  final SearchRepository _repo;

  SearchController()
      : _repo = getIt<SearchRepository>(),
        super(const SearchState());

  Future<void> search(String query) async {
    final q = query.trim().toLowerCase().replaceAll('@', '');
    if (q.isEmpty) return;
    state =
        state.copyWith(searching: true, clearResult: true, clearError: true);
    final result = await _repo.findByUsername(q);
    result.fold(
      (failure) =>
          state = state.copyWith(searching: false, error: failure.message),
      (user) {
        if (user == null) {
          state =
              state.copyWith(searching: false, error: 'Kullanıcı bulunamadı');
        } else {
          state = state.copyWith(searching: false, result: user);
        }
      },
    );
  }

  Future<void> openChat(FoundUser user) async {
    state = state.copyWith(opening: true, clearError: true);
    final result = await _repo.getOrCreateDirectChat(user.username);
    result.fold(
      (failure) =>
          state = state.copyWith(opening: false, error: failure.message),
      (chatId) => state = state.copyWith(
        opening: false,
        openedChatId: chatId,
        openedUsername: user.username,
      ),
    );
  }

  void consumeOpened() => state = state.copyWith(clearOpened: true);
}

final searchControllerProvider =
    StateNotifierProvider.autoDispose<SearchController, SearchState>(
  (ref) => SearchController(),
);
