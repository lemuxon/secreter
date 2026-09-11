import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/usecases/conversation_usecases.dart';

class ConversationsState extends Equatable {
  final List<ConversationEntity> conversations;
  final bool isLoading;
  final String? error;

  const ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  factory ConversationsState.initial() =>
      const ConversationsState(isLoading: true);

  ConversationsState copyWith({
    List<ConversationEntity>? conversations,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [conversations, isLoading, error];
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final WatchConversations _watchConversations;
  StreamSubscription? _sub;

  ConversationsNotifier()
      : _watchConversations = getIt<WatchConversations>(),
        super(ConversationsState.initial()) {
    _start();
  }

  void _start() {
    // EMNIYET AGI: 8 sn icinde akistan hicbir sey gelmezse iskeleti kaldir
    // (bos liste goster). Boylece beklenmedik bir durumda kullanici sonsuz
    // "yukleniyor" ekraninda kalmaz.
    Timer(const Duration(seconds: 8), () {
      if (mounted && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    });

    _sub = _watchConversations(const NoParams()).listen((either) {
      either.fold(
        (failure) =>
            state = state.copyWith(isLoading: false, error: failure.message),
        (list) => state = state.copyWith(
          conversations: list,
          isLoading: false,
          clearError: true,
        ),
      );
    });
  }

  /// Asagi cek-yenile: stream'e yeniden abone ol (taze sunucu anligi).
  /// Mevcut liste korunur — titreme olmaz; yeni veri gelince degisir.
  Future<void> refresh() async {
    await _sub?.cancel();
    _start();
    // Gostergenin cok hizli kaybolmamasi icin kisa bekleme
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final conversationsNotifierProvider = StateNotifierProvider.autoDispose<
    ConversationsNotifier, ConversationsState>(
  (ref) => ConversationsNotifier(),
);
