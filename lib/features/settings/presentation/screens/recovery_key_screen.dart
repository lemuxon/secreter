import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../services/recovery_key_service.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/security/native_security_bridge.dart';
import '../../../../services/privacy_service.dart';

/// 🔑 KURTARMA ANAHTARI EKRANI
///
/// Anahtar hesabın kendisidir: gösterirken şifre gibi davranılır.
/// Kayıt sonrası bir kez ([firstTime] true) ve Ayarlar'dan her zaman
/// açılabilir.
class RecoveryKeyScreen extends ConsumerStatefulWidget {
  final bool firstTime;
  const RecoveryKeyScreen({super.key, this.firstTime = false});

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  String? _key;
  bool _loading = true;
  bool _revealed = false;
  bool _saved = false;

  /// QR görünümü açık mı? (metin ↔ QR geçişi)
  bool _showQr = false;

  @override
  void initState() {
    super.initState();

    // 📸 EKRAN GÖRÜNTÜSÜ İZNİ — bu ekrana ÖZEL
    //
    // Kullanıcının kurtarma anahtarını (özellikle QR'ı) ekran görüntüsü
    // olarak saklaması GEREKİYOR — anahtarın tek yedeği bu. Genel
    // "ekran görüntüsünü engelle" ayarı açıkken bu imkânsızdı.
    //
    // Bu ekranda koruma geçici olarak kaldırılır, çıkışta geri gelir.
    // Güvenlik açısından makul: anahtar zaten kullanıcının kendi
    // sorumluluğunda ve ekran kilidi arkasında.
    NativeSecurityBridge.release('user_pref');
    NativeSecurityBridge.release('recovery_screen');

    // Anahtar artık PAROLA ile şifreleniyor; parola alınana kadar üretilemez.
    // (Eskiden düz base64'tü ve ekran açılır açılmaz gösterilebiliyordu —
    // yani QR'ı gören/fotoğraflayan herkes hesabı devralabiliyordu.)
    _loading = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPassphrase());
  }

  /// Parola sor ve şifreli kurtarma anahtarını üret.
  Future<void> _askPassphrase() async {
    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: !widget.firstTime,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(context.tr('recovery_pass_title'),
              style:
                  const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('recovery_pass_why'),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12.5)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  obscureText: true,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: context.tr('recovery_pass_label'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: context.tr('recovery_pass_confirm'),
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!widget.firstTime)
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.tr('cancel'))),
            TextButton(
              onPressed: () {
                if (ctrl.text.length < 8) {
                  setLocal(() => error = context.tr('recovery_pass_too_short'));
                  return;
                }
                if (ctrl.text != confirmCtrl.text) {
                  setLocal(() => error = context.tr('recovery_pass_mismatch'));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(context.tr('continue_word'),
                  style: const TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    final k = await RecoveryKeyService.forCurrentAccount(ctrl.text);
    if (!mounted) return;
    setState(() {
      _key = k;
      _loading = false;
    });
  }

  @override
  void dispose() {
    // Ekrandan çıkınca kullanıcının GENEL tercihini geri yükle.
    PrivacyService.isScreenshotBlocked().then((blocked) {
      if (blocked) NativeSecurityBridge.acquire('user_pref');
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // İLK GÖSTERİM: ekrandan çıkış YOK.
    //
    // `automaticallyImplyLeading: false` yalnızca üstteki geri OKUNU
    // gizler — Android'in sistem geri tuşu/jesti ekranı yine kapatır.
    // Bu yüzden PopScope ile sistem geri hareketi de engellenir; tek
    // çıkış "kaydettim" onayından geçer.
    return PopScope(
      canPop: !widget.firstTime,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(context.tr('recovery_key')),
          automaticallyImplyLeading: !widget.firstTime,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ---------- NEDEN ----------
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppTheme.danger.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(context.tr('recovery_key_why'),
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  if (_key == null)
                    // Eski sürüm hesabı: parola bağlanmamış
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(context.tr('recovery_key_unavailable'),
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.5)),
                    )
                  else ...[
                    // ---------- ANAHTAR ----------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.35)),
                      ),
                      child: _revealed
                          ? (_showQr
                              // 📱 QR GÖRÜNÜMÜ
                              //
                              // Anahtar ~190 karakter — elle yazmak zor.
                              // QR olarak gösterip kullanıcının ekran
                              // görüntüsü almasını sağlıyoruz; yeni cihazda
                              // taratıp metni yapıştırmak yeterli.
                              // Beyaz zemin ŞART: koyu arka planda QR
                              // okuyucular kodu göremez.
                              ? Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: QrImageView(
                                        data: _key!,
                                        version: QrVersions.auto,
                                        size: 230,
                                        backgroundColor: Colors.white,
                                        errorStateBuilder: (ctx, err) =>
                                            SizedBox(
                                          width: 230,
                                          height: 230,
                                          child: Center(
                                            child: Text(
                                              context.tr('qr_failed'),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  color: Colors.black54,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(context.tr('qr_hint'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12)),
                                  ],
                                )
                              : SelectableText(
                                  _key!,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 12.5,
                                    height: 1.7,
                                    letterSpacing: 0.6,
                                    fontFamily: 'monospace',
                                  ),
                                ))
                          : Column(
                              children: [
                                const Icon(Icons.lock_outline,
                                    color: AppTheme.textSecondary, size: 28),
                                const SizedBox(height: 10),
                                Text(context.tr('recovery_key_hidden'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12.5)),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      setState(() => _revealed = true),
                                  icon: const Icon(Icons.visibility_outlined,
                                      size: 18),
                                  label: Text(context.tr('recovery_key_show')),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),

                    if (_revealed) ...[
                      // Metin ↔ QR geçişi
                      Center(
                        child: TextButton.icon(
                          onPressed: () => setState(() => _showQr = !_showQr),
                          icon: Icon(
                              _showQr ? Icons.text_fields : Icons.qr_code_2,
                              size: 18,
                              color: AppTheme.primary),
                          label: Text(
                              _showQr
                                  ? context.tr('show_as_text')
                                  : context.tr('show_as_qr'),
                              style: const TextStyle(color: AppTheme.primary)),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _key!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(context.tr('copied'))));
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: Text(context.tr('copy')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Share.share(_key!,
                                  subject: context.tr('recovery_key')),
                              icon: const Icon(Icons.ios_share, size: 18),
                              label: Text(context.tr('share')),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 22),
                    Text(context.tr('recovery_key_where'),
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                            height: 1.6)),
                  ],

                  // ---------- İLK GÖSTERİM ONAYI ----------
                  if (widget.firstTime && _key != null) ...[
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      value: _saved,
                      onChanged: (v) => setState(() => _saved = v ?? false),
                      activeColor: AppTheme.primary,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(context.tr('recovery_key_confirm'),
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 13.5)),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed:
                          _saved ? () => Navigator.of(context).pop() : null,
                      child: Text(context.tr('continue')),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
