import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../services/backup_service.dart';
import '../../../../utils/app_theme.dart';
import 'backup_viewer_screen.dart';

/// 💾 Şifreli yedek — oluştur ve aç.
class BackupScreen extends ConsumerStatefulWidget {
  final String myUid;
  const BackupScreen({super.key, required this.myUid});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  double _progress = 0;
  String _label = '';

  Future<String?> _askPassword({required bool creating}) async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('backup_password'),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (creating)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(context.tr('backup_password_warn'),
                    style: const TextStyle(
                        color: AppTheme.danger, fontSize: 12.5)),
              ),
            TextField(
              controller: c1,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration:
                  InputDecoration(hintText: context.tr('backup_password')),
            ),
            if (creating)
              TextField(
                controller: c2,
                obscureText: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                    hintText: context.tr('backup_password_again')),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('cancel'))),
          TextButton(
            onPressed: () {
              final p = c1.text;
              if (p.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(context.tr('backup_password_short'))));
                return;
              }
              if (creating && p != c2.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(context.tr('pwd_mismatch'))));
                return;
              }
              Navigator.pop(ctx, p);
            },
            child: Text(context.tr('ok'),
                style: const TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
    return res;
  }

  Future<void> _create() async {
    final pw = await _askPassword(creating: true);
    if (pw == null || !mounted) return;

    setState(() {
      _busy = true;
      _progress = 0;
      _label = '';
    });
    try {
      final dir = await getTemporaryDirectory();
      final file = await BackupService.create(
        password: pw,
        myUid: widget.myUid,
        targetDir: dir,
        onProgress: (p, l) {
          if (mounted) {
            setState(() {
              _progress = p;
              _label = l;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await Share.shareXFiles([XFile(file.path)],
          text: context.tr('backup_share_text'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('err_unexpected'))));
    }
  }

  Future<void> _open() async {
    final picked = await openFile();
    if (picked == null || !mounted) return;

    // 1) DOSYAYI XFile ILE OKU.
    //    KOK NEDEN: Android'de secici content:// URI dondurur; bunu
    //    File(path) ile acmak FileSystemException veriyordu. XFile kendi
    //    okuma API'siyle her iki durumu da dogru yonetir.
    String raw;
    try {
      raw = await picked.readAsString();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('backup_bad_file'))));
      return;
    }

    // 2) PAROLADAN ONCE dogrula — yanlis dosya icin bosuna parola sorma.
    Map<String, dynamic> env;
    try {
      env = BackupService.parseEnvelope(raw);
    } on BackupFormatError {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('backup_bad_file'))));
      return;
    }

    // 3) Simdi parola iste
    if (!mounted) return;
    final pw = await _askPassword(creating: false);
    if (pw == null || !mounted) return;

    setState(() => _busy = true);
    try {
      // Anahtar türetme artık arka plan isolate'inde (150k tur PBKDF2)
      // olduğu için asenkron — UI donmaz.
      final data = await BackupService.decryptEnvelope(env, pw);
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BackupViewerScreen(data: data, myUid: widget.myUid),
      ));
    } on BackupPasswordError {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('backup_wrong_password'))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('backup_wrong_password'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('backup'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
                const Icon(Icons.lock_outline,
                    color: AppTheme.secure, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(context.tr('backup_desc'),
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (_busy) ...[
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              backgroundColor: AppTheme.surface,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 10),
            Text(_label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 22),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.save_alt),
            label: Text(context.tr('backup_create')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _open,
            icon: const Icon(Icons.folder_open),
            label: Text(context.tr('backup_open')),
          ),
          const SizedBox(height: 8),
          Text(context.tr('backup_pick_hint'),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11.5)),
          const SizedBox(height: 26),
          Text(context.tr('backup_note'),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}
