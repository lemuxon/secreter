import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

/// Kullanıcı profilini uid ile getirir (foto + bio + username). Riverpod cache'ler.
final userProfileProvider =
    FutureProvider.family<UserModel?, String>((ref, uid) async {
  return AuthService.getUserProfile(uid);
});

/// Profil fotoğrafı varsa gösterir, yoksa harf avatarı. uid ile profili çeker.
class UserAvatar extends ConsumerWidget {
  final String uid;
  final String fallbackLetter;
  final double radius;

  const UserAvatar({
    super.key,
    required this.uid,
    required this.fallbackLetter,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid));
    final user = profile.asData?.value;
    final url = user?.avatarUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    // fallbackLetter boşsa çekilen kullanıcı adının ilk harfini kullan
    final letter = fallbackLetter.isNotEmpty
        ? fallbackLetter
        : ((user?.username.isNotEmpty ?? false)
            ? user!.username[0].toUpperCase()
            : '?');

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary,
      backgroundImage: hasPhoto ? CachedNetworkImageProvider(url) : null,
      child: hasPhoto
          ? null
          : Text(
              letter,
              style: TextStyle(
                color: const Color(0xFF04141C),
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}
