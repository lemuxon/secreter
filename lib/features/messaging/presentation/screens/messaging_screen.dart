import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
// `Source` adi hem audioplayers hem cloud_firestore'da var; ses
// kaynagi icin audioplayers'inki kullanilir.
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../conversations/presentation/providers/conversations_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/theme/chat_wallpaper.dart';
import '../../../../core/theme/chat_theme.dart';
import 'chat_background_screen.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/prefs/starred_messages.dart';
import '../../../../services/scheduled_message_service.dart';
import '../../../../services/disappearing_service.dart';
import '../../../../services/incognito_service.dart';
import '../../../../services/pinned_message_service.dart';
import '../../../../services/group_write_gate.dart';
import '../../../../services/translation_service.dart';
import '../../../../services/poll_service.dart';
import '../../../../core/prefs/hidden_messages.dart';
import 'video_player_screen.dart';
import '../../../../core/media/secure_media_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection.dart';
import '../../domain/usecases/manage_message.dart';
import '../../../../core/providers/active_chat_provider.dart';
import '../../../../core/widgets/full_screen_image.dart';
import '../../../../core/widgets/secure_media_image.dart';
import '../../../../core/media/video_trim_screen.dart';
import '../../../../core/media/video_trim_service.dart';
import '../../../../core/presence/presence.dart';
import '../../../../core/security/native_security_bridge.dart';
import '../../../../services/e2ee_session_service.dart';
import '../../../security/presentation/safety_number_screen.dart';
import '../../../../core/gif/giphy_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../settings/presentation/screens/user_profile_view.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/messaging_notifier.dart';
import '../providers/connectivity_provider.dart';
import '../state/messaging_state.dart';
import '../../../../utils/app_theme.dart';
import '../../../../widgets/common/frosted_surface.dart';
import '../../../group/presentation/screens/group_info_screen.dart';
import '../../../call/presentation/screens/call_screen.dart';
import '../../../call/presentation/screens/group_call_screen.dart';
import '../../../../services/self_note_service.dart';
import '../../../../models/call_model.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../services/block_service.dart';
import '../../../../core/widgets/safety_actions.dart';
import '../../../../core/prefs/chat_prefs.dart';
import '../../../settings/presentation/screens/blocked_users_screen.dart';
import '../../../../core/prefs/draft_service.dart';
import '../../../../services/username_resolver.dart';
import '../../../../services/privacy_service.dart';
import '../../../../core/privacy/privacy_controller.dart';
import '../../../../core/widgets/image_picker_helper.dart';
// PhotoEditorScreen doğrudan kullanılıyor (1047: fotoğraf düzenleyiciyi aç).
// Dart importları GEÇİŞLİ DEĞİLDİR: image_picker_helper bu dosyayı import
// etse de buradan erişilebilir kılmaz — ayrı import şart.
import '../../../../core/widgets/photo_editor_screen.dart';
import '../../../story/presentation/screens/story_viewer_screen.dart';
import '../../../story/data/models/story_model.dart';
import '../../../story/domain/entities/story_entity.dart';
import '../../../../core/media/upload_progress.dart';
import '../../../../core/security/security_alerts.dart';
import '../../../../services/group_key_service.dart';
import '../../../../core/observability/handled_error.dart';
import '../widgets/security_banners.dart';

/// Mesaj ekranı — "Buzlu Obsidyen" tasarımıyla (referans implementasyon).
///
/// Yenilikler (v14 UI):
/// - Buzlu cam üst çubuk + giriş çubuğu (içerik altından kayar)
/// - Avatar'da Hero animasyonu (sohbet listesi → sohbet geçişi için hazır)
/// - Mesajların yumuşak giriş animasyonu (azaltılmış-harekete saygılı)
/// - E2EE mesajlara "güvenli malzeme" dokunuşu (mint kenar + kilit)
/// - Yazarken büyüyen/renklenen gönder butonu (implicit animasyon)
class MessagingScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatTitle;
  final String myUid;
  final bool isGroup;

  const MessagingScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.myUid,
    this.isGroup = false,
  });

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasText = false;

  bool _didInitialJump = false;

  // Çoklu seçim modu
  final Set<String> _selectedIds = {};

  // Kendini imha: aktif süre (chat-genelinde), canli izlenir
  int? _disappearSeconds;
  StreamSubscription<int?>? _disappearSub;

  // Gizli sohbet (incognito): cikista iki taraftan temizlenir
  bool _incognito = false;
  StreamSubscription<bool>? _incognitoSub;

  String get _draftKey => 'draft_${widget.myUid}_${widget.chatId}';

  // TASARIM: gonderirken tek atimlik 'firlama' nabzi
  bool _sendPulse = false;

  // 🙈 gizlenen mesajlar bu oturumda gorunur mu (PIN ile acilir)
  bool _revealHidden = false;

  // 🗓 tarih-araligi arama filtresi
  DateTimeRange? _searchRange;

  // #14 @bahsetme: aktif oneri listesi (grup uyeleri) + kaynak
  List<String> _mentionSuggestions = [];
  List<String> _groupUsernames = [];

  /// 🗒️ KENDİNE SOHBET Mİ ("Notlarım")?
  ///
  /// Birebir sohbet gibi görünür ama karşı taraf YOKTUR: arama, güvenlik
  /// numarası ve kimlik uyarıları burada anlamsızdır — hepsi "karşı
  /// taraf" varsayar.
  bool get _kendineSohbet =>
      SelfNoteService.isSelfChat(widget.chatId, widget.myUid);

  // 📣 KANAL MI? `isGroup` hem grubu hem kanalı kapsıyor (ana ekran ikisini
  // de `isGroup: true` ile açıyor). Grup ARAMASI yalnızca gruplara ait bir
  // özellik: kanal yayın içindir, üye sayısı mesh'in sınırını çok aşabilir.
  // Sohbet dokümanı gelene kadar buton gösterilmez (varsayılan `true`).
  bool _isChannel = true;

  // #13: yazma kisiti sebebi (null = yazabilir; yalniz grup/kanal)
  String? _writeBlockReason;
  StreamSubscription<String?>? _writeGateSub;

  // 📌 Sabitlenmis mesaj (sohbet-genelinde)
  PinnedInfo? _pinned;
  StreamSubscription<PinnedInfo?>? _pinnedSub;
  bool get _selectionMode => _selectedIds.isNotEmpty;

  // Sohbet içi arama
  bool _searchActive = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentMatch = 0;

  // 🔍 Geçerli arama eşleşmesinin ekrandaki yerini bulmak için anahtar.
  // Oransal kaydırma (maxScrollExtent × index/total) yalnızca TAHMİNDİR:
  // mesaj yükseklikleri değişken olduğu için hedef mesaj sık sık ekran
  // dışında kalıyordu. Bu anahtarla kaydırma sonrası HASSAS düzeltme
  // yapılır (ensureVisible).
  final GlobalKey _currentMatchKey = GlobalKey();

  // Sesli mesaj kaydı
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordPath;

  // ✏️ TASLAK: gonderilmeyen metin sohbette kalir. Her tus vurusunda
  // diske yazmamak icin 600 ms gecikmeli kaydedilir.
  Timer? _draftTimer;

  // 🔐 Guvenlik numarasi durumu (yalnizca birebir sohbet).
  // Karsi tarafin kimlik anahtari degistiyse uyari bandi bundan cizilir.
  SafetyInfo? _safety;

  /// 🛡️ Grup anahtarı rotasyonu başarısız oldu mu? (bkz. SecurityAlerts)
  bool _keyRotationFailed = false;

  /// 🔓 Bu grupta mesajlar şifresiz mi gidiyor? (§4x'in kalan hâli)
  bool _groupPlaintext = false;

  /// Doğrulama önerisi bu sohbette kapatıldı mı?
  /// Yüklenene kadar `true` — yanıp sönen bir band göstermemek için.
  bool _verifyPromptDismissed = true;

  /// dispose() sirasinda `ref` kullanilamadigi icin initState'te yakalanir.
  late final StateController<String?> _activeChat;

  @override
  void initState() {
    super.initState();

    // 🐞 `dispose()` ICINDE `ref` KULLANILAMAZ (§4as).
    //
    // Eskiden dispose() su satirla basliyordu:
    //     if (ref.read(activeChatProvider) == widget.chatId) { ... }
    // ve Riverpod "Cannot use ref after the widget was disposed" firlatiyordu.
    // Cihaz gunlugunde dogrulandi. Istisna dispose'un GERI KALANINI iptal
    // ettigi icin `PresenceService.setTyping(null)` HIC calismiyordu —
    // yani sohbetten cikinca karsi taraf seni SUREKLI "yaziyor" goruyordu.
    // Ayrica ses kaydedici ve arama denetleyicisi de bosa dusmuyordu.
    //
    // Cozum: bildiriciyi burada yakala. `activeChatProvider` global bir
    // StateProvider (autoDispose degil), yani referansi tutmak guvenli.
    _activeChat = ref.read(activeChatProvider.notifier);

    // 🔐 Kimlik anahtari degisimi ekran acilir acilmaz gorunsun.
    if (!widget.isGroup && !_kendineSohbet) _refreshSafety();
    _refreshSecurityAlerts();

    // ✏️ Onceki taslagi geri yukle (varsa)
    DraftService.get(widget.chatId).then((t) {
      if (!mounted || t.isEmpty) return;
      // Kullanici bu arada yazmaya baslamissa dokunma
      if (_textController.text.isNotEmpty) return;
      _textController.text = t;
      setState(() => _hasText = true);
    });

    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
        // Yaziyor... bildirimi (yalnizca gecislerde yazilir — az Firestore)
        if (!widget.isGroup) {
          PresenceService.setTyping(has ? widget.chatId : null);
        }
      }
      if (widget.isGroup) _updateMentionSuggestions();

      // ✏️ Taslagi gecikmeli kaydet (yazma performansini bozmasin)
      _draftTimer?.cancel();
      _draftTimer = Timer(const Duration(milliseconds: 600), () {
        DraftService.save(widget.chatId, _textController.text);
      });
    });
    _scrollController.addListener(_maybeLoadOlder);
    // #4 TASLAK: yazilip gonderilmemis metni geri yukle
    SharedPreferences.getInstance().then((p) {
      final d = p.getString(_draftKey);
      if (!mounted || d == null || d.isEmpty) return;
      if (_textController.text.isNotEmpty) return;
      _textController.text = d;
      _textController.selection = TextSelection.collapsed(offset: d.length);
    });
    // Kendini imha süresini canli izle; hem gostergeyi hem gonderimi ayarla
    if (widget.isGroup) {
      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get()
          .then((d) async {
        // Kanal mı grup mu? Grup araması düğmesi buna bakar.
        final kanal = (d.data()?['type'] ?? '').toString() == 'channel';
        if (mounted && kanal != _isChannel) setState(() => _isChannel = kanal);
        // ── @BAHSETME KAYNAĞI (metadata gizliliği 2. aşama) ──
        // Sohbet dokümanı artık üye adlarını taşımıyor; öneri listesi
        // `memberIds` üzerinden uid → ad çözülerek kurulur.
        final ids = (d.data()?['memberIds'] as List?)
                ?.map((e) => e.toString())
                .where((u) => u.isNotEmpty)
                .toList() ??
            const <String>[];
        await UsernameResolver.warm(ids);
        final names = <String>{
          for (final id in ids) UsernameResolver.cached(id) ?? '',
          // Eski dokümanlarda ad dizisi hâlâ dolu olabilir; çözüm
          // başarısızsa (ağ yok) öneriler tamamen kaybolmasın.
          ...?(d.data()?['memberUsernames'] as List?)?.map((e) => e.toString()),
        }..removeWhere((u) => u.isEmpty);
        if (mounted) _groupUsernames = names.toList();
      });
      _writeGateSub =
          GroupWriteGate.watchBlockReason(widget.chatId, widget.myUid)
              .listen((reason) {
        if (!mounted || reason == _writeBlockReason) return;
        setState(() => _writeBlockReason = reason);
      });
    }
    _pinnedSub = PinnedMessageService.watch(widget.chatId).listen((p) {
      if (!mounted || p?.messageId == _pinned?.messageId) return;
      setState(() => _pinned = p);
    });
    _incognitoSub = IncognitoService.watch(widget.chatId).listen((on) {
      if (!mounted || on == _incognito) return;
      setState(() => _incognito = on);
    });
    _disappearSub = DisappearingService.watch(widget.chatId).listen((sec) {
      if (!mounted || sec == _disappearSeconds) return; // yalnizca DEGISIMDE
      setState(() => _disappearSeconds = sec);
      ref
          .read(messagingNotifierProvider(widget.chatId).notifier)
          .setDisappearSeconds(sec);
    });
    // Bu sohbet acikken bildirim gosterilmesin diye isaretle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeChatProvider.notifier).state = widget.chatId;
      // DM (birebir) sohbetlerde ekran görüntüsü koruması — ANCAK
      // kullanıcı tercihi kapalıysa UYGULANMAZ.
      //
      // ESKİ DAVRANIŞ: koruma "her zaman açık" idi; Ayarlar → Güvenlik →
      // "Ekran görüntüsünü engelle" kapatılsa bile sohbette ekran
      // görüntüsü alınamıyordu. Kapanmayan bir ayar, kullanıcıya yanlış
      // bilgi verir — ayarın söylediği şeyi yapması gerekir.
      if (!widget.isGroup) {
        PrivacyService.isScreenshotBlocked().then((blocked) {
          if (!mounted) return;
          if (blocked) {
            NativeSecurityBridge.acquire('dm_${widget.chatId}');
          } else {
            // Tercih kapalıysa varsa bırak (ayar sohbet açıkken değişmiş
            // olabilir)
            NativeSecurityBridge.release('dm_${widget.chatId}');
          }
        });
      }
      // HER ACILISTA rozet sifirla + okundu isaretle (notifier'in ne zaman
      // kuruldugundan bagimsiz — rozetin silinmeme sorununun kesin cozumu)
      ref
          .read(messagingNotifierProvider(widget.chatId).notifier)
          .markAsReadNow();
      // Bu sohbetin bekleyen bildirimini kapat (okundu)
      NotificationService.cancelForChat(widget.chatId);
      _jumpToBottom();
      // Gec yuklenen icerik (resim/ses) yuksekligi degistirebilir
      Future.delayed(const Duration(milliseconds: 400), _jumpToBottom);
    });
  }

  bool _loadingOlderNow = false;

  /// Yukari kaydirilinca eski sayfayi yukle; kaydirma POZISYONUNU KORU
  /// (yeni icerik uste eklenince liste ziplamasin).
  Future<void> _maybeLoadOlder() async {
    if (_loadingOlderNow) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels > 300) return;
    final st = ref.read(messagingNotifierProvider(widget.chatId));
    if (st.isLoadingMore || !st.hasMore || st.messages.isEmpty) return;
    _loadingOlderNow = true;
    final oldMax = _scrollController.position.maxScrollExtent;
    final oldPixels = _scrollController.position.pixels;
    await ref
        .read(messagingNotifierProvider(widget.chatId).notifier)
        .loadOlder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final delta = _scrollController.position.maxScrollExtent - oldMax;
        if (delta > 0) {
          _scrollController.jumpTo(oldPixels + delta);
        }
      }
      _loadingOlderNow = false;
    });
  }

  void _jumpToBottom() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent > 0) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _didInitialJump = true;
    }
  }

  @override
  void dispose() {
    // ✏️ Bekleyen taslagi ANINDA kaydet (gecikmeli timer calismadan
    // ekrandan cikilmis olabilir)
    _draftTimer?.cancel();
    DraftService.save(widget.chatId, _textController.text);

    // Aktif sohbet isaretini kaldir (tekrar bildirim alinabilsin).
    // ⚠️ `ref` DEGIL — initState'te yakalanan bildirici kullanilir.
    if (_activeChat.state == widget.chatId) {
      _activeChat.state = null;
    }
    if (!widget.isGroup) {
      PresenceService.setTyping(null);
      NativeSecurityBridge.release('dm_${widget.chatId}');
    }
    _recordTimer?.cancel();
    _recorder.dispose();
    _searchController.dispose();
    // #4 TASLAK: cikista kaydet (gizli sohbette IZ BIRAKMA — kaydetme)
    final draft = _textController.text;
    final saveDraft = !_incognito && draft.trim().isNotEmpty;
    final draftKey = _draftKey;
    SharedPreferences.getInstance().then((p) {
      if (saveDraft) {
        p.setString(draftKey, draft);
      } else {
        p.remove(draftKey);
      }
    });
    _textController.dispose();
    _scrollController.dispose();
    _disappearSub?.cancel();
    _incognitoSub?.cancel();
    _pinnedSub?.cancel();
    _writeGateSub?.cancel();
    // GIZLI SOHBET: ekrandan cikista tum mesajlar IKI TARAFTAN silinir.
    // ROBUST: _incognito bayragi stream-zamanlamasi yuzunden dispose aninda
    // senkron olmayabilir. Bu yuzden chat dokumanini DOGRUDAN okuyup
    // (authoritative) incognito ise temizleriz. Hatalar loglanir (sessiz
    // yutulmaz) ki bir daha kor kalmayalim.
    if (!widget.isGroup) {
      final cid = widget.chatId;
      Future<void> doClear() async {
        final r = await getIt<ClearChat>()(cid);
        r.fold(
          (f) => debugPrint('GIZLI SOHBET temizleme HATASI: ${f.message}'),
          (_) => debugPrint('GIZLI SOHBET temizlendi: $cid'),
        );
      }

      if (_incognito) {
        doClear();
      } else {
        // Bayrak false ise bile son durumu dokumandan dogrula (yedek)
        FirebaseFirestore.instance.collection('chats').doc(cid).get().then((d) {
          if (d.data()?['incognito'] == true) doClear();
          // onError: catchError'in donus tipi sorununu onler
        }, onError: (e) => debugPrint('gizli sohbet exit read: $e'));
      }
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('mic_permission'))),
          );
        }
        return;
      }
      final path =
          '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      _recordPath = path;
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('msg_deleted'))),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final duration = _recordSeconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _isRecording = false);
    path ??= _recordPath;
    if (path != null && duration >= 1) {
      await ref
          .read(messagingNotifierProvider(widget.chatId).notifier)
          .sendVoice(path, duration * 1000);
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _isRecording = false);
  }

  Widget _buildRecordingBar() {
    final m = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_recordSeconds % 60).toString().padLeft(2, '0');
    return FrostedSurface(
      intensity: 10, // PERFORMANS: canli blur maliyeti (bkz. FrostedTopBar)
      tint: AppTheme.background.withValues(alpha: 0.55),
      border: const Border(
        top: BorderSide(color: AppTheme.glassTint, width: 0.5),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.md, Spacing.sm, Spacing.sm, Spacing.sm),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                onPressed: _cancelRecording,
              ),
              const Icon(Icons.fiber_manual_record,
                  color: AppTheme.danger, size: 14),
              const SizedBox(width: 8),
              Text('${context.tr('recording')}  $m:$sec',
                  style: const TextStyle(color: AppTheme.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: _stopAndSendRecording,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        ref
                            .watch(effectiveBubbleThemeProvider(widget.chatId))
                            .a,
                        ref
                            .watch(effectiveBubbleThemeProvider(widget.chatId))
                            .b,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.arrow_upward_rounded,
                      color: Color(0xFF04141C), size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ── YANIT ALINTISINDAN ORİJİNALE ATLA (§4bp) ──
  ///
  /// Alıntı, neye yanıt verildiğini gösteriyor ama oraya götürmüyordu;
  /// bağlamı bulmak için elle yukarı kaydırmak gerekiyordu.
  ///
  /// ⚠️ Orijinal mesaj YÜKLÜ OLMAYABİLİR: liste sayfalı ve eski mesajlar
  /// henüz çekilmemiş olabilir. O durumda sessizce hiçbir şey yapmak
  /// "dokundum ama olmadı" hissi verirdi; kullanıcıya nedenini söylüyoruz.
  void _yanitlananaGit(String messageId) {
    final st = ref.read(messagingNotifierProvider(widget.chatId));
    final gosterilen = _display(st.messages);
    final index = gosterilen.indexWhere((m) => m.id == messageId);

    if (index < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('reply_target_missing')),
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    HapticFeedback.selectionClick();
    _scrollToIndex(index, gosterilen.length);
  }

  /// ── ÇİFT DOKUNUŞLA HIZLI TEPKİ (§4bg) ──
  ///
  /// Flutter'ın `onDoubleTap`'i KULLANILMAZ: o tanımlayıcı, ikinci
  /// dokunuşu beklemek için her tek dokunuşu ~300 ms geciktirir ve
  /// daha önce "yarım saniye sonra tepki veriyor" şikâyetine yol açmıştı.
  /// Burada süre elle ölçülür; tek dokunuşlar hiç yavaşlamaz.
  DateTime? _sonBaloncukDokunusu;
  String? _sonBaloncukId;

  static const _ciftDokunusPenceresi = Duration(milliseconds: 300);
  static const _hizliTepki = '👍';

  void _baloncugaDokunuldu(MessageEntity msg) {
    final simdi = DateTime.now();
    final ayniBalon = _sonBaloncukId == msg.id;
    final yeterinceHizli = _sonBaloncukDokunusu != null &&
        simdi.difference(_sonBaloncukDokunusu!) < _ciftDokunusPenceresi;

    if (ayniBalon && yeterinceHizli) {
      _sonBaloncukDokunusu = null;
      _sonBaloncukId = null;
      // Aynı emojiye tekrar çift dokunmak tepkiyi KALDIRIR.
      final mevcut = msg.reactions[widget.myUid];
      HapticFeedback.selectionClick();
      ref
          .read(messagingNotifierProvider(widget.chatId).notifier)
          .setReaction(msg.id, mevcut == _hizliTepki ? '' : _hizliTepki);
      return;
    }

    _sonBaloncukDokunusu = simdi;
    _sonBaloncukId = msg.id;
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    // firlama nabzi (130ms — maliyetsiz his dokunusu)
    setState(() => _sendPulse = true);
    Future.delayed(const Duration(milliseconds: 130), () {
      if (mounted) setState(() => _sendPulse = false);
    });
    _textController.clear();
    DraftService.clear(widget.chatId); // ✏️ taslak artik gereksiz
    if (!widget.isGroup) PresenceService.setTyping(null);
    ref.read(messagingNotifierProvider(widget.chatId).notifier).sendText(text);
  }

  /// ⏰ Yazili metni ileri tarihe zamanla (gonder butonuna uzun bas).
  Future<void> _scheduleCurrentText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: context.tr('send_date'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))),
      helpText: context.tr('send_time'),
    );
    if (time == null || !mounted) return;
    final sendAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!sendAt.isAfter(now.add(const Duration(seconds: 30)))) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('past_time'))));
      return;
    }
    try {
      await ScheduledMessageService.schedule(
          chatId: widget.chatId, content: text, sendAt: sendAt);
      if (!mounted) return;
      _textController.clear();
      DraftService.clear(widget.chatId); // ✏️ zamanlandı → taslak gitsin
      if (!widget.isGroup) PresenceService.setTyping(null);
      String two(int n) => n.toString().padLeft(2, '0');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⏰ ${context.tr('scheduled_msgs')}: '
            '${two(sendAt.day)}.${two(sendAt.month)} '
            '${two(sendAt.hour)}:${two(sendAt.minute)} '
            '${context.tr('plain_text_note')}'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('schedule_failed'))));
    }
  }

  /// #14 Imlecin solundaki @parca'ya gore oneri listesi guncelle.
  void _updateMentionSuggestions() {
    final sel = _textController.selection;
    if (!sel.isValid || sel.baseOffset < 0) {
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }
    final upToCursor = _textController.text.substring(0, sel.baseOffset);
    final match = RegExp(r'@(\w*)$').firstMatch(upToCursor);
    if (match == null) {
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }
    final q = match.group(1)!.toLowerCase();
    final myU = widget.myUid;
    final results = _groupUsernames
        .where((u) => u.toLowerCase().startsWith(q))
        .take(5)
        .toList();
    // kendini onerme
    results.removeWhere((u) => u.toLowerCase() == myU.toLowerCase());
    setState(() => _mentionSuggestions = results);
  }

  /// Secilen kullanici adini @parca'nin yerine yaz.
  void _applyMention(String username) {
    final sel = _textController.selection;
    final text = _textController.text;
    final upToCursor = text.substring(0, sel.baseOffset);
    final match = RegExp(r'@(\w*)$').firstMatch(upToCursor);
    if (match == null) return;
    final start = match.start;
    final newText =
        '${text.substring(0, start)}@$username ${text.substring(sel.baseOffset)}';
    _textController.text = newText;
    final pos = start + username.length + 2; // '@' + ' '
    _textController.selection = TextSelection.collapsed(offset: pos);
    setState(() => _mentionSuggestions = []);
  }

  Widget _buildMentionBar() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      color: AppTheme.surface,
      child: ListView(
        shrinkWrap: true,
        children: _mentionSuggestions
            .map((u) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.primary,
                    child: Text(u[0].toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF04141C), fontSize: 13)),
                  ),
                  title: Text('@$u',
                      style: const TextStyle(color: AppTheme.textPrimary)),
                  onTap: () => _applyMention(u),
                ))
            .toList(),
      ),
    );
  }

  /// #9 Gizli sohbet aç/kapa (onayli — acikken cikista iki taraftan silinir).
  Future<void> _toggleIncognito() async {
    if (widget.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('secret_chat_dm_only'))));
      return;
    }
    if (_incognito) {
      await IncognitoService.set(widget.chatId, false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('secret_chat_closed'))));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('secret_chat'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Açıkken:\n• Listede içerik önizlemesi gizlenir\n'
          '• Sohbetten HER ÇIKIŞTA tüm mesajlar iki taraftan da '
          'kalıcı olarak silinir (iz bırakmaz)\n\n'
          'Bu ayar iki taraf için de geçerlidir. Açılsın mı?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('open'),
                style: const TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await IncognitoService.set(widget.chatId, true);
    }
  }

  /// #1 Kaybolan mesaj süresi seçici (sohbet-genelinde).
  void _showDisappearSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kaybolan mesajlar',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                context.tr('disappearing_desc'),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12.5),
              ),
            ),
            ...DisappearingService.presets.entries.map((e) {
              final selected = (e.value == 0
                  ? (_disappearSeconds == null)
                  : (_disappearSeconds == e.value));
              return ListTile(
                leading: Icon(
                    e.value == 0
                        ? Icons.timer_off_outlined
                        : Icons.timer_outlined,
                    color:
                        selected ? AppTheme.primary : AppTheme.textSecondary),
                title: Text(context.tr(e.key),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                trailing: selected
                    ? const Icon(Icons.check, color: AppTheme.primary)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await DisappearingService.set(widget.chatId, e.value);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// ⏰ Bu sohbetteki bekleyen zamanlanmis mesajlarim.
  void _showScheduledSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 340,
          child: StreamBuilder<List<ScheduledItem>>(
            stream: ScheduledMessageService.watchForChat(widget.chatId),
            builder: (context, snap) {
              final items = snap.data ?? const <ScheduledItem>[];
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    context.tr('no_scheduled'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }
              String two(int n) => n.toString().padLeft(2, '0');
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = items[i];
                  final t = it.sendAt;
                  return ListTile(
                    leading: const Icon(Icons.schedule_send,
                        color: AppTheme.primary),
                    title: Text(it.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text(
                        '${two(t.day)}.${two(t.month)}.${t.year}  ${two(t.hour)}:${two(t.minute)}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.danger),
                      tooltip: context.tr('cancel_action'),
                      onPressed: () => ScheduledMessageService.cancel(it.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Mesaji baska bir sohbete ilet (metin).
  void _showForwardPicker(String content) {
    if (content.trim().isEmpty) return;
    final conversations = ref.read(conversationsNotifierProvider).conversations;
    if (conversations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('no_forward_chat'))),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(context.tr('msg_forward'),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: conversations.map((c) {
                  final title = c.displayTitle(widget.myUid);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary,
                      child: Text(c.avatarLetter(widget.myUid),
                          style: const TextStyle(
                              color: Color(0xFF04141C),
                              fontWeight: FontWeight.w700)),
                    ),
                    title: Text(title,
                        style: const TextStyle(color: AppTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      ref
                          .read(messagingNotifierProvider(c.id).notifier)
                          .sendText(content);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('$title → ${context.tr('msg_forward')}')),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Galeriden foto sec ve gonder (aktif yanit varsa ona baglanir).
  void _showGifPicker({bool sticker = false}) {
    // Anahtar yoksa boş bir ızgara yerine NEDENİNİ söyle.
    if (!GiphyService.isEnabled) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surface,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gif_box_outlined,
                    color: AppTheme.textSecondary, size: 40),
                const SizedBox(height: 14),
                Text(
                  context.tr('gif_unavailable'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('gif_unavailable_detail'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => _GifPicker(
        initialSticker: sticker,
        onSelected: (url, sticker) {
          Navigator.pop(context);
          ref
              .read(messagingNotifierProvider(widget.chatId).notifier)
              .sendGif(url, sticker: sticker);
        },
      ),
    );
  }

  void _showPhotoSourceMenu() {
    bool viewOnce = false;
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: viewOnce,
                onChanged: (v) => setSheet(() => viewOnce = v),
                activeThumbColor: AppTheme.primary,
                secondary: const Icon(Icons.visibility_off_outlined,
                    color: AppTheme.primary),
                title: Text(context.tr('once_view'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text(context.tr('once_view_sub'),
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              const Divider(height: 1),
              // 📷 TEK GİRİŞ: galeri (fotoğraf + video bir arada)
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppTheme.primary),
                title: Text(context.tr('gallery'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text(context.tr('photo_or_video'),
                    style: const TextStyle(color: AppTheme.textSecondary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery(viewOnce);
                },
              ),
              // 📸 KAMERA: fotoğraf çek veya video kaydet — ikisi de
              // burada. Eskiden 4 ayrı satır vardı; kullanıcı önce
              // "fotoğraf mı video mu" diye düşünmek zorundaydı.
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppTheme.primary),
                title: Text(context.tr('camera'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text(context.tr('photo_or_video'),
                    style: const TextStyle(color: AppTheme.textSecondary)),
                onTap: () {
                  Navigator.pop(context);
                  _openCamera(viewOnce);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🎥 Video kaynagi: galeri veya kamera (fotograf menusuyle ayni desen).
  ///
  /// ⚠️ TEK GÖRÜNTÜLÜK ANAHTARI EKLENDİ.
  /// Görüntüleme tarafı video için tek-görüntülüğü zaten destekliyordu
  /// (bulanık önizleme + izlenince Storage'dan silme), ama bu menüde
  /// anahtar YOKTU: `_pickAndSendVideo` her zaman `viewOnce: false` ile
  /// çağrılıyordu. Yani özellik fotoğrafta çalışıyor, videoda kullanıcıya
  /// hiç sunulmuyordu.
  void _showVideoSourceMenu() {
    bool viewOnce = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: viewOnce,
                onChanged: (v) => setSheet(() => viewOnce = v),
                activeThumbColor: AppTheme.primary,
                secondary: const Icon(Icons.visibility_off_outlined,
                    color: AppTheme.primary),
                title: Text(context.tr('once_view'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text(context.tr('once_view_sub'),
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.video_library_outlined,
                    color: AppTheme.primary),
                title: Text(context.tr('pick_gallery'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendVideo(fromCamera: false, viewOnce: viewOnce);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: AppTheme.primary),
                title: Text(context.tr('record_video'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendVideo(fromCamera: true, viewOnce: viewOnce);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 🎥 Video sec ve gonder (galeriden, 50 MB siniri).
  Future<void> _pickAndSendVideo(
      {bool fromCamera = false, bool viewOnce = false}) async {
    final picked = await ImagePicker().pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );
    if (picked == null || !mounted) return;
    await _sendVideoFile(picked, viewOnce);
  }

  /// Video gönderme — boyut kontrolü + uyarı + gönderim.
  /// Hem galeri hem kamera yolundan çağrılır (kod tekrarı olmasın).
  Future<void> _sendVideoFile(XFile picked, bool viewOnce) async {
    const maxBytes = 500 * 1024 * 1024; // 500 MB (sert sinir)
    const warnBytes = 50 * 1024 * 1024; // 50 MB uzeri: uyar

    // 🎬 KIRPMA EKRANI
    //
    // Eskiden seçilen video DOĞRUDAN gidiyordu; kullanıcının tek seçeneği
    // ya tamamını göndermek ya da vazgeçmekti. Uzun kayıtlarda bu hem
    // dakikalarca yükleme hem yüksek depolama gideri demekti. Artık
    // istediği bölümü seçebilir (aralığa dokunmazsa hiçbir işlem yapılmaz).
    var path = picked.path;
    if (VideoTrimService.isSupported && mounted) {
      final trimmed = await VideoTrimScreen.open(context, path);
      if (trimmed == null) return; // kullanıcı vazgeçti
      path = trimmed;
    }

    final size = await File(path).length();
    if (!mounted) return;
    // MALIYET + KULLANICI DENEYIMI: buyuk videolar mobil baglantida
    // dakikalarca yuklenir ve depolama giderini buyutur. Sert sinir
    // korunur, ama kullanici ne yaptigini bilerek onaylasin.
    if (size > warnBytes && size <= maxBytes && mounted) {
      final mb = (size / (1024 * 1024)).toStringAsFixed(0);
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('$mb MB',
              style:
                  const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
          content: Text(context.tr('large_video_warn'),
              style: const TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('cancel'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.tr('continue'),
                    style: const TextStyle(color: AppTheme.primary))),
          ],
        ),
      );
      if (go != true) return;
    }
    // Uyarı diyaloğu beklenirken ekran kapanmış olabilir (derin bağlantı,
    // geri tuşu). Yok edilmiş bir State'in context'ini kullanmak istisna
    // fırlatır.
    if (!mounted) return;
    if (size > maxBytes) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('video_too_big'))));
      return;
    }
    // KIRPILMIŞ yolu gönder — `picked.path` kırpma öncesi orijinaldir.
    await ref
        .read(messagingNotifierProvider(widget.chatId).notifier)
        .sendVideo(path, picked.name, viewOnce: viewOnce);
  }

  /// #6 Dosya sec ve gonder (25 MB siniri).
  Future<void> _pickAndSendFile() async {
    final XFile? picked = await openFile();
    if (picked == null || !mounted) return;
    const maxBytes = 25 * 1024 * 1024;
    final size = await File(picked.path).length();
    if (!mounted) return;
    if (size > maxBytes) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('file_too_big'))));
      return;
    }
    await ref
        .read(messagingNotifierProvider(widget.chatId).notifier)
        .sendFile(picked.path, picked.name);
  }

  /// 🖼️ Galeriden seç — fotoğraf mı video mu, KULLANICI DEĞİL sistem
  /// belirler. Seçilen dosyanın uzantısına göre doğru akış çalışır.
  Future<void> _pickFromGallery(bool viewOnce) async {
    final picked = await ImagePicker().pickMedia(imageQuality: 70);
    if (picked == null || !mounted) return;

    final ext = picked.path.toLowerCase();
    final isVideo = ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mkv') ||
        ext.endsWith('.webm') ||
        ext.endsWith('.3gp');

    if (isVideo) {
      await _sendVideoFile(picked, viewOnce);
    } else {
      // Fotoğraf → doğrudan EDİTÖR (kırpma dahil)
      final edited = await PhotoEditorScreen.open(context, picked.path);
      if (edited == null || !mounted) return;
      await ref
          .read(messagingNotifierProvider(widget.chatId).notifier)
          .sendPhoto(edited, source: 'gallery', viewOnce: viewOnce);
    }
  }

  /// 📸 Kamera — fotoğraf mı video mu seçtir, sonra ilgili akışa gir.
  Future<void> _openCamera(bool viewOnce) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primary),
              title: Text(ctx.tr('take_photo'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.videocam_outlined, color: AppTheme.primary),
              title: Text(ctx.tr('record_video'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;

    if (mode == 'photo') {
      await _pickAndSendPhoto(ImageSource.camera, 'camera', viewOnce);
    } else {
      await _pickAndSendVideo(fromCamera: true, viewOnce: viewOnce);
    }
  }

  Future<void> _pickAndSendPhoto(
      ImageSource source, String label, bool viewOnce) async {
    // ✂️ Seçim + KIRPMA/DÖNDÜRME tek adımda
    final path = await ImagePickerHelper.pickAndCrop(
      context,
      allowEdit: true,
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (path == null || !mounted) return;
    await ref
        .read(messagingNotifierProvider(widget.chatId).notifier)
        .sendPhoto(path, source: label, viewOnce: viewOnce);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagingNotifierProvider(widget.chatId));
    final notifier =
        ref.read(messagingNotifierProvider(widget.chatId).notifier);
    final wallpaperId = ref.watch(wallpaperProvider);

    ref.listen<MessagingState>(messagingNotifierProvider(widget.chatId),
        (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        // ── YAZILAN METİN KAYBOLMAZ (§4bk) ──
        // Gönderim başarısızsa geçici balon kaldırılıyor ve kullanıcının
        // yazdığı metin hiçbir yerde kalmıyordu; uzun bir mesajı
        // gönderememek onu baştan yazmak demekti. Metin geri konur —
        // ama kullanıcı bu arada YENİ bir şey yazmaya başladıysa üzerine
        // YAZILMAZ.
        final geri = next.basarisizMetin;
        if (geri != null && geri.isNotEmpty && _textController.text.isEmpty) {
          _textController.text = geri;
          _textController.selection =
              TextSelection.collapsed(offset: geri.length);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(next.error!))),
        );
        notifier.clearError();
      }
      // Yeni mesaj gelince (veya ilk yuklemede) en alta kaydir: en yeni
      // mesaj her zaman gorunur olsun (en altta). Sira + gorunurluk birlikte.
      // PAGINATION GUARD: eski sayfa USTE eklenince alta kaydirma!
      // Yalnizca SON mesaj degistiyse (yeni mesaj geldi) kaydir.
      final prevLastId = (prev != null && prev.messages.isNotEmpty)
          ? prev.messages.last.id
          : null;
      final nextLastId =
          next.messages.isNotEmpty ? next.messages.last.id : null;
      if (nextLastId != null && nextLastId != prevLastId) {
        // 🔐 Gelen mesaj cozulurken karsi tarafin kimlik anahtari
        // degismis olabilir (yeniden kurulum ya da araya girme).
        // Cozme bu noktada bitmis olur; bandi tazele.
        if (!widget.isGroup && !_kendineSohbet) _refreshSafety();
        // Sohbet ACIKKEN yeni mesaj geldiyse okundu isaretle (ekran = niyet)
        if (prevLastId != null && next.messages.last.senderId != widget.myUid) {
          notifier.markAsReadNow();
          NotificationService.cancelForChat(widget.chatId);
        }
        final firstLoad = !_didInitialJump && next.messages.isNotEmpty;
        if (firstLoad) _didInitialJump = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          if (firstLoad) {
            // ILK ACILIS: animasyonsuz dogrudan en alta ATLA (uzun
            // sohbetlerde ustten baslama sorunu). Resim vb. gec yuklenen
            // icerik yuksekligi degistirebildigi icin kisa sure sonra
            // bir kez daha atla.
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
            Future.delayed(const Duration(milliseconds: 350), () {
              if (mounted && _scrollController.hasClients) {
                _scrollController
                    .jumpTo(_scrollController.position.maxScrollExtent);
              }
            });
          } else {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      // ⌨️ KLAVYE FIX: Bazı cihazlarda (özellikle jest navigasyonlu
      // Android'de) klavye açılınca gönderme çubuğu altta kalıyordu.
      // Açıkça true vermek + çubuğa klavye yüksekliği kadar boşluk
      // eklemek (aşağıda viewInsets) sorunu kapatır.
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 26),
        child: FrostedTopBar(
            height: kToolbarHeight + 26,
            child: _selectionMode
                ? _buildSelectionBar(state)
                : (_searchActive
                    ? _buildSearchBar(state)
                    : _buildAppBarContent())),
      ),
      body: Column(
        children: [
          _buildConnectivityBanner(),
          Expanded(
            child: Builder(builder: (context) {
              // #7: sohbete ozel FOTO arka plan (blur + karartma) varsa onu,
              // yoksa global preset duvar kagidini kullan.
              final bgPhoto = ref.watch(chatBgPhotoProvider(widget.chatId));
              final photoOk =
                  bgPhoto != null && File(bgPhoto.path).existsSync();
              if (!photoOk) {
                return Container(
                  decoration: wallpaperDecorationFor(wallpaperId),
                  child: _buildMessageList(state),
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(
                        sigmaX: bgPhoto.blur, sigmaY: bgPhoto.blur),
                    child: Image.file(File(bgPhoto.path),
                        cacheWidth: 1080, // PERFORMANS: tam-coz. decode etme
                        fit: BoxFit.cover),
                  ),
                  ColoredBox(
                      color: Colors.black.withValues(alpha: bgPhoto.darken)),
                  _buildMessageList(state),
                ],
              );
            }),
          ),
          if (widget.isGroup && _mentionSuggestions.isNotEmpty)
            _buildMentionBar(),
          if (state.replyingTo != null) _buildReplyBar(state, notifier),
          _buildInputBar(state),
        ],
      ),
    );
  }

  /// 🙈 Gorunur mesajlar: gizlenenler (PIN'le acilmadikca) listeden dusur.
  /// TUM index-tabanli isler (arama, atlama, sabit-atlama) BU listeyi
  /// kullanmali — ham state.messages ile karistirilirsa indeksler kayar.
  List<MessageEntity> _display(List<MessageEntity> all) {
    var list = all;

    // 🗑️ SOHBET SİLİNDİYSE: silme anından ÖNCEKİ mesajlar bende
    // görünmez. "Sohbeti sildim ama kişiyle tekrar yazışınca eski
    // mesajlar geri geliyor" sorununun kaynağı buydu — silme yalnızca
    // sohbeti listeden gizliyordu, mesajlar duruyordu.
    // (Yedekten geri yükleme bu işareti kaldırır; o zaman hepsi görünür.)
    final deletedAt =
        ref.read(chatPrefsProvider(widget.myUid)).deletedAt[widget.chatId];
    if (deletedAt != null) {
      list = list.where((m) => m.timestamp.isAfter(deletedAt)).toList();
    }

    if (_revealHidden) return list;
    final hidden = ref.read(hiddenMessagesProvider(widget.myUid));
    if (hidden.isEmpty) return list;
    return list
        .where((m) => !hidden.contains('${widget.chatId}|${m.id}'))
        .toList();
  }

  /// Arama eslesme indeksleri (metin mesajlarinda, buyuk/kucuk duyarsiz).
  List<int> _searchMatches(List<MessageEntity> messages) {
    final q = _searchQuery.trim().toLowerCase();
    final range = _searchRange;
    if (q.isEmpty && range == null) return const [];
    // aralik sinirlarini gun bazina yay (baslangic 00:00, bitis 23:59)
    final start = range == null
        ? null
        : DateTime(range.start.year, range.start.month, range.start.day);
    final end = range == null
        ? null
        : DateTime(range.end.year, range.end.month, range.end.day)
            .add(const Duration(days: 1));
    final res = <int>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.isDeleted) continue;
      if (start != null &&
          (m.timestamp.isBefore(start) || !m.timestamp.isBefore(end!))) {
        continue;
      }
      if (q.isEmpty) {
        res.add(i); // yalniz tarih filtresi: araliktaki TUM mesajlar
      } else if (m.type == MessageContentType.text &&
          m.content.toLowerCase().contains(q)) {
        res.add(i);
      }
    }
    return res;
  }

  /// 🗓 Tarih araligi sec + gerekirse eski sayfalari araliga kadar yukle.
  Future<void> _pickSearchRange(MessagingState state) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: now,
      initialDateRange: _searchRange,
      helpText: context.tr('date_range_search'),
      saveText: 'Uygula',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _searchRange = picked;
      _currentMatch = 0;
    });
    // Aralik, yuklu pencereden eskiyse: sayfalari otomatik cek (en cok 15)
    final startDay =
        DateTime(picked.start.year, picked.start.month, picked.start.day);
    var loops = 0;
    var st = ref.read(messagingNotifierProvider(widget.chatId));
    while (loops < 15 &&
        st.hasMore &&
        st.messages.isNotEmpty &&
        st.messages.first.timestamp.isAfter(startDay)) {
      await ref
          .read(messagingNotifierProvider(widget.chatId).notifier)
          .loadOlder();
      if (!mounted) return;
      st = ref.read(messagingNotifierProvider(widget.chatId));
      loops++;
    }
    if (!mounted) return;
    if (loops >= 15 &&
        st.messages.isNotEmpty &&
        st.messages.first.timestamp.isAfter(startDay)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('search_older_hint'))));
    }
    final msgs = _display(st.messages);
    final m = _searchMatches(msgs);
    if (m.isNotEmpty) {
      setState(() => _currentMatch = m.length - 1);
      _scrollToIndex(m.last, msgs.length);
    }
  }

  /// İKİ AŞAMALI KAYDIRMA
  ///
  /// 1) Oransal tahminle hedefin yakınına git (liste henüz o mesajı
  ///    çizmemiş olabilir; anahtar da bu yüzden yok).
  /// 2) Kare sonrası mesaj çizildiyse `ensureVisible` ile TAM ortaya al.
  ///    Çizilmediyse tahmini bir kez daha uygula.
  ///
  /// Eskiden yalnızca 1. aşama vardı; değişken mesaj yükseklikleri
  /// yüzünden aranan mesaj sık sık ekran dışında kalıyordu.
  void _scrollToIndex(int index, int total) {
    if (!_scrollController.hasClients || total <= 1) return;

    void proportional() {
      final target =
          _scrollController.position.maxScrollExtent * (index / (total - 1));
      _scrollController.animateTo(
        target.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }

    proportional();

    // Hassas düzeltme: iki denemeye kadar
    var attempt = 0;
    void refine() {
      if (!mounted || attempt >= 2) return;
      attempt++;
      final ctx = _currentMatchKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.4, // hafif üstte dursun, çevresi görünsün
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
        return;
      }
      proportional();
      WidgetsBinding.instance.addPostFrameCallback((_) => refine());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Animasyon otursun, sonra düzelt
      Future<void>.delayed(const Duration(milliseconds: 260), refine);
    });
  }

  void _gotoMatch(int delta, List<int> matches, int total) {
    if (matches.isEmpty) return;
    setState(() {
      _currentMatch = (_currentMatch + delta) % matches.length;
      if (_currentMatch < 0) _currentMatch += matches.length;
    });
    _scrollToIndex(matches[_currentMatch], total);
  }

  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _searchRange = null;
      _currentMatch = 0;
      _searchController.clear();
    });
  }

  /// Baslik alt-satiri: 1-1 sohbette yaziyor.../cevrimici/son gorulme,
  /// yoksa (grup/kanal veya veri yok) sifreli/uye bilgisi.
  Widget _buildSubtitle() {
    final secureRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock, size: 11, color: AppTheme.secure),
        const SizedBox(width: 3),
        Text(
          context.tr('e2ee_short'),
          style: const TextStyle(color: AppTheme.secure, fontSize: 12),
        ),
      ],
    );
    final other = _otherUid();
    if (other == null) return secureRow;
    // IZOLASYON: presence/yaziyor yayinlari yalnizca bu kucuk metni
    // rebuild etsin — onceden her yaziyor-basladi/durdu TUM ekrani
    // yeniden insa ettiriyordu.
    return Consumer(builder: (context, ref, _) {
      final presence = ref.watch(presenceProvider(other)).asData?.value;
      if (presence == null) return secureRow;
      final text = presenceText(context, presence, forChatId: widget.chatId);
      if (text.isEmpty) return secureRow;
      final isTyping = text == 'yazıyor...';
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isTyping || text == 'çevrimiçi'
              ? AppTheme.primary
              : AppTheme.textSecondary,
          fontSize: 12,
          fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
        ),
      );
    });
  }

  Widget _buildSearchBar(MessagingState state) {
    final display = _display(state.messages);
    final matches = _searchMatches(display);
    final cur = matches.isEmpty ? 0 : (_currentMatch % matches.length) + 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: _closeSearch,
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: context.tr('search_in_msgs'),
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                border: InputBorder.none,
              ),
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _currentMatch = 0;
                });
                final disp = _display(state.messages);
                final m = _searchMatches(disp);
                if (m.isNotEmpty) {
                  // En son (en yeni) eslesmeye git
                  setState(() => _currentMatch = m.length - 1);
                  _scrollToIndex(m.last, disp.length);
                }
              },
            ),
          ),
          if (_searchRange != null)
            InkWell(
              onTap: () => setState(() {
                _searchRange = null;
                _currentMatch = 0;
              }),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_searchRange!.start.day}.${_searchRange!.start.month}–${_searchRange!.end.day}.${_searchRange!.end.month}',
                      style: const TextStyle(
                          color: AppTheme.primary, fontSize: 11.5),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.close, size: 12, color: AppTheme.primary),
                  ],
                ),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.calendar_month,
                size: 20,
                color: _searchRange != null
                    ? AppTheme.primary
                    : AppTheme.textSecondary),
            onPressed: () => _pickSearchRange(state),
          ),
          Text(
            matches.isEmpty
                ? ((_searchQuery.trim().isEmpty && _searchRange == null)
                    ? ''
                    : '0')
                : '$cur/${matches.length}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up,
                color: AppTheme.textPrimary),
            onPressed: () => _gotoMatch(-1, matches, display.length),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                color: AppTheme.textPrimary),
            onPressed: () => _gotoMatch(1, matches, display.length),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          // Hero: sohbet listesindeki avatarla eşleşmeye hazır
          Hero(
            tag: 'avatar_${widget.chatId}',
            child: _otherUid() != null
                ? UserAvatar(
                    uid: _otherUid()!,
                    fallbackLetter: widget.chatTitle.isNotEmpty
                        ? widget.chatTitle[0].toUpperCase()
                        : '?',
                    radius: 19,
                  )
                : Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.chatTitle.isNotEmpty
                          ? widget.chatTitle[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Color(0xFF04141C),
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                  ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openProfileOrInfo,
              // TASMA-GECIRMEZ baslik: ilk karede yazi tipi yuklenene kadar
              // yedek fontun metrikleri 1-2px yuksek olabilir; Flexible,
              // cizgi basmak yerine o kareyi esneterek gecirir (Flutter'in
              // onerdigi anti-overflow deseni; buyuk yazi tipinde de guvenli).
              child: Column(
                mainAxisSize: MainAxisSize.min, // TASMA FIX: kirmizi serit
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                          child: Text(
                        widget.chatTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                      if (_disappearSeconds != null) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.timer_outlined,
                            size: 14, color: AppTheme.primary),
                      ],
                      if (_incognito) ...[
                        const SizedBox(width: 6),
                        const Text('🕵️', style: TextStyle(fontSize: 12)),
                      ],
                      // 🔐 Sifreli oturum VARSA durum rozeti. Oturum yokken
                      // kalkan gostermek yaniltici olurdu.
                      if (!widget.isGroup &&
                          (_safety?.hasSession ?? false)) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openSafetyNumber,
                          child: Icon(
                            _safety!.identityChanged
                                ? Icons.gpp_maybe_rounded
                                : (_safety!.userVerified
                                    ? Icons.verified_user_rounded
                                    : Icons.shield_outlined),
                            size: 14,
                            color: _safety!.identityChanged
                                ? AppTheme.danger
                                : (_safety!.userVerified
                                    ? AppTheme.secure
                                    : AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  _buildSubtitle(),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.textPrimary),
            onPressed: () => setState(() => _searchActive = true),
            tooltip: context.tr('search_in_msgs_tip'),
          ),
          // Arama butonları (sadece direkt sohbet — kendinle arama yok)
          if (!widget.isGroup && !_kendineSohbet) ...[
            IconButton(
              icon: const Icon(Icons.call, color: AppTheme.textPrimary),
              onPressed: () => _startCall(CallType.audio),
              tooltip: context.tr('voice_call'),
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: AppTheme.textPrimary),
              onPressed: () => _startCall(CallType.video),
              tooltip: context.tr('video_call'),
            ),
          ] else if (!_isChannel) ...[
            // 👥 GRUP ARAMASI (mesh) — kanallarda YOK.
            IconButton(
              icon: const Icon(Icons.groups, color: AppTheme.textPrimary),
              onPressed: () => _startGroupCall(video: false),
              tooltip: context.tr('group_call'),
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: AppTheme.textPrimary),
              onPressed: () => _startGroupCall(video: true),
              tooltip: context.tr('group_call'),
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
            color: AppTheme.surface,
            onSelected: (v) {
              if (v == 'clear') _confirmClearChat();
              if (v == 'theme') {
                showBubbleThemePicker(context, ref, chatId: widget.chatId);
              }
              if (v == 'sched') _showScheduledSheet();
              if (v == 'disappear') _showDisappearSheet();
              if (v == 'incognito') _toggleIncognito();
              if (v == 'revealHidden') _toggleRevealHidden();
              if (v == 'export') _exportChat();
              if (v == 'safety') _showSafetySheet();
              if (v == 'safetynum') _openSafetyNumber();
              if (v == 'bg') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatBackgroundScreen(
                      chatId: widget.chatId, chatTitle: widget.chatTitle),
                ));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'theme',
                child: Text(context.tr('chat_color'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
              ),
              PopupMenuItem(
                value: 'bg',
                child: Text(context.tr('background'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
              ),
              PopupMenuItem(
                value: 'sched',
                child: Text(context.tr('scheduled_msgs'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
              ),
              if (!widget.isGroup)
                PopupMenuItem(
                  value: 'safetynum',
                  child: Text(context.tr('safety_number'),
                      style: const TextStyle(color: AppTheme.textPrimary)),
                ),
              if (!widget.isGroup)
                PopupMenuItem(
                  value: 'safety',
                  child: Text(
                      '${context.tr('block_user')} / ${context.tr('report_user')}',
                      style: const TextStyle(color: AppTheme.danger)),
                ),
              PopupMenuItem(
                value: 'export',
                child: Text(context.tr('export_chat'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
              ),
              PopupMenuItem(
                value: 'revealHidden',
                child: Text(
                    _revealHidden
                        ? context.tr('hide_hidden')
                        : context.tr('show_hidden'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
              ),
              PopupMenuItem(
                value: 'disappear',
                child: Text(context.tr('disappearing'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
              ),
              PopupMenuItem(
                value: 'incognito',
                child: Text(context.tr('secret_chat'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Text(context.tr('clear_chat'),
                    style: const TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Çoklu seçim ----
  void _enterSelection(String id) {
    setState(() => _selectedIds.add(id));
  }

  void _toggleSelect(String id) {
    setState(() {
      _selectedIds.contains(id)
          ? _selectedIds.remove(id)
          : _selectedIds.add(id);
    });
  }

  void _clearSelection() {
    setState(_selectedIds.clear);
  }

  void _selectAll(List<MessageEntity> messages) {
    setState(() {
      _selectedIds.addAll(messages.where((m) => !m.isDeleted).map((m) => m.id));
    });
  }

  Widget _buildSelectionBar(MessagingState state) {
    final selected =
        state.messages.where((m) => _selectedIds.contains(m.id)).toList();
    final allMine =
        selected.isNotEmpty && selected.every((m) => m.isSentBy(widget.myUid));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                onPressed: _clearSelection,
                tooltip: context.tr('cancel_it'),
              ),
              Text('${_selectedIds.length} ${context.tr('n_selected')}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (selected.length == 1)
                PopupMenuButton<String>(
                  icon:
                      const Icon(Icons.more_vert, color: AppTheme.textPrimary),
                  color: AppTheme.surface,
                  onSelected: (v) => _onSingleAction(v, selected.first),
                  itemBuilder: (_) {
                    final m = selected.first;
                    final isText = m.type == MessageContentType.text;
                    final mine = m.isSentBy(widget.myUid);
                    return [
                      if (isText)
                        PopupMenuItem(
                            value: 'reply',
                            child: Text(context.tr('msg_reply'),
                                style: const TextStyle(
                                    color: AppTheme.textPrimary))),
                      if (isText)
                        PopupMenuItem(
                            value: 'copy',
                            child: Text(context.tr('msg_copy'),
                                style: const TextStyle(
                                    color: AppTheme.textPrimary))),
                      if (isText)
                        PopupMenuItem(
                            value: 'translate',
                            child: Text(context.tr('msg_translate'),
                                style: const TextStyle(
                                    color: AppTheme.textPrimary))),
                      if (isText)
                        PopupMenuItem(
                            value: 'forward',
                            child: Text(context.tr('msg_forward'),
                                style: const TextStyle(
                                    color: AppTheme.textPrimary))),
                      if (isText && mine)
                        PopupMenuItem(
                            value: 'edit',
                            child: Text(context.tr('msg_edit'),
                                style: const TextStyle(
                                    color: AppTheme.textPrimary))),
                      PopupMenuItem(
                          value: 'hide',
                          child: Text(
                              (_revealHidden &&
                                      ref
                                          .read(hiddenMessagesProvider(
                                              widget.myUid))
                                          .contains(
                                              '${widget.chatId}|${selected.first.id}'))
                                  ? context.tr('msg_unhide')
                                  : context.tr('msg_hide'),
                              style: const TextStyle(
                                  color: AppTheme.textPrimary))),
                      PopupMenuItem(
                          value: 'pin',
                          child: Text(
                              _pinned?.messageId == m.id
                                  ? context.tr('unpin')
                                  : context.tr('pin'),
                              style: const TextStyle(
                                  color: AppTheme.textPrimary))),
                      PopupMenuItem(
                          value: 'star',
                          child: Text(
                              ref
                                      .read(starredProvider(widget.myUid))
                                      .any((x) => x.messageId == m.id)
                                  ? context.tr('unstar')
                                  : context.tr('star'),
                              style: const TextStyle(
                                  color: AppTheme.textPrimary))),
                      PopupMenuItem(
                          value: 'info',
                          child: Text(context.tr('msg_info'),
                              style: const TextStyle(
                                  color: AppTheme.textPrimary))),
                    ];
                  },
                ),
              IconButton(
                icon: const Icon(Icons.select_all, color: AppTheme.textPrimary),
                tooltip: context.tr('select_all'),
                onPressed: () => _selectAll(_display(state.messages)),
              ),
              IconButton(
                icon: const Icon(Icons.visibility_off_outlined,
                    color: AppTheme.textPrimary),
                tooltip: context.tr('hide_show'),
                onPressed:
                    selected.isEmpty ? null : () => _hideSelectedFlow(selected),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                tooltip: context.tr('delete'),
                onPressed:
                    selected.isEmpty ? null : () => _showDeleteOptions(allMine),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 📖 Kimliğe göre hikâye aç.
  ///
  /// Hikâyeler 24 saat sonra silinir; bulunamazsa "süresi dolmuş"
  /// bilgisi verilir — sessizce hiçbir şey olmaması kafa karıştırırdı.
  Future<void> _openStoryById(String storyId) async {
    debugPrint('[SECRETER-STORY] alıntıya dokunuldu · id=$storyId');
    if (storyId.isEmpty) {
      // İŞARET BOZUK: önizleme 'story:<id>:<metin>' biçiminde
      // olmalıydı ama id boş geldi. Sessiz kalmak yerine bildir.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('story_expired'))));
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('story_expired'))));
        return;
      }
      final story = StoryModel.fromMap(doc.data()!);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          userStories: UserStoriesEntity(
            userId: story.userId,
            username: story.username,
            stories: [story],
          ),
          myUid: widget.myUid,
        ),
      ));
    } catch (e) {
      debugPrint('Hikâye açılamadı: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('story_expired'))));
    }
  }

  /// 🛡️ Engelle / şikâyet sayfası (yalnız birebir sohbetlerde).
  Future<void> _showSafetySheet() async {
    final parts = widget.chatId.split('_');
    if (parts.length != 2) return;
    final other = parts[0] == widget.myUid ? parts[1] : parts[0];
    final blocked = ref
            .read(blockedUsersProvider(widget.myUid))
            .asData
            ?.value
            .contains(other) ??
        false;
    final name = widget.chatTitle.replaceAll('@', '');
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: AppTheme.danger),
              title: Text(
                  blocked
                      ? context.tr('unblock_user')
                      : context.tr('block_user'),
                  style: const TextStyle(color: AppTheme.danger)),
              onTap: () {
                Navigator.pop(ctx);
                SafetyActions.confirmBlock(context,
                    myUid: widget.myUid,
                    otherUid: other,
                    username: name,
                    currentlyBlocked: blocked);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.flag_outlined, color: AppTheme.textPrimary),
              title: Text(context.tr('report_user'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                SafetyActions.report(context,
                    myUid: widget.myUid,
                    otherUid: other,
                    username: name,
                    chatId: widget.chatId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 📤 Sohbeti .txt olarak dışa aktar ve paylaş.
  /// GIZLILIK: gizlenen mesajlar dokume DAHIL EDILMEZ; medya icerigi
  /// yerine tur etiketi yazilir (📷/🎥/🎵...).
  Future<void> _exportChat() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary)),
    );
    // eski sayfalari da cek (2000 mesaj emniyet tavani)
    var st = ref.read(messagingNotifierProvider(widget.chatId));
    var loops = 0;
    while (st.hasMore && loops < 40) {
      await ref
          .read(messagingNotifierProvider(widget.chatId).notifier)
          .loadOlder();
      if (!mounted) return;
      st = ref.read(messagingNotifierProvider(widget.chatId));
      loops++;
    }
    final msgs = _display(st.messages); // gizlenenler haric
    final buf = StringBuffer()
      ..writeln('SECRETER — ${widget.chatTitle}')
      ..writeln('Dışa aktarma: ${DateTime.now()}')
      ..writeln('Mesaj sayısı: ${msgs.length}')
      ..writeln('---');
    String two(int n) => n.toString().padLeft(2, '0');
    for (final m in msgs) {
      final t = m.timestamp;
      final stamp =
          '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
      final who = m.isSentBy(widget.myUid) ? 'Ben' : '@${m.senderUsername}';
      final body = m.type == MessageContentType.text && !m.isDeleted
          ? m.content
          : m.preview;
      buf.writeln('[$stamp] $who: $body');
    }
    try {
      final dir = await getTemporaryDirectory();
      // DOSYA ADI: Türkçe karakterler bazı sistemlerde/paylaşım
      // hedeflerinde bozuluyor. İçerik UTF-8 kalır, yalnızca DOSYA ADI
      // ASCII'ye çevrilir.
      const trMap = {
        'ç': 'c',
        'Ç': 'C',
        'ğ': 'g',
        'Ğ': 'G',
        'ı': 'i',
        'İ': 'I',
        'ö': 'o',
        'Ö': 'O',
        'ş': 's',
        'Ş': 'S',
        'ü': 'u',
        'Ü': 'U',
      };
      var safe = widget.chatTitle;
      trMap.forEach((k, v) => safe = safe.replaceAll(k, v));
      safe = safe.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final file =
          File('${dir.path}/SECRETER_${safe.isEmpty ? 'sohbet' : safe}.txt');
      // TÜRKÇE KARAKTER DÜZELTMESİ
      //
      // `writeAsString` UTF-8 yazar ama BOM (byte order mark) EKLEMEZ.
      // Windows Not Defteri gibi programlar BOM'suz dosyayı ANSI sanıp
      // ç/ğ/ı/ö/ş/ü karakterlerini bozuk gösteriyordu.
      // BOM eklemek dosyayı her yerde doğru okutur.
      const bom = '\uFEFF';
      await file.writeAsString(bom + buf.toString(),
          encoding: utf8, flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(); // yukleme kapat
      await Share.shareXFiles([XFile(file.path)],
          text: 'SECRETER sohbet dökümü');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('export_failed'))));
    }
  }

  /// ⚡ Secili mesajin altindaki kompakt emoji seridi.
  Widget _quickReactStrip(MessageEntity m) {
    return Container(
      margin: const EdgeInsets.only(top: 4, left: 6, right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['❤️', '😂', '👍', '😮', '🔥', '👏']
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: GestureDetector(
                    onTap: () {
                      final id = m.id;
                      _clearSelection();
                      ref
                          .read(
                              messagingNotifierProvider(widget.chatId).notifier)
                          .setReaction(id, e);
                    },
                    child: Text(e, style: const TextStyle(fontSize: 23)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  /// 🙈 Gizlenenleri gorunur yap / tekrar gizle (sifre dogrulamali).
  Future<void> _toggleRevealHidden() async {
    if (_revealHidden) {
      setState(() => _revealHidden = false);
      return;
    }
    final has = await HiddenLockService.hasPin(widget.myUid);
    if (!has) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('no_hidden'))));
      }
      return;
    }
    final ok = await _askHiddenPin(verifyOnly: true);
    if (ok && mounted) setState(() => _revealHidden = true);
  }

  /// 🙈 TOPLU gizle/goster: SIFRE BIR KEZ sorulur, tum secilenlere uygulanir.
  Future<void> _hideSelectedFlow(List<MessageEntity> msgs) async {
    if (msgs.isEmpty) return;
    final notifier = ref.read(hiddenMessagesProvider(widget.myUid).notifier);
    final hiddenSet = ref.read(hiddenMessagesProvider(widget.myUid));
    final allHidden =
        msgs.every((m) => hiddenSet.contains('${widget.chatId}|${m.id}'));
    final has = await HiddenLockService.hasPin(widget.myUid);
    final ok = await _askHiddenPin(verifyOnly: has);
    if (!ok || !mounted) return;
    var changed = 0;
    for (final m in msgs) {
      final h = hiddenSet.contains('${widget.chatId}|${m.id}');
      if (allHidden ? h : !h) {
        await notifier.toggle(widget.chatId, m.id);
        changed++;
      }
    }
    _clearSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(allHidden
              ? '$changed mesajın gizlemesi kaldırıldı'
              : '$changed mesaj gizlendi — ⋮ → "Gizlenen mesajları göster"')));
    }
  }

  Future<bool> _askHiddenPin({required bool verifyOnly}) async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
            verifyOnly ? 'Gizli mesaj şifresi' : 'Gizli mesaj şifresi belirle',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: c1,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                  hintText: context.tr('pwd_4_8'), counterText: ''),
            ),
            if (!verifyOnly)
              TextField(
                controller: c2,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                    hintText: context.tr('pwd_again'), counterText: ''),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('ok'),
                  style: const TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
    final pin = c1.text.trim();
    final pin2 = c2.text.trim();
    if (res != true || !mounted) return false;
    if (pin.length < 4) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('pwd_min4'))));
      return false;
    }
    if (verifyOnly) {
      final ok = await HiddenLockService.verify(widget.myUid, pin);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('pwd_wrong'))));
      }
      return ok;
    }
    if (pin != pin2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('pwd_mismatch'))));
      return false;
    }
    await HiddenLockService.setPin(widget.myUid, pin);
    return true;
  }

  /// #16 Mesaji cevir. GIZLILIK: metin ucuncu taraf servise gider —
  /// ilk kullanimda acik onay alinir.
  Future<void> _translateMessage(MessageEntity m) async {
    if (m.content.trim().isEmpty) return;
    final ok = await _ensureTranslateConsent();
    if (!ok || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary)),
    );
    String? result;
    String? error;
    try {
      result = await TranslationService.translate(m.content,
          target: Localizations.localeOf(context).languageCode);
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // yukleme kapat

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${context.tr('translate_failed')}: ${error ?? ''}')),
      );
      return;
    }
    // closure icinde null-safety promotion sorunu olmasin diye sabitle
    final translated = result;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.translate,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(context.tr('translation'),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              Text(context.tr('original_text'),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11.5)),
              const SizedBox(height: 3),
              Text(m.content,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13.5)),
              const Divider(height: 22),
              Text(context.tr('translation'),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11.5)),
              const SizedBox(height: 3),
              SelectableText(translated,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 15.5)),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(context.tr('msg_copy')),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: translated));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.tr('translation_copied'))));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ilk kullanimda gizlilik onayi (kalici saklanir).
  Future<bool> _ensureTranslateConsent() async {
    if (await TranslationService.hasConsent()) return true;
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('translate_privacy'),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Text(
          context.tr('translate_privacy_body'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('i_agree'),
                style: const TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await TranslationService.setConsent(true);
      return true;
    }
    return false;
  }

  void _onSingleAction(String action, MessageEntity m) {
    final notifier =
        ref.read(messagingNotifierProvider(widget.chatId).notifier);
    switch (action) {
      case 'reply':
        notifier.setReplyingTo(m);
        _clearSelection();
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: m.content));
        _clearSelection();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('copied'))));
        break;
      case 'hide':
        _hideSelectedFlow([m]);
        break;
      case 'translate':
        _clearSelection();
        _translateMessage(m);
        break;
      case 'forward':
        final c = m.content;
        _clearSelection();
        _showForwardPicker(c);
        break;
      case 'edit':
        notifier.setEditing(m);
        _textController.text = m.content;
        _textController.selection =
            TextSelection.collapsed(offset: m.content.length);
        _clearSelection();
        break;
      case 'pin':
        if (_pinned?.messageId == m.id) {
          PinnedMessageService.unpin(widget.chatId);
        } else {
          // E2EE: sunucuya maskeli onizleme (duz metin sizmaz)
          final preview = m.isEncrypted
              ? context.tr('preview_message')
              : _starPreview(m).length > 80
                  ? '${_starPreview(m).substring(0, 80)}…'
                  : _starPreview(m);
          PinnedMessageService.pin(widget.chatId, m.id, preview);
        }
        _clearSelection();
        break;
      case 'star':
        final notif = ref.read(starredProvider(widget.myUid).notifier);
        if (notif.isStarred(m.id)) {
          notif.remove(m.id);
        } else {
          notif.add(StarredMessage(
            chatId: widget.chatId,
            messageId: m.id,
            chatTitle: widget.chatTitle,
            isGroup: widget.isGroup,
            sender: m.isSentBy(widget.myUid)
                ? 'Sen'
                : (m.senderUsername.isNotEmpty
                    ? m.senderUsername
                    : widget.chatTitle),
            preview: _starPreview(m),
            timestamp: m.timestamp,
            starredAt: DateTime.now(),
          ));
        }
        _clearSelection();
        break;
      case 'info':
        _clearSelection();
        _showMsgInfo(m);
        break;
    }
  }

  String _starPreview(MessageEntity m) {
    switch (m.type) {
      case MessageContentType.image:
        return '📷 Fotoğraf';
      case MessageContentType.gif:
        return 'GIF';
      case MessageContentType.voice:
        return '🎤 Sesli mesaj';
      default:
        return m.content;
    }
  }

  void _showMsgInfo(MessageEntity m) {
    final t = m.timestamp;
    String two(int n) => n.toString().padLeft(2, '0');
    final dateStr =
        '${two(t.day)}.${two(t.month)}.${t.year}  ${two(t.hour)}:${two(t.minute)}';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('msg_info_t'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.tr('time_label')}: $dateStr',
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Text('${context.tr('status_label')}: ${m.status.name}',
                style: const TextStyle(color: AppTheme.textSecondary)),
            if (m.isEdited) ...[
              const SizedBox(height: 6),
              Text(context.tr('edited'),
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ],
            // GRUPTA "KİMLER OKUDU"
            //
            // Bu bölüm ikinci, ÖLÜ bir kopyada (`_showMessageInfo`) yazılmış
            // ama hiçbir yere bağlanmamıştı — yani kullanıcı özelliği hiç
            // göremiyordu. Ölü kopya silindi, özellik canlı diyaloğa taşındı.
            if (widget.isGroup && m.senderId == widget.myUid) ...[
              const SizedBox(height: 12),
              Text('${context.tr('readers')} (${m.readBy.length})',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (m.readBy.isEmpty)
                Text(context.tr('nobody_read'),
                    style: const TextStyle(color: AppTheme.textSecondary))
              else
                SizedBox(
                  width: double.maxFinite,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView(
                      shrinkWrap: true,
                      children:
                          m.readBy.map((uid) => _ReaderRow(uid: uid)).toList(),
                    ),
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('close')),
          ),
        ],
      ),
    );
  }

  /// Silme seçenekleri (Benden sil / Herkesten sil).
  ///
  /// [ids] verilmezse SEÇİLİ mesajlar kullanılır (toplu silme).
  /// Tek mesaj silmede ⋮ menüsünden `ids: [msg.id]` ile çağrılır — böylece
  /// tek ve toplu silme AYNI davranışı gösterir.
  void _showDeleteOptions(bool allMine, {List<String>? ids}) {
    final targets = ids ?? _selectedIds.toList();
    if (targets.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                  '${targets.length} ${context.tr('messages_will_delete')}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading:
                  const Icon(Icons.visibility_off, color: AppTheme.textPrimary),
              title: Text(context.tr('delete_for_me'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(context.tr('delete_for_me_sub'),
                  style: const TextStyle(color: AppTheme.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                _doDelete(targets, forEveryone: false);
              },
            ),
            if (allMine)
              ListTile(
                leading:
                    const Icon(Icons.delete_forever, color: AppTheme.danger),
                title: Text(context.tr('delete_for_all'),
                    style: const TextStyle(color: AppTheme.danger)),
                subtitle: Text(context.tr('delete_for_all_sub'),
                    style: const TextStyle(color: AppTheme.textSecondary)),
                onTap: () {
                  Navigator.pop(context);
                  _doDelete(targets, forEveryone: true);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textSecondary),
              title: Text(context.tr('cancel'),
                  style: const TextStyle(color: AppTheme.textSecondary)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doDelete(List<String> ids, {required bool forEveryone}) async {
    _clearSelection();
    final notifier =
        ref.read(messagingNotifierProvider(widget.chatId).notifier);
    final ok = forEveryone
        ? await notifier.deleteForEveryone(ids)
        : await notifier.deleteForMe(ids);
    if (!mounted) return;
    // TANILAMA: başarısızlıkta GERÇEK hatayı göster. Eskiden yalnızca
    // "Silinemedi" yazıyordu ve sebebi anlaşılamıyordu.
    final err = ref.read(messagingNotifierProvider(widget.chatId)).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? context.tr('deleted')
            : (err == null ? context.tr('delete_failed') : context.tr(err))),
      ),
    );
  }

  Future<void> _confirmClearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('clear_chat'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        // ⚠️ METİN GERÇEĞİ SÖYLER (§4aw). Eskiden "her iki taraftan da
        // kalıcı olarak silinecek" yazıyordu — ama bu ne oluyordu ne de
        // olmalıydı: bir sohbetin tarafına diğerinin geçmişini tek
        // taraflı yok etme yetkisi vermek, söylediklerinin kaydını
        // silmek isteyen biri için hazır bir araçtır.
        content: Text(
          context.tr('clear_chat_desc'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('yes_clear'),
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success = await ref
        .read(messagingNotifierProvider(widget.chatId).notifier)
        .clearChat();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(success ? 'chat_cleared' : 'err_clear_chat')),
      ),
    );
  }

  void _startCall(CallType type) {
    // Direkt sohbet chatId'si sıralı [myUid, otherUid].join('_') formatında
    final calleeId = widget.chatId
        .split('_')
        .firstWhere((id) => id != widget.myUid, orElse: () => '');
    if (calleeId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          calleeId: calleeId,
          calleeUsername: widget.chatTitle,
          callType: type,
        ),
      ),
    );
  }

  /// 👥 Grup aramasını aç (mesh — §4bq).
  ///
  /// Gruba ait CANLI bir arama varsa ona katılır, yoksa yenisini açar;
  /// ayrımı servis yapar. Burada yalnızca ekran açılır.
  void _startGroupCall({required bool video}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupCallScreen(
          chatId: widget.chatId,
          chatTitle: widget.chatTitle,
          video: video,
        ),
      ),
    );
  }

  /// 🔐 Guvenlik numarasi durumunu cihazdan tazele.
  Future<void> _refreshSafety() async {
    final info = await E2EESessionService.safetyInfo(widget.chatId);
    if (!mounted) return;
    // GEREKSIZ REBUILD YOK: her gelen mesajda cagriliyor, yalnizca
    // kullaniciya gorunen bir alan degistiyse ekrani yenile.
    final cur = _safety;
    if (cur != null &&
        cur.userVerified == info.userVerified &&
        cur.identityChanged == info.identityChanged &&
        cur.hasSession == info.hasSession) {
      return;
    }
    setState(() => _safety = info);
  }

  /// 🛡️ Kullanıcıya gösterilecek güvenlik durumlarını yükle.
  Future<void> _refreshSecurityAlerts() async {
    final rot = widget.isGroup
        ? await SecurityAlerts.groupKeyRotationFailed(widget.chatId)
        : false;
    final plain = await SecurityAlerts.groupSendsPlaintext(widget.chatId);
    final dismissed = widget.isGroup
        ? true
        : await SecurityAlerts.verifyPromptDismissed(widget.chatId);
    if (!mounted) return;
    if (rot == _keyRotationFailed &&
        plain == _groupPlaintext &&
        dismissed == _verifyPromptDismissed) {
      return; // gereksiz yeniden çizim yok
    }
    setState(() {
      _keyRotationFailed = rot;
      _groupPlaintext = plain;
      _verifyPromptDismissed = dismissed;
    });
  }

  /// Rotasyonu yeniden dene. Başarılıysa uyarı kalkar.
  Future<void> _retryKeyRotation() async {
    try {
      await GroupKeyService.rotate(widget.chatId);
      await SecurityAlerts.setGroupKeyRotationFailed(widget.chatId, false);
      if (!mounted) return;
      setState(() => _keyRotationFailed = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('sec_rotation_fixed'))),
      );
    } catch (e, s) {
      reportHandled('Grup anahtarı rotasyonu (tekrar) başarısız', e, stack: s);
      if (!mounted) return;
      // Bant yerinde kalır; kullanıcı yeniden deneyebilir.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('err_unexpected'))),
      );
    }
  }

  Future<void> _dismissVerifyPrompt() async {
    await SecurityAlerts.dismissVerifyPrompt(widget.chatId);
    if (!mounted) return;
    setState(() => _verifyPromptDismissed = true);
  }

  Future<void> _openSafetyNumber() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SafetyNumberScreen(
        chatId: widget.chatId,
        peerName: widget.chatTitle,
      ),
    ));
    if (!mounted) return;
    await _refreshSafety();
  }

  /// 🔐 Kimlik anahtari degisti bandi.
  ///
  /// Column cocugu olarak degil OVERLAY olarak cizilir: bu ekranda
  /// extendBodyBehindAppBar acik oldugu icin Column'un ilk cocugu
  /// appbar'in ARKASINDA kalir (sabit mesaj bandinda ayni desen).
  Widget _buildSafetyBanner() => Material(
        color: const Color(0xFF3A1B23),
        child: InkWell(
          onTap: _openSafetyNumber,
          child: SizedBox(
            height: 38,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.gpp_maybe_rounded,
                      color: AppTheme.danger, size: 17),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      context.tr('safety_banner_changed'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.danger, fontSize: 12.5),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.danger, size: 18),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildRotationBanner() =>
      GroupKeyRotationBanner(onRetry: _retryKeyRotation);

  Widget _buildVerifyPromptBanner() => VerifyPromptBanner(
        onOpen: _openSafetyNumber,
        onDismiss: _dismissVerifyPrompt,
      );

  String? _otherUid() {
    if (widget.isGroup) return null;
    final parts = widget.chatId.split('_');
    if (parts.length == 2) {
      final other =
          parts.firstWhere((id) => id != widget.myUid, orElse: () => '');
      return other.isNotEmpty ? other : null;
    }
    return null;
  }

  void _openProfileOrInfo() {
    final other = _otherUid();
    if (other != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => UserProfileView(
          uid: other,
          fallbackUsername: widget.chatTitle,
        ),
      ));
    } else if (widget.isGroup) {
      _openInfoIfGroup();
    }
  }

  Future<void> _openInfoIfGroup() async {
    if (!widget.isGroup) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(
          chatId: widget.chatId,
          myUid: widget.myUid,
        ),
      ),
    );
    // ⚠️ Üye atma/ekleme BU EKRANDA olur ve anahtar rotasyonu orada
    // başarısız olabilir. Dönüşte bayrağı tazelemezsek uyarı bandı ancak
    // sohbet yeniden açıldığında görünürdü — yani kullanıcı atma
    // işleminden hemen sonra yanlış güvenlik hissiyle devam ederdi.
    await _refreshSecurityAlerts();
  }

  /// 📌 Sabitlenmis mesaj banner'i: gercek metni YERELDEN cozer
  /// (sunucudaki maskeyi degil), dokununca mesaja kaydirir, X ile kaldirir.
  Widget _buildPinnedBanner(MessagingState state) {
    final p = _pinned!;
    final dispP = _display(state.messages);
    final idx = dispP.indexWhere((m) => m.id == p.messageId);
    final text = idx >= 0
        ? _starPreview(dispP[idx])
        : (p.preview.isEmpty
            ? context.tr('preview_message')
            : context.trPreview(p.preview));
    return Material(
      color: AppTheme.surface,
      child: InkWell(
        onTap: () {
          if (idx >= 0) {
            _scrollToIndex(idx, dispP.length);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('load_older'))));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.glassTint, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.push_pin, size: 16, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13.5),
                ),
              ),
              GestureDetector(
                onTap: () => PinnedMessageService.unpin(widget.chatId),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close,
                      size: 18, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectivityBanner() {
    // IZOLASYON: connectivity yayini yalnizca BU banner'i rebuild etsin;
    // ekran-seviyesi watch tum ekrani (liste dahil) yeniden insa ettiriyordu
    // ("surekli ufak kasma"nin ana kaynagi).
    return Consumer(builder: (context, ref, _) {
      final connectivity = ref.watch(connectivityProvider);
      return connectivity.when(
        // TITREME FIX: MIUI'de connectivity, aboneliğin hemen ardindan
        // anlik bir "yok" yayip "var"a donebiliyor — sohbete girerken ust
        // tarafta kizil serit bir an parlayip sonuyordu. Cozum: cevrimdisi
        // durumu 1.2 sn SUREKLILIK kazanmadan serit HIC gosterilmez;
        // baglanti gelince aninda gizlenir.
        data: (isConnected) =>
            _DebouncedOfflineBanner(isConnected: isConnected),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    });
  }

  Widget _buildMessageList(MessagingState state) {
    // PERFORMANS: arama eslesmeleri BUILD basina TEK KEZ hesaplanir
    // (onceden her balon icin yeniden hesaplaniyordu — O(n^2)).
    // 🙈 gizli filtre + arama ayni listeyi kullanir (indeks tutarliligi)
    final hiddenIds = ref.watch(hiddenMessagesProvider(widget.myUid));
    final msgs = _display(state.messages);
    final searchMatches = (_searchActive &&
            (_searchQuery.trim().isNotEmpty || _searchRange != null))
        ? _searchMatches(msgs)
        : const <int>[];
    // Balon temasi: build basina TEK watch (onceden her item ayri watch)
    final bubbleTheme = ref.watch(effectiveBubbleThemeProvider(widget.chatId));
    // Yildiz gostergesi: build basina TEK okuma (id seti)
    final starredIds = ref
        .watch(starredProvider(widget.myUid))
        .map((m) => m.messageId)
        .toSet();
    if (state.isLoading) {
      // Iskelet yukleme: balon taslaklari (bos cark yerine)
      return MessageListSkeleton(
          topPadding: MediaQuery.of(context).padding.top + kToolbarHeight + 26);
    }
    if (_display(state.messages).isEmpty) {
      return _buildEmptyState();
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 26;
    // 🔐 Uyari bandi sabit mesaj bandinin USTUNDE durur; ikisi de
    // gorunuyorsa listenin ust boslugu ikisini birden saymali.
    // 🛡️ GÜVENLİK BANTLARI — sırayla üst üste dizilir.
    //
    // Öncelik önemli: kimlik değişimi bir UYARIDIR, doğrulama önerisi
    // yalnızca öneri. İkisi aynı anda gösterilmez — kimlik değiştiyse
    // zaten doğrulama düşmüştür ve kullanıcıyı iki ayrı bantla
    // yormanın anlamı yok.
    final banners = <Widget>[
      if (!widget.isGroup && (_safety?.identityChanged ?? false))
        _buildSafetyBanner()
      else if (!widget.isGroup &&
          !_verifyPromptDismissed &&
          (_safety?.hasSession ?? false) &&
          !(_safety?.userVerified ?? false))
        _buildVerifyPromptBanner(),
      if (widget.isGroup && _keyRotationFailed) _buildRotationBanner(),
      // 🔓 Şifreleme etkin değilse bunu SÖYLE. Balon başına rozet
      // koymak yanlış olurdu: `isEncrypted == false` gönderim
      // sırasındaki yer tutucularda, GIF'lerde, anketlerde ve geri
      // yüklenen yedeklerde de doğrudur ve hepsi meşrudur. Durum
      // GRUP düzeyinde bir gerçektir, mesaj düzeyinde değil.
      // ⚠️ BİREBİR sohbetlerde de gösterilir. §4aa yalnızca grup yolunu
      // kapsıyordu; oysa karşı tarafın anahtar paketi yoksa birebir mesaj
      // da şifresiz gidiyor ve o durum tamamen sinyalsizdi.
      if (_groupPlaintext) const GroupPlaintextBanner(),
    ];
    final safetyOffset = kSecurityBannerHeight * banners.length;

    final listView = ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
          top:
              topInset + safetyOffset + (_pinned != null ? 38 : 0) + Spacing.sm,
          bottom: Spacing.md + 2), // TASARIM: bara nefes payı
      itemCount: msgs.length,
      itemBuilder: (context, i) {
        final msg = msgs[i];
        final bubble = _MessageBubble(
          message: msg,
          isMine: msg.isSentBy(widget.myUid),
          myUid: widget.myUid,
          isGroup: widget.isGroup,
          bubbleTheme: bubbleTheme,
          isStarred: starredIds.contains(msg.id),
          isHidden:
              _revealHidden && hiddenIds.contains('${widget.chatId}|${msg.id}'),
          selectionMode: _selectionMode,
          isSelected: _selectedIds.contains(msg.id),
          onEnterSelection: () => _enterSelection(msg.id),
          onToggleSelect: () => _toggleSelect(msg.id),
          // TEK MESAJ SİLME: artık TOPLU silmeyle aynı seçenekleri sorar
          // (Benden sil / Herkesten sil). Eskiden doğrudan herkesten
          // siliyordu; "benden sil" sanılıp karşı tarafta da silinmesi
          // bu yüzdendi.
          onDelete: () =>
              _showDeleteOptions(msg.isSentBy(widget.myUid), ids: [msg.id]),
          onReply: () => ref
              .read(messagingNotifierProvider(widget.chatId).notifier)
              .setReplyingTo(msg),
          // ÇİFT DOKUNUŞLA 👍 (§4bg) — süreyi ekran ölçer, arena değil.
          onQuickTap: () => _baloncugaDokunuldu(msg),
          onOpenReply: _yanitlananaGit,
          onReact: (emoji) {
            // Ayni emoji tekrar secilirse kaldir, degilse ayarla (toggle)
            final current = msg.reactions[widget.myUid];
            ref
                .read(messagingNotifierProvider(widget.chatId).notifier)
                .setReaction(msg.id, current == emoji ? '' : emoji);
          },
          onConsumeViewOnce: (url) => ref
              .read(messagingNotifierProvider(widget.chatId).notifier)
              .consumeViewOnce(msg.id, url),
          onOpenStory: _openStoryById,
          onEdit: () {
            ref
                .read(messagingNotifierProvider(widget.chatId).notifier)
                .setEditing(msg);
            _textController.text = msg.content;
            _textController.selection =
                TextSelection.collapsed(offset: msg.content.length);
          },
          onForward: () => _showForwardPicker(msg.content),
          onShowPollVoters: (i) => _showPollVoters(msg, i),
        );

        // Arama eslesme vurgusu
        // 📞 CEVAPSIZ ÇAĞRI: normal mesaj balonu yerine ORTALI sistem
        // bildirimi olarak çizilir (tik/durum göstergesi yok, taraf yok).
        // 🔒 ÇÖZÜLEMEYEN MESAJ: açıklayıcı bilgi balonu
        if (msg.content == '\u0000E2EE_LOST') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 15, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.tr('e2ee_lost'),
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (msg.content.startsWith('📞 call:')) {
          // 📞 CEVAPLANAN ARAMA: '📞 call:<tur>:<saniye>' işaretini
          // kullanıcının diline çevirerek ortalı bildirim olarak göster.
          final p = msg.content.substring('📞 call:'.length).split(':');
          final isVideo = p.isNotEmpty && p[0] == 'video';
          final sec = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
          final m = sec ~/ 60, sn = sec % 60;
          final dur =
              m == 0 ? '${sn}s' : '${m}dk ${sn.toString().padLeft(2, '0')}s';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.secure.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppTheme.secure.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isVideo ? Icons.videocam : Icons.call,
                        size: 15, color: AppTheme.secure),
                    const SizedBox(width: 7),
                    Text(
                      '${isVideo ? context.tr('preview_video') : context.tr('call_label')} · $dur',
                      style: const TextStyle(
                          color: AppTheme.secure,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (msg.content == '📞 Cevapsız çağrı') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.danger.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call_missed,
                        size: 15, color: AppTheme.danger),
                    const SizedBox(width: 7),
                    Text(
                      context.tr('call_missed'),
                      style: const TextStyle(
                          color: AppTheme.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
                      '${msg.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        Widget wrapped = bubble;
        if (searchMatches.isNotEmpty) {
          final matches = searchMatches;
          if (matches.contains(i)) {
            final isCurrent = matches.isNotEmpty &&
                matches[_currentMatch % matches.length] == i;
            wrapped = Container(
              // Yalnizca GECERLI eslesmeye anahtar takilir; hassas
              // kaydirma bu anahtar uzerinden yapilir.
              key: isCurrent ? _currentMatchKey : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: AppTheme.primary
                      .withValues(alpha: isCurrent ? 0.9 : 0.35),
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: bubble,
            );
          }
        }

        // ⚡ HIZLI TEPKI: emojiler UZUN BASILAN MESAJIN HEMEN ALTINDA
        // (ustteki sabit-boy barda tasma yapiyordu — dogru yeri burasi).
        if (_selectedIds.length == 1 && _selectedIds.contains(msg.id)) {
          wrapped = Column(
            crossAxisAlignment: msg.isSentBy(widget.myUid)
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [wrapped, _quickReactStrip(msg)],
          );
        }

        // #3 KAYDIRARAK YANITLA: saga surukle -> yanit modu (WhatsApp jesti)
        wrapped = _SwipeToReply(
          enabled: !_selectionMode && !msg.isDeleted,
          onReply: () => ref
              .read(messagingNotifierProvider(widget.chatId).notifier)
              .setReplyingTo(msg),
          child: wrapped,
        );

        // PERFORMANS: giris animasyonu yalnizca GERCEKTEN YENI mesajda
        // oynar. Eskiden gorunume her geri girişte fade+kayma yeniden
        // calisiyordu — kaydirmayi agirlastiriyordu.
        final isFresh = DateTime.now().difference(msg.timestamp).inSeconds < 3;
        if (reduceMotion || !isFresh) {
          return RepaintBoundary(child: wrapped);
        }

        // Yumuşak giriş: hafif yukarı kayma + solma
        return RepaintBoundary(
            child: TweenAnimationBuilder<double>(
          key: ValueKey(msg.id),
          tween: Tween(begin: 0, end: 1),
          duration: Motion.base,
          curve: Motion.enter,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 8),
              child: child,
            ),
          ),
          child: wrapped,
        ));
      },
    );

    return Stack(
      children: [
        listView,
        // 🔐 Güvenlik bantları — her şeyin üstünde, sırayla.
        for (var i = 0; i < banners.length; i++)
          Positioned(
            top: topInset + kSecurityBannerHeight * i,
            left: 0,
            right: 0,
            child: banners[i],
          ),
        // 📌 Sabit mesaj banner'i — appbar'in hemen altinda (extendBody
        // duzeninde Column cocugu appbar arkasinda kalirdi; overlay dogru).
        if (_pinned != null)
          Positioned(
            top: topInset + safetyOffset,
            left: 0,
            right: 0,
            child: _buildPinnedBanner(state),
          ),
        // Eski sayfa yuklenirken ustte kucuk gosterge
        if (state.isLoadingMore)
          Positioned(
            top: topInset + safetyOffset + (_pinned != null ? 44 : 6),
            left: 0,
            right: 0,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppTheme.primary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    // TASARIM: tema-uyumlu karsilama (statik gradient — sifir maliyet)
    final t = ref.watch(effectiveBubbleThemeProvider(widget.chatId));
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  t.a.withValues(alpha: 0.30),
                  t.b.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: t.a.withValues(alpha: 0.4)),
            ),
            child: Icon(
                widget.isGroup
                    ? Icons.groups_outlined
                    : Icons.waving_hand_outlined,
                color: t.a,
                size: 32),
          ),
          const SizedBox(height: Spacing.lg),
          Text(context.tr('chat_start'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(context.tr('chat_start_sub'),
              style: Theme.of(context).textTheme.labelMedium),
          if (!widget.isGroup) ...[
            const SizedBox(height: Spacing.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    color: AppTheme.secure, size: 13),
                const SizedBox(width: 5),
                Text(context.tr('e2ee_note'),
                    style: TextStyle(
                        color: AppTheme.secure.withValues(alpha: 0.9),
                        fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyBar(MessagingState state, MessagingNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(color: AppTheme.primary, width: 3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: AppTheme.primary, size: 20),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              context.trPreview(state.replyingTo!.preview),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: () => notifier.setReplyingTo(null),
          ),
        ],
      ),
    );
  }

  /// 📊 Bir secenege oy verenlerin adlari (grup; veri zaten duz metin).
  Future<void> _showPollVoters(MessageEntity m, int optionIndex) async {
    final uids = m.pollVotes.entries
        .where((e) => e.value == optionIndex)
        .map((e) => e.key)
        .toList();
    if (uids.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('no_vote_option'))));
      return;
    }
    // Kullanici adlarini getir (az sayida dokuman — tek seferlik)
    final names = <String>[];
    for (final uid in uids) {
      try {
        final d =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        names.add((d.data()?['username'] ?? 'Bilinmeyen').toString());
      } catch (_) {
        names.add('Bilinmeyen');
      }
    }
    if (!mounted) return;
    final opt = (optionIndex >= 0 && optionIndex < m.pollOptions.length)
        ? m.pollOptions[optionIndex]
        : '';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"$opt" — ${names.length} ${context.tr('votes_word')}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...names.map((n) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: AppTheme.primary,
                          child: Text(n.isEmpty ? '?' : n[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Color(0xFF04141C), fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Text('@$n',
                            style:
                                const TextStyle(color: AppTheme.textPrimary)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  /// 📊 Anket olusturma sayfasi (soru + 2-6 secenek).
  void _showCreatePollSheet() {
    final qCtrl = TextEditingController();
    final optCtrls = [TextEditingController(), TextEditingController()];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.poll_outlined,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(context.tr('create_poll'),
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: qCtrl,
                    autofocus: true,
                    maxLength: 120,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                        hintText: context.tr('question'), counterText: ''),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(optCtrls.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: optCtrls[i],
                        maxLength: 60,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: '${context.tr('poll_option')} ${i + 1}',
                          counterText: '',
                          suffixIcon: optCtrls.length > 2
                              ? IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 18, color: AppTheme.textSecondary),
                                  onPressed: () =>
                                      setSheet(() => optCtrls.removeAt(i)),
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                  if (optCtrls.length < 6)
                    TextButton.icon(
                      onPressed: () =>
                          setSheet(() => optCtrls.add(TextEditingController())),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.tr('add_option')),
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final q = qCtrl.text.trim();
                        final opts = optCtrls
                            .map((c) => c.text.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        if (q.isEmpty || opts.length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(context.tr('poll_need_options'))));
                          return;
                        }
                        Navigator.pop(ctx);
                        ref
                            .read(messagingNotifierProvider(widget.chatId)
                                .notifier)
                            .sendPoll(q, opts);
                      },
                      child: Text(context.tr('send_poll')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// TASARIM: tum ekleme secenekleri tek yerde (dengeli giris cubugu).
  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) {
        Widget opt(IconData ic, String label, VoidCallback onTap) => InkWell(
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(ic, color: AppTheme.primary, size: 25),
                    ),
                    const SizedBox(height: 7),
                    Text(label,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            // TASMA FIX: 6 secenek tek satira sigmiyordu (39px overflow);
            // Wrap sigmayani alt satira akitir — her ekranda tasma imkansiz.
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                // ⚠️ Bu etiketler SABİT TÜRKÇE idi; uygulama 8 dil
                // desteklemesine rağmen ek menüsü her dilde Türkçe
                // görünüyordu. Hepsi çeviri anahtarına bağlandı.
                // ('GIF' bilinçli olarak çevrilmez — markadır.)
                opt(Icons.insert_drive_file_outlined, context.tr('file_word'),
                    _pickAndSendFile),
                opt(Icons.image_outlined, context.tr('photo_word'),
                    _showPhotoSourceMenu),
                opt(Icons.videocam_outlined, context.tr('preview_video'),
                    _showVideoSourceMenu),
                // ⚠️ SEÇENEK HER ZAMAN GÖRÜNÜR — GİZLENMEZ.
                //
                // Bir ara anahtarsız derlemede `if (GiphyService.isEnabled)`
                // ile tamamen gizleniyordu. Amaç "boş sayfa açılmasın"dı
                // ama sonuç daha kötü oldu: hiçbir derlemeye anahtar
                // konmadığı için özellik kullanıcıdan TAMAMEN kayboldu ve
                // kimse nedenini öğrenemedi.
                //
                // Doğrusu: seçenek durur, açıldığında NEDEN kullanılamadığı
                // açıkça yazılır. Sessizce yok olan özellik, hata
                // mesajından daha kötüdür.
                opt(Icons.gif_box_outlined, 'GIF', _showGifPicker),
                opt(Icons.emoji_emotions_outlined, context.tr('sticker_word'),
                    () => _showGifPicker(sticker: true)),
                opt(Icons.poll_outlined, context.tr('poll_word'),
                    _showCreatePollSheet),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(MessagingState state) {
    // Klavye yüksekliği: SafeArea bunu HER cihazda hesaba katmıyor.
    // Bu değer klavye kapalıyken 0'dır, açıkken çubuğu yukarı iter.
    // 🛡️ ENGELLİ KİŞİ: yazma çubuğu yerine bilgi şeridi. Dokununca
    // "Engellenenler" ekranına gider; engel oradan kaldırılır.
    if (!widget.isGroup) {
      final parts = widget.chatId.split('_');
      if (parts.length == 2) {
        final other = parts[0] == widget.myUid ? parts[1] : parts[0];
        final blocked = ref
                .watch(blockedUsersProvider(widget.myUid))
                .asData
                ?.value
                .contains(other) ??
            false;
        if (blocked) {
          return SafeArea(
            top: false,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BlockedUsersScreen(myUid: widget.myUid),
              )),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                color: AppTheme.surface,
                child: Row(
                  children: [
                    const Icon(Icons.block, size: 18, color: AppTheme.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(context.tr('blocked_chat_notice'),
                          style: const TextStyle(
                              color: AppTheme.danger, fontSize: 13.5)),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 20, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }

    // #13: susturulmus / yalniz-yoneticiler modunda giris cubugu yerine
    // bilgi cubugu gosterilir (yazma fiilen engellenir).
    if (_writeBlockReason != null) {
      final muted = _writeBlockReason == 'err_muted_in_group';
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          color: AppTheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(muted ? Icons.volume_off : Icons.lock_outline,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.tr(_writeBlockReason!),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isRecording) return _buildRecordingBar();
    // Tema: TEK watch (gonder butonu + ayrac ayni degeri kullanir)
    final inputTheme = ref.watch(effectiveBubbleThemeProvider(widget.chatId));
    return FrostedSurface(
      intensity: 10, // PERFORMANS: canli blur maliyeti
      tint: AppTheme.background.withValues(alpha: 0.55),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TASARIM: sohbet temasıyla uyumlu gradient ayraç —
          // eski 0.5px soluk cizginin yerine (sifir calisma maliyeti).
          Container(
            height: 2.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  inputTheme.a,
                  inputTheme.b,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25, 0.75, 1.0],
              ),
            ),
          ),
          SafeArea(
            top: false,
            // ⌨️ KLAVYE FIX
            //
            // SORUN: Bazı cihazlarda (jest navigasyonu + belirli üretici
            // ROM'ları) klavye açılınca gönderme tuşu klavyenin ALTINDA
            // kalıyordu. `SafeArea` yalnızca sistem çubuklarını hesaba katar,
            // klavyeyi (viewInsets) HER cihazda doğru yansıtmaz.
            //
            // ÇÖZÜM: Klavye yüksekliği kadar alt boşluk eklenir. Klavye
            // kapalıyken bu değer 0'dır — normal görünüm değişmez.
            // `bottom: false` ile SafeArea'nın kendi alt boşluğu devre dışı
            // bırakılır, yoksa çift boşluk oluşur.
            // Klavye açıkken SafeArea alt boşluğu GEREKSİZ (klavye zaten
            // gezinme çubuğunu kapatıyor) — açık bırakılınca çift boşluk
            // oluşuyor ve yazma alanı gereksiz yükseliyordu.
            // ⌨️ ÇİFT BOŞLUK DÜZELTMESİ
            //
            // `Scaffold(resizeToAvoidBottomInset: true)` gövdeyi klavye
            // kadar ZATEN küçültüyor. Buraya bir kez daha klavye yüksekliği
            // eklemek boşluğu İKİYE KATLIYORDU (ekran görüntüsündeki büyük
            // boşluğun sebebi buydu).
            //
            // Doğrusu: SafeArea normal işini yapsın, ek padding OLMASIN.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.md, Spacing.sm, Spacing.sm, Spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // TASARIM: 3 ikon TEK ekleme butonuna toplandi —
                  // metin alanina genis yer, dengeli orantilar.
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppTheme.textSecondary, size: 26),
                    onPressed: state.isSending ? null : _showAttachmentSheet,
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius:
                            BorderRadius.circular(24), // TASARIM: tam pill
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.lg, vertical: 4),
                      child: TextField(
                        controller: _textController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: context.tr('type_message'),
                          hintStyle:
                              const TextStyle(color: AppTheme.textSecondary),
                          // TASARIM FIX: temanin genel filled+focusedBorder'i
                          // (odaklaninca gri pill icinde KUCUK MAVI cerceve
                          // ciziyordu) burada tamamen kapatilir — tek yuzey.
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  // Yazarken büyüyen + renklenen gönder butonu
                  AnimatedScale(
                    scale: _sendPulse ? 1.18 : (_hasText ? 1.0 : 0.9),
                    duration: Motion.fast,
                    curve: Motion.emphasized,
                    child: GestureDetector(
                      onTap: _hasText ? _send : _startRecording,
                      // UZUN BAS: mesaji ILERI TARIHE zamanla
                      onLongPress: _hasText ? _scheduleCurrentText : null,
                      child: AnimatedContainer(
                        duration: Motion.fast,
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _hasText
                              ? LinearGradient(
                                  colors: [inputTheme.a, inputTheme.b],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: _hasText ? null : AppTheme.surfaceLight,
                        ),
                        child: state.isSending
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                    color: Color(0xFF04141C), strokeWidth: 2),
                              )
                            : Icon(
                                _hasText
                                    ? Icons.arrow_upward_rounded
                                    : Icons.mic,
                                color: _hasText
                                    ? const Color(0xFF04141C)
                                    : AppTheme.textSecondary,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek mesaj baloncuğu — gönderen/alıcı ayrımı + E2EE güvenli malzeme.
class _MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMine;
  final String myUid;
  final bool isGroup;
  final BubbleTheme bubbleTheme;
  final bool isStarred;
  // 🙈 gizli (goster modunda isaret icin)
  final bool isHidden;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onEnterSelection;
  final VoidCallback onToggleSelect;
  final VoidCallback onDelete;
  final VoidCallback onReply;
  final void Function(String emoji) onReact;

  /// Yanıt alıntısına dokunuldu — orijinal mesaja git (§4bp).
  final void Function(String messageId) onOpenReply;

  /// Baloncuğa TEK dokunuş (seçim modu dışında).
  ///
  /// Çift dokunuşu ekran katmanı ZAMANLA ölçer; burada `onDoubleTap`
  /// KULLANILMAZ — sebebi aşağıdaki nota yazılı.
  final VoidCallback onQuickTap;
  final void Function(String mediaUrl) onConsumeViewOnce;

  /// 📖 Hikâye alıntısına dokununca ilgili hikâyeyi açar.
  final void Function(String storyId) onOpenStory;
  final VoidCallback onEdit;
  final VoidCallback onForward;
  // 📊 grupta secenege uzun bas -> oy verenler
  final void Function(int optionIndex)? onShowPollVoters;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.myUid,
    this.isGroup = false,
    this.bubbleTheme = const BubbleTheme('teal', 'Camgöbeği',
        AppTheme.bubbleSent, AppTheme.primary, AppTheme.primaryDark),
    this.isStarred = false,
    this.isHidden = false,
    this.selectionMode = false,
    this.isSelected = false,
    required this.onEnterSelection,
    required this.onToggleSelect,
    required this.onDelete,
    required this.onReply,
    required this.onReact,
    required this.onQuickTap,
    required this.onOpenReply,
    required this.onConsumeViewOnce,
    required this.onOpenStory,
    required this.onEdit,
    required this.onForward,
    this.onShowPollVoters,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _DeletedBubble(isMine: isMine);
    }

    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    // #7 Cikartma: balon CERCEVESIZ (seffaf arka plan, padding yok)
    final isSticker = message.type == MessageContentType.gif &&
        message.mediaSource == 'sticker';
    final bubbleColor = isSticker
        ? Colors.transparent
        : (isMine ? bubbleTheme.bubble : AppTheme.bubbleReceived);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(Radii.lg),
      topRight: const Radius.circular(Radii.lg),
      bottomLeft: Radius.circular(isMine ? Radii.lg : Radii.sm),
      bottomRight: Radius.circular(isMine ? Radii.sm : Radii.lg),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        if (selectionMode) {
          onToggleSelect();
        } else {
          HapticFeedback.mediumImpact();
          onEnterSelection();
        }
      },
      onTap: selectionMode ? onToggleSelect : onQuickTap,
      // ⚠️ `onDoubleTap` HÂLÂ KULLANILMIYOR — bilerek.
      //
      // Çift-dokunuş tanımlayıcısı, ikinci dokunuşu beklemek için HER tek
      // dokunuşun çözümünü ~300 ms geciktirir (Flutter gesture arena).
      // Bu, daha önce "basıyorum yarım saniye sonra tepki veriyor" diye
      // bildirilen gecikmenin köküydü ve o yüzden kaldırılmıştı.
      //
      // Çift dokunuşla 👍 tepkisi (§4bg) bu yüzden ARENA DIŞINDA çalışır:
      // tek dokunuşlar normal hızda geçer, ekran katmanı iki dokunuş
      // arasındaki SÜREYİ ölçerek çift dokunuşa karar verir. Böylece
      // özellik geri geldi ama gecikme geri gelmedi.
      child: Container(
        color: isSelected
            ? AppTheme.primary.withValues(alpha: 0.16)
            : Colors.transparent,
        child: Align(
          alignment: align,
          child: Container(
            margin:
                const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 3),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            padding: isSticker
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(
                    horizontal: Spacing.lg, vertical: Spacing.md - 2),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: radius,
              // E2EE "güvenli malzeme": ince sol kenar.
              // 🎨 Kendi mesajlarımda SOHBET RENGİNİ alır (sabit yeşil,
              // değişen balon rengiyle uyumsuz duruyordu); gelen
              // mesajlarda güvenlik yeşili kalır.
              // 🎨 Sol kenar çizgisi HER İKİ TARAFTA da sohbet rengini alır.
              // (Önce yalnızca kendi mesajlarımda uygulanmıştı; gelen
              // mesajlarda sabit yeşil kalınca renk uyumu bozuluyordu.)
              border: (message.isEncrypted && !isSticker)
                  ? Border(
                      left: BorderSide(color: bubbleTheme.a, width: 2),
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 📖 HİKÂYE YANITI: 'story:<id>:<önizleme>' işaretli alıntı
                // özel çizilir ve DOKUNULABİLİR — ilgili hikâyeye götürür.
                if (message.replyToPreview != null &&
                    message.replyToPreview!.startsWith('story:'))
                  Builder(builder: (context) {
                    final parts = message.replyToPreview!.split(':');
                    final storyId = parts.length > 1 ? parts[1] : '';
                    final preview =
                        parts.length > 2 ? parts.sublist(2).join(':') : '';
                    return GestureDetector(
                      onTap: () => onOpenStory(storyId),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(Spacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(Radii.sm),
                          border: Border(
                            left: BorderSide(color: bubbleTheme.a, width: 3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_stories_outlined,
                                size: 14, color: bubbleTheme.a),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(context.tr('story_reply_label'),
                                      style: TextStyle(
                                          color: bubbleTheme.a,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  if (preview.isNotEmpty)
                                    Text(preview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                else if (message.replyToPreview != null)
                  // ── ALINTIYA DOKUNUNCA ORİJİNALE GİT (§4bp) ──
                  // Alıntı şimdiye kadar ölü bir kutuydu: neye yanıt
                  // verildiğini gösteriyor ama oraya GÖTÜRMÜYORDU. Uzun
                  // sohbette bağlamı bulmak için elle yukarı kaydırmak
                  // gerekiyordu. Hikâye alıntısında bu davranış zaten
                  // vardı; mesaj alıntısında eksikti.
                  GestureDetector(
                    onTap: message.replyToId == null
                        ? null
                        : () => onOpenReply(message.replyToId!),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(Spacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(Radii.sm),
                        border: Border(
                          left: BorderSide(color: bubbleTheme.a, width: 3),
                        ),
                      ),
                      child: Text(
                        message.replyToPreview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                if (message.type == MessageContentType.gif &&
                    message.mediaSource == 'sticker' &&
                    message.mediaUrl != null)
                  // #7 Cikartma: seffaf, cercevesiz, kompakt
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: CachedNetworkImage(
                      imageUrl: message.mediaUrl!,
                      memCacheWidth: 400,
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(
                          width: 140,
                          height: 140,
                          child: Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primary)))),
                      errorWidget: (_, __, ___) => const SizedBox(
                          width: 140,
                          height: 140,
                          child: Icon(Icons.broken_image_outlined,
                              color: AppTheme.textSecondary)),
                    ),
                  )
                else if (message.type == MessageContentType.image ||
                    message.type == MessageContentType.gif)
                  _buildImageContent(context)
                else if (message.type == MessageContentType.voice &&
                    message.mediaUrl != null)
                  _VoiceBubble(
                    url: message.mediaUrl!,
                    durationMs: message.voiceDurationMs ?? 0,
                    mediaKey: message.mediaKey,
                  )
                else if (message.type == MessageContentType.poll)
                  _PollBubble(
                    message: message,
                    myUid: myUid,
                    isGroup: isGroup,
                    accent: bubbleTheme.a,
                    onVote: (i) =>
                        PollService.vote(message.chatId, message.id, myUid, i),
                    onClose: () =>
                        PollService.close(message.chatId, message.id),
                    onShowVoters: onShowPollVoters,
                  )
                // 🎥 TEK GÖRÜNTÜLÜK VİDEO: fotoğrafla aynı mantık.
                // Gönderen tekrar göremez; alıcı bir kez izler ve dosya
                // sunucudan silinir. Eskiden video için hiç uygulanmıyordu.
                else if (message.type == MessageContentType.video &&
                    message.viewOnce)
                  (message.mediaUrl == null || message.mediaUrl!.isEmpty)
                      ? _viewOncePlaceholder(
                          context.tr('viewed'), Icons.visibility_off)
                      : (isMine
                          ? _viewOncePlaceholder(context.tr('once_video'),
                              Icons.visibility_off_outlined)
                          : _OnceVideoBubble(
                              url: message.mediaUrl!,
                              sizeBytes: message.fileSizeBytes,
                              mediaKey: message.mediaKey,
                              onConsume: () =>
                                  onConsumeViewOnce(message.mediaUrl!),
                            ))
                else if (message.type == MessageContentType.video &&
                    message.mediaUrl != null)
                  _VideoBubble(
                    url: message.mediaUrl!,
                    sizeBytes: message.fileSizeBytes,
                    mediaKey: message.mediaKey,
                  )
                else if (message.type == MessageContentType.file &&
                    message.mediaUrl != null)
                  _FileBubble(
                    url: message.mediaUrl!,
                    name: message.fileName ?? 'Dosya',
                    sizeBytes: message.fileSizeBytes,
                  )
                else
                  _MentionText(
                    text: message.content,
                    baseStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isEdited) ...[
                      Text(context.tr('edited_low'),
                          style: TextStyle(
                              color:
                                  AppTheme.textPrimary.withValues(alpha: 0.45),
                              fontSize: 10,
                              fontStyle: FontStyle.italic)),
                      const SizedBox(width: 5),
                    ],
                    if (isStarred) ...[
                      const Icon(Icons.star,
                          size: 11, color: Color(0xFFFFC94D)),
                      const SizedBox(width: 4),
                    ],
                    if (isHidden) ...[
                      const Icon(Icons.visibility_off,
                          size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                    ],
                    if (message.isEncrypted) ...[
                      // 🎨 Kilit ikonu SOHBET RENGİNİ alır.
                      // Eskiden sabit yeşildi; sohbet rengi değişince
                      // uyumsuz duruyordu. Kendi mesajlarımda tema
                      // vurgusu, gelen mesajlarda güvenlik yeşili.
                      Icon(Icons.lock, size: 10, color: bubbleTheme.a),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                          color: AppTheme.textPrimary.withValues(alpha: 0.45),
                          fontSize: 11),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      _StatusIcon(status: message.status),
                    ],
                  ],
                ),
                if (message.reactions.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children:
                        _groupReactions(message.reactions).entries.map((e) {
                      final mine = message.reactions[myUid] == e.key;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppTheme.primary.withValues(alpha: 0.30)
                              : Colors.black.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${e.key} ${e.value}',
                            style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, int> _groupReactions(Map<String, String> reactions) {
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  /// Tam ekran aç. DÖNÜŞ: resim gerçekten yüklendi mi?
  ///
  /// 🐞 `mediaKey` GEÇİLMİYORDU (§4as). Sohbet medyası AES-GCM ile
  /// şifrelenip Storage'a `application/octet-stream` olarak yazılıyor;
  /// çözme anahtarı sunucuya HİÇ yazılmaz, mesajla birlikte bellekte
  /// taşınır (`MessageModel.mediaKey`). Anahtar geçilmeyince tam ekran
  /// görüntüleyici ŞİFRELİ baytları çözücüye veriyordu ve Android:
  ///
  ///   E/FlutterImageDecoderImplDefault: Failed to decode image
  ///   ImageDecoder$DecodeException: ... 'unimplemented' Input contained an error.
  ///
  /// Baloncuktaki küçük hâl `SecureMediaImage` üzerinden anahtarla
  /// çözüldüğü için ÇALIŞIYORDU — bu yüzden hata yalnızca fotoğrafa
  /// dokununca ortaya çıkıyordu.
  Future<bool> _openFullScreen(BuildContext context, String url) {
    return FullScreenImage.open(context, url, mediaKey: message.mediaKey);
  }

  /// Resim icerigini duruma gore cizer: normal / tek-goruntuluk (bulanik) /
  /// tuketilmis (goruntulendi).
  Widget _buildImageContent(BuildContext context) {
    final url = message.mediaUrl;
    final consumed = url == null || url.isEmpty;

    if (message.viewOnce) {
      if (consumed) {
        return _viewOncePlaceholder(
            context.tr('viewed_word'), Icons.visibility_off);
      }
      if (isMine) {
        // Gonderen tekrar goremez (Telegram mantigi)
        return _viewOncePlaceholder(
            context.tr('once_photo'), Icons.visibility_off_outlined);
      }
      // Alici: bulanik + dokun-goster; goruntuleyince tuketilir (silinir)
      return GestureDetector(
        onTap: selectionMode
            ? onToggleSelect
            : () async {
                // ⏳ SADECE GÖRÜLDÜYSE TÜKET
                // Yavaş bağlantıda resim yüklenmeden çıkılırsa hak
                // yanmaz; kullanıcı tekrar deneyebilir.
                final seen = await _openFullScreen(context, url);
                if (seen) {
                  onConsumeViewOnce(url); // Storage'dan gerçekten sil
                }
              },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                // 🔐 Şifreli ek: indirilip ÇÖZÜLDÜKTEN sonra çizilir.
                child: SecureMediaImage(
                  url: url,
                  mediaKey: message.mediaKey,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder:
                      Container(height: 200, width: 200, color: Colors.black26),
                  errorWidget:
                      Container(height: 120, width: 200, color: Colors.black26),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 30),
                  const SizedBox(height: 4),
                  Text(context.tr('tap_to_view'),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Normal foto
    if (consumed) {
      return _viewOncePlaceholder(
          'Fotoğraf kaldırıldı', Icons.image_not_supported);
    }
    return GestureDetector(
      onTap:
          selectionMode ? onToggleSelect : () => _openFullScreen(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Stack(
          children: [
            // ⚡ YEREL DOSYA mı, ağdan mı?
            // Gönderilmekte olan fotoğrafın yolu yereldir (henüz
            // yüklenmedi). `CachedNetworkImage` yerel dosyayı açamaz,
            // bu yüzden ayrım yapılır.
            if (!url.startsWith('http'))
              Image.file(
                File(url),
                width: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  width: 200,
                  color: Colors.black26,
                ),
              )
            else
              // 🔐 Şifreli ek: indir + çöz + yerel dosyadan çiz.
              // Eski (şifresiz) mesajlarda mediaKey null'dur ve widget
              // otomatik olarak eski davranışa döner.
              SecureMediaImage(
                url: url,
                mediaKey: message.mediaKey,
                fit: BoxFit.cover,
                placeholder: Container(
                  height: 160,
                  width: 200,
                  color: Colors.black26,
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: Container(
                  height: 100,
                  width: 200,
                  color: Colors.black26,
                  child: const Icon(Icons.broken_image,
                      color: AppTheme.textSecondary),
                ),
              ),

            // YÜKLENİYOR KATMANI: gönderim sürerken fotoğrafın üstünde
            // YÜZDE + halka göstergesi (WhatsApp'taki gibi).
            if (message.status == MessageDeliveryStatus.sending)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: ValueListenableBuilder<double?>(
                      valueListenable: UploadProgress.instance.progress,
                      builder: (context, value, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              // Değer bilinmiyorsa belirsiz mod
                              value: value,
                              strokeWidth: 3,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          if (value != null) ...[
                            const SizedBox(height: 8),
                            Text('%${(value * 100).round()}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (message.mediaSource != null)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        message.mediaSource == 'camera'
                            ? Icons.camera_alt
                            : Icons.photo_library,
                        size: 11,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        message.mediaSource == 'camera' ? 'Kamera' : 'Galeri',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _viewOncePlaceholder(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  /// 🕐 KABA ZAMAN DAMGASI
  ///
  /// Ayar açıkken mesaj saatleri SAATE YUVARLANIR (14:37 → 14:00).
  /// Amaç: mesajlaşma düzeninden kişinin günlük rutininin çıkarılmasını
  /// zorlaştırmak (metadata gizliliği).
  ///
  /// NOT: Bu ayar ekranda VARDI ama hiçbir yerde KULLANILMIYORDU —
  /// anahtarı açmak/kapatmak hiçbir şeyi değiştirmiyordu.
  String _formatTime(DateTime t) {
    final coarse = getIt<PrivacySettingsReader>().current.coarseTimestamps;
    final h = t.hour.toString().padLeft(2, '0');
    if (coarse) return '$h:00';
    return '$h:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _DeletedBubble extends StatelessWidget {
  final bool isMine;
  const _DeletedBubble({required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 3),
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.md - 2),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(context.tr('msg_deleted'),
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageDeliveryStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final faint = AppTheme.textPrimary.withValues(alpha: 0.45);
    switch (status) {
      case MessageDeliveryStatus.sending:
        return Icon(Icons.access_time, size: 12, color: faint);
      case MessageDeliveryStatus.sent:
        return Icon(Icons.check, size: 13, color: faint);
      case MessageDeliveryStatus.delivered:
        return Icon(Icons.done_all, size: 13, color: faint);
      case MessageDeliveryStatus.read:
        return const Icon(Icons.done_all, size: 13, color: AppTheme.primary);
      case MessageDeliveryStatus.failed:
        return const Icon(Icons.error_outline,
            size: 13, color: AppTheme.danger);
    }
  }
}

/// Sesli mesaj baloncugu: oynat/durdur + ilerleme + sure.
class _VoiceBubble extends StatefulWidget {
  final String url;
  final int durationMs;

  /// Şifreli ek anahtarı. null ise ses ŞİFRESİZDİR (eski mesajlar).
  final String? mediaKey;

  const _VoiceBubble(
      {required this.url, required this.durationMs, this.mediaKey});

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  // PERFORMANS: player TEMBEL olusturulur. Onceden her ses balonu
  // GORUNUR OLDUGU AN native MediaPlayer yaratiyordu (platform kanal +
  // native kaynak) — sesli mesajli sohbetlerde kaydirma jank'inin
  // kaynagiydi. Simdi yalnizca ILK oynatmada kurulur.
  AudioPlayer? _player;
  bool _playing = false;

  // #8 Oynatma hizi — OTURUM GENELI paylasilir (WhatsApp gibi):
  // bir baloncukta 1.5x secince sonraki tum sesler de o hizda baslar.
  static double _globalRate = 1.0;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _total = Duration(milliseconds: widget.durationMs);
  }

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    p.onPlayerStateChanged.listen((st) {
      if (mounted) setState(() => _playing = st == PlayerState.playing);
    });
    p.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    p.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });
    p.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
    _player = p;
    return p;
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  /// 🐞 SES ŞİFRELİ URL'DEN OYNATILMAYA ÇALIŞILIYORDU (§4as).
  ///
  /// `sendMediaMessage` sesi de AES-GCM ile şifreliyor; `UrlSource(url)`
  /// oynatıcıya ŞİFRELİ baytları veriyordu ve sesli mesaj HİÇ çalmıyordu.
  /// Artık önce indirilip çözülür, sonra YEREL dosyadan çalınır.
  Future<Source> _kaynak() async {
    final k = widget.mediaKey;
    if (k == null || k.isEmpty) return UrlSource(widget.url); // eski mesajlar
    final dosya =
        await SecureMediaCache.instance.resolve(widget.url, key: k, ext: 'm4a');
    return DeviceFileSource(dosya.path);
  }

  Future<void> _toggle() async {
    final player = _ensurePlayer();
    if (_playing) {
      await player.pause();
    } else if (_position == Duration.zero) {
      await player.play(await _kaynak());
      await player.setPlaybackRate(_globalRate);
    } else {
      await player.resume();
      await player.setPlaybackRate(_globalRate);
    }
  }

  /// 🎵 Dalga formuna dokunarak/kaydirarak SARMA.
  /// Henuz oynatilmamis sesde de calisir: once yuklenir, sonra sarilir.
  Future<void> _seekFraction(double f) async {
    final total = _total.inMilliseconds > 0
        ? _total
        : Duration(milliseconds: widget.durationMs);
    if (total.inMilliseconds <= 0) return;
    final target = Duration(
        milliseconds: (total.inMilliseconds * f.clamp(0.0, 1.0)).round());
    final player = _ensurePlayer();
    try {
      if (_position == Duration.zero && !_playing) {
        // Kaynak henuz yuklenmemis olabilir
        await player.play(await _kaynak());
        await player.setPlaybackRate(_globalRate);
      }
      await player.seek(target);
      if (mounted) setState(() => _position = target);
    } catch (e) {
      debugPrint('Ses sarma hatasi: $e');
    }
  }

  void _cycleRate() {
    setState(() {
      _globalRate = _globalRate >= 2.0 ? 1.0 : (_globalRate >= 1.5 ? 2.0 : 1.5);
    });
    // Su an caliyorsa aninda uygula
    _player?.setPlaybackRate(_globalRate);
    HapticFeedback.selectionClick();
  }

  String _rateLabel() =>
      _globalRate == 1.0 ? '1x' : (_globalRate == 1.5 ? '1.5x' : '2x');

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _total.inMilliseconds > 0
        ? _total
        : Duration(milliseconds: widget.durationMs);
    final progress = total.inMilliseconds > 0
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Icon(
            _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: AppTheme.primary,
            size: 38,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎵 DALGA FORMU: düz çubuk yerine ses dalgası görünümü.
            // DÜRÜST NOT: bu gerçek genlik verisi DEĞİL — sesi çözmek
            // pahalı olurdu. Mesaj kimliğinden türetilmiş SABİT bir
            // desen; aynı mesaj her açılışta aynı görünür, rastgele
            // titremez. İşlevi: ilerlemeyi göstermek ve sarma yüzeyi olmak.
            _Waveform(
              seed: widget.url.hashCode,
              progress: progress,
              onSeek: _seekFraction,
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fmt((_playing || _position > Duration.zero)
                      ? _position
                      : total),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
                if (_playing || _position > Duration.zero) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _cycleRate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        _rateLabel(),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Bilgi diyaloğunda tek okuyucu satırı (foto + @kullanıcıadı).
class _ReaderRow extends ConsumerWidget {
  final String uid;
  const _ReaderRow({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid)).asData?.value;
    final username = profile?.username ?? '...';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          UserAvatar(uid: uid, fallbackLetter: '', radius: 13),
          const SizedBox(width: 8),
          Text('@$username',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Giphy GIF seçici: arama (300ms debounce) + ızgara.
class _GifPicker extends StatefulWidget {
  final void Function(String url, bool sticker) onSelected;
  final bool initialSticker;
  const _GifPicker({required this.onSelected, this.initialSticker = false});

  @override
  State<_GifPicker> createState() => _GifPickerState();
}

class _GifPickerState extends State<_GifPicker> {
  // #7: false=GIF, true=Cikartma (Giphy Stickers)
  late bool _stickerMode = widget.initialSticker;
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GiphyGif> _gifs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    try {
      final gifs = _stickerMode
          ? await GiphyService.trendingStickers()
          : await GiphyService.trending();
      if (mounted) {
        setState(() {
          _gifs = gifs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'GIF yüklenemedi';
          _loading = false;
        });
      }
    }
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final gifs = q.trim().isEmpty
            ? (_stickerMode
                ? await GiphyService.trendingStickers()
                : await GiphyService.trending())
            : (_stickerMode
                ? await GiphyService.searchStickers(q.trim())
                : await GiphyService.search(q.trim()));
        if (mounted) {
          setState(() {
            _gifs = gifs;
            _loading = false;
            _error = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Arama başarısız';
            _loading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: false,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.tr('gif_search'),
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon:
                    const Icon(Icons.search, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          // #7: GIF | Cikartma sekmeleri
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [false, true].map((sticker) {
                final selected = _stickerMode == sticker;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text(sticker ? 'Çıkartma' : 'GIF'),
                    selected: selected,
                    selectedColor: AppTheme.primary.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                        fontSize: 13),
                    onSelected: (_) {
                      if (_stickerMode == sticker) return;
                      setState(() {
                        _stickerMode = sticker;
                        _loading = true;
                        _gifs = [];
                      });
                      _loadTrending();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style:
                                const TextStyle(color: AppTheme.textSecondary)))
                    : _gifs.isEmpty
                        ? Center(
                            child: Text(context.tr('gif_not_found'),
                                style: const TextStyle(
                                    color: AppTheme.textSecondary)))
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.3,
                            ),
                            itemCount: _gifs.length,
                            itemBuilder: (context, i) => GestureDetector(
                              onTap: () =>
                                  widget.onSelected(_gifs[i].url, _stickerMode),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: _gifs[i].url,
                                  memCacheWidth: 300, // PERFORMANS
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      Container(color: Colors.black26),
                                  errorWidget: (_, __, ___) => Container(
                                      color: Colors.black26,
                                      child: const Icon(Icons.broken_image,
                                          color: AppTheme.textSecondary)),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

/// #3 Kaydirarak yanitla: mesaji SAGA surukle -> esik asilirsa yanit modu.
/// Yatay surukleme, dikey liste kaydirmasiyla ve balonun tap/uzun-bas
/// jestleriyle cakismaz (ayri gesture arena). Birakinca yumusakca geri doner.
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback onReply;
  const _SwipeToReply({
    required this.child,
    required this.enabled,
    required this.onReply,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _dx = 0;
  bool _dragging = false;
  static const double _max = 64;
  static const double _trigger = 46;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (d) =>
          setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, _max)),
      onHorizontalDragEnd: (_) => _release(),
      onHorizontalDragCancel: _release,
      child: Stack(
        children: [
          // Arkada beliren yanit ikonu
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Opacity(
                  opacity: (_dx / _trigger).clamp(0.0, 1.0),
                  child: const Icon(Icons.reply,
                      color: AppTheme.primary, size: 22),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration:
                _dragging ? Duration.zero : const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }

  void _release() {
    final fire = _dx >= _trigger;
    setState(() {
      _dragging = false;
      _dx = 0;
    });
    if (fire) {
      HapticFeedback.mediumImpact();
      widget.onReply();
    }
  }
}

/// #6 Dosya balonu: ikon + ad + boyut; dokununca tarayicida acar/indirir.
class _FileBubble extends StatelessWidget {
  final String url;
  final String name;
  final int? sizeBytes;
  const _FileBubble({required this.url, required this.name, this.sizeBytes});

  String _fmtSize(int b) {
    if (b >= 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('file_open_fail'))));
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.insert_drive_file_outlined,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  if (sizeBytes != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _fmtSize(sizeBytes!),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cevrimdisi seridi — 1.2 sn kararlilik esigiyle (anlik titremeler gizli).
class _DebouncedOfflineBanner extends StatefulWidget {
  final bool isConnected;
  const _DebouncedOfflineBanner({required this.isConnected});

  @override
  State<_DebouncedOfflineBanner> createState() =>
      _DebouncedOfflineBannerState();
}

class _DebouncedOfflineBannerState extends State<_DebouncedOfflineBanner> {
  bool _show = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _DebouncedOfflineBanner old) {
    super.didUpdateWidget(old);
    if (old.isConnected != widget.isConnected) _sync();
  }

  void _sync() {
    _timer?.cancel();
    if (widget.isConnected) {
      if (_show) setState(() => _show = false);
    } else {
      _timer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted && !widget.isConnected) {
          setState(() => _show = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.standard,
      child: !_show
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: const Color(0xFF3A2D14),
              padding: const EdgeInsets.symmetric(
                  vertical: 6, horizontal: Spacing.md),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, color: Color(0xFFE0A93C), size: 15),
                  SizedBox(width: Spacing.sm),
                  Text(
                    'Çevrimdışı — mesajlar bağlanınca gönderilecek',
                    style: TextStyle(color: Color(0xFFE0A93C), fontSize: 13),
                  ),
                ],
              ),
            ),
    );
  }
}

/// #14 Metin icindeki @kullanici parcalarini vurgular (renkli + kalin).
/// #14 @vurgu + 🌐 tiklanabilir linkler.
/// Stateful: TapGestureRecognizer'lar YASAM DONGUSUYLE yonetilir
/// (stateless'ta recognizer sizintisi olurdu — bilinen Flutter tuzagi).
class _MentionText extends StatefulWidget {
  final String text;
  final TextStyle? baseStyle;
  const _MentionText({required this.text, this.baseStyle});

  @override
  State<_MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<_MentionText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _linkTap(String url) {
    final target = url.startsWith('http') ? url : 'https://$url'; // www. duzelt
    final r = TapGestureRecognizer()
      ..onTap = () async {
        try {
          await launchUrl(Uri.parse(target),
              mode: LaunchMode.externalApplication);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('link_open_fail'))));
          }
        }
      };
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    // eski recognizer'lari temizle (metin degisiminde yeniden kurulur)
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final pattern = RegExp(r'(@\w+|https?://[^\s]+|www\.[^\s]+)');
    if (!pattern.hasMatch(text)) {
      return Text(text, style: widget.baseStyle);
    }
    final spans = <TextSpan>[];
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final tok = m.group(0)!;
      if (tok.startsWith('@')) {
        spans.add(TextSpan(
          text: tok,
          style: const TextStyle(
              color: AppTheme.primary, fontWeight: FontWeight.w600),
        ));
      } else {
        spans.add(TextSpan(
          text: tok,
          style: const TextStyle(
              color: AppTheme.primary, decoration: TextDecoration.underline),
          recognizer: _linkTap(tok),
        ));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(
      text: TextSpan(style: widget.baseStyle, children: spans),
    );
  }
}

/// 📊 Anket balonu: canli sonuc cubuklari, oy degistirme destekli.
class _PollBubble extends StatelessWidget {
  final MessageEntity message;
  final String myUid;
  final bool isGroup;
  final Color accent;
  final void Function(int optionIndex) onVote;
  final VoidCallback onClose;
  final void Function(int optionIndex)? onShowVoters;
  const _PollBubble(
      {required this.message,
      required this.myUid,
      this.isGroup = false,
      required this.accent,
      required this.onVote,
      required this.onClose,
      this.onShowVoters});

  @override
  Widget build(BuildContext context) {
    final votes = message.pollVotes;
    final total = votes.length;
    final myVote = votes[myUid];
    final closed = message.pollClosed;
    final mine = message.senderId == myUid;
    final counts = List<int>.filled(message.pollOptions.length, 0);
    for (final v in votes.values) {
      if (v >= 0 && v < counts.length) counts[v]++;
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.poll_outlined, size: 16, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(message.content,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(message.pollOptions.length, (i) {
            final frac = total == 0 ? 0.0 : counts[i] / total;
            final selected = myVote == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: InkWell(
                onTap: closed ? null : () => onVote(i),
                onLongPress: (isGroup && onShowVoters != null)
                    ? () => onShowVoters!(i)
                    : null,
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  children: [
                    // sonuc dolgusu
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: frac.clamp(0.0, 1.0),
                            child: Container(
                                color: accent.withValues(alpha: 0.28)),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: selected
                                ? accent
                                : AppTheme.textSecondary
                                    .withValues(alpha: 0.35),
                            width: selected ? 1.6 : 0.8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 15,
                              color:
                                  selected ? accent : AppTheme.textSecondary),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(message.pollOptions[i],
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13.5)),
                          ),
                          Text('${counts[i]}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Row(
            children: [
              Expanded(
                child: Text(
                  closed
                      ? '🔒 ${context.tr('poll_closed')} · $total ${context.tr('votes_word')}'
                      : (total == 0
                          ? context.tr('no_votes_tap')
                          : '$total ${context.tr('votes_word')} · ${context.tr('can_change_vote')}'),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
              if (mine && !closed)
                GestureDetector(
                  onTap: onClose,
                  child: Text(context.tr('finish'),
                      style: TextStyle(
                          color: accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 🎥 Video balonu: koyu kart + oynat rozetı; dokununca uygulama-ici
/// oynatici acilir (kucuk resim v1'de yok — durust odun).
class _VideoBubble extends StatelessWidget {
  final String url;
  final int? sizeBytes;

  /// Şifreli ek anahtarı — oynatıcı çözebilsin diye taşınır (§4as).
  final String? mediaKey;

  const _VideoBubble({required this.url, this.sizeBytes, this.mediaKey});

  String _fmtSize(int b) => b >= 1024 * 1024
      ? '${(b / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(b / 1024).toStringAsFixed(0)} KB';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(url: url, mediaKey: mediaKey))),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 210,
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFF0B151B),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.25)),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Color(0xFF04141C), size: 28),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: Row(
                children: [
                  const Icon(Icons.videocam,
                      size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    sizeBytes == null
                        ? 'Video'
                        : 'Video · ${_fmtSize(sizeBytes!)}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🎵 SES DALGA FORMU
///
/// Mesaj kimliğinden türetilen SABİT bir çubuk deseni çizer; oynatılan
/// kısım vurgulanır. Dokunma/kaydırma ile sarma sağlar.
///
/// Neden gerçek genlik yok: ses dosyasını çözüp örnekleme yapmak her
/// balon için pahalı bir iş (CPU + bellek) ve kaydırma akıcılığını bozar.
/// Sabit desen, kullanıcıya ilerleme ve dokunma yüzeyi sağlamak için
/// yeterli — sahte veriyi gerçekmiş gibi sunmuyoruz.
class _Waveform extends StatelessWidget {
  final int seed;
  final double progress;
  final ValueChanged<double> onSeek;

  const _Waveform({
    required this.seed,
    required this.progress,
    required this.onSeek,
  });

  static const int _barCount = 32;
  static const double _width = 130;
  static const double _height = 22;

  /// Deterministik yükseklikler (aynı mesaj → aynı desen)
  List<double> _heights() {
    var x = seed == 0 ? 1 : seed.abs();
    final out = <double>[];
    for (var i = 0; i < _barCount; i++) {
      // Basit doğrusal eşlenik üreteç — kütüphane gerekmez
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      final r = (x >> 16) % 100 / 100.0; // 0..1
      // Uçları kısalt, ortayı yükselt: konuşma dalgasına benzesin
      final center = 1 - ((i / (_barCount - 1)) - 0.5).abs() * 2;
      out.add(0.25 + r * 0.55 + center * 0.2);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final heights = _heights();
    final playedBars = (progress * _barCount).floor();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => onSeek(d.localPosition.dx / _width),
      onHorizontalDragUpdate: (d) => onSeek(d.localPosition.dx / _width),
      child: SizedBox(
        width: _width,
        height: _height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (i) {
            final played = i < playedBars;
            return Container(
              width: 2.5,
              height: _height * heights[i],
              decoration: BoxDecoration(
                color: played ? AppTheme.primary : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// 🎥 TEK GÖRÜNTÜLÜK VİDEO BALONU
///
/// Fotoğraftaki mantığın video karşılığı: bulanık kapak + "bir kez izle"
/// uyarısı. İzleme bittiğinde [onConsume] çağrılır; dosya Storage'dan
/// silinir ve mesajdaki bağlantı temizlenir — tekrar izlenemez.
class _OnceVideoBubble extends StatelessWidget {
  final String url;
  final int? sizeBytes;
  final VoidCallback onConsume;

  /// Şifreli ek anahtarı — oynatıcı çözebilsin diye taşınır (§4as).
  final String? mediaKey;

  const _OnceVideoBubble({
    required this.url,
    required this.onConsume,
    this.sizeBytes,
    this.mediaKey,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(url: url, mediaKey: mediaKey),
        ));
        // İzleme ekranından dönüldü → tüket (sunucudan sil)
        onConsume();
      },
      child: Container(
        width: 220,
        height: 130,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_outline,
                size: 40, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(context.tr('once_video_tap'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
