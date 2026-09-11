import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/message_entity.dart';

/// Mesaj veri erişiminin SÖZLEŞMESİ (soyut arayüz).
///
/// Domain katmanı bu arayüze bağımlıdır, implementasyona değil.
/// Implementasyon (MessageRepositoryImpl) data katmanındadır.
/// Bu "Dependency Inversion" — yüksek seviye modül (domain) düşük
/// seviye detaya (Firestore) bağımlı olmaz; ikisi de soyutlamaya bağlanır.
///
/// Tüm metodlar Either<Failure, T> döndürür: sol taraf hata,
/// sağ taraf başarı. Exception fırlatılmaz.
abstract class MessageRepository {
  /// Bir sohbetteki mesajları canlı dinle
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(String chatId);

  /// Metin mesajı gönder
  Future<Either<Failure, Unit>> sendTextMessage({
    required String chatId,
    required String text,
    String? replyToId,
    String? replyToPreview,
    int? disappearAfterSeconds,
  });

  /// Medya mesajı gönder (resim, ses, dosya)
  Future<Either<Failure, Unit>> sendMediaMessage({
    required String chatId,
    required String localFilePath,
    required MessageContentType type,
    String? fileName,
    String? replyToId,
    String? replyToPreview,
    String? mediaSource,
    bool viewOnce,
    int? voiceDurationMs,
  });

  /// Mesajı sil (her iki taraftan)
  /// Eski mesaj sayfasi getir (pagination).
  Future<Either<Failure, List<MessageEntity>>> getOlderMessages(
      String chatId, DateTime before);

  /// Sohbetteki tum mesajlari sil (her iki taraf).
  Future<Either<Failure, Unit>> clearChat(String chatId);

  /// 'Benden sil' (tek/toplu): yalnizca mevcut kullanici icin gizle.
  Future<Either<Failure, Unit>> deleteForMe(
      String chatId, List<String> messageIds);

  /// 'Herkesten sil' (tek/toplu): tum katilimcilar icin soft-delete.
  Future<Either<Failure, Unit>> deleteForEveryone(
      String chatId, List<String> messageIds);

  Future<Either<Failure, Unit>> deleteMessage({
    required String chatId,
    required String messageId,
  });

  /// Mesajı düzenle
  Future<Either<Failure, Unit>> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  });

  /// Mesajları okundu işaretle
  Future<Either<Failure, Unit>> markAsRead(String chatId);

  /// Reaksiyon ayarla (emoji bos ise kaldirir).
  Future<Either<Failure, Unit>> setReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  });

  /// GIF mesaji gonder (URL ile — yukleme gerektirmez, Giphy'den gelir).
  Future<Either<Failure, Unit>> sendGifMessage({
    required String chatId,
    required String gifUrl,
    bool sticker = false,
  });

  /// 📊 Anket gonder (soru + 2-6 secenek; oylar mesaj dokumaninda).
  Future<Either<Failure, Unit>> sendPollMessage({
    required String chatId,
    required String question,
    required List<String> options,
  });

  /// Tek goruntuluk fotoyu tuket: Storage'dan sil + dokumandan mediaUrl temizle.
  Future<Either<Failure, Unit>> consumeViewOnce({
    required String chatId,
    required String messageId,
    required String mediaUrl,
  });
}
