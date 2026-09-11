# GizliChat — Kurulum & APK Derleme Kılavuzu

> 🏗️ **v9 Mimari Güncellemesi:** Messaging modülü Clean Architecture +
> Riverpod + Dependency Injection ile yeniden yapılandırıldı. Detaylar ve
> bu deseni diğer modüllere uygulama rehberi için **ARCHITECTURE.md**'ye bakın.
> Yeni kod `lib/core/` ve `lib/features/` altında; eski `lib/services/` ve
> `lib/screens/` kademeli geçiş için korundu.

> 📴 **v10 Offline Desteği:** Hive ile lokal cache + pending kuyruğu eklendi.
> Mesajlar açılışta cache'ten anında gelir; offline gönderilenler bağlanınca
> otomatik gönderilir. **Not:** `connectivity_plus` 5.x kullanılıyor — 6.x'e
> yükseltirsen `onConnectivityChanged` artık `List<ConnectivityResult>`
> döndürür, `network_info.dart`'ı ona göre güncelle.

> 🛡️ **v11 Güvenlik Sertleştirme:** Root/jailbreak, emulator, geliştirici
> modu, Frida ve debugger tespiti + `FLAG_SECURE` eklendi. Kritik tehditte
> uygulama açılmaz; uyarıda kullanıcı devam edebilir. Detaylar aşağıda.

> 🧪 **v12 Test Altyapısı:** 26 unit + 4 widget testi (mocktail), integration
> test iskeleti, sıkı lint kuralları (`analysis_options.yaml`) ve GitHub Actions
> CI eklendi. `flutter test` ile çalıştırılır. Detaylar ARCHITECTURE.md'de.

> 🏛️ **v13 Modül Geçişi Tamamlandı:** messaging, story, group ve call
> modüllerinin **dördü de** Clean Architecture'a taşındı (domain/data/
> presentation). İş mantığı `services/`'ten katmanlara dağıtıldı. Eski kod
> kademeli geçiş için korundu — detaylar ve emekliye ayırma planı ARCHITECTURE.md'de.

> 🎨 **v14 UI Yenileme:** Material 3 tema sistemi + "Buzlu Obsidyen" tasarım
> dili (buzlu cam yüzeyler, iki-tonlu anlam taşıyan palet, Hero/giriş
> animasyonları, E2EE "güvenli malzeme" dokunuşu). Tasarım kararları ve
> dürüst sınırlamalar **DESIGN.md**'de. Tema tüm ekranlara otomatik yansır.

> 🔭 **v15 Gözlemlenebilirlik + Metadata Gizliliği:** Onay-bazlı (opt-in)
> Crashlytics raporlama (PII temizlemeli, soyutlama arkasında — Sentry'ye
> tek dosyada geçilir) + mesaj dolgusu (uzunluk gizleme), metadata
> kontrolleri (okundu/yazıyor/çevrimiçi kapatılabilir), kaba zaman damgası.
> Dürüst tehdit modeli ve Firebase'in sınırları **METADATA_PRIVACY.md**'de.

## 📋 Gereksinimler
- Flutter SDK 3.x (https://flutter.dev/docs/get-started/install)
- Android Studio veya VS Code
- Firebase hesabı (ücretsiz)
- Java 17+

---

## 🔥 ADIM 1 — Firebase Kurulumu

### 1.1 Firebase Projesi Oluştur
1. https://console.firebase.google.com adresine git
2. "Proje oluştur" → İsim: `gizlichat`
3. Google Analytics: kapalı bırak (anonimlik için)

### 1.2 Android Uygulaması Ekle
1. Firebase Console → Android simgesi
2. Package name: `com.gizlichat.app`
3. `google-services.json` dosyasını indir
4. Dosyayı `android/app/` klasörüne koy

### 1.3 Firebase Servislerini Aç
Firebase Console'da şunları aktifleştir:
- **Authentication** → Oturum açma yöntemi → **Anonim** → Etkinleştir
- **Firestore Database** → Veritabanı oluştur → **Test modunda başlat**
- **Storage** → Başlat → Test modunda

### 1.4 Güvenlik Kurallarını Yükle
Firebase Console → Firestore → Kurallar sekmesi:
- `firestore.rules` dosyasının içeriğini yapıştır → Yayınla

Firebase Console → Storage → Kurallar sekmesi:
- `storage.rules` dosyasının içeriğini yapıştır → Yayınla

---

## 📦 ADIM 2 — Proje Bağımlılıkları

```bash
# Proje klasörüne gir
cd gizlichat

# Bağımlılıkları yükle
flutter pub get
```

---

## 🔧 ADIM 3 — android/app/build.gradle Düzenle

`android/app/build.gradle` dosyasına ekle:

```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        applicationId "com.gizlichat.app"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        multiDexEnabled true
    }
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-analytics'
}

apply plugin: 'com.google.gms.google-services'
```

---

## ⚠️ ÖNEMLİ — Biyometrik için MainActivity

Faz 3'te eklenen parmak izi/yüz tanıma özelliği `FlutterFragmentActivity` gerektirir.
Proje içinde `MainActivity.kt` zaten bu şekilde ayarlı:

```kotlin
class MainActivity : FlutterFragmentActivity()
```

Ayrıca `android/app/build.gradle` içinde `minSdkVersion` **en az 23** olmalı (biyometrik için):

```gradle
minSdkVersion 23
```

---

## 🔔 ÖNEMLİ — Push Bildirim (FCM) Sunucu Kurulumu

Faz 4'teki push bildirimleri **iki parçadan** oluşur:

**1. Cihaz tarafı (zaten hazır):** Uygulama FCM token'ı alıp Firestore'a kaydeder, izin ister, gelen bildirimi gösterir.

**2. Sunucu tarafı (senin kurman gerek):** Birine mesaj gelince ona push gönderecek kod. Bunun için Firebase Cloud Functions kullan:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendMessageNotification = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const chatId = context.params.chatId;

    // Chat üyelerini al
    const chatDoc = await admin.firestore()
      .collection('chats').doc(chatId).get();
    const memberIds = chatDoc.data().memberIds;

    // Gönderen hariç herkese bildirim gönder
    for (const uid of memberIds) {
      if (uid === message.senderId) continue;
      const userDoc = await admin.firestore()
        .collection('users').doc(uid).get();
      const token = userDoc.data()?.fcmToken;
      if (!token) continue;

      await admin.messaging().send({
        token: token,
        notification: {
          title: '@' + message.senderUsername,
          body: 'Yeni mesaj',  // İçerik şifreli olduğu için sadece bildirim
        },
        data: { chatId: chatId },
      });
    }
  });
```

Kurulum:
```bash
npm install -g firebase-tools
firebase login
firebase init functions
# Yukarıdaki kodu functions/index.js'e yapıştır
firebase deploy --only functions
```

> Not: Cloud Functions ücretsiz katmanı (Spark planı) ayda 2M çağrı içerir — küçük/orta kullanım için yeterli.

---

## 📞 ÖNEMLİ — Sesli/Görüntülü Arama (WebRTC)

Aramalarda ses/görüntü sunucudan geçmez; yalnızca bağlantı kurulumu (signaling) Firestore üzerinden yapılır.

### ⚠️ TURN YOKSA IP ADRESLERİ KARŞILIKLI GÖRÜNÜR

Bu, arama kalitesi değil **anonimlik** meselesidir. TURN yapılandırılmamışsa arama P2P kurulur ve **arayan ile aranan birbirinin gerçek IP adresini öğrenir**. Telefon numarası istemeyen bir uygulamada IP, kimliğin en güçlü belirleyicilerinden biridir.

TURN yapılandırıldığında `iceTransportPolicy: relay` devreye girer: yalnızca relay adayları toplanır, cihazın IP'si karşı tarafa **hiç gitmez**. Uygulama bu durumu arama ekranında kullanıcıya da gösterir (🔒 "IP adresin gizli" / ⚠️ "IP adresin karşı tarafa görünüyor").

**STUN (hazır):** Google'ın ücretsiz STUN sunucuları yedek olarak yapılandırıldı — bağlantı kurulur ama **IP gizlenmez**.

### TURN kimlik bilgileri nasıl veriliyor

**Tercih edilen yol — sunucudan, kısa ömürlü:** `getTurnCredentials` Cloud Function'ı, coturn'ün `use-auth-secret` şemasıyla saatlerle ölçülen kimlik üretir. Sır **yalnızca sunucuda** durur.

> ❗ TURN parolasını `--dart-define` ile vermek onu APK'ya gömer ve **APK'dan çıkarılabilir** (Giphy anahtarında yaşanan sorunun aynısı). Bu yol yalnızca yedektir; kullanılıyorsa parolanın sızmış sayılması ve döndürülmesi için yeni sürüm gerekir.
>
> Kimlik bilgilerini **kaynak koda yazma** — `call_service.dart` artık bunu okumaz.

Kurulumun tamamı (VPS, coturn, TLS, 443/TCP, güvenlik duvarı, doğrulama): **[`TURN_KURULUMU.md`](TURN_KURULUMU.md)**

> Test için: aynı Wi-Fi ağındaki iki cihaz STUN ile sorunsuz çalışır ama IP'ler görünür. Gerçek gizlilik testi için TURN şarttır.

> ⚠️ iOS'ta WebRTC için ek Info.plist izinleri gerekir (kamera/mikrofon). Bu proje Android odaklı; iOS eklersen `flutter_webrtc` dökümanına bak.

---

## 🔐 ÖNEMLİ — Uçtan Uca Şifreleme (E2EE) Mimarisi ve Sınırları

Faz 7'de **direkt sohbetlere** (1-1) gerçek E2EE eklendi. Mimari:

**Kullanılan denetlenmiş primitifler** (`cryptography` paketi):
- X25519 (Diffie-Hellman anahtar değişimi)
- AES-256-GCM (mesaj şifreleme + bütünlük)
- HKDF-SHA256 (anahtar türetme)

**Protokol katmanı** (bu projede yazıldı):
- **X3DH:** İlk bağlantıda iki taraf, özel anahtarlarını paylaşmadan ortak sırra ulaşır. Karşı taraf çevrimdışıyken bile çalışır (prekey bundle sayesinde).
- **Double Ratchet (symmetric):** Her mesajda anahtar değişir → Forward Secrecy.
- Özel anahtarlar **sadece cihazda** (secure storage). Sunucu sadece açık anahtarları (prekey bundle) görür.

**Nasıl çalışır:**
1. Kayıtta her kullanıcı identity key + signed prekey + 100 one-time prekey üretir, açık kısımları `keyBundles`'a yükler.
2. İlk mesajda gönderen, alıcının bundle'ını çekip X3DH başlatır, başlığı ilk mesaja ekler.
3. Alıcı bu başlıkla aynı sırra ulaşır, oturum kurulur.
4. Sonraki her mesaj ratchet'i ilerletir.

**⚠️ Bu E2EE'nin bilinen sınırları (dürüst olmak gerekirse):**
1. **Denetlenmemiş protokol katmanı:** Primitifler güvenli ama X3DH/Ratchet *uygulaması* profesyonel güvenlik denetiminden geçmedi. Gerçek anonimlik hayati önemdeyse (gazeteci, aktivist) bunun yerine **gerçek Signal uygulamasını** kullanın.
2. **Sadece 1-1 sohbetler:** Grup/kanal E2EE bu fazda yok (Signal'de bile grup şifreleme ayrı, karmaşık bir mekanizmadır — Sender Keys).
3. **Basitleştirilmiş Ratchet:** Tam Double Ratchet'teki DH-ratchet adımı yok (sadece symmetric ratchet). Sıra dışı gelen mesajlarda (out-of-order) çözme sorunları olabilir.
4. **Signed prekey imza doğrulaması** tam uygulanmadı — MITM'e karşı tam koruma için eklenmelidir.
5. **Anahtar yedekleme yok:** Cihaz kaybedilirse oturum geçmişi çözülemez (bu aslında güvenlik açısından iyi, ama kullanıcıyı uyarın).

**Üretim için öneri:** Bu katman E2EE'nin *nasıl çalıştığını* gösterir ve makul koruma sağlar, ama hayati gizlilik için olgunlaştığında resmi `libsignal` binding'ine geçilmelidir.

---

## 🛡️ v11 — Güvenlik Sertleştirme

Uygulama açılışında (`splash_screen` → `SecurityService`) cihaz taranır:

| Tehdit | Tespit yöntemi | Davranış |
|--------|---------------|----------|
| Root / Jailbreak | RootBeer (flutter_jailbreak_detection) + safe_device | **Engelle** |
| Hooking (Frida/Xposed) | Native Frida port taraması (MainActivity.kt) | **Engelle** |
| Debugger | Native `Debug.isDebuggerConnected()` | **Engelle** |
| Emulator | safe_device `isRealDevice` | Uyarı (devam edilebilir) |
| Geliştirici modu | flutter_jailbreak_detection `developerMode` | Uyarı |

**FLAG_SECURE:** `MainActivity.kt` açılışta `WindowManager.LayoutParams.FLAG_SECURE`
set eder → ekran görüntüsü, ekran kaydı ve son kullanılanlar önizlemesi
engellenir. Runtime'da `NativeSecurityBridge.setSecureFlag()` ile değiştirilebilir.

### ⚠️ ÖNEMLİ — Güvenlik Sertleştirmenin Sınırları (dürüst değerlendirme)

Bu kontroller **mutlak güvenlik DEĞİLDİR**. Kararlı bir saldırgan:
- **Magisk Hide / Zygisk** ile root tespitini atlatabilir
- **Frida gadget injection** ile port taramasını atlatabilir
- **Uygulamayı yeniden paketleyerek** tüm kontrolleri kaldırabilir

Bu bir "yükseltme bariyeri"dir — sıradan tehditleri eler, ama asıl koruma
**E2EE şifreleme** ve **sunucu kurallarındadır**. İstemci kontrolleri her zaman
atlatılabilir; kritik doğrulama sunucuda yapılmalı.

### Production için daha güçlü alternatifler

Şu an `flutter_jailbreak_detection` + `safe_device` + native port taraması
kullanıyoruz. Daha güvenilir tespit için:

1. **`jailbreak_root_detection`** — RootBeer **+ DetectFrida** içerir (gerçek
   Frida tespiti, port taramasından güçlü)
2. **`device_safety_info`** — Native FFI ile process memory map taraması
   (Frida/Xposed/Cydia hook tespiti) + native TracerPid debugger tespiti

Bunlara geçmek için sadece `SecurityServiceImpl` değişir — soyutlama (`SecurityService`)
ve geri kalan kod aynı kalır (mimarinin avantajı).

> Not: `flutter_jailbreak_detection` Samsung Knox / Xiaomi gibi cihazlarda
> false-positive verebilir. Production'da `jailbreakDetails` ile hangi kontrolün
> tetiklendiğini loglayıp eşiği ayarlamak gerekebilir.

---

## 📱 ADIM 4 — APK Derleme

### Debug APK (Test için)
```bash
flutter build apk --debug
# Çıktı: build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK (Dağıtım için)
```bash
# Önce imzalama anahtarı oluştur
keytool -genkey -v -keystore gizlichat.keystore \
  -alias gizlichat -keyalg RSA -keysize 2048 -validity 10000

# key.properties dosyası oluştur (android/ klasörüne)
echo "storePassword=SIFREN
keyPassword=SIFREN
keyAlias=gizlichat
storeFile=../gizlichat.keystore" > android/key.properties

# Release APK derle
flutter build apk --release --split-per-abi

# En küçük APK (arm64 — çoğu modern telefon)
# Çıktı: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🏗️ Proje Yapısı

```
gizlichat/
├── lib/
│   ├── main.dart                    # Uygulama giriş noktası
│   ├── models/
│   │   ├── user_model.dart          # Kullanıcı modeli
│   │   ├── message_model.dart       # Mesaj modeli
│   │   └── chat_model.dart          # Chat/Grup modeli
│   ├── services/
│   │   ├── auth_service.dart        # Anonim auth + kullanıcı adı
│   │   ├── chat_service.dart        # Mesaj gönderme/silme/gruplama
│   │   └── encryption_service.dart  # AES-256 şifreleme
│   ├── screens/
│   │   ├── splash_screen.dart       # Açılış ekranı
│   │   ├── register_screen.dart     # Kullanıcı adı kaydı
│   │   ├── home_screen.dart         # Chat listesi
│   │   ├── chat_screen.dart         # Mesajlaşma ekranı
│   │   ├── search_user_screen.dart  # Kullanıcı arama
│   │   └── create_group_screen.dart # Grup oluşturma
│   └── utils/
│       └── app_theme.dart           # Telegram benzeri karanlık tema
├── android/
│   └── app/
│       └── src/main/
│           └── AndroidManifest.xml
├── firestore.rules                  # Firestore güvenlik kuralları
├── storage.rules                    # Storage güvenlik kuralları
└── pubspec.yaml                     # Bağımlılıklar
```

---

## ✅ Özellikler

| Özellik | Durum |
|--------|-------|
| Anonim kayıt (kullanıcı adı ile) | ✅ |
| Birebir mesajlaşma | ✅ |
| Grup kurma ve yönetim | ✅ |
| Mesaj geçmişi | ✅ |
| Fotoğraf gönderme | ✅ |
| GIF gönderme | ✅ |
| Sesli mesaj (dalga animasyonlu) | ✅ |
| Dosya gönderme (50MB'a kadar) | ✅ |
| Konum paylaşımı | ✅ |
| Yanıtlama (reply) | ✅ |
| Tepki emojisi | ✅ |
| Yazıyor göstergesi | ✅ |
| Okundu bilgisi (tik sistemi) | ✅ |
| Mesaj düzenleme | ✅ |
| Kaybolan mesajlar | ✅ |
| Uygulama kilidi (PIN) | ✅ |
| Parmak izi / yüz tanıma | ✅ |
| Sahte PIN (plausible deniability) | ✅ |
| Otomatik kilit | ✅ |
| Ekran görüntüsü engelleme | ✅ |
| Son görülmeyi gizleme | ✅ |
| Okundu bilgisini gizleme | ✅ |
| Yazıyor göstergesini gizleme | ✅ |
| Push bildirim (FCM) | ✅ |
| Bildirim içeriği gizleme | ✅ |
| 24 saatlik hikaye/durum | ✅ |
| Metin + fotoğraf durumu | ✅ |
| Durum görüntülenme sayısı | ✅ |
| Çoklu hesap | ✅ |
| Grup rolleri (kurucu/admin/üye) | ✅ |
| Üye atma / yasaklama | ✅ |
| Üye sessize alma | ✅ |
| Davet linki | ✅ |
| Kanal (tek yönlü yayın) | ✅ |
| Sadece adminler yazsın modu | ✅ |
| Grup açıklaması düzenleme | ✅ |
| Sesli arama (WebRTC P2P) | ✅ |
| Görüntülü arama (WebRTC P2P) | ✅ |
| Arama kontrolleri (mute/kamera/hoparlör) | ✅ |
| Gelen arama bildirimi | ✅ |
| Ön/arka kamera değiştirme | ✅ |
| Uçtan uca şifreleme (X3DH) | ✅ |
| Double Ratchet (forward secrecy) | ✅ |
| Prekey bundle sistemi | ✅ |
| Çevrimdışı oturum kurma | ✅ |
| Her iki taraftan mesaj silme | ✅ |
| AES-256 mesaj şifreleme | ✅ |
| Çevrimiçi durum göstergesi | ✅ |
| Kullanıcı adıyla kişi arama | ✅ |
| Telegram benzeri karanlık tema | ✅ |
| APK olarak dağıtım | ✅ |

---

## 🔒 Gizlilik Notları

- Firebase **anonim auth** kullanır — telefon/e-posta kaydı yok
- Mesajlar **AES-256** ile uygulama katmanında şifrelenir
- Firebase sunucusunda şifreli veri saklanır
- **Tam anonimlik** için ileride Matrix/Synapse'a geçiş yapılabilir
- Şifreleme anahtarı cihazda `flutter_secure_storage` ile saklanır

---

## 🚀 APK'yı Telefona Yükle

1. APK dosyasını telefona kopyala
2. Ayarlar → Güvenlik → **Bilinmeyen kaynaklardan yükleme** → Aç
3. APK'ya tıkla → Yükle
