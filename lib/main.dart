import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/di/injection.dart';
import 'core/observability/crash_reporter.dart';
import 'core/privacy/privacy_settings.dart';
import 'features/messaging/data/datasources/message_sync_service.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/e2ee_session_service.dart';
import 'services/group_key_service.dart';
import 'services/key_management_service.dart';
import 'services/self_note_service.dart';
import 'services/privacy_service.dart';
import 'utils/app_theme.dart';
import 'services/deep_link_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/locale_provider.dart';
import 'core/widgets/active_call_banner.dart';
import 'core/security/chat_lock_service.dart';
import 'features/security/presentation/app_lock_wrapper.dart';
import 'features/conversations/domain/entities/conversation_entity.dart';

/// 🔗 Derin-link yonlendirmesi icin kok navigator anahtari.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Hesap kapsamı akışı — yeniden kurulumda eskisini iptal etmek için.
StreamSubscription<String?>? _kapsamAbonesi;

/// TÜM kapsamlı servisleri TEK yerden ayarla.
///
/// Dört servis de aynı uid ile kapsamlanmalı; biri unutulursa o servisin
/// verisi yanlış hesabın önekiyle okunur/yazılır (§4au, §4bd).
void _hesapKapsaminiKur(String? uid) {
  E2EESessionService.setActiveAccount(uid);
  GroupKeyService.setActiveAccount(uid);
  ChatLockService.setActiveAccount(uid);
  KeyManagementService.setActiveAccount(uid);
  SelfNoteService.setActiveAccount(uid);
}

void main() {
  // runZonedGuarded: yakalanmamış async hataları da raporlanır
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ============ SAVUNMACI BOOT ============
    // KURAL: runApp HER KOSULDA calisir. Baslatma adimlarindan herhangi
    // biri hata firlatirsa uygulama BEYAZ EKRANDA kalmaz — adim atlanir,
    // log dusulur, boot devam eder. (Release'te yasanan beyaz ekranin
    // koku: zincirdeki bir await'in firlatmasi runApp'i engelliyordu.)

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('BOOT: Firebase init hatası (devam ediliyor): $e');
    }

    // Hive lokal veritabanını başlat (offline cache + gizlilik ayarları)
    try {
      await Hive.initFlutter();
    } catch (e) {
      debugPrint('BOOT: Hive init hatası (devam ediliyor): $e');
    }

    // Bağımlılıkları kaydet (DI container)
    try {
      await initDependencies();
    } catch (e) {
      debugPrint('BOOT: DI hatası (devam ediliyor): $e');
    }

    // GÜVENLİK TAŞIMASI: düz metin SharedPreferences'ta duran kilit
    // bayrağı ve kilitli sohbet listesi şifreli depoya taşınır. Bu
    // olmadan cihaza erişen biri `lock_enabled=false` yazarak uygulama
    // kilidini PIN'i bilmeden devre dışı bırakabiliyordu.
    try {
      await PrivacyService.migrateLegacyPrefs();
      await ChatLockService.migrateLegacy();
    } catch (e) {
      debugPrint('BOOT: gizlilik taşıması atlandı: $e');
    }

    // Eski surum (kimliksiz) aktif hesabi sessizce yeni surume yukselt.
    // `await` YOK: ağ çağrısı açılışı bekletmemeli. Hataları zone
    // yakalayıcısı toplar (saran try/catch async hatayı yakalayamıyordu).
    AuthService.upgradeCurrentAccountIfNeeded().catchError((Object e) {
      debugPrint('BOOT: hesap yükseltme hatası (devam ediliyor): $e');
    });

    // E2EE anahtarlarını ve sohbet kilitlerini AKTİF HESABA kapsamla:
    // anahtarlar yalnızca chatId ile isimlendirildiğinde çoklu hesapta
    // oturum durumu ve düz metinler hesaplar arasında karışıyordu.
    try {
      // İLK kurulum: oturum zaten geri yüklenmişse kapsam hemen doğru olur.
      _hesapKapsaminiKur(AuthService.currentUid);

      // ⚠️ VE OTURUM OTURDUĞUNDA YENİDEN KUR (§4bd).
      //
      // 🐞 Kapsam SADECE burada, bir kez kuruluyordu. Ama
      // `FirebaseAuth.currentUser`, `initializeApp()` hemen ardından
      // HENÜZ NULL olabilir — kaydedilmiş oturum asenkron geri yüklenir.
      // O yarışı kaybeden açılışta kapsam `'_'` kalıyor ve:
      //   • oturum anahtarı `e2ee_session___{chatId}` olur → KAYITLI
      //     OTURUM BULUNAMAZ → gelen her mesaj "çözülemiyor",
      //   • giden mesajlar `'_'` altında yeni oturum kurar → sonraki
      //     açılışta doğru uid ile okunur, ÖKSÜZ kalır ve karşı tarafın
      //     cevapları da çözülemez.
      // Her açılışta yeniden zar atıldığı için arıza ARALIKLI görünüyordu.
      _kapsamAbonesi?.cancel();
      _kapsamAbonesi = AuthService.activeUidChanges.listen(
        _hesapKapsaminiKur,
        onError: (Object e) => debugPrint('BOOT: kapsam akışı hatası: $e'),
      );
    } catch (e) {
      debugPrint('BOOT: hesap kapsamı ayarlanamadı: $e');
    }

    // Flutter framework hatalarını raporcuya yönlendir
    // (raporcu arıza-emniyetli: platform hatasında kendini kapatır)
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      try {
        if (getIt.isRegistered<CrashReporter>()) {
          getIt<CrashReporter>().recordFlutterError(
              details.exception, details.stack ?? StackTrace.current);
        }
      } catch (_) {}
    };

    // Mesaj senkronizasyon servisini başlat (offline kuyruğu)
    try {
      getIt<MessageSyncService>().start();
    } catch (e) {
      debugPrint('BOOT: sync başlatma hatası (devam ediliyor): $e');
    }

    // FCM arka plan handler'ı
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('BOOT: FCM handler hatası (devam ediliyor): $e');
    }

    runApp(const ProviderScope(child: SecreterApp()));

    // ============ ERTELENMIS TELEMETRI ============
    // Kilitlenme raporlama — VARSAYILAN KAPALI, sadece onayla açılır.
    // ILK KARE ciziltikten SONRA baslatilir: Crashlytics'in Android
    // eklentisi eksik olsa bile acilisi asla etkileyemez.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 🔗 davet derin-linki dinleyicisi (arizasi acilisi etkileyemez)
      try {
        await DeepLinkService.init(rootNavigatorKey);
      } catch (e) {
        debugPrint('DeepLink init atlandı: $e');
      }
      try {
        final reporter = getIt<CrashReporter>();
        final consent = await _readCrashConsent();
        await reporter.initialize(consentGiven: consent);
      } catch (e) {
        debugPrint('Telemetri başlatılamadı (uygulama etkilenmez): $e');
      }
    });
  }, (error, stack) {
    // Zone dışına sızan async hatalar — raporlama da hata firlatirsa yut
    debugPrint('FATAL: $error');
    try {
      if (getIt.isRegistered<CrashReporter>()) {
        getIt<CrashReporter>().recordError(error, stack, fatal: true);
      }
    } catch (_) {}
  });
}

/// Onay bayrağını Hive'dan oku (PrivacyController ile aynı kutu/anahtar).
Future<bool> _readCrashConsent() async {
  try {
    final box = Hive.isBoxOpen('privacy_settings')
        ? Hive.box('privacy_settings')
        : await Hive.openBox('privacy_settings');
    final raw = box.get('settings');
    if (raw == null) return false; // varsayılan: kapalı
    final settings = PrivacySettings.fromMap(Map<String, dynamic>.from(raw));
    return settings.crashReportingConsent;
  } catch (_) {
    return false;
  }
}

class SecreterApp extends ConsumerWidget {
  const SecreterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌐 secili dil (null ise MaterialApp cihaz dilini dener; ilk acilista
    // dil ekrani zaten gosterilecek)
    final locale = ref.watch(localeProvider);
    // 🌐 Domain katmanindaki YEDEK basliklar da cevrilsin.
    // `ConversationEntity` saf kalsin diye ceviri, ad cozumleyicide
    // oldugu gibi, disaridan FONKSIYON olarak takilir. Dil
    // degistiginde bu build yeniden calisir ve kanca tazelenir.
    ConversationEntity.labelResolver =
        (key) => AppLocalizations(locale ?? const Locale('en')).t(key);
    return MaterialApp(
      navigatorKey: rootNavigatorKey, // 🔗 derin-link yonlendirme
      title: 'SECRETER',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: AppLanguages.locales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ⚠️ KİLİT EN ÜSTTE OLMALI.
      //
      // AppLockWrapper eskiden yalnızca HomeShell'i saran bir ROTA'ydı.
      // `rootNavigatorKey` üzerine push edilen her şey (özellikle
      // `gizlichat://join/...` derin bağlantısı) o rotanın ÜSTÜNE binip
      // PIN ekranını tamamen ATLIYORDU. Burada, Navigator'ın da üstünde
      // durduğu için hiçbir rota kilidi aşamaz.
      builder: (context, child) => AppLockWrapper(
        child: ActiveCallBanner(child: child ?? const SizedBox.shrink()),
      ),
      home: const SplashScreen(),
    );
  }
}
