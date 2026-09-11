import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/prefs/decoy_content.dart';
import '../../../core/security/native_security_bridge.dart';
import '../../../core/media/secure_media_cache.dart';
import '../../../services/e2ee_session_service.dart';
import '../../../services/privacy_service.dart';
import '../../../utils/app_theme.dart';
import 'pin_lock_screen.dart';

/// Uygulamayı saran güvenlik katmanı.
///
/// ⚠️ KONUM KRİTİK: Bu widget artık `MaterialApp.builder` içinde, yani
/// Navigator'ın ÜSTÜNDE duruyor. Eskiden yalnızca `HomeShell`'i saran bir
/// ROTA'ydı; bu yüzden `rootNavigatorKey` üzerine push edilen her şey
/// (özellikle `gizlichat://join/...` derin bağlantısı) kilit ekranının
/// ÜSTÜNE biniyor ve PIN'i TAMAMEN ATLIYORDU.
///
/// Sorumlulukları:
///  • Açılışta kilit varsa PIN ister
///  • Arka plandan dönünce auto-lock süresine göre tekrar kilitler
///  • Kilitliyken bellekteki çözülmüş mesajları temizler
///  • Ekran görüntüsü engellemeyi uygular
class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

_AppLockWrapperState? _activeLockState;

/// Panik jesti: her yerden sahte moda geçir.
void triggerPanicDecoy() => _activeLockState?._enterDecoyMode();

/// Uygulama şu an kilitli mi? (Derin bağlantılar bunu bekler — kilitliyken
/// sohbet açmak kilidi anlamsız kılardı.)
bool isAppLocked() =>
    _activeLockState?._locked == true || _activeLockState?._decoyMode == true;

/// Sahte (panik) mod aktif mi? Bildirim ve widget güncellemeleri buna bakar.
bool isDecoyActive() => _activeLockState?._decoyMode == true;

class _AppLockWrapperState extends State<AppLockWrapper>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _decoyMode = false;
  bool _checking = true;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    _activeLockState = this;
    WidgetsBinding.instance.addObserver(this);
    _initialCheck();
    _applyScreenshotSetting();
  }

  @override
  void dispose() {
    if (_activeLockState == this) _activeLockState = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _applyScreenshotSetting() async {
    final blocked = await PrivacyService.isScreenshotBlocked();
    if (blocked) {
      await NativeSecurityBridge.acquire('user_pref');
    } else {
      await NativeSecurityBridge.release('user_pref');
    }
  }

  Future<void> _initialCheck() async {
    final lockEnabled = await PrivacyService.isLockEnabled();
    if (!mounted) return;
    setState(() {
      _locked = lockEnabled;
      _checking = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkAutoLock();
      _applyScreenshotSetting();
    }
  }

  Future<void> _checkAutoLock() async {
    final lockEnabled = await PrivacyService.isLockEnabled();
    if (!lockEnabled || _locked) return;

    final autoLockMinutes = await PrivacyService.getAutoLockMinutes();
    if (_pausedAt == null) return;

    // SANİYE hassasiyeti: `elapsed.inMinutes >= 1` karşılaştırması, 1 dakika
    // ayarında 59 saniyeye kadar kilitlemeyi GECİKTİRİYORDU.
    final elapsed = DateTime.now().difference(_pausedAt!);
    if (autoLockMinutes == 0 || elapsed.inSeconds >= autoLockMinutes * 60) {
      _lockNow();
    }
  }

  void _lockNow() {
    // Kilitlenirken bellekteki ÇÖZÜLMÜŞ mesaj metinlerini temizle: kilit
    // ekranı arkasında RAM'de düz metin tutmak, kilidin amacını zayıflatır.
    E2EESessionService.clearMemoryCache();
    if (!mounted) return;
    setState(() => _locked = true);
  }

  void _unlock() {
    if (!mounted) return;
    setState(() {
      _locked = false;
      _decoyMode = false;
    });
  }

  void _enterDecoyMode() {
    // ── SAHTE MOD İZOLASYONU ──
    // Eskiden yalnızca görünen widget değişiyordu: alttaki Firestore
    // dinleyicileri, bildirimler ve ana ekran widget'ı ÇALIŞMAYA DEVAM
    // EDİYORDU. Yani sahte ekranın üstünde gerçek mesaj bildirimi
    // belirebiliyor ve launcher widget'ı gerçek okunmamış sayısını
    // gösteriyordu — makul inkâr edilebilirlik tamamen kırılıyordu.
    // Artık bellekteki düz metinler silinir ve `isDecoyActive()` ile
    // bildirim/widget katmanları susturulur.
    E2EESessionService.clearMemoryCache();
    // Çözülmüş fotoğraf/ses cihazda kalırsa sahte mod inandırıcılığını
    // kaybeder: galeri/dosya gezgininden gerçek içerik bulunabilir.
    SecureMediaCache.instance.clearAll();
    if (!mounted) return;
    setState(() {
      _locked = false;
      _decoyMode = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: AppTheme.background,
          child:
              Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        ),
      );
    }

    if (_locked) {
      return PinLockScreen(
        mode: LockMode.verify,
        onSuccess: _unlock,
        onDecoyEntered: _enterDecoyMode,
      );
    }

    if (_decoyMode) {
      return const _DecoyHomeScreen();
    }

    return widget.child;
  }
}

/// Sahte PIN girildiğinde gösterilen ekran.
///
/// Gerçek ana ekranla AYNI tema kullanılır (tutarsızlık sahte modu ele
/// verirdi). Boş ekran şüphe çektiği için kullanıcının kendi hazırladığı
/// zararsız sahte sohbetler gösterilir; bunlar tamamen yereldir ve dışarı
/// hiçbir şey yazmaz.
class _DecoyHomeScreen extends ConsumerWidget {
  const _DecoyHomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(decoyContentProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('SECRETER',
            style: TextStyle(color: AppTheme.textPrimary)),
      ),
      body: chats.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  Text(context.tr('no_conv_yet'),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            )
          : ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0x11FFFFFF)),
              itemBuilder: (context, i) {
                final c = chats[i];
                final last = c.messages.isEmpty ? '' : c.messages.last.text;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFF04141C))),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(color: AppTheme.textPrimary)),
                  subtitle: Text(last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => _DecoyChatScreen(chat: c)),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.edit_rounded, color: Color(0xFF04141C)),
      ),
    );
  }
}

/// Sahte sohbet ekranı — yalnızca önceden hazırlanmış mesajları gösterir;
/// yazma çubuğu görseldir, hiçbir yere gönderim YAPMAZ.
class _DecoyChatScreen extends StatelessWidget {
  final DecoyChat chat;
  const _DecoyChatScreen({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(chat.name,
            style: const TextStyle(color: AppTheme.textPrimary)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: chat.messages.length,
              itemBuilder: (context, i) {
                final m = chat.messages[i];
                return Align(
                  alignment:
                      m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: m.mine
                          ? AppTheme.bubbleSent
                          : AppTheme.bubbleReceived,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.text,
                        style: const TextStyle(color: AppTheme.textPrimary)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: AppTheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: Text(context.tr('type_message'),
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ),
                const Icon(Icons.send, color: AppTheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
