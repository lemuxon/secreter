import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/chat_theme.dart';
import '../../../../services/app_update_service.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/conversations_notifier.dart';
import '../../../messaging/presentation/screens/messaging_screen.dart';
import '../../../search/presentation/screens/search_user_screen.dart';
import '../../../search/presentation/screens/channel_search_screen.dart';
import '../../../group/presentation/screens/create_group_screen.dart';
import '../../../group/presentation/screens/create_channel_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../story/presentation/providers/story_notifier.dart';
import '../../../story/domain/entities/story_entity.dart';
import '../../../story/presentation/screens/story_creator_screen.dart';
import '../../../story/presentation/screens/story_viewer_screen.dart';
import '../../../call/presentation/providers/call_providers.dart';
import '../../../call/presentation/screens/incoming_call_screen.dart';
import '../../../call/domain/entities/call_entity.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/providers/active_chat_provider.dart';
import '../../../../core/presence/presence.dart';
import '../../../../core/prefs/chat_prefs.dart';
import '../../../../core/di/injection.dart';
import '../../../group/domain/usecases/group_usecases.dart';
import '../../../../services/mute_service.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../services/direct_chat_service.dart';
import '../../../../services/self_note_service.dart';
import '../../../../services/rehandshake_service.dart';
import '../../../../core/observability/handled_error.dart';
import '../../../security/presentation/app_lock_wrapper.dart';
import '../../../../services/privacy_service.dart';
import '../../../../services/home_widget_service.dart';
import '../../../../core/prefs/user_aliases.dart';
import '../../../../core/auth/current_user_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/security/chat_lock_service.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../messaging/presentation/providers/connectivity_provider.dart';
import '../../../security/presentation/chat_pin_screen.dart';
import '../../../group/domain/repositories/group_repository.dart';
import '../../../../services/notification_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../call/presentation/screens/call_log_screen.dart';
import '../../../../services/call_log_service.dart';
import '../../../../services/block_service.dart';
import '../../../../services/call_service.dart';
import '../../../search/presentation/screens/meet_code_screen.dart';
import '../../../../services/key_management_service.dart';

/// Ana kabuk: altta Sohbet / Hikaye / Kanal sekmeleri (kaydırmalı PageView).
/// Gelen arama dinleyicisi burada tutulur (tüm sekmelerde aktif).
class HomeShell extends ConsumerStatefulWidget {
  final String myUid;
  const HomeShell({super.key, required this.myUid});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  final _pageController = PageController();
  int _index = 0;
  // Ayni cagri icin ekranin iki kez acilmamasi (yeniden-dinleme kenari)
  final Set<String> _handledCallIds = {};

  // 🔕 etiket tespiti icin (on-plan bildirim kapisi)
  String? _myUsername;

  // Cevapsiz cagri sayaci: abonelik state'te tutulur. NavigationBar'in
  // icine StreamBuilder koymak (ikonun kendisi olarak) alisilmadik bir
  // yapiydi; sadelestirildi.
  StreamSubscription<int>? _missedSub;
  StreamSubscription? _handshakeSub;
  int _missedCount = 0;

  /// Play'e göre yeni sürüm var mı (§4bl).
  bool _guncellemeVar = false;

  @override
  void initState() {
    super.initState();

    // 🔑 E2EE ANAHTAR GARANTİSİ — her açılışta.
    //
    // Anahtar paketi eskiden YALNIZCA kayıt sırasında yayınlanıyordu.
    // Kurtarma anahtarıyla giriş, hesap değiştirme veya yeniden kurulum
    // sonrası paket eksik/eski kalıyor ve karşı taraf mesajları
    // çözemiyordu ("🔒 çözülemedi"). Ana ekran tüm giriş yollarının
    // ortak noktası olduğu için kontrol buraya konuldu.
    // Arka planda çalışır — açılışı geciktirmez.
    unawaited(KeyManagementService.ensureKeysPublished());

    // 🔄 GÜNCELLEME KONTROLÜ (§4bl) — arka planda, açılışı geciktirmez.
    // Play dışı kurulumda sessizce false döner; bant hiç görünmez.
    unawaited(AppUpdateService.guncellemeVarMi().then((v) {
      if (mounted && v) setState(() => _guncellemeVar = true);
    }));
    getIt<CurrentUserProvider>().currentUsername.then((u) => _myUsername = u);
    _missedSub = CallLogService.watchMissedCount(widget.myUid).listen(
      (n) {
        if (mounted && n != _missedCount) setState(() => _missedCount = n);
      },
      onError: (e) => debugPrint('Cevapsız çağrı sayacı: $e'),
    );
    // #18 FIX: widget yalniz degisimde guncelleniyordu; acilista mevcut
    // toplami da IT (aksi halde widget 0'da kaliyordu).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final convs = ref.read(conversationsNotifierProvider).conversations;
      var t = 0;
      for (final c in convs) {
        t += c.unreadFor(widget.myUid);
      }
      HomeWidgetService.updateUnread(t);
    });
    // Connectivity provider'ini ISIT: ilk sohbet acilisinda soguk-baslatma
    // yayini (anlik 'yok' titremesi) yasanmasin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(connectivityProvider);
    });
    // 🤝 SESSİZ EL SIKIŞMA DİNLEYİCİSİ (§4cc) — uygulama genelinde.
    //
    // ⚠️ Sohbet ekranına bağlanamaz: onarımın bütün değeri, karşı tarafın
    // o sohbeti AÇMASINI beklememesinde. Tek koleksiyon-grubu akışı
    // bütün sohbetleri kapsar.
    _handshakeSub = RehandshakeService.dinle(widget.myUid);

    WidgetsBinding.instance.addObserver(this);
    PresenceService.setOnline(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama one gelince cevrimici, arkaya gidince cevrimdisi + son gorulme
    if (state == AppLifecycleState.resumed) {
      PresenceService.setOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      PresenceService.setOnline(false);
    }
  }

  // 🌐 baslıklar artık context.tr ile (dile gore)
  List<String> _titles(BuildContext context) => [
        context.tr('tab_chats'),
        context.tr('tab_stories'),
        context.tr('tab_channels'),
        context.tr('nav_calls'),
      ];

  @override
  void dispose() {
    _missedSub?.cancel();
    _handshakeSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PresenceService.setOnline(false);
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    // 📞 Aramalar sekmesi açıldı → cevapsız çağrı rozetini sıfırla
    if (i == 3) {
      CallLogService.markCallsSeen(widget.myUid).then((_) {
        if (mounted) setState(() => _missedCount = 0);
      });
    }
    setState(() => _index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// #15 Davet koduyla katıl: kod gir -> gruba katil -> ac.
  Future<void> _joinByCodeDialog(String myUid) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('join_by_code'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: context.tr('paste_invite'),
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(context.tr('join'),
                style: const TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;

    // Yukleme gostergesi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary)),
    );
    final result = await getIt<JoinByInviteCode>()(code);
    if (!mounted) return;
    Navigator.of(context).pop(); // yukleme kapat

    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(f.message))),
      ),
      (chatId) async {
        String title = 'Grup';
        try {
          final d = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get();
          title = (d.data()?['groupName'] ?? 'Grup').toString();
        } catch (_) {}
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MessagingScreen(
            chatId: chatId,
            chatTitle: title,
            myUid: myUid,
            isGroup: true,
          ),
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = widget.myUid;

    // Yeni mesaj bildirimi (uygulama ACIKKEN): bir sohbetin son mesaji
    // degistiyse, gonderen ben degilsem ve o sohbet su an acik degilse bildir.
    ref.listen<ConversationsState>(conversationsNotifierProvider, (prev, next) {
      // #18: ana ekran widget'ina toplam okunmamisi yaz (degisince).
      // Icerik degil, yalnizca SAYI gider (gizlilik).
      var totalUnread = 0;
      for (final c in next.conversations) {
        totalUnread += c.unreadFor(myUid);
      }
      HomeWidgetService.updateUnread(totalUnread);

      final prevList = prev?.conversations;
      if (prevList == null || prevList.isEmpty) return;
      final activeChat = ref.read(activeChatProvider);
      // O(n) arama icin id -> eski zaman haritasi (liste buyudukce onemli)
      final prevTimes = {
        for (final p in prevList) p.id: p.lastMessageTime,
      };
      for (final c in next.conversations) {
        if (!prevTimes.containsKey(c.id)) continue;
        final oldTime = prevTimes[c.id];
        final newTime = c.lastMessageTime;
        final changed =
            newTime != null && (oldTime == null || newTime.isAfter(oldTime));
        if (changed &&
            c.lastMessageSenderId != null &&
            c.lastMessageSenderId != myUid &&
            c.id != activeChat) {
          // 🔕 SESSIZE ALMA KAPISI (on-plan): susturulmussa bildirme;
          // etiket-istisnasi aciksa YALNIZ @bahsetme gecer.
          final prefsNow = ref.read(chatPrefsProvider(myUid));
          var body = context.tr('notif_new_msg');
          if (prefsNow.muted.contains(c.id)) {
            final u = _myUsername;
            final wantMention = prefsNow.muteMentionOk.contains(c.id) &&
                (c.isGroup || c.isChannel) &&
                u != null &&
                u.isNotEmpty;
            final mentioned = wantMention &&
                RegExp('@${RegExp.escape(u)}(?!\\w)', caseSensitive: false)
                    .hasMatch(c.lastMessage ?? '');
            if (!mentioned) continue;
            body = context.tr('notif_mentioned');
          }
          NotificationService.showLocal(
            c.displayTitle(myUid),
            body,
            chatId: c.id,
          );
        }
      }
    });

    // Gelen arama dinleyicisi — yeni çağrı gelince ekranı aç (tüm sekmelerde)
    ref.listen<AsyncValue<CallEntity?>>(incomingCallProvider, (prev, next) {
      final call = next.asData?.value;
      final prevCall = prev?.asData?.value;
      if (call != null &&
          call.id != prevCall?.id &&
          !_handledCallIds.contains(call.id)) {
        _handledCallIds.add(call.id);
        // 🛡️ ENGEL KAPISI: engellenen kisinin aramasi ekrana getirilmez;
        // sessizce reddedilir (arayan "mesgul/cevapsiz" gorur).
        final blocked =
            ref.read(blockedUsersProvider(widget.myUid)).asData?.value ??
                const <String>{};
        if (blocked.contains(call.callerId)) {
          debugPrint('Engellenen arayan reddedildi: ${call.callerId}');
          // ⚠️ GRUP ARAMASINI REDDETME — `rejectCall` çağrının durumunu
          // değiştirir; grupta bu, engellediğim kişi yüzünden KONUŞAN
          // HERKESİN aramasını kapatmak demekti. Engel burada yalnızca
          // "ekranım açılmasın" anlamına gelir.
          if (!call.isGroup) {
            CallService().rejectCall(call.id).catchError((_) {});
          }
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => IncomingCallScreen(call: call)),
        );
      }
    });

    // GERI TUSU: 1. sekmede degilsek once Sohbetler'e don; oradaysak
    // uygulamadan cik. (canPop=false -> sistem geri tusunu biz yakalariz)
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) _goTo(0);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          // 🎭 PANIK JESTI: basliga uzun bas -> (etkinse) sahte moda gec.
          // Gorunurde sadece bir baslik; bilen icin acil cikis.
          title: GestureDetector(
            onLongPress: () async {
              if (await PrivacyService.isPanicEnabled()) {
                triggerPanicDecoy();
              }
            },
            child: Text(_titles(context)[_index]),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_guncellemeVar) _guncellemeBandi(context),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _ConversationList(
                    myUid: myUid,
                    channelsOnly: false,
                    emptyText: context.tr('no_chats_yet'),
                  ),
                  _StoriesTab(myUid: myUid),
                  _ConversationList(
                    myUid: myUid,
                    channelsOnly: true,
                    emptyText: context.tr('no_channels_yet'),
                  ),
                  // 📞 4. sekme: çağrı geçmişi
                  CallLogScreen(myUid: myUid),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFab(context, myUid),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          backgroundColor: AppTheme.surface,
          // ── ANA EKRAN DA SOHBET RENGİNİ KULLANIR (§4bj) ──
          // Renk seçimi yalnızca sohbet balonlarını değiştiriyordu; ana
          // ekran her temada aynı camgöbeği kalıyor ve seçim yarım
          // görünüyordu. Artık vurgu renkleri (gezinme göstergesi, FAB)
          // GLOBAL sohbet renginden gelir — sohbete özel geçersiz
          // kılmalar ana ekranı etkilemez, orası tek bir sohbete ait
          // değildir.
          indicatorColor: _anaVurgu(ref).withValues(alpha: 0.25),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline),
              selectedIcon: const Icon(Icons.chat_bubble),
              label: context.tr('nav_chat'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_stories_outlined),
              selectedIcon: const Icon(Icons.auto_stories),
              label: context.tr('nav_story'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.campaign_outlined),
              selectedIcon: const Icon(Icons.campaign),
              label: context.tr('nav_channel'),
            ),
            NavigationDestination(
              icon: _missedCount > 0
                  ? Badge.count(
                      count: _missedCount,
                      backgroundColor: AppTheme.danger,
                      child: const Icon(Icons.call_outlined),
                    )
                  : const Icon(Icons.call_outlined),
              selectedIcon: const Icon(Icons.call),
              label: context.tr('nav_calls'),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔄 GÜNCELLEME BANDI (§4bl)
  ///
  /// Play yeni sürüm bildirince en üstte çıkar; dokununca mağaza
  /// sayfasına gider. Kapatılabilir — kullanıcı görmezden gelmeyi
  /// seçebilmeli, zorla gösterilen bir bant rahatsız edicidir.
  Widget _guncellemeBandi(BuildContext context) {
    final vurgu = _anaVurgu(ref);
    return Material(
      color: vurgu.withValues(alpha: 0.14),
      child: InkWell(
        onTap: AppUpdateService.magazayiAc,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.system_update_alt_rounded, color: vurgu, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('update_ready'),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: AppUpdateService.magazayiAc,
                child: Text(context.tr('update_action'),
                    style: TextStyle(color: vurgu)),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    size: 18, color: AppTheme.textSecondary),
                onPressed: () => setState(() => _guncellemeVar = false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ana ekranın vurgu rengi — GLOBAL sohbet renginden.
  static Color _anaVurgu(WidgetRef ref) =>
      bubbleThemeById(ref.watch(globalBubbleThemeProvider)).a;

  Widget? _buildFab(BuildContext context, String myUid) {
    // Hikaye sekmesinde FAB yok (oluşturma satırı listede)
    if (_index == 1 || _index == 3) return null; // hikaye + çağrılar
    return FloatingActionButton(
      backgroundColor: _anaVurgu(ref),
      foregroundColor: const Color(0xFF04141C),
      onPressed: () {
        if (_index == 2) {
          // Kanal sekmesi: yeni kanal / kanal ara
          showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline,
                        color: AppTheme.primary),
                    title: Text(context.tr('new_channel'),
                        style: const TextStyle(color: AppTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CreateChannelScreen(myUid: myUid)));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.travel_explore,
                        color: AppTheme.primary),
                    title: Text(context.tr('search_join_channel'),
                        style: const TextStyle(color: AppTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChannelSearchScreen(myUid: myUid)));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.link, color: AppTheme.primary),
                    title: Text(context.tr('join_by_code'),
                        style: const TextStyle(color: AppTheme.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      _joinByCodeDialog(myUid);
                    },
                  ),
                ],
              ),
            ),
          );
        } else {
          _showCreateMenu(context, myUid);
        }
      },
      child: Icon(_index == 2 ? Icons.add : Icons.edit_outlined),
    );
  }

  /// 🗒️ "Notlarım" sohbetini aç (yoksa oluştur).
  Future<void> _openSelfChat(String myUid) async {
    try {
      final chatId = await DirectChatService.getOrCreateSelfChat();
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MessagingScreen(
          chatId: chatId,
          chatTitle: context.tr('self_chat'),
          myUid: myUid,
        ),
      ));
    } catch (e) {
      reportHandled('Kendine sohbet açılamadı', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('err_chat_create'))),
      );
    }
  }

  void _showCreateMenu(BuildContext context, String myUid) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline,
                  color: AppTheme.primary),
              title: Text(context.tr('new_chat'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SearchUserScreen(myUid: myUid)));
              },
            ),
            // 🗒️ Kendine mesaj — ikinci hesap açmadan not tutma
            ListTile(
              leading:
                  const Icon(Icons.bookmark_border, color: AppTheme.primary),
              title: Text(context.tr('self_chat'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(context.tr('self_chat_hint'),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _openSelfChat(myUid);
              },
            ),
            // 🤝 Buluşma kodu — kullanıcı adı paylaşmadan tanışma
            ListTile(
              leading:
                  const Icon(Icons.handshake_outlined, color: AppTheme.primary),
              title: Text(context.tr('meet_code'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MeetCodeScreen(
                    myUid: myUid,
                    myUsername: _myUsername ?? '',
                  ),
                ));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.group_outlined, color: AppTheme.primary),
              title: Text(context.tr('new_group'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CreateGroupScreen(myUid: myUid)));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.campaign_outlined, color: AppTheme.primary),
              title: Text(context.tr('new_channel_short'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CreateChannelScreen(myUid: myUid)));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Konuşma listesi — kanal filtreli (Sohbet sekmesi: kanal-dışı, Kanal sekmesi: kanal).
class _ConversationList extends ConsumerStatefulWidget {
  final String myUid;
  final bool channelsOnly;
  final String emptyText;
  const _ConversationList({
    required this.myUid,
    required this.channelsOnly,
    required this.emptyText,
  });

  @override
  ConsumerState<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends ConsumerState<_ConversationList> {
  // #17 secili klasor (null = Tumu)
  String? _folder;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsNotifierProvider);

    if (state.isLoading) {
      // Iskelet yukleme: bos donen cark yerine icerik taslagi (modern UX)
      return const ChatListSkeleton();
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.tr(state.error!),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final prefs = ref.watch(chatPrefsProvider(widget.myUid));
    final q = _query.trim().toLowerCase();
    final all = state.conversations
        .where((c) => widget.channelsOnly ? c.isChannel : !c.isChannel)
        .where((c) =>
            q.isEmpty || c.displayTitle(widget.myUid).toLowerCase().contains(q))
        .toList();
    // Arşivlenenleri ana listeden çıkar; sabitlenmişleri üste al
    final items = all
        .where((c) =>
            !prefs.archived.contains(c.id) &&
            !prefs.isHidden(c.id, c.lastMessageTime) &&
            // #17 klasor filtresi
            (_folder == null || prefs.folders[c.id] == _folder))
        .toList()
      ..sort((a, b) {
        final ap = prefs.pinned.contains(a.id) ? 0 : 1;
        final bp = prefs.pinned.contains(b.id) ? 0 : 1;
        return ap
            .compareTo(bp); // stabil: pin grubu içinde sunucu sırası korunur
      });
    final archivedCount = all
        .where((c) =>
            prefs.archived.contains(c.id) &&
            !prefs.isHidden(c.id, c.lastMessageTime))
        .length;
    final locked = ref.watch(lockedChatsProvider);

    return Column(
      children: [
        // Üstte arama kutusu (kullanıcı adı / kanal filtrele)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.channelsOnly
                  ? context.tr('search_channel_hint')
                  : context.tr('search_user_hint'),
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // #17 Klasor sekmeleri (yalnizca sohbetlerde ve klasor varsa)
        if (!widget.channelsOnly && prefs.folderNames.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _folderChip(context.tr('all_word'), null),
                ...prefs.folderNames.map((f) => _folderChip(f, f)),
              ],
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    q.isEmpty ? widget.emptyText : context.tr('no_results'),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
                  onRefresh: () => ref
                      .read(conversationsNotifierProvider.notifier)
                      .refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length + (archivedCount > 0 ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      // İlk satır: arşivlenmişler girişi (varsa)
                      if (archivedCount > 0 && i == 0) {
                        return ListTile(
                          leading: const Icon(Icons.archive_outlined,
                              color: AppTheme.textSecondary),
                          title: Text(
                              '${context.tr('archived')} ($archivedCount)',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary)),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _ArchivedScreen(
                                myUid: widget.myUid,
                                channelsOnly: widget.channelsOnly,
                              ),
                            ),
                          ),
                        );
                      }
                      final c = items[archivedCount > 0 ? i - 1 : i];
                      return _conversationTile(
                        context,
                        c,
                        widget.myUid,
                        isPinned: prefs.pinned.contains(c.id),
                        isLocked: locked.contains(c.id),
                        isMuted: prefs.muted.contains(c.id),
                        // 🗒️ Kendine sohbette "karşı taraf" yok: takma
                        // ad araması boş uid'e düşer ve başlık kendi
                        // kullanıcı adın olurdu. Adı açıkça veriyoruz.
                        aliasTitle: SelfNoteService.isSelfChat(
                                c.id, widget.myUid)
                            ? context.tr('self_chat')
                            : (!c.isGroup && !c.isChannel)
                                ? ref.watch(userAliasesProvider(widget.myUid))[c
                                    .memberIds
                                    .firstWhere((u) => u != widget.myUid,
                                        orElse: () => '')]
                                : null,
                        onOpen: () => _openChat(c),
                        onLongPress: () =>
                            _showChatMenu(context, ref, c, prefs, locked),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// #17 Klasor sekmesi cipi.
  Widget _folderChip(String label, String? value) {
    final selected = _folder == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppTheme.primary.withValues(alpha: 0.25),
        backgroundColor: AppTheme.surface,
        labelStyle: TextStyle(
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 13),
        side: BorderSide.none,
        onSelected: (_) => setState(() => _folder = value),
      ),
    );
  }

  /// 🏷️ Etiket duzenleme diyalogu.
  Future<void> _editAliasDialog(ConversationEntity c) async {
    final other =
        c.memberIds.firstWhere((u) => u != widget.myUid, orElse: () => '');
    if (other.isEmpty) return;
    final current = ref.read(userAliasesProvider(widget.myUid))[other] ?? '';
    final ctrl = TextEditingController(text: current);
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('label_alias'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 24,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: context.tr('label_alias'),
            counterText: '',
            helperText: context.tr('alias_helper'),
            helperStyle:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ),
        actions: [
          if (current.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text(context.tr('remove'),
                  style: const TextStyle(color: AppTheme.danger)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(context.tr('save'),
                  style: const TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
    if (res == null) return;
    await ref
        .read(userAliasesProvider(widget.myUid).notifier)
        .setAlias(other, res.isEmpty ? null : res);
  }

  /// #17 Sohbeti klasore ata / klasorden cikar.
  Future<void> _showFolderPicker(ConversationEntity c, ChatPrefs prefs) async {
    final current = prefs.folders[c.id];
    final names = prefs.folderNames;
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Text(context.tr('move_to_folder'),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            ...names.map((n) => ListTile(
                  leading: Icon(Icons.folder,
                      color: current == n
                          ? AppTheme.primary
                          : AppTheme.textSecondary),
                  title: Text(n,
                      style: const TextStyle(color: AppTheme.textPrimary)),
                  trailing: current == n
                      ? const Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, n),
                )),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined,
                  color: AppTheme.primary),
              title: Text('${context.tr('new_folder')}...',
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, '__new__'),
            ),
            if (current != null)
              ListTile(
                leading: const Icon(Icons.folder_off_outlined,
                    color: AppTheme.danger),
                title: Text(context.tr('remove_from_folder'),
                    style: const TextStyle(color: AppTheme.danger)),
                onTap: () => Navigator.pop(ctx, '__none__'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    String? target;
    if (picked == '__none__') {
      target = null;
    } else if (picked == '__new__') {
      final ctrl = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(context.tr('new_folder'),
              style: const TextStyle(color: AppTheme.textPrimary)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 18,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: context.tr('new_folder'),
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('cancel'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: Text(context.tr('create'),
                    style: const TextStyle(color: AppTheme.primary))),
          ],
        ),
      );
      if (name == null || name.isEmpty || !mounted) return;
      target = name;
    } else {
      target = picked;
    }
    await ref
        .read(chatPrefsProvider(widget.myUid).notifier)
        .setFolder(c.id, target);
  }

  /// Sohbeti aç — kilitliyse önce PIN doğrula.
  Future<void> _openChat(ConversationEntity c) async {
    var title = c.displayTitle(widget.myUid);
    if (SelfNoteService.isSelfChat(c.id, widget.myUid)) {
      title = context.tr('self_chat');
    } else if (!c.isGroup && !c.isChannel) {
      final other =
          c.memberIds.firstWhere((u) => u != widget.myUid, orElse: () => '');
      title = ref.read(userAliasesProvider(widget.myUid))[other] ?? title;
    }
    if (ref.read(lockedChatsProvider).contains(c.id)) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) =>
            ChatPinScreen(chatId: c.id, chatTitle: title, setup: false),
      ));
      if (ok != true || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MessagingScreen(
        chatId: c.id,
        chatTitle: title,
        myUid: widget.myUid,
        isGroup: c.isGroup || c.isChannel,
      ),
    ));
  }

  void _showChatMenu(BuildContext context, WidgetRef ref, ConversationEntity c,
      ChatPrefs prefs, Set<String> locked) {
    final pinned = prefs.pinned.contains(c.id);
    final archived = prefs.archived.contains(c.id);
    final notifier = ref.read(chatPrefsProvider(widget.myUid).notifier);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        // TASMA KORUMASI: kucuk ekranlarda menu artik kaydirilabilir
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: AppTheme.primary),
                title: Text(pinned ? context.tr('unpin') : context.tr('pin'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  notifier.togglePin(c.id);
                },
              ),
              ListTile(
                leading: Icon(
                    archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    color: AppTheme.primary),
                title: Text(
                    archived ? context.tr('unarchive') : context.tr('archive'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  notifier.toggleArchive(c.id);
                },
              ),
              // #17 Klasore tasi
              ListTile(
                leading:
                    const Icon(Icons.folder_outlined, color: AppTheme.primary),
                title: Text(
                    prefs.folders[c.id] == null
                        ? context.tr('move_to_folder')
                        : '${context.tr('folder_word')}: ${prefs.folders[c.id]}',
                    style: const TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showFolderPicker(c, prefs);
                },
              ),
              // 🏷️ Etiket (takma ad) — yalniz birebir sohbetlerde
              if (!c.isGroup && !c.isChannel)
                ListTile(
                  leading:
                      const Icon(Icons.label_outline, color: AppTheme.primary),
                  title: Text(() {
                    final other = c.memberIds
                        .firstWhere((u) => u != widget.myUid, orElse: () => '');
                    final a = prefsAlias(ref, widget.myUid)[other];
                    return a == null
                        ? context.tr('add_label')
                        : '${context.tr('label_word')}: $a';
                  }(), style: const TextStyle(color: AppTheme.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    _editAliasDialog(c);
                  },
                ),
              // 🔕 Sessize al / sesi ac
              ListTile(
                leading: Icon(
                    prefs.muted.contains(c.id)
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                    color: AppTheme.primary),
                title: Text(
                    prefs.muted.contains(c.id)
                        ? context.tr('unmute')
                        : context.tr('mute'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  final nowMuted = !prefs.muted.contains(c.id);
                  notifier.toggleMute(c.id);
                  MuteService.setMuted(c.id, widget.myUid, nowMuted)
                      .catchError((_) {});
                  if (nowMuted && (c.isGroup || c.isChannel)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('muted_note'))));
                  }
                },
              ),
              // 🔕 Etiket istisnasi (yalniz susturulmus grup/kanal)
              if (prefs.muted.contains(c.id) && (c.isGroup || c.isChannel))
                ListTile(
                  leading: const Icon(Icons.alternate_email,
                      color: AppTheme.primary),
                  title: Text(
                      prefs.muteMentionOk.contains(c.id)
                          ? context.tr('mention_on')
                          : context.tr('mention_off'),
                      style: const TextStyle(color: AppTheme.textPrimary)),
                  subtitle: Text(context.tr('mention_note'),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    final allow = !prefs.muteMentionOk.contains(c.id);
                    notifier.setMuteMentionOk(c.id, allow);
                    MuteService.setMentionOk(c.id, widget.myUid, allow)
                        .catchError((_) {});
                  },
                ),
              // Sohbet kilidi (PIN)
              ListTile(
                leading: Icon(
                    locked.contains(c.id)
                        ? Icons.lock_open_outlined
                        : Icons.lock_outline,
                    color: AppTheme.primary),
                title: Text(
                    locked.contains(c.id)
                        ? context.tr('unlock')
                        : context.tr('lock'),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  final title = c.displayTitle(widget.myUid);
                  if (locked.contains(c.id)) {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => ChatPinScreen(
                            chatId: c.id, chatTitle: title, setup: false),
                      ),
                    );
                    if (ok == true) {
                      ref.read(lockedChatsProvider.notifier).unlock(c.id);
                    }
                  } else {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => ChatPinScreen(
                            chatId: c.id, chatTitle: title, setup: true),
                      ),
                    );
                    if (ok == true) {
                      ref.read(lockedChatsProvider.notifier).refresh();
                    }
                  }
                },
              ),
              // Bireysel sohbeti sil (tek-tarafli — grup/kanalda Sil/Ayril var)
              if (!c.isChannel && !c.isGroup)
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: AppTheme.danger),
                  title: Text(context.tr('delete_chat'),
                      style: const TextStyle(color: AppTheme.danger)),
                  onTap: () async {
                    Navigator.pop(context);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        title: const Text(
                          'Bu sohbeti cihazınızdan silmek istediğinize emin misiniz?',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 17),
                        ),
                        content: const Text(
                          'Yalnızca sizden gizlenir; karşı taraf etkilenmez. '
                          'Yeni mesaj gelirse sohbet tekrar görünür.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(context.tr('cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(context.tr('delete'),
                                style: const TextStyle(color: AppTheme.danger)),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      ref
                          .read(chatPrefsProvider(widget.myUid).notifier)
                          .markDeleted(c.id);
                    }
                  },
                ),
              // Kanal/grup: yonetici -> Sil, uye -> Ayril (onayli)
              if (c.isChannel || c.isGroup)
                ListTile(
                  leading: Icon(
                      c.isAdmin(widget.myUid)
                          ? Icons.delete_forever
                          : Icons.exit_to_app,
                      color: AppTheme.danger),
                  title: Text(
                    c.isAdmin(widget.myUid)
                        ? (c.isChannel ? 'Kanalı sil' : 'Grubu sil')
                        : (c.isChannel ? 'Kanaldan ayrıl' : 'Gruptan ayrıl'),
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteChat(c);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteChat(ConversationEntity c) async {
    final isAdmin = c.isAdmin(widget.myUid);
    final isChannel = c.isChannel;
    final noun = isChannel ? 'kanalı' : 'grubu';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          isAdmin
              ? 'Bu $noun silmek istediğinize emin misiniz?'
              : 'Bu ${isChannel ? "kanaldan" : "gruptan"} ayrılmak istiyor musunuz?',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17),
        ),
        content: Text(
          isAdmin
              ? 'Bu işlem geri alınamaz. Tüm mesajlar kalıcı olarak silinir.'
              : 'Tekrar katılmak için davet ya da arama gerekebilir.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAdmin ? 'Evet, sil' : 'Ayrıl',
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repo = getIt<GroupRepository>();
    final result =
        isAdmin ? await repo.deleteGroup(c.id) : await repo.leaveGroup(c.id);
    if (!mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr(f.message)))),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAdmin ? 'Silindi' : 'Ayrıldınız'))),
    );
  }
}

Map<String, String> prefsAlias(WidgetRef ref, String uid) =>
    ref.read(userAliasesProvider(uid));

Widget _conversationTile(
    BuildContext context, ConversationEntity c, String myUid,
    {bool isPinned = false,
    bool isLocked = false,
    bool isMuted = false,
    String? aliasTitle,
    VoidCallback? onOpen,
    VoidCallback? onLongPress}) {
  final title = aliasTitle ?? c.displayTitle(myUid);
  return ListTile(
    onLongPress: onLongPress,
    leading: Hero(
      tag: 'avatar_${c.id}',
      child: c.otherUserId(myUid) != null
          ? UserAvatar(
              uid: c.otherUserId(myUid)!,
              fallbackLetter: c.avatarLetter(myUid),
              radius: 24,
            )
          : CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primary,
              backgroundImage: (c.avatarUrl != null && c.avatarUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(c.avatarUrl!)
                  : null,
              child: (c.avatarUrl != null && c.avatarUrl!.isNotEmpty)
                  ? null
                  : Text(
                      c.avatarLetter(myUid),
                      style: const TextStyle(
                          color: Color(0xFF04141C),
                          fontWeight: FontWeight.w700),
                    ),
            ),
    ),
    title: Row(
      children: [
        Flexible(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        ),
        if (isPinned) ...[
          const SizedBox(width: 5),
          const Icon(Icons.push_pin, size: 13, color: AppTheme.textSecondary),
        ],
        if (isLocked) ...[
          const SizedBox(width: 5),
          const Icon(Icons.lock, size: 13, color: AppTheme.textSecondary),
        ],
      ],
    ),
    subtitle: c.incognito
        // GIZLI SOHBET: onizleme MASKELENIR (icerik listede gorunmez)
        ? Text(context.tr('secret_chat'),
            maxLines: 1,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontStyle: FontStyle.italic))
        : (c.lastMessage != null
            ? Text(context.trPreview(c.lastMessage!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary))
            : null),
    // NOT: Ozel Container(alignment:) burada Flutter'in bilinen bir semantics
    // hatasini tetikliyordu (ListTile.trailing baseline + RenderPositionedBox
    // -> '!semantics.parentDataDirty' cokmesi). Framework'un hazir Badge
    // widget'i ayni gorunumu guvenle verir.
    trailing: c.unreadFor(myUid) > 0
        ? Badge.count(
            count: c.unreadFor(myUid),
            backgroundColor: AppTheme.primary,
            textColor: const Color(0xFF04141C),
          )
        : (isMuted
            ? const Icon(Icons.volume_off,
                size: 16, color: AppTheme.textSecondary)
            : null),
    onTap: onOpen ??
        () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MessagingScreen(
                chatId: c.id,
                chatTitle: title,
                myUid: myUid,
                isGroup: c.isGroup || c.isChannel,
              ),
            ),
          );
        },
  );
}

/// Hikaye sekmesi — üstte \"Durumunu paylaş\", altında kişilerin hikayeleri (dikey).
class _StoriesTab extends ConsumerWidget {
  final String myUid;
  const _StoriesTab({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storyNotifierProvider);
    final userStories = state.userStories;

    return ListView(
      children: [
        ListTile(
          leading: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              children: [
                UserAvatar(uid: myUid, fallbackLetter: '', radius: 24),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                        color: AppTheme.background, shape: BoxShape.circle),
                    child: const Icon(Icons.add_circle,
                        color: AppTheme.primary, size: 18),
                  ),
                ),
              ],
            ),
          ),
          title: Text(context.tr('share_status'),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Text(context.tr('photo_or_text'),
              style: const TextStyle(color: AppTheme.textSecondary)),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StoryCreatorScreen()),
          ),
        ),
        const Divider(height: 1),
        if (userStories.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(context.tr('no_stories_yet'),
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ),
          )
        else
          ...userStories.map((us) => _storyTile(context, us, myUid)),
      ],
    );
  }
}

Widget _storyTile(BuildContext context, UserStoriesEntity us, String myUid) {
  final allViewed = us.allViewedBy(myUid);
  return ListTile(
    leading: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: allViewed ? AppTheme.surfaceLight : AppTheme.primary,
          width: 2,
        ),
      ),
      child: UserAvatar(
        uid: us.userId,
        fallbackLetter:
            us.username.isNotEmpty ? us.username[0].toUpperCase() : '?',
        radius: 22,
      ),
    ),
    title: Text('@${us.username}',
        style: const TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
    subtitle: Text(
        allViewed ? context.tr('story_seen') : context.tr('story_new'),
        style: const TextStyle(color: AppTheme.textSecondary)),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(userStories: us, myUid: myUid),
      ),
    ),
  );
}

/// Arşivlenmiş sohbetler ekranı (uzun-bas: arşivden çıkar).
class _ArchivedScreen extends ConsumerWidget {
  final String myUid;
  final bool channelsOnly;
  const _ArchivedScreen({required this.myUid, required this.channelsOnly});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationsNotifierProvider);
    final prefs = ref.watch(chatPrefsProvider(myUid));
    final items = state.conversations
        .where((c) => channelsOnly ? c.isChannel : !c.isChannel)
        .where((c) => prefs.archived.contains(c.id))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('archived'))),
      body: items.isEmpty
          ? Center(
              child: Text(context.tr('archive_empty'),
                  style: const TextStyle(color: AppTheme.textSecondary)),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _conversationTile(
                context,
                items[i],
                myUid,
                onLongPress: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => SafeArea(
                      child: ListTile(
                        leading: const Icon(Icons.unarchive_outlined,
                            color: AppTheme.primary),
                        title: Text(context.tr('unarchive'),
                            style:
                                const TextStyle(color: AppTheme.textPrimary)),
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(chatPrefsProvider(myUid).notifier)
                              .toggleArchive(items[i].id);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
