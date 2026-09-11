import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../core/di/injection.dart';
import '../core/security/security_service.dart';
import '../features/security/presentation/security_warning_screen.dart';
import '../features/conversations/presentation/screens/home_shell.dart';
import '../utils/app_theme.dart';
import '../features/security/presentation/app_lock_wrapper.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/onboarding/presentation/language_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/i18n/app_localizations.dart';
import '../core/observability/handled_error.dart';

/// Uygulamaya asil giris yonlendirmesi. HERHANGI bir canli context ile
/// calisir (Splash yasamiyor olsa bile) — "olu state'e callback" bug'inin
/// kalici cozumu.
Future<void> _routeToApp(BuildContext context) async {
  // 🌐 ILK ACILIS: dil hic secilmediyse once dil ekranini goster.
  // Secim sonrasi ayni yonlendirme mantigi (_afterLanguage) calisir.
  try {
    final p = await SharedPreferences.getInstance();
    final chosen = p.getString('app_locale_code');
    if ((chosen == null || chosen.isEmpty) && context.mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => LanguageScreen(
          onDone: (ctx) => _afterLanguage(ctx), // canli context
        ),
      ));
      return;
    }
  } catch (_) {
    // SharedPreferences hatasi: dil ekranini atla, akisa devam
  }
  if (!context.mounted) return;
  await _afterLanguage(context);
}

/// Dil secildikten (veya zaten secilmisken) sonraki normal yonlendirme.
Future<void> _afterLanguage(BuildContext context) async {
  // DAYANIKLILIK: isLoggedIn secure-storage okur; bazi cihazlarda
  // (ozellikle yeniden kurulum sonrasi MIUI) firlatabilir. Firlarsa
  // uygulama SIKISMAZ — log duser, oturumsuz akisa gecilir.
  bool loggedIn = false;
  try {
    loggedIn = await AuthService.isLoggedIn();
  } catch (e) {
    debugPrint('SPLASH: isLoggedIn hatası (oturumsuz devam): $e');
  }
  if (!context.mounted) return;

  if (loggedIn) {
    try {
      NotificationService.initialize();
    } catch (e) {
      debugPrint('SPLASH: bildirim init hatası (devam): $e');
    }
  }

  String? myUid;
  try {
    myUid = AuthService.currentUid;
  } catch (e) {
    debugPrint('SPLASH: currentUid hatası: $e');
  }
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => loggedIn && myUid != null
          ? AppLockWrapper(child: HomeShell(myUid: myUid))
          : const RegisterScreen(),
    ),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    _checkAuth();
    // BEKCI: 10 sn icinde yonlendirme olmadiysa (asilma/istisna) zorla gir.
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      debugPrint('SPLASH bekçi: takılma algılandı, zorla giriş yapılıyor.');
      _routeToApp(context).catchError((e) {
        debugPrint('SPLASH bekçi yönlendirme hatası: $e');
        _forceEnter();
      });
    });
  }

  Future<void> _checkAuth() async {
    // ACILIS HIZI: eski akista 2 sn SABIT bekleme + ardindan SIRALI guvenlik
    // kontrolu vardi (~2.5-3 sn kayip). Simdi marka animasyonu icin kisa bir
    // bekleme, guvenlik kontroluyle PARALEL calisir.
    SecurityCheckResult secResult;
    try {
      final security = getIt<SecurityService>();
      final results = await Future.wait([
        Future.delayed(const Duration(milliseconds: 700)),
        // Platform cagrisi asilirsa splash'i rehin almasin
        security.performSecurityCheck().timeout(const Duration(seconds: 4)),
      ]);
      secResult = results[1] as SecurityCheckResult;
    } catch (e, s) {
      // ⚠️ "GÜVENLİ" DİYE İŞARETLENİR AMA HİÇ BAKILMAMIŞTIR.
      // Kontrol zaman aşımına uğrar ya da platform kanalı patlarsa sonuç
      // `safe()` olur; kök erişimi/hook tespiti çalışmamış olsa bile
      // uygulama açılır ve kullanıcı kontrolün geçtiğini sanır. Açılışı
      // bir platform arızası yüzünden engellemek daha kötü olurdu
      // (kullanıcı uygulamasına hiç giremezdi), bu yüzden davranış
      // korunuyor — ama §4j'nin dersi gereği artık sessiz değil.
      reportHandled('Güvenlik kontrolü yapılamadı — GÜVENLİ VARSAYILDI', e,
          stack: s);
      secResult = const SecurityCheckResult.safe();
    }
    if (!mounted) return;

    // Kritik tehdit varsa uygulamayı engelle
    if (secResult.hasCriticalThreat) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SecurityWarningScreen(result: secResult),
        ),
      );
      return;
    }

    // Kritik OLMAYAN uyarilar (gelistirici modu, emulator vb.):
    // KESINTISIZ gecis — kullaniciyi korkutan ara ekran KALDIRILDI.
    // (Istenirse _interruptOnWarnings=true ile eski davranis geri gelir;
    // buton bug'i da duzeltildi: artik uyari ekraninin KENDI context'iyle
    // yonlendirir, yok edilmis Splash state'ine bagimli degildir.)
    const interruptOnWarnings = false;
    if (!secResult.isSafe) {
      // Yalnızca LOG: çeviri anahtarı yeterli (kullanıcıya gösterilmez).
      debugPrint('Güvenlik uyarıları (engellenmedi): '
          '${secResult.threats.map((t) => t.titleKey).join(', ')}');
      // ignore: dead_code
      if (interruptOnWarnings) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SecurityWarningScreen(
              result: secResult,
              onContinueAnyway: (ctx) => _routeToApp(ctx),
            ),
          ),
        );
        return;
      }
      await _proceedToApp();
      return;
    }

    // 2. Güvenliyse normal akış
    try {
      await _proceedToApp();
    } catch (e) {
      debugPrint('SPLASH: yönlendirme hatası: $e');
      _forceEnter();
    }
  }

  Future<void> _proceedToApp() async {
    if (!mounted) return;
    await _routeToApp(context);
  }

  /// Son care girisi: her sey basarisiz olsa bile kullanici kayit/giris
  /// akisina ulasir (SIKISMA yerine).
  void _forceEnter() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // MARKA: gercek uygulama logosu (assets/brand/logo.png)
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 34,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/brand/logo.png',
                      width: 116,
                      height: 116,
                      fit: BoxFit.cover,
                      // Asset eksikse acilis KIRILMASIN
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.primary,
                        child: const Icon(Icons.lock_rounded,
                            size: 52, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'SECRETER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('splash_tagline'),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
