import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../models/call_model.dart';
import '../../../../services/call_log_service.dart';
import '../../../../utils/app_theme.dart';
import '../../../settings/presentation/screens/user_profile_view.dart';
import 'call_screen.dart';
import '../../../../core/widgets/user_avatar.dart';

/// 📞 Çağrı geçmişi sekmesi.
///
/// Etkileşimler:
/// • Uzun bas → seçim modu, çoklu seçim, toplu sil
/// • Sola kaydır → aynı kişiyi tekrar ara
/// • Avatara dokun → kişinin profili
///
/// Silme KİŞİYE ÖZELDİR: kayıt iki tarafa ait olduğu için doküman
/// silinmez, yalnızca bu kullanıcı için gizlenir.
class CallLogScreen extends ConsumerStatefulWidget {
  final String myUid;
  const CallLogScreen({super.key, required this.myUid});

  @override
  ConsumerState<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends ConsumerState<CallLogScreen> {
  // PERFORMANS: stream bir kez kurulur (build içinde üretilirse her
  // çizimde yeni Firestore dinleyicisi açılır).
  late final Stream<List<CallLogEntry>> _logs =
      CallLogService.watch(widget.myUid);

  final Set<String> _selected = {};
  bool get _selectionMode => _selected.isNotEmpty;

  String get myUid => widget.myUid;

  void _toggle(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    final n = ids.length;
    _clearSelection();
    try {
      await CallLogService.deleteForMe(ids, myUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n ${context.tr('calls_deleted')}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('err_unexpected'))));
    }
  }

  void _callBack(CallLogEntry c) {
    final uid = c.otherUid(myUid);
    if (uid.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CallScreen(
        calleeId: uid,
        calleeUsername: c.otherName(myUid),
        callType: c.type == 'video' ? CallType.video : CallType.audio,
      ),
    ));
  }

  void _openProfile(CallLogEntry c) {
    final uid = c.otherUid(myUid);
    if (uid.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UserProfileView(
        uid: uid,
        fallbackUsername: c.otherName(myUid),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_selectionMode) _selectionBar(),
        Expanded(
          child: StreamBuilder<List<CallLogEntry>>(
            stream: _logs,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(snap.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary)),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary));
              }
              final logs = snap.data!;
              if (logs.isEmpty) return _empty();
              return ListView.separated(
                padding: const EdgeInsets.only(top: 6, bottom: 24),
                itemCount: logs.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0x11FFFFFF)),
                itemBuilder: (context, i) => _row(logs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _selectionBar() {
    return Material(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textPrimary),
              onPressed: _clearSelection,
              tooltip: context.tr('cancel_it'),
            ),
            Expanded(
              child: Text(
                '${_selected.length} ${context.tr('n_selected')}',
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
              tooltip: context.tr('delete'),
              onPressed: _deleteSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call_outlined,
                size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 14),
            Text(context.tr('no_calls'),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );

  /// Satır: seçim modunda dokunuş seçer; değilken sola kaydırma geri arar.
  Widget _row(CallLogEntry c) {
    final tile = _tile(c);
    if (_selectionMode) return tile;

    return Dismissible(
      key: ValueKey('call_${c.callId}'),
      direction: DismissDirection.endToStart,
      // Kaydırma bir eylemi TETİKLER, satırı silmez.
      confirmDismiss: (_) async {
        _callBack(c);
        return false;
      },
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.only(right: 22),
        color: AppTheme.secure.withValues(alpha: 0.18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(context.tr('call_again'),
                style: const TextStyle(
                    color: AppTheme.secure, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.call, color: AppTheme.secure),
          ],
        ),
      ),
      child: tile,
    );
  }

  Widget _tile(CallLogEntry c) {
    final outgoing = c.isOutgoing(myUid);
    final name = c.otherName(myUid);
    final selected = _selected.contains(c.callId);

    // RENK KURALI: ULAŞILAMAYAN kırmızı, ULAŞILAN yeşil.
    final unreachable = c.isMissed || c.isRejected;
    const red = AppTheme.danger;
    const green = AppTheme.secure;
    const iconMissedIn = Icon(Icons.call_missed, size: 14, color: red);
    const iconMissedOut =
        Icon(Icons.call_missed_outgoing, size: 14, color: red);
    const iconOutOk = Icon(Icons.call_made, size: 14, color: green);
    const iconInOk = Icon(Icons.call_received, size: 14, color: green);
    final Widget dirIcon = unreachable
        ? (outgoing ? iconMissedOut : iconMissedIn)
        : (outgoing ? iconOutOk : iconInOk);

    return ListTile(
      tileColor: selected ? AppTheme.primary.withValues(alpha: 0.14) : null,
      onLongPress: () => _toggle(c.callId),
      onTap: _selectionMode ? () => _toggle(c.callId) : null,
      leading: GestureDetector(
        // Seçim modunda avatar da seçer; değilken profile götürür.
        onTap: () => _selectionMode ? _toggle(c.callId) : _openProfile(c),
        child: selected
            ? const CircleAvatar(
                backgroundColor: AppTheme.primary,
                child: Icon(Icons.check, color: Color(0xFF04141C)),
              )
            : UserAvatar(
                uid: c.otherUid(myUid),
                fallbackLetter: name.isEmpty ? '?' : name[0].toUpperCase(),
                radius: 20,
              ),
      ),
      title: Text('@$name',
          style: TextStyle(
              color: unreachable ? AppTheme.danger : AppTheme.textPrimary,
              fontWeight: unreachable ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Row(
        children: [
          dirIcon,
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _subtitle(context, c, outgoing, unreachable),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      ),
      trailing: _selectionMode
          ? null
          : IconButton(
              tooltip: context.tr('call_again'),
              icon: c.type == 'video'
                  ? const Icon(Icons.videocam_outlined,
                      size: 20, color: AppTheme.textSecondary)
                  : const Icon(Icons.call_outlined,
                      size: 20, color: AppTheme.textSecondary),
              onPressed: () => _callBack(c),
            ),
    );
  }

  String _subtitle(
      BuildContext context, CallLogEntry c, bool outgoing, bool unreachable) {
    final when = _when(context, c.createdAt);
    if (c.isRejected) return '${context.tr('call_rejected')} · $when';
    if (unreachable) return '${context.tr('call_missed')} · $when';
    if (c.durationSec > 0) return '${_dur(c.durationSec)} · $when';
    return when;
  }

  String _dur(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m == 0) return '${s}s';
    return '${m}dk ${s.toString().padLeft(2, '0')}s';
  }

  String _when(BuildContext context, DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final hm = '${two(t.hour)}:${two(t.minute)}';
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    if (sameDay) return hm;
    final y = now.subtract(const Duration(days: 1));
    if (t.year == y.year && t.month == y.month && t.day == y.day) {
      return '${context.tr('yesterday')} $hm';
    }
    return '${two(t.day)}.${two(t.month)} $hm';
  }
}
