import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/prefs/decoy_content.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';

/// 🎭 Sahte sohbet düzenleyici — kullanici, sahte PIN girildiginde
/// gorunecek zararsiz sohbetleri kendisi hazirlar (inandiricilik).
class DecoyEditorScreen extends ConsumerWidget {
  const DecoyEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(decoyContentProvider);
    final notifier = ref.read(decoyContentProvider.notifier);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(context.tr('decoy_chats'),
            style: const TextStyle(color: AppTheme.textPrimary)),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sahte PIN girildiğinde bu sohbetler görünür. Boş bir '
              'ekran şüphe çekeceği için, buraya zararsız görünen '
              'sohbetler ekle.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, i) {
                final c = chats[i];
                return ListTile(
                  leading:
                      const Icon(Icons.chat_outlined, color: AppTheme.primary),
                  title: Text(c.name,
                      style: const TextStyle(color: AppTheme.textPrimary)),
                  subtitle: Text('${c.messages.length} mesaj',
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.danger),
                    onPressed: () => notifier.removeChat(i),
                  ),
                  onTap: () => _editChat(context, ref, i, c),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Color(0xFF04141C)),
        onPressed: () => _addChat(context, notifier),
      ),
    );
  }

  Future<void> _addChat(
      BuildContext context, DecoyContentNotifier notifier) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('decoy_chat_name'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(hintText: context.tr('decoy_example')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(context.tr('add'),
                  style: const TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await notifier.addChat(name);
    }
  }

  Future<void> _editChat(
      BuildContext context, WidgetRef ref, int index, DecoyChat chat) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _DecoyChatEditor(index: index, chat: chat),
    ));
  }
}

class _DecoyChatEditor extends ConsumerWidget {
  final int index;
  final DecoyChat chat;
  const _DecoyChatEditor({required this.index, required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // her degisiklikte guncel chat'i saglayicidan al
    final live = ref.watch(decoyContentProvider);
    final c = index < live.length ? live[index] : chat;
    final notifier = ref.read(decoyContentProvider.notifier);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title:
            Text(c.name, style: const TextStyle(color: AppTheme.textPrimary)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: c.messages.length,
              itemBuilder: (context, i) {
                final m = c.messages[i];
                return Align(
                  alignment:
                      m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: m.mine
                          ? AppTheme.bubbleSent
                          : AppTheme.bubbleReceived,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.text,
                        style: const TextStyle(color: AppTheme.textPrimary)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _addBtn(context, notifier, 'Gelen', false),
                const SizedBox(width: 8),
                _addBtn(context, notifier, 'Giden', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addBtn(BuildContext context, DecoyContentNotifier notifier,
      String label, bool mine) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () async {
          final ctrl = TextEditingController();
          final text = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text('$label mesaj',
                  style: const TextStyle(color: AppTheme.textPrimary)),
              content: TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(context.tr('cancel'))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                    child: Text(context.tr('add'),
                        style: const TextStyle(color: AppTheme.primary))),
              ],
            ),
          );
          if (text != null && text.isNotEmpty) {
            await notifier.addMessage(index, text, mine);
          }
        },
        child: Text(label),
      ),
    );
  }
}
