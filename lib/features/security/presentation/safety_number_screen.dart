import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../services/e2ee_session_service.dart';
import '../../../utils/app_theme.dart';

/// 🔐 GÜVENLİK NUMARASI EKRANI
///
/// E2EE'nin araya girmeye (MITM) karşı tek gerçek güvencesi, iki tarafın
/// kimlik anahtarlarını BAŞKA bir kanaldan karşılaştırmasıdır. Sunucudan
/// gelen imza bunu sağlamaz: araya giren taraf kendi anahtar çiftiyle
/// kendi geçerli imzasını üretebilir. Bu yüzden numaranın yüz yüze (ya da
/// güvenilen başka bir kanaldan) karşılaştırılması gerekir.
///
/// Numara iki tarafta AYNI çıkar: iki kimlik anahtarı sıralanıp birlikte
/// özetlenir (bkz. [E2EESessionService.safetyNumber]).
///
/// ⚠️ UYGULAMADA QR OKUYUCU YOKTUR — yeni bir kamera/tarayıcı bağımlılığı
/// APK boyutunu ve saldırı yüzeyini büyütürdü. QR bu yüzden KARŞILAŞTIRMA
/// içindir: iki cihazdaki kod aynı görünmelidir (ya da herhangi bir harici
/// okuyucuyla okunup metin karşılaştırılır). Asıl yol 30 haneli numaradır
/// ve arayüz bunu gizlemez.
class SafetyNumberScreen extends StatefulWidget {
  final String chatId;

  /// Başlıkta gösterilecek ad — yalnızca metin, güvenlik etkisi yok.
  final String peerName;

  const SafetyNumberScreen({
    super.key,
    required this.chatId,
    required this.peerName,
  });

  @override
  State<SafetyNumberScreen> createState() => _SafetyNumberScreenState();
}

class _SafetyNumberScreenState extends State<SafetyNumberScreen> {
  SafetyInfo? _info;
  bool _loading = true;

  /// Anahtar yazılırken çift dokunuşu engelle.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await E2EESessionService.safetyInfo(widget.chatId);
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  /// QR yükü: iki cihazda BAYT BAYT aynı olmalı. Ham anahtarlar değil,
  /// ekranda gösterilen numaranın kendisi (boşluksuz) kodlanır — kod ile
  /// rakamlar aynı şeyi temsil etmelidir.
  String _qrPayload(String number) =>
      'SECRETER-SN:${number.replaceAll(' ', '')}';

  Future<void> _setVerified(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);

    final ok = await E2EESessionService.setUserVerified(widget.chatId, value);
    // Kullanıcı yeniden doğruladıysa "anahtar değişti" uyarısı da düşer;
    // uyarının amacı zaten yeniden karşılaştırmaya zorlamaktı.
    if (ok && value) {
      await E2EESessionService.acknowledgeIdentityChange(widget.chatId);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _acknowledgeChange() async {
    await E2EESessionService.acknowledgeIdentityChange(widget.chatId);
    await _load();
  }

  Future<void> _copy(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('safety_copied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('safety_number')),
            if (widget.peerName.isNotEmpty)
              Text(
                widget.peerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Sohbet ekranı rozetini tazeleyebilsin diye son durum döner.
          onPressed: () =>
              Navigator.of(context).pop(info?.userVerified ?? false),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : (info == null || !info.hasSession)
              ? _buildNoSession(context)
              : _buildContent(context, info),
    );
  }

  // ── Şifreli oturum henüz yok ──
  Widget _buildNoSession(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(
            borderColor: AppTheme.textSecondary.withValues(alpha: 0.25),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_open_outlined,
                    color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('safety_no_session'),
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  // ── Numara + QR + doğrulama ──
  Widget _buildContent(BuildContext context, SafetyInfo info) {
    final number = info.number!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (info.identityChanged) ...[
          _buildChangedWarning(context),
          const SizedBox(height: 18),
        ],

        // ---------- QR ----------
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: QrImageView(
              data: _qrPayload(number),
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              errorStateBuilder: (ctx, err) => SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: Text(
                    ctx.tr('qr_failed'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('safety_qr_hint'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 20),

        // ---------- NUMARA ----------
        _card(child: _buildNumberGrid(number)),
        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _copy(number),
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: Text(context.tr('safety_copy')),
          ),
        ),
        const SizedBox(height: 6),

        // ---------- AÇIKLAMA ----------
        Text(
          context.tr('safety_number_desc'),
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 13, height: 1.55),
        ),
        const SizedBox(height: 14),

        // Numarayı BU sohbetten göndermek doğrulama SAYILMAZ: araya giren
        // taraf o mesajı da değiştirebilir. Bu tuzağı açıkça yazmak gerekir.
        _card(
          borderColor: AppTheme.danger.withValues(alpha: 0.30),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppTheme.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('safety_dont_send_here'),
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ---------- DOĞRULAMA ANAHTARI ----------
        _card(
          borderColor: info.userVerified
              ? AppTheme.secure.withValues(alpha: 0.45)
              : AppTheme.textSecondary.withValues(alpha: 0.20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: info.userVerified,
                onChanged: _busy ? null : _setVerified,
                activeThumbColor: AppTheme.secure,
                title: Text(
                  info.userVerified
                      ? context.tr('safety_verified')
                      : context.tr('safety_mark_verified'),
                  style: TextStyle(
                    color: info.userVerified
                        ? AppTheme.secure
                        : AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                secondary: Icon(
                  info.userVerified
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
                  color: info.userVerified
                      ? AppTheme.secure
                      : AppTheme.textSecondary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.tr('safety_verify_hint'),
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Kimlik anahtarı değişti uyarısı ──
  Widget _buildChangedWarning(BuildContext context) => _card(
        borderColor: AppTheme.danger.withValues(alpha: 0.55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gpp_maybe_rounded,
                    color: AppTheme.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('safety_changed_title'),
                    style: const TextStyle(
                        color: AppTheme.danger,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('safety_changed_desc'),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12.5, height: 1.5),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _acknowledgeChange,
                child: Text(context.tr('safety_changed_ack')),
              ),
            ),
          ],
        ),
      );

  /// Numarayı 5'li gruplar hâlinde, iki sütunlu bir ızgarada gösterir —
  /// 30 haneyi tek satır olarak karşılaştırmak hataya çok açıktır.
  Widget _buildNumberGrid(String number) {
    final groups = number.split(' ').where((g) => g.isNotEmpty).toList();
    final rows = <Widget>[];

    for (var i = 0; i < groups.length; i += 2) {
      final pair = groups.skip(i).take(2).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final g in pair)
                Text(
                  g,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    letterSpacing: 2.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              // Tek kalan grup hizayı bozmasın.
              if (pair.length == 1) const SizedBox(width: 96),
            ],
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _card({required Widget child, Color? borderColor}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: borderColor == null ? null : Border.all(color: borderColor),
        ),
        child: child,
      );
}
