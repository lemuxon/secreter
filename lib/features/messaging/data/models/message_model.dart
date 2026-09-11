import '../../domain/entities/message_entity.dart';

/// Mesajın DATA temsili (DTO).
/// Domain entity'sini extend eder, Firestore serileştirmesi ekler.
///
/// Bu ayrım sayesinde: Firestore şeması değişirse sadece bu dosya
/// değişir, domain ve UI etkilenmez.
class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    required super.senderUsername,
    required super.content,
    required super.type,
    required super.timestamp,
    super.status,
    super.isDeleted,
    super.isEdited,
    super.editedAt,
    super.isEncrypted,
    super.mediaUrl,
    super.mediaKey,
    super.mediaSource,
    super.viewOnce,
    super.voiceDurationMs,
    super.pollOptions,
    super.pollVotes,
    super.pollClosed,
    super.fileName,
    super.fileSizeBytes,
    super.replyToId,
    super.replyToPreview,
    super.disappearAfterSeconds,
    super.expiresAt,
    super.reactions,
    super.readBy,
    super.deletedFor,
    this.e2eeHeader,
  });

  /// E2EE oturum baslatma basligi (yalnizca ilk mesajda dolu olur).
  /// Transport detayi oldugu icin sadece data katmaninda tutulur.
  final Map<String, dynamic>? e2eeHeader;

  /// Firestore map'inden model oluştur
  factory MessageModel.fromMap(Map<String, dynamic> map, String chatId) {
    return MessageModel(
      id: map['id'] ?? '',
      chatId: chatId,
      senderId: map['senderId'] ?? '',
      senderUsername: map['senderUsername'] ?? '',
      content: map['content'] ?? '',
      type: _parseType(map['type']),
      pollOptions:
          (map['pollOptions'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      // `(v as num)` karışık tipli bir oy haritasında patlıyordu; artık
      // güvenli dönüşüm yapılır (bir bozuk oy tüm sohbeti düşürmesin).
      pollVotes: ((map['pollVotes'] as Map?) ?? const {}).map<String, int>(
        (k, v) => MapEntry(
          k.toString(),
          v is num ? v.toInt() : (int.tryParse(v.toString()) ?? 0),
        ),
      ),
      pollClosed: map['pollClosed'] == true,
      // Sunucuda UTC saklanır; yerel saate çevirerek arayüze veriyoruz.
      timestamp: (DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now())
          .toLocal(),
      status: _parseStatus(map['status']),
      isDeleted: map['isDeleted'] ?? false,
      isEdited: map['isEdited'] ?? false,
      editedAt: map['editedAt'] == null
          ? null
          : DateTime.tryParse(map['editedAt'].toString())?.toLocal(),
      isEncrypted: map['isE2EE'] ?? false,
      mediaUrl: map['mediaUrl'],
      mediaSource: map['mediaSource'],
      viewOnce: map['viewOnce'] == true,
      voiceDurationMs: map['voiceDurationMs'],
      fileName: map['fileName'],
      fileSizeBytes: map['fileSizeBytes'],
      replyToId: map['replyTo']?['messageId'],
      replyToPreview: map['replyTo']?['preview'],
      disappearAfterSeconds: map['disappearAfterSeconds'],
      expiresAt: DateTime.tryParse(map['expiresAt'] ?? '')?.toLocal(),
      e2eeHeader: (map['e2eeHeader'] as Map?)?.cast<String, dynamic>(),
      reactions: _parseReactions(map['reactions']),
      readBy: _stringList(map['readBy']),
      deletedFor: _stringList(map['deletedFor']),
    );
  }

  /// Tepkileri HER İKİ eski şemadan da oku.
  ///
  /// ⚠️ NEDEN GEREKLİ: Bu alana geçmişte üç farklı üretici yazdı —
  /// eski `ChatService` LİSTE (`[{emoji,userId,username}]`), yeni katman ve
  /// Cloud Function ise HARİTA (`{uid: emoji}`). Ham `as Map` cast'i karşı
  /// şemayla karşılaşınca TypeError fırlatıyor, bu hata `watchMessages`
  /// akışını düşürüyor ve SOHBET EKRANI HİÇ AÇILMIYORDU. Artık iki biçim de
  /// tolere edilir ve haritaya normalize edilir.
  static Map<String, String> _parseReactions(Object? raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    if (raw is List) {
      final out = <String, String>{};
      for (final e in raw) {
        if (e is Map) {
          final uid = e['userId']?.toString();
          final emoji = e['emoji']?.toString();
          if (uid != null && uid.isNotEmpty && emoji != null) {
            out[uid] = emoji;
          }
        }
      }
      return out;
    }
    return const {};
  }

  /// Dizi alanlarını güvenli oku — `cast<String>()` karışık tipli bir
  /// dizide çalışma anında patlıyordu.
  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList();
  }

  /// Firestore'a yazmak için map
  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        // ⚠️ `senderUsername` BİLEREK YAZILMIYOR — metadata gizliliği.
        //
        // Her mesajda gönderenin ADININ düz metin durması, içerik
        // şifreli olsa bile sunucuya sosyal grafiği okunabilir hâlde
        // veriyordu ("@ayse → @mehmet, 14:32"). Ad artık gösterim
        // anında uid'den çözülür (bkz. UsernameResolver).
        //
        // `fromMap` alanı OKUMAYA devam eder: bu değişiklikten ÖNCE
        // yazılmış mesajlarda dolu ve orada bırakılır.
        'content': content,
        'type': type.name,
        if (pollOptions.isNotEmpty) 'pollOptions': pollOptions,
        if (pollOptions.isNotEmpty) 'pollVotes': pollVotes,
        if (pollOptions.isNotEmpty) 'pollClosed': pollClosed,
        // UTC: yerel saat yazmak, farklı saat dilimlerindeki kullanıcılar
        // arasında mesaj sıralamasını bozuyordu (ISO dizeleri sözlükbilimsel
        // karşılaştırılır ve sunucu sorguları bu alanla orderBy yapar).
        'timestamp': timestamp.toUtc().toIso8601String(),
        'status': status.name,
        'isDeleted': isDeleted,
        'isEdited': isEdited,
        if (editedAt != null) 'editedAt': editedAt!.toUtc().toIso8601String(),
        'isE2EE': isEncrypted,
        'mediaUrl': mediaUrl,
        'mediaSource': mediaSource,
        'viewOnce': viewOnce,
        'voiceDurationMs': voiceDurationMs,
        'fileName': fileName,
        'fileSizeBytes': fileSizeBytes,
        if (replyToId != null)
          'replyTo': {'messageId': replyToId, 'preview': replyToPreview},
        'disappearAfterSeconds': disappearAfterSeconds,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        if (e2eeHeader != null) 'e2eeHeader': e2eeHeader,
        'reactions': reactions,
        'readBy': readBy,
        'deletedFor': deletedFor,
      };

  /// İçeriği değiştirilmiş kopya (çözülmüş metin için).
  ///
  /// [mediaKey] medya mesajlarında, çözülen içerikten çıkarılan ek
  /// anahtarını taşır. Bu alan Firestore'a YAZILMAZ; yalnızca bellekte
  /// yaşar ve görüntüleme katmanına iletilir.
  /// Gönderen adını YERELDE çözülmüş adla doldur.
  ///
  /// Ad sunucudan gelmediği için gösterim katmanı onu uid'den çözer.
  /// Alan zaten doluysa (eski mesaj) dokunulmaz.
  MessageModel withResolvedSender(String? username) {
    if (senderUsername.isNotEmpty || username == null || username.isEmpty) {
      return this;
    }
    return copyWithContent(content, senderUsername: username);
  }

  /// İçeriği değiştiren kopya — DİĞER TÜM ALANLAR taşınır.
  ///
  /// ⚠️ BURAYA ALAN EKLERKEN LİSTEYİ GÜNCELLE. Bu metot dört alanı
  /// (`pollOptions`, `pollVotes`, `pollClosed`, `e2eeHeader`) taşımıyordu
  /// ve bedeli ağırdı (§4az):
  ///
  ///  • `withResolvedSender` her GELEN mesajı, daha ÇÖZÜLMEDEN önce
  ///    buradan geçiriyor (§4k: `senderUsername` sunucuya yazılmıyor,
  ///    uid'den çözülüyor). Düşen `e2eeHeader` yüzünden alıcı X3DH
  ///    oturumunu kuramıyor → "bu mesaj bu cihazda çözülemiyor", ve ek
  ///    anahtarı şifreli içerikte taşındığı için MEDYA DA açılmıyordu.
  ///  • Anket seçenekleri düşünce alıcıda oylanacak bir şey kalmıyordu.
  ///
  /// Kendi mesajlarımızda ad zaten dolu olduğu için bu dal hiç
  /// çalışmıyor — arızanın neden yalnızca KARŞI TARAFTA göründüğünün
  /// sebebi buydu. Kapı: `test/.../copy_with_content_test.dart`.
  MessageModel copyWithContent(String newContent,
      {String? mediaKey, String? senderUsername}) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      content: newContent,
      mediaKey: mediaKey ?? this.mediaKey,
      type: type,
      timestamp: timestamp,
      status: status,
      isDeleted: isDeleted,
      isEdited: isEdited,
      editedAt: editedAt,
      isEncrypted: isEncrypted,
      mediaUrl: mediaUrl,
      mediaSource: mediaSource,
      viewOnce: viewOnce,
      voiceDurationMs: voiceDurationMs,
      pollOptions: pollOptions,
      pollVotes: pollVotes,
      pollClosed: pollClosed,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      replyToId: replyToId,
      replyToPreview: replyToPreview,
      disappearAfterSeconds: disappearAfterSeconds,
      expiresAt: expiresAt,
      reactions: reactions,
      readBy: readBy,
      deletedFor: deletedFor,
      e2eeHeader: e2eeHeader,
    );
  }

  /// Yalnızca teslim durumunu değiştiren kopya. TÜM alanları taşır.
  MessageModel copyWithStatus(MessageDeliveryStatus newStatus) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderUsername: senderUsername,
      content: content,
      type: type,
      timestamp: timestamp,
      status: newStatus,
      isDeleted: isDeleted,
      isEdited: isEdited,
      editedAt: editedAt,
      isEncrypted: isEncrypted,
      mediaUrl: mediaUrl,
      mediaKey: mediaKey,
      mediaSource: mediaSource,
      viewOnce: viewOnce,
      voiceDurationMs: voiceDurationMs,
      pollOptions: pollOptions,
      pollVotes: pollVotes,
      pollClosed: pollClosed,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      replyToId: replyToId,
      replyToPreview: replyToPreview,
      disappearAfterSeconds: disappearAfterSeconds,
      expiresAt: expiresAt,
      reactions: reactions,
      readBy: readBy,
      deletedFor: deletedFor,
      e2eeHeader: e2eeHeader,
    );
  }

  static MessageContentType _parseType(String? raw) {
    return MessageContentType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => MessageContentType.text,
    );
  }

  static MessageDeliveryStatus _parseStatus(String? raw) {
    return MessageDeliveryStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => MessageDeliveryStatus.sent,
    );
  }
}
