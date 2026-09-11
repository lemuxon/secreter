import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/full_screen_image.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../services/block_service.dart';
import '../../../../core/widgets/safety_actions.dart';
import '../../../../services/auth_service.dart';

/// Başka bir kullanıcının profili (salt-okunur): foto (dokun→zoom) + kullanıcı
/// adı + hakkında.
class UserProfileView extends ConsumerWidget {
  final String uid;
  final String fallbackUsername;

  const UserProfileView({
    super.key,
    required this.uid,
    required this.fallbackUsername,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid));
    final user = profile.asData?.value;
    final username = user?.username ?? fallbackUsername;
    final avatarUrl = user?.avatarUrl;
    final bio = user?.bio;
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(context.tr('profile')),
        actions: [
          // 🛡️ Güvenlik eylemleri (engelle / şikâyet)
          Consumer(builder: (context, ref2, _) {
            final myUid = AuthService.currentUid;
            if (myUid == null || myUid == uid) return const SizedBox.shrink();
            final blockedAsync = ref2.watch(blockedUsersProvider(myUid));
            final blocked = blockedAsync.asData?.value.contains(uid) ?? false;
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
              color: AppTheme.surface,
              onSelected: (v) {
                if (v == 'block') {
                  SafetyActions.confirmBlock(context,
                      myUid: myUid,
                      otherUid: uid,
                      username: username,
                      currentlyBlocked: blocked);
                } else if (v == 'report') {
                  SafetyActions.report(context,
                      myUid: myUid, otherUid: uid, username: username);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'block',
                  child: Text(
                      blocked
                          ? context.tr('unblock_user')
                          : context.tr('block_user'),
                      style: const TextStyle(color: AppTheme.danger)),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Text(context.tr('report_user'),
                      style: const TextStyle(color: AppTheme.textPrimary)),
                ),
              ],
            );
          }),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Consumer(builder: (context, ref2, _) {
            final myUid = AuthService.currentUid;
            if (myUid == null) return const SizedBox.shrink();
            final blocked = ref2
                    .watch(blockedUsersProvider(myUid))
                    .asData
                    ?.value
                    .contains(uid) ??
                false;
            if (!blocked) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, size: 16, color: AppTheme.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.tr('blocked_notice'),
                        style: const TextStyle(
                            color: AppTheme.danger, fontSize: 13)),
                  ),
                ],
              ),
            );
          }),
          Center(
            child: GestureDetector(
              onTap: hasPhoto
                  ? () => FullScreenImage.open(context, avatarUrl)
                  : null,
              child: CircleAvatar(
                radius: 56,
                backgroundColor: AppTheme.primary,
                backgroundImage:
                    hasPhoto ? CachedNetworkImageProvider(avatarUrl) : null,
                child: hasPhoto
                    ? null
                    : Text(
                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Color(0xFF04141C),
                            fontSize: 44,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '@$username',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 28),
          const Text('HAKKINDA',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (bio != null && bio.isNotEmpty) ? bio : context.tr('no_about'),
              style: TextStyle(
                color: (bio != null && bio.isNotEmpty)
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
