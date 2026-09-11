import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/group_create_controller.dart';
import '../../../messaging/presentation/screens/messaging_screen.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';

/// Kanal oluşturma ekranı (yeni mimari).
class CreateChannelScreen extends ConsumerStatefulWidget {
  final String myUid;
  const CreateChannelScreen({super.key, required this.myUid});

  @override
  ConsumerState<CreateChannelScreen> createState() =>
      _CreateChannelScreenState();
}

class _CreateChannelScreenState extends ConsumerState<CreateChannelScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _create() {
    ref.read(groupCreateControllerProvider.notifier).createChannel(
          _nameController.text.trim(),
          _descController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupCreateControllerProvider);

    ref.listen<GroupCreateState>(groupCreateControllerProvider, (prev, next) {
      if (next.createdChatId != null &&
          next.createdChatId != prev?.createdChatId) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MessagingScreen(
              chatId: next.createdChatId!,
              chatTitle: next.createdName ?? 'Kanal',
              myUid: widget.myUid,
              isGroup: true,
            ),
          ),
        );
      }
    });

    final canCreate = !state.creating && _nameController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('create_channel_t'))),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.campaign_outlined,
                color: AppTheme.primary, size: 40),
            const SizedBox(height: Spacing.lg),
            Text(context.tr('channel_oneway'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.xs),
            Text(context.tr('channel_oneway_sub'),
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: Spacing.xl),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(hintText: context.tr('channel_name')),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _descController,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 3,
              decoration:
                  InputDecoration(hintText: context.tr('desc_optional')),
            ),
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
                    : Text(context.tr('create_channel_t')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
