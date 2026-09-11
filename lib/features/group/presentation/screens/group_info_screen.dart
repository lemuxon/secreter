import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/group_notifier.dart';
import '../../domain/entities/group_entity.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/image_picker_helper.dart';

/// Grup bilgisi / yönetim ekranı (yeni mimari).
/// Rol değiştirme, susturma, atma/yasaklama, davet linki, ayarlar.
class GroupInfoScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String myUid;
  const GroupInfoScreen({super.key, required this.chatId, required this.myUid});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  ({String chatId, String myUid}) get _params =>
      (chatId: widget.chatId, myUid: widget.myUid);

  @override
  void initState() {
    super.initState();
    // Davet kodunu yükle (gruplar için)
    Future.microtask(() =>
        ref.read(groupNotifierProvider(_params).notifier).loadInviteCode());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupNotifierProvider(_params));
    final group = state.group;

    ref.listen<GroupState>(groupNotifierProvider(_params), (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr(next.error!))));
        ref.read(groupNotifierProvider(_params).notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(group?.isChannel == true
            ? context.tr('channel_info_title')
            : context.tr('group_info_title')),
      ),
      body: group == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _buildContent(group),
    );
  }

  Widget _buildContent(GroupEntity group) {
    final canModerate = group.canModerate(widget.myUid);
    return ListView(
      children: [
        const SizedBox(height: Spacing.xl),
        _header(group, canModerate),
        const SizedBox(height: Spacing.xl),
        // KANAL YETKILERI: davet ve ayar bolumleri kanallarda da acik.
        // (Kanal yoneticisi davet kodu paylasabilmeli ve gerekirse tum
        //  uyelerin yazmasina izin verebilmeli.)
        if (canModerate) _inviteSection(group),
        if (canModerate) _settingsSection(group),
        _membersHeader(group),
        ...group.members.map((m) => _memberTile(group, m, canModerate)),
        const SizedBox(height: Spacing.xl),
        _leaveButton(group),
        const SizedBox(height: Spacing.xl),
      ],
    );
  }

  Future<void> _changeGroupPhoto() async {
    // ✂️ Grup/kanal fotoğrafı KARE kırpılır
    final path = await ImagePickerHelper.pickAndCrop(
      context,
      source: ImageSource.gallery,
      mod: KirpmaModu.kare,
      imageQuality: 75,
      maxWidth: 800,
    );
    if (path == null || !mounted) return;
    final picked = XFile(path);

    // 🖼️ ÖNİZLEME + ONAY
    //
    // ESKİ DAVRANIŞ: Seçilen fotoğraf ANINDA yükleniyordu; kullanıcı
    // nasıl görüneceğini göremeden gönderiliyordu. Artık önce yuvarlak
    // çerçevede (gerçek görünümüyle) gösterilir, onaylanırsa yüklenir.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('photo_preview'),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Yuvarlak: profil fotoğrafı nasıl görünecekse öyle
            ClipOval(
              child: Image.file(
                File(picked.path),
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
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
    if (ok != true) return;

    await ref
        .read(groupNotifierProvider(_params).notifier)
        .setGroupPhoto(picked.path);
  }

  Widget _header(GroupEntity group, bool canModerate) {
    final title = group.groupName ?? 'Grup';
    final hasPhoto = group.avatarUrl != null && group.avatarUrl!.isNotEmpty;
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: AppTheme.primary,
              backgroundImage: hasPhoto
                  ? CachedNetworkImageProvider(group.avatarUrl!)
                  : null,
              child: hasPhoto
                  ? null
                  : Text(
                      title.isNotEmpty ? title[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Color(0xFF04141C),
                          fontSize: 36,
                          fontWeight: FontWeight.bold),
                    ),
            ),
            if (canModerate)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _changeGroupPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: AppTheme.primary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center),
            ),
            if (canModerate) ...[
              const SizedBox(width: Spacing.sm),
              GestureDetector(
                onTap: () => _editDialog(group),
                child:
                    const Icon(Icons.edit, size: 18, color: AppTheme.primary),
              ),
            ],
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          group.isChannel
              ? '${group.memberCount} abone · Kanal'
              : '${group.memberCount} ${context.tr('n_members')}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        if (group.description != null && group.description!.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Text(group.description!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ],
    );
  }

  Widget _inviteSection(GroupEntity group) {
    final code = ref.watch(groupNotifierProvider(_params)).inviteCode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.sm, Spacing.lg, Spacing.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: AppTheme.primary, size: 20),
                const SizedBox(width: Spacing.sm),
                Text(context.tr('invite_link'),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    code ?? '...',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontFamily: 'monospace',
                        fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy,
                      size: 18, color: AppTheme.textSecondary),
                  onPressed: code == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(context.tr('invite_copied'))),
                          );
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.share,
                      size: 18, color: AppTheme.primary),
                  tooltip: context.tr('share_invite'),
                  onPressed: code == null
                      ? null
                      : () {
                          final name =
                              group.groupName ?? context.tr('group_word');
                          final msg =
                              '$name — ${context.tr('invite_join_line')}\n\n'
                              '${context.tr('invite_code_label')}: $code\n'
                              '${context.tr('invite_link_label')}: secreter://join/$code\n\n'
                              '${context.tr('invite_howto')}';
                          Clipboard.setData(ClipboardData(text: msg));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(context.tr('invite_msg_copied'))),
                          );
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh,
                      size: 18, color: AppTheme.textSecondary),
                  onPressed: () => ref
                      .read(groupNotifierProvider(_params).notifier)
                      .resetInviteCode(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsSection(GroupEntity group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: SwitchListTile(
          value: group.onlyAdminsCanPost,
          activeThumbColor: AppTheme.primary,
          title: Text(context.tr('admins_only_send'),
              style:
                  const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
          onChanged: (v) => ref
              .read(groupNotifierProvider(_params).notifier)
              .setOnlyAdminsCanPost(v),
        ),
      ),
    );
  }

  Widget _membersHeader(GroupEntity group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.xl, Spacing.lg, Spacing.xl, Spacing.sm),
      child: Text(
          group.isChannel ? context.tr('admins') : context.tr('members_caps'),
          style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Widget _memberTile(
      GroupEntity group, GroupMemberEntity member, bool canModerate) {
    final isMe = member.uid == widget.myUid;
    final canActOn = canModerate && !isMe && member.role != MemberRole.owner;
    // Ad sohbet dokümanında tutulmuyor; uid'den çözülür (§4o).
    final name = member.displayName;
    return ListTile(
      // Üye listesinde de profil fotoğrafı (yoksa harfe düşer)
      leading: UserAvatar(
        uid: member.uid,
        fallbackLetter: name.isNotEmpty ? name[0].toUpperCase() : '?',
        radius: 20,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text('@$name${isMe ? ' (sen)' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textPrimary)),
          ),
          if (member.isMuted) ...[
            const SizedBox(width: 6),
            const Icon(Icons.volume_off,
                size: 14, color: AppTheme.textSecondary),
          ],
        ],
      ),
      subtitle: Text(_roleLabel(context, member.role),
          style: TextStyle(
              color: member.role == MemberRole.owner
                  ? AppTheme.primary
                  : AppTheme.textSecondary,
              fontSize: 12)),
      trailing: canActOn
          ? IconButton(
              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
              onPressed: () => _memberActions(member),
            )
          : null,
    );
  }

  String _roleLabel(BuildContext context, MemberRole role) {
    switch (role) {
      case MemberRole.owner:
        return context.tr('role_founder');
      case MemberRole.admin:
        return context.tr('role_admin');
      case MemberRole.member:
        return context.tr('role_member');
    }
  }

  void _memberActions(GroupMemberEntity member) {
    final notifier = ref.read(groupNotifierProvider(_params).notifier);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.shield_outlined, color: AppTheme.primary),
              title: Text(
                  member.role == MemberRole.admin
                      ? context.tr('remove_admin')
                      : context.tr('make_admin'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                notifier.changeMemberRole(
                    member,
                    member.role == MemberRole.admin
                        ? MemberRole.member
                        : MemberRole.admin);
              },
            ),
            ListTile(
              leading: Icon(member.isMuted ? Icons.volume_up : Icons.volume_off,
                  color: AppTheme.textPrimary),
              title: Text(
                  member.isMuted
                      ? context.tr('unmute_user')
                      : context.tr('mute_user'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                notifier.toggleMute(member);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: AppTheme.danger),
              title: Text(context.tr('kick_member'),
                  style: const TextStyle(color: AppTheme.danger)),
              onTap: () {
                Navigator.pop(context);
                notifier.removeMember(member, ban: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppTheme.danger),
              title: Text(context.tr('ban_member'),
                  style: const TextStyle(color: AppTheme.danger)),
              onTap: () {
                Navigator.pop(context);
                notifier.removeMember(member, ban: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editDialog(GroupEntity group) {
    final nameCtrl = TextEditingController(text: group.groupName ?? '');
    final descCtrl = TextEditingController(text: group.description ?? '');
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('edit_group'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(hintText: context.tr('group_name')),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(hintText: context.tr('group_desc')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel_it2')),
          ),
          FilledButton(
            onPressed: () {
              ref.read(groupNotifierProvider(_params).notifier).updateInfo(
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                  );
              Navigator.pop(context);
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    ).whenComplete(() {
      // SIZINTI ONLEME: dialog kapaninca controller'lar dispose edilir
      nameCtrl.dispose();
      descCtrl.dispose();
    });
  }

  Widget _leaveButton(GroupEntity group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.logout, color: AppTheme.danger),
          label: Text(
              group.isChannel
                  ? context.tr('leave_channel')
                  : context.tr('leave_group'),
              style: const TextStyle(color: AppTheme.danger)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppTheme.danger),
          ),
          onPressed: () => _confirmLeave(),
        ),
      ),
    );
  }

  void _confirmLeave() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('leave'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(context.tr('leave_group_confirm'),
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final ok = await ref
                  .read(groupNotifierProvider(_params).notifier)
                  .leaveGroup();
              if (ok && mounted) {
                // Gruptan çık → sohbet listesine dön
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: Text(context.tr('leave')),
          ),
        ],
      ),
    );
  }
}
