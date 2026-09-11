import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../conversations/presentation/providers/conversations_notifier.dart';
import '../../../story/presentation/providers/story_notifier.dart';
import '../../../messaging/presentation/providers/messaging_notifier.dart';
import '../../../../services/multi_account_service.dart';
import '../../../../services/auth_service.dart';
import '../../../conversations/presentation/screens/home_shell.dart';
import '../../../../utils/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../auth/presentation/screens/register_screen.dart';

/// Cihazda kayitli hesaplari listeler; gecis ve silme saglar.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  List<SavedAccount> _accounts = [];
  String? _activeUid;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // TAKILMA DÜZELTMESİ: Eski sürüm hesabını yükseltme adımı bir AĞ
    // çağrısı yapıyor (linkWithCredential) ve zaman aşımı yoktu. Bağlantı
    // yavaşsa ekran sonsuza kadar "yükleniyor" durumunda kalıyordu.
    //
    // Artık: yükseltme en fazla 8 sn bekletir, başarısız olsa bile liste
    // yine gösterilir. Yükseltme yalnızca ESKİ hesaplar için gerekli;
    // yeni hesaplarda zaten anında döner.
    try {
      await AuthService.upgradeCurrentAccountIfNeeded()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Hesap yükseltme atlandı: $e');
    }

    // Hesap listesi YEREL depodan okunur — hızlıdır, ağ gerektirmez.
    List<SavedAccount> accounts = const [];
    String? active;
    try {
      accounts = await MultiAccountService.getAccounts();
      active = await MultiAccountService.getActiveAccountUid();
    } catch (e) {
      debugPrint('Hesap listesi okunamadı: $e');
    }

    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _activeUid = active;
      _loading = false;
    });
  }

  /// ➕ Yeni hesap ekle.
  ///
  /// Mevcut hesap cihazdaki kayıtlı listede KALIR (signOut yalnızca aktif
  /// oturumu kapatır, kayıtları silmez). Kayıt ekranı açılır; yeni hesap
  /// oluşturulunca o da listeye eklenir ve aralarında geçiş yapılabilir.
  Future<void> _addAccount() async {
    // SINIR: en fazla 3 hesap. Aşılırsa açıklayıcı uyarı gösterilir.
    if (!await MultiAccountService.canAddAccount()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${context.tr('max_accounts_reached')} (${MultiAccountService.maxAccounts})'),
      ));
      return;
    }
    // Yukarıdaki erken çıkışta mounted kontrolü vardı ama DÜŞEN yolda
    // yoktu: `canAddAccount()` beklenirken ekran kapanmışsa context
    // kullanmak istisna fırlatır.
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('add_account'),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Text(context.tr('add_account_desc'),
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('continue'),
                  style: const TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await AuthService.signOut();
    } catch (e) {
      debugPrint('Hesap ekleme çıkışı: $e');
    }
    if (!mounted) return;
    // Kayıt ekranını KÖKE al: geri tuşuyla yarım oturuma dönülmesin.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
      (route) => false,
    );
  }

  Future<void> _switchTo(SavedAccount account) async {
    if (account.uid == _activeUid) return;
    setState(() => _busy = true);
    final error = await AuthService.switchAccount(account);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error))),
      );
      return;
    }
    // GIZLILIK DUZELTMESI: eski hesabin bellek durumunu (sohbetler,
    // hikayeler, acik mesaj ekranlari) TAMAMEN sifirla — yoksa gecis
    // animasyonu sirasinda provider'lar hic bosa dusmedigi icin eski
    // hesabin verileri yeni hesapta gorunuyordu.
    ref.invalidate(conversationsNotifierProvider);
    ref.invalidate(storyNotifierProvider);
    // 🐞 messagingNotifierProvider DA GECERSIZLESTIRILMELI (§4as).
    //
    // Eski yorum "bilerek invalidate edilmiyor, hayalet yeniden kurulum
    // rozeti sifirliyordu" diyordu. O gerekce ARTIK GECERSIZ: rozeti
    // sifirlayan `markAsRead` cagrisi `_startWatching`ten kaldirildi
    // (bkz. messaging_notifier.dart), yani sebep kaynaginda cozuldu.
    //
    // ÖLÇÜM (cihaz gunlugu, 20:42:13): hesap degisiminde signOut→signIn
    // araligindaki bir an auth BOSTA kalir ve o anda calisan TUM Firestore
    // dinleyicileri `permission-denied` alir — sohbet listesi, calls,
    // callLogs, blocks ve ACIK SOHBETIN MESAJ AKISI dahil, hepsi ayni
    // saniyede. Firestore reddedilen bir dinleyiciyi YENIDEN DENEMEZ;
    // stream kalici olarak olur. Kimse yeniden kurmazsa o oturumda canli
    // guncelleme bir daha gelmez: mesaj gonderilir, sunucuya yazilir, ama
    // EKRANDA GORUNMEZ (kullanici "gitmedi" sanir) ve durum ikonu
    // gonderildigi andaki degerde (saat) donar kalir.
    ref.invalidate(messagingNotifierProvider);

    // Yeni kimlikle ana ekrana don, yigini tamamen temizle
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeShell(myUid: account.uid),
      ),
      (route) => false,
    );
  }

  Future<void> _confirmRemove(SavedAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.tr('remove_account'),
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '"${account.username}" hesabi bu cihazdan kaldirilsin mi? '
          'Sunucudaki veriler silinmez, ama gizli anahtar bu cihazdan '
          'silinecegi icin bu hesaba bir daha girilemez.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('remove'),
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await MultiAccountService.removeAccount(account.uid);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.tr('my_accounts'))),
      // ➕ YENİ HESAP EKLE: mevcut hesap cihazda KAYITLI kalır; yeni
      // hesapla kayıt olunur ve aralarında tek dokunuşla geçilir.
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              icon:
                  const Icon(Icons.person_add_alt_1, color: Color(0xFF04141C)),
              label: Text(context.tr('add_account'),
                  style: const TextStyle(
                      color: Color(0xFF04141C), fontWeight: FontWeight.w600)),
              onPressed: _addAccount,
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        context.tr('accounts_desc'),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                    ..._accounts.map((a) {
                      final isActive = a.uid == _activeUid;
                      final canSwitch = a.password.isNotEmpty;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            a.username.isNotEmpty
                                ? a.username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF04141C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          '@${a.username}',
                          style: const TextStyle(color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          isActive
                              ? context.tr('active_account')
                              : (canSwitch
                                  ? context.tr('tap_to_switch')
                                  : 'Eski surum - gecis yapilamaz'),
                          style: TextStyle(
                            color: isActive
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isActive
                            ? const Icon(Icons.check_circle,
                                color: AppTheme.primary)
                            : IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.textSecondary),
                                onPressed:
                                    _busy ? null : () => _confirmRemove(a),
                              ),
                        onTap: (_busy || isActive || !canSwitch)
                            ? null
                            : () => _switchTo(a),
                      );
                    }),
                  ],
                ),
                if (_busy)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}
