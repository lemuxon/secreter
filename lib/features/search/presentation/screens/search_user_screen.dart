import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/search_controller.dart';
import '../../domain/entities/found_user.dart';
import '../../../messaging/presentation/screens/messaging_screen.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/widgets/user_avatar.dart';

/// Kullanıcı arama ekranı (yeni mimari).
/// Bulunan kullanıcıyla sohbet açıp yeni MessagingScreen'e geçer.
class SearchUserScreen extends ConsumerStatefulWidget {
  final String myUid;
  const SearchUserScreen({super.key, required this.myUid});

  @override
  ConsumerState<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends ConsumerState<SearchUserScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    ref.read(searchControllerProvider.notifier).search(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);

    // Sohbet açıldıysa MessagingScreen'e geç (bu ekranı kapatarak)
    ref.listen<SearchState>(searchControllerProvider, (prev, next) {
      if (next.openedChatId != null &&
          next.openedChatId != prev?.openedChatId) {
        final chatId = next.openedChatId!;
        final title = next.openedUsername ?? 'Sohbet';
        ref.read(searchControllerProvider.notifier).consumeOpened();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MessagingScreen(
              chatId: chatId,
              chatTitle: title,
              myUid: widget.myUid,
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('find_user'))),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: '@kullanici_adi',
                      prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                FilledButton(
                  onPressed: state.searching ? null : _search,
                  child: state.searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Color(0xFF04141C), strokeWidth: 2),
                        )
                      : Text(context.tr('search')),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            if (state.error != null)
              Text(context.tr(state.error!),
                  style: const TextStyle(color: AppTheme.textSecondary)),
            if (state.result != null) _resultCard(state, state.result!),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(SearchState state, FoundUser user) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(Spacing.lg),
        // PROFİL FOTOĞRAFI: arama sonucunda yalnızca baş harf
        // gösteriliyordu. UserAvatar, uid'den profili çekip fotoğraf
        // varsa onu gösterir (fotoğraf yoksa harfe düşer) ve sonucu
        // önbelleğe alır — her arama için yeniden istek atılmaz.
        leading: UserAvatar(
          uid: user.uid,
          fallbackLetter: user.avatarLetter,
          radius: 24,
        ),
        title: Text('@${user.username}',
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: user.isOnline ? AppTheme.online : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
                user.isOnline
                    ? context.tr('online_now')
                    : context.tr('offline_now'),
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
        trailing: FilledButton(
          onPressed: state.opening
              ? null
              : () =>
                  ref.read(searchControllerProvider.notifier).openChat(user),
          child: state.opening
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Color(0xFF04141C), strokeWidth: 2),
                )
              : Text(context.tr('send_message')),
        ),
      ),
    );
  }
}
