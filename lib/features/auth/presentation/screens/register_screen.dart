import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../../../../core/auth/current_user_provider.dart';
import '../../../conversations/presentation/screens/home_shell.dart';
import '../../../../core/di/injection.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../services/multi_account_service.dart';
import '../../../../services/auth_service.dart';
import '../../../conversations/presentation/providers/conversations_notifier.dart';
import '../../../story/presentation/providers/story_notifier.dart';
import '../../../messaging/presentation/providers/messaging_notifier.dart';
import '../../../../services/recovery_key_service.dart';
import '../../../settings/presentation/screens/recovery_key_screen.dart';

/// Kayıt ekranı (yeni mimari, provider-tabanlı).
/// Başarılı kayıtta yeni ConversationsScreen'e geçer.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // KILITLENME DUZELTMESI: "hesap ekle" akisinda cikis yapiliyor ama geri
  // donus yolu yoktu — kullanici zorla ikinci hesap acmak zorunda kaliyordu.
  // Cihazda kayitli hesap varsa vazgecme yolu gosterilir.
  List<SavedAccount> _saved = const [];
  bool _switching = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    ref.read(authControllerProvider.notifier).checkUsername(val);
  }

  Future<void> _register() async {
    await ref
        .read(authControllerProvider.notifier)
        .register(_controller.text.trim());
  }

  @override
  void initState() {
    super.initState();
    MultiAccountService.getAccounts().then((list) {
      if (mounted) setState(() => _saved = list);
    });
  }

  /// Kayıtlı hesaba geri dön (yeni hesap açmaktan vazgeçme yolu).
  Future<void> _backToAccount(SavedAccount account) async {
    setState(() => _switching = true);
    final error = await AuthService.switchAccount(account);
    if (!mounted) return;
    setState(() => _switching = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    // 🐞 BURADA HIC GECERSIZLESTIRME YOKTU (§4as). Hesap degisiminde
    // onceki hesabin Firestore dinleyicileri `permission-denied` alip
    // KALICI olarak oluyor; yeniden kurulmazlarsa canli akis o oturumda
    // bir daha calismiyor. accounts_screen ayni ucluyu zaten dusuruyordu,
    // bu yol atlanmisti.
    ref.invalidate(conversationsNotifierProvider);
    ref.invalidate(storyNotifierProvider);
    ref.invalidate(messagingNotifierProvider);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeShell(myUid: account.uid)),
      (route) => false,
    );
  }

  /// Kayıtlı hesap listesi — hangisine döneceğini seçtirir.
  Future<void> _showSavedAccounts() async {
    final acc = await showModalBottomSheet<SavedAccount>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
              child: Row(
                children: [
                  const Icon(Icons.switch_account,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(context.tr('back_to_account'),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            ..._saved.map((a) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: Text(
                        a.username.isEmpty ? '?' : a.username[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFF04141C))),
                  ),
                  title: Text('@${a.username}',
                      style: const TextStyle(color: AppTheme.textPrimary)),
                  onTap: () => Navigator.pop(ctx, a),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (acc != null) await _backToAccount(acc);
  }

  /// Kayıt sonrası akış: kurtarma anahtarı ekranı → ana ekran.
  ///
  /// Anahtar üretilemezse (eski sürüm hesabı) kullanıcıyı bekletmeyiz,
  /// doğrudan ana ekrana geçilir — engel olmak yerine Ayarlar'dan
  /// erişilebilir kalır.
  Future<void> _showRecoveryThenHome(String uid) async {
    // Anahtar ARTIK parola ile şifreleniyor, bu yüzden burada önceden
    // üretilemez — parolayı kullanıcı kurtarma ekranında belirler.
    // (Eskiden anahtar düz base64'tü ve önizleme için burada üretilebiliyordu.)
    if (mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const RecoveryKeyScreen(firstTime: true),
      ));
    }
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeShell(myUid: uid)),
      (route) => false,
    );
  }

  /// 🔑 Kurtarma anahtarıyla hesabı geri getir.
  Future<void> _restoreWithKey() async {
    final keyCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('recovery_key_restore'),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('recovery_key_paste'),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 10),
              TextField(
                controller: keyCtrl,
                maxLines: 4,
                minLines: 2,
                autofocus: true,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12.5),
                decoration: const InputDecoration(hintText: 'SKP2 ...'),
              ),
              const SizedBox(height: 14),
              // Anahtar artık PAROLA ile şifreli: parola olmadan çözülemez.
              TextField(
                controller: passCtrl,
                obscureText: true,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: context.tr('recovery_pass_label'),
                  helperText: context.tr('recovery_pass_hint'),
                  helperMaxLines: 2,
                ),
              ),
            ],
          ),
        ),
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
    if (go != true || !mounted) return;

    setState(() => _switching = true);
    final result =
        await RecoveryKeyService.restore(keyCtrl.text, passCtrl.text);
    if (!mounted) return;
    setState(() => _switching = false);

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(result.error ?? 'recovery_failed'))),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeShell(myUid: result.uid!)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    // Başarılı kayıtta: ÖNCE kurtarma anahtarı, SONRA sohbet listesi.
    //
    // NEDEN ZORUNLU BİR ADIM: Bu uygulamada telefon numarası/e-posta yok,
    // yani hesabın kimliği yalnızca cihazda durur. Kullanıcı bu anahtarı
    // kaydetmezse telefonunu kaybettiğinde hesabı KALICI olarak gider ve
    // telafisi olmaz. Bu yüzden Ayarlar'a gömmek yetmez — kayıt anında
    // gösterilir ve "kaydettim" onayı alınmadan geçilemez.
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.registered && !(prev?.registered ?? false)) {
        final uid = getIt<CurrentUserProvider>().currentUid;
        if (uid == null) return;
        _showRecoveryThenHome(uid);
      }
    });

    final canSubmit = !state.registering && state.usernameAvailable == true;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kayitli hesap varsa: vazgecip geri donme yolu
              if (_saved.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextButton.icon(
                      onPressed: _switching ? null : _showSavedAccounts,
                      icon: const Icon(Icons.arrow_back,
                          size: 18, color: AppTheme.primary),
                      label: Text(context.tr('back_to_account'),
                          style: const TextStyle(color: AppTheme.primary)),
                    ),
                  ),
                ),
              // 🔑 Kurtarma anahtarıyla giriş — her zaman görünür
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _switching ? null : _restoreWithKey,
                  icon: const Icon(Icons.vpn_key_outlined,
                      size: 18, color: AppTheme.primary),
                  label: Text(context.tr('recovery_key_restore'),
                      style: const TextStyle(color: AppTheme.primary)),
                ),
              ),
              SizedBox(height: _saved.isEmpty ? 30 : 12),
              const Icon(Icons.shield_rounded,
                  color: AppTheme.primary, size: 48),
              const SizedBox(height: Spacing.xl),
              Text(context.tr('reg_username_q'),
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: Spacing.sm),
              Text(context.tr('reg_privacy'),
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: Spacing.xxl),
              TextField(
                controller: _controller,
                autofocus: true,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'kullanici_adi',
                  prefixText: '@  ',
                  prefixStyle: const TextStyle(color: AppTheme.primary),
                  suffixIcon: _buildSuffix(state),
                ),
                onChanged: _onChanged,
              ),
              const SizedBox(height: Spacing.sm),
              Text(context.tr('reg_rules'),
                  style: Theme.of(context).textTheme.labelSmall),
              if (state.error != null) ...[
                const SizedBox(height: Spacing.sm),
                Text(context.tr(state.error!),
                    style:
                        const TextStyle(color: AppTheme.danger, fontSize: 13)),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canSubmit ? _register : null,
                  child: state.registering
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Color(0xFF04141C), strokeWidth: 2),
                        )
                      : Text(context.tr('reg_start')),
                ),
              ),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildSuffix(AuthState state) {
    if (state.checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.primary),
        ),
      );
    }
    if (state.usernameAvailable == null) return null;
    return Icon(
      state.usernameAvailable! ? Icons.check_circle : Icons.cancel,
      color: state.usernameAvailable! ? AppTheme.online : AppTheme.danger,
    );
  }
}
