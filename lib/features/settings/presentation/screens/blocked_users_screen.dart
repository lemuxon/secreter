import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../services/block_service.dart';
import '../../../../utils/app_theme.dart';
import 'user_profile_view.dart';
import '../../../../core/widgets/user_avatar.dart';

/// 🛡️ Engellenen kullanıcılar — Ayarlar → Engellenenler.
/// Buradan engel kaldırılabilir; isim tıklanınca profil açılır.
class BlockedUsersScreen extends ConsumerWidget {
  final String myUid;
  const BlockedUsersScreen({super.key, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUsersProvider(myUid));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('blocked_users'))),
      body: blockedAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            // ⚠️ Ham istisna EKRANA basılmaz (§4ao): Firestore hataları
            // doküman yolu taşır ve o yol `users/<uid>/private/blocks`
            // — yani kullanıcının kendi kimliği ekranda görünürdü.
            child: Text(context.tr('err_unexpected'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
        ),
        data: (blocked) {
          if (blocked.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block,
                      size: 52, color: AppTheme.textSecondary),
                  const SizedBox(height: 14),
                  Text(context.tr('no_blocked'),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 15)),
                ],
              ),
            );
          }
          final list = blocked.toList();
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0x11FFFFFF)),
            itemBuilder: (context, i) => _tile(context, list[i]),
          );
        },
      ),
    );
  }

  /// HATA DÜZELTMESİ: eskiden ham kullanıcı kimliği (rastgele harf-rakam)
  /// gösteriliyordu. Artık profil sorgulanıp KULLANICI ADI gösteriliyor.
  Widget _tile(BuildContext context, String uid) {
    return Consumer(builder: (context, ref, _) {
      final profile = ref.watch(userProfileProvider(uid));
      final username = profile.asData?.value?.username;
      final label = (username == null || username.isEmpty) ? '…' : '@$username';
      final initial = (username == null || username.isEmpty)
          ? '?'
          : username[0].toUpperCase();

      return ListTile(
        leading: UserAvatar(uid: uid, fallbackLetter: initial, radius: 20),
        title: Text(label,
            style:
                const TextStyle(color: AppTheme.textPrimary, fontSize: 14.5)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              UserProfileView(uid: uid, fallbackUsername: username ?? ''),
        )),
        trailing: TextButton(
          onPressed: () => BlockService.unblock(myUid, uid),
          child: Text(context.tr('unblock_user'),
              style: const TextStyle(color: AppTheme.primary)),
        ),
      );
    });
  }
}
