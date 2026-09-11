import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/message_entity.dart';
import '../repositories/message_repository.dart';

/// Mesaj silme use case'i (her iki taraftan)
class DeleteMessage implements UseCase<Unit, DeleteMessageParams> {
  final MessageRepository repository;
  DeleteMessage(this.repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteMessageParams params) {
    return repository.deleteMessage(
      chatId: params.chatId,
      messageId: params.messageId,
    );
  }
}

class DeleteMessageParams extends Equatable {
  final String chatId;
  final String messageId;
  const DeleteMessageParams({required this.chatId, required this.messageId});

  @override
  List<Object?> get props => [chatId, messageId];
}

/// Mesaj düzenleme use case'i
class EditMessage implements UseCase<Unit, EditMessageParams> {
  final MessageRepository repository;
  EditMessage(this.repository);

  @override
  Future<Either<Failure, Unit>> call(EditMessageParams params) async {
    final trimmed = params.newText.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('err_message_empty'));
    }
    return repository.editMessage(
      chatId: params.chatId,
      messageId: params.messageId,
      newText: trimmed,
    );
  }
}

class EditMessageParams extends Equatable {
  final String chatId;
  final String messageId;
  final String newText;
  const EditMessageParams({
    required this.chatId,
    required this.messageId,
    required this.newText,
  });

  @override
  List<Object?> get props => [chatId, messageId, newText];
}

/// Reaksiyon ayarlama use case'i (emoji bos ise kaldirir)
class SetReaction implements UseCase<Unit, SetReactionParams> {
  final MessageRepository repository;
  SetReaction(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SetReactionParams params) {
    return repository.setReaction(
      chatId: params.chatId,
      messageId: params.messageId,
      emoji: params.emoji,
    );
  }
}

class SetReactionParams extends Equatable {
  final String chatId;
  final String messageId;
  final String emoji;
  const SetReactionParams({
    required this.chatId,
    required this.messageId,
    required this.emoji,
  });

  @override
  List<Object?> get props => [chatId, messageId, emoji];
}

/// Medya (fotograf vb.) mesaji gonderme use case'i (yanit destekli)
class SendMediaMessage implements UseCase<Unit, SendMediaParams> {
  final MessageRepository repository;
  SendMediaMessage(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SendMediaParams params) {
    return repository.sendMediaMessage(
      chatId: params.chatId,
      localFilePath: params.localFilePath,
      type: params.type,
      fileName: params.fileName,
      replyToId: params.replyToId,
      replyToPreview: params.replyToPreview,
      mediaSource: params.mediaSource,
      viewOnce: params.viewOnce,
      voiceDurationMs: params.voiceDurationMs,
    );
  }
}

class SendMediaParams extends Equatable {
  final String chatId;
  final String localFilePath;
  final MessageContentType type;
  final String? fileName;
  final String? replyToId;
  final String? replyToPreview;
  final String? mediaSource;
  final bool viewOnce;
  final int? voiceDurationMs;
  const SendMediaParams({
    required this.chatId,
    required this.localFilePath,
    required this.type,
    this.fileName,
    this.replyToId,
    this.replyToPreview,
    this.mediaSource,
    this.viewOnce = false,
    this.voiceDurationMs,
  });

  @override
  List<Object?> get props => [
        chatId,
        localFilePath,
        type,
        fileName,
        replyToId,
        replyToPreview,
        mediaSource,
        viewOnce,
        voiceDurationMs
      ];
}

/// Tek goruntuluk fotoyu tuketme use-case'i (Storage'dan siler)
class ConsumeViewOnce implements UseCase<Unit, ConsumeViewOnceParams> {
  final MessageRepository repository;
  ConsumeViewOnce(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ConsumeViewOnceParams params) {
    return repository.consumeViewOnce(
      chatId: params.chatId,
      messageId: params.messageId,
      mediaUrl: params.mediaUrl,
    );
  }
}

class ConsumeViewOnceParams extends Equatable {
  final String chatId;
  final String messageId;
  final String mediaUrl;
  const ConsumeViewOnceParams({
    required this.chatId,
    required this.messageId,
    required this.mediaUrl,
  });

  @override
  List<Object?> get props => [chatId, messageId, mediaUrl];
}

/// GIF gonderme use-case'i (Giphy URL — yukleme yok)
class SendGifMessage implements UseCase<Unit, SendGifParams> {
  final MessageRepository repository;
  SendGifMessage(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SendGifParams params) {
    return repository.sendGifMessage(
      chatId: params.chatId,
      gifUrl: params.gifUrl,
      sticker: params.sticker,
    );
  }
}

/// 📊 Anket gonderme use-case'i
class SendPollMessage implements UseCase<Unit, SendPollParams> {
  final MessageRepository repository;
  SendPollMessage(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SendPollParams params) {
    final q = params.question.trim();
    final opts =
        params.options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (q.isEmpty) {
      return Future.value(
          const Left(ValidationFailure('err_poll_question_empty')));
    }
    if (opts.length < 2) {
      return Future.value(
          const Left(ValidationFailure('err_poll_min_options')));
    }
    return repository.sendPollMessage(
        chatId: params.chatId, question: q, options: opts);
  }
}

class SendPollParams extends Equatable {
  final String chatId;
  final String question;
  final List<String> options;
  const SendPollParams(
      {required this.chatId, required this.question, required this.options});

  @override
  List<Object?> get props => [chatId, question, options];
}

class SendGifParams extends Equatable {
  final String chatId;
  final String gifUrl;
  final bool sticker; // #7: cikartma isareti (seffaf render)
  const SendGifParams(
      {required this.chatId, required this.gifUrl, this.sticker = false});

  @override
  List<Object?> get props => [chatId, gifUrl, sticker];
}

/// Sohbeti okundu isaretle (readBy + status + rozet sifirlama)
class MarkAsRead implements UseCase<Unit, String> {
  final MessageRepository repository;
  MarkAsRead(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String chatId) {
    return repository.markAsRead(chatId);
  }
}

/// Sohbetteki tum mesajlari sil
class ClearChat implements UseCase<Unit, String> {
  final MessageRepository repository;
  ClearChat(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String chatId) =>
      repository.clearChat(chatId);
}

/// 'Benden sil' (tek/toplu)
class DeleteForMe implements UseCase<Unit, DeleteBatchParams> {
  final MessageRepository repository;
  DeleteForMe(this.repository);
  @override
  Future<Either<Failure, Unit>> call(DeleteBatchParams p) =>
      repository.deleteForMe(p.chatId, p.messageIds);
}

/// 'Herkesten sil' (tek/toplu)
class DeleteForEveryone implements UseCase<Unit, DeleteBatchParams> {
  final MessageRepository repository;
  DeleteForEveryone(this.repository);
  @override
  Future<Either<Failure, Unit>> call(DeleteBatchParams p) =>
      repository.deleteForEveryone(p.chatId, p.messageIds);
}

class DeleteBatchParams extends Equatable {
  final String chatId;
  final List<String> messageIds;
  const DeleteBatchParams({required this.chatId, required this.messageIds});
  @override
  List<Object?> get props => [chatId, messageIds];
}

/// Eski mesaj sayfasi getir (pagination)
class GetOlderMessages
    implements UseCase<List<MessageEntity>, OlderMessagesParams> {
  final MessageRepository repository;
  GetOlderMessages(this.repository);
  @override
  Future<Either<Failure, List<MessageEntity>>> call(OlderMessagesParams p) =>
      repository.getOlderMessages(p.chatId, p.before);
}

class OlderMessagesParams extends Equatable {
  final String chatId;
  final DateTime before;
  const OlderMessagesParams({required this.chatId, required this.before});
  @override
  List<Object?> get props => [chatId, before];
}
