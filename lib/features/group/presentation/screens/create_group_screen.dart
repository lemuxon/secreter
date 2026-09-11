import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/group_create_controller.dart';
import '../../../search/domain/entities/found_user.dart';
import '../../../messaging/presentation/screens/messaging_screen.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';

/// Grup oluşturma ekranı (yeni mimari) — üye arayıp seç.
class CreateGroupScreen extends ConsumerStatefulWidget {
  final String myUid;
  const CreateGroupScreen({super.key, required this.myUid});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    ref
        .read(groupCreateControllerProvider.notifier)
        .searchUser(_searchController.text);
  }

  void _create() {
    ref
        .read(groupCreateControllerProvider.notifier)
        .createGroup(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupCreateControllerProvider);
    final notifier = ref.read(groupCreateControllerProvider.notifier);

    ref.listen<GroupCreateState>(groupCreateControllerProvider, (prev, next) {
      if (next.createdChatId != null &&
          next.createdChatId != prev?.createdChatId) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MessagingScreen(
              chatId: next.createdChatId!,
              chatTitle: next.createdName ?? 'Grup',
              myUid: widget.myUid,
              isGroup: true,
            ),
          ),
        );
      }
    });

    final canCreate = !state.creating &&
        _nameController.text.trim().isNotEmpty &&
        state.selectedMembers.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('create_group'))),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(hintText: context.tr('group_name')),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.lg),
            // Seçili üyeler
            if (state.selectedMembers.isNotEmpty)
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: state.selectedMembers
                    .map((u) => Chip(
                          backgroundColor: AppTheme.surfaceLight,
                          label: Text('@${u.username}',
                              style:
                                  const TextStyle(color: AppTheme.textPrimary)),
                          deleteIconColor: AppTheme.textSecondary,
                          onDeleted: () => notifier.removeMember(u),
                        ))
                    .toList(),
              ),
            const SizedBox(height: Spacing.sm),
            // Üye arama
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: '@kullanici_adi ekle',
                      prefixIcon:
                          Icon(Icons.person_add_alt, color: AppTheme.primary),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                FilledButton(
                  onPressed: state.searching ? null : _search,
                  child: state.searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Color(0xFF04141C), strokeWidth: 2),
                        )
                      : Text(context.tr('search')),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            if (state.searchError != null)
              Text(state.searchError!,
                  style: const TextStyle(color: AppTheme.textSecondary)),
            if (state.searchResult != null)
              _searchResultTile(state.searchResult!, notifier),
            if (state.error != null) ...[
              const SizedBox(height: Spacing.md),
              Text(context.tr(state.error!),
                  style: const TextStyle(color: AppTheme.danger)),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canCreate ? _create : null,
                child: state.creating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Color(0xFF04141C), strokeWidth: 2),
                      )
                    : Text(
                        '${context.tr('create_group')} (${state.selectedMembers.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchResultTile(FoundUser user, GroupCreateController notifier) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary,
          child: Text(user.avatarLetter,
              style: const TextStyle(
                  color: Color(0xFF04141C), fontWeight: FontWeight.bold)),
        ),
        title: Text('@${user.username}',
            style: const TextStyle(color: AppTheme.textPrimary)),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: AppTheme.online),
          onPressed: () => notifier.addMember(user),
        ),
      ),
    );
  }
}
