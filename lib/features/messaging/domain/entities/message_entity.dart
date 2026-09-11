import 'package:equatable/equatable.dart';

/// Mesajın domain temsili — Firestore'dan, JSON'dan, hiçbir
/// veri kaynağından bağımsız saf iş nesnesi.
///
/// Data katmanındaki MessageModel bunu extend eder ve
/// serileştirme (toMap/fromMap) ekler.
enum MessageContentType {
  text,
  image,
  gif,
  voice,
  file,
  video,
  location,
  poll,
  deleted
}

enum MessageDeliveryStatus { sending, sent, delivered, read, failed }

class MessageEntity extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String senderUsername;
  final String content;
  final MessageContentType type;
  final DateTime timestamp;
  final MessageDeliveryStatus status;
  final bool isDeleted;
  final bool isEdited;

  /// Son düzenleme zamanı.
  ///
  /// Firestore'a yazılıyordu ama modele HİÇ okunmuyordu. Artık okunuyor:
  /// düzenlenen mesajın düz metni bu damgayla ayrı bir önbellek
  /// anahtarına yazılır — aksi halde alıcı, eski metni önbellekten
  /// okumaya devam eder ve düzenlemeyi HİÇ görmez.
  final DateTime? editedAt;

  final bool isEncrypted;

  // Medya
  final String? mediaUrl;

  /// 🔐 Ek şifreleme anahtarı — YALNIZCA ÇALIŞMA ZAMANI.
  ///
  /// Firestore'a ASLA yazılmaz (`toMap` içinde yoktur). Anahtar, mesajın
  /// E2EE'li `content` alanının İÇİNDE taşınır (`ATT1|<anahtar>|`) ve
  /// çözme sırasında buraya yerleştirilir. Böylece sunucu şifreli medyayı
  /// saklar ama açacak anahtarı asla görmez.
  ///
  /// null ise ek ŞİFRESİZDİR (bu sürümden önce gönderilmiş mesajlar).
  final String? mediaKey;

  /// Medya kaynagi: 'gallery' | 'camera' (kose etiketi icin)
  final String? mediaSource;

  /// Tek goruntuluk foto (acilinca Storage'dan da silinir)
  final bool viewOnce;
  final int? voiceDurationMs;

  // 📊 ANKET: soru = content; secenekler + oylar (uid -> secenek indeksi).
  // Grup mesajlari gibi DUZ METIN (toplulastirma icin zorunlu odun).
  final List<String> pollOptions;
  final Map<String, int> pollVotes;
  final bool pollClosed;
  final String? fileName;
  final int? fileSizeBytes;

  // Yanıt
  final String? replyToId;
  final String? replyToPreview;

  // Kaybolan mesaj
  final int? disappearAfterSeconds;
  final DateTime? expiresAt;

  /// Emoji reaksiyonlar: {userId: emoji}. Her kullanici tek reaksiyon.
  final Map<String, String> reactions;

  /// Bu mesaji okuyan kullanicilar (grup 'kimler okudu' icin).
  final List<String> readBy;

  /// 'Benden sil': bu kullanicilar icin GIZLI (karsi taraf gormeye devam eder).
  final List<String> deletedFor;

  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderUsername,
    required this.content,
    required this.type,
    required this.timestamp,
    this.status = MessageDeliveryStatus.sent,
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    this.isEncrypted = false,
    this.mediaUrl,
    this.mediaKey,
    this.mediaSource,
    this.viewOnce = false,
    this.voiceDurationMs,
    this.pollOptions = const [],
    this.pollVotes = const {},
    this.pollClosed = false,
    this.fileName,
    this.fileSizeBytes,
    this.replyToId,
    this.replyToPreview,
    this.disappearAfterSeconds,
    this.expiresAt,
    this.reactions = const {},
    this.readBy = const [],
    this.deletedFor = const [],
  });

  /// Kaybolan mesaj süresi doldu mu? (iş kuralı domain'de yaşar)
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Bu mesaj belirli kullanıcı tarafından mı gönderildi?
  bool isSentBy(String userId) => senderId == userId;

  /// Önizleme metni (son mesaj, reply için)
  String get preview {
    if (isDeleted) return 'Silinen mesaj';
    switch (type) {
      case MessageContentType.image:
        return '🖼️ Fotoğraf';
      case MessageContentType.gif:
        return mediaSource == 'sticker' ? '🎟️ Çıkartma' : '🎬 GIF';
      case MessageContentType.voice:
        return '🎤 Sesli mesaj';
      case MessageContentType.video:
        return '🎥 Video';
      case MessageContentType.poll:
        return '📊 Anket';
      case MessageContentType.file:
        return '📎 ${fileName ?? "Dosya"}';
      case MessageContentType.location:
        return '📍 Konum';
      default:
        return content;
    }
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        content,
        type,
        timestamp,
        status,
        isDeleted,
        isEdited,
        editedAt,
        isEncrypted,
        mediaUrl,
        replyToId,
        expiresAt,
        reactions,
        readBy,
        deletedFor,
        voiceDurationMs,
        pollOptions,
        pollVotes,
        pollClosed,
        mediaSource,
        viewOnce,
        mediaKey,
      ];
}
