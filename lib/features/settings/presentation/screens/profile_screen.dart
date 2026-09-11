import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../services/auth_service.dart';
import '../../../../models/user_model.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/widgets/image_picker_helper.dart';

/// Kullanıcının kendi profili: fotoğraf + "Hakkında" (bio) düzenleme.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _bioController = TextEditingController();
  UserModel? _profile;
  bool _loading = true;
  bool _uploading = false;
  bool _savingBio = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await AuthService.getMyProfile();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _bioController.text = p?.bio ?? '';
      _loading = false;
    });
  }

  Future<void> _changePhoto() async {
    // ✂️ SERBEST kırpma (oran düğmesi yok — kullanıcı isteği).
    //
    // ⚠️ Avatar `CircleAvatar` ile çizilir; o da görüntüyü KARE alana
    // kırpıp yuvarlağa oturtur. Kare dışı bir seçimde kenarlar yine
    // kırpılır. Kilidi kaldırmak, kullanıcıya hangi BÖLGENİN
    // kullanılacağını seçtirir; dairenin kendisini değiştirmez.
    final path = await ImagePickerHelper.pickAndCrop(
      context,
      source: ImageSource.gallery,
      mod: KirpmaModu.serbest,
      imageQuality: 75,
      maxWidth: 800,
    );
    if (path == null || !mounted) return;
    final picked = XFile(path);

    // 🖼️ ÖNİZLEME + ONAY (grup fotoğrafıyla aynı akış)
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('photo_preview'),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.file(File(picked.path),
                  width: 200, height: 200, fit: BoxFit.cover),
            ),
            const SizedBox(height: 14),
            Text(context.tr('photo_preview_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12.5)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('use_photo'),
                  style: const TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _uploading = true);
    try {
      await AuthService.uploadAndSetAvatar(picked.path);
      // UserAvatar önbelleğini yenile (hikaye halkası, sohbet listesi vb.)
      final uid = AuthService.currentUid;
      if (uid != null) ref.invalidate(userProfileProvider(uid));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('photo_upload_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveBio() async {
    setState(() => _savingBio = true);
    try {
      await AuthService.setBio(_bioController.text.trim());
      final uid = AuthService.currentUid;
      if (uid != null) ref.invalidate(userProfileProvider(uid));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('about_saved'))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = _profile?.username ?? '';
    final avatarUrl = _profile?.avatarUrl;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('my_profile'))),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Avatar + değiştir
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: AppTheme.primary,
                        backgroundImage:
                            (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Color(0xFF04141C),
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _uploading ? null : _changePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.surfaceLight,
                              shape: BoxShape.circle,
                            ),
                            child: _uploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.primary),
                                  )
                                : const Icon(Icons.camera_alt,
                                    size: 18, color: AppTheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    username.isNotEmpty ? '@$username' : '',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 28),

                // Hakkında
                Text(context.tr('about_caps'),
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        letterSpacing: 1.2)),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  maxLength: 200,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: context.tr('about_hint'),
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _savingBio ? null : _saveBio,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: const Color(0xFF04141C),
                    ),
                    child: _savingBio
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF04141C)),
                          )
                        : Text(context.tr('save')),
                  ),
                ),
              ],
            ),
    );
  }
}
