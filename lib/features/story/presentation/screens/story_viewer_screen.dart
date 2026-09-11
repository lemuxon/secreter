import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/story_notifier.dart';
import '../../domain/entities/story_entity.dart';
import '../../../../utils/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../messaging/presentation/screens/messaging_screen.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/observability/handled_error.dart';
import '../../../../services/story_reaction_service.dart';
import '../../../../core/widgets/user_avatar.dart';

/// Tam ekran hikaye görüntüleyici (yeni mimari).
/// Üstte ilerleme çubukları, dokununca sonraki, kenarda önceki.
class StoryViewerScreen extends ConsumerStatefulWidget {
  final UserStoriesEntity userStories;
  final String myUid;
  const StoryViewerScreen(
      {super.key, required this.userStories, required this.myUid});

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

/// Görüntüleyen kaydı — tepki verenleri ayırt etmek için.
class _ViewerEntry {
  final String uid;
  final String name;
  final String? reaction;
  const _ViewerEntry(this.uid, this.name, this.reaction);
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  int _currentIndex = 0;

  /// Bu kullanıcının AÇIK hikâyeye verdiği tepki (yoksa null).
  /// Hikâye değiştiğinde sıfırlanır — her hikâyenin kendi tepkisi var.
  String? _myReaction;

  static const _storyDuration = Duration(seconds: 5);

  List<StoryEntity> get _stories => widget.userStories.stories;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    _startStory();
  }

  void _startStory() {
    _progressController.reset();
    _progressController.forward();
    // Görüntülendi işaretle
    ref
        .read(storyNotifierProvider.notifier)
        .markViewed(_stories[_currentIndex].id);
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
      setState(() {
        _currentIndex++;
        _myReaction = null; // yeni hikâye = yeni tepki durumu
      });
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _myReaction = null; // önceki hikâye = kendi tepki durumu
      });
      _startStory();
    }
  }

  /// 👀 Hikayeyi gorenler (yalniz sahibe) — isim listesi.
  /// ❤️ Tepki şeridi + yanıt alanı (yalnızca başkasının hikâyesinde).
  Widget _reactionBar(StoryEntity story) {
    // ── 🐞 ŞERİTTEKİ BOŞLUKLAR HİKAYEYİ İLERLETİYORDU ──
    //
    // GERÇEK ŞİKÂYET: *"tek tıklama yerine çift tıklamak gerekiyor."*
    //
    // Ekranın tamamında "sağa dokun → sonraki hikaye" jesti var. Tepki
    // şeridinde yalnızca EMOJİLERİN ve yanıt kutusunun kendi
    // `GestureDetector`ı vardı; aralarındaki BOŞLUKLAR (Row
    // `spaceEvenly` ile dağıtılıyor, yani boşluk emojiden geniş) alttaki
    // jeste düşüyordu. Emojiye biraz ıskalayan dokunuş hikayeyi
    // atlatıyor, kullanıcı ikinci kez dokunmak zorunda kalıyordu — ve
    // bunu "çift tıklama gerekiyor" diye yaşıyordu.
    //
    // ⚠️ `HitTestBehavior.opaque` + boş `onTap`: şerit, kendisine gelen
    // dokunuşları YUTAR. Kontrol çubuğuna dokunmak hiçbir zaman
    // "sonraki hikaye" anlamına gelmemeli.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hızlı tepkiler
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in StoryReactionService.quickReactions)
                    GestureDetector(
                      onTap: () => _sendReaction(story, e),
                      child: AnimatedScale(
                        scale: _myReaction == e ? 1.35 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: Text(e, style: const TextStyle(fontSize: 30)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Yanıt alanı
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _replyToStory(story),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white38, width: 1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          context.tr('reply_to_story'),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tepki gönder — aynı emojiye tekrar basmak KALDIRIR.
  Future<void> _sendReaction(StoryEntity story, String emoji) async {
    // Hikâye zamanlayıcısını durdur: kullanıcı etkileşimdeyken
    // hikâye kaymasın.
    _progressController.stop();

    // Aynı emojiye tekrar basmak KALDIRIR; kaldırma mesaj göndermez.
    final kaldiriliyor = _myReaction == emoji;
    setState(() => _myReaction = kaldiriliyor ? null : emoji);

    // ⚠️ `context` await'ten SONRA kullanılamaz; önizleme şimdi hesaplanır.
    final onizleme =
        (story.text?.isNotEmpty ?? false) ? story.text! : context.tr('a_story');

    try {
      await StoryReactionService.react(storyId: story.id, emoji: emoji);

      // ── TEPKİ KARŞI TARAFA MESAJ OLARAK DA GİDER ──
      //
      // 🐞 GERÇEK KULLANICIDA GÖRÜLDÜ: *"tepkin gönderildi diyor ama
      // tepki gitmemiş."* Haklıydı. Tepki yalnızca
      // `stories/{id}.reactions` haritasına yazılıyordu: bildirim YOK,
      // mesaj YOK. Hikâye sahibi ancak KENDİ izleyici listesini açarsa
      // görebiliyordu. Gönderene "gönderildi" demek bu yüzden
      // yanıltıcıydı.
      //
      // Artık yazılı yanıtla AYNI yoldan geçer: sohbete hikâye alıntılı
      // bir mesaj olarak düşer, böylece karşı taraf gerçekten haberdar
      // olur. Harita kaydı da durur — izleyici listesindeki küçük emoji
      // göstergesi ondan besleniyor.
      if (!kaldiriliyor) {
        await StoryReactionService.reply(
          ownerUid: story.userId,
          ownerUsername: story.username,
          text: emoji,
          storyPreview: onizleme,
          storyId: story.id,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$emoji ${context.tr('reaction_sent')}'),
        duration: const Duration(seconds: 1),
      ));
    } catch (e, st) {
      // ⚠️ SESSİZ YUTMA DEĞİL. Eskiden hata yalnızca emojiyi söndürüyordu;
      // kullanıcı ya fark etmiyor ya da neden olduğunu bilmiyordu.
      reportHandled('Hikâye tepkisi gönderilemedi', e, stack: st);
      if (!mounted) return;
      setState(() => _myReaction = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('reaction_failed')),
        duration: const Duration(seconds: 2),
      ));
    }
    _progressController.forward();
  }

  /// Hikâyeye yazılı yanıt — sahibiyle olan sohbete mesaj olarak gider.
  Future<void> _replyToStory(StoryEntity story) async {
    _progressController.stop();
    final ctrl = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ctx.tr('reply_to')} @${story.username}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 1,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration:
                      InputDecoration(hintText: ctx.tr('type_a_message')),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(ctx.tr('send')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (text != null && text.isNotEmpty) {
      // Yanıt kutusu açıkken hikâye kapanmış olabilir; context'i
      // kullanmadan önce ekranın hâlâ ayakta olduğunu doğrula.
      if (!mounted) return;
      try {
        // Hikâye 24 saatte silinse bile yanıtın neye ait olduğu
        // anlaşılsın diye kısa bir önizleme taşınır.
        final preview = (story.text?.isNotEmpty ?? false)
            ? story.text!
            : context.tr('a_story');
        await StoryReactionService.reply(
          ownerUid: story.userId,
          ownerUsername: story.username,
          text: text,
          storyPreview: preview,
          storyId: story.id,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('reply_sent')),
            duration: const Duration(seconds: 1)));
      } catch (e) {
        if (!mounted) return;
        // TEŞHİS geliştiriciye, METİN kullanıcıya.
        //
        // ⚠️ Buradaki `$e` EKRANA basılıyordu (§4ao). Firestore hatası
        // `[cloud_firestore/permission-denied] ... /chats/uidA_uidB/...`
        // biçiminde gelir; yani sohbet kimliği — iki tarafın uid'i —
        // kullanıcının ekranına düşer. Hata ekranları paylaşılır ve
        // ekran görüntüsü alınır. §4q'nun ham istisna sızıntısını
        // kapatma gerekçesinin aynısı.
        reportHandled('Hikâye yanıtı gönderilemedi', e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('reply_failed')),
          duration: const Duration(seconds: 4),
        ));
      }
    }
    _progressController.forward();
  }

  Future<void> _showViewersSheet(StoryEntity story) async {
    _progressController.stop();
    final uids = story.viewedBy.where((u) => u != widget.myUid).toList();

    // ❤️ TEPKİLER: hikâye dokümanından okunur ({uid: emoji})
    Map<String, String> reactions = {};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('stories')
          .doc(story.id)
          .get();
      final raw = (doc.data()?['reactions'] as Map?) ?? const {};
      reactions = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (e) {
      debugPrint('Tepkiler okunamadı: $e');
    }

    // Tepki verenler görüntüleyenler listesinde olmayabilir
    // (tepki verdi ama "görüldü" yazılmadıysa) — birleştir.
    final allUids = <String>{...uids, ...reactions.keys}
        .where((u) => u != widget.myUid)
        .toList();

    final entries = <_ViewerEntry>[];
    for (final uid in allUids) {
      String name = 'Bilinmeyen';
      try {
        final d =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        name = (d.data()?['username'] ?? 'Bilinmeyen').toString();
      } catch (_) {}
      entries.add(_ViewerEntry(uid, name, reactions[uid]));
    }

    // SIRALAMA: tepki verenler ÜSTTE, sonra alfabetik.
    entries.sort((a, b) {
      if ((a.reaction != null) != (b.reaction != null)) {
        return a.reaction != null ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    final names = entries.map((e) => e.name).toList();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                      '${context.tr('viewers')} (${names.length})'
                      '${reactions.isEmpty ? '' : '  ·  ❤️ ${reactions.length}'}',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              if (names.isEmpty)
                Text(context.tr('nobody_viewed'),
                    style: const TextStyle(color: AppTheme.textSecondary)),
              // Tepki verenler üstte; tepkisi emoji olarak sağda görünür
              ...entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        UserAvatar(
                          uid: e.uid,
                          fallbackLetter:
                              e.name.isEmpty ? '?' : e.name[0].toUpperCase(),
                          radius: 15,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('@${e.name}',
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(color: AppTheme.textPrimary)),
                        ),
                        if (e.reaction != null)
                          Text(e.reaction!,
                              style: const TextStyle(fontSize: 20)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
    if (mounted) _progressController.forward();
  }

  /// 👤 Hikaye sahibinin profil karti + Mesaj gonder.
  Future<void> _showOwnerProfile(StoryEntity story) async {
    _progressController.stop();
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppTheme.primary,
                child: Text(
                    story.username.isNotEmpty
                        ? story.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFF04141C), fontSize: 26)),
              ),
              const SizedBox(height: 10),
              Text('@${story.username}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(context.tr('send_message')),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final ids = [widget.myUid, story.userId]..sort();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MessagingScreen(
                        chatId: ids.join('_'),
                        chatTitle: '@${story.username}',
                        myUid: widget.myUid,
                        isGroup: false,
                      ),
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppTheme.primary;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_currentIndex];
    final isMe = story.userId == widget.myUid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onLongPress: () => _progressController.stop(),
        onLongPressUp: () => _progressController.forward(),
        child: Stack(
          children: [
            Positioned.fill(child: _buildStoryContent(story)),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  Row(
                    children: List.generate(_stories.length, (i) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: _buildProgressBar(i),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: isMe ? null : () => _showOwnerProfile(story),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.primary,
                              child: Text(
                                story.username.isNotEmpty
                                    ? story.username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '@${story.username}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(context, story.createdAt),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12),
                      ),
                      const Spacer(),
                      if (isMe)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () async {
                            await ref
                                .read(storyNotifierProvider.notifier)
                                .deleteStory(story.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ❤️ BAŞKASININ hikâyesinde: tepki şeridi + yanıt alanı
            if (!isMe)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _reactionBar(story),
              ),

            if (isMe)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 16,
                child: GestureDetector(
                  onTap: () => _showViewersSheet(story),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${story.viewedBy.length} ${context.tr('views')}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      const Icon(Icons.keyboard_arrow_up,
                          color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int index) {
    if (index < _currentIndex) {
      return Container(color: Colors.white);
    } else if (index == _currentIndex) {
      return AnimatedBuilder(
        animation: _progressController,
        builder: (context, _) {
          return LinearProgressIndicator(
            value: _progressController.value,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          );
        },
      );
    } else {
      return Container(color: Colors.white.withValues(alpha: 0.3));
    }
  }

  Widget _buildStoryContent(StoryEntity story) {
    switch (story.type) {
      case StoryMediaType.text:
        return Container(
          color: _parseColor(story.backgroundColor),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                story.text ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      case StoryMediaType.image:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: story.mediaUrl ?? '',
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            ),
            if (story.text != null && story.text!.isNotEmpty)
              Padding(
                // ⬆️ ALT BOŞLUK: tepki şeridi + yanıt alanı ekranın
                // altını kaplıyor. Açıklama eskiden onun ALTINDA kalıp
                // görünmüyordu. Yaklaşık şerit yüksekliği kadar boşluk
                // bırakılır (tepki satırı ~56 + yanıt kutusu ~52 + iç
                // boşluklar).
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
                child: Text(
                  story.text!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
          ],
        );
      default:
        return const Center(child: Icon(Icons.error, color: Colors.white));
    }
  }

  /// Göreli zaman — kısaltmalar da çevrilir ('dk' / 'sa' Türkçeydi).
  String _timeAgo(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return context.tr('just_now');
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${context.tr('min_short')}';
    }
    return '${diff.inHours}${context.tr('hour_short')}';
  }
}
