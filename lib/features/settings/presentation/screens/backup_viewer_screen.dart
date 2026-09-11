import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../services/backup_service.dart';
import '../../../../utils/app_theme.dart';
import '../../../../services/backup_restore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/prefs/chat_prefs.dart';

/// 💾 Yedek görüntüleyici — SALT OKUNUR.
///
/// Yedek, canlı verinin üzerine YAZILMAZ. Amaç geçmişe erişmek;
/// sunucudaki mevcut sohbetleri bozmamak (çift kayıt / şifreleme
/// uyumsuzluğu riski taşımadan).
class BackupViewerScreen extends ConsumerStatefulWidget {
  final BackupData data;
  final String myUid;
  const BackupViewerScreen(
      {super.key, required this.data, required this.myUid});

  @override
  ConsumerState<BackupViewerScreen> createState() => _BackupViewerScreenState();
}

class _BackupViewerScreenState extends ConsumerState<BackupViewerScreen> {
  bool _busy = false;
  double _progress = 0;
  String _label = '';
  BackupData get data => widget.data;

  /// Tüm yedeği bu cihaza geri yükle.
  Future<void> _restoreAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('restore'),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Text(context.tr('restore_confirm'),
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('restore'),
                  style: const TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // ⚠️ YEDEK BU HESABA AİT Mİ? (§4ao)
    // Geri yükleme tamamen yerel ve `chatId` ile anahtarlı; birebir
    // sohbet kimliği `sıralı(uid1,uid2)`den türüyor. Başka bir hesabın
    // yedeği, bu hesabın hiçbir zaman açmayacağı chatId'lere yazılır:
    // ekran "N mesaj geri yüklendi" der ve kullanıcı hiçbir şey görmez.
    // Sessiz başarı yerine açık hata.
    if (!data.belongsTo(widget.myUid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('err_backup_other_account'))),
      );
      return;
    }

    setState(() {
      _busy = true;
      _progress = 0;
      _label = '';
    });
    final n = await BackupRestoreService.restoreAll(
      data,
      onProgress: (p, l) {
        if (mounted) {
          setState(() {
            _progress = p;
            _label = l;
          });
        }
      },
    );
    // Silinmis (listeden gizlenmis) sohbetleri TEK islemde geri getir.
    await ref
        .read(chatPrefsProvider(widget.myUid).notifier)
        .unmarkDeletedAll(data.chats.map((c) => c.id));
    if (!mounted) return;
    setState(() => _busy = false);
    await _showResult(n, data.chats.length);
  }

  /// SONUÇ ÖZETİ.
  ///
  /// NOT: Geri yükleme artık çok hızlı bittiği için ilerleme çubuğu
  /// çoğu zaman görünmeden kapanıyor. Kullanıcıya "oldu mu?" sorusunu
  /// bırakmamak için işlem sonunda net bir özet gösteriyoruz.
  /// (Yapay gecikme eklemek yerine — sahte ilerleme dürüst değil.)
  Future<void> _showResult(int messages, int chats) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppTheme.secure, size: 22),
            const SizedBox(width: 10),
            Text(context.tr('restore'),
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$messages ${context.tr('restore_done')}',
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
            const SizedBox(height: 6),
            Text('$chats ${context.tr('tab_chats').toLowerCase()}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Text(
              messages == 0
                  ? context.tr('restore_none')
                  : context.tr('restore_where'),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('ok'))),
        ],
      ),
    );
  }

  /// Tek sohbeti geri yükle.
  Future<void> _restoreOne(BackupChat c) async {
    setState(() => _busy = true);
    final n = await BackupRestoreService.restoreChat(c);
    await ref
        .read(chatPrefsProvider(widget.myUid).notifier)
        .unmarkDeleted(c.id);
    if (!mounted) return;
    setState(() => _busy = false);
    await _showResult(n, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('backup'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${data.chatCount} · ${data.messageCount}'
                    '${data.createdAt != null ? " · ${data.createdAt!.day}.${data.createdAt!.month}.${data.createdAt!.year}" : ""}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
                if (!_busy)
                  TextButton.icon(
                    onPressed: _restoreAll,
                    icon: const Icon(Icons.restore, size: 18),
                    label: Text(context.tr('restore_all')),
                  ),
              ],
            ),
          ),
          if (_busy) ...[
            LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                backgroundColor: AppTheme.surface,
                color: AppTheme.primary),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                  '%${(_progress * 100).round()}'
                  '${_label.isEmpty ? "" : "  ·  $_label"}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
          ],
          Expanded(
            child: ListView.separated(
              itemCount: data.chats.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0x11FFFFFF)),
              itemBuilder: (context, i) {
                final c = data.chats[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.surface,
                    child: Icon(
                        c.isGroup ? Icons.groups_outlined : Icons.person,
                        color: AppTheme.textSecondary,
                        size: 18),
                  ),
                  title: Text(c.title,
                      style: const TextStyle(color: AppTheme.textPrimary)),
                  subtitle: Text('${c.messages.length}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: IconButton(
                    tooltip: context.tr('restore'),
                    icon: const Icon(Icons.restore,
                        size: 20, color: AppTheme.primary),
                    onPressed: _busy ? null : () => _restoreOne(c),
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _BackupChatScreen(chat: c),
                  )),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupChatScreen extends StatelessWidget {
  final BackupChat chat;
  const _BackupChatScreen({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(chat.title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: chat.messages.length,
        itemBuilder: (context, i) {
          final m = chat.messages[i];
          final t = m.timestamp;
          String two(int n) => n.toString().padLeft(2, '0');
          final stamp = t == null
              ? ''
              : '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('@${m.senderUsername}',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(stamp,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 5),
                SelectableText(m.content,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14.5)),
              ],
            ),
          );
        },
      ),
    );
  }
}
