import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../services/meet_code_service.dart';
import '../../../../utils/app_theme.dart';
import '../../domain/repositories/search_repository.dart';
import '../../../messaging/presentation/screens/messaging_screen.dart';

/// 🤝 BULUŞMA KODU EKRANI
///
/// İki bölüm: kod üret (paylaş) ve kod gir (bağlan).
class MeetCodeScreen extends ConsumerStatefulWidget {
  final String myUid;
  final String myUsername;
  const MeetCodeScreen(
      {super.key, required this.myUid, required this.myUsername});

  @override
  ConsumerState<MeetCodeScreen> createState() => _MeetCodeScreenState();
}

class _MeetCodeScreenState extends ConsumerState<MeetCodeScreen> {
  final _inputController = TextEditingController();
  MeetCode? _myCode;
  bool _creating = false;
  bool _joining = false;
  Timer? _ticker;
  StreamSubscription<String?>? _usedSub;

  @override
  void dispose() {
    _ticker?.cancel();
    _usedSub?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final code = await MeetCodeService.create(
        myUid: widget.myUid,
        myUsername: widget.myUsername,
      );
      if (!mounted) return;
      setState(() {
        _myCode = code;
        _creating = false;
      });
      // Geri sayım
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (code.remaining == Duration.zero) {
          t.cancel();
          setState(() => _myCode = null);
        } else {
          setState(() {});
        }
      });
      // Karşı taraf kodu girdiğinde haber ver
      _usedSub?.cancel();
      _usedSub = MeetCodeService.watchUsedBy(code.code).listen((who) {
        if (!mounted || who == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('@$who · ${context.tr('meet_code_used_by')}')),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('meet_code_create_failed'))));
    }
  }

  Future<void> _cancelCode() async {
    final c = _myCode;
    if (c == null) return;
    _ticker?.cancel();
    _usedSub?.cancel();
    setState(() => _myCode = null);
    await MeetCodeService.cancel(c.code);
  }

  Future<void> _join() async {
    final raw = _inputController.text;
    if (raw.trim().isEmpty) return;
    setState(() => _joining = true);
    try {
      // 1) Kodu kullan → karşı tarafın kullanıcı adı
      final username = await MeetCodeService.redeem(
        code: raw,
        myUid: widget.myUid,
        myUsername: widget.myUsername,
      );
      // 2) Mevcut altyapıyla sohbeti aç/oluştur
      final result =
          await getIt<SearchRepository>().getOrCreateDirectChat(username);
      if (!mounted) return;
      setState(() => _joining = false);
      result.fold(
        (f) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr(f.message)))),
        (chatId) => Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => MessagingScreen(
            chatId: chatId,
            chatTitle: '@$username',
            myUid: widget.myUid,
          ),
        )),
      );
    } on MeetCodeError catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr(e.key))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('meet_code_not_found'))));
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final code = _myCode;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('meet_code'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---------- açıklama ----------
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.secure.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.handshake_outlined,
                    color: AppTheme.secure, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(context.tr('meet_code_desc'),
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          // ---------- KOD ÜRET ----------
          Text(context.tr('meet_code_share'),
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          if (code == null)
            FilledButton.icon(
              onPressed: _creating ? null : _create,
              icon: const Icon(Icons.vpn_key_outlined),
              label: Text(context.tr('meet_code_create')),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  SelectableText(
                    code.pretty,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${context.tr('meet_code_expires')} ${_fmt(code.remaining)}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12.5)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code.pretty));
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.tr('copied'))));
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(context.tr('copy')),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: _cancelCode,
                        icon: const Icon(Icons.close,
                            size: 18, color: AppTheme.danger),
                        label: Text(context.tr('cancel_it'),
                            style: const TextStyle(color: AppTheme.danger)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 30),
          const Divider(color: Color(0x11FFFFFF)),
          const SizedBox(height: 18),

          // ---------- KOD GİR ----------
          Text(context.tr('meet_code_enter'),
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            controller: _inputController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
                color: AppTheme.textPrimary, letterSpacing: 3, fontSize: 18),
            decoration: const InputDecoration(
              hintText: 'ABCD-EFGH',
              hintStyle:
                  TextStyle(color: AppTheme.textSecondary, letterSpacing: 3),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _joining ? null : _join,
            icon: const Icon(Icons.login),
            label: Text(context.tr('meet_code_connect')),
          ),
          if (_joining)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(
                  backgroundColor: AppTheme.surface, color: AppTheme.primary),
            ),

          const SizedBox(height: 24),
          Text(context.tr('meet_code_note'),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11.5, height: 1.5)),
        ],
      ),
    );
  }
}
