import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/usecases/watch_messages.dart';
import '../../domain/usecases/send_text_message.dart';
import '../../domain/usecases/manage_message.dart';
import '../state/messaging_state.dart';
import '../../../../services/block_service.dart';
import '../../../../services/auth_service.dart';

/// Belirli bir sohbetin mesaj durumunu yöneten Notifier.
///
/// UI olaylarını alır → use case'leri çağırır → state'i günceller.
/// UI sadece bu notifier'ı dinler, repository/datasource'u hiç görmez.
class MessagingNotifier extends StateNotifier<MessagingState> {
  final String chatId;

  // Use case'ler DI'dan çözülür
  final WatchMessages _watchMessages;
  final SendTextMessage _sendTextMessage;
  final DeleteMessage _deleteMessage;
  final EditMessage _editMessage;
  final SetReaction _setReaction;
  final SendMediaMessage _sendMediaMessage;
  final ConsumeViewOnce _consumeViewOnce;
  final SendGifMessage _sendGifMessage;
  final SendPollMessage _sendPollMessage;
  final MarkAsRead _markAsRead;
  final ClearChat _clearChat;
  final DeleteForMe _deleteForMe;
  final DeleteForEveryone _deleteForEveryone;
  final GetOlderMessages _getOlder;

  StreamSubscription? _messagesSub;

  MessagingNotifier(this.chatId)
      : _watchMessages = getIt<WatchMessages>(),
        _sendTextMessage = getIt<SendTextMessage>(),
        _deleteMessage = getIt<DeleteMessage>(),
        _editMessage = getIt<EditMessage>(),
        _setReaction = getIt<SetReaction>(),
        _sendMediaMessage = getIt<SendMediaMessage>(),
        _consumeViewOnce = getIt<ConsumeViewOnce>(),
        _sendGifMessage = getIt<SendGifMessage>(),
        _sendPollMessage = getIt<SendPollMessage>(),
        _markAsRead = getIt<MarkAsRead>(),
        _clearChat = getIt<ClearChat>(),
        _deleteForMe = getIt<DeleteForMe>(),
        _deleteForEveryone = getIt<DeleteForEveryone>(),
        _getOlder = getIt<GetOlderMessages>(),
        super(MessagingState.initial()) {
    _startWatching();
  }

  /// Mesajları canlı dinlemeye başla
  /// Yuklenmis eski sayfalar (canli pencerenin oncesi).
  List<MessageEntity> _older = [];

  /// Yukari kaydirinca eski mesaj sayfasi yukle. Ekrandan cagrilir.
  Future<void> loadOlder() async {
    if (state.isLoadingMore || !state.hasMore || state.messages.isEmpty) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    final before = state.messages.first.timestamp;
    final result =
        await _getOlder(OlderMessagesParams(chatId: chatId, before: before));
    result.fold(
      (f) => state = state.copyWith(isLoadingMore: false, error: f.message),
      (older) {
        if (older.isNotEmpty) {
          final byId = <String, MessageEntity>{
            for (final m in older) m.id: m,
            for (final m in _older) m.id: m,
          };
          _older = byId.values.toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }
        final byId = <String, MessageEntity>{
          for (final m in _older) m.id: m,
          for (final m in state.messages) m.id: m,
        };
        final merged = byId.values.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        state = state.copyWith(
          messages: merged,
          isLoadingMore: false,
          // 50'den az geldiyse gecmisin sonuna ulasildi
          hasMore: older.length >= 50,
        );
      },
    );
  }

  void _startWatching() {
    // NOT: markAsRead BILEREK burada cagrilmiyor. Notifier, hesap gecisi
    // sirasindaki invalidate ile YENI hesabin kimligiyle hayalet olarak
    // yeniden kurulabiliyor ve rozeti daha dogmadan sifirliyordu. Okundu
    // isaretleme yalnizca EKRAN acilisindan tetiklenir (gercek niyet).
    // EMNIYET AGI: 6 sn icinde akistan hicbir sey gelmezse yukleniyor
    // durumunu kapat (yeni acilan kanal/sohbette bos ekran gorunsun).
    Timer(const Duration(seconds: 6), () {
      if (mounted && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    });

    _messagesSub = _watchMessages(chatId).listen((either) {
      either.fold(
        (failure) => state = state.copyWith(
          isLoading: false,
          error: failure.message,
        ),
        (messages) {
          // PAGINATION birlestirme: yuklenmis eski sayfalar + canli pencere.
          // id ile tekillestir (kesisme olabilir), zamana gore ARTAN sirala.
          final byId = <String, MessageEntity>{
            for (final m in _older) m.id: m,
            for (final m in messages) m.id: m,
          };

          // ⚡ İYİMSER BALONLARI KORU
          //
          // Gönderilen mesaj anında listeye eklenir ('pending_' önekli).
          // Sunucudan GERÇEK kaydı gelene kadar listede kalmalı, yoksa
          // balon bir görünüp kaybolur. Aynı içerik sunucudan geldiyse
          // geçici olan elenir (tekilleştirme).
          final serverTexts =
              messages.map((m) => '${m.senderId}|${m.content}').toSet();
          for (final p in state.messages) {
            if (!p.id.startsWith('pending_')) continue;
            if (serverTexts.contains('${p.senderId}|${p.content}')) continue;
            byId[p.id] = p;
          }

          final ordered = byId.values.toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          state = state.copyWith(
            messages: ordered,
            isLoading: false,
            clearError: true,
          );
        },
      );
    });
  }

  /// Metin mesajı gönder
  /// Birebir sohbetin karsi tarafi (chatId = siralı uid1_uid2).
  /// Grup/kanal ise null doner.
  String? _otherUidOfDirectChat() {
    final myUid = AuthService.currentUid;
    if (myUid == null) return null;
    final parts = chatId.split('_');
    if (parts.length != 2) return null;

    // KENDİ KENDİNE SOHBET (uid_uid): karşı taraf YOK.
    // Eskiden burada kendi kimliğim dönüyordu; E2EE kendi kendine
    // oturum kurmaya çalışıp takılıyordu — mesaj gönderilmiş
    // görünmüyor, uygulama yeniden açılınca beliriyordu.
    if (parts[0] == parts[1]) return null;

    if (parts[0] == myUid) return parts[1];
    if (parts[1] == myUid) return parts[0];
    return null;
  }

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;

    // 🛡️ ENGEL KAPISI: birebir sohbette engel varsa gönderme.
    // (Cift yonlu: ben engelledim VEYA o beni engelledi.)
    final other = _otherUidOfDirectChat();
    if (other != null) {
      final myUid = AuthService.currentUid;
      if (myUid != null &&
          await BlockService.isBlockedEitherWay(myUid, other)) {
        state = state.copyWith(error: 'cannot_send_blocked');
        return;
      }
    }

    // Düzenleme modundaysak güncelle
    if (state.editingMessage != null) {
      final msg = state.editingMessage!;
      state = state.copyWith(clearEdit: true);
      final result = await _editMessage(EditMessageParams(
        chatId: chatId,
        messageId: msg.id,
        newText: text,
      ));
      result.fold(
        (f) => state = state.copyWith(error: f.message),
        (_) {},
      );
      return;
    }

    // ⚡ İYİMSER GÖSTERİM
    //
    // SORUN: Mesaj gönderilince ekrana HİÇBİR ŞEY eklenmiyordu; balon
    // ancak sunucudan geri geldiğinde görünüyordu. Yeni açılan bir
    // kanal/sohbette dinleyici henüz kurulmadığı için bu bekleme
    // saniyeler sürebiliyor ve mesaj "geç geliyor" gibi hissettiriyordu.
    //
    // ÇÖZÜM: Mesaj ANINDA listeye eklenir (gönderiliyor durumunda).
    // Sunucudan gerçek kayıt gelince aynı içerik tekilleştirilir.
    final myUid = AuthService.currentUid;
    // ── YANIT ÇUBUĞU ANINDA KAPANIR (§4bf) ──
    //
    // 🐞 GERÇEK KULLANICIDA GÖRÜLDÜ: *"yanıtı gönderince yarım saniye
    // daha yanıt önizlemesi görünüyor."* Sebep: `clearReply` yalnızca
    // `await _sendTextMessage(...)` DÖNDÜKTEN sonra uygulanıyordu, yani
    // çubuk ağ gecikmesi kadar ekranda kalıyordu.
    //
    // Yanıt bilgisi önce yerel değişkene alınır; böylece çubuk hemen
    // kapansa da gönderilen mesaj alıntısını KAYBETMEZ.
    final yanitlanan = state.replyingTo;
    final yanitId = yanitlanan?.id;
    final yanitOnizleme = yanitlanan?.preview;

    final tempId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    if (myUid != null) {
      final pending = MessageEntity(
        id: tempId,
        chatId: chatId,
        senderId: myUid,
        senderUsername: '',
        content: text,
        type: MessageContentType.text,
        timestamp: DateTime.now(),
        status: MessageDeliveryStatus.sending,
        isEncrypted: false,
        replyToId: yanitId,
        replyToPreview: yanitOnizleme,
      );
      state = state.copyWith(
        messages: [...state.messages, pending],
        isSending: true,
        clearReply: true,
      );
    } else {
      state = state.copyWith(isSending: true, clearReply: true);
    }

    final result = await _sendTextMessage(SendTextParams(
      chatId: chatId,
      text: text,
      replyToId: yanitId,
      replyToPreview: yanitOnizleme,
      disappearAfterSeconds: state.disappearSeconds,
    ));

    result.fold(
      (failure) {
        // Gönderilemedi: geçici balonu KALDIR, hata göster ve YANITI
        // geri getir — kullanıcı alıntıyı yeniden kurmak zorunda kalmasın.
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != tempId).toList(),
          isSending: false,
          error: failure.message,
          replyingTo: yanitlanan,
          // ── YAZILAN METİN KAYBOLMAZ (§4bk) ──
          // Gönderim başarısızsa balon kaldırılıyordu ve kullanıcının
          // yazdığı metin HİÇBİR YERDE kalmıyordu: uzun bir mesaj
          // yazıp gönderememek, onu baştan yazmak demekti. Artık metin
          // geri verilir; ekran onu giriş kutusuna koyar.
          basarisizMetin: text,
        );
      },
      (_) => state = state.copyWith(
        isSending: false,
        clearError: true,
      ),
    );
  }

  /// Mesajı sil
  Future<void> deleteMessage(String messageId) async {
    final result = await _deleteMessage(DeleteMessageParams(
      chatId: chatId,
      messageId: messageId,
    ));
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (_) {},
    );
  }

  /// Secili mesajlari 'benden sil' (yalnizca ben).
  Future<bool> deleteForMe(List<String> ids) async {
    final r =
        await _deleteForMe(DeleteBatchParams(chatId: chatId, messageIds: ids));
    return r.fold((f) {
      state = state.copyWith(error: f.message);
      return false;
    }, (_) => true);
  }

  /// Secili mesajlari 'herkesten sil'.
  Future<bool> deleteForEveryone(List<String> ids) async {
    final r = await _deleteForEveryone(
        DeleteBatchParams(chatId: chatId, messageIds: ids));
    return r.fold((f) {
      state = state.copyWith(error: f.message);
      return false;
    }, (_) => true);
  }

  /// Sohbetteki tum mesajlari sil (her iki taraf).
  Future<bool> clearChat() async {
    final result = await _clearChat(chatId);
    return result.fold((f) {
      state = state.copyWith(error: f.message);
      return false;
    }, (_) => true);
  }

  /// Sohbet acildiginda ekrandan cagrilir: rozet sifirla + okundu isaretle.
  /// (Notifier yasam dongusunden BAGIMSIZ — her ekran acilisinda garanti.)
  void markAsReadNow() => _markAsRead(chatId);

  /// GIF gonder (Giphy URL).
  Future<void> sendGif(String gifUrl, {bool sticker = false}) async {
    final result = await _sendGifMessage(
        SendGifParams(chatId: chatId, gifUrl: gifUrl, sticker: sticker));
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (_) {},
    );
  }

  /// Sesli mesaj gonder.
  Future<void> sendVoice(String localPath, int durationMs) async {
    state = state.copyWith(isSending: true);
    final result = await _sendMediaMessage(SendMediaParams(
      chatId: chatId,
      localFilePath: localPath,
      type: MessageContentType.voice,
      voiceDurationMs: durationMs,
    ));
    result.fold(
      (f) => state = state.copyWith(isSending: false, error: f.message),
      (_) => state = state.copyWith(isSending: false, clearError: true),
    );
  }

  /// Fotograf gonder (aktif yanit varsa ona baglar).
  Future<void> sendPhoto(String localPath,
      {String? source, bool viewOnce = false}) async {
    // ⚡ İYİMSER GÖSTERİM (WhatsApp gibi)
    //
    // Fotoğraf ANINDA sohbete düşer ve "gönderiliyor" durumunda görünür;
    // yükleme arka planda sürer. Eskiden yükleme bitene kadar ekranda
    // hiçbir şey yoktu — büyük fotoğrafta saniyelerce belirsizlik.
    //
    // `mediaUrl` YEREL DOSYA YOLU: balon bunu doğrudan gösterebilir,
    // ağdan indirmeyi beklemez.
    final myUid = AuthService.currentUid;
    final tempId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    if (myUid != null) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          MessageEntity(
            id: tempId,
            chatId: chatId,
            senderId: myUid,
            senderUsername: '',
            content: '',
            type: MessageContentType.image,
            timestamp: DateTime.now(),
            status: MessageDeliveryStatus.sending,
            isEncrypted: false,
            mediaUrl: localPath, // yerel yol
            viewOnce: viewOnce,
          ),
        ],
        isSending: true,
      );
    } else {
      state = state.copyWith(isSending: true);
    }

    final result = await _sendMediaMessage(SendMediaParams(
      chatId: chatId,
      localFilePath: localPath,
      type: MessageContentType.image,
      replyToId: state.replyingTo?.id,
      replyToPreview: state.replyingTo?.preview,
      mediaSource: source,
      viewOnce: viewOnce,
    ));
    result.fold(
      (f) => state = state.copyWith(
        // Yükleme başarısız: geçici balonu kaldır
        messages: state.messages.where((m) => m.id != tempId).toList(),
        isSending: false,
        error: f.message,
      ),
      (_) => state =
          state.copyWith(isSending: false, clearReply: true, clearError: true),
    );
  }

  /// 📊 Anket gonder.
  Future<void> sendPoll(String question, List<String> options) async {
    state = state.copyWith(isSending: true);
    final result = await _sendPollMessage(
        SendPollParams(chatId: chatId, question: question, options: options));
    result.fold(
      (f) => state = state.copyWith(isSending: false, error: f.message),
      (_) => state = state.copyWith(isSending: false, clearError: true),
    );
  }

  /// 🎥 Video gonder (galeriden; oynatici uygulama icinde).
  Future<void> sendVideo(String localPath, String fileName,
      {bool viewOnce = false}) async {
    state = state.copyWith(isSending: true);
    final result = await _sendMediaMessage(SendMediaParams(
      chatId: chatId,
      localFilePath: localPath,
      type: MessageContentType.video,
      fileName: fileName,
      viewOnce: viewOnce,
      replyToId: state.replyingTo?.id,
      replyToPreview: state.replyingTo?.preview,
    ));
    result.fold(
      (f) => state = state.copyWith(isSending: false, error: f.message),
      (_) => state =
          state.copyWith(isSending: false, clearReply: true, clearError: true),
    );
  }

  /// #6 Dosya/belge gonder (PDF, ses, arsiv vb.).
  Future<void> sendFile(String localPath, String fileName) async {
    state = state.copyWith(isSending: true);
    final result = await _sendMediaMessage(SendMediaParams(
      chatId: chatId,
      localFilePath: localPath,
      type: MessageContentType.file,
      fileName: fileName,
      replyToId: state.replyingTo?.id,
      replyToPreview: state.replyingTo?.preview,
    ));
    result.fold(
      (f) => state = state.copyWith(isSending: false, error: f.message),
      (_) => state =
          state.copyWith(isSending: false, clearReply: true, clearError: true),
    );
  }

  /// Tek goruntuluk fotoyu tuket (Storage'dan siler, dokumani temizler).
  Future<void> consumeViewOnce(String messageId, String mediaUrl) async {
    await _consumeViewOnce(ConsumeViewOnceParams(
      chatId: chatId,
      messageId: messageId,
      mediaUrl: mediaUrl,
    ));
  }

  /// Reaksiyon ekle/kaldir (ayni emoji tekrar secilirse kaldirir).
  Future<void> setReaction(String messageId, String emoji) async {
    final result = await _setReaction(SetReactionParams(
      chatId: chatId,
      messageId: messageId,
      emoji: emoji,
    ));
    result.fold((f) => state = state.copyWith(error: f.message), (_) {});
  }

  /// Yanıtlama modunu ayarla
  void setReplyingTo(MessageEntity? message) {
    state = message == null
        ? state.copyWith(clearReply: true)
        : state.copyWith(replyingTo: message, clearEdit: true);
  }

  /// Düzenleme modunu ayarla
  void setEditing(MessageEntity? message) {
    state = message == null
        ? state.copyWith(clearEdit: true)
        : state.copyWith(editingMessage: message, clearReply: true);
  }

  /// Kaybolan mesaj süresini ayarla
  void setDisappearSeconds(int? seconds) {
    // TUM alanlar korunur (elle kurulum hasMore/isLoadingMore/error'i
    // dusurup pagination'i bozuyordu). disappearSeconds null olabildigi
    // icin copyWith yerine tam kurulum, ama eksiksiz.
    state = MessagingState(
      messages: state.messages,
      isLoading: state.isLoading,
      error: state.error,
      isSending: state.isSending,
      hasMore: state.hasMore,
      isLoadingMore: state.isLoadingMore,
      replyingTo: state.replyingTo,
      editingMessage: state.editingMessage,
      disappearSeconds: seconds,
    );
  }

  /// Hata mesajını temizle (gösterildikten sonra)
  void clearError() {
    // Metin ekrana geri konduktan sonra state'te tutulmaz;
    // aksi hâlde sonraki hatada eski metin yeniden basılırdı.
    state = state.copyWith(clearError: true, clearBasarisizMetin: true);
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }
}

/// Her sohbet için ayrı notifier (family — chatId parametreli).
/// autoDispose: ekran kapanınca otomatik temizlenir (bellek sızıntısı yok).
final messagingNotifierProvider = StateNotifierProvider.autoDispose
    .family<MessagingNotifier, MessagingState, String>(
  (ref, chatId) => MessagingNotifier(chatId),
);
