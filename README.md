# SECRETER

**Telefon numarası istemeyen, uçtan uca şifreli Android mesajlaşma uygulaması.**
Flutter + Firebase ile yazıldı. Kayıt için e-posta da istemez; hesap
cihazda üretilen bir anahtarla açılır.

📦 `com.secreter.app` · 🧩 Flutter (Dart) + Cloud Firestore + Cloud Functions
· 📄 [AGPL-3.0](LICENSE) · 🌍 Arayüz 16 dilde

🇬🇧 **[English README](README.en.md)** · 🐛 **[Bilinen sorunlar → Issues](https://github.com/lemuxon/secreter/issues)** · 🤝 [Katkı rehberi](CONTRIBUTING.md) · 🔒 [Güvenlik](SECURITY.md)

---

## ⚠️ Projenin durumu — önce bunu oku

**Bu proje aktif olarak geliştirilmiyor ve çalışan bir hizmeti yok.**

* Google Play'de **üretime çıkmadı.** Kapalı testte (≈12 testçi) 24 sürüm
  yayınlandı, üretim erişimi alındı ama kullanılmadı.
* Projeye ait **Firebase arka ucu kapatılıyor.** Depodaki
  `firebase_options.dart` ve `google-services.json` artık çalışmayan bir
  projeye işaret ediyor — fork'larsan **kendi Firebase projeni kurmalısın**
  (aşağıya bak).
* Kod, çalıştığı hâliyle ve olduğu gibi yayımlanıyor: biri faydalanabilsin
  diye. Destek, yol haritası veya güvenlik güncellemesi sözü **yok**.

> 🔐 **Gerçek gizlilik ihtiyacın varsa bu uygulamayı kullanma.** E2EE
> katmanı bağımsız denetimden geçmedi ve bilinen sınırları var (aşağıda
> dürüstçe yazılı). Gazeteci, aktivist veya risk altındaki biriysen
> **Signal** kullan.

---

## Ne yapıyor

| | |
|---|---|
| 🔑 **Numarasız kayıt** | Telefon numarası ve e-posta istemez; kimlik cihazda üretilir |
| 🔒 **E2EE (1-1)** | X25519 + AES-256-GCM + HKDF; X3DH el sıkışma, ratchet |
| 👥 **Grup & kanal** | Sender-key ile grup şifrelemesi, kanal yayını |
| 📞 **Sesli/görüntülü arama** | WebRTC; TURN kurulursa IP gizlenir |
| 🕑 **Kaybolan mesaj** | Süresi dolunca cihazdan **ve sunucudan** silinir |
| 🧹 **Metadata kontrolleri** | Okundu/yazıyor/çevrimiçi kapatılabilir, mesaj dolgusu, kaba zaman damgası |
| 🎭 **Kılık modu** | Uygulama başlatıcıda "Hesap Makinesi" olarak görünebilir |
| 🛡️ **Cihaz sertleştirme** | Root/Frida/debugger tespiti, `FLAG_SECURE` |
| 📤 **Veri taşınabilirliği** | Sohbet dışa aktarma, hesap silme |

Kod: **185 Dart dosyası**, **60 test dosyası**.
Doğrulama kapıları: analyzer 0 bulgu · **640 Dart testi** · **175 Firestore
kural testi** · 4 functions testi.

---

## Mimari

| Belge | İçerik |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Clean Architecture katmanları, Riverpod, DI |
| [`METADATA_PRIVACY.md`](METADATA_PRIVACY.md) | Dürüst tehdit modeli, Firebase'in sınırları |
| [`DESIGN.md`](DESIGN.md) | Tasarım dili ve kararları |
| [`TURN_KURULUMU.md`](TURN_KURULUMU.md) | coturn kurulumu (IP gizleme için şart) |
| [`GUVENLIK_DUZELTMELERI.md`](GUVENLIK_DUZELTMELERI.md) | Her güvenlik düzeltmesinin GEREKÇESİ |
| [`DEVAM.md`](DEVAM.md) | Geliştirme günlüğü — ne zaman, ne, neden |

> `DEVAM.md` ve `GUVENLIK_DUZELTMELERI.md` geliştirme sırasında tutulmuş
> çalışma notlarıdır; cilalı belge değil, gerçek kayıt. Bir kararın
> *neden* öyle verildiğini merak edersen cevap büyük ihtimalle oradadır.

---

## Kurulum

### Gereksinimler

| Araç | Sürüm | Ne için |
|---|---|---|
| Flutter SDK | **3.44.4** (Dart 3.12.2) | uygulama — CI bu sürüme sabitli |
| JDK | **17** | Android derlemesi |
| JDK | **21** | Firestore kural testleri (`firebase-tools` şartı) |
| Node.js | 20+ | Cloud Functions ve kural testleri |
| Firebase CLI | güncel | dağıtım |

> ⚠️ İki ayrı JDK gerekiyor. Kural testleri 21'in altında **çalışmaz**;
> Android derlemesi 17 ile yapılır.

### 0. 🧪 Hızlı yol — hiçbir hesap açmadan çalıştır

Sadece denemek veya katkı vermek istiyorsan Firebase hesabı, proje ve
kredi kartı **gerekmez**. Yerel emülatör yeter:

```bash
flutter pub get
firebase emulators:start                      # firestore + auth + functions + storage
flutter run --dart-define=USE_EMULATOR=true   # ayrı bir terminalde
```

Emülatör paneli: <http://localhost:4000>

🪤 **İlk çalıştırmada** Storage emülatörü bir `.jar` indirir ve bu sırada
Functions keşfi 10 saniyelik penceresini aşıp şu hatayı verebilir:
*"User code failed to load. Cannot determine backend specification."*
Kod bozuk değildir — **komutu bir daha çalıştır**, indirme önbelleğe
alındığı için ikincisi geçer. Doğru açılışta şunu görmelisin:

```
+  functions: Loaded functions definitions from source: … claimPreKey …
```

`claimPreKey` listede yoksa E2EE oturumu kurulamaz.

⚠️ **Gerçek bir Android cihazda** `10.0.2.2` çalışmaz (o adres yalnızca
Android emülatöründen ana makineye gider). Cihaz ile bilgisayar aynı
ağdaysa makinenin LAN adresini ver:

```bash
flutter run --dart-define=USE_EMULATOR=true --dart-define=EMULATOR_HOST=192.168.1.42
```

🪤 `--dart-define` **sürüm derlemesinde de geçerlidir.** `USE_EMULATOR=true`
ile çıkılmış bir APK herkesin telefonunda var olmayan bir yerel sunucuya
bağlanmaya çalışır ve uygulama sessizce tamamen çalışmaz. Bu yüzden bayrak
sürüm derlemesinde yok sayılır; bilerek istiyorsan
`--dart-define=ALLOW_EMULATOR_IN_RELEASE=true` eklemen gerekir.
Gerekçe: `lib/core/emulator_kurulumu.dart`.

Gerçek bir arka uç istiyorsan aşağıdan devam et.

### 1. Kendi Firebase projeni kur

Depodaki yapılandırma kapatılan bir projeye ait. Kendi projeni oluştur ve
şunları **kendi** projene bağla:

```bash
flutterfire configure            # firebase_options.dart + google-services.json üretir
```

### 2. 🔴 Sunucu tarafını DAĞIT — atlanırsa uygulama korumasız çalışır

Bu adım isteğe bağlı değil. Güvenlik istemcide değil **kurallarda**:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

* `firestore.rules` / `storage.rules` dağıtılmazsa **veri herkese açıktır**
* `firestore.indexes.json` eksikse sorgular **sessizce boş döner**
* `functions/` olmadan **E2EE oturumu kurulamaz** (`claimPreKey`)

> 💸 **Cloud Functions için Blaze planı gerekiyor** (kullandıkça öde).
> Spark planında v2 fonksiyonlar çalışmaz — dağıtılmış görünüp sessizce
> durur. Bu projede tam olarak bu yaşandı; bkz. `DEVAM.md` §4cn.

### 3. Derle

```bash
flutter pub get
flutter build apk --release --split-per-abi
# veya Play paketi:
flutter build appbundle --release
```

---

## Depoda OLMAYAN, senin üretmen gerekenler

`.gitignore` bunları bilerek dışarıda tutar:

| Dosya / değer | Ne işe yarar |
|---|---|
| `android/key.properties` | imzalama parolaları — şablon: `key.properties.ORNEK` |
| `*.jks` / `*.keystore` | imzalama anahtarı (`keytool` ile üretilir) |
| `functions/.env` | `TURN_SECRET`, `TURN_URLS` — bkz. `TURN_KURULUMU.md` |
| `--dart-define=GIPHY_API_KEY=...` | GIF sekmesi; verilmezse özellik kapalı gelir |

`google-services.json` ve `lib/firebase_options.dart` **depoda vardır**.
İçlerindeki Firebase API anahtarı tasarım gereği herkese açıktır (her
APK'nın içinde gider) ve güvenlik ondan değil Firestore kurallarından
gelir. Yine de kendi anahtarını Google Cloud Console'dan **Android
uygulaması + SHA-1** ile kısıtla.

---

## Doğrulama kapıları

Bu projede her değişiklik beş kapıdan geçer:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze                       # 0 bulgu olmalı
flutter test                          # 640 test
node --check functions/index.js
cd functions && node --test           # 4 test

# Firestore kuralları (175 test) — JDK 21 ŞART, emülatör gerekir:
cd test/rules && npm install
firebase emulators:exec --only firestore --project secreter-rules-test "npm test"
```

> ⚠️ `.github/workflows/ci.yml` tetikleyicisi `main`/`develop` dallarına
> bakıyor ama bu deponun dalı `master` — CI olduğu gibi çalışmaz.
> Fork'larsan tetikleyiciyi kendi dalına göre düzelt.

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

Birebir (1-1) sohbetlerde gerçek E2EE var. Mimari:

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
2. **Grup E2EE var ama ayrı bir mekanizma:** Grup/kanal mesajları "sender key" deseniyle şifrelenir (`lib/services/group_key_service.dart`) — her üye kendi gönderen zincirini üretir, mevcut ikili E2EE kanalından dağıtır, mesajı bir kez şifreler. Üyelik değiştiğinde zincir rotasyona girer; ayrılan kişi sonraki mesajları okuyamaz. ⚠️ Rotasyon **her üyenin kendi cihazında** gerçekleşmek zorundadır; yalnızca atan yöneticinin rotasyonuna güvenmek diğer üyelerin zincirlerini olduğu gibi bırakırdı. Bu yüzden üyelik farkı gönderim anında her cihazda ayrıca ölçülür.
3. **Basitleştirilmiş Ratchet:** Tam Double Ratchet'teki DH-ratchet adımı yok (sadece symmetric ratchet). Sıra dışı gelen mesajlarda (out-of-order) çözme sorunları olabilir.
4. **Signed prekey imza doğrulaması** tam uygulanmadı — MITM'e karşı tam koruma için eklenmelidir.
5. **Anahtar yedekleme yok:** Cihaz kaybedilirse oturum geçmişi çözülemez (bu aslında güvenlik açısından iyi, ama kullanıcıyı uyarın).

**Üretim için öneri:** Bu katman E2EE'nin *nasıl çalıştığını* gösterir ve makul koruma sağlar, ama hayati gizlilik için olgunlaştığında resmi `libsignal` binding'ine geçilmelidir.

---


## 🛡️ Cihaz güvenliği sertleştirmesi

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


## 📖 Lisans — AGPL-3.0

Bu proje **GNU Affero General Public License v3.0** ile dağıtılır. Tam
metin: kök dizindeki [`LICENSE`](LICENSE).

Kısaca ne demek:

* Kodu **kullanabilir, inceleyebilir, değiştirebilir ve dağıtabilirsin.**
* Değiştirilmiş bir sürümü **dağıtırsan** (veya ağ üzerinden hizmet olarak
  sunarsan), **kaynağını da açmak zorundasın** — aynı lisansla.
* Garanti verilmez.

AGPL, gizlilik iddiası taşıyan bir uygulama için bilinçli bir tercih:
kodun kapatılıp yeniden paketlenememesi, kullanıcının "bu gerçekten
iddia ettiği şeyi mi yapıyor" sorusunu sorabilmesini kalıcı kılar.

### ⚠️ Fork'layacaksan — güvenlik uyarısı

Bu uygulamanın güvenliği yalnızca istemci koduna dayanmaz. Kendi
sürümünü yayımlayacaksan **kendi Firebase projeni kur** ve şunları
kendin dağıt; aksi halde uygulama çalışır görünür ama korumasız olur:

* `firestore.rules` ve `storage.rules` — **dağıtılmadan** veri herkese
  açıktır (bu projede bir kez yaşandı, bkz. `GUVENLIK_DUZELTMELERI.md`)
* `firestore.indexes.json` — eksikse sorgular sessizce boş döner
* `functions/` — E2EE oturumu `claimPreKey` olmadan kurulamaz

### Depoda OLMAYAN ve senin üretmen gerekenler

Bunlar bilerek dışarıda bırakıldı (`.gitignore`):

| Dosya | Ne işe yarar |
|---|---|
| `android/key.properties` | imzalama parolaları — şablonu `key.properties.ORNEK` |
| `*.jks` / `*.keystore` | imzalama anahtarı |
| `functions/.env` | `TURN_SECRET`, `TURN_URLS` (bkz. `TURN_KURULUMU.md`) |
| `--dart-define=GIPHY_API_KEY` | GIF sekmesi; verilmezse özellik kapalı gelir |

`android/app/google-services.json` ve `lib/firebase_options.dart`
**depoda vardır**; içlerindeki Firebase API anahtarı tasarım gereği
herkese açıktır (her APK'nın içinde gider) ve güvenlik ondan değil
Firestore kurallarından gelir. Yine de kendi projeni kurarken anahtarı
Google Cloud Console'dan **Android uygulaması + SHA-1** ile kısıtla.


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
