import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/prefs/starred_messages.dart';
import '../../../messaging/presentation/screens/messaging_screen.dart';
import '../../../../core/i18n/app_localizations.dart';

/// ⭐ Yıldızlı mesajlar listesi (Ayarlar'dan açılır).
/// Satıra dokun → o sohbete git; yıldıza dokun → favoriden çıkar.
class StarredScreen extends ConsumerWidget {
  final String myUid;
  const StarredScreen({super.key, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starred = ref.watch(starredProvider(myUid));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(context.tr('starred_msgs'),
            style: const TextStyle(color: AppTheme.textPrimary)),
      ),
      body: starred.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border,
                      size: 56, color: AppTheme.textSecondary),
                  SizedBox(height: 12),
                  Text(
                    'Henüz yıldızlı mesaj yok\nBir mesaja uzun basıp ⋮ → Yıldızla',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: starred.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = starred[i];
                return ListTile(
                  leading: const Icon(Icons.star,
                      color: Color(0xFFFFC94D), size: 22),
                  title: Text(
                    '${m.chatTitle}  ·  ${m.sender}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12.5),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      m.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14.5),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _dateStr(m.timestamp),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => ref
                            .read(starredProvider(myUid).notifier)
                            .remove(m.messageId),
                        child: const Icon(Icons.star_outline,
                            size: 20, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MessagingScreen(
                        chatId: m.chatId,
                        chatTitle: m.chatTitle,
                        myUid: myUid,
                        isGroup: m.isGroup,
                      ),
                    ));
                  },
                );
              },
            ),
    );
  }

  String _dateStr(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year}';
  }
}
