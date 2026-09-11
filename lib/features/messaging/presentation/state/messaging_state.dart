import 'package:equatable/equatable.dart';
import '../../domain/entities/message_entity.dart';

/// Mesaj ekranının UI durumu.
/// Immutable — her değişiklikte yeni kopya üretilir (copyWith).
class MessagingState extends Equatable {
  final List<MessageEntity> messages;
  final bool isLoading;
  final String? error;
  final bool isSending;

  /// Gönderilemeyen mesajın METNİ (§4bk).
  ///
  /// Gönderim başarısızsa geçici balon kaldırılır; metin burada geri
  /// verilir ki ekran onu giriş kutusuna koyabilsin. Aksi hâlde uzun bir
  /// mesajı yazıp gönderememek, onu baştan yazmak demekti.
  final String? basarisizMetin;

  // Pagination
  final bool hasMore;
  final bool isLoadingMore;

  // Reply/edit durumu
  final MessageEntity? replyingTo;
  final MessageEntity? editingMessage;
  final int? disappearSeconds;

  const MessagingState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.basarisizMetin,
    this.isSending = false,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.replyingTo,
    this.editingMessage,
    this.disappearSeconds,
  });

  factory MessagingState.initial() => const MessagingState(isLoading: true);

  MessagingState copyWith({
    String? basarisizMetin,
    bool clearBasarisizMetin = false,
    List<MessageEntity>? messages,
    bool? isLoading,
    String? error,
    bool? isSending,
    bool? hasMore,
    bool? isLoadingMore,
    MessageEntity? replyingTo,
    MessageEntity? editingMessage,
    int? disappearSeconds,
    bool clearReply = false,
    bool clearEdit = false,
    bool clearError = false,
  }) {
    return MessagingState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      basarisizMetin:
          clearBasarisizMetin ? null : (basarisizMetin ?? this.basarisizMetin),
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
      editingMessage:
          clearEdit ? null : (editingMessage ?? this.editingMessage),
      disappearSeconds: disappearSeconds ?? this.disappearSeconds,
    );
  }

  @override
  List<Object?> get props => [
        basarisizMetin,
        messages,
        isLoading,
        error,
        isSending,
        hasMore,
        isLoadingMore,
        replyingTo,
        editingMessage,
        disappearSeconds,
      ];
}
