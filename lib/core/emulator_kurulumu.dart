/// 🧪 YEREL EMÜLATÖR MODU — kendi Firebase projen olmadan çalıştırmak için
///
/// ── ÇÖZDÜĞÜ SORUN ──
/// Depoyu klonlayan birinin uygulamayı AÇABİLMESİ için şunlar gerekiyordu:
/// kendi Firebase projesi, `flutterfire configure` ve — Cloud Functions v2
/// Spark planında çalışmadığı için — **kredi kartı bağlı Blaze planı**.
/// Yani tek bir ekranı görmeden önce bir saat kurulum ve bir ödeme yöntemi.
/// Bu, katkıya değil denemeye bile engeldi.
///
/// `firebase.json` içinde dört emülatör zaten tanımlıydı (firestore 8080,
/// auth 9099, functions 5001, storage 9199) ama uygulama onlara HİÇ
/// bağlanmıyordu. Eksik olan tek parça buydu.
///
///     firebase emulators:start
///     flutter run --dart-define=USE_EMULATOR=true
///
/// Firebase hesabı, proje, ücret ve Blaze gerekmez.
///
/// ── 🪤 TUZAK 1: BÖLGE ──
/// Uygulama `FirebaseFunctions.instance` DEĞİL,
/// `FirebaseFunctions.instanceFor(region: 'europe-west1')` kullanıyor
/// (`auth_service.dart`, `key_management_service.dart`,
/// `turn_credentials_service.dart`). Emülatör varsayılan örneğe
/// bağlansaydı SESSİZCE hiçbir şey yapmazdı: çağrılar yine gerçek
/// buluta — ya da hiçbir yere — giderdi. Aşağıda aynı bölgeli örnek
/// kullanılır; bölge değişirse burası da değişmeli.
///
/// ── 🪤 TUZAK 2: SÜRÜM DERLEMESİNE SIZMASI ──
/// `--dart-define` sürüm derlemesinde de geçerlidir. `USE_EMULATOR=true`
/// ile çıkılan bir APK, her kullanıcının telefonunda var olmayan bir yerel
/// sunucuya bağlanmaya çalışır ve uygulama TAMAMEN çalışmaz — üstelik
/// sessizce. Bu yüzden sürüm derlemesinde bayrak yok sayılır; bilerek
/// yapılıyorsa ikinci bir bayrak açıkça verilmelidir.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Emülatöre bağlan.
const bool kEmulatorKullan =
    bool.fromEnvironment('USE_EMULATOR', defaultValue: false);

/// Sürüm derlemesinde emülatöre bağlanmaya İZİN VER. Bkz. TUZAK 2.
const bool kEmulatorSurumdeIzinli =
    bool.fromEnvironment('ALLOW_EMULATOR_IN_RELEASE', defaultValue: false);

/// Emülatörün çalıştığı makinenin adresi.
///
/// Boş bırakılırsa Android'de `10.0.2.2` (Android emülatöründen ana
/// makineye giden özel adres), diğer platformlarda `localhost` kullanılır.
///
/// ⚠️ GERÇEK bir Android cihazda `10.0.2.2` ÇALIŞMAZ — cihaz ile
/// bilgisayarın aynı ağda olması ve bilgisayarın LAN adresinin verilmesi
/// gerekir:
///
///     flutter run --dart-define=USE_EMULATOR=true \
///                 --dart-define=EMULATOR_HOST=192.168.1.42
const String kEmulatorHost =
    String.fromEnvironment('EMULATOR_HOST', defaultValue: '');

/// Portlar `firebase.json` → `emulators` ile AYNI olmalı.
const int _authPort = 9099;
const int _firestorePort = 8080;
const int _functionsPort = 5001;
const int _storagePort = 9199;

/// Functions çağrılarının yapıldığı bölge. Bkz. TUZAK 1.
const String _functionsBolgesi = 'europe-west1';

/// Emülatörün adresi — `EMULATOR_HOST` verilmediyse platforma göre çözülür.
String get cozulmusEmulatorHost {
  if (kEmulatorHost.isNotEmpty) return kEmulatorHost;
  return defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
}

/// Emülatör modu gerçekten etkin mi?
///
/// Sürüm derlemesinde `ALLOW_EMULATOR_IN_RELEASE` olmadan FALSE döner.
bool get emulatorEtkinMi {
  if (!kEmulatorKullan) return false;
  if (kReleaseMode && !kEmulatorSurumdeIzinli) return false;
  return true;
}

/// Tüm Firebase istemcilerini yerel emülatöre yönlendir.
///
/// `Firebase.initializeApp()` SONRASI, Firestore/Auth'a ilk erişimden
/// ÖNCE çağrılmalıdır. Emülatör kapalıysa hiçbir şey yapmaz.
///
/// Kendi içinde hata yakalar: `main.dart`'taki savunmacı boot kuralı
/// gereği hiçbir başlatma adımı `runApp`'i engellememelidir.
Future<void> emulatoreBagla() async {
  if (!kEmulatorKullan) return;

  if (kReleaseMode && !kEmulatorSurumdeIzinli) {
    debugPrint(
      'EMULATOR: USE_EMULATOR sürüm derlemesinde YOK SAYILDI. Bilerek '
      'istiyorsan --dart-define=ALLOW_EMULATOR_IN_RELEASE=true ekle.',
    );
    return;
  }

  final host = cozulmusEmulatorHost;
  try {
    await FirebaseAuth.instance.useAuthEmulator(host, _authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, _firestorePort);
    FirebaseStorage.instance.useStorageEmulator(host, _storagePort);
    FirebaseFunctions.instanceFor(region: _functionsBolgesi)
        .useFunctionsEmulator(host, _functionsPort);

    debugPrint(
      'EMULATOR: $host — auth:$_authPort firestore:$_firestorePort '
      'functions:$_functionsPort storage:$_storagePort',
    );
  } catch (e) {
    debugPrint('EMULATOR: bağlanılamadı (devam ediliyor): $e');
  }
}
