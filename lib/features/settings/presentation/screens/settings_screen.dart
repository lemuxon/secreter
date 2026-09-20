import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/auth/current_user_provider.dart';
import '../../../../core/privacy/privacy_controller.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/screens/register_screen.dart';
import 'accounts_screen.dart';
import 'decoy_editor_screen.dart';
import '../../../onboarding/presentation/language_screen.dart';
import '../../../../core/i18n/app_localizations.dart';
import 'profile_screen.dart';
import 'wallpaper_screen.dart';
import '../../../../core/theme/chat_theme.dart';
import 'starred_screen.dart';
import '../../../security/presentation/pin_lock_screen.dart';
import '../../../../services/privacy_service.dart';
import '../../../../utils/app_theme.dart';
import '../../../../services/auth_service.dart';
import 'blocked_users_screen.dart';
import 'backup_screen.dart';
import 'recovery_key_screen.dart';
import '../../../../core/security/app_disguise_service.dart';
import '../../../../core/security/native_security_bridge.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/proje_kimligi.dart';
import '../../../../core/observability/handled_error.dart';

/// Ayarlar ekranı (yeni mimari).
/// v15'te kurulan metadata gizlilik kontrollerini UI'a bağlar.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;
  bool _deleting = false;
  late final Future<String?> _usernameFuture;
  bool _lockEnabled = false;
  bool _hasDecoy = false;
  bool _panicEnabled = false;
  // 📸 Ekran görüntüsü engeli — servis ve mantık vardı ama AYAR EKRANDA
  // HİÇ YOKTU; kullanıcı açıp kapatamıyordu.
  bool _blockScreenshot = false;

  /// 🥸 Başlatıcıda hesap makinesi olarak görünme.
  bool _disguised = false;
  int _autoLockMin = 0;

  @override
  void initState() {
    super.initState();
    // Bir kez çek (her rebuild'de yeniden çekilmesin → titreme olmasın)
    _usernameFuture = getIt<CurrentUserProvider>().currentUsername;
    _loadSecurity();
  }

  Future<void> _loadSecurity() async {
    final r = await Future.wait([
      PrivacyService.isLockEnabled(),
      PrivacyService.hasDecoyPin(),
      PrivacyService.getAutoLockMinutes(),
      PrivacyService.isPanicEnabled(),
      PrivacyService.isScreenshotBlocked(),
    ]);
    if (!mounted) return;
    setState(() {
      _lockEnabled = r[0] as bool;
      _hasDecoy = r[1] as bool;
      _autoLockMin = r[2] as int;
      _panicEnabled = r[3] as bool;
      _blockScreenshot = r[4] as bool;
    });

    // Kılık durumu SİSTEMDEN okunur (yerel bayraktan değil): kullanıcı
    // veriyi temizlese bile arayüz gerçeği gösterir.
    final disguised = await AppDisguiseService.isDisguised();
    if (!mounted) return;
    setState(() => _disguised = disguised);
  }

  /// Kılığı aç/kapat. Açarken kullanıcı ne olacağını ANLAMALI: aksi
  /// halde uygulamayı başlatıcıda bulamayıp "kayboldu" sanır.
  Future<void> _toggleDisguise(bool on) async {
    if (on) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(ctx.tr('disguise_confirm_title'),
              style:
                  const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
          content: Text(ctx.tr('disguise_confirm_body'),
              style:
                  const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.tr('cancel'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.tr('continue'),
                    style: const TextStyle(color: AppTheme.primary))),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;

    final done = await AppDisguiseService.setDisguised(on);
    if (!mounted) return;

    if (!done) {
      // SESSİZ BAŞARI YOK: kullanıcı "gizlendim" sanmamalı. Bu özellikte
      // yanlış güven, özelliğin hiç olmamasından tehlikelidir.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('disguise_failed'))),
      );
      return;
    }
    setState(() => _disguised = on);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(on ? 'disguise_on' : 'disguise_off'))),
    );
  }

  String _autoLockLabel(int m) {
    switch (m) {
      case 0:
        return context.tr('autolock_immediate');
      case 1:
        return '1 dakika sonra';
      case 5:
        return '5 dakika sonra';
      case 30:
        return '30 dakika sonra';
      default:
        return '$m dakika sonra';
    }
  }

  /// Bir işlem için mevcut PIN'i doğrula (iptal edilebilir).
  Future<bool> _verifyPinForAction() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (ctx) => PinLockScreen(
        mode: LockMode.verify,
        onSuccess: () => Navigator.pop(ctx, true),
      ),
    ));
    return ok == true;
  }

  Future<void> _toggleLock(bool enable) async {
    if (enable) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const PinLockScreen(mode: LockMode.setup),
      ));
      if (ok == true) await _loadSecurity();
    } else {
      final ok = await _verifyPinForAction();
      if (ok) {
        await PrivacyService.removePin();
        await _loadSecurity();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('app_lock_removed'))));
        }
      }
    }
  }

  Future<void> _changePin() async {
    final ok = await _verifyPinForAction();
    if (!ok || !mounted) return;
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PinLockScreen(mode: LockMode.change),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('pin_updated'))));
    }
  }

  Future<void> _setupDecoy() async {
    // Guvenlik: once gercek PIN dogrulanir
    final ok = await _verifyPinForAction();
    if (!ok || !mounted) return;
    final set = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PinLockScreen(mode: LockMode.setupDecoy),
    ));
    if (set == true) await _loadSecurity();
  }

  Future<void> _removeDecoy() async {
    final ok = await _verifyPinForAction();
    if (!ok) return;
    await PrivacyService.clearDecoyPin();
    await _loadSecurity();
  }

  Future<void> _pickAutoLock() async {
    final v = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0, 1, 5, 30]
              .map((m) => ListTile(
                    title: Text(_autoLockLabel(m),
                        style: const TextStyle(color: AppTheme.textPrimary)),
                    trailing: _autoLockMin == m
                        ? const Icon(Icons.check, color: AppTheme.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, m),
                  ))
              .toList(),
        ),
      ),
    );
    if (v == null) return;
    await PrivacyService.setAutoLockMinutes(v);
    await _loadSecurity();
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    final result = await getIt<AuthRepository>().signOut();
    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() => _signingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(failure.message))),
        );
      },
      (_) {
        // Oturumu kapat → kayıt ekranına dön (yığını temizle)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
          (route) => false,
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('remove_account_q'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          context.tr('delete_account_warn'),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('delete_account_caps'),
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    final error = await AuthService.deleteMyAccount();
    if (!mounted) return;
    if (error != null) {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final privacy = ref.watch(privacyControllerProvider);
    final privacyNotifier = ref.read(privacyControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        children: [
          // ── Hesap ──
          _sectionHeader(context.tr('sec_account')),
          FutureBuilder<String?>(
            future: _usernameFuture,
            builder: (context, snapshot) {
              final username = snapshot.data;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    (username != null && username.isNotEmpty)
                        ? username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFF04141C), fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  username != null ? '@$username' : '...',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(context.tr('anonymous_account'),
                    style: const TextStyle(color: AppTheme.textSecondary)),
              );
            },
          ),

          // 🌐 Dil — en üstte, kolay erisilir
          ListTile(
            leading: const Icon(Icons.language, color: AppTheme.primary),
            title: Text(context.tr('language'),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(context.tr('app_language'),
                style: const TextStyle(color: AppTheme.textSecondary)),
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LanguageScreen()),
            ),
          ),

          // 🔑 Kurtarma anahtarı — hesap kaybına karşı tek çare
          ListTile(
            leading:
                const Icon(Icons.vpn_key_outlined, color: AppTheme.primary),
            title: Text(context.tr('recovery_key'),
                style: const TextStyle(color: AppTheme.textPrimary)),
            subtitle: Text(context.tr('recovery_key_sub'),
                style: const TextStyle(color: AppTheme.textSecondary)),
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const RecoveryKeyScreen(),
            )),
          ),

          // 💾 Şifreli yedek
          ListTile(
            leading: const Icon(Icons.save_alt, color: AppTheme.primary),
            title: Text(context.tr('backup'),
                style: const TextStyle(color: AppTheme.textPrimary)),
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () {
              final myUid = AuthService.currentUid;
              if (myUid == null) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BackupScreen(myUid: myUid),
              ));
            },
          ),

          // 🛡️ Engellenen kullanıcılar
          ListTile(
            leading: const Icon(Icons.block, color: AppTheme.primary),
            title: Text(context.tr('blocked_users'),
                style: const TextStyle(color: AppTheme.textPrimary)),
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () {
              final myUid = AuthService.currentUid;
              if (myUid == null) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BlockedUsersScreen(myUid: myUid),
              ));
            },
          ),

          ListTile(
            // 👤 Kendi profil fotoğrafın — ikon yerine gerçek avatar.
            // Fotoğraf yoksa baş harfe düşer.
            leading: Builder(builder: (context) {
              final uid = AuthService.currentUid;
              if (uid == null) {
                return const Icon(Icons.person_outline,
                    color: AppTheme.primary);
              }
              return UserAvatar(uid: uid, fallbackLetter: '?', radius: 18);
            }),
            title: Text(context.tr('my_profile'),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(context.tr('photo_about'),
                style: const TextStyle(color: AppTheme.textSecondary)),
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.switch_account, color: AppTheme.primary),
            title: Text(context.tr('my_accounts'),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(context.tr('account_switch'),
                style: const TextStyle(color: AppTheme.textSecondary)),
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountsScreen()),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppTheme.danger),
            title: Text(context.tr('remove_account'),
                style: const TextStyle(
                    color: AppTheme.danger, fontWeight: FontWeight.w600)),
            subtitle: Text(context.tr('remove_account_sub'),
                style: const TextStyle(color: AppTheme.textSecondary)),
            trailing: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.danger),
                  )
                : const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
            onTap: _deleting ? null : _confirmDeleteAccount,
          ),

          // ── Görünüm ──
          ListTile(
            leading:
                const Icon(Icons.star_outline, color: AppTheme.textPrimary),
            title: Text(context.tr('starred_msgs'),
                style: const TextStyle(color: AppTheme.textPrimary)),
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () {
              final uid = getIt<CurrentUserProvider>().currentUid;
              if (uid == null) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => StarredScreen(myUid: uid),
              ));
            },
          ),
          _sectionHeader(context.tr('sec_security')),
          SwitchListTile(
            secondary:
                const Icon(Icons.lock_outline, color: AppTheme.textPrimary),
            title: Text(context.tr('app_lock_title'),
                style: const TextStyle(color: AppTheme.textPrimary)),
            subtitle: Text(context.tr('app_lock_pin'),
                style: const TextStyle(color: AppTheme.textSecondary)),
            activeThumbColor: AppTheme.primary,
            value: _lockEnabled,
            onChanged: (v) => _toggleLock(v),
          ),
          if (_lockEnabled) ...[
            ListTile(
              leading: const Icon(Icons.password, color: AppTheme.textPrimary),
              title: Text(context.tr('change_pin'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: _changePin,
            ),
            ListTile(
              leading: const Icon(Icons.theater_comedy_outlined,
                  color: AppTheme.textPrimary),
              title: Text(
                  _hasDecoy ? 'Sahte PIN (aktif)' : context.tr('decoy_pin'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(context.tr('decoy_pin_sub'),
                  style: const TextStyle(color: AppTheme.textSecondary)),
              trailing: _hasDecoy
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.danger),
                      tooltip: context.tr('remove_pin'),
                      onPressed: _removeDecoy,
                    )
                  : null,
              onTap: _setupDecoy,
            ),
            // 🎭 Sahte sohbet icerigi (inandiricilik)
            ListTile(
              leading:
                  const Icon(Icons.forum_outlined, color: AppTheme.textPrimary),
              title: Text(context.tr('decoy_edit'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(context.tr('decoy_edit_sub'),
                  style: const TextStyle(color: AppTheme.textSecondary)),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DecoyEditorScreen())),
            ),
            // 🎭 Panik jesti
            SwitchListTile(
              secondary: const Icon(Icons.touch_app_outlined,
                  color: AppTheme.textPrimary),
              title: Text(context.tr('panic_gesture'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(context.tr('panic_gesture_sub'),
                  style: const TextStyle(color: AppTheme.textSecondary)),
              activeThumbColor: AppTheme.primary,
              value: _panicEnabled,
              onChanged: (v) async {
                await PrivacyService.setPanicEnabled(v);
                setState(() => _panicEnabled = v);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.timer_outlined, color: AppTheme.textPrimary),
              title: Text(context.tr('auto_lock'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(_autoLockLabel(_autoLockMin),
                  style: const TextStyle(color: AppTheme.textSecondary)),
              onTap: _pickAutoLock,
            ),
          ],
          _sectionHeader(context.tr('sec_appearance')),
          ListTile(
            leading:
                const Icon(Icons.palette_outlined, color: AppTheme.textPrimary),
            title: Text(context.tr('chat_color'),
                style: const TextStyle(color: AppTheme.textPrimary)),
            subtitle: Text(context.tr('bubble_color_sub'),
                style: const TextStyle(color: AppTheme.textSecondary)),
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () => showBubbleThemePicker(context, ref),
          ),
          ListTile(
            leading:
                const Icon(Icons.wallpaper_outlined, color: AppTheme.primary),
            title: Text(context.tr('chat_wallpaper'),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(context.tr('wallpaper_sub'),
                style: const TextStyle(color: AppTheme.textSecondary)),
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WallpaperScreen()),
            ),
          ),

          // ── Gizlilik ──
          _sectionHeader(context.tr('sec_privacy')),
          // 📸 Ekran görüntüsü engeli
          _switch(
            title: context.tr('block_screenshot'),
            subtitle: context.tr('block_screenshot_sub'),
            value: _blockScreenshot,
            onChanged: (v) async {
              setState(() => _blockScreenshot = v);
              await PrivacyService.setScreenshotBlocked(v);
              // Tercihi ANINDA uygula (uygulama yeniden başlatılmadan)
              if (v) {
                await NativeSecurityBridge.acquire('user_pref');
              } else {
                await NativeSecurityBridge.release('user_pref');
              }
            },
          ),
          // 🥸 UYGULAMA KILIĞI — sahte PIN'in tamamlayıcısı.
          // Sahte PIN telefon açıldıktan SONRA korur; kılık uygulamanın
          // VARLIĞINI gizler.
          _switch(
            title: context.tr('disguise_title'),
            subtitle: context.tr('disguise_sub'),
            value: _disguised,
            onChanged: _toggleDisguise,
          ),
          _switch(
            title: context.tr('read_receipts'),
            subtitle: context.tr('read_receipts_sub'),
            value: privacy.sendReadReceipts,
            onChanged: privacyNotifier.setReadReceipts,
          ),
          _switch(
            title: context.tr('typing_indicator'),
            subtitle: context.tr('typing_indicator_sub'),
            value: privacy.sendTypingIndicator,
            onChanged: privacyNotifier.setTypingIndicator,
          ),
          _switch(
            title: context.tr('online_status'),
            subtitle: context.tr('online_status_sub'),
            value: privacy.sharePresence,
            onChanged: privacyNotifier.setPresence,
          ),
          _switch(
            title: context.tr('coarse_time'),
            subtitle: context.tr('coarse_time_sub'),
            value: privacy.coarseTimestamps,
            onChanged: privacyNotifier.setCoarseTimestamps,
          ),

          // ── Telemetri ──
          _sectionHeader(context.tr('sec_telemetry')),
          _switch(
            title: context.tr('crash_report'),
            subtitle: context.tr('crash_report_sub'),
            value: privacy.crashReportingConsent,
            onChanged: privacyNotifier.setCrashReportingConsent,
          ),

          // ── 📖 HAKKINDA ──
          // ⚠️ Bu bölüm depo adresi BOŞKEN hiç çizilmez. "Açık kaynak"
          // demek, kodun gidip görülebildiği anlamına gelir; yayımlamadan
          // önce söylemek yanlış beyan olur (bkz. `proje_kimligi.dart`).
          if (acikKaynakGosterilebilir) ...[
            _sectionHeader(context.tr('sec_about')),
            ListTile(
              leading: const Icon(Icons.code_rounded, color: AppTheme.secure),
              title: Text(context.tr('open_source'),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(
                context.tr('open_source_sub').replaceAll('{lisans}', lisansAdi),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.open_in_new,
                  size: 18, color: AppTheme.textSecondary),
              onTap: _depoyuAc,
            ),
          ],

          const SizedBox(height: Spacing.lg),
          // ── Maksimum gizlilik ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.shield, color: AppTheme.secure),
                label: Text(context.tr('apply_max_privacy'),
                    style: const TextStyle(color: AppTheme.secure)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.secure),
                ),
                onPressed: () async {
                  await privacyNotifier.applyMaxPrivacy();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(context.tr('apply_max_privacy_sub'))),
                    );
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: Spacing.xl),
          // ── Çıkış ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _signingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.logout, color: Colors.white),
                label: Text(
                    _signingOut
                        ? context.tr('logging_out')
                        : context.tr('logout'),
                    style: const TextStyle(color: Colors.white)),
                onPressed: _signingOut ? null : _confirmSignOut,
              ),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
        ],
      ),
    );
  }

  /// Depoyu dış tarayıcıda aç. Açılamazsa sessiz kalmaz — yutulan hata
  /// bu projede tekrar eden kök sebep (§4ah).
  Future<void> _depoyuAc() async {
    try {
      final acildi = await launchUrl(
        Uri.parse(depoAdresi),
        mode: LaunchMode.externalApplication,
      );
      if (!acildi) throw Exception('launchUrl false döndü: $depoAdresi');
    } catch (e, st) {
      if (!mounted) return;
      reportHandled('Depo adresi açılamadı', e, stack: st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('err_unexpected'))),
      );
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('logout'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(context.tr('logout_confirm'),
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _signOut();
            },
            child: Text(context.tr('logout')),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.xl, Spacing.xl, Spacing.xl, Spacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Widget _switch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      activeThumbColor: AppTheme.primary,
      title: Text(title,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      onChanged: onChanged,
    );
  }
}
