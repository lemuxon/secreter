# SECRETER — Güvenlik Denetimi Düzeltme Raporu

**Tarih:** 2026-08-13
**Kapsam:** 252 kaynak dosyalık tam denetimde bulunan 96 sorunun giderilmesi
**Doğrulama:** `flutter analyze` · `flutter test` · `dart format` ·
Firestore emulator kural testleri · `node --check`

---

## Doğrulanmış Sonuç

| Kapı | Önce | Sonra |
|---|---|---|
| `flutter analyze` | 0 error, **6 warning**, 264 info | **0 error, 0 warning, 0 info** |
| `flutter test` | **28 geçti / 7 başarısız** | **310 geçti / 0 başarısız** |
| `dart format` | **97 dosya ihlal** | **0 ihlal** |
| Firestore kuralları | **test yok** | **113 test, emulator'de 113/113 geçiyor** |
| Cloud Functions | **CI yok** | sözdizimi + CI işi eklendi |

> Kural testleri gerçek Firestore emulator'ünde çalışır ve giderilen her
> kritik açığa karşılık gelen bir test içerir. Bu, düzeltmelerin
> "iddia" değil **ölçülmüş** olduğu anlamına gelir.

---

## 1. Kritik (12) — hepsi giderildi

### C-01 · Herkes herkesin özel sohbetine girebiliyordu
`firestore.rules`
Kural, kişinin yalnızca üyelik alanlarını değiştirmesi koşuluyla kendini
**herhangi** bir sohbete eklemesine izin veriyordu; kanal kontrolü yoktu.
Birebir sohbet kimliği `sıralı(uid1,uid2)` olduğu ve `users` koleksiyonu
listelenebildiği için **her kayıtlı kullanıcı** iki kişinin özel sohbetini
hesaplayıp içine girebiliyordu.
→ Katılma yalnızca **açık kanallara** kısıtlandı; eklenen kişinin **tek
başına kendisi** olması ve **kimsenin çıkarılmaması** kural düzeyinde
zorunlu. Yasaklılar giremez.
*Testler: "YABANCI kendini ÖZEL birebir sohbete EKLEYEMEZ" + 8 test*

### C-02 · Tüm sohbet medyası her kullanıcıya açıktı
`storage.rules`
`chats/**` okuma koşulu yalnızca "giriş yapmış olmak"tı → medya hiçbir
zaman E2EE değildi ve chatId hesaplanabildiği için herkes indirebiliyordu.
Ayrıca `avatars/*` ve `group_avatars/*` için **hiç kural yoktu** → profil
fotoğrafı yükleme her zaman sessizce başarısız oluyordu.
→ Okuma/yazma Firestore üyeliğine bağlandı; üzerine yazma ve istemci
silme kapatıldı; eksik yollar tanımlandı.

### C-03 · WebRTC ICE adayları herkese açıktı (IP ifşası)
`firestore.rules` · `call_service.dart`
`callerCandidates`/`calleeCandidates` `if signedIn()` idi. ICE adayları
**IP adresi** taşır → anonimlik iddiasının tam çöküşü; ayrıca sahte aday
enjekte edilebiliyordu.
→ Alt koleksiyonlar aramanın **iki tarafına** kısıtlandı. TURN
yapılandırıldığında `iceTransportPolicy: relay` ile IP hiç sızmaz.
*Testler: "YABANCI ICE adaylarını (IP) OKUYAMAZ" + 4 test*

### C-04 · `reactions` şema çakışması sohbeti tamamen kırıyordu
Üç üretici (eski motor: LİSTE, yeni katman + Cloud Function: HARİTA) aynı
alana yazıyordu. Karşı şemada `TypeError` → mesaj akışı düşüyor → **sohbet
ekranı hiç açılmıyordu**. Hikâye yanıtı üzerinden erişilebilirdi.
→ Eski motor silindi, okuyucu **iki biçimi de** tolere edecek şekilde
normalize edildi, Function `{}` (harita) yazıyor.

### C-05 · Grup içeriği ve önizleme sunucuda düz metindi
Şifresiz sohbetlerde mesajın **tam metni** `chats.lastMessage` alanına düz
yazılıyordu.
→ Önizleme her durumda `🔒 Mesaj`. *Test: "önizlemeye İÇERİK yazılmaz"*

### C-06 · Şifreleme hatası sessizce düz metne düşüyordu
`encryption_service.dart` — `catch (e) { return plainText; }`
Anahtar bozuksa düz metin "şifrelenmiş" sanılıp sunucuya yazılıyordu.
Ayrıca AES-**CBC** kimlik doğrulamasızdı.
→ AES-256-**GCM**; hata artık **fırlatılır**, asla düz metin dönmez.
*Testler: "geçersiz anahtarda ASLA düz metin döndürmez" + "kurcalanmış
şifreli metin reddedilir"*

### C-07 · Çözülmüş mesaj metinleri cihazda sonsuza kadar kalıyordu
`e2ee_sent_*` anahtarları yazılıyor ama **hiçbir yerde silinmiyordu** →
kaybolan mesajlar ve "herkesten sil" cihazda hiçbir şey temizlemiyordu.
→ Tam yaşam döngüsü (`forgetPlaintext(s)`, `wipeAllPlaintexts`,
`wipeAccount`) eklendi ve silme/temizleme/çıkış/hesap-silme yollarına
bağlandı. *Testler: "silinen mesajın CİHAZDAKİ düz metni de silinir"*

### C-08 · Eski akış ratchet'i her snapshot'ta ilerletiyordu
Sonuç: **yalnızca en yeni mesaj okunabiliyordu.**
→ Eski motor tamamen silindi; yeni katmanda kalıcı düz metin önbelleği
idempotan çözme sağlıyor.

### C-09 · E2EE oturumu hiç kurulamıyordu
İstemci, karşı tarafın `keyBundles` dokümanından ön-anahtar tüketmeye
çalışıyordu; kural bunu reddediyor → oturum kurulamıyor → mesajlar
**şifresiz** gidiyordu.
→ Tüketim `claimPreKey` **callable Cloud Function**'ına taşındı
(transaction ile atomik; "tek kullanımlık" garantisi de düzeldi).
*Test: "BAŞKASININ anahtar paketi DEĞİŞTİRİLEMEZ"*

### C-10 · Üyesi olmadığın sohbete mesaj enjeksiyonu
`scheduledMessages` kuralı `chatId`'yi kontrol etmiyordu; Function Admin
SDK ile kuralları atlayarak yazıyordu.
→ Kuralda **üyelik zorunlu**; Function'da üyelik + susturma + yalnız-
yönetici kontrolü tekrar doğrulanıyor.
*Test: "üyesi OLMADIĞIN sohbete zamanlanmış mesaj yazılamaz"*

### C-11 · Derin bağlantı uygulama kilidini atlıyordu
`AppLockWrapper` yalnızca `HomeShell`'i saran bir **rota**ydı; kök
navigator'a push edilen davet bağlantısı kilidin **üstüne** biniyordu.
→ Kilit `MaterialApp.builder` içine, **Navigator'ın üstüne** taşındı.
Bağlantı kilitliyken beklemeye alınır; ayrıca kod biçimi doğrulanır ve
gruba katılmadan önce **kullanıcı onayı** istenir.

### C-12 · Kurallar hiç dağıtılmıyordu
`firebase.json` içinde `firestore`/`storage` bölümleri **yoktu** → özenle
yazılmış kurallar üretimde muhtemelen hiç aktif değildi.
→ Bölümler eklendi (+ hosting, emulator yapılandırması).

---

## 2. Yüksek (22) — hepsi giderildi

| Kod | Konu | Çözüm |
|---|---|---|
| H-01 | `allowBackup` açık, Hive şifresiz, kilit bayrağı düz metin | `allowBackup=false` + `data_extraction_rules.xml` + `HiveAesCipher` + kilit ayarları secure storage'a |
| H-02 | PIN: tek tur SHA-256, tahmin edilebilir tuz | `PinHasher` — PBKDF2 150k tur, kriptografik tuz, sabit zamanlı karşılaştırma, **deneme sınırı** |
| H-03 | Sahte PIN sessizce kurulmuyordu | Bağımsız çalışır, başarısızlıkta fırlatır, gerçek PIN'le aynı olamaz |
| H-04 | Sahte mod gerçek veri sızdırıyordu | Bildirimler susturulur, bellekteki düz metin temizlenir (`isDecoyActive()`) |
| H-05 | Function `isEncrypted`, istemci `isE2EE` yazıyordu | Alan adı hizalandı (@bahsetme bildirimi artık çalışıyor) |
| H-06 | Çevrimiçi durumu iki ayrı alana yazılıyordu | Tek yazıcı `PresenceService`; `AuthService` delege ediyor |
| H-07 | İki paralel gizlilik ayarı sistemi | Tek kaynak `PrivacySettings`; `PrivacyService` köprü |
| H-08 | Susturma/yalnız-yönetici/oy/sabitleme yalnızca istemcide | Kurallara taşındı: yazarlık + rol + susturma sunucuda |
| H-09 | Herkes her hikâyeyi ezebiliyordu | Sahibi dışında yalnızca `viewedBy`/`reactions` |
| H-10 | Herkes davet kodlarını silebiliyordu (DoS) | Sahiplik zorunlu; meetCode yalnızca kullanım alanları |
| H-11 | `releasedUsernames` silme kuralı kaydı patlatıyordu | Temizlik sunucuya taşındı (`cleanupReleasedUsernames`) |
| H-12 | Yedek sohbet başına ~100 mesajla sınırlıydı | Tam sayfalama; boş yedekte hata; başarısız sohbetler raporlanır |
| H-13 | 120k tur PBKDF2 ana isolate'te (ANR) | `compute` ile arka plan isolate |
| H-14 | Çeviri metni kamuya açık korpusa gidiyordu | MyMemory yedeği kaldırıldı, onay kapısı servise taşındı |
| H-15 | Android 13+ bildirim izni yoktu | `POST_NOTIFICATIONS` eklendi |
| H-16 | Arka planda arama sürdürülemiyordu | `FOREGROUND_SERVICE_*` + `BLUETOOTH_CONNECT` eklendi |
| H-17 | Kullanılmayan konum izni (Play politikası riski) | İzinler ve ölü konum kodu kaldırıldı |
| H-18 | Kurtarma anahtarı düz base64'tü (QR = hesap devri) | Parola ile AES-256-GCM sarmalama (PBKDF2 150k) |
| H-19 | Giphy anahtarı kaynak kodda | `--dart-define`; anahtar yoksa özellik kapalı; timeout eklendi |
| H-20 | Yayın imzalama parolası düz metinde | Ortam değişkeni önceliği + kök `.gitignore` koruması |
| H-21 | CI üç kapıda kırmızıydı | Üçü de yeşil + kurallar ve functions işleri eklendi |
| H-22 | Hesap silme eksikti (KVKK/GDPR) | `deleteAccountData` Function'ı + cihazdaki tüm izlerin silinmesi |

---

## 3. Orta / Düşük — giderilenler

**Veri bütünlüğü:** mesaj kaybı (hata sonrası kuyruğa alma), senkronizasyon
yarışı (çift gönderim), üstel geri çekilme + ölü mektup kuyruğu, UTC zaman
damgaları (saat dilimi sıralama hatası), üye önbelleği geçersizleştirme,
grup okundu durumu, buluşma kodu transaction'ı, birebir sohbet
oluşturmada `merge`.

**Kripto:** yön-bazlı ayrı zincirler (iki yön aynı anahtarı kullanıyordu),
**atlanan mesaj anahtarları** (sırasız mesaj artık kaybolmuyor), SPK
imzalama + doğrulama (MITM koruması), düşük mertebeli nokta kontrolü,
ön-anahtar tükenince kimlik anahtarının yenilenmemesi, dolgunun
**bayt** bazlı olması, güvenlik numarası (safety number) API'si.

**Bellek/performans:** `_plainMemo` LRU budama, `_expiredHandled` sınırı,
Hive kutu LRU + mesaj tahliyesi, arama akışlarının dispose edilmesi
(kamera/mikrofon serbest bırakma), `_remoteStream` dispose.

**Sağlamlık:** bozuk tek kaydın tüm önbelleği düşürmemesi, `pollVotes`
güvenli dönüşümü, `offer` alan doğrulaması, ICE aday null güvenliği,
`setRemoteDescription` yarış koruması.

---

## 4. Öz-denetimde bulunan ve giderilen İKİ REGRESYON

Düzeltmeler tamamlandıktan sonra "kurallarda referans verilen her alanı
istemci gerçekten yazıyor mu?" kontrolü yapıldı ve **kendi
değişikliklerimin açtığı iki boşluk** bulundu. İkisi de giderildi:

### R-01 · Susturma ve yönetici rolü sunucuda uygulanmıyordu
Kurallar `adminUids` / `mutedUids` düz dizilerini okuyordu, ancak
**hiçbir Dart kodu bu dizileri yazmıyordu.** Sonuç: H-08'in çözdüğü
sanılan sorun kısmen açık kalıyordu — susturulmuş bir üye sunucu
tarafından engellenmiyor, terfi ettirilmiş bir yönetici de yönetici
haklarını alamıyordu (yalnızca `adminId` sahibi çalışıyordu).

**Neden bu tasarım:** Firestore kural motorunda **döngü yoktur**;
`members` dizisindeki nesnelerin `role`/`isMuted` alanları kuraldan
okunamaz. Bu yüzden düz dizi şarttır.

→ `GroupModel.toMap()`, `_updateMemberInArray`, `_removeMember` ve
`leaveGroup` artık bu dizileri `members` ile birlikte güncel tutuyor.

### R-02 · Kanal arama tamamen kırılmıştı
C-01 düzeltmesiyle `chats` listeleme yalnızca kişinin kendi
sohbetleriyle sınırlandı; `channels` dizini kurallara eklendi ama
**arama ekranı hâlâ `chats` sorguluyordu** → her arama
`permission-denied` verecekti.

→ `syncChannelDirectory` Cloud Function'ı eklendi: kanal
oluşturulduğunda/güncellendiğinde `channels/{chatId}` dizinini
yalnızca kamuya açık alanlarla (ad, açıklama, üye SAYISI) senkronlar.
Arama ekranı bu dizini sorguluyor. Dizine yazma istemciye **tamamen
kapalı** (`allow write: if false`) — sahte kanal eklenemez, üye sayısı
şişirilemez. Yasak kontrolü artık sunucuda: katılma denemesi
`permission-denied` alırsa kullanıcıya "yasaklısın" gösterilir.

*Testler: "istemci kanal dizinine YAZAMAZ", "dizin üye listesi
sızdırmaz" (+1 test) → kural testleri 50 → **53**.*

> **Ders:** Kural dosyasında yeni bir alana dayanmak, o alanı yazan
> istemci kodunu da zorunlu kılar. Bu tür "kural ↔ istemci uyumsuzluğu"
> zaten denetimin en kritik bulgusuydu (C-09) — aynı hatayı tekrar
> etmemek için bu kontrol yapıldı.

---

## 4b. R8 AÇILIŞ ÇÖKMESİ — sebep, çözüm, ders

**Belirti:** `flutter run --release` sonrası "Uygulama sürekli duruyor".

**Gerçek sebep (logcat):**
```
java.lang.RuntimeException: Unable to get provider
  androidx.startup.InitializationProvider:
  Failed to create an instance of androidx.work.impl.WorkDatabase
      at androidx.work.WorkManagerInitializer.a(SourceFile:69)
```

**Kök neden — denetim sırasında YAPILAN HATA:**
M-32 kapsamında R8 (`isMinifyEnabled`) açıldı **ve** WorkManager/Room
koruma kuralları "bu proje onları kullanmıyor" gerekçesiyle silindi.
Bu değerlendirme YANLIŞTI:

* WorkManager `pubspec.yaml`'da **görünmez** — `firebase_messaging` ve
  `flutter_local_notifications` üzerinden **transitif bir Android
  bağımlılığı** olarak gelir.
* `androidx.startup.InitializationProvider` ile daha `Application.onCreate`
  aşamasında başlatılır; yani hata ilk kareden önce oluşur.
* Room, veritabanı sınıfını **yansıma** ile bulur
  (`Class.forName(dbClass.getCanonicalName() + "_Impl")`). R8
  `WorkDatabase_Impl`'i yeniden adlandırınca arama başarısız olur.

Kod tabanında bunu uyaran açık bir yorum vardı ve gerçek cihazda test
edilemeden geçersiz kılındı.

**Çözüm:** Koruma kuralları `proguard-rules.pro` içine, **neden silinmemesi
gerektiğini açıklayan** kalıcı bir uyarıyla geri kondu
(`androidx.work.**`, `androidx.room.**`, `androidx.sqlite.**`,
`androidx.startup.**`, `*_Impl`, RoomDatabase alt sınıfları).

**Doğrulama (gerçek cihaz — Xiaomi 2201116TG / Android 13):**
```
adb install -r app-release.apk   → Success
adb shell am start …/.MainActivity
✅ çökme yok   ✅ süreç ayakta   ✅ pencere çizili   ✅ E/flutter hatası yok
```

**Ders:** Bir Android bağımlılığının kullanılıp kullanılmadığı
`pubspec.yaml`'a bakarak anlaşılamaz — transitif AAR'lar oradan görünmez.
`./gradlew :app:dependencies` çıktısına bakılmalı. Ayrıca R8 gibi
davranışı yalnızca release'te değişen ayarlar, **gerçek cihazda test
edilmeden** açılmamalıdır.

> R8 artık **AÇIK** ve çalıştığı doğrulandı (obfuscation + kaynak
> küçültme). Yeni bir yansıma kullanan paket eklendiğinde release
> derlemesi tekrar cihazda denenmelidir.

---

## 4c. ŞİFRELEMENİN KAPSAMI TAMAMLANDI (yeni)

Denetim, uygulamanın gizlilik iddiasının yalnızca **birebir metin** için
doğru olduğunu göstermişti. Kalan iki büyük açık kapatıldı:

### G-01 · Grup/kanal mesajları artık uçtan uca şifreli — *Sender Key*
`lib/services/group_key_service.dart`

**Önce:** grup ve kanal içeriği sunucuda **düz metin**. Firebase'e (ve
konsola erişen herkese) her grup sohbeti tamamen açıktı.

**Şimdi:** Signal'in *sender key* deseni:
1. Her üye, her grup için kendine bir **gönderen zinciri** üretir.
2. Bu zinciri her üyeye **ayrı ayrı, ikili E2EE kanalıyla şifreli** yollar.
3. Mesajı kendi zincirinden türettiği anahtarla **bir kez** şifreler
   (N-1 kez değil — 50 kişilik grupta 49 kat maliyet farkı).
4. Alıcı, gönderene ait zinciri ilerleterek çözer.

**Kritik tasarım kararı:** anahtar dağıtımı, ikili sohbetin ratchet'ini
**kullanmaz**. Kullansaydı dağıtım mesajı karşı tarafın DM alma zincirini
ilerletir ve **gerçek DM mesajları çözülemez** hâle gelirdi. Bu yüzden
`kd_<sıralı uid çifti>` adında ayrı bir oturum ad alanı kullanılır.

**İleri gizlilik üyelik sınırında da korunur:** biri gruptan ayrıldığında/
atıldığında zincir **rotasyona** girer (`_afterMembershipChange`) — ayrılan
kişi eski anahtarı bilse bile sonraki mesajları çözemez.

**Zarif düşüş:** hiçbir üyeye anahtar ulaştırılamıyorsa (kimsenin anahtar
paketi yok) mesaj şifrelenmez ve **kilit simgesi gösterilmez** — şifrelemek,
mesajı herkes için okunmaz yapardı.

### G-02 · Medya ekleri artık uçtan uca şifreli
`lib/core/media/attachment_crypto.dart` · `secure_media_cache.dart` ·
`core/widgets/secure_media_image.dart`

**Önce:** fotoğraf, video, sesli mesaj ve dosyalar Storage'a **düz**
yükleniyordu. Yani metin şifreliyken, çoğu zaman metinden **daha hassas**
olan medya sunucuda tamamen açıktı.

**Şimdi:** her ek için rastgele 256-bit anahtar üretilir, dosya cihazda
**AES-256-GCM** ile şifrelenir, Storage'a yalnızca şifreli baytlar gider
(`contentType: application/octet-stream` — gerçek tür bile sızmaz).

**Anahtar nerede duruyor:** mesajın **E2EE'li `content` alanının içinde**
(`ATT1|<anahtar>|`). Firestore'a düz yazılan bir `mediaKey` alanı **yoktur**
— olsaydı şifreleme anlamsız olurdu. Alan yalnızca çözme sonrası bellekte
yaşar (`MessageEntity.mediaKey`, `toMap`'te yer almaz).

**Görüntüleme:** `SecureMediaImage` indirir → çözer → yerel dosyadan çizer.
Eski (şifresiz) mesajlarda `mediaKey` null'dur ve widget otomatik olarak
eski davranışa döner — **geçmiş mesajlar bozulmaz**.

**Bütünlük:** GCM sayesinde sunucuda değiştirilen bir dosya sessizce bozuk
görüntü olarak açılmaz, çözme **hata verir**.

**Temizlik:** çözülmüş medya uygulamaya özel dizindedir (galeriye düşmez,
`allowBackup=false` ile yedeklenmez) ve çıkış / hesap silme / **panik
modunda** silinir — aksi halde "kaybolan mesaj" bir yanılsama olurdu.

### Ek gizlilik kazanımı
Medya önizlemesi artık yalnızca **tür** taşır. `message.preview` dosya adını
içeriyordu (`📎 pasaport-tarama.pdf`); bu, sohbet listesinde ve sunucuda
okunabilen hassas üst veriydi.

**Doğrulama:** 11 yeni ek-şifreleme testi + 8 yeni grup anahtarı kural
testi. Toplam: **71 Dart testi**, **61 kural testi**, gerçek cihazda
release doğrulaması.

---

## 4d. VİDEO KIRPMA (yeni özellik)

`android/.../VideoTrimmer.kt` · `core/media/video_trim_service.dart` ·
`core/media/video_trim_screen.dart`

**Önce:** seçilen video **doğrudan** gönderiliyordu. Tek kontrol boyut
uyarısıydı; kullanıcının seçeneği "tamamını gönder" ya da "vazgeç"ti.
Uzun kayıtlar dakikalarca yükleniyor ve depolama giderini büyütüyordu.

**Şimdi:** video göndermeden önce kırpma ekranı açılır — önizleme, iki
uçlu aralık seçici, seçili süre ve **tahmini boyut**. Aralığa dokunulmazsa
hiçbir işlem yapılmaz.

### Neden FFmpeg kullanılmadı
`ffmpeg_kit_flutter` APK'ya **30–80 MB** ekler; uygulama zaten ~103 MB.
Bunun yerine Android'in yerleşik `MediaExtractor` + `MediaMuxer` ikilisi
kullanıldı:

| | FFmpeg | MediaMuxer (seçilen) |
|---|---|---|
| APK maliyeti | +30–80 MB | **+0.3 MB** (ölçüldü: 103.2 → 103.5 MB) |
| Yeniden kodlama | var | **yok** (sample kopyalama) |
| Hız | yavaş | **çok hızlı** |
| Kalite kaybı | var | **yok** |
| Kesim hassasiyeti | kare | anahtar kare (0–2 sn sapma) |

Anahtar kare sapması kullanıcıya arayüzde **açıkça** yazılır — sessiz bir
sürpriz bırakmak yerine dürüst davranılır.

### Veri kaybına karşı korumalar
* Kırpma **başarısız olursa orijinal** video gönderilir (kullanıcı
  videosunu asla kaybetmez).
* Yarım kalan çıktı dosyası silinir — "geçerli video" sanılmaz.
* En az 1 saniyelik seçim zorunlu (0 uzunluk bozuk dosya üretirdi).
* Döndürme bilgisi (`orientationHint`) korunur; aksi halde dikey çekilen
  videolar yan yatık kaydedilirdi.
* Kırpma arka plan thread'inde çalışır (ANA thread'de büyük video ANR
  üretirdi).

### ⚠️ Bu iş sırasında yakalanan API uyumsuzluğu
İlk sürüm `MediaMetadataRetriever().use { }` kullanıyordu.
`MediaMetadataRetriever`, `AutoCloseable` arayüzünü **ancak API 29'da**
kazandı; projenin `minSdk` değeri **24**. Derleme `compileSdk` yüksek
olduğu için **sorunsuz geçiyordu**, ancak Android 7–9 cihazlarda
`NoSuchMethodError` ile **çökecekti**. Elle `release()` yapan
`readMetadata` yardımcısına çevrildi.

> Ders: `compileSdk` ile derlenen bir çağrının `minSdk`'de var olduğu
> garanti değildir. Analyzer bunu yakalamaz; yeni platform API'si
> kullanırken "hangi API seviyesinde eklendi" kontrol edilmelidir.

**Doğrulama:** release derleme + gerçek cihazda (Android 13) çalıştırma
→ çökme yok, Dart hatası yok. Kırpmanın kendisi native olduğu için birim
testle kapsanamaz; gerçek bir videoyla elle denenmelidir.

---

## 4e. GÜVENLİK NUMARASI DOĞRULAMASI (yeni)

`lib/features/security/presentation/safety_number_screen.dart` ·
`services/e2ee_session_service.dart` ·
`features/messaging/data/datasources/encryption_datasource_impl.dart`

**Önce:** X3DH imza doğrulaması vardı ama kullanıcı araya girmeyi
(MITM) **tespit edemiyordu**. `safetyNumber()` API'si yazılmıştı, onu
gösteren ekran yoktu — yani özellik pratikte YOKTU.

**Şimdi:** sohbet başlığındaki kalkan rozetinden (ya da taşma
menüsünden) açılan ekran numarayı 5'li altı grup hâlinde ve QR olarak
gösterir, kullanıcı karşılaştırınca "Doğrulandı" işaretleyebilir.

### İmza doğrulaması ile KULLANICI doğrulaması ayrıldı
`SessionState.verified` alanı, sunucudan gelen imzalı ön-anahtarın
imzasının tutarlı olduğunu söyler. **Bu, MITM'e karşı tek başına bir
şey ifade etmez:** araya giren taraf kendi anahtar çiftiyle kendi
geçerli imzasını üretebilir. Mevcut alanı "doğrulandı" rozeti için
kullanmak, kullanıcıya **hiç yapmadığı bir doğrulamayı** göstermek
olurdu. Bu yüzden ayrı bir `userVerified` alanı eklendi.

Eski oturum kayıtlarında bu alan yoktur ve **`false`** kabul edilir
(*test: "ESKİ kayıt (uv/cf alanları yok) doğrulanmamış sayılır"*).

### 🐞 Bu iş sırasında bulunan SESSİZ HATA
`ensureSessionFromHeader` eklenirken ortaya çıktı: oturum kurma
yalnızca **"oturum YOKSA"** çalışıyordu.

Karşı taraf uygulamayı yeniden kurduğunda (ya da cihaz değiştirdiğinde)
yeni bir kimlik anahtarıyla yeni bir X3DH başlığı gönderir. Bizde oturum
zaten var olduğu için başlık **yok sayılıyor**, mesajlar eski zincirle
çözülmeye çalışılıyor ve hepsi başarısız oluyordu. Sonuç: o sohbetteki
**sonraki TÜM mesajlar sessizce "çözülemedi"** olarak kalıyordu —
hiçbir hata, hiçbir uyarı, kurtarma yolu yok.

→ Gelen başlıktaki kimlik anahtarı sabitlenmiş anahtardan **farklıysa**
oturum yeni anahtarla kurulur, `userVerified` **düşer** ve değişim
kullanıcıya gösterilmek üzere kaydedilir (`changedFrom`).

**Yeniden kurulum ile araya girme AYIRT EDİLEMEZ.** Doğru davranış
ikisini de aynı şekilde ele alıp kullanıcıyı uyarmaktır; sohbetin
üstünde kırmızı bir bant çıkar ve dokununca doğrulama ekranı açılır.

Ters yöndeki risk daha pahalıydı: kimlik **aynıyken** oturumu yeniden
kurmak ratchet zincirini sıfırlar ve o sohbeti kırardı. Bu yüzden aynı
anahtar durumunda oturuma hiç dokunulmaz
(*test: "AYNI kimlik anahtarında oturuma DOKUNULMAZ"*).

### Arayüzde dürüstlük
* Şifreli oturum **yokken** kalkan rozeti hiç gösterilmez — olmayan bir
  korumayı ima etmez.
* "Numarayı BU sohbetten göndererek doğrulama" uyarısı ekranda açıkça
  yazar: araya giren taraf o mesajı da değiştirebilir.
* Uyarı bandını kapatmak doğrulamayı **geri getirmez**; kullanıcı
  numarayı yeniden karşılaştırmadan sohbet doğrulanmış sayılmaz
  (*test: "uyarı kapatılınca doğrulama GERİ GELMEZ"*).

### ⚠️ Bilinçli sınır: QR OKUYUCU YOK
QR yalnızca **karşılaştırma** içindir — iki cihazdaki kod aynı
görünmelidir. Uygulama içi tarama, yeni bir kamera/tarayıcı bağımlılığı
(`mobile_scanner` vb.) gerektirir; APK boyutu ve R8 riski göze
alınmadığı için ertelendi. Ekran bunu **gizlemez**, açıkça yazar ve
asıl yol olarak 30 haneli numarayı öne çıkarır.

**Doğrulama:** 12 yeni birim testi (toplam **83** Dart testi),
16 dile 234 çeviri anahtarı, `flutter analyze` 0 error / 0 warning.

---

## 4f. TURN / IP GİZLİLİĞİ ALTYAPISI (yeni)

`functions/index.js` → `getTurnCredentials` ·
`lib/services/turn_credentials_service.dart` · `call_service.dart` ·
`active_call.dart` · `features/call/.../call_screen.dart`

**Önce:** kod TURN'ü destekliyordu ama üç boşluk vardı ve hiçbiri
kullanıcıya görünmüyordu.

### T-01 · Kullanıcı IP'sinin açık olduğunu göremiyordu
`hasRelay` alanı hiçbir yerde arayüze yansımıyordu. Uygulama "anonim"
diye kurulup aramada karşı tarafa IP veriyor, kullanıcı bunu **hiçbir
şekilde** öğrenemiyordu.

→ Arama ekranında rozet: 🔒 *IP adresin gizli (relay)* / ⚠️ *IP adresin
karşı tarafa görünüyor*. Gösterge tahmin değil: `iceTransportPolicy:
relay` açıkken yalnızca relay adayları toplandığı için bağlantı
kurulduysa medya **kesinlikle** relay üzerindedir.

### T-02 · Kalıcı TURN parolası APK'ya gömülüyordu
`--dart-define` ile verilen parola derlenmiş pakette durur ve
**çıkarılabilir** — Giphy anahtarıyla (H-19) birebir aynı sorun. Sonuç:
sunucuyu herkes kullanabilir (bant genişliği hırsızlığı) ve parolayı
döndürmek **yeni sürüm yayınlamayı** gerektirir.

→ `getTurnCredentials` callable function'ı, coturn'ün `use-auth-secret`
şemasıyla kısa ömürlü (varsayılan 12 saat) kimlik üretir:

```
username = <bitiş-zaman-damgası>:<opak-kimlik>
password = base64(HMAC-SHA1(TURN_SECRET, username))
```

Sır **yalnızca sunucuda** durur. Statik `--dart-define` yolu yedek
olarak korundu ama artık açıkça "önerilmez" diye işaretli.

**Gizlilik ayrıntısı:** kullanıcı adında uid KULLANILMAZ, rastgele opak
bir değer üretilir. TURN sunucusu zaten iki tarafın IP'sini görür; oraya
bir de hesap kimliği yazmak IP ile hesabı kalıcı olarak ilişkilendirirdi.
Aynı nedenle hesap değişiminde kimlik düşürülür — aksi halde TURN
sunucusu "bu iki hesap aynı cihaz" çıkarımını yapabilirdi.

### T-03 · Tek URL — kısıtlı ağlarda arama hiç kurulmuyordu
`_turnUrl` tek bir string'di. Kurumsal/kısıtlı ağlar UDP'yi ve 3478'i
kapatır; `turns:...:443?transport=tcp` yedeği olmadan o ağlarda arama
**hiç** kurulamaz.

→ Çoklu URL desteği (hem sunucudan gelen listede hem `--dart-define`
içinde virgülle ayrılmış). Kurulum dokümanı 443/TCP'yi listenin başına
koymayı açıkça söyler.

### T-04 · TURN erişilemezliği "arama kurulamadı" diye kayboluyordu
`relay` politikasında tek aday kaynağı TURN'dür. Sunucu kapalıysa ICE
hiç aday bulamaz ve arama ayırt edilemez şekilde başarısız olur.

→ `onIceConnectionState` failed + relay aktif → ayrı bir hata:
☁️ *Relay sunucusuna ulaşılamıyor*. Bu, yanlış yerde saatlerce hata
aramayı önler.

### Bozulmama garantileri
* TURN yapılandırılmamışsa function **hata fırlatmaz**, `configured:
  false` döner — aksi halde TURN kurmamış bir projede TÜM aramalar
  kırılırdı.
* Kimlik alınamazsa STUN'a düşülür: IP görünür ama arama **kurulur**.
* **Geçici** ağ hatasıyla **kesin** "yapılandırılmamış" cevabı ayrılır.
  İkisi aynı sayılsaydı tek bir ağ tökezlemesi, oturumun kalanındaki tüm
  aramaları IP'si açık hâle getirirdi.
* Eksik alan gelirse relay denenmez: `iceTransportPolicy: relay` +
  geçersiz kimlik = **hiç kurulamayan** arama.

**Doğrulama:** 7 yeni birim testi (toplam **90** Dart testi). En kritiği
"TURN varken iceTransportPolicy MUTLAKA relay olur" — `all`a düşerse
WebRTC host adaylarını da toplar ve relay kurulu olsa bile IP sızar.

> ⚠️ **Sunucu hâlâ kurulmadı.** Bu bölüm uygulama tarafını anlatır;
> relay gerçekten çalışana kadar aramalar P2P kurulur ve IP'ler
> karşılıklı görünür. Kurulum: `TURN_KURULUMU.md`.

---

## 4g. DH RATCHET + İMZALI ÖN-ANAHTAR ROTASYONU (yeni)

`lib/services/double_ratchet_service.dart` · `e2ee_session_service.dart` ·
`x3dh_service.dart` · `key_management_service.dart` · `functions/index.js`

### 🐞 D-01 · SPK rotasyonunda SESSİZ uyuşmazlık (önce bulundu, önce düzeltildi)

DH ratchet'in başlangıç adımı imzalı ön-anahtara (SPK) dayanır; oraya
bakarken **canlı bir hata** ortaya çıktı.

`_republishPreKeys()` — ön-anahtarlar azalınca çalışır — SPK'yı yeniliyor
ve **eski özel anahtarı siliyordu**. Sıralama şöyle bozuluyordu:

1. Alice, Bob'un paketini alır (SPK_eski ile ortak sır türetir).
2. Bob uygulamayı açar; ön-anahtarları azalmıştır → SPK yenilenir,
   **SPK_eski'nin özel kısmı silinir**.
3. Alice'in mesajı ulaşır. Bob X3DH'i **SPK_yeni** ile karşılar; DH1 ve
   DH3 tutmaz → taraflar **farklı ortak sır** türetir.

Sonuç: **hiçbir hata verilmeden** o sohbetteki tüm mesajlar çözülemez
hâle geliyordu. Bob günlerce çevrimdışı kalabildiği için pencere geniş;
kullanıcıya görünen belirti "sohbet bir gün kendiliğinden bozuldu".

Bu, denetimde yakalanan **sessiz anahtar uyuşmazlığının** (X3DH #2) tek
kullanımlık ön-anahtar yerine SPK'da tekrar eden hâliydi.

→ Paket artık `signedPreKeyId` taşır, X3DH başlığı hangi SPK'nın
kullanıldığını söyler ve **önceki SPK saklanır**. Kimlik verilmiş ama
hiçbir anahtarla eşleşmiyorsa oturum sessizce kurulmaz, açıkça hata
verilir.

### G-03 · DH ratchet — post-compromise security

**Önce:** yalnızca simetrik zincir vardı. Forward secrecy sağlanıyordu
(eski mesajlar yeni anahtardan çözülemez) ama **break-in recovery
yoktu**: saldırgan cihazdaki zincir anahtarını bir kez ele geçirirse o
sohbetin **sonraki tüm mesajlarını süresiz** okuyabiliyordu.

**Şimdi:** Signal'in DH ratchet'i. Her mesaj başlığı gönderenin güncel DH
açık anahtarını taşır; karşı taraftan **yeni** bir DH anahtarı görülünce
kök anahtardan yeni zincirler türetilir ve kendi DH çiftimiz yenilenir.
Saldırgan bir anlık durumu ele geçirse bile, iki tur karşılıklı
mesajlaşmadan sonra yeni DH sırrını bilemediği için **dışarıda kalır**.

*Test: "saldırgan çalınan durumla SONSUZA KADAR okuyamaz" — çalınan
durumun ÖNCE gerçekten okuyabildiği de doğrulanır; yoksa sonraki
başarısızlık hiçbir şey kanıtlamazdı.*

### Bozulmama garantileri (en büyük risk buydu)

Denetimin en pahalı hataları (C-08, C-09) tam olarak "ratchet değişikliği
mevcut sohbetleri kırdı" sınıfındaydı. Bu yüzden:

* **v2 yolu KALDIRILMADI.** Sahadaki oturumlarda kök anahtar yoktur ve
  sonradan türetilemez (X3DH anında üretilir). Eski oturumlar v2'de
  çalışmaya devam eder; ayrım `SessionState.isDhRatchet` ile yapılır.
* **Sürüm anlaşması var.** İstemci `keyBundles.ratchetVersion` yayınlar;
  karşı taraf desteklemiyorsa v3 oturum **kurulmaz**. Eski bir istemciye
  v3 paket göndermek o sohbeti tamamen kırardı.
* **Sürüm PAKETTEN okunur**, oturumdan değil: yolda kalmış bir v2 paketi
  v3 oturumda da doğru yolla çözülür.
* **Atlanan anahtarlar zincir bazında saklanır.** Yalnızca mesaj numarası
  kullanılsaydı, her DH adımında numaralar sıfırlandığı için farklı
  zincirlerin "5" numaralı mesajları birbirini ezerdi.
  *Test: "atlanan anahtar kimliği zinciri de içerir"*
* **Zincir değişiminde eski zincirin kalan anahtarları saklanır** (`pn`
  alanı). Aksi halde yolda olan mesajlar kalıcı kayıp olurdu.
  *Test: "ÖNCEKİ zincirden geç gelen mesaj kaybolmaz"*
* **DoS sınırı korundu**: `maxSkip` aşan mesaj numarası reddedilir.

### Bilinen davranış (hata değil)
Cevaplayan taraf, karşı taraftan **ilk mesajı almadan gönderemez** —
gönderme zinciri o anda kurulur. Signal'de de böyledir. Grup anahtarı
dağıtımı bu duruma denk gelirse artık günlüğe açık bir satır düşer;
eskiden sessizce atlanıyordu.

**Doğrulama:** 11 yeni birim testi (toplam **101** Dart testi).

---

## 4h. DÜZENLENEN MESAJLAR ARTIK ŞİFRELİ (yeni)

`message_repository_impl.dart` · `message_remote_datasource.dart` ·
`message_model.dart` · `e2ee_session_service.dart`

**Önce — İKİ ayrı bozukluk aynı anda:**

1. **Düzenlenen metin Firestore'a DÜZ yazılıyordu.** Yani bir mesajı
   düzeltmek, onu sunucuya açık göndermek demekti. Kullanıcı için bu en
   ters yerde olan sızıntıdır: insanlar mesajı çoğu zaman **yazdıkları
   bir şeyi geri almak için** düzenler.

2. **Alıcı düzenlemeyi HİÇ görmüyordu.** `isE2EE` bayrağı
   değiştirilmiyordu (kodda o satır hiç yoktu — dokümanda "isE2EE=false
   işaretlenir" yazsa da). Sonuç:
   * Mesajı daha önce çözmüş alıcı, düz metin önbelleği mesaj kimliğiyle
     anahtarlandığı için **eski metni** görmeye devam ediyordu.
   * Önbelleği olmayan alıcı ise düz metni ratchet'le çözmeye çalışıp
     **"çözülemedi"** görüyordu.

   Yani özellik yalnızca gönderenin kendi ekranında çalışıyordu.

**Kod içindeki gerekçe yanlıştı.** "E2EE ratchet düzenlemeyi
DESTEKLEMEZ" deniyordu; oysa düzenleme yalnızca **yeni bir ratchet
mesajıdır**. Tek gereken, alıcının onu yeniden çözmesidir.

**Şimdi:**
* Düzenleme, ratchet'te yeni bir mesaj olarak şifrelenir; Firestore'a
  şifreli metin gider.
* Düz metin önbelleği artık `<mesajId>#<düzenlemeZamanı>` ile
  anahtarlanır → alıcı yeni içeriği yeniden çözer.
* Şifrelenemiyorsa (oturum yok / grupta anahtar dağıtılamadı) içerik
  açık yazılır ama `isE2EE` **false** olarak işaretlenir — arayüz artık
  yanıltıcı kilit simgesi göstermez. (Bu, belgelenmiş ama hiç
  yazılmamış davranıştı.)
* `editedAt` alanı Firestore'a yazılıyor ama modele **hiç okunmuyordu**;
  artık okunuyor.

### 🔒 Silme yollarıyla uyum — C-07 tekrarını önleme
Düzenlenen metin ayrı bir anahtarda saklandığı için, yalnızca ham mesaj
kimliğini silmek yetmezdi: "kaybolan mesaj" ve "herkesten sil"
işlemlerinden sonra **düzenlenmiş metin cihazda okunabilir kalırdı** —
C-07 ile birebir aynı hata.

→ `forgetPlaintext` artık `<mesajId>#` önekli tüm sürümleri de siler
(bellek içi memo dahil).
*Testler: "forgetPlaintext DÜZENLEME SÜRÜMLERİNİ de siler",
"benzer kimlikli mesaj yanlışlıkla silinmez" (m1 silinirken m10 gitmez)*

### Yan bulgu: `deleteByPrefix` yarıda kalabiliyordu
Silme, `readAll()` sonucunun anahtarları üzerinde **dönerken** siliyordu.
Canlı bir görünüm döndüren bir uygulamada bu
`ConcurrentModificationError` üretir ve silme yarıda kalır — üstelik
hata yutulduğu için sessizce. Artık anahtarların kopyası üzerinde
dönülüyor.

**Doğrulama:** 10 yeni test (toplam **111** Dart testi). En kritiği
"düzenlenen metin SUNUCUYA DÜZ GİTMEZ".

---

## 4i. KURAL ↔ İSTEMCİ ↔ FONKSİYON TUTARLILIK TARAMASI (yeni)

Bu projede **aynı sınıftan altı hata** çıktı: bir katman bir alana
dayanıyor, başka bir katman onu hiç yazmıyor/okumuyor.

| | Bulgu |
|---|---|
| C-09 | Kural ön-anahtar tüketimini reddediyordu → E2EE oturumu HİÇ kurulamıyordu |
| R-01 | Kural `adminUids`/`mutedUids` okuyordu, hiçbir Dart kodu yazmıyordu |
| R-02 | Arama ekranı `chats` sorguluyordu, kural yalnızca `channels` diziniyle izin veriyordu |
| H-05 | Function `isEncrypted`, istemci `isE2EE` yazıyordu |
| §4g | Başlık hangi SPK'nın kullanıldığını söylemiyordu → sessiz uyuşmazlık |
| §4h | `isE2EE=false` belgelenmişti ama HİÇ yazılmıyordu; `editedAt` yazılıyordu ama HİÇ okunmuyordu |

Yayın öncesi bu eksen **sistematik olarak** tarandı.

### Tarama 1 — kuralların dayandığı 46 alan
Her alan için "bunu kim yazıyor?" soruldu. **İki alanın hiçbir üreticisi
yoktu** — ama R-01'in tersi yönde: kural bu alanları *okumuyor*,
**yazılmasına izin veriyordu**.

* `chats.typingUids` — "yazıyor" durumu aslında `users/{uid}.typingIn`de
* `callLogs.seenBy` — çağrı "görüldü" durumu aslında CİHAZDA
  (SharedPreferences)

Kimse okumadığı için mantığı etkilemiyordu; ama her üyeye o dokümana
**istediği veriyi yazma** kapısı bırakıyordu. Firestore dokümanı 1 MiB'a
kadar şişirilebilir ve o dokümanı her üye her okumada indirir — sessiz
bir maliyet/DoS yüzeyi. **İzinler kaldırıldı.**
*Testler: "üye sohbete typingUids YAZAMAZ", "katılımcı çağrı kaydına
seenBy YAZAMAZ", "izinli alan hâlâ yazılabilir (aşırı kısıtlama yok)"*

### Tarama 2 — Cloud Functions'ın okuduğu alanlar
Üç aday çıktı, üçü de zararsız: biri yanlış pozitif (`attempts` — kısa
gösterimle fonksiyonun kendisi yazıyor), ikisi ölü yedek yol
(`imageUrl`, `mediaUrlBackup`). Alan adı uyuşmazlığı **yok**.

### 🐞 Tarama 3 — istemcinin sohbet dokümanına yazdıkları
Burada **gerçek bir hata** çıktı.

`DirectChatService.getOrCreate`, sohbet dokümanına koşulsuz olarak
`memberUsernames` yazıyordu. Kural bunu MEVCUT bir sohbette reddeder —
ve **haklı olarak**: sohbet listesi karşı tarafın adını bu diziden okur,
yani izin verilseydi bir üye kendini karşı tarafın listesinde
*"SECRETER Destek"* gibi gösterebilirdi.

Sorun kuralda değil, yazının koşulsuz yapılmasındaydı. Doküman farklı
bir kullanıcı adı listesiyle oluşmuşsa — en olası sebep: **ilk yazım
sırasında kendi profilimiz henüz yüklenmemiş ve `me?.username` boş
kalmış** — çağrı `permission-denied` alıyor ve o sohbet **kalıcı olarak
açılamıyordu**. Her denemede aynı hata; kurtarma yolu yok.

Etkilenen akışlar: aramadan sohbet başlatma, hikâyeye yanıt verme.

→ İstemci artık bu durumu ele alıyor: sohbet zaten varsa kimliğini
döndürüyor. Kullanıcı adı dizisi bayat kalabilir (listede eski ad
görünür) ama bu görsel bir eksiklik; sohbeti tamamen erişilemez
yapmaktan kıyaslanamayacak kadar iyidir.
*Testler: "mevcut sohbette memberUsernames ÜZERİNE YAZILAMAZ",
"yalnızca izinli alanları yazmak GEÇER"*

### Tarama 4 — Storage yolları
İstemcinin yüklediği dört yolun (`avatars/`, `chats/`,
`group_avatars/`, `stories/`) dördü de kurallarda tanımlı. Sahipsiz yol
**yok** — C-02'de bulunan "kuralı olmayan yola yükleme sessizce
başarısız oluyor" durumu tekrarlamıyor.

**Doğrulama:** kural testleri 61 → **66**.

---

## 4j. KALİTE VE SERTLEŞTİRME TURU (yeni)

Şifreleme kapsamı tamamlandıktan sonra kod tabanı bir de "sessiz
bozukluk" gözüyle tarandı.

### 🐞 K-01 · await sonrası BuildContext — üç gizli çökme
Bir `await` sonrasında `context` kullanmak, widget o sırada yok
edilmişse (rota kapandı, derin bağlantı başka ekrana geçirdi) istisna
fırlatır. Üç yerde koruma yoktu:

* `messaging_screen` — büyük video uyarısı beklenirken ekran kapanırsa
* `accounts_screen` — `canAddAccount()` beklenirken (erken çıkış yolunda
  kontrol VARDI, düşen yolda yoktu)
* `story_viewer_screen` — hikâye yanıtı kutusu açıkken hikâye kapanırsa

→ Üçüne de `mounted` kontrolü eklendi.

### 🐞 K-02 · Gizlilik ayarı sessizce uygulanmıyordu
`PrivacyController._persist()` içinde `PrivacySettingsReader.update()`
çağrısı, Hive yazımıyla **aynı try bloğundaydı** ve blok
`catch (_) {}` ile bitiyordu.

Hive hata verdiğinde (kutu açılamadı, disk dolu, şifreleme anahtarı
sorunu) okuyucu güncellenmiyordu. Repository'ler ayarları o okuyucudan
okuduğu için sonuç şuydu: **kullanıcı arayüzde "okundu bilgisi kapalı"
görürken uygulama okundu bilgisi göndermeye devam ediyordu** — hiçbir
iz bırakmadan. Gizlilik odaklı bir uygulamada kabul edilemez.

→ Okuyucu artık yazımdan ÖNCE güncelleniyor (seçim o oturumda kesin
uygulanır), hata da günlüğe düşüyor. `_load` içinde de aynı hizalama
yapıldı.

### K-03 · Güvenlik dedektörleri sessizce çökebiliyordu
`SecurityServiceImpl` beş tehdit dedektörünü ayrı ayrı `try` içine
alıyordu — doğru tasarım (biri patlarsa tarama tamamen düşmesin). Ama
hepsi `catch (_) {}` ile sessizdi: kalıcı olarak başarısız olan bir
dedektör, uygulamanın "tehdit yok" demesine yol açıyor ve bu hiçbir
yerde görünmüyordu. **Tarayıcının çalışmaması, tehdit bulmamasıyla aynı
şey değildir.**

→ Ortak `_run(ad, kontrol)` yardımcısına çıkarıldı; davranış aynı, hata
artık adıyla günlüğe düşüyor.

### K-04 · Analyzer tamamen temizlendi (259 → 0)
237'si `prefer_const_constructors` olan bulgular, gerçek uyarıların
içinde kaybolduğu bir gürültü katmanıydı. Otomatik düzeltmelerle
(`dart fix`) ve elle üç deprecated API göçüyle (Radio → `RadioGroup`,
`activeColor` → `activeThumbColor`) sıfıra indirildi.

**Neden önemli:** artık yeni bir uyarı ANINDA görünür. 259 satırlık
listede yeni bir `use_build_context_synchronously` fark edilmezdi.

### K-05 · Test kapsamı — kritik servisler
Kripto servislerinin bir kısmının HİÇ testi yoktu. İkisi eklendi:

* **Kurtarma anahtarı (9 test)** — H-18'in özü ölçülüyor: anahtarı ele
  geçirmek tek başına yetmemeli. Yanlış parola reddi, kurcalanmış
  anahtar reddi, kodlanmış metnin hesabı açıkça taşımaması, aynı hesabın
  her seferinde farklı anahtar üretmesi (sabit tuz/nonce olsaydı iki
  anahtar eşleştirilebilirdi).
* **Grup E2EE (8 test)** — çözme yolu, sırasız mesaj, başka gönderenin
  zinciriyle çözülememesi, hesap kapsamı sızıntısı ve **birebir mesaj
  paketinin grup zarfı sanılmaması** (yanlış pozitif o sohbeti tamamen
  çözülemez yapardı).
* **Derin bağlantı (7 test)** — dışarıdan kontrol edilen tek girdi.
  Doğrulama saf bir fonksiyona (`parseInviteCode`) çıkarıldı ki
  ölçülebilsin: yabancı şema/host reddi, yol gezinme (`..`, `a/b`),
  uzunluk sınırları ve boşluk davranışı. C-11'de kilit atlatan akışın
  giriş kapısı burasıydı; kod ayrıca doğrudan Firestore doküman kimliği
  olarak kullanılıyordu.

### Taranıp temiz çıkanlar
* **Kaynak sızıntısı:** tüm `State` sınıflarında abonelik/controller/timer
  alanları `dispose` içinde kapatılıyor — sıfır bulgu.
* **`main.dart` içindeki sessiz yakalamalar:** bunlar hata
  işleyicilerinin İÇİNDE; orada yutmak doğrudur (özyineleme ve asıl
  hatanın maskelenmesi riski). Dokunulmadı.

**Doğrulama:** Dart testleri 111 → **135**, analyzer **0 bulgu**.

---

## 4k. METADATA GİZLİLİĞİ — 1. AŞAMA (yeni)

`message_model.dart` · `message_repository_impl.dart` ·
`services/username_resolver.dart` · `scheduled_message_service.dart` ·
`functions/index.js`

### Sorun: içerik şifreliydi, GRAFİK değildi

Her mesaj Firestore'a `senderUsername` alanını **düz metin** yazıyordu.
Sohbet dokümanında `memberUsernames`, mesajda `readBy` ve zaman damgası
da açıktı. Yani sunucuya (ve konsola erişen herkese) şu görünüyordu:

```
@ayse → @mehmet   14:32   okundu 14:33
```

İçerik okunamıyordu ama **sosyal grafiğin tamamı, gerçek kullanıcı
adlarıyla** açıktı. Telefon numarası istemeyen, anonimlik vaat eden bir
uygulamada asıl açık buydu — Signal'in "sealed sender" ile yıllarca
uğraştığı alan.

### Bu aşamada yapılan

* `senderUsername` **artık sunucuya yazılmıyor**. Ad, gösterim anında
  uid'den çözülür (`UsernameResolver`, süreç ömrü boyunca önbellekli;
  bir sohbetin göndereni birkaç kişi olduğu için ilk açılıştan sonra ağ
  isteği yapılmaz).
* Zamanlanmış mesajlar da alanı yazmıyor; Cloud Function da mesaj
  dokümanına geri koymuyordu — o da kaldırıldı.
* **Push bildirimi başlığı nötrleştirildi.** Birebir bildirim başlığı
  `"@kullanıcıadı"` idi: gönderenin adı hem **FCM üzerinden Google'a**
  hem de **kilit ekranına** çıkıyordu. İçerik zaten maskeliyken
  (`🔒 Mesaj`) başlığın adı taşıması tutarsızdı.

### Geriye uyumluluk
`fromMap` alanı OKUMAYA devam eder: bu değişiklikten önce yazılmış
mesajlarda dolu ve orada bırakılır — eski sohbetler adsız kalmaz.
*Testler: "ESKİ mesajlardaki ad okunmaya devam eder", "DOLU ad EZİLMEZ"*

### ⚠️ Ne KAZANILMADI (dürüstlük)
Bu **birinci aşamadır**. Sunucuda hâlâ açık olanlar:

* `senderId` (uid) — kural motoru yazarlık denetimini bununla yapıyor
* `memberIds` ve `memberUsernames` (sohbet dokümanında)
* `readBy`, zaman damgaları, mesaj sayısı/sıklığı

Kazanılan şey, grafiğin **adlarla doğrudan okunabilir** olmaktan
çıkmasıdır: veritabanına bakan biri artık uid'leri ayrıca eşlemek
zorundadır. Sonraki aşamalar:

1. `memberUsernames`'i sohbet dokümanından kaldırmak (sohbet listesi,
   @bahsetme kaynağı ve `isSelfJoin` kuralı birlikte değişmeli)
2. `users/{uid}` okumasını ortak sohbeti olanlara kısıtlamak — şu an
   **her oturum açmış kullanıcı tüm profilleri okuyabiliyor**
3. `senderId` yerine sohbet-içi takma kimlik (sealed-sender benzeri) —
   kural motoru yazarlığı doğrulamak zorunda olduğu için en zoru

**Doğrulama:** 8 yeni test (toplam **150**). En kritiği "gönderen ADI
sunucuya YAZILMAZ" — alan geri gelirse grafik yine adlarla okunur olur.

---

## 4l. KULLANICI NUMARALANDIRMA KAPATILDI (yeni)

`firestore.rules` · `auth_service.dart`

### Sorun
`users` koleksiyonunun kuralı `allow read: if signedIn()` idi. Firestore'da
`read`, tekil okumayı (**get**) VE sorguyu (**list**) birlikte kapsar.
Yani giriş yapmış herhangi biri şunu yazabiliyordu:

```dart
FirebaseFirestore.instance.collection('users')
    .orderBy('username').limit(1000).get();
```

ve **tüm kullanıcı tabanını** dökebiliyordu: kullanıcı adları, çevrimiçi
durumları, avatarlar, biyografiler. Telefon numarası istemeyen bir
uygulamada bu, "kim bu uygulamada kayıtlı?" sorusunun herkese açık
olması demekti — anonimlik iddiasıyla doğrudan çelişir.

Anonim kayıt olduğu için saldırganın maliyeti de sıfırdı.

### Çözüm
```
allow get:  if signedIn();   // uid gerekir
allow list: if false;        // döküm YOK
```

`get` bilinçli olarak korundu: avatar, çevrimiçi durumu ve (§4k'den
sonra) ad çözümü bununla çalışır. Profil okumak için **uid** gerekir ve
uid tahmin edilemez — ancak ortak bir sohbetten ya da ad dizininden
öğrenilir.

### Arama nasıl çalışmaya devam ediyor
Ada göre arama zaten var olan **`usernames/{ad}`** dizini üzerinden
yapılıyor (doküman kimliği = küçük harfli kullanıcı adı). Bu koleksiyon
kayıt sırasında atomik rezervasyon için kuruluydu ve kuralı zaten
doğruydu: `get` açık, `list` KAPALI, `create` yalnızca kendi uid'inle ve
yalnızca doküman yoksa.

Yani arama tek bir doküman okuması oldu — sorgu değil. Numaralandırma
için oradan da bir kapı yok.

**Dizin doğrulaması:** dizin istemciden yazıldığı için `findUserByUsername`
artık profildeki adın dizindeki adla tuttuğunu KONTROL EDİYOR. Aksi
halde biri `usernames/banka` dokümanını kendi uid'siyle oluşturup
başkası gibi görünmeye çalışabilirdi.

### Yan temizlik
`isUsernameAvailable` içindeki `users` sorgusu kaldırıldı — aynı kontrolü
`usernames` dizini zaten ve daha güvenilir yapıyordu (rezervasyonun tek
doğruluk kaynağı odur). Yan kazanç: kayıt yarıda kalıp `users` dokümanı
oluşmuş ama ad rezerve edilememişse kullanıcı artık aynı adla tekrar
deneyebiliyor.

**Doğrulama:** 5 yeni kural testi (toplam **71**):
"kullanıcı listesi DÖKÜLEMEZ", "ada göre SORGU da çalışmaz",
"uid BİLİNİYORSA profil okunabilir", "ad dizini tekil okunur ama
DÖKÜLEMEZ", "BAŞKASININ adına dizin kaydı açılamaz".

---

## 4m. 🐞 KURALLAR DAĞITILDI — VE GİZLİ BİR KIRIK ORTAYA ÇIKTI

Kurallar 2026-08-29'da ilk kez üretime dağıtıldı
(`firebase deploy --only firestore:rules`, proje `gizlichat-f2a99`).
Bu, denetimdeki TÜM kural düzeltmelerinin nihayet aktif olması demek —
C-12'nin kapanışı.

Dağıtımdan hemen sonra cihaz günlüğünde şu belirdi:

```
Listen for Query(calls where calleeId==<uid> and status==ringing)
  failed: PERMISSION_DENIED
```

### Ne oldu
`calls` koleksiyonunda kural şöyleydi:
```
allow list: if false;      // "arama dökümü yok"
```
Niyet doğruydu (kimse tüm aramaları dökemesin) ama **istemci gelen
aramayı bulmak için listelemek ZORUNDA**:

```dart
calls.where('calleeId', isEqualTo: myUid)
     .where('status', isEqualTo: 'ringing')
```

Sonuç: gelen arama dinleyicisi izin alamıyor, kullanıcı **hiç arama
alamıyordu**. Bu, denetimin en sık tekrarlayan hata sınıfının
(C-09, R-01, R-02, §4i) bir örneği daha — ve yalnızca kurallar
GERÇEKTEN dağıtıldığı için görünür oldu. Emülatör testleri bunu
yakalayamamıştı çünkü o sorgu için test yoktu.

### Düzeltme
```
allow list: if callParty();
```
Doğru kısıt "listeleme yok" değil, **"yalnızca kendi araman"**. Firestore
list kuralını dönen HER dokümana uygular; tüm aramaları dökmeye çalışan
bir sorgu içinde bize ait olmayan doküman bulunacağı için yine
reddedilir.

*Testler (4 yeni): "kendi gelen aramalarını LİSTELEYEBİLİR", "arayan da
kendi aramalarını görebilir", "TÜM aramalar DÖKÜLEMEZ", "BAŞKASININ
aramaları listelenemez". Kural testleri 71 → **75**.*

### Ders
Emülatör testi ancak **yazdığın sorgu kadar** kapsar. Bir koleksiyona
`list: false` koymadan önce, istemcinin o koleksiyonu sorgulayıp
sorgulamadığı taranmalıdır. Bu bulgudan sonra istemcideki tüm liste
sorguları (`callLogs`, `calls`, `channels`, `chats`, `stories`) kurallara
karşı tek tek denetlendi; `calls` dışında uyumsuzluk yok.

### ⚠️ Hâlâ DAĞITILMAMIŞ olanlar
```bash
firebase deploy --only firestore:indexes    # indeksler
firebase deploy --only storage              # Storage kuralları
firebase deploy --only functions            # getTurnCredentials + bildirim değişiklikleri
firebase deploy --only hosting              # gizlilik politikası sayfaları
```
Özellikle **functions**: §4k'deki bildirim başlığı düzeltmesi ve
zamanlanmış mesajlardan ad kaldırma, fonksiyonlar dağıtılana kadar
üretimde ETKİLİ DEĞİLDİR.

---

## 4n. FONKSİYONLAR VE İNDEKSLER DAĞITILDI — "hiç aktif değildi" DOĞRUYMUŞ

2026-08-29. Kuralların ardından Cloud Functions ve Firestore indeksleri
de dağıtıldı. Çıktı, dokümandaki uyarının bir tahmin değil **ölçülmüş
gerçek** olduğunu gösterdi.

### 🐞 Bulgu: fonksiyonların ÇOĞU üretimde hiç yoktu

Dağıtım çıktısında "updating" değil **"creating"** yazanlar:

| Fonksiyon | Neyi çözüyordu |
|---|---|
| **`claimPreKey`** | **C-09** — E2EE ön-anahtar tüketiminin sunucuda atomik yapılması |
| **`syncChannelDirectory`** | **R-02** — kanal arama dizini |
| `deleteAccountData` | H-22 — KVKK/GDPR hesap silme |
| `cleanupStaleCalls`, `cleanupReleasedUsernames`, `cleanupSoftDeletedMedia` | H-10/H-11 temizlik işleri |
| `getTurnCredentials` | §4f — TURN kimliği |

`claimPreKey` özellikle ağır: C-09'un çözümü buydu ve fonksiyon hiç
dağıtılmadığı için **üretimde E2EE oturumu kurulamıyordu**. Aynı şekilde
`syncChannelDirectory` olmadan kanal araması da çalışmıyordu.

### 🐞 Dağıtımı engelleyen iki ayrı arıza

**1. `npm ci` kırıktı.** `package.json` ile `package-lock.json` senkron
değildi (`eslint@9` lock dosyasında yoktu). `firebase.json` predeploy
hook'u tam olarak `npm ci` çalıştırdığı için dağıtım **hiç
başlayamıyordu**. Lock dosyası `--package-lock-only` ile senkronlandı
(node_modules'e dokunulmadan). Aynı arıza CI'yı da düşürür.

**2. Modül yüklenemiyordu.** Dağıtım şu hatayla düşüyordu:

```
User code failed to load. Cannot determine backend specification.
Timeout after 10000.
```

Hangi fonksiyonun sorunlu olduğunu söylemiyor. Kod yerelde yüklenince
sebep çıktı:

```js
const bucket = admin.storage().bucket();   // MODUL SEVIYESINDE
```

`admin.storage().bucket()`, ortamda `storageBucket` yapılandırılmamışsa
**fırlatır**. Firebase CLI dağıtımdan önce kodu analiz için yerel bir
süreçte yükler; orada bucket adı bulunmadığı için modül yüklenemiyordu.

→ Tembel hale getirildi (`storageBucket()` yardımcısı, ilk kullanımda
alınır). Artık yapılandırma olmadan da yükleniyor. Yalnızca medya silme
yolunda gerekli olduğu için maliyet yok.

### 🐞 İndeksler de hiç dağıtılmamıştı
Fonksiyon dağıtımından sonra cihaz günlüğünde:

```
Query(chats where memberIds array_contains <uid> order by -lastMessageTime)
  failed: FAILED_PRECONDITION — The query requires an index
Query(callLogs where participants array_contains <uid> order by -createdAt)
  failed: FAILED_PRECONDITION — The query requires an index
```

Yani **sohbet listesi ve arama geçmişi** üretimde çalışmıyordu —
uygulamanın ana ekranı boş geliyordu. `firestore.indexes.json` doğru
tanımlıydı, sadece dağıtılmamıştı. Dağıtıldı (indeks oluşturmak veriye
dokunmaz); Firestore indeksleri arka planda inşa eder.

### Dağıtım durumu
| | Durum |
|---|---|
| `firestore:rules` | ✅ dağıtıldı (75 test) |
| `functions` | ✅ 13 fonksiyon dağıtıldı |
| `firestore:indexes` | ✅ dağıtıldı ve inşa TAMAMLANDI (cihazda doğrulandı: indeks hatası 0) |
| `storage` | ❌ **hâlâ dağıtılmadı** — C-02'nin medya erişim düzeltmesi aktif DEĞİL |
| `hosting` | ❌ gizlilik politikası sayfaları |

### Ders
"Kod düzeltildi" ile "düzeltme aktif" arasındaki fark bu projede
defalarca kanıtlandı. Dağıtım, kodun kendisi kadar denetlenmelidir:
`claimPreKey` deponun içinde aylardır duruyordu ve üretimde yoktu.

---

## 4o. METADATA GİZLİLİĞİ — 2. AŞAMA: ÜYE ADLARI SOHBET DOKÜMANINDAN ÇIKTI

`firestore.rules` · `conversation_entity.dart` ·
`conversation_repository_impl.dart` · `group_entity.dart` ·
`group_model.dart` · `group_repository_impl.dart` ·
`direct_chat_service.dart` · `channel_search_screen.dart` ·
`messaging_screen.dart` · `group_info_screen.dart` ·
`services/chat_metadata_scrub.dart` · `core/di/injection.dart`

### Sorun: mesajdan adı kaldırmak yetmiyordu

1. aşamada (§4k) `senderUsername` mesajlardan kaldırılmıştı. Ama sohbet
dokümanının kendisi hâlâ şunu taşıyordu:

```
chats/uidA_uidB
  memberIds:       ["uidA", "uidB"]
  memberUsernames: ["ayse", "mehmet"]     ← düz metin
```

Grup ve kanallarda ad **ikinci** bir yerde daha duruyordu:

```
  members: [ {uid: "uidA", username: "ayse", role: "owner", ...}, ... ]
```

Yani mesajlardan adı silmenin kazandırdığı şey burada geri veriliyordu:
veritabanına bakan biri uid eşlemesi yapmadan, doğrudan **kimin kiminle
yazıştığını** ve **hangi grupta kimlerin olduğunu** adlarıyla okuyordu.
Bir sohbet dokümanı zaten iki tarafı yan yana tutar; adlar da orada
durunca sosyal grafik tek koleksiyondan dökülebiliyordu.

### Bu aşamada yapılan

**1. İstemci artık ad yazmıyor.** Beş yazma noktası temizlendi: birebir
sohbet oluşturma, grup oluşturma, kanal oluşturma, davet koduyla
katılma, kanal aramasından katılma. Üyeliğin tek gösterimi `memberIds`.
`members[]` girdileri de artık adsız yazılır.

**2. Ad gösterim anında uid'den çözülüyor.** 1. aşamadan gelen
`UsernameResolver` yeniden kullanıldı. Domain varlıkları Firestore'a
bağlanmasın diye çözüm bir **fonksiyon kancası** olarak dışarıdan takılır
(`initDependencies` → `ConversationEntity.nameResolver`,
`GroupMemberEntity.nameResolver`). Varlıklar saf kalır; birim testleri
Firebase istemez.

Ağ okuması **çizimden önce** yapılır (`UsernameResolver.warm`): sohbet
listesi deposu birebir sohbetlerin karşı taraflarını, grup deposu üye
uid'lerini toplu ısıtır. Böylece senkron çizim yolunda ad hazırdır,
başlık önce "Sohbet" görünüp sonradan zıplamaz.

İki yerde ad zaten **biliniyor** ve ağ isteği hiç yapılmaz: birebir
sohbet açılışında (kullanıcı karşı tarafı arayıp buldu) ve grup
kurulumunda (üyeleri kullanıcı seçti) — isimler yerel önbelleğe
tohumlanır, sunucuya yazılmaz.

**3. Sıra: canlı çözüm > eski dizi.** Eski dizi **bayat kalabiliyordu**
(kullanıcı adını değiştirdiğinde sohbet dokümanı güncellenmiyordu);
`users/{uid}` güncel adı verir. Dizi yalnızca çözüm başarısızsa
kullanılır — eski sohbetler adsız kalmaz.

**4. Kural sunucuda kapatıyor.** İstemciden kaldırmak tek başına yetmez:
değiştirilmiş ya da eski bir istemci alanı geri yazabilirdi.

```
allow create: ... && noUsernameArray();
allow update: if signedIn() && usernameArrayNotGrown() && ( ... );
```

Kısıt **dört güncelleme yolunun da üstünde** durur — yönetici yolu dahil.
Yönetici "her şeyi değiştirebilir" olduğu için kısıt dışarıda bırakılsaydı
adları geri yazmanın açık kapısı kalırdı.

**5. Eski dokümanlar TEMİZLENİYOR.** "Artık yazmıyoruz" demek, yazılmış
olanı ortadan kaldırmaz — 2. aşamadan önce oluşmuş her sohbet sunucuda
adları taşımaya devam ederdi. Bu yüzden kural, alanın **silinmesine**
bilinçli olarak izin verir (ekleme ve değiştirme her yolda reddedilir) ve
`ChatMetadataScrub`, alanı dolu gördüğü her sohbette bir kez silme dener.
Sessiz ve ateşle-unut: başarısız olursa sohbet normal çalışır, deneme
sonraki açılışta tekrarlanır.

### ⚠️ Kuralın "yok" değil "ARTIRILMASIN" olmasının sebebi

`request.resource.data` yazma **sonrası** dokümanı temsil eder. Alanın
varlığını topyekûn yasaklamak — `!('memberUsernames' in
request.resource.data)` — alanı hâlâ taşıyan ESKİ sohbetlerdeki **her**
güncellemeyi kırardı: mesaj önizlemesi, okunmamış sayacı, sabitleme.
Yani §4m'de gelen aramayı kıran hatanın aynısı tekrarlanırdı. Doğru
kısıt "alan olmasın" değil, **"alan eklenmesin veya değiştirilmesin"**.
İki test bunu ayrıca koruyor: eski dokümanda ilgisiz güncelleme ve mesaj
gönderme çalışmaya devam etmeli.

### ⚠️ Kaçınılan tuzak: `arrayRemove` birebir eşleşme ister

`members[]` girdilerinden adı kaldırmak, üye çıkarmayı **sessizce
bozabilirdi**. Üye çıkarma şöyle yapılıyor:

```dart
'members': FieldValue.arrayRemove([memberModel.toMap()])
```

Firestore dizi elemanını **birebir** karşılaştırır. `toMap()` adı hiç
yazmasaydı, dokümanda adıyla duran ESKİ bir üyenin haritası eşleşmez ve
o kişi `memberIds`'ten çıkarılmasına rağmen `members` dizisinde
**kalmaya devam ederdi** — atılan üye listede görünmeye devam eder,
kural motorunun okuduğu düz diziler ile `members` birbirinden ayrışırdı.
Hata mesajı da olmazdı.

→ `toMap()` adı **koşullu** yazar: doluysa (eski girdi) korunur, boşsa
(yeni girdi) hiç yazılmaz. Her iki yönde de eşleşme bozulmaz.
*Test: "ESKİ üye haritası adıyla BİREBİR geri yazılır".*

### 🐞 Yan bulgu: ölü ikinci sohbet modeli

`lib/models/chat_model.dart` — `ChatModel`, `GroupMember`, `MemberRole`
tanımlıyor ve `toMap()` içinde `memberUsernames` yazıyordu. **Hiçbir
yerden import edilmiyordu**; `features/group` altındaki modellerin
kopyasıydı.

Bu, denetimin daha önce üç kritik hataya sebep olduğu için sildiği
şablonun aynısı: iki farklı şema yazan iki model (bkz. eski
`chat_service.dart` + `models/message_model.dart`). Ölü hâlde bile
tehlikeli, çünkü bir sonraki geliştirici doğru model sanıp kullanabilir
ve adları sunucuya geri yazan bir yol açabilirdi. Dosya kaldırıldı.

### ⚠️ Ne KAZANILMADI (dürüstlük)

Sunucuda hâlâ açık olanlar:

* `senderId` ve `memberIds` — kural motoru üyelik ve yazarlık denetimini
  bunlarla yapıyor; kaldırılamaz (3. aşamanın konusu)
* `readBy`, zaman damgaları, mesaj sayısı/sıklığı
* `users/{uid}` **uid bilen her oturuma açık** (`get`). Numaralandırma
  kapalı (§4l) ama ortak sohbeti olmayan biri de uid'yi ele geçirirse
  profili okuyabilir. Kural düzeyinde "ortak sohbeti olanlar" kısıtı
  `get()` çağrısı gerektirir ve her ad çözümüne bir okuma maliyeti
  bindirir — bilinçli olarak ertelendi.
* `members[]` içindeki **eski** adlar yerinde kalır. Yeni üyeler adsız
  yazılır; eski girdiler ancak o üye çıkarılıp yeniden eklenirse temizlenir
  (`arrayRemove` tuzağı yüzünden toplu temizlik bilinçli yapılmadı).

Kazanılan: birebir sohbetlerde ad **tamamen** gitti (eskiler dahil,
temizlikle) ve grup/kanallarda yeni üyelikler adsız kuruluyor.

### ⚠️ Dağıtım sırası — kural İSTEMCİDEN ÖNCE gitti

`firebase deploy --only firestore:rules` **2026-09-01'de yapıldı**
(`gizlichat-f2a99`, "rules file compiled successfully" → "released").

İdeali kural ve istemcinin **birlikte** gitmesiydi. Kural önce
dağıtıldığı için, hâlâ eski APK çalıştıran cihazlarda ad yazan yollar
reddedilir:

| Eski istemcide | Sonuç |
|---|---|
| Yeni birebir sohbet açma | ❌ `create` reddedilir (alan taşıyor) |
| Yeni grup/kanal oluşturma | ❌ reddedilir |
| Kanala katılma | ❌ reddedilir |
| Mevcut sohbetler, mesajlaşma | ✅ etkilenmez |

Bu bilinçli kabul edildi: üretimde anlamlı bir kullanıcı tabanı yok —
fonksiyonlar ve indeksler §4n'e kadar hiç dağıtılmamıştı, yani sohbet
listesi bile çalışmıyordu. Test cihazına **yeni derleme kurulmalı**.

### Dağıtım durumu (§4o sonrası)
| | Durum |
|---|---|
| `firestore:rules` | ✅ 2026-09-01 dağıtıldı (84 test) |
| `functions` | ✅ §4n'de dağıtıldı — §4o fonksiyonlara dokunmadı |
| `firestore:indexes` | ✅ §4n'de dağıtıldı |
| `storage` | ✅ 2026-09-02 dağıtıldı — **C-02 nihayet AKTİF** |
| `hosting` | ✅ 2026-09-02 dağıtıldı → https://gizlichat-f2a99.web.app |
| İstemci (APK) | ✅ 2026-09-01 cihaza kuruldu, açılış temiz |

Bununla **denetimdeki tüm düzeltmeler üretimde aktif** oldu: C-12'nin
("kurallar hiç dağıtılmıyor") kapanışı ancak burada tamamlandı.

### Storage dağıtımından önce yapılan uyuşmazlık taraması

§4m'nin dersi gereği, kural yayına alınmadan önce istemcinin Storage
kullanımı kurala karşı tarandı. Yollar birebir uyuşuyor
(`avatars/{uid}.jpg`, `group_avatars/{chatId}.jpg`, `stories/{id}.jpg`,
`chats/{chatId}/...`).

İki **istemci silme** çağrısı kural tarafından reddedilecek durumda
bulundu — ikisi de zararsız çıktı, çünkü gerçek temizliği zaten
dağıtılmış fonksiyonlar yapıyor:

| İstemci çağrısı | Kural | Gerçek temizleyici |
|---|---|---|
| `consumeViewOnce` → `refFromURL(...).delete()` | ❌ `delete: if false` | `cleanupSoftDeletedMedia` — tam olarak `before.mediaUrl && !after.mediaUrl && after.viewOnce` geçişini dinler |
| Hesap silme yedeği → `avatars/{uid}.jpg` silme | ❌ | `deleteAccountData` sunucuda siler |

İstemcideki iki çağrı da zaten `catch` ile yutuluyordu; artık ölü
yüzeydir. **Tek görüntülük medya kaybolmaya devam eder** — silmeyi
Admin SDK yapar, ki güvenilir olan da budur (değiştirilmiş bir istemci
silmeyi atlayabilirdi).

### 🐞 Yan bulgu: cihaz doğrulama komutu yanlış pozitif veriyordu

`DEVAM.md`'deki kabul kapısı `adb logcat -d | grep -E "FATAL
EXCEPTION|E/flutter"` idi. Bu, **tüm sistem günlüğünü** tarar. Kurulum
sonrası ilk açılışta şu satır çıktı:

```
E/flutter ( 7949): Unhandled Exception: Task didn't run
```

Bir süre bunun yeni bir açılış hatası olduğu düşünüldü. Kaynak
aranınca metin ne `lib/` içinde, ne pub önbelleğinde, ne Flutter
SDK'sında bulunamadı. PID izlenince sebep çıktı: SECRETER **7936**'ydı,
hata **7949**'dan geliyordu — telefondaki **başka bir Flutter
uygulaması** (`io.ente.photos`), `dev.fluttercommunity.workmanager.
BackgroundWorker` çalıştırırken. `workmanager` bu projenin bağımlılığı
bile değil.

→ Komut `--pid` ile süreç kapsamına alındı. Cihazda başka bir Flutter
uygulaması bulunduğu sürece eski komut her doğrulamada yanlış alarm
verirdi.

**Doğrulama:** 17 yeni Dart testi (150 → **167**) ve 9 yeni kural testi
(75 → **84**). `flutter analyze` 0 bulgu.

---

## 4p. YUTULAN HATALAR GÖRÜNÜR KILINDI

`core/observability/handled_error.dart` (yeni) · `analysis_options.yaml` ·
`group_key_service.dart` · `key_management_service.dart` ·
`security_service_impl.dart` · `group_repository_impl.dart` ·
`auth_service.dart` · `chat_metadata_scrub.dart`

### Sorun: bu denetimdeki hataların ORTAK ÖZELLİĞİ sessiz olmalarıydı

| Bulgu | Nasıl saklandı |
|---|---|
| C-06 | Şifreleme hatası sessizce düz metne düşüyordu |
| §4e | Kimlik değişimi tüm mesajları sessizce çözülemez yapıyordu |
| §4g | SPK rotasyonunda sessiz uyuşmazlık |
| §4j | Gizlilik ayarı sessizce uygulanmıyordu |
| §4m | Gelen arama tamamen kırıktı |
| §4n | `claimPreKey` üretimde hiç yoktu |

Hiçbiri **çökmedi**. Bu yüzden aylarca görünmediler.

Oysa hata görünürlüğü YALNIZCA çökmeler için kuruluydu: `CrashReporter`
sadece `FlutterError.onError` ve Zone'un yakalanmamış hata kancasına
bağlıydı. **Yakalanan** hiçbir hata telemetriye ulaşmıyordu — 96 tanesi
`debugPrint` ile üretimde kimsenin okumadığı konsola yazılıyordu.
`AppLogger` soyutlaması DI'da kayıtlıydı ve **hiçbir yerden
çağrılmıyordu** (ölü altyapı — `chat_model.dart` ile aynı şablon, §4o).

### 🐞 Önce denenen çözüm ÇALIŞMADI: `empty_catches` lint'i

İlk plan "56 boş catch'i lint ile makineye yakalattırmak"tı. Lint açıldı
ve **sıfır bulgu** verdi. Sebebi kuralın kendi tanımında:
`catch (_) {}` biçimi "geliştirici bunu bilerek yaptı" sayılıp muaf
tutulur — kod tabanındaki boş catch'lerin **tamamı** o biçimde.

Bu, ölçmeden karar vermenin bedelini gösteriyor: kural açık bırakıldı
(gelecekteki `catch (e) {}` biçimini yakalar) ama **sessiz hata sorununu
çözemeyeceği** dosyaya yazıldı. İş elle denetimle yapıldı.

### İkinci ölçüm: 56 catch'in çoğu zaten meşrumuş

Elle geçilince tablo değişti. `catch (_)` sitelerinin büyük kısmı hata
gizlemiyor, **denetim akışı** kuruyor:

* `double_ratchet_service` — çözememe `null` döner; çağıran karar verir
  (kriptoda doğru olan da budur: neden çözülemediğini sızdırma)
* `backup_service` — yakalayıp `BackupFormatError`/`BackupPasswordError`
  tipli hataya çevirir; örnek alınası kullanım
* `native_security_bridge`, `biometric_service` — platform kanalı yok
* `presence`, `secure_store`, `splash_screen` — gerçekten en-iyi-çaba

Yani "56 sessiz catch" kötü bir ölçüydü. Asıl açık `debugPrint` ile
yutulan **96** hatadaydı: bunlar gerçek başarısızlıklar ve hiçbiri
cihazdan dışarı çıkmıyordu.

### Çözüm: `reportHandled()` geçidi

Yutulan hata artık iki yere birden gider: yerel günlüğe (tam ayrıntı) ve
`CrashReporter`'a (onaya bağlı, **fatal: false**).

### ⚠️ Telemetriye HAM HATA METNİ GİTMEZ

Bu karar bu uygulama için kritik. Gerçek bir Firestore hatası şuna benzer:

```
[cloud_firestore/permission-denied] ... /chats/uidAlice_uidBob/messages/m1
```

Birebir sohbet kimliği iki tarafın uid'sinden türediği için bu satır
**tek başına sosyal grafiği ele verir**. Böyle bir metni Crashlytics'e
yollamak, §4o'da sohbet dokümanından kullanıcı adlarını kaldırmak için
harcanan işi tek hamlede geri verirdi.

Bu yüzden dışarı yalnızca iki şey çıkar:
1. `what` — geliştiricinin yazdığı **sabit** etiket (değişken içermez)
2. hatanın imzası — `FirebaseException.code` (`permission-denied`,
   `unavailable`…) ya da tip adı. Kodlar sabit sözlükten gelir,
   tanımlayıcı taşımaz.

Ham metin ve `context` yalnızca cihazdaki hata ayıklama konsoluna yazılır.
Tanımlayıcı gerekiyorsa `Redact.id()` ile maskelenir.

*Testler: "Firestore hatasının KODU alınır, mesajı ALINMAZ" — hata
metnindeki `uidAlice`/`uidBob`/`chats` imzada BULUNMAMALI.*

### Dönüştürülen çağrılar — güvenlik garantisi sessizce bozulanlar

| Çağrı | Sessiz kalırsa ne olur |
|---|---|
| **Grup anahtarı rotasyonu** | ⚠️ Gruptan ATILAN üye eski anahtarla sonraki mesajları çözmeye devam eder — ileri gizlilik bozulur, arayüzde her şey normal görünür |
| Grup anahtarı dağıtımı | Yeni üye grup mesajlarını hiç okuyamaz |
| Anahtar paketi kontrolü / yayını | Kimse bu hesaba E2EE oturumu kuramaz (C-09'un sınıfı) |
| Güvenlik dedektörü çökmesi | Koruma hiç çalışmaz (§4j'nin tekrarı) |
| Sunucu tarafı hesap silme | Kullanıcı "silindi" sanır, veri sunucuda kalır (KVKK/GDPR) |
| Kullanıcı adı rezervasyonu | Adı başkası alabilir (§4l taklit yüzeyi) |
| Eski ad dizisi temizliği | §4o gizlilik temizliği sessizce yapılmaz |

**Bilerek dönüştürülmeyenler:** arama teardown'ı, kırpma yedeği, medya
önbelleği temizliği, hikâye tepkileri. Bunlar gerçekten en-iyi-çaba;
hepsini raporlamak gürültü üretip sinyali boğardı.

**Doğrulama:** 5 yeni test (167 → **172**). `flutter analyze` 0 bulgu.

---

## 4q. HATA METİNLERİ ÇEVRİLEBİLİR OLDU, HAM İSTİSNA SIZINTISI KAPANDI

`core/error/exceptions.dart` · `core/i18n/app_localizations.dart` ·
14 datasource/repository · `conversation_entity.dart` · `main.dart`

### Sorun: 16 dilli uygulama, hata anında herkese Türkçe

data/domain katmanı kullanıcıya dönen hataları **sabit Türkçe** üretiyordu:

```dart
ValidationFailure('Geçersiz davet kodu')
ServerException('Mesaj gönderilemedi: $e')
```

Bir Alman kullanıcı davet kodunu yanlış girdiğinde "Geçersiz davet kodu"
görüyordu. Uygulama 16 dil taşıyor; delik tam olarak **hata anında**,
yani kullanıcının en çok yardıma ihtiyaç duyduğu yerde açılıyordu.

İkinci kusur aynı satırlarda: `$e` **ham Firebase istisnasını** ekrana
basıyordu.

```
[cloud_firestore/permission-denied] ... /chats/uidAlice_uidBob/messages/m1
```

Kullanıcı bundan hiçbir şey anlamıyor; üstelik gizlilik uygulaması iç
yapısını ve **sohbet kimliğini** ekrana yazmış oluyordu.

### Mimari zaten doğruydu — uygulanmamıştı

`Failure` varsayılanları **zaten i18n anahtarıydı** (`err_server`,
`err_auth`…) ve bazı ekranlar `context.tr(f.message)` çağırıyordu. Yani
tasarım baştan doğruydu; sorun tutarsız uygulanmasıydı:

* bazı üreticiler anahtar yerine düz Türkçe geçiyordu
* bazı tüketiciler `tr()` çağırmadan `f.message` basıyordu
* `exceptions.dart` **varsayılanları** hâlâ Türkçeydi (`'Sunucu hatası'`)
  — bunlar `Failure(e.message)` ile aynen ekrana taşınıyordu

Son madde testi yazarken ortaya çıktı: üreticileri düzeltmek yetmiyordu,
sınıfların kendi varsayılanları da metindi.

### Yapılan

| | Önce | Sonra |
|---|---|---|
| Türkçe üretici | **74** | **5** (hiçbiri kullanıcıya ulaşmıyor) |
| `Failure(e.toString())` — ham metin | **43** | **0** |
| `tr()` çağırmadan gösterim | 3 | **0** |
| `err_*` anahtarı | 28 | **67** |

Dönüşümün şekli — §4p'nin geçidiyle birleşiyor:

```dart
} catch (e, s) {
  reportHandled('Mesaj gönderilemedi', e, stack: s);   // geliştirici: tam ayrıntı
  throw const ServerException('err_send_message');     // kullanıcı: çeviri
}
```

Böylece ham metin **kaybolmuyor**, yalnızca doğru yere gidiyor.

### Diller: yeni anahtarlar `tr` + `en`, gerisi İngilizce yedeğine düşer

Ölçüm: 16 dilden 14'ü **zaten** 41 anahtarda İngilizce yedeğine
düşüyordu. Yeni 41 anahtar da aynı desende eklendi (`tr` + `en` tam).
`t()` zinciri `dil → en → anahtarın kendisi` olduğu için hiçbir
kullanıcı boş ekran görmez; Türkçe olmayan kullanıcı artık **Türkçe
yerine İngilizce** görüyor — bu kesin bir iyileşme.

⚠️ Kalan 14 dile bu anahtarların yazılması bekliyor. Dosyanın kendi
notu geçerli: az konuşulan diller üretime çıkmadan ana dili konuşan
biri tarafından gözden geçirilmeli.

### Domain katmanındaki yedek başlıklar

`ConversationEntity.displayTitle` `'Grup'` / `'Sohbet'` döndürüyordu —
`BuildContext` göremeyen bir sınıftan doğrudan ekrana çıkan sabit
Türkçe. §4o'daki `nameResolver` deseni tekrar kullanıldı: çeviri
`labelResolver` olarak dışarıdan takılır (`main.dart`, dil değişiminde
tazelenir), takılı değilse Türkçe'ye düşer. Varlık saf kalır.

### Bilerek dokunulmayan 5 nokta

`giphy_service`, `secure_media_cache`, `secure_store`,
`photo_editor_screen` içindeki metinler **artık kullanıcıya
ulaşmıyor**: hepsi genel `Exception` fırlatıyor ve repository katmanı
onları `const UnexpectedFailure()` (yani `err_unexpected`) olarak
çeviriyor. Geliştirici için okunur kalmaları bir kazanç.

**Doğrulama:** 7 yeni test (172 → **179**). En kritiği "kullanılan
anahtarların çevirisi var" — kod bir anahtar üretip tabloya eklenmezse
kullanıcı ham `err_send_message` metnini görür; test bunu yakalar.

---

## 4r. 🐞 UYGULAMA KENDİ ÜRETTİĞİ DAVET KODUNU KABUL ETMİYORDU

`services/meet_code_service.dart` · `group_repository_impl.dart`

Kullanıcı bildirdi: buluşma kodu `JGSG-DSDH` biçiminde üretiliyor ama
kopyalayıp yapıştırınca giriş yapmıyor; **tireyi elle silmek** gerekiyor.

### Ne oluyordu

Üç yer birbiriyle çelişiyordu:

| Yer | Ne yapıyor |
|---|---|
| `MeetCode.pretty` | Kodu **tireli** gösteriyor: `ABCD-EFGH` |
| Kopyala düğmesi | Panoya **`pretty`** yazıyor — yani tireli |
| Giriş ipucu | Aynen `ABCD-EFGH` yazıyor |
| `redeem()` | Yalnızca **boşluk** siliyordu |

```dart
final clean = code.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
if (clean.length != 8) throw const MeetCodeError('meet_code_invalid');
```

Tireli kod 9 karakter olduğu için uzunluk kontrolüne takılıyor ve
kullanıcı "geçersiz kod" alıyordu. Yani uygulama **kendi kopyaladığı
biçimi reddediyordu** ve ipucu metni de kullanıcıyı o biçime
yönlendiriyordu.

Bu, özelliğin tamamını pratikte kullanılamaz kılıyordu: buluşma kodunun
tüm amacı "karşı tarafa gönder, o girsin" — gönderilen biçim
çalışmıyorsa özellik yok demektir. Otomatik testle yakalanamazdı çünkü
testler kodu hep düz biçimde veriyordu.

### Düzeltme

`MeetCodeService.normalize()`: harf ve rakam **dışındaki** her şey atılır
(tire, boşluk, satır sonu, noktalama, görünmez karakterler). Hem
`ABCD-EFGH`, hem `abcd efgh`, hem düz `ABCDEFGH` çalışır.

### ⚠️ Bilinçli sınır: alfabede olmayan HARF atılmaz

Alfabe karışan karakterleri dışlıyor (`I`, `L`, `O`, `S`, `0`, `1`, `5`
yok). Yine de yanlışlıkla yazılan bir `S` **silinmez** — silmek kalan
karakterleri kaydırıp kodu **başka birinin geçerli koduna**
dönüştürebilirdi. Yanlış kodun dürüstçe "bulunamadı" demesi doğrusudur.

### Aynı tuzak grup davet kodunda da kapatıldı

`joinByInviteCode` de yapıştırılan kodu temizliyor. Orada bir fark var:
grup kodu alfabesi **karışık durumludur** (`aB3x…`), bu yüzden harf
durumu DEĞİŞTİRİLMEZ — büyük harfe çevirmek kodu geçersiz yapardı.

**Doğrulama:** 10 yeni test (179 → **189**). En kritiği "gösterim biçimi
geri normalleştirilebilir (gidiş-dönüş)": `normalize(pretty(code)) ==
code`. Bu test kırılırsa hata geri gelmiş demektir.

---

## 4s. GÜVENLİK DURUMU ARTIK KULLANICIYA DA GÖRÜNÜYOR

`core/security/security_alerts.dart` (yeni) · `messaging_screen.dart` ·
`group_repository_impl.dart` · `app_localizations.dart`

### Sorun: §4p geliştiriciyi uyarıyordu, kullanıcıyı değil

§4p ile yutulan hatalar telemetriye bağlandı. Ama iki durumda bunu
bilmesi gereken kişi **kullanıcı**:

**1. Grup anahtarı rotasyonu başarısız.** Bir üye gruptan atıldığında
anahtar yenilenmezse, o kişi **elindeki anahtarla sonraki mesajları
çözmeye devam edebilir**. Arayüzde hiçbir şey değişmez: kullanıcı "onu
attım, artık okuyamaz" sanır ve o yanlış inançla yazışmayı sürdürür.
Bu, güvenlik açığından da kötüdür — **yanlış bir güvenlik hissidir**.

**2. Sohbet hiç doğrulanmamış.** Güvenlik numarası ekranı §4e'de
yapılmıştı ama hiçbir yer kullanıcıyı oraya yönlendirmiyordu. Özellik
kod tabanında duruyor, pratikte kullanılmıyordu.

### Yapılan

`SecurityAlerts` — cihazda tutulan, sohbet başına güvenlik durumu.
**Sunucuya yazılmaz:** bu cihazın kendi bilgisidir, sunucuya yazmak
gereksiz metadata üretirdi (§4o'nun tersi yönde bir adım olurdu).

| Bant | Renk | Kapatılabilir | Eylem |
|---|---|---|---|
| Kimlik değişti (§4e, mevcuttu) | kırmızı | ❌ | Güvenlik numarasını aç |
| **Grup anahtarı yenilenemedi** | kırmızı | ❌ | **Tekrar dene** |
| **Bu sohbeti doğrula** | nötr | ✅ | Güvenlik numarasını aç |

### Neden biri kapatılabilir, diğeri değil

Doğrulama önerisi bir **öneridir**; kapatılamazsa gürültüye dönüşür ve
kullanıcı tüm bantları görmezden gelmeye başlar — o noktada **gerçek
uyarı da işe yaramaz**. Rotasyon uyarısı ise bir sözün tutulamadığını
söyler; kapatılabilseydi kullanıcı attığı kişinin hâlâ okuyabildiğini
hiç öğrenemezdi.

Aynı sebeple kimlik değişimi ile doğrulama önerisi **aynı anda
gösterilmez**: kimlik değiştiyse doğrulama zaten düşmüştür ve iki bant
üst üste yığmak dikkati dağıtır.

### Rotasyon uyarısı NE ZAMAN belirir

Üye atma/ekleme **grup bilgisi ekranında** olur ve rotasyon orada
başarısız olabilir. Sohbet ekranı, o ekrandan **dönüşte** bayrağı
tazeler. Bu olmasaydı bant ancak sohbet yeniden açıldığında görünürdü —
yani kullanıcı atma işleminden hemen sonraki en kritik dakikalarda
yanlış güvenlik hissiyle devam ederdi.

Başarılı bir rotasyon (yeniden deneme dahil) bayrağı **temizler**;
kalıcı bir uyarı bırakmak yukarıdaki "gürültü" tuzağına düşmek olurdu.

### ⚠️ Ne KAZANILMADI

* Uyarı yalnızca **rotasyonu tetikleyen cihazda** görünür. Grubun diğer
  yöneticileri bilmez — bunun için sunucuya durum yazmak gerekirdi ve o
  da metadata demektir. Bilinçli bir denge.
* Bant "anahtar yenilenemedi" der; **hangi üyenin** hâlâ okuyabileceğini
  söylemez. Söylemek için o bilgiyi cihazda tutmak gerekirdi.

### Bantlar neden ayrı dosyada

Bir bandın doğru koşulda ÇIKMASI bir güvenlik özelliğidir, "herhalde
çalışıyordur" denecek bir şey değil. `MessagingScreen` içinde gömülü
kaldıkça sınanamıyorlardı: test için Firestore, Riverpod ve E2EE oturumu
ayağa kaldırmak gerekirdi.

`presentation/widgets/security_banners.dart` içine çıkarıldılar; artık
widget testiyle metin, çeviri, düğme davranışı ve yükseklik sözleşmesi
doğrudan sınanıyor.

### 🐞 Cihazda doğrulama neden YAPILAMADI

Rotasyon başarısızlığı elle zorlanamıyor. Debug derlemesi kurup bayrağı
`run-as` ile yazmak akla geliyor — **ama yapılamaz**: debug APK farklı
anahtarla imzalanır, release'in üzerine kurulamaz. Kurmak için önce
kaldırmak gerekir ve bu, cihazdaki **hesabı, E2EE kimliğini ve tüm
sohbetleri siler**. Bir bandı görmek için ödenecek bedel bu değildir.

→ Doğrulama widget testine taşındı: tek seferlik cihaz kontrolünden
kalıcı olarak daha iyi, çünkü her CI çalışmasında tekrarlanır.

**Doğrulama:** 16 yeni test (189 → **205**).
* `SecurityAlerts` (8): en kritiği "BAŞARILI rotasyon uyarıyı TEMİZLER"
* Bantlar (8): "KAPATMA düğmesi YOKTUR" (rotasyon bandı görmezden
  gelinemez), "metne dokunmak güvenlik numarasını AÇAR", "kapatmak
  ekranı açmamalı" ve iki bandın AYNI yükseklikte olması (sohbet ekranı
  bantları üst üste dizerken bu sabite dayanıyor).

**Cihazda doğrulanan:** doğrulama önerisi bandı 2026-09-04'te gerçek
cihazda görüldü ve güvenlik numarası ekranını açtığı teyit edildi.

---

## 4t. ÇAĞRI ŞEMASI İKİ KİŞİDEN N KİŞİYE GENELLEŞTİRİLDİ

`call_entity.dart` · `call_model.dart` · `call_service.dart` ·
`call_remote_datasource.dart` · `call_repository*.dart` ·
`firestore.rules` · `firestore.indexes.json`

Grup araması (Telegram/Signal'de var) istendi. Bu, bir düğme eklemek
değil: sinyalleşme **iki kişiye çakılıydı** ve üç katman birden bu
varsayıma dayanıyordu.

| Katman | Eski varsayım |
|---|---|
| Doküman | `callerId` + `calleeId` |
| Aday yolları | `callerCandidates/` + `calleeCandidates/` |
| Kurallar | `callerId == uid \|\| calleeId == uid` |
| Gelen arama sorgusu | `where('calleeId', ==, me)` |
| İstemci | tek `RTCPeerConnection` |

### Yapılan: üyeliğin tek kaynağı `participants`

`callerId` korunur (kim başlattı + engel kontrolü), `calleeId` birebir
aramada anlamlıdır; ama yetki artık diziden okunur. Gelen arama sorgusu
`participants array-contains me` oldu — grup aramasında "aranan" diye
tek bir kişi yoktur, davet edilen **herkes** çağrıyı görmelidir.

### 🔒 Asıl kazanım: adresli ICE adayları

Eski şemada bir tarafın **tüm** adaylarını diğer taraf okuyabiliyordu.
İki kişide sorun değildi. Üç kişide A, B↔C adaylarını — yani onların
**IP adreslerini** — okuyabilirdi: C-03'ün grup hâli, ve grup araması
eklenseydi sessizce ortaya çıkacaktı.

Adaylar tek `candidates` koleksiyonuna taşındı, her biri `from`/`to`
taşıyor ve kural yalnızca o ikisine açıyor. Yazarken `from` kendin
olmak zorunda — aksi halde çağrıya sahte rota enjekte edilebilirdi.
*Test: "ÜÇÜNCÜ KATILIMCI, diğer ikisinin adaylarını (IP) GÖREMEZ",
"taraf bile BAŞKASI ADINA aday yazamaz".*

### ⚠️ Eski dokümanlar kopmasın

Kural `participants` yoksa `callerId`/`calleeId` yedeğine düşer.
§4m'nin dersi: bir alan zorunlu kılınmadan önce ESKİ dokümanların ne
olacağı düşünülmeli — aksi halde şema değişiminin tam o anında **devam
eden bir arama konuşma ortasında koparadı**.
*Test: "ESKİ şemadaki (participants YOK) arama erişilebilir kalır".*

### 🐞 Yan bulgu: kendi aramam "gelen arama" olarak görünürdü

`participants` beni de içerdiği için, kendi başlattığım çağrı da gelen
arama sorgusuna düşüyor. `calleeId` ile süzerken bu sorun yoktu.
Elenmeseydi arayan kişiye kendi araması gelen arama ekranı olarak
açılırdı. Sorgu sonucu `callerId != me` ile süzülüyor.

### 🐞 Yan bulgu: iki paralel sinyalleşme yolu

Canlı arama tamamen `CallService` üzerinden yürüyor (Firestore'a
**doğrudan** yazıyor). Clean katmanındaki `CallRemoteDataSource` ise
aynı koleksiyonun ikinci bir istemcisi. Taranınca ortaya çıktı:

* `addIceCandidate` / `watchIceCandidates` → **hiçbir yerden
  çağrılmıyor** (repository ve arayüz dahil ölü)
* `StartCall`, `AnswerCall`, `EndCall` usecase'leri DI'da kayıtlı ama
  **çözümlenmiyor**
* Canlı olanlar: `WatchIncomingCall`, `WatchCall`, `RejectCall`

Ölü ICE metotları **eski şemayı kodluyordu**; bırakılsalardı bir
sonraki geliştirici onları doğru yol sanıp `callerCandidates`'a
yazabilirdi. Kaldırıldılar (§4i'nin ölü yazma yüzeyi ilkesi, §4o'daki
`chat_model.dart` ile aynı şablon). Ölü usecase'ler ise dokunulmadı —
ayrı bir temizlik.

### ⚠️ Bu, grup araması DEĞİL — temelidir

Yapılan iş sinyalleşme şeması + kurallardır. Eksik olan:
istemcide **N adet** `RTCPeerConnection` yönetimi ve bir **medya
sunucusu**. Mimari not (bilinçli karar):

* **Mesh** (herkes herkese) yeni sunucu istemez ama 5 kişide 10
  bağlantı demektir ve **TURN kurulu olmadığı için** herkesin IP'si
  herkese açılır — §4f'teki mevcut açığın çarpanla büyümesi.
* **SFU** (Signal/Telegram'ın yolu) ölçeklenir ve E2EE kare düzeyinde
  korunabilir (`flutter_webrtc` `FrameCryptor`), ama sunucu ister.

Zaten TURN kurulması gerekiyor; **LiveKit ikisini birden** verdiği için
sıralama "önce sunucu, sonra grup araması" olarak belirlendi. Mesh yazıp
sonra atmak yerine, iki mimaride de gereken şema işi önden yapıldı.

### ⚠️ Kapsam dışı bırakılan bulgu

`calls` dokümanı `callerUsername` / `calleeUsername` alanlarını **düz
metin** yazıyor — §4k/§4o'da mesajlardan ve sohbet dokümanından
temizlenen sızıntının aynısı, aramalarda gözden kaçmış. Sunucuda "kim
kimi aradı" adlarıyla duruyor. Bu turda bilerek yapılmadı: gelen arama
ekranı, çağrı geçmişi ve bildirimler o alanları okuyor; şema
değişimiyle aynı anda yapmak iki riskli işi birbirine karıştırırdı.
`DEVAM.md` §3b'ye ayrı madde olarak yazıldı.

**Doğrulama:** 8 Dart testi (205 → **213**) ve 5 kural testi
(84 → **89**).

---

## 4u. ÇAĞRI ADLARI SUNUCUDAN ÇIKTI — VE §4t'DE BIRAKILAN BİR KIRIK

`models/call_model.dart` · `features/call/.../call_model.dart` ·
`call_entity.dart` · `call_log_service.dart` · `incoming_call_screen.dart`

### Sorun: aramalar §4k/§4o'dan atlanmıştı

Üç yerde kullanıcı adı düz metin duruyordu:

| Yer | Ömür | Ne diyordu |
|---|---|---|
| `calls/{id}` | kısa | "kim kimi arıyor" |
| **`callLogs/{id}`** | **kalıcı** | "kim kimi ne zaman aradı" — süresiz |
| `chats/.../messages/call_*` | kalıcı | `senderUsername` |

İkincisi en ağırı: çağrı geçmişi silinmez, yani sosyal grafik adlarıyla
**süresiz** saklanıyordu.

### 🐞 Üçüncüsü §4k'nin doğrudan İHLALİYDİ

§4k gönderen adını mesajlardan kaldırmıştı ve bunu bir testle
korumuştu — ama test `MessageModel.toMap()` üzerindeydi.
`CallLogService` ise **modeli atlayıp ham map yazıyor** ve
`senderUsername` alanını geri koyuyordu. Model üzerindeki test bunu
göremezdi.

Ders: bir alanı modelden kaldırmak yetmiyor; o koleksiyona **ham map
yazan başka yol var mı** diye aranmalı.

### 🐞🐞 Daha kötüsü: §4t'yi BOZUK göndermişim

Bu iş sırasında ortaya çıktı. Çağrı için **iki model** var:

* `lib/models/call_model.dart` → **CANLI YOL** (`CallService` kullanır)
* `features/call/data/models/call_model.dart` → Clean katmanı, çoğu ölü

§4t `participants` alanını **yalnızca ikincisine** ekledi. Sonuç: canlı
çağrı dokümanı alanı hiç taşımıyordu ve gelen arama dinleyicisi

```dart
where('participants', arrayContains: myUid)
```

**hiçbir zaman eşleşmiyordu — hata vermeden.** Kullanıcı arama alamazdı.
Açılış doğrulamasında görünmedi çünkü sorgu başarıyla kuruluyor, sadece
boş dönüyor. §4m ile aynı sınıf: "hata yok ama özellik ölü".

Kurallar ve indeks üretime dağıtılmış, APK cihaza kurulmuştu; yani
kırık hâliyle yayına çıktı. Bu turda düzeltildi.

**Kök sebep, bu projede ÜÇÜNCÜ kez aynı desen:** aynı koleksiyona yazan
iki model. Öncekiler `chat_service.dart` + `models/message_model.dart`
(silindi) ve `models/chat_model.dart` (§4o'da silindi). Bu ikisi henüz
birleştirilmedi — `DEVAM.md` §3b'ye madde olarak yazıldı.

### Yapılan

* Her iki model de adları YAZMIYOR, ikisi de `participants` yazıyor.
* `callLogs` adları yazmıyor; `CallLogEntry.otherName` uid'den çözüyor
  (eski kayıtlar adsız kalmasın diye eski alan yedek).
* Çağrı sistem mesajından `senderUsername` kaldırıldı.
* `CallEntity.nameResolver` kancası (§4o deseni) + DI bağlantısı.
* Çağrı geçmişi listesi çizilmeden önce adlar toplu ısıtılıyor.

**Doğrulama:** 10 yeni test (213 → **223**). En kritiği canlı model
üzerindeki "participants YAZILIR (gelen arama sorgusu buna dayanıyor)" —
iki modelin şeması yine ayrışırsa bu test kırılır.

---

## 4v. İKİ ÇAĞRI MODELİNİN AYRIŞMASI YAPISAL OLARAK ENGELLENDİ

`core/call/call_document.dart` (yeni) · `models/call_model.dart` ·
`features/call/data/models/call_model.dart`

§4u'da gönderilen hatanın kök sebebi kapatıldı.

### Asıl sorun "iki model" değil, SESSİZCE AYRIŞABİLMELERİYDİ

`calls` koleksiyonuna iki model yazıyor: canlı yol (`CallService`) ve
Clean katmanı. §4t alanı yalnızca birine ekledi; doküman `participants`
taşımadı ve gelen arama dinleyicisi **hata vermeden** hiç eşleşmedi.

Tam birleştirme (`CallService`'i Clean modele taşımak) arama yolunda
büyük bir yeniden yapılandırmadır ve **cihazda arama testi yapılamadığı
için** şu an riskli. Bunun yerine ayrışma yapısal olarak imkânsız
kılındı: iki model de dokümanı `buildCallDocument()` ile üretiyor.
Bir alan eklemek/kaldırmak tek yerde olur ve ikisini birden etkiler.

### ⚠️ İmzada kullanıcı adı parametresi YOK — kasıtlı

`buildCallDocument` ad almaz. Alanı geri eklemek isteyen birinin önce
bu dosyaya dokunması gerekir; §4u'da olduğu gibi bir modelde sessizce
belirmesi mümkün değil.

### Testin gerçekten koruduğu doğrulandı

Ortak şemadan `participants` geçici olarak kaldırıldı → ilgili testler
anında kırıldı, geri alınınca geçti. Kırılamayan bir koruma işe yaramaz.

⚠️ Kapsam notu: **eşitlik testleri** (iki model aynı alanları yazar) o
denemede GEÇMEYE devam etti — ikisi de aynı kaynağı kullandığı için
hâlâ eşitler. Onları yakalayan, alanın varlığını ayrıca sınayan test
oldu. İki test birlikte iki farklı hatayı kapsıyor:
* **ayrışma** (§4u'nun hatası) → eşitlik testi
* **ortak şemadan alan düşmesi** → alan testi

**Doğrulama:** 8 yeni test (223 → **231**).

### Kalan iş

Modellerin tam birleştirilmesi hâlâ açık; `CallService`'in Clean modele
taşınmasını ve ölü `StartCall`/`AnswerCall`/`EndCall` usecase'lerinin
temizlenmesini gerektiriyor. Cihazda arama testi yapılabildiğinde
ele alınmalı — `DEVAM.md` **§3b/5** (§3b/4 grup aramasıdır; bu
referans önce yanlış yazılmıştı).

> 📌 **SONRADAN (§4aj):** Bu maddenin ikinci yarısı yapıldı ve teşhis
> düzeltildi. Ölü usecase'ler "temizlik işi" değil, **kök sebebin
> kendisiydi**: `calls`'a yazan ikinci yol onlardı. Silindiler; artık
> tek yazar var, yani buradaki eşitlik testinin koruduğu ayrışma
> **yapısal olarak imkânsız**. `call_schema_parity_test.dart` da
> eşitlik testinden **canlı yazar → Clean okur** tur testine çevrildi.
> `CallService`'in taşınması hâlâ açık ama artık güvenlik değil mimari
> tutarlılık işi.

---

## 4w. YUTULAN HATALAR — İKİNCİ TUR: GÜVENLİK SÖZÜ BOZULANLAR

§4p geçidi kurmuş ve 7 kritik çağrıyı bağlamıştı. Bu tur kalan 105
yutulan hatayı **tek tek eleyip** 12 tanesini daha bağladı. Ölçüt:
*kullanıcı çalıştı sanıyor ama çalışmadı* ya da bir güvenlik sözü
sessizce bozuluyor.

### 🔴 En ağırı: grup şifrelemesi düz metne düşüyor (C-06'nın şekli)

```dart
} catch (e) {
  debugPrint('Grup şifreleme hatası: $e');
}
return EncryptionResult(ciphertext: plaintext, isEncrypted: false);
```

Bir satır yukarıda "kimsenin anahtarı yok → şifrelemek mesajı HERKES
için okunmaz yapardı" diye **bilinçli** bir düz metin tercihi var. Ama
`catch` bloğu da aynı yere düşüyor: grup şifrelemesinde **herhangi bir
istisna**, mesajı sessizce şifresiz gönderiyor. C-06 tam olarak buydu
("şifreleme hatası sessizce DÜZ METNE düşüyordu") ve grup yolunda
kalmış.

⚠️ Bu turda yalnızca **görünür** kılındı. Davranışı değiştirmek
(istisnada göndermemek) kullanıcıyı etkileyen bir karardır ve ayrıca
ele alınmalı — `DEVAM.md` §3b.

### C-07 bölgesi: cihazda düz metin kalması (4 nokta)

| Nokta | Sessiz kalırsa |
|---|---|
| Süresi dolan mesaj | "Kaybolan mesaj" yalnızca SUNUCUDAN kaybolur, cihazda okunabilir kalır |
| Sohbeti temizleme | Sunucu temizlenir, cihaz temizlenmez → mesajlar yeniden açılışta geri gelir |
| Mesaj silme | Silinen mesajın çözülmüş metni cihazda kalır |
| Mesaj düzenleme | Düzenlemenin amacı çoğu zaman yazılanı geri almaktır; eski metin kalırsa boşa çıkar |
| `SecureStore` önek temizliği | Çıkış/hesap değişiminde ESKİ HESABIN düz metinleri cihazda kalır |

### Diğerleri

* **Mesaj kalıcı olarak düşürüldü** — `maxAttempts` sonrası kuyruktan
  atılıyor; mesaj ARTIK GÖNDERİLMEYECEK ve kullanıcıya söyleyen yol yok.
* **Gizlilik ayarı kaydedilemedi** — §4j ile aynı sınıf: kullanıcı ayarı
  değiştirdiğini görür, yeniden başlatınca varsayılana döner. (Kodun
  kendi yorumu da bunu zaten söylüyordu.)
* **Sohbet kilidi taşınamadı** — eski DÜZ METİN kilit listesi cihazda
  kalır; taşımanın amacı tam o yüzeyi kaldırmaktı.
* **Uygulama kılığı değiştirilemedi** — mekanizma zaten `false` dönüp
  arayüze bırakıyordu; eksik olan geliştirici görünürlüğüydü.
* **E2EE oturumu kurulamadı** — ön-anahtar eksik/imza geçersiz.

### Bilerek dokunulmayanlar (93 nokta)

Açılış (`BOOT:`), splash, taslak kaydetme, medya önbelleği temizliği,
video kırpma, fotoğraf kırpıcı yedeği, hikâye tepkileri, hesap listesi.
Bunlar gerçekten en-iyi-çaba: başarısızlıkları bir sözü bozmuyor ve
hepsini raporlamak sinyali gürültüde boğardı. §4p'nin ilkesi burada da
geçerli — **her hatayı raporlamak, hiçbirini raporlamamak kadar
işe yaramaz.**

**Doğrulama:** analyzer 0 bulgu, 231 test geçmeye devam ediyor
(dönüşümler davranışı değiştirmedi, görünürlüğü değiştirdi).

---

## 4x. C-06 GRUP YOLUNDA KAPATILDI — ARIZADA MESAJ ARTIK GÖNDERİLMİYOR

`encryption_datasource_impl.dart` · `app_localizations.dart`

§4w bu sızıntıyı görünür kılmıştı; bu bölüm davranışı düzeltir.

### İki yol aynı yere düşüyordu — ama aynı şey değiller

```dart
if (envelope != null) return şifreli;
// (1) kimsenin anahtarı yok  → düz metin
} catch (e) {
// (2) İSTİSNA               → düz metin   ← C-06
}
return EncryptionResult(ciphertext: plaintext, isEncrypted: false);
```

**(1) belgelenmiş bir tercihtir:** hiçbir üyeye anahtar ulaştırılamadıysa
şifrelemek mesajı HERKES için okunmaz yapar; erişilebilirlik gizliliğe
tercih edilmiş. Bu bir durum, hata değil.

**(2) ise bir arızadır** ve düz metne düşmesi C-06'nın tanımıydı:
"şifreleme hatası sessizce DÜZ METNE düşüyordu". Denetimde birebir
sohbetler için giderilmiş, grup yolunda kalmıştı.

### Yapılan

İstisna yolu artık **fırlatıyor**: mesaj **gönderilmiyor** ve kullanıcı
`err_encrypt_failed` ile bilgilendiriliyor —
*"Mesaj şifrelenemedi, bu yüzden gönderilmedi. Tekrar deneyin."*

Bu, mevcut hata yoluna oturdu: `sendTextMessage` zaten
`on EncryptionException → EncryptionFailure` yakalıyordu. Şifreleme
mesaj oluşturulmadan ÖNCE yapıldığı için fırlatma temiz kapanır —
ne önbelleğe, ne kuyruğa, ne sunucuya bir şey yazılır.

⚠️ Şifreli sanılan bir mesajın açıkta gitmesindense **gönderilmemesi**
yeğdir. Kullanıcı tekrar deneyebilir; açıkta giden mesaj geri alınamaz.

### (1) neden değiştirilmedi

Erişilebilirlik tercihi bilinçli ve belgeli. Ama artık **ölçülüyor**:
`reportHandled` ile raporlanıyor, çünkü gerçekte ne sıklıkta olduğu
bilinmeden bu tercihin bedeli de bilinemez. Arayüzde şifreli mesajlar
kilit ikonu taşıyor; şifresiz olan yalnızca **kilidin yokluğuyla** belli
oluyor — kimsenin fark etmediği bir sinyal. Açık bir işaret koymak
arayüz kararı gerektiriyor, `DEVAM.md` §3b'de duruyor.

**Doğrulama:** analyzer 0, 231 test geçiyor; `err_encrypt_failed`
anahtarı `tr`+`en` tanımlı ve regresyon testine eklendi.

---

## 4y. PREMIUM — HESABA BAĞLANMAYAN YETKİ (kör imza)

`core/premium/blind_signature.dart` · `core/premium/entitlement.dart` ·
`functions/index.js → issueEntitlement` · `firestore.rules`
Tam mimari: **`PREMIUM_MIMARISI.md`**

### Neden basit yol reddedildi

`users/{uid}.isPremium = true` yazmak şu zinciri tamamlar:

```
gerçek kimlik → Google hesabı → Play satın alması → SECRETER uid → sohbetler
```

Google ilk üç halkayı zaten biliyor; sunucumuz dördüncüyü de öğrenirse
"kim olduğunuzu bilmiyoruz" iddiası çöker — üstelik **ödeme yapan**,
yani uygulamaya en çok güvenen kullanıcılar için.

### Çözüm: sunucu GÖRMEDİĞİ değeri imzalar

Chaum kör imzası. İstemci rastgele bir gövde üretip körleştirir; sunucu
satın almayı doğrulayıp körleştirilmiş değeri imzalar; istemci körlüğü
kaldırır. Sunucu **"biri ödedi"** der, **"bu uid ödedi"** demez.

### 🐞 Yazarken yakalanan tuzak: jetonu saklamak bağlanamazlığı yok eder

İlk tasarımda sunucu, tekrar deneme için `blinded` ve `blindSignature`
saklayacaktı. Bu, saldırıyı mümkün kılıyor:

```
r' = blindSignature · sig⁻¹ mod n
blinded =? FDH(nonce) · r'ᵉ mod n
```

Sunucu sonradan sunulan yetkiyi bu eşitlikle satın almaya
**bağlayabilirdi** — yani kör imza tamamen anlamsız olurdu.

→ Yalnızca **özetler** saklanıyor. Özetten `blinded` geri getirilemez,
ama tekrar denemede istemci aynı değeri gönderdiği için özet eşleşmesi
kontrol edilebiliyor ve RSA deterministik olduğu için aynı imza yeniden
üretiliyor. "Kullanıcı ödedi ama yetki alamadı" durumu da böylece
oluşmuyor.

### Diğer kritik kararlar

* **Uç nokta kimlik doğrulamasız** (`onRequest`, `onCall` DEĞİL).
  `onCall` sunucuya uid'yi gösterirdi ve körleştirme anlamsız kalırdı.
* **Son kullanma tarihi ANAHTARDA.** Sunucu körleştirilmiş değere tarih
  yazamaz, istemci de kendi yazsa uydurur. Her dönem ayrı imza anahtarı
  kullanılır; yetkinin ömrü anahtarın penceresidir (Privacy Pass
  yaklaşımı). ⚠️ Anonimlik kümesi = o dönemin tüm ödeyenleri; dönem
  aylıktan kısa yapılmamalı.
* **`entitlementRedemptions` istemciye tamamen kapalı** — okunabilseydi
  kayıt zamanları üzerinden yetkiler satın almalara eşleştirilebilir,
  bağlanamazlık yan kanaldan delinirdi.

### ⚠️ Doğrulama bağlanmadan ÜRETİME ÇIKARILMAMALI

`issueEntitlement` içinde Play doğrulaması henüz yok
(`purchaseVerified = false`) ve fonksiyon `501` döner. Bağlanmadan
açılırsa uç nokta **herkese premium dağıtır**.

**Doğrulama:** 26 Dart testi (231 → **257**) ve 3 kural testi
(89 → **92**). En kritikleri:
* "sunucunun GÖRDÜĞÜ değer, sonradan SUNULAN değer DEĞİLDİR"
* "AYNI nonce, farklı körleştirmeyle farklı görünür"
* "kodlanmış jetonda uid/ad/satın alma izi YOK"
* "dönem BİTTİKTEN sonra geçersiz"

---

## 4z. APK BOYUTU: 103,9 MB → 39,6 MB (%62)

### Önce ölçüldü, sonra kesildi

APK'nın içi dökülünce kazancın nerede olduğu netleşti:

| İçerik | Boyut | Pay |
|---|---|---|
| `lib/x86_64` | 40,1 MB | %34 |
| `lib/arm64-v8a` | 34,6 MB | %30 |
| `lib/armeabi-v7a` | 27,3 MB | %23 |
| dex + kaynaklar + varlıklar | 14,7 MB | %13 |

**%87'si üç mimari için yerel kütüphaneler.** Tek tek bakıldığında
kesilecek gereksiz kütüphane YOK:

* `libjingle_peerconnection_so.so` (WebRTC) — 12,1 MB, aramalar için şart
* `libflutter.so` (motor) — 11,6 MB
* `libapp.so` (derlenmiş Dart) — 10,7 MB

Yani sorun "şişmiş bağımlılık" değil, **tek dosyada üç mimari
taşımaktı**.

### En çarpıcı bulgu: en büyük parça hiç kullanılmıyor

`x86_64` APK'nın **üçte birinden fazlası** ve gerçek telefonlarda hiç
çalışmıyor — yalnızca emülatör ve birkaç Intel Chromebook için. Her
kullanıcı, ihtiyaç duymadığı 40 MB'ı indiriyordu.

### Sonuç

| Derleme | Boyut |
|---|---|
| Evrensel (eski) | 103,9 MB |
| **arm64-v8a** | **39,6 MB** |
| armeabi-v7a | 32,6 MB |
| x86_64 | 44,8 MB (dağıtılmamalı) |

Gerçek bir kullanıcı için **%62 azalma**. Gizlilik uygulaması indiren
insan çoğu zaman kısıtlı ağda ve aceleyle indirir; 100 MB gerçek bir
engeldi.

### Doğrulandı — küçülmüş APK ÇALIŞIYOR

Bölünmüş APK'nın riski eksik kütüphanedir ve bu ancak o kütüphane
kullanıldığında ortaya çıkar (WebRTC yalnızca arama başlarken yüklenir,
yani açılış testi görmez). Bu yüzden iki kontrol birden yapıldı:
* Cihaza kuruldu, açılış temiz (`UnsatisfiedLink`/`dlopen` hatası yok)
* APK içeriği listelendi: her iki bölünmüş APK de kendi mimarisinin
  TÜM kütüphanelerini taşıyor — WebRTC dahil

### Karartma (`--obfuscate`) BİLEREK yapılmadı

Boyutu biraz daha düşürür ve tersine mühendisliği zorlaştırır, ama
§4p'nin telemetrisini bozar: `reportHandled` hatanın `runtimeType`
adını gönderiyor ve karartma altında bu anlamsız bir kısaltmaya
dönüşür. `FirebaseException.code` metin olduğu için hayatta kalır —
yani imzanın işe yarar yarısı korunur ama tip bilgisi kaybolur.
Yeni kurulmuş bir gözlem yeteneğini marjinal bir boyut kazancı için
körleştirmek doğru olmazdı.

---

## 4aa. ŞİFRESİZ GİDEN MESAJ ARTIK GÖRÜNÜYOR

`security_alerts.dart` · `encryption_datasource_impl.dart` ·
`security_banners.dart` · `messaging_screen.dart`

§4x arıza yolunu kapattı. Geriye **bilinçli** tercih kaldı: hiçbir üyeye
anahtar ulaştırılamadıysa mesaj şifresiz gider — aksi halde HERKES için
okunmaz olurdu. Tercih savunulabilir; **görünmez olması** değildi.

Arayüzde şifreli mesajlar kilit ikonu taşıyor. Şifresiz olan yalnızca
**kilidin yokluğuyla** belli oluyordu — kimsenin fark etmediği bir
sinyal.

### 🐞 Balon başına rozet YANLIŞ araçtı

İlk akla gelen, `isEncrypted == false` olan her balona "🔓 şifresiz"
rozeti koymaktı. Kaynaklar sayılınca bunun gürültü üreteceği görüldü:

| Kaynak | Neden şifresiz | Meşru mu |
|---|---|---|
| `messaging_notifier` | gönderim sırasındaki geçici yer tutucu | ✅ |
| GIF | içerik zaten herkese açık Giphy adresi | ✅ |
| Anket | toplulaştırma için bilinçli ödün (kodda yazılı) | ✅ |
| Yedek geri yükleme | yerel, tarihsel kayıt | ✅ |
| Çağrı kaydı | ortalı sistem bildirimi | ✅ |
| **Grup anahtarsız** | **gerçek sorun** | ❌ |

Hepsini işaretlemek §4s'in tuzağına düşerdi: **gürültü, gerçek uyarıyı
da görünmez kılar.** Gönderdiği her mesajda rozet gören kullanıcı bir
hafta sonra hiçbirini okumaz.

### Doğru araç: GRUP düzeyinde bant

Durum mesaj düzeyinde değil, grup düzeyinde bir gerçektir: "bu grupta
şifreleme çalışmıyor". §4s'te kurulan bant altyapısı kullanıldı.

* **Turuncu** — kırmızı değil. Kimlik değişimi ve anahtar rotasyonu
  uyarılarıyla aynı ağırlıkta göstermek yanlış olurdu: bu, bilinçli bir
  tercihin sonucudur; ciddi ama felaket değil.
* **Kapatılamaz** — kullanıcı görmezden gelebilseydi şifreli sandığı
  grupta konuşmaya devam ederdi.
* **Kendiliğinden kalkar** — üyeler anahtarlarını yayınlayınca şifreleme
  başlar ve bayrak temizlenir. Kalıcı bir bant, bir süre sonra
  görmezden gelinirdi.

### Disk trafiği

Bayrak `SharedPreferences`ta durur ama her mesajda yazılmaz: şifreleme
katmanı son bilinen durumu bellekte tutar ve yalnızca DEĞİŞİMDE yazar.

**Doğrulama:** 7 yeni test (257 → **264**). En kritiği "KAPATILAMAZ
(görmezden gelinemez)" ve "şifreleme çalışınca bayrak TEMİZLENİR".

---

## 4ab. SIZMIŞ SIRLAR — kod tarafı hazır, tarama kalıcı kapı oldu

`test/tooling/secret_scan_test.dart` (yeni) · **`SIR_DONDURME.md`**

Sırların kendisi konsollarda döndürülür (parola, Giphy anahtarı) —
kodda yapılacak iş, döndürmenin işe yaradığından emin olmak ve aynı
sızıntının tekrarını engellemektir.

### Önce ölçüldü: kod zaten hazırmış

| Kontrol | Sonuç |
|---|---|
| `.gitignore` → `key.properties`, `*.jks`, `*.keystore`, `.env` | ✅ korunuyor |
| Giphy anahtarı | ✅ `String.fromEnvironment`, **gömülü yedek YOK** |
| README / `TURN_KURULUMU.md` | ✅ yer tutucu (değerler sınandı, yazdırılmadı) |
| `android/key.properties` | gerçek parola — yeri burası, `.gitignore`da |
| Firebase `AIza...` | sır DEĞİL; kısıtlanmalı (konsol işi) |

Tarama üç **yanlış pozitif** de üretti: 32 karakterlik "anahtar" kalıbı
`ConversationRemoteDataSourceImpl` gibi uzun tanımlayıcılara takılıyordu.
Kalıcı testte bu kalıp kullanılmadı.

### Kalıcı kapı: gömülü sır testi

`.gitignore` yalnızca DOSYA sızıntısını engeller; birinin anahtarı
doğrudan bir `.dart` dosyasına yazmasını engellemez. Yeni test bunu
yakalar ve `flutter test` ile CI'da otomatik çalışır.

**Bulunan değer yazdırılmaz** — yalnızca dosya:satır ve kalıbın adı.
Hata mesajı da bir sızıntı yüzeyidir; CI günlükleri çoğu zaman herkese
açıktır.

Muaf tutulanlar ve gerekçeleri koda yazıldı: `key.properties` (yeri
orası), `google-services.json` + `firebase_options.dart` (Firebase
istemci anahtarları sır değildir; korunma yolu gizlemek değil, Cloud
Console'da uygulama kısıtlamasıdır).

### Testin gerçekten yakaladığı doğrulandı

Sahte bir `AIza...` anahtarı ve gömülü parola içeren geçici bir dosya
eklendi → test iki kalıbı da yakaladı ve dosya:satır bildirdi; dosya
silinince yeniden geçti.

### ⚠️ Döndürme rehberindeki kritik ayrım

`SIR_DONDURME.md` şu ayrımla başlıyor: **parola mı sızdı, anahtar
dosyası mı?** Denetimde görüntülenen paroladır. Anahtar deposu
sızmadıysa `keytool -storepasswd` / `-keypasswd` yeter; yükleme anahtarı
sıfırlamaya gerek kalmaz.

Anahtar dosyası da sızdıysa belirleyici soru **Play App Signing
kullanılıp kullanılmadığıdır**: kullanılmıyorsa uygulama imzalama
anahtarı DEĞİŞTİRİLEMEZ — değişirse mevcut kullanıcılar güncelleme
alamaz (Android farklı imzayı farklı uygulama sayar).

Ayrıca sıra uyarısı: **önce imzalama, sonra Firebase SHA-1 kısıtlaması.**
Ters sırada yapılırsa kısıtlama yanlış parmak izini tutar ve uygulama
Firebase'e erişemez.

**Doğrulama:** 3 yeni test (264 → **267**).

---

## 4ac. ÖLÜ KOD SİSTEMATİK TARANDI — DÖRDÜNCÜSÜ BULUNDU

`test/tooling/secret_scan_test.dart` · `conversations_screen.dart` (silindi)
· Clean çağrı katmanı (işaretlendi)

Bu oturumda aynı hata sınıfı ÜÇ kez çıktı, hepsi ölü ya da ikizlenmiş
kod yüzünden. Tek tek bulmak yerine sistematik tarandı.

### 🐞 Dördüncüsü: `conversations_screen.dart` (306 satır)

Sohbet listesinin **bayat ikizi**. Hiçbir yerden import edilmiyordu;
canlı ekran `home_shell.dart` (1392 satır).

Ne kadar bayat olduğu ölçüldü — ölü ekranda **hiçbiri yok**:

| Özellik | Ölü | Canlı |
|---|---|---|
| Takma adlar (`userAliases`) | 0 | 5 |
| Sabitleme (`pinned`) | 0 | 6 |
| Kilit (`isLocked`) | 0 | 3 |
| Profil fotoğrafı (`UserAvatar`) | 0 | 3 |

⚠️ İçinde **gelen arama dinleyicisi** de vardı. Canlı ekranda da
bulunduğu (`home_shell.dart:286`) ayrıca doğrulandı — yoksa silmek
gelen aramayı tamamen kırardı. Silindi.

### Clean çağrı katmanı: SİLİNMEDİ, İŞARETLENDİ

`StartCall` / `AnswerCall` / `EndCall` usecase'leri DI'da kayıtlı ama
hiçbir yerden çözümlenmiyor. Yine de **silinmedi**: §3b'deki birleştirme
işinin hedefi tam olarak orası; silmek göçü zorlaştırırdı.

Bunun yerine dört dosyanın başına, §4u'nun kök sebebine doğrudan hitap
eden bir uyarı kondu — hangi yolun CANLI olduğu artık kodun kendisinde
yazıyor. §4t'deki hata tam olarak bu bilginin eksikliğinden çıkmıştı.

### İnce tarama İŞE YARAMADI (dürüstlük)

Dosya değil SINIF düzeyinde tarama denendi: 33 "atıfsız genel sınıf"
buldu ve çoğu **yanlış pozitifti** — Riverpod notifier'ları kendi
dosyalarındaki sağlayıcıdan kullanılıyor, tarama yalnızca BAŞKA
dosyalara bakıyordu. Kovalanmadı; kalıcı teste yalnızca dosya düzeyi
kontrol alındı çünkü yanlış pozitifi yok.

### Kalıcı kapı

`flutter test` artık iki şeyi birden arıyor: **gömülü sır** (§4ab) ve
**import edilmeyen dosya**. İkisinin de gerçekten yakaladığı, geçici
dosyalar eklenerek doğrulandı; eklenince kırıldılar, silinince geçtiler.

Hata mesajı gerekçeyi de taşıyor: *"Bir sonraki geliştirici bunları
CANLI sanıp üzerinde çalışabilir."* Tehlike yer kaplaması değil, yanlış
yeri düzeltmektir.

### 🐞 Yol boyunca: Dart regex kaçış tuzağı

İlk sürüm `RegExp` ile import arıyordu ve **hiçbir dosyayı bulamıyordu**
— `injection.dart` bile "ölü" görünüyordu. Kaçış kurallarıyla uğraşmak
yerine düz metin eşleşmesine geçildi: bir import satırı dosya adını
daima kapanış tırnağından hemen önce taşır (`.../injection.dart'`).
Daha basit, yanlış pozitifi yok.

**Doğrulama:** 1 yeni test (267 → **268**), 306 satır ölü kod silindi.

---

## 4ad. CI KAPILARI YEREL KAPIYLA EŞİTLENDİ

`.github/workflows/ci.yml`

Eklenen bütün testler ancak CI **gerçekten geçit tutuyorsa** işe yarar.
İki boşluk kapatıldı.

### 1. Analiz CI'da daha GEVŞEKTİ

```
yerel:  flutter analyze              → SIFIR bulgu (info dahil)
CI:     flutter analyze --no-fatal-infos
```

Info düzeyinde bir gerileme **CI'dan geçer, yerelde kırılırdı** — yani
CI yanlış güven veriyordu. Bayrak kaldırıldı; iki kapı artık aynı
sıkılıkta.

### 2. 🐞 Functions işi yalnızca SÖZDİZİMİNE bakıyordu

§4n'in dersi tam olarak buydu ve CI'ya hiç yansımamıştı:

> Dağıtım aylarca `User code failed to load. Cannot determine backend
> specification.` ile düşüyordu. Sebep `admin.storage().bucket()`
> çağrısının MODÜL SEVİYESİNDE olmasıydı. `node --check` bunu göremez —
> sözdizimi kusursuzdu.

Firebase CLI dağıtımdan önce kodu bir kez yükler; o kontrol CI'ya
taşındı.

### Yeni kapının GERÇEKTEN yakaladığı doğrulandı

§4n'in hatası birebir geri konuldu (`admin.storage().bucket()` modül
seviyesinde) ve iki kapı karşılaştırıldı:

| Kapı | Sonuç |
|---|---|
| `node --check` (eski) | **çıkış 0 — geçti**, hatayı göremedi |
| Modül yükleme (yeni) | **çıkış 1 — yakaladı** (`FirebaseError`) |

⚠️ İlk deneme isabetsizdi: taklit değişkenine `_bucket` adı verilmişti
ve dosyada zaten o adda bir değişken vardı (§4n'in tembel yükleme
düzeltmesinden), yani çalışma zamanı hatası yerine SÖZDİZİMİ hatası
üretildi — her iki kapı da yakalardı. Benzersiz adla tekrarlandı;
ancak o zaman gerçek ayrım görüldü.

### Yanılıp düzeltmediğim şey (dürüstlük)

`build` işindeki `--dart-define=SECRETER_TURN_*` değerlerinin §4f'ten
kalma **bayat** olduğunu düşündüm. Kodu okuyunca yanıldığım anlaşıldı:
bunlar Cloud Function erişilemezse devreye giren, belgelenmiş bilinçli
bir yedek (kodda "APK'dan çıkarılabilir" uyarısıyla birlikte). Çalışan
yapılandırmaya dokunulmadı.

Ayrıca `npm ci` her iki yolda da (`functions`, `test/rules`) temiz
çalışıyor — §4n'de dağıtımı engelleyen lock uyuşmazlığı geri gelmemiş.

---

## 4ae. 🐞 KENDİ İŞİMİ DENETLEDİM — §4aa EKSİKMİŞ

`encryption_datasource_impl.dart` · `messaging_screen.dart`

§4t bu oturumda **bozuk gönderildi**: düzeltme canlı olmayan katmana
yapılmıştı. Aynı hatanın başka değişikliklerimde de olup olmadığı
sistematik olarak arandı ve bir tane daha bulundu.

### 🐞 Ripgrep bu dosyayı "ikili" sayıyor

`encryption_datasource_impl.dart` içinde gerçek bir NUL baytı var —
kasıtlı bir sentinel: `lostMarker = '\u0000E2EE_LOST'` (kullanıcı
metniyle çakışamasın diye).

Sonucu: `rg` dizin taramasında bu dosya için **"binary file matches"**
yazıp eşleşen SATIRLARI göstermiyor. Dosyanın adı görünüyor ama içeriği
görünmüyor — kırpılmış çıktıda kolayca gözden kaçıyor.

§4aa'nın kaynak sayımı tam olarak bu yüzden eksik kaldı.

### Bulunan: BİREBİR sohbetlerde şifresiz mesaj SİNYALSİZDİ

Beş düz metin yolu varmış; §4aa yalnızca birini kapsıyordu:

| Yol | Durum | §4aa | Şimdi |
|---|---|---|---|
| Grup, üye < 2 | dejenere grup | ❌ | ✅ |
| Grup, kimsenin anahtarı yok | bilinçli tercih | ✅ | ✅ |
| **Birebir, karşı tarafın anahtar paketi yok** | bilinçli tercih | ❌ | ✅ |
| **Birebir, oturum durumu okunamadı** | **ARIZA** | ❌ | ✅ |
| Grup, istisna | arıza | §4x kapattı | — |

Yani birebir bir mesaj şifresiz gidiyor ve kullanıcıya **hiçbir şey**
söylenmiyordu. Kodun kendi yorumu "kullanıcı durumu görebilir" diyordu
— ama görebileceği tek şey kilit simgesinin YOKLUĞUYDU; §4aa'nın
tamamı zaten bunun bir sinyal olmadığı üzerine kuruluydu.

### Yapılan

Bayrak dört yola da bağlandı, bant `isGroup` kısıtından çıkarıldı ve
metin ikisini birden kapsayacak şekilde nötrleştirildi
("Bu sohbette… anahtarlar henüz hazır değil").

Başarılı **birebir** şifrelemede bayrağın temizlenmediği de fark edildi
— karşı taraf anahtarlarını yayınladıktan sonra bant asılı kalırdı.
Düzeltildi.

### ⚠️ Açık kalan soru

"Oturum durumu okunamadı" yolu bir **arıza**, bilinçli bir tercih değil.
§4x'in mantığıyla kapatılması (mesajı göndermemek) tartışılmalı. Bu
turda yalnızca raporlandı + bant gösterildi; kapatmadan önce gerçekte ne
sıklıkta olduğu ölçülmeli. `DEVAM.md` §3b.

### Ders

Bu oturumda üçüncü kez aynı kök: **düzeltmenin canlı yola ulaştığını
varsaymak.** İlk ikisi §4t (bozuk gönderildi) ve §4u (iki model). Bu
sefer hatayı üretime gitmeden kendi denetimimde yakaladım — ama ancak
`rg`'nin sessiz kısıtını fark ettikten sonra.

---

## 4af. 🐞 GRUP ANAHTARI ROTASYONU YALNIZCA TEK CİHAZDA YAPILIYORDU

`group_key_service.dart` · `group_repository_impl.dart`

`DEVAM.md` §3b/2'nin son maddesi şuydu: *"uyarı yalnızca rotasyonu
tetikleyen cihazda görünüyor; diğer yöneticiler bilmiyor."* Madde bir
**bildirim** eksiği olarak yazılmıştı. Kod okununca eksiğin bildirim
değil **rotasyonun kendisi** olduğu ortaya çıktı.

### Sender key deseninde rotasyon TEK TARAFLI YAPILAMAZ

Grup E2EE'sinde her üyenin **kendi** gönderen zinciri vardır ve
`rotate()` yalnızca çağrıldığı cihazdakini siler. Oysa rotasyon tek bir
yerden tetikleniyordu: `GroupRepositoryImpl._afterMembershipChange`,
yani üyeyi **atan yöneticinin** cihazından.

```
A, X'i gruptan atar
  └─ A'nın zinciri yenilenir            ✅
     B, C, D'nin zincirleri DEĞİŞMEZ    ❌
```

X, gruptan atılmadan önce B, C ve D'nin zincir anahtarlarını almıştı.
Zincir ileri doğru **deterministik** ilerlediğinden X, elindeki anahtarı
kendi başına sürerek onların **atıldıktan sonraki tüm mesajlarını**
çözmeye devam edebiliyordu. Süresiz.

Yani `GroupKeyService` sınıf başlığındaki

> *"Üyelik değiştiğinde (biri ayrıldı/atıldı) zincir ROTASYONA girer —
> ayrılan kişi sonraki mesajları okuyamaz."*

sözü yalnızca **tek cihazda** tutuyordu. Arayüzde hiçbir iz yoktu; atan
kişi "onu attım, artık okuyamaz" sanıyordu — `SecurityAlerts`
dokümanının "yanlış bir güvenlik hissi ve sessiz kalması kabul edilemez"
diye tarif ettiği durumun ta kendisi, ama uyarı bandının GÖREMEDİĞİ
yerde.

### Yapılan: üyelik farkı her cihazda, GÖNDERİM ANINDA ölçülür

`GroupKeyService.syncMembership(chatId, memberIds)` eklendi ve
`encrypt()`in **en başına** bağlandı. Her cihaz kendi gördüğü üye
listesini yerel bir anlık görüntüyle karşılaştırır; biri **çıkmışsa**
kendi zincirini rotasyona sokar.

**Neden sunucuya alan eklenmedi.** Üyelik değişimi zaten `memberIds`
üzerinden görülüyor; ayrı bir sürüm/epoch alanı yazmak yeni üst veri
üretirdi (§4o'nun tersine bir adım). Karşılaştırma tamamen yerel:
sunucuya hiçbir şey eklenmez, yeni kural gerekmez ve çevrimdışı kalmış
bir cihaz da döndüğünde farkı görür.

**Neden gönderim anında.** Zincirim yalnızca mesaj GÖNDERDİĞİMDE bir şey
açar. Atılan kişinin okuyabileceği ilk mesajdan hemen önce rotasyona
girmek, ayrı bir dinleyici ya da arka plan işi olmadan tam zamanında
koruma verir. Hiç mesaj göndermezsem okunacak bir şey de yoktur.

**Yalnızca ÇIKAN üye tetikler.** Üye eklenmesi tetiklemez: zincir ileri
ilerlediği için yeni üyeye ulaşan anahtar geçmiş mesajları zaten açmaz,
ve her eklemede rotasyon tüm gruba gereksiz bir yeniden dağıtım
maliyeti bindirirdi.

### İki tuzak, ikisi de testle kilitli

* **Boş liste bir üyelik DEĞİL, okunamamış bir listedir.** "Herkes
  çıkmış" sayılsaydı her geçici okuma hatası rotasyon doğurur ve grup
  anahtarı sürekli yeniden dağıtılırdı. Boş listede anlık görüntüye
  DOKUNULMAZ da — ezilseydi gerçek üyelik farkı kalıcı olarak
  kaybolurdu.
* **Bozuk anlık görüntüde güvenli taraf ROTASYONDUR.** Kimin çıktığı
  bilinemiyorsa bedeli tek bir yeniden dağıtım, alternatifi atılmış bir
  üyenin okumaya devam etmesidir.

### Bant artık HER cihazda çıkıyor

`SecureStore.delete` hatayı yutar (yalnızca raporlar), yani `rotate()`
başarısız olsa bile sessizce döner. Artık rotasyondan sonra zincirin
gerçekten gittiği **doğrulanıyor**; gitmediyse `SecurityAlerts` bayrağı
o cihazda kalkıyor ve sohbet ekranındaki uyarı bandı "Tekrar dene" ile
orada da çıkıyor. `DEVAM.md` §3b/2'nin sorduğu şey buydu — ama artık
yalnızca haber vermekle kalmıyor, koruma da her cihazda uygulanıyor.

**Doğrulama:** 9 yeni test. Koruma kırılabilirliği ölçüldü: rotasyon
çağrısı geçici olarak kaldırıldığında "ÜYE ÇIKINCA zincirim rotasyona
girer" ve "BOZUK anlık görüntüde güvenli taraf ROTASYONDUR" testleri
anında düştü, geri alınınca geçti.

---

## 4ag. 🐞 ÜYE LİSTESİ OKUNAMAYINCA GRUP MESAJI ŞİFRESİZ GİDİYORDU

`message_repository_impl.dart` · `encryption_datasource_impl.dart`

C-06 ("şifreleme hatası sessizce DÜZ METNE düşüyordu") §4x'te grup
yolunda kapatılmıştı: istisnada mesaj artık gönderilmiyor. Ama aynı
sonuca çıkan **ikinci bir kapı** açık kalmıştı ve bu turda bulundu.

### Bir ARIZA, bir DURUM gibi okunuyordu

```dart
Future<List<String>> _membersOf(String chatId) async {
  try {
    return await remoteDataSource.memberIds(chatId);
  } catch (e) {
    debugPrint('Üye listesi alınamadı ($chatId): $e');
    return const [];              // ← ARIZA burada DURUMA dönüşüyor
  }
}
```

Dönen boş liste şifreleme katmanına gidiyor ve orada:

```dart
if (myUid == null || memberIds.length < 2) {
  _noteGroupPlaintext(chatId, true);
  return EncryptionResult(ciphertext: plaintext, isEncrypted: false);
}
```

dalına düşüyordu — yani **"dejenere grup"** sayılıp mesaj sunucuya
**düz metin** yazılıyordu. Geçici bir Firestore okuma hatası (ağ
titremesi, kural reddi, kota) bir grup mesajının açıkta gitmesine
yetiyordu. §4x'in kapattığı davranışın aynısı, başka bir kapıdan.

Bu, projede tekrar eden desenin bir başka örneği: **bir katmanın
"veri yok" dediği yerde diğer katman "böyle bir durum var" anlıyor.**
Hata yutulduğu an, iki katman arasındaki ayrım kayboluyor.

### Yapılan

`_membersOf` artık **yutmuyor**; istisna yukarı gidiyor. Üç çağıranın
(`sendTextMessage`, `sendMediaMessage`, `editMessage`) hepsi zaten
`ServerException`ı kullanıcıya görünen bir `ServerFailure`a çeviriyordu,
yani mesaj **gönderilmiyor** ve kullanıcı hatayı görüyor. §4x'in
ilkesi: şifreli sanılan bir mesajın açıkta gitmesindense
gönderilmemesi yeğdir; kullanıcı tekrar deneyebilir.

Artık gerçekten tek kişilik bir gruba düşen dal da `reportHandled`a
bağlandı — §4aa/§4ae'de bant bağlanmıştı ama telemetri yoktu, yani bu
dalın gerçekte ne sıklıkta çalıştığı ölçülemiyordu.

### ⚠️ Testin YANLIŞ SEBEPLE geçtiği yakalandı

İlk yazılan medya testi var olmayan bir dosya yolu kullanıyordu.
`sendMediaMessage`, üye listesini okumadan **önce** `file.length()`
çağırdığı için test "dosya bulunamadı" ile geçiyor, üyelik yolunu hiç
çalıştırmıyordu. Gerçek bir geçici dosyayla değiştirildi.

Aynı şekilde ilk sürümde `mockEncryption.encrypt` stub'lanmamıştı;
yutan davranış geri konsa bile stublanmamış mock null döndüğü için
testler **yine** geçiyordu. Stub, gerçek `encrypt()` davranışını taklit
edecek şekilde yazıldı (iki üyeden az → düz metin). Ancak ondan sonra
üç testin de gerçekten koruduğu doğrulandı: yutan davranış geri
konduğunda **üçü birden** düştü.

**Ders (§4v'nin devamı):** bir testin geçmesi yetmez — o testin,
korumaya çalıştığı hata geri geldiğinde DÜŞTÜĞÜ ölçülmelidir. Yanlış
sebeple geçen test, korumasız bir alanı korunuyor sanmaktır.

**Doğrulama:** 3 yeni test.

---

## 4ah. YUTULAN HATALAR — ÜÇÜNCÜ TUR VE `AppLogger` SADELEŞTİRİLDİ

`DEVAM.md` §3b/2'nin kalan iki maddesi.

### Kalan yutmalar tarandı, 16'sı bağlandı

Kaynak ağacındaki `catch` blokları içindeki **97** `debugPrint`
taranıp tek ölçüte göre elendi: *kullanıcı bir GARANTİNİN geçerli
olduğunu sanıyor ama sessizce geçerli değil.* Gürültü sinyali boğduğu
için bozuk kayıt atlama, kutu kapatma gibi olağan dayanıklılık
yutmalarına dokunulmadı.

| Yer | Kullanıcı ne sanıyor | Gerçekte ne oluyor |
|---|---|---|
| `chat_lock_service` | "sohbet kilitli" | liste okunamıyor → **kilitli sohbetlerin HEPSİ PIN'siz açılıyor** |
| `block_service` | "onu engelledim" | liste okunamıyor → engelli kişinin içeriği geri geliyor |
| `secure_media_cache` ×2 | "sildim / panik modundayım" | çözülmüş fotoğraflar cihazda kalıyor (C-07) |
| `message_local_datasource` ×3 | "hesabımı/sohbeti sildim" | çözülmüş mesajlar diskte kalıyor (C-07) |
| `auth_service` ×2 | "hesabım silindi" | yedek temizlik de tutmadı → profil ve hikâyeler sunucuda |
| `meet_code_service` | "kodu iptal ettim" | kod canlı, paylaşılan herkes hâlâ ulaşabiliyor |
| `notification_service` ×3 | "bildirimler çalışıyor" / "çıkış yaptım" | hiç push gelmiyor · çıkış yapılmış cihaza bildirim akmaya devam ediyor |
| `splash_screen` | "güvenlik kontrolü geçti" | kontrol hiç yapılmadı, `safe()` varsayıldı |
| `privacy_controller` | "ayarlarım geçerli" | okunamadı, varsayılana düşüldü |
| `privacy_service` | "uygulama kilidim açık" | taşıma yarıda kaldı → kilit ayarı kayıp, düz metin kopya yerinde |
| `app_disguise_service` | "kılık kapalı/açık" | sistemin gerçeği okunamadı, arayüz yanlış gösteriyor |
| `recovery_key_service` | "bu hesap eski sürümden" | aslında ARIZA — kurtarma anahtarı üretilemedi, geri dönüş yolu yok |

Ölçüt karşılanmayanlar **bilerek** bırakıldı: `main.dart`'ın BOOT
yolları (telemetri henüz ayakta değil), bozuk önbellek kaydı atlama,
LRU kutu kapatma, `rethrow` eden yollar (zaten yukarı çıkıyor).

Sayılar: `reportHandled` çağrısı **121 → 142**, `catch` içinde yutulan
`debugPrint` **97 → 78**.

### `AppLogger` sadeleştirildi (yaygınlaştırmak yerine)

`DEVAM.md` "ya yaygınlaştır ya da sadeleştir" diyordu. Sadeleştirildi.

Arayüzde `debug`/`info`/`warning`/`error` vardı; **yalnızca `error`**
çağrılıyordu ve onu da tek bir yer çağırıyordu: `reportHandled`.
Çağrılmayan üç metot ölü bir **yazma yüzeyiydi** — arayüze bakan bir
sonraki geliştiriciye "burası genel amaçlı bir günlükçü,
`logger.info` yazabilirim" diyen türden. Bu projede aynı desen üç kez
zarar verdi (§4i, §4o, §4t) ve buradaki bedeli somut olurdu:
`logger.info('sohbet $chatId açıldı')` gibi bir satır hiçbir maskeleme
kapısından geçmeden tanımlayıcı loglardı.

Arayüz tek metoda indirildi; `ConsoleLogger` üretimde hiçbir şey
yazmıyor (yığın izi ve hata metni tanımlayıcı taşıyabilir, `adb logcat`
cihazdaki başka uygulamalara da açıktır). `Redact` yardımcıları
duruyor — onlar kullanılıyor. Artık günlüğe bir şey yazmanın TEK yolu
`reportHandled` geçidinden geçmek.

---

## 4ai. ÇEVİRİ AÇIĞI KAPANDI VE KALICI BİR KAPIYA BAĞLANDI

`app_localizations.dart` · `test/core/i18n/translation_gate_test.dart` (yeni)

`DEVAM.md` §3b/3. Madde "41 yeni anahtar 14 dile eklenmeli… toplam ~82
anahtar açığı var" diyordu. Ölçülünce açık **89 anahtar × 14 dil =
1246 çeviri** çıktı.

### Açığın nerede olduğu, "eksik ama bozuk değil"den daha kötüydü

Eksik 89 anahtarın dağılımı rastgele değildi — hepsi **son turlarda
eklenen güvenlik metinleriydi**:

| Grup | Adet | Ne zaman görünür |
|---|---|---|
| `err_*` | 45 | mesaj gönderilemedi, şifrelenemedi, oturum kurulamadı |
| `threat_*` | 10 | root/hook/emülatör/debugger uyarı ekranı |
| `sec_*` | 9 | grup şifresizlik bandı, rotasyon başarısızlığı, doğrulama önerisi |
| `recovery_*` | 8 | kurtarma anahtarı parolası akışı |
| `video_trim_*`, sözcükler | 17 | kırpma ekranı, önizleme etiketleri |

Yani Rusça arayüz kullanan biri **tam olarak en kritik anlarda**
İngilizce metin görüyordu: mesajı şifrelenemediğinde (§4x'in
"gönderilmedi" uyarısı), cihazında hook aracı bulunduğunda, gruptan
atılan birinin hâlâ okuyabildiği söylendiğinde (§4af'nin bandı) ve
kurtarma anahtarına parola belirlerken — telefonu kaybettiğinde tek
geri dönüş yolunu kurarken.

`DEVAM.md`'nin "bozuk değil ama eksik" ifadesi bu yüzden açığı olduğundan
hafif gösteriyordu. Bir gizlilik uygulamasında güvenlik uyarısının
kullanıcının anlamadığı bir dilde çıkması, uyarının hiç çıkmaması
demektir.

### 🚪 Asıl düzeltme: kapı

Çevirileri yazmak açığı kapatır ama **tekrar açılmasını engellemez.**
Kök sebep mekanizmadaydı:

```dart
String t(String key) =>
    _values[lang]?[key] ?? _values['en']?[key] ?? key;
```

Bu yedek zinciri doğru — arayüz asla boş kalmaz, ham anahtar ekrana
çıkmaz. Ama yan etkisi şuydu: **eksik çeviri hiçbir yerde
görünmüyordu.** `tr`+`en`'e anahtar eklemek diğer 14 dili sessizce
geride bırakıyor, hiçbir test düşmüyor, hiçbir uyarı çıkmıyordu. Açık
89 anahtara kadar tam da bu yüzden büyüdü.

Projede tekrar eden sınıfın aynısı (§4m, §4n, §4t, §4af): *çalışmayan
şey hata vermiyor, o yüzden aylarca görünmüyor.*

`translation_gate_test.dart` altı invaryantı kilitliyor:

1. `tr` ve `en` **aynı** anahtar kümesini taşır (yedek zinciri kopmasın)
2. **Her** dil referans setinin tamamını taşır
3. Hiçbir dilde **fazladan** anahtar yok (yazım hatası / ölü artık)
4. Hiçbir çeviri **boş** değil — boş dize `??` ile yakalanmaz, `t()`
   onu geçerli sayar ve kullanıcı BOŞ bir uyarı görür
5. **Dil seçici ile tablo birebir örtüşür** — `AppLanguages.all` hem
   seçiciyi hem `supportedLocales`i besliyor; listeye tabloda karşılığı
   olmayan bir dil eklenirse kullanıcı onu bayrağıyla seçer ve arayüz
   tamamen İngilizce kalır
6. Anahtar biçimi tutarlı (`^[a-z0-9_]+$`)

Kapı, `AppLocalizations` üzerine iki `@visibleForTesting` getter ile
çalışıyor; üretim kodu onları kullanmıyor.

### 🐞 Yan bulgu: bir test AÇIĞIN KENDİSİNİ doğruluyordu

`error_keys_test.dart` içinde şu test vardı:

```dart
test('çevirisi olmayan dil İNGİLİZCE yedeğine düşer, anahtara DEĞİL', () {
  expect(_tr('err_send_message', lang: 'de'),
         _tr('err_send_message', lang: 'en'));
});
```

Almanca çeviri eklenince bu test **kırıldı** — çünkü Almanca artık
İngilizce'ye düşmüyor. Test, yedek MEKANİZMASINI doğruladığını
sanıyordu; gerçekte Almanca'nın bu anahtarda çevirisiz olduğunu
doğruluyordu. Yani doğru davranış testi kırdı.

Desteklenmeyen bir dil koduyla (`'xx'`) yeniden yazıldı: mekanizma hâlâ
önemli (tanımadığımız bir cihaz dili gelirse arayüz İngilizce olmalı,
ham anahtar değil), ama desteklenen dillerdeki eksikleri artık kapı
engelliyor.

**Ders:** bir testin neyi doğruladığı, adının söylediğiyle aynı
olmayabilir. Mevcut durumu "beklenen" diye sabitleyen test, o durum
düzeltilince kırılır — ve kırılması iyi haberdir.

### ⚠️ Çevirilerin gözden geçirilme durumu — dürüst not

`app_localizations.dart`'ın kendi uyarısı hâlâ geçerli: **ana dili
konuşan biri gözden geçirmeli.** Bu 1246 çeviri o incelemeden
geçmedi.

Yine de İngilizce yedeğinden kesin olarak daha iyi: 16 dilin hepsi
yaygın konuşulan dillerdir, metinler kısa arayüz dizeleridir ve
alternatif, kullanıcının hiç anlamadığı bir güvenlik uyarısıydı.
Doğrulanan biçimsel özellikler:

* Arapça RTL metni bozulmadan yerleşti; `GlobalWidgetsLocalizations`
  zaten yön veriyor ve `ar` `supportedLocales` içinde — ek iş
  gerekmedi.
* Çince tam-genişlik noktalama (`。`, `：`) korundu.
* Fransızca/Yunanca/İtalyanca kesme işaretleri Dart dizesinde `\'`
  olarak kaçırıldı.
* `lock_too_many_attempts` gibi **sonuna süre eklenen** anahtarlarda
  sondaki boşluk korundu (Çince'de bilerek yok: tam-genişlik iki nokta
  zaten ayırıyor).

Yayın öncesi öncelik sırası, o dildeki kullanıcı sayısına göre
belirlenmeli; en kritik 19 anahtar `sec_*` + `threat_*` grubudur.

**Doğrulama:** 7 yeni test (280 → **287**). Kapının kırılabilirliği
ölçüldü: Almanca'dan bir anahtar silinip Rusça'da bir çeviri
boşaltıldığında ilgili iki test anında düştü, geri alınınca geçti.

---

## 4aj. `calls`'A YAZAN İKİNCİ YOL SİLİNDİ — AYRIŞMA ARTIK İMKÂNSIZ

`call_usecases.dart` · `call_repository.dart` · `call_repository_impl.dart` ·
`call_remote_datasource.dart` · `features/.../call_model.dart` ·
`injection.dart` · `call_document.dart`

`DEVAM.md` §3b/5. Madde "iki çağrı modeli birleştirilmeli" diyordu ve
§4v birleştirmeyi **cihazda arama testi yapılamadığı için** ertelemişti.
Bu tur üçüncü bir yol izlendi: birleştirmek yerine **ölü yazarı silmek.**

### Kök sebep "iki model" değil, "iki YAZAR"dı

§4u'nun teşhisi şuydu: `calls` koleksiyonuna iki model yazıyor ve §4t
alanı yalnızca birine ekledi. §4v ortak şemayla (`buildCallDocument`)
ayrışmayı test altına aldı — ama **iki yazar durmaya devam etti.**

Oysa ikinci yazar hiç çalışmıyordu:

| Katman | Ölü olan | Durum |
|---|---|---|
| Usecase | `StartCall`, `AnswerCall`, `EndCall` | DI'da kayıtlı, **hiç çözümlenmiyor** |
| Repository | `createCall`, `answerCall`, `endCall` | yalnızca o usecase'lerden çağrılıyordu |
| Repository | `getAnswer` | **hiçbir yerden** çağrılmıyordu (usecase'i bile yoktu) |
| DataSource | `createCall`, `setAnswer`, `getAnswer`, `deleteCall` | yalnızca yukarıdakilerden |
| Model | `CallModel.toMap()` | yalnızca ölü `createCall`ten |

Yani `calls`'a **tam bir doküman yazacak** (ve silecek) bir kod yolu
duruyordu, üretimde hiç çalışmadan. §4t'nin ölü ICE metotları için
verdiği gerekçenin aynısı geçerliydi:

> *Ölü ICE metotları eski şemayı kodluyordu; bırakılsalardı bir sonraki
> geliştirici onları doğru yol sanıp `callerCandidates`'a yazabilirdi.*

Ayrıca §4t'nin **kendisi** bu tuzağa düşmüştü: alanı canlı yola değil,
tam da bu ölü katmandaki modele eklemişti.

### Yapılan

Ölü yazma yüzeyi tamamen kaldırıldı; canlı olan üç yol dokunulmadan
kaldı (`WatchIncomingCall`, `WatchCall`, `RejectCall`). Net **−237
satır**.

Sonuç: `calls`'a yazan **tek** model kaldı
(`lib/models/call_model.dart`, `CallService`). §4u'nun ayrışma sınıfı
artık bir testin yakaladığı şey değil — **yapısal olarak imkânsız.**

`CallRepositoryImpl`den `uuid` bağımlılığı da düştü; yorumla
işaretlendi, çünkü oraya bir kimlik üreteci geri koymak "bu katman
yeniden doküman oluşturabilir" demektir.

### 🔒 Geriye kalan gerçek bağ: CANLI YAZAR → CLEAN OKUR

Clean katmanı hâlâ o dokümanları **okuyor**: `watchIncomingCall` ve
`watchCall`, `CallService`in yazdığını `CallModel.fromMap` ile çözüyor.
Yazan ile okuyan ayrışırsa sonuç §4u'nun **aynısıdır**, sadece okuma
tarafından: sorgu kurulur, doküman gelir, üyelik boş çözülür, gelen
arama ekranı hiç açılmaz.

`call_schema_parity_test.dart` bu yüzden **eşitlik testinden tur
testine** çevrildi: canlı model bir doküman yazar, Clean model onu okur,
alanlar tek tek doğrulanır — `participants`, `callerId`, `status`, her
`CallStatus`, her `CallType` ve zaman damgaları. Canlı kodun gerçekten
çalıştırdığı yolu ölçtüğü için eski eşitlik testinden güçlü.

`call_document.dart` duruyor ama gerekçesi değişti: artık "iki yazarı
hizada tutmak" değil, **yazan/okuyan/sorgu üçlüsüne tek alan-adı
kaynağı** vermek.

### 🐞 Testin zayıf kaldığı yer ölçülerek bulundu

Tur testi ilk yazıldığında birebir aramayla sınanıyordu ve
`buildCallDocument`ten `participants` satırı kasten silindiğinde
**geçmeye devam etti.** Sebep: `readParticipants`, alan eksikse listeyi
`callerId`+`calleeId`'den türetiyor (§4m'nin geriye uyumluluk yedeği).
Yani 1:1 turunda alanın hiç yazılmaması fark edilmiyor — §4u'nun tam
hatası böyle gizlenebilirdi.

Üç kişilik bir grup vakası eklendi: yedek yalnızca iki kişi türetebildiği
için **üçüncü katılımcı sessizce düşer** ve test artık düşüyor.

**Ders (§4v ve §4ai'nin devamı):** bir testin geçmesi yetmez; korumaya
çalıştığı hata geri konduğunda DÜŞTÜĞÜ ölçülmelidir. Bu turda ilk
kırma denemesi testi düşürmedi ve zayıflık ancak o yüzden görüldü.

### ⚠️ Kalan iş — §3b/5 kapanmadı

`CallService`'in Clean mimariye taşınması hâlâ açık. Ama madde artık
"iki yazar ayrışabiliyor" riski taşımıyor; kalan tamamen mimari
tutarlılık işi ve **cihazda arama testi yapılabildiğinde** ele
alınmalı. Gelen arama senaryosu hâlâ doğrulanmamış (§6).

**Doğrulama:** 2 yeni test (287 → **289**), analyzer 0 bulgu. Kırma
denemesi: `buildCallDocument`ten `participants` çıkarıldığında grup tur
testi dahil 5 test düştü, geri alınınca geçti.

---

## 4ak. 🐞 ÜYE ÇIKARMA BİREBİR HARİTA EŞLEŞMESİNE DAYANIYORDU

`group_remote_datasource.dart` · `group_repository_impl.dart` ·
`group_model.dart` · `test/rules/firestore.rules.test.js`

`DEVAM.md` §3b/7'nin ikinci maddesi (`members[]` içindeki eski adların
temizliği) incelenirken, temizliği engelleyen şeyin kendisinin bir
**hata** olduğu ortaya çıktı.

### Kimlik `uid`di, eşleşme ise TÜM HARİTAYDI

Üye çıkarma şöyleydi:

```dart
'members': FieldValue.arrayRemove([memberModel.toMap()])
```

Firestore dizi elemanını **birebir** karşılaştırır: `uid`, `role`,
`isMuted`, `joinedAt` ve eski girdilerde `username` — hepsi tutmak
zorunda. Harita ise **arayüzün elindeki anlık görüntüden** kuruluyordu
(`_removeMember` üyeyi çağırandan alıyor, sunucudan taze okumuyordu).

Yani araya giren herhangi bir değişiklik eşleşmeyi bozar:

* başka bir yönetici o kişiyi terfi ettirdi ya da susturdu
* girdi 2. aşamadan önce yazıldığı için `username` taşıyor
* `joinedAt` biçimi kayıyor

Bozulunca ne olur: `memberIds`, `adminUids`, `mutedUids` ve
`memberCount` güncellenir ama **`members` dizisi olduğu gibi kalır.**
Atılan kişi grup bilgisi ekranında görünmeye devam eder, sayaç listeyle
tutmaz — ve **hiçbir hata çıkmaz.** `DEVAM.md` §6'nın "üye atma —
⚠️ EN ÖNEMLİSİ" elle testi tam da bunu arıyordu.

§4o bu tuzağı biliyordu ve `toMap()`e adı **koşullu** yazdırarak
kaçınmıştı. Ama bu çözüm yalnızca **ad** boyutunu kapatıyordu; rol ve
susturma boyutları açık kalmıştı. Üstelik aynı koşul, eski adların
sunucuda yaşamasının da sebebiydi (§3b/7).

### Yapılan: uid ile çıkarma, işlem içinde

`GroupRemoteDataSource.removeMemberFromArray(chatId, uid, extra:)`
eklendi. `runTransaction` içinde diziyi okur, **uid'e göre** süzer,
geri yazar.

**Neden işlem:** diziyi okuyup geri yazmak `arrayRemove`un
atomikliğini kaybettirir — eşzamanlı bir katılma sessizce ezilirdi.
İşlem o pencereyi kapatır.

**Yan kazanç:** `memberCount` artık `increment(-1)` değil **gerçek
uzunluk** olarak yazılır; daha önce kaymışsa kendini onarır. Üye
`members` içinde hiç yoksa (dizi ile `memberIds` zaten ayrışmışsa)
diğer alanlar yine yazılır — çağrı o tutarsızlığı düzeltiyor olabilir.

### 🐞 Yol üstünde: SUSTURULMUŞ ÜYE GRUPTAN ÇIKAMIYORDU

Ayrılma yolu hiç kural testi taşımıyordu. Test yazılınca çıktı:

`isSelfLeave()` yalnızca
`['memberIds','memberUsernames','members','memberCount']` değişimine
izin veriyor. İstemci ise `adminUids` ve `mutedUids` de yazıyordu.
`arrayRemove` bir şey çıkarmadığında dizi değişmez ve `affectedKeys()`
onu görmez — bu yüzden sıradan üyelerde sorun **hiç fark edilmiyordu.**

Ama kişi gerçekten `mutedUids` içindeyse dizi DEĞİŞİR, `onlyChanges`
düşer ve **ayrılma tamamen reddedilir.** Susturulmuş bir üye gruba
kilitleniyordu.

→ Ayrılırken `mutedUids`e hiç dokunulmuyor. Kalan girdi zararsızdır
(`canPost()` zaten üyelik de ister) ve ayrılıp yeniden katılarak
susturmadan **kaçılamaması** doğru davranıştır.

→ `adminUids` yalnızca kişi gerçekten yöneticiyse yazılır; o yol
kuralda `isAdmin()` dalından geçtiği için izinlidir. **Bu zorunlu:**
`isAdmin()` üyelik denetimi yapmaz, yalnızca `adminUids`e bakar —
ayrılan bir yönetici dizide kalırsa ayrıldığı gruba yönetici olarak
hükmetmeye devam ederdi.

### ✅ §3b/7 ikinci maddesi kapandı: eski adlar temizleniyor

Birebir eşleşme bağımlılığı kalkınca `toMap()`in koşullu `username`
yazması **hiçbir şeyi korumayan, yalnızca sızıntıyı yaşatan** bir
kalıntıya dönüştü. Ad artık hiçbir koşulda yazılmıyor; ayrıca çıkarma
işlemi kalan üyelerin girdilerinden de `username`i düşürüyor.

Sonuç: `members` dizisini yeniden yazan her yol (üye çıkarma, ayrılma,
rol/susturma değişimi) o gruptaki eski adları **kendiliğinden
temizler.** Kural izin veriyor — `usernameArrayNotGrown()` yalnızca
top-level `memberUsernames` dizisini kısıtlar.

⚠️ **Tam süpürme değil:** hiç üyelik/rol değişikliği olmayan bir grupta
eski adlar durur. Tam temizlik yönetici tarafında ayrı bir tarama
gerektirir (kural yalnızca yöneticiye açık); `DEVAM.md` §3b/7'de
kaldı.

### Doğrulama

* **6 yeni kural testi** (92 → **98**), gerçek emulator'de. Ayrılma
  yolu ilk kez test altında; `members` dizisinin uid ile yeniden
  yazılabildiği ve eski adların temizlenebildiği kural düzeyinde
  kilitlendi.
* **7 yeni Dart testi** (289 → **296**). En kritiği "🔒 arayüzdeki
  anlık görüntü BAYAT olsa da aynı çağrı yapılır": üye sunucuda terfi
  etmiş, susturulmuş ve eski adıyla duruyor olsa bile çıkarma uid ile
  yapılır.
* Kırılabilirlik ölçüldü: ayrılma yoluna `mutedUids` geri konduğunda
  iki test anında düştü, geri alınınca geçti.

⚠️ **Kural dosyası DEĞİŞMEDİ** — yalnızca test eklendi. Mevcut
`isAdmin()` ve `isSelfLeave()` bu yazma biçimine zaten izin veriyordu;
yeniden dağıtım gerekmiyor.

---

## 4al. KAYBOLAN MESAJ ARTIK SUNUCUDA DA SİLİNİYOR

`functions/index.js` → `cleanupExpiredMessages` (yeni) ·
`firestore.indexes.json` · `test/rules/firestore.rules.test.js`

### Vaadin sunucuda karşılığı yoktu

Süresi dolan mesajı sunucudan silen tek şey **okuyan istemciydi**:
`MessageRepositoryImpl` akıştaki mesajın `isExpired` olduğunu görünce
`hardDeleteMessage` çağırıyordu. Yani "kaybolan mesaj" üç koşula
bağlıydı:

1. birinin o sohbeti **açması**,
2. istemcinin değiştirilmemiş olması,
3. silme çağrısının başarılı olması (`hardDeleteMessage` hatayı yutuyor).

Üçü tutmazsa mesaj sunucuda **süresiz** kalıyordu; kullanıcı ise
"kayboldu" sanıyordu. Hikâyelerde bu iş `cleanupExpiredStories` ile
zaten sunucuda yapılıyordu — mesajlarda karşılığı hiç yoktu.

Bu, C-07'nin ("çözülmüş mesajlar cihazda sonsuza kadar kalıyordu")
**sunucu tarafındaki eşi.**

### Yapılan

`cleanupExpiredMessages`: 30 dakikada bir çalışan zamanlanmış iş,
`collectionGroup("messages")` üzerinde süresi dolmuş dokümanları toplu
siler. Turlu ve üst sınırlı (5 tur × 200 kayıt) — hatalı bir durumda
faturayı ve süreyi patlatmasın.

**Medya BURADA silinmiyor:** `cleanupDeletedMessageMedia` onDelete
tetikleyicisi zaten her silinen mesajın ekini topluyor ve Admin SDK
silmeleri de o tetikleyiciyi ateşliyor. İkinci bir silme yolu açmak,
ayrışabilecek bir yüzey üretmek olurdu.

### 🔬 İKİ VARSAYIM YAZILDI, EMÜLATÖR İKİSİNİ DE ÇÜRÜTTÜ

Bu bölümün asıl değeri burada.

**1. varsayım — "null tuzağı".** `MessageModel.toMap()` süre yoksa bile
alanı yazıyor: `expiresAt: null`. Firestore'un tip *sıralamasında* null
string'lerden önce geldiği için, `<= now` sorgusunun bu kayıtları da
eşleştireceği ve temizlik işinin **uygulamadaki bütün mesajları
sileceği** düşünüldü. Fonksiyona `> ""` alt sınırı ve büyük harfli bir
"BU SATIRI KALDIRMA" uyarısı yazıldı.

Emülatörde ölçüldü: **yanlış.** Eşitsizlik süzgeçleri null taşıyan
dokümanları zaten eliyor.

**2. varsayım — "Timestamp'ler yanlışlıkla eşleşir".** Bu kez alt
sınırın gerekçesi tip sıralamasına dayandırıldı: Timestamp String'den
önce geldiğine göre, gelecek tarihli bir Timestamp kaydı `<= "2020-…"`
ile eşleşir ve **süresi dolmamış mesaj silinir** denildi.

Emülatörde ölçüldü: **o da yanlış.**

**Ölçülen gerçek:** Firestore'da eşitsizlik süzgeçleri **tip
kapsamlıdır** — string ile karşılaştırma yalnızca string değerleri
döndürür. Yani risk tam ters yönde: string sorgusu, `expiresAt` alanı
Timestamp yazılmış bir kaydı **hiçbir zaman görmez** ve o mesaj
sonsuza kadar temizlenmeden kalır.

Bu, `cleanupExpiredStories`in **zaten belgelediği** durumun aynısı:

> *"`expiresAt` bazı kayıtlarda ISO string, bazılarında Timestamp
> olabilir. Tek tipte sorgulamak, diğer tipteki kayıtları SONSUZA KADAR
> temizlenmemiş bırakıyordu."*

→ Alt sınır kaldırıldı (hiçbir şey korumuyordu), yerine hikâyelerdeki
gibi **iki sorgu** (string + Timestamp) kondu.

**Ders:** varsayımla yazılmış bir gerekçe, kodun kendisi doğru görünse
bile bir sonraki geliştiriciyi yanlış yöne sürer. Bu turda gerekçe iki
kez yanlıştı ve ikisini de yalnızca ölçüm yakaladı. Fonksiyonun
yorumunda bu açıkça yazılı: *"Sorgu davranışını değiştirecek olan önce
ölçüm testlerine baksın."*

### Doğrulama

**4 yeni emülatör testi** (98 → **102**). Kural testi değiller; bir
Cloud Function'ın dayandığı Firestore davranışını gerçek motora karşı
kilitliyorlar:

* `null` taşıyan mesaj hiçbir sorguda eşleşmez (1. varsayımın çürüğü
  kayda geçti — bir sonraki okuyan alt sınırı yanlış sebeple
  savunmasın)
* 🔴 yalnızca string sorgusu, süresi dolmuş **Timestamp** kaydı kaçırır
* ✅ iki sorgu birlikte her iki tipi de yakalar
* ✅ süresi dolmamış kayıtlar hiçbir tipte eşleşmez

### ✅ DAĞITILDI — 2026-09-10

Önceki turlar (§4af–§4ak) yalnızca istemciyi değiştirmişti. Bu değişiklik
sunucuya iniyor:

```bash
firebase deploy --only firestore:indexes            # once indeks
firebase deploy --only functions:cleanupExpiredMessages
```

**Sıra bilinçli:** fonksiyonun sorgusu indekse bağlı; indeks önce gitti.

`firestore.indexes.json` içine `messages.expiresAt` için
**COLLECTION_GROUP** kapsamlı tek alan indeksi eklendi; koleksiyon-grubu
sorgusu onsuz çalışmaz. Varsayılan koleksiyon kapsamlı indeksler de
korundu.

**Dağıtım öncesi diff alındı** (§4n'in dersi: neyin değiştiğini bilmeden
dağıtma). Üretimdeki 6 bileşik indeks yereldekiyle **birebir aynıydı**;
yalnızca bir `fieldOverride` eklendi, **silinen indeks yok**. Böylece
tam dosya dağıtımının var olan indeksleri düşürme riski ölçülerek
elendi.

**Dağıtım sonrası doğrulandı:**
* `cleanupExpiredMessages` üretimde, `europe-west1`, durum ACTIVE
  (13 → **14** fonksiyon)
* `issueEntitlement` hâlâ **dağıtılmamış** — hedefli dağıtım ona
  dokunmadı
* `messages.expiresAt` `fieldOverride`ı COLLECTION_GROUP kapsamıyla
  üretimde görünüyor

### ✅ ÇALIŞTIĞI DA DOĞRULANDI — 2026-09-10 10:45 UTC

§4n'in dersi (*dağıtıldı ≠ çalışıyor*) gereği dağıtımla yetinilmedi;
ilk zamanlanmış çalışma beklenip günlük okundu:

```
10:45:02  cleanupexpiredmessages: Kaybolan mesaj temizliği: 4 kayıt silindi
```

Hata taraması temiz: `FAILED_PRECONDITION`, `requires an index` ve
`Unhandled` **yok** — yani koleksiyon-grubu sorgusu gerçekten çalışıyor
ve indeks inşa edilmiş durumda.

**O 4 kayıt bu bölümün gerekçesinin somut ölçüsüdür:** süresi çoktan
dolmuş ama sunucuda duran mesajlardı. Kimse o sohbetleri açmadığı için
istemci tarafı silme hiç tetiklenmemişti — tam olarak §4al'in kapattığı
sızıntı.

⚠️ **Zamanlayıcı ayrıntısı:** `every 30 minutes` `:00/:30`'da değil,
**fonksiyon oluşturulduktan 30 dk sonra** tetikleniyor (10:14 → 10:44).
İlk doğrulama denemesi 10:30 penceresini beklediği için boş döndü ve bir
an "çalışmıyor" sanıldı. Yeni bir zamanlanmış fonksiyon dağıtırken bunu
hesaba kat.

⚠️ **Kural dosyası değişmedi.** Fonksiyon Admin SDK ile çalışır,
kurallardan bağımsızdır.

### ⚠️ Kapsam dışı bırakılanlar (dürüstlük)

* **Gönderenin cihazındaki düz metin.** Ratchet tek yönlü olduğu için
  gönderen kendi mesajının düz metnini `SecureStore`da saklıyor
  (`e2ee_plain_…`). Bu kayıt **süre bilgisi taşımıyor** ve yerel bir
  süpürme yok; temizliği yalnızca istemcinin süre-dolma yolu yapıyor.
  Sunucu silmesi bunu bozmuyor — istemci akışı yerel Hive önbelleğinden
  de beslendiği için süresi dolan mesaj sohbet açıldığında hâlâ
  görülüp temizleniyor. Ama sohbet hiç açılmazsa (ya da mesaj 500'lük
  önbellek sınırından düşerse) düz metin cihazda kalır. **Bu açık bu
  turdan önce de vardı**; ayrı bir madde olarak `DEVAM.md` §3b'ye
  yazıldı.
* **`chats/{id}.lastMessage`** süresi dolan mesajdan sonra da duruyor.
  İçerik sızdırmıyor (önizleme `🔒 Mesaj` olarak maskeli, §4o) ama
  zaman damgası kalıyor. İstemci silmesinde de aynıydı.

---

## 4am. GELEN ARAMA ARTIK OTOMATİK DOĞRULANIYOR

`test/fixtures/call_incoming.golden.json` (yeni) ·
`test/features/call/incoming_call_contract_test.dart` (yeni) ·
`test/rules/firestore.rules.test.js` · `call_remote_datasource.dart`

`DEVAM.md` aylardır şunu yazıyordu:

> *"Otomatik doğrulama bu senaryoyu göremiyor, çünkü sorgu her iki
> durumda da sorunsuz kuruluyor, sadece boş dönüyor."*

Görebiliyormuş. Bu tur o cümle kaldırıldı.

### Var olan test neyi ölçmüyordu

`calls` için zaten bir kural testi vardı:

```js
it("kendi gelen aramalarını LİSTELEYEBİLİR", async () => {
  await assertSucceeds(getDocs(query(...)));
});
```

`assertSucceeds` sorgunun **İZİNLİ** olduğunu ölçer — **EŞLEŞTİĞİNİ**
değil. §4u'nun hatası tam olarak "sorgu kuruluyor ama boş dönüyor"du,
yani bu test kırık hâlde de **geçerdi.**

İkinci sorun: fixture elle yazılmıştı (`{callerId, calleeId,
participants, status}`). Canlı şema `participants` yazmayı bıraksa
fixture yine onu içerdiği için test hiçbir şey fark etmezdi. Yani test,
korumaya çalıştığı hatanın **tam olarak kör olduğu** yerdeydi.

### Yapılan: iki dili bağlayan altın dosya

`test/fixtures/call_incoming.golden.json` gelen arama sözleşmesini
tutar: sunucuya yazılan **belge** ve sorgunun dayandığı **alan adları**.
İki test onu iki uçtan kilitler:

| Uç | Ne doğruluyor |
|---|---|
| `incoming_call_contract_test.dart` | `buildCallDocument` çıktısı ve `CallFields` sabitleri altın dosyayla AYNI mı — şema kayarsa düşer |
| `firestore.rules.test.js` | Altın belgeyi gerçek emülatöre yazar, altın alan adlarıyla sorguyu çalıştırır ve **sonucun boş olmadığını** ölçer |

Fixture artık elle yazılmıyor; Dart şeması değişirse altın dosya
güncellenmek zorunda, güncellenince de emülatör testi o yeni şemayla
çalışıyor. §4u'nun "iki temsil sessizce ayrıştı" deseni bu iki test
arasında kapatıldı.

Sorgu da tek doğruluk kaynağına bağlandı: `call_remote_datasource`
artık `'participants'`/`'status'` yerine `CallFields.participants` /
`CallFields.status` kullanıyor.

### Eklenen emülatör testleri

* 🔒 **ARANAN kişi çağrıyı GERÇEKTEN görüyor** — sonuç boş değil ve
  doğru belgeyi içeriyor (asıl kazanım)
* 🐞 `participants` yoksa sorgu **sessizce** boş döner — §4u'nun neden
  fark edilmediğini belgeler: hata yok, izin var, yalnızca sonuç boş
* Çağrı `ringing` değilse sorguya düşmez
* Katılımcı olmayan aynı sorguyu çalıştırınca hiçbir şey görmez
* **Grup araması:** üçüncü katılımcı da çağrıyı görür (§4t'nin amacı)

### Kırılabilirlik ÖLÇÜLDÜ — iki tarihsel hata da yakalanıyor

* **§4u taklidi:** `buildCallDocument`ten `participants` çıkarıldı →
  Dart sözleşme testi anında düştü ("canlı şema altın belgeyle AYNI").
* **§4m taklidi:** `firestore.rules` içinde `calls` için
  `allow list: if callParty()` → `if false` yapıldı → emülatörde 7 test
  düştü, aralarında "ARANAN kişi çağrıyı GERÇEKTEN görüyor" ve "GRUP
  araması" da var.

İkisi de geri alınınca geçti. Yani gelen aramayı üretime kırık
gönderen **her iki hata da** artık otomatik kapıda duruyor.

### 🐞 Yol üstünde: kendi testim alakasız veriye bağlıydı

"Çağrı ÇALMIYORSA sorguya düşmez" testi ilk hâlinde `snap.empty`
bekliyordu ve **düştü** — çünkü genel fixture ALICE'i başka bir
`ringing` çağrının (`call1`) katılımcısı yapıyor. Assertion, ölçmek
istediği şeyden fazlasını iddia ediyordu. Hedeflenen belgeye
daraltıldı.

Küçük ama aynı sınıf: bir testin geçmesi/düşmesi, ölçtüğünü sandığın
şeyden farklı bir sebebe bağlı olabilir.

### ⚠️ Kalan

Bu, elle testin yerini **tamamen** almaz. Otomatik kapı artık şunu
garanti ediyor: *doğru şemayla yazılmış çalan bir çağrı, kuralların
altında, aranan kişinin sorgusuyla eşleşir.* Kapsamadığı: WebRTC
sinyalleşmesi, bildirim tetikleme ve arayüzün çağrı ekranını açması.
`DEVAM.md` §6'daki iki cihazlı test bu yüzden duruyor — ama artık
"otomatik doğrulama göremez" gerekçesiyle değil.

**Doğrulama:** 4 yeni Dart testi (296 → **300**), 6 yeni emülatör testi
(102 → **108**). Kural dosyası değişmedi.

---

## 4an. KATILMA VE ROL DEĞİŞİMİ DE İŞLEME TAŞINDI

`group_remote_datasource.dart` · `group_repository_impl.dart` ·
`channel_search_screen.dart` · testler

§4ak üye ÇIKARMAYI birebir harita eşleşmesinden kurtarıp uid'e taşımıştı.
Aynı sınıftaki iki yol açıkta kalmıştı; bu tur onlar kapandı.

### 1. Katılma: üç yazmanın idempotentliği FARKLIYDI

```dart
'memberIds':   FieldValue.arrayUnion([myUid]),      // idempotent
'members':     FieldValue.arrayUnion([m.toMap()]),  // DEĞİL
'memberCount': FieldValue.increment(1),             // DEĞİL
```

* `members` haritası `joinedAt: DateTime.now()` taşıyor → ikinci çağrıda
  **farklı bir eleman** olur ve aynı kişi listede **iki kez** görünür.
* `memberCount` her çağrıda bir artar.

"Zaten üye mi" kontrolü vardı ama okuma ile yazma **arasında**
yapılıyordu. Hızlı iki dokunuş ya da bir yeniden deneme aradan geçince
sonuç: bir üye, iki `members` girdisi, sayaç iki fazla.

### 🐞 Kanal aramasında bu hata KOD YORUMUNDA NORMAL SAYILMIŞTI

`channel_search_screen.dart` üyeliği **doğrudan Firestore'a** yazıyordu
(repository'yi atlayarak — bu projede §4u'yu üreten desenin ta kendisi)
ve yorumu şöyleydi:

> *"Zaten üyeysek katılma güncellemesi de kural gereği geçer;
> reddedilirse tek meşru sebep YASAKLI olmaktır."*

Yani zaten üye olunan bir kanala her dokunuşta `increment(1)`
çalışıyordu ve bu **beklenen davranış** olarak yazılmıştı. Kanal
listesindeki üye sayısı, kullanıcıların kanala kaç kez dokunduğunu
sayıyordu.

### 2. Rol/susturma: işlemsiz oku-değiştir-yaz

`_updateMemberInArray` diziyi okuyup **tamamını** geri yazıyordu, işlem
yoktu. Okuma ile yazma arasında biri gruba katılırsa, geri yazılan liste
onu içermediği için **yeni üye siliniyordu** — `memberIds`'te durur,
`members`'ten düşerdi. §4ak'de kapatılan tutarsızlığın ekleme yarışıyla
oluşan hâli.

### Yapılan

İki yeni işlem tabanlı datasource metodu:

| Metot | Ne yapıyor |
|---|---|
| `addMemberToArray` | Üyeyi **uid ile** ekler; zaten üyeyse **hiç yazmaz**; `memberCount`u gerçek uzunluğa yazar |
| `updateMemberFields` | Üyenin alanlarını **uid ile** günceller; düz dizileri yeniden türetir |

Kanal ekranı da bu yola bağlandı — `chats` koleksiyonuna üyelik yazan
tek bir yol kaldı.

**"Zaten üyeyse hiç yazma" iki sebeple gerekli**, biri sonradan çıktı:
sayaç kaymasını durduruyor **ve** kural `isSelfJoin()` eklenen kümenin
tam olarak `{ben}` olmasını istediği için, zaten üyeyken yazmak
`permission-denied` alırdı — kanal ekranı da o kodu **"bu kanaldan
yasaklısın"** diye gösteriyor. Yazmak yalnızca gereksiz değil,
**yanıltıcı bir hata** üretirdi.

Bu yüzden `addMemberToArray` `permission-denied`i sarmalamadan geçirir:
kanal katılmasında o kodun tek meşru sebebi gerçekten yasaklı olmaktır
ve ekranın ayrımı korunmalı.

### `_flatRoleFields` tek yere indi

Düz dizi türetimi (`adminUids`/`mutedUids`) repository'de varlıklar
üzerinde yapılıyordu. İşlem ham haritalarla çalıştığı için ikinci bir
kopya gerekecekti — aynı diziyi iki yerde hesaplamak bu projenin
defalarca bedelini ödediği desendir (§4u, §4aj). Türetme datasource'a
taşındı, repository'deki kopya silindi. **Kural motoru `adminUids`e
baktığı için ayrışma doğrudan yetki hatası demek.**

### Girdi bulunamazsa sessizce başarılı DÖNMEZ

`memberIds` ile `members` ayrışmışsa rol değişimi hiçbir şey yapamaz.
Uydurma bir girdi yazmak (özellikle `joinedAt`) veriyi kirletir; sessiz
kalmak §4ah'nin ölçütünü ihlal eder — kullanıcı rolü değiştirdiğini
sanır, değişmemiştir. `updateMemberFields` bulunamadığını bildiriyor,
repository `reportHandled` + `ValidationFailure` döndürüyor.

### Doğrulama

* **4 yeni Dart testi** (300 → **304**): katılmanın `arrayUnion`/
  `increment` kullanmadığı, rol/susturmanın uid + alan haritasıyla
  gittiği, ve girdi bulunamazsa başarısız döndüğü.
* **5 yeni kural testi** (108 → **113**): işlemin yazdığı **tam dizi**
  biçimini kuralın kabul ettiği emülatörde ölçüldü — `isSelfJoin()`
  eklenen kümenin tam olarak `{ben}` olmasını istiyor, tam liste yazmak
  bunu bozmuyor. Yasaklı kullanıcının hâlâ reddedildiği de kilitlendi.
* Kırılabilirlik ölçüldü: eski `arrayUnion`/`increment` yolu geri
  konduğunda ilgili test anında düştü.

### 🐞 Yol üstünde: kendi testim yanlış sebeple geçiyordu

"Katılma işlem kullanır" testi ilk hâlinde hiçbir şey ölçmüyordu:
fixture'daki uid zaten üyeydi, `joinByInviteCode` "zaten üye" diye
erken dönüyordu ve `addMemberToArray` hiç çağrılmıyordu. Katılan kişi
üye olmayan biriyle değiştirildi.

⚠️ **Kural dosyası değişmedi**, yalnızca test eklendi. Bu tur da
istemci tarafı — dağıtım bekleyen tek şey hâlâ §4al.

---

## 4ao. ŞİKÂYET AKIŞI, YEDEK SAHİPLİĞİ VE ARAYÜZE SIZAN İSTİSNALAR

`safety_actions.dart` · `backup_service.dart` ·
`backup_viewer_screen.dart` · 8 arayüz dosyası ·
`test/tooling/ui_exception_leak_test.dart` (yeni)

`DEVAM.md` listesindeki iki madde (şikâyet iş akışı, yedeğin kapsamı)
incelenirken üç ayrı sorun çıktı.

### 1. 🐞 `ownerUid` yedeğe YAZILIYOR ama HİÇ OKUNMUYORDU

`BackupService.create` yedeğe `ownerUid` yazıyor; `BackupData.fromMap`
o alanı **düşürüyordu.** Doğrulama yoktu.

Neden önemli: geri yükleme tamamen **yerel** ve `chatId` ile anahtarlı
(`BackupRestoreService` sunucuya hiçbir şey yazmaz — bilinçli, çünkü
yedekteki mesajlar çözülmüş hâlde). Birebir sohbet kimliği ise
`sıralı(uid1,uid2)`den türüyor.

Sonuç: **başka bir hesabın yedeği** geri yüklendiğinde mesajlar, bu
hesabın hiçbir zaman açmayacağı chatId'lere yazılıyordu. Ekran *"N
mesaj geri yüklendi"* diyor, kullanıcı sohbetlere bakıyor ve hiçbir şey
yok. Hata da yok — projenin imza arıza sınıfı.

→ `ownerUid` artık okunuyor ve `belongsTo()` ile doğrulanıyor. Uyuşmazsa
açık hata. `ownerUid` taşımayan **eski** yedekler reddedilmiyor (§4m'nin
dersi: yeni alan zorunlu kılınırken eski kayıtların ne olacağı
düşünülmeli).

#### Yedeğin kapsamı — soruya cevap

Liste maddesi *"E2EE kimlik anahtarları yedeğe giriyor mu?"* diye
soruyordu. Ölçüldü:

| | Durum |
|---|---|
| Yedek şifreli mi | ✅ AES-256-GCM + PBKDF2 150k, parola dosyada YOK |
| Kimlik anahtarı içeriyor mu | ❌ Hayır — yalnızca çözülmüş mesaj metni |
| Yani dosya "hesabın kendisi" mi | ❌ Değil |

Yani korkulan iki senaryonun ikisi de yok. **Ama belgelenmemiş bir
bağımlılık var:** yedek yalnızca AYNI uid'e geri dönülürse işe yarar,
çünkü chatId'ler uid'den türüyor. Uid'e dönmenin yolu **kurtarma
anahtarı**. `BackupService` başlığı ise yedeği "telefon kaybolursa
çıkış yolu" diye tarif ediyor — tek başına yanıltıcı. Yedek geçmişi,
kurtarma anahtarı hesabı kurtarır; **ikisi birlikte gerekir.**

### 2. Şikâyet akışı: ölü parametre ve eksik kaldıraç

`SafetyActions.report` imzasında `messageId` vardı; **hiçbir çağıran
geçmiyordu** ve geçse bile `BlockService.report`a iletilmiyordu — üç
katman boyunca ölü yüzey (§4t/§4aj'nin deseni).

Kaldırıldı, ve gerekçesi yazıldı: mesaj düzeyinde şikâyet bu mimaride
**içerik tabanlı olamaz**. Mesajlar uçtan uca şifreli, yani konsola bir
mesaj kimliği göndermek okunamayan bir dokümanı işaret eder; içerik
göndermek ise E2EE'yi tam da moderasyon için delmek olurdu. Gerçekçi
kaldıraçlar: **şikâyet + engelle + hesap düzeyinde işlem.**

İkincisi eksikti: şikâyet eden kişi için hiçbir şey değişmiyordu —
şikâyet edip aynı kişiden taciz görmeye devam edebiliyordu. Şikâyet
sayfasına **"Bu kişiyi de engelle"** eklendi (varsayılan açık, zorunlu
değil). Engelleme şikâyetten SONRA ve şikâyet başarısızsa hiç
çalışmıyor — sessizce yalnızca engelleyip "şikâyet gönderildi" demek
yanıltıcı olurdu.

### 3. 🐞 ARAYÜZE HAM İSTİSNA BASAN 10 YER

Şikâyet akışındaki `SnackBar(content: Text(e.toString()))` fark edilince
tarandı: **10 yerde** ham istisna kullanıcıya gösteriliyordu.

Bu kozmetik değil, **metadata sızıntısı**:

```
[cloud_firestore/permission-denied] ... /chats/uidA_uidB/messages/m1
```

Firestore hataları doküman YOLU taşır ve birebir sohbet kimliği
`sıralı(uid1,uid2)` olduğu için bu metin **iki tarafın uid'ini** ekrana
basar. `blocked_users_screen`'deki hâli daha da doğrudandı: yol
`users/<uid>/private/blocks`. Hata ekranları paylaşılır, ekran
görüntüsü alınır — §4o'nun sohbet dokümanından adları temizlemek için
harcadığı iş tek bir hata mesajıyla geri verilir.

§4q bu sızıntıyı **"43 → 0"** diye kapatmıştı. Yeniden 10 olmuş. Yani
sayı sıfırlanmış ama **sıfır kalmasını sağlayan bir şey yokmuş.**

→ 10'u da çevrilmiş metne çevrildi (çoğu yalnızca `: $e` ekinin
silinmesiydi; üçü `err_unexpected`e bağlandı, biri `reportHandled`a).
→ **Kalıcı kapı:** `ui_exception_leak_test.dart` `lib/` içinde
`Text(...)`/`SnackBar(...)` satırlarında `$e`/`e.toString()` arıyor.
Kırılabilirlik ölçüldü: kasten bir sızıntı eklendiğinde kapı düştü.

Asıl düzeltme kapı. §4q gösterdi ki elle temizlemek yetmiyor.

### Doğrulama

* **6 yeni Dart testi** (304 → **310**): yedek sahipliği (5) ve arayüz
  sızıntı kapısı (1).
* Sızıntı sayısı **10 → 0**, ölçülerek.
* Yeni çeviri anahtarları (`err_backup_other_account`,
  `report_also_block`) **16 dile birden** eklendi — §4ai'nin kapısı
  eksik bıraksaydı testi düşürecekti.
* Kural dosyası ve fonksiyonlar değişmedi.

### ⚠️ Kalan: şikâyetlerin sunucu tarafı

`reports` koleksiyonu hiçbir istemci tarafından okunamıyor (doğru) ama
işleme alınması tamamen konsol işi. Kod tarafında kalanlar:

* **Hız sınırı yok** — bir kullanıcı şikâyet yağdırabilir. Kural
  `create`e izin veriyor; sınırlama Cloud Function ya da kural düzeyi
  sayaç ister.
* **Şikâyet edilen hesaba işlem** (askıya alma/yasaklama) için sunucu
  tarafı bir akış yok. Play'in içerik uygulaması beklentisi bu;
  `DEVAM.md` §3b'ye madde olarak yazıldı.

---

## 4ap. ATIL ÖN PLAN İZİNLERİ VE ZIMNEN ZORUNLU BLUETOOTH

Play Console, 1.0.2 (3) paketini kapalı teste sunarken **yayını engelleyen
bir hata** verdi: *"Uygulamanızda beyan edilmemiş ön plan hizmeti izinleri
kullanılıyor"* — `FOREGROUND_SERVICE_CAMERA` ve
`FOREGROUND_SERVICE_MICROPHONE` için kullanım amacı beyanı istiyordu.

### 🐞 İzinler vardı, KARŞILIĞI YOKTU

Beyanı doldurmadan önce iznin gerçekten kullanılıp kullanılmadığı ölçüldü:

```bash
# 1) Birleştirilmiş (paketlenen) manifestte tür beyan eden servis var mı?
grep -n "foregroundServiceType"   build/app/intermediates/packaged_manifests/release/*/AndroidManifest.xml
#   -> HİÇBİR ÇIKTI YOK

# 2) Kodda ön plan hizmeti başlatan bir yer var mı?
grep -rn "startForeground\|ForegroundService" lib android/app/src
#   -> yalnızca manifestteki izin satırlarının kendisi
```

Yani iki izin de **atıldı**. Manifestteki eski yorum şunu iddia ediyordu:

> *"Arama arka planda sürsün: foreground service ZORUNLU. Bunlar olmadan
> Android, arka plandaki mikrofon/kamera erişimini kesiyor ve ekran
> kapanınca arama düşüyordu."*

Bu yorum **yanlıştı**. İzin tek başına arka planda mikrofon/kamera erişimi
açmaz; bunun için `android:foregroundServiceType="camera|microphone"`
beyan eden, `startForeground()` çağıran gerçek bir servis gerekir. Öyle bir
servis hiç yazılmamıştı. İzinler eklenmiş, sorunun çözüldüğü varsayılmış,
doğrulanmamıştı.

**Sonuç:** aramalar arka plana alınınca hâlâ düşüyor olmalı (§3b'ye alındı),
ama izinler bunu düzeltmiyordu — yalnızca Play'de, **olmayan bir davranışı
beyan etme** zorunluluğu doğuruyorlardı. Yanlış beyan, uygulamanın
kaldırılmasına yol açan bir ihlâldir.

**Yapılan:** iki TÜRLÜ izin kaldırıldı. Düz `FOREGROUND_SERVICE` bırakıldı —
eklentilerin getirdiği WorkManager (`androidx.work.impl.foreground.
SystemForegroundService` paketlenen manifestte duruyor) onu kullanabiliyor
ve Play bu izin için beyan istemiyor (beyan formu yalnızca Kamera ve
Mikrofon soruyordu). Davranış değişmedi: atıl izinler kaldırıldı.

### Bluetooth ZIMNEN zorunlu hâle gelmişti

Aynı incelemede Play, sürümün *"önceki sürümde yer alan 22 cihazı artık
desteklemediği"* uyarısını verdi; paket tablosunda 1.0.1 için 6, 1.0.2 için
**7** "gerekli özellik" görünüyordu.

Manifestte `BLUETOOTH` ve `BLUETOOTH_CONNECT` izinleri var, ama
karşılığında `uses-feature` **yoktu**. Android'de izinler zımnen donanım
özelliği doğurur: `BLUETOOTH` → `android.hardware.bluetooth`
**`required="true"`**. Yani bluetooth'suz cihazlar mağazada uygulamayı
göremez hâle gelmişti — manifestin kendi yazdığı ilkeye (*"Donanım zorunlu
değil: kamerasız cihazlar da uygulamayı kurabilsin"*) aykırı olarak.

**Yapılan:** `android.hardware.bluetooth` açıkça `required="false"` yazıldı;
kamera/mikrofon için zaten yapılan şeyin bluetooth'ta atlanmış hâliydi.

### 🐞 …ve bu çıkarım YANLIŞ ÇIKTI (ölçüldü)

Yukarıdaki bluetooth teşhisi **çıkarımdı, ölçüm değildi** — ve paket 4
yüklendikten sonra Play'in cihaz karşılaştırma tablosu onu **çürüttü**:

| Form faktörü | Düşen (paket 3, düzeltmesiz) | Düşen (paket 4, düzeltmeli) |
|---|---|---|
| Telefon | 0 | 0 |
| Tablet | 5 | **5** |
| Otomobil | 17 | **17** |

22 cihazın **hiçbiri geri gelmedi.** "Gerekli özellikler" sayısı da
değişmedi: 1.0.1 (paket 2) = **6**, paket 3 = **7**, paket 4 = **7**.
Yani 1.0.2'de artan 7. özellik bluetooth DEĞİLDİ; bluetooth'u açıkça
isteğe bağlı yapmak o sayıyı düşürmedi.

Düzeltmenin tek ölçülebilir etkisi "yeni desteklenen" tarafta oldu:
tablet +10 → **+23**, telefon +7 → **+8**. Yani zarar vermedi, hatta
biraz genişletti (`required="false"` cihaz desteğini yalnızca
genişletir), ama **hedeflediği sorunu çözmedi.**

> 🔍 **AÇIK SORU:** 1.0.1 → 1.0.2 arasında artan 7. özellik nedir?
> Paketin manifestinde yalnızca 4 `uses-feature` var (bluetooth, camera,
> camera.autofocus, microphone) ve hepsi `required="false"`. Kalan 3'ü
> Play'in izinlerden türettiği zımnî özellikler olmalı. Ölçmek için
> Play Console → **En yeni sürümler ve paketler → paketi seç → cihaz
> kataloğu**'nda paket 2 ile paket 4'ün özellik listelerini birebir
> karşılaştırmak gerekiyor. **Yapılmadı.**
>
> ⚠️ Etkisi küçük ve engelleyici değil: **telefon kaybı 0**, kayıp 5
> tablet + 17 otomobil. Mesajlaşma uygulaması için Android Automotive
> zaten hedef değil.

**DERS:** §4al'de iki kez olan şey burada üçüncü kez oldu — makul
görünen, belgeli kurala dayanan bir çıkarım ölçüldüğünde çöktü. Bluetooth
satırı yerinde bırakıldı (zararsız ve doğru), ama *gerekçesi* artık
"22 cihazı geri getirir" değil, "izin varsa özellik açıkça isteğe bağlı
yazılmalıdır".

### Doğrulama

```bash
grep -c "FOREGROUND_SERVICE_" android/app/src/main/AndroidManifest.xml   # 0
grep "hardware.bluetooth" android/app/src/main/AndroidManifest.xml       # required="false"
```

Yeniden derlemek gerekti → `versionCode` **4** (sürüm adı 1.0.2 kaldı;
1.0.2 (3) testçilere hiç ulaşmadan taslakta kaldı).

---

## 4aq. CİHAZ TESTİNİN ÇIKARDIĞI ALTI ARIZA

Kapalı test paketi hazırken cihazda yapılan elle deneme altı ayrı arıza
gösterdi. Hepsinin kökü ayrıydı; hiçbiri birbirinin belirtisi değildi.

### 1. 🐞 MEDYA HİÇ YÜKLENMİYORDU (yapılandırma, kod değil)

Resim ve dosya gönderimi "Medya yüklenemedi" veriyordu. Storage kuralları
üyeliği Firestore'dan okuyor:

```
function isChatMember(chatId) {
  return signedIn() && request.auth.uid in
    firestore.get(/databases/(default)/documents/chats/$(chatId)).data.memberIds;
}
```

Firebase Console'daki bant sebebi söylüyordu:

> *"Your rules make use of cross-service database calls, but your project
> is not configured to execute those calls"*

`firestore.get()` **servisler arası** bir çağrı ve Storage servis hesabına
ek bir IAM rolü verilmemişti. Çağrı çalıştırılamayınca koşul
değerlendirilemiyor, değerlendirilemeyen koşul **reddediliyor**. Yani
`chats/**` altına yapılan HER yükleme reddediliyordu.

**Ölçülebilir imza:** `avatars/` ve `stories/` yalnızca `signedIn()`
baktığı için ÇALIŞIYOR; `chats/**` ve `group_avatars/**` (`isChatMember`
kullanan iki yol) ÇALIŞMIYOR. Teşhis bununla doğrulanır.

**Yapılan:** Console → Storage → Rules → *Fix issue* → *Attach
permissions*. Kod değişmedi, yeniden derleme gerekmedi.

> ⚠️ **DAĞITIM KONTROL LİSTESİNE EKLENDİ.** `firebase deploy --only storage`
> kuralları yükler ama bu izni VERMEZ. Kurallar dağıtılmış görünürken
> medya sessizce ölü kalabilir. Yeni projede/yeni kovada tekrar gerekir.

### 2. 🐞 SAAT İKONU HİÇ GEÇMİYORDU

Çevrimdışı gönderilen mesaj kuyruğa `status: sending` ile girer. Kuyruk
boşaltılırken `message_sync_service.dart` **aynı nesneyi** gönderiyordu:
Firestore'a `sending` yazılıyor, yerel önbellek de `sending` kalıyordu.
Mesaj karşı tarafa ULAŞSA BİLE gönderende saat ikonu sonsuza kadar
duruyordu — durumu ilerleten başka hiçbir yol yok.

**Yapılan:** `copyWithStatus(sent)` ile gönderilir ve yerel kopya
güncellenir. `MessageModel.copyWithStatus` yeni eklendi; mevcut
`copyWithContent` anket alanlarını ve `e2eeHeader`'ı DÜŞÜRDÜĞÜ için onu
örnek almadı, tüm alanları taşır.

### 3. 🐞 YENİ HESAPTA ANAHTAR KAPSAMI KURULMUYORDU

Gönderilen mesajların düz metni `e2ee_plain_<scope>_<id>` ile saklanır;
gönderen kendi şifreli metnini çözemez (ratchet tek yönlü), bu kayıttan
okur. `_accountScope` YALNIZCA `main.dart` açılışında ve `switchAccount`ta
ayarlanıyordu.

`register()` ayarlamıyordu → kapsam ya `'_'` (temiz kurulum) ya da önceki
hesabın uid'i kalıyordu. O oturumda gönderilen mesajların düz metni yanlış
ön ekle yazılıyor, uygulama yeniden açılınca `main.dart` kapsamı doğru
uid'e çekiyor ve kayıtlar erişilemez oluyordu. Kullanıcının gördüğü:
**kendi mesajı "bu mesaj cihazda çözülemiyor"**.

`signOut()` da kapsamı sıfırlamıyordu. "Hesap ekle" akışı signOut +
register olduğu için yeni hesabın verisi ESKİ hesabın ön ekiyle
yazılıyordu — kapsamlamanın önlemek için var olduğu sızıntının kendisi.

**Yapılan:** `register()` uid belli olur olmaz üç servisin de
`setActiveAccount(uid)`'ini çağırır; `signOut()` üçünü de `null`'a düşürür.

### 4. 🐞 KULLANICI ADI DİZİNİ ÖKSÜZ KALABİLİYORDU

`register()` `usernames/{ad}` dokümanını **profilden ÖNCE** yazıyor.
`users/{uid}` yazımı patlarsa dizin geri alınmıyordu. Sonuç: ad "alınmış"
görünür ama profil yok → `findUserByUsername` profil bulamayınca `null`
döner (**aramada çıkmaz**) ve `isUsernameAvailable` dizine bakıp "dolu"
der (**başkası da alamaz**). Ad kalıcı olarak çöpe gidiyordu.

**Yapılan:** profil yazımı `try/catch` içine alındı; patlarsa
`usernames/{ad}` silinir. Geri alma da başarısız olursa sessiz geçilmez,
`reportHandled` ile raporlanır.

### 5. 🐞 GIF SEKMESİ ANAHTARSIZ DERLEMEDE GİZLENMİYORDU

`GiphyService`'in kendi belgesi *"`isEnabled` false ise arayüz GIF
sekmesini HİÇ GÖSTERMEMELİDİR"* diyor. Arayüz bunu **hiçbir yerde**
kontrol etmiyordu: `--dart-define=GIPHY_API_KEY` verilmeden derlenen
pakette kullanıcı seçeneği görüyor, açıyor ve boş sayfayla kalıyordu.

**Yapılan:** GIF ve çıkartma seçenekleri `if (GiphyService.isEnabled)`
kapısına alındı.

### Doğrulama

| Ne | Nasıl |
|---|---|
| Saat ikonu | `message_sync_status_test.dart` — 5 test |
| Anahtar kapsamı | `account_scope_test.dart` — 6 test |
| Kırılganlık ölçüldü | Hata geri konuldu → iki kilit test DÜŞTÜ, sonra geri alındı |

`AuthService` statik Firebase tekillerine bağlı olduğu için `register()`
ve `signOut()` DOĞRUDAN test edilemiyor; kapsam testleri mekanizmanın
kendisini sabitler. Bu sınır `DEVAM.md`'ye yazıldı.

Dört kapı: analyze 0 · format temiz · node OK · **321 test**.

---

## 4ar. AKIŞ DENETİMİ: ÖLÜ `isOnline` ALANI

Kullanıcı akışlarının uçtan uca denetiminde `users` belgesinde **iki ayrı
çevrimiçi alanı** bulundu:

| Alan | Yazan | Güncelleniyor mu? | Gizlilik ayarına uyar mı? |
|---|---|---|---|
| `online` | `PresenceService` | ✅ her durum değişiminde | ✅ kapalıysa `false` yazar |
| `isOnline` | `UserModel.toMap()` → yalnızca `register()` | ❌ **bir kez `true`** | ❌ |

`UserModel.fromMap` **ölü olanı** okuyordu ve arama sonucu ekranı ona
bakıyordu:

```dart
// search_user_screen.dart:129
color: user.isOnline ? AppTheme.online : AppTheme.textSecondary,
```

**Sonuç:** aramada bulunan HERKES her zaman "çevrimiçi" görünüyordu —
kişi aylardır girmemiş olsa bile. Dahası, kullanıcının *"varlığımı
paylaş"* ayarı bu ekranda hiç geçerli değildi: `PresenceService` ayar
kapalıyken `online: false` yazıyor ama kimse o alana bakmıyordu. Yani
gizlilik ayarı, en görünür yerde etkisizdi.

**Yapılan:** `fromMap` gerçek varlık alanını okur (`map['online'] == true`);
`toMap` ölü alanı artık YAZMAZ (iki alan yan yana durdukça yanlış olanın
tekrar okunması an meselesi).

**Doğrulama:** `test/models/user_model_presence_test.dart` — 5 test,
`online: false` + `isOnline: true` çakışmasını da kapsar.

> 🔍 **NASIL BULUNDU:** rastgele kod okumakla değil — "kullanıcının
> deneyimlediği her akış doğru mu" sorusu, her akışın YAZAN ve OKUYAN
> ucunu ayrı ayrı izleyerek yürütüldü. Alan adı uyuşmazlıkları ancak bu
> iki uç yan yana konunca görünüyor.

---

## 4as. CİHAZ GÜNLÜĞÜNÜN ÇIKARDIĞI BEŞ ARIZA

`adb logcat` ile gerçek kullanım izlendi. **Hiçbiri statik incelemeyle
bulunamazdı**; beşi de yalnızca yayın derlemesinde, gerçek cihazda görünür.

### 1. 🐞 R8 + Gson: her bildirim iptalinde çökme

```
FATAL: PlatformException(error, TypeToken must be created with a type
argument: new TypeToken<...>() {}; When using code shrinkers (ProGuard,
R8, ...) make sure that generic signatures are preserved.
  at com.dexterous.flutterlocalnotifications...loadScheduledNotifications
```

Bir turda **15+ kez** düştü — bildirim iptali her sohbet açılışında
tetiklendiği için pratikte sürekli.

`-keep class com.dexterous.** { *; }` ve `-keepattributes Signature`
ZATEN VARDI ve YETMEDİ: R8 "full mode" (AGP 8+ varsayılanı) `TypeToken`'ın
**anonim alt sınıfını** kücültüp karartabiliyor; `Signature` yalnızca
imzayı korur, sınıfı değil. Gson'un resmi R8 3.0+ kuralı eklendi.

### 2. 🐞 `dispose()` içinde `ref` → dispose'un geri kalanı ÇALIŞMIYOR

`Bad state: Cannot use "ref" after the widget was disposed.`
(`messaging_screen.dart:355`)

İstisna `dispose()`'u yarıda kestiği için ardından gelen HİÇBİR ŞEY
çalışmıyordu:

```dart
PresenceService.setTyping(null);      // ← karşı taraf seni SÜREKLİ
NativeSecurityBridge.release(...);    //   "yazıyor" görüyordu
_recorder.dispose(); _searchController.dispose();   // sızıntı
```

Bildirici artık `initState`'te yakalanıyor.

### 3. 🐞 HESAP DEĞİŞİMİNDE TÜM CANLI AKIŞLAR ÖLÜYOR

**En ağırı ve en aldatıcısı.** Cihaz günlüğü, 20:42:13 — tek bir saniyede:

```
chats where memberIds array_contains <uid>   → PERMISSION_DENIED
chats/<chatId>                               → PERMISSION_DENIED
chats/<chatId>/messages                      → PERMISSION_DENIED
callLogs / calls / users/<uid>/private/blocks → PERMISSION_DENIED
```

`switchAccount` içindeki signOut→signIn aralığında auth bir an BOŞTA
kalır. O anda çalışan her Firestore dinleyicisi `permission-denied` alır
ve **Firestore reddedilen dinleyiciyi YENİDEN DENEMEZ** — stream kalıcı
olarak ölür.

`accounts_screen` sohbet ve hikâye sağlayıcılarını düşürüyordu ama
`messagingNotifierProvider`'ı **bilerek** düşürmüyordu; gerekçe "hayalet
yeniden kurulum rozeti sıfırlıyor"du. O gerekçe ARTIK GEÇERSİZDİ:
rozeti sıfırlayan `markAsRead` çağrısı `_startWatching`ten çoktan
kaldırılmıştı, yani sebep kaynağında çözülmüştü — yorum güncellenmemişti.
`register_screen` ise **hiçbir şeyi** düşürmüyordu.

**Kullanıcının gördüğü belirtiler (hepsi tek kök):**
* Mesaj "gönderiliyor" saatinde donuyor → sunucuda `sent`, ekran bayat
* Yeni mesaj "anlık gelmiyor", uygulama yeniden açılınca beliriyor
* GIF/video/ses "gitmiyor" → hepsi gitmişti, sadece görünmüyorlardı

> 🔍 **DERS:** üç ayrı "gitmiyor" şikâyeti tek bir ölü stream'di.
> Sunucuya bakmadan (Firestore Console'da `status: "sent"` görmeden)
> bunların gönderim hatası olmadığı anlaşılamazdı.

### 4. 🐞 ŞİFRELİ MEDYA ÇÖZÜLMEDEN OYNATICIYA VERİLİYORDU

```
E/FlutterImageDecoderImplDefault: Failed to decode image
ImageDecoder$DecodeException: 'unimplemented' Input contained an error.
```

`sendMediaMessage` **HER** medya tipini AES-GCM ile şifreler (görsel,
video, ses, dosya) ve Storage'a `application/octet-stream` yazar. Ama:

| Yol | Eski hâli | Sonuç |
|---|---|---|
| Baloncuktaki görsel | `SecureMediaImage` (anahtarla çözer) | ✅ çalışıyordu |
| Tam ekran görsel | `FullScreenImage.open(context, url)` | ❌ anahtar geçilmiyordu |
| Video | `VideoPlayerController.networkUrl(url)` | ❌ hiç çözülmüyordu |
| Sesli mesaj | `player.play(UrlSource(url))` | ❌ hiç çözülmüyordu |

Yani **şifreli birebir sohbetlerde video ve sesli mesaj HİÇ
oynatılamıyordu.** Görsel çalıştığı için hata "bazen oluyor" gibi
görünüyordu; oysa üç ayrı yol vardı ve biri doğruydu.

**Yapılan:** üçü de `SecureMediaCache.resolve(url, key:, ext:)` ile önce
indirilip çözülüyor, sonra YEREL dosyadan açılıyor. Anahtar
`_VideoBubble`, `_OnceVideoBubble` ve `_VoiceBubble`'a kadar taşındı.
Eski şifresiz mesajlar için URL dalı korundu.

### 5. 🟡 Hata teşhisi YANLIŞ YERE bakıyor

```
Sohbet sorgusu dizinsiz moda düştü (dizin oluşturulmalı):
  [cloud_firestore/permission-denied]
```

Kod, **izin hatasını "indeks eksik" sanıyor** ve öyle raporluyor. Gerçek
sebebi gizlediği için bir sonraki kişiyi saatlerce yanlış yöne sürer.
**DÜZELTİLMEDİ** — kayda geçti.

### Doğrulama (aynı testin öncesi/sonrası, cihaz günlüğünden sayıldı)

| Belirti | v6 | v8 |
|---|---|---|
| `TypeToken` çökmesi | 15+ | **0** |
| `Cannot use "ref" after disposed` | var | **0** |
| Canlı mesaj akışı | ölü | **çalışıyor** |
| Tam ekran görsel / video / ses | açılmıyor | **üçü de açılıyor** |

> 🟡 **KAPANMAMIŞ UÇ:** v8'de açılıştan hemen sonra hâlâ 3 adet
> `Failed to decode image` görülüyor (mesaj medyası testleri geçtikten
> ÖNCE). Kaynağı bulunamadı — muhtemelen bir avatar ya da GIF karesi.
> Mesaj medyası yolları temiz.

---

## 4at. YENİ AÇILAN HESAP ARANAMIYORDU (kural, üretime dağıtıldı)

**Belirti:** kullanıcı arama yapıyor, karşı taraf çalmıyor; arama kaydına
düşmüyor; sohbette sistem mesajı görünmüyor. **Dört belirti, tek sebep.**

### Kök neden: `get()` olmayan dokümanda NULL döner

`calls` oluşturma kuralı aranan kişinin engelleme listesini okuyordu:

```
allow create: if ... && notBlockedBy(request.resource.data.calleeId);

function notBlockedBy(targetUid) {
  return !(request.auth.uid in
    get(.../users/$(targetUid)/private/blocks).data.get('uids', []));
}
```

Firestore güvenlik kurallarında **olmayan** bir dokümana `get()` **null**
döner; `.data` erişimi kural değerlendirmesini HATAYA düşürür ve
**hata = REDDET**. Emülatörün hata metni birebir:

```
evaluation error at L384:24 for 'create' @ L384
Null value error. for 'create' @ L384
```

`blocks` dokümanı yalnızca kişi **birini engellediğinde** oluşur. Yani
**YENİ AÇILAN HER HESAP** için o doküman yoktur → o hesabı **kimse
arayamaz**. Arama dokümanı hiç oluşmadığı için zincirin tamamı sessizce
çöküyordu: çalma yok, `archive()` çalışmıyor, kayıt yok, sohbet mesajı yok.

**Etki alanı dar:** `notBlockedBy` YALNIZCA arama oluşturmada kullanılıyor
(`grep -n notBlockedBy firestore.rules` → tek çağrı). Mesajlaşmanın
çalışıp aramanın çalışmamasının sebebi buydu.

### Yapılan

```
function notBlockedBy(targetUid) {
  let snap = get(/databases/$(database)/documents/users/$(targetUid)/private/blocks);
  return snap == null || !(request.auth.uid in snap.data.get('uids', []));
}
```

Tek `get()` ile çözülür — `exists()` + `get()` iki okuma ederdi.

### 🐞 TESTLER BUNU NEDEN YAKALAMADI: fixture hatayı örtüyordu

`test/rules/firestore.rules.test.js` `beforeEach`:

```js
await setDoc(doc(db, `users/${BOB}/private/blocks`), { uids: [] });
```

BOB'un `blocks` dokümanı **her zaman** oluşturuluyordu. Gerçek dünyada
o doküman yalnızca engelleme yapılınca oluşur. Fixture, testin asla
karşılaşmayacağı bir ön koşul sağlıyordu.

> 🔍 **BU DESEN BUGÜN ÜÇÜNCÜ KEZ.** Daha önce: (a) medya testi dosya
> yokken erken dönüyordu, (b) katılma testi uid zaten üyeyken hiçbir şey
> ölçmüyordu. Ortak ders: **fixture'ın sağladığı her ön koşul, testin
> ölçmediği bir durumdur.** Yeni test yazarken "bu satır olmasaydı test
> yine geçer miydi?" diye sormak gerekiyor.

Eklenen üç test: dokümanı **hiç olmayan** kullanıcı, **boş** dokümanlı
kullanıcı, **gerçekten engellemiş** kullanıcı (koruma bozulmadı).
**116 kural testi geçiyor** (113'tü).

### Doğrulama

Düzeltmeden ÖNCE test eklendi ve **düştü** (`Null value error`), sonra
kural düzeltildi ve **geçti**. Kırılganlık ölçüldü.

`firebase deploy --only firestore:rules` ile **2026-09-10'da üretime
dağıtıldı** — uygulama sürümünden bağımsız, tüm kullanıcılarda geçerli.

---

## 4au. E2EE KİMLİK ANAHTARLARI HESAP KAPSAMSIZDI

**ÜRETİM VERİSİNDE ÖLÇÜLDÜ.** Aynı cihazdaki iki hesabın `keyBundles`
belgeleri:

| uid | identityKey | signingPublicKey |
|---|---|---|
| `bWCIo1l9gSWC…` | `6oop6Hy9SNf…QlDc=` | `pQQurDjTqwc…nSKM=` |
| `qYbF9GVCioPG…` | **`6oop6Hy9SNf…QlDc=`** | **`pQQurDjTqwc…nSKM=`** |

Birebir aynı. Sebep: oturumlar (`E2EESessionService`), grup anahtarları ve
sohbet kilitleri aktif uid ile kapsamlanmışken **kimlik anahtarları düz
sabitlerdi** (`e2ee_identity_priv`, `e2ee_spk_priv`, `e2ee_opk_priv`…).

### İki ayrı arıza

**1. MESAJLAR ÇÖZÜLEMİYOR.** Her hesap KENDİ imzalı ön-anahtarını
yayımlar (`spk_hm5zb5cfo4` / `spk_hm5zc5o9td` — farklı) ama özel yarısı
TEK bir yere yazılır; sonra yayımlayan öncekini **ezer**. Karşı taraf
sunucudaki A ön-anahtarıyla şifreler, cihazda artık B'nin özeli vardır →
*"bu mesaj cihazda çözülemiyor"*. Cihaz günlüğü onayladı:

```
E2EE: anahtar paketi yeniden yayınlanıyor (imzalı ön-anahtar uyuşmuyor)
```

**2. HESAPLAR BİRBİRİNE BAĞLANABİLİR.** `keyBundles` giriş yapmış herkese
açıktır. Aynı kimlik anahtarı, isteyen herkesin *"bu iki hesap aynı kişi"*
diyebilmesi demektir — çoklu hesap özelliğinin varlık sebebini yok eder.
Kod bu riski TURN kimliği için düşünmüştü (`switchAccount` yorumu),
**E2EE kimliği için düşünmemişti.**

### Yapılan

Dokuz anahtarın hepsi `_$_accountScope` ile kapsamlandı;
`setActiveAccount` dört yere bağlandı (`main.dart`, `switchAccount`,
`register`, `signOut`).

**GÖÇ — mevcut kullanıcılar kırılmadı.** Körlemesine yeniden adlandırmak
HERKESİN kimliğini "kayıp" sayar, yeniden ürettirir ve çalışan tüm
oturumları kırardı — tek hesaplı kullanıcılar dahil, oysa onların sorunu
yok. Onun yerine eski anahtarlar **güncellemeden sonra çalışan İLK
hesaba devredilir**:

* tek hesaplı kullanıcı → hiçbir şey değişmez
* çoklu hesaplı cihaz → biri devralır, diğeri yeni kimlik üretip paketini
  yeniden yayımlar (aranan davranış)

Devir TEK SEFERLİKTİR: eski kayıtlar devirden sonra **silinir**, ayrıca
`e2ee_legacy_adopted` işaretçisi konur. İki bağımsız koruma.

### 🐞 `ensureKeysPublished` ÖN-ANAHTAR UYUMUNU DENETLEMİYORDU

Yalnızca KİMLİK karşılaştırılıyordu. Ama bozulan kimlik değil, imzalı
ön-anahtardı; kimlik aynı kaldığı için denetim "her şey yolunda" diyordu.
Eklenen denetim, **zaten bozulmuş cihazları kendi kendine onarır**:
yerel açık SPK ile sunucudaki uyuşmuyorsa paket kimlik korunarak
yeniden yayımlanır.

### Doğrulama

`test/services/key_scope_test.dart` — 7 test (devir, silme, ikinci
hesabın devralmaması, mevcut kimliğin ezilmemesi, kapsam ayrımı).

> 🔍 **KIRILGANLIK ÖLÇÜMÜNDE ÖĞRENİLEN:** korumayı kaldırıp testin
> düşmesi beklendi — **düşmedi**. İkinci hesabı engelleyen asıl mekanizma
> işaretçi değil, eski kayıtların SİLİNMESİYMİŞ. Silme kaldırılınca da
> kritik test geçti (işaretçi devreye girdi). Ancak **ikisi birden**
> kaldırılınca düştü. Yani "şu satır bu testi düşürür" denemez; test iki
> korumanın ORTAK sonucunu ölçer.

Yol üstünde `safety_number_test.dart`'ın 4 testi kırıldı (kapsamsız
`e2ee_identity_pub` yazıyordu) ve yeni gerçeğe uyarlandı — kasıtlı
davranış değişikliğinin doğal sonucu.

---

## 4av. BOZUK OTURUM KENDİ KENDİNE ONARILAMIYORDU

§4au'nun bozduğu oturumlar, paket onarıldıktan **sonra da** bozuk kaldı.

### Neden

`ensureSessionFromHeader` oturumu YALNIZCA karşı tarafın KİMLİK anahtarı
değişince yeniler:

```dart
if (pinned == header.identityKey) return false;   // dokunma
```

§4au'da kimlik **aynı** kaldı, bozulan ön-anahtardı. Oturum hiç
yenilenmedi ve o sohbetteki her mesaj sessizce çözülemez oldu.

### İki aşamalı kurtarma eklendi

**1. Başlık varsa:** çözme başarısızsa oturum sıfırlanıp başlıktan
yeniden kurulur, BİR KEZ denenir.

**2. 🐞 BAŞLIK YOKSA** — ve cihaz günlüğü bunun ASIL DURUM olduğunu
gösterdi: kurtarma hiç tetiklenmedi, çünkü **başlık yalnızca gönderen
oturumu İLK kurarken eklenir**; sonraki mesajlarda yoktur. Yani alıcının
elinde yeniden kuracak hiçbir şey kalmaz.

Bu durumda kendi oturumumuz **silinir**: o sohbete bir sonraki
yazışımızda `encrypt()` "oturum yok" görüp X3DH'i baştan kurar ve BAŞLIK
ekler; karşı taraf onunla kendi tarafını onarır. Sohbet başına bir kez
(kötü niyetli üye sürekli el sıkışma zorlayamasın).

### ⚠️ BU BİR YAMA, TASARIM DÜZELTMESİ DEĞİL

Doğru çözüm: **oturum onaylanana kadar başlığın HER mesaja eklenmesi**
(Signal'ın PreKeySignalMessage yaklaşımı). O zaman alıcı tek başına
onarır, karşı tarafın yazmasını beklemez.

Mevcut yamanın iki sınırı var ve ikisi de kullanıcıya anlatılmalı:
* **İki tarafın da** yeni sürümde olması gerekir — tek taraf yetmez.
* Onarım için **birinin o sohbete yeni mesaj yazması** gerekir.
* Eski mesajlar kurtarılamaz.

---

## 4aw. 🟡 "SOHBETİ TEMİZLE" HER BİREBİR SOHBETTE BOZUK (düzeltilmedi)

`clearMessages` sohbetteki **bütün** mesajları toplu siler — karşı
tarafınkiler dahil. Kural ise:

```
allow delete: if member() && (
  resource.data.senderId == request.auth.uid || isChatAdmin()
);
```

Birebir sohbette yönetici yoktur → başkasının mesajı silinemez. Toplu
yazma **atomik** olduğu için tek reddedilen belge TÜM işlemi düşürür:
kendi mesajların bile silinmez. Kullanıcı *"Sohbet temizlenemedi"* görür.

Yani karşı taraftan tek bir mesaj bile olan HER birebir sohbette bu
özellik çalışmıyor. **DÜZELTİLMEDİ** — kararı gerektiriyor: "temizle"
ne demeli? Muhtemelen "benden sil" (`deletedFor` ile gizle), çünkü
başkasının mesajını silmek tasarım gereği yasak.

---

## 4ax. KİMLİĞİNİ KORUYAN HESAP MESAJ ALAMIYORDU (yeniden el sıkışma)

§4au anahtarları hesap kapsamına aldıktan sonra saha ölçümü net bir
ayrım gösterdi:

| Hesap | §4au'da ne oldu | Sonuç |
|---|---|---|
| Kimliği DEĞİŞEN (yeni anahtar üretti) | eski anahtar yok, sıfırdan | **çalışıyor** |
| Kimliği KORUYAN (eski anahtarları devraldı) | kimlik aynı kaldı | **mesaj ALAMIYOR** |

Kullanıcının kendi `secreter` hesabı ikinci gruptaydı: başkalarına
yazabiliyor ama gelen mesajları çözemiyordu.

### Sebep: oturum yenileme kararı YALNIZCA kimliğe bakıyordu

`ensureSessionFromHeader` şunu yapıyordu: gelen başlıktaki kimlik
anahtarı, kayıtlı oturumdaki kimlikle aynıysa **erken dön** — oturum
zaten kurulu say.

Karşı taraf oturumunu sıfırlayıp yeni bir X3DH başlattığında **kimliği
değişmez**; değişen şey **efemeral** anahtardır. Ayrım yapılmadığı için
yeniden el sıkışma sessizce yok sayılıyor, bizim tarafta eski zincir
kullanılmaya devam ediyor ve sohbet **kalıcı olarak ölüyordu**.

Kimliği değişen hesaplarda hata görünmüyordu, çünkü orada kimlik
denetimi zaten tetikleniyordu — arızayı bu yüzden aylarca kimse
göremedi.

### Düzeltme

`SessionState` artık karşı tarafın **efemeral** anahtarını da taşıyor
(`peerEphemeralKey`, JSON'da `pek`); karar buna göre veriliyor:

```dart
final eskiEfemeral = existing.peerEphemeralKey;
final yenidenElSikisma = eskiEfemeral != null &&
    eskiEfemeral.isNotEmpty &&
    eskiEfemeral != header.ephemeralKey;
if (!yenidenElSikisma &&
    (pinned == null || pinned.isEmpty || pinned == header.identityKey)) {
  return false; // gerçekten aynı oturum — dokunma
}
```

**Geriye dönük uyum bilinçli:** sahadaki eski kayıtlarda `pek` yoktur
(`null`). O durumda karar verilemez ve **eski davranış korunur** —
aksi hâlde her gelen başlıkta zincir sıfırlanır, yolda olan mesajlar
çözülemez hâle gelirdi.

**Kapı:** `test/services/rehandshake_test.dart` (6 test). Kritik olanı
"aynı kimlik + yeni efemeral → yeniden kurulur"; erken dönüş geri
gelirse test düşer.

---

## 4ay. ARAMADAKİ IP UYARISI YUMUŞATILDI (bilgi korunarak)

Kullanıcı geri bildirimi: arama ekranındaki

> ⚠️ *IP adresin karşı tarafa görünüyor*  (uyarı sarısı + 🌐 simgesi)

rozeti insanları rahatsız ediyordu. Okunuşu *"bu arama güvensiz / bir
şey bozuk"* idi.

### Ölçüm: metin DOĞRUYDU, sorun tonundaydı

Önce metnin kaldırılıp kaldırılamayacağına bakıldı. **Kaldırılamaz:**

- `functions/.env` yok, `firebase functions:config:get` boş `{}` döndü,
  hiçbir derlemede `SECRETER_TURN_*` dart-define'ı geçmiyor
  → **TURN hiçbir yerde yapılandırılmamış**,
- yani aramalar gerçekten P2P kuruluyor ve IP gerçekten paylaşılıyor
  (`TURN_KURULUMU.md` bunu "anonimlik iddiasındaki en büyük açık"
  diye tanımlıyor),
- numara istemeyen bir uygulamada IP, kimliğin en güçlü
  belirleyicilerinden biridir.

Doğru bir gizlilik açıklamasını silmek kullanıcıyı yanıltmak olurdu.
Ama uyarı tonu da yanlıştı: **doğrudan (P2P) bağlantı WebRTC'nin normal
hâlidir**, ses her iki durumda da şifrelidir. Bu bir arıza değil,
kalite ↔ gizlilik ödünleşimidir.

### Yapılan: kısa nötr etiket + dokununca TAM açıklama

| | Önce | Sonra |
|---|---|---|
| Etiket | "IP adresin karşı tarafa görünüyor" | "Doğrudan bağlantı" |
| Renk | uyarı sarısı `0xFFE0A93C` | `AppTheme.primary` (camgöbeği) |
| Simge | 🌐 `public_rounded` | ⇄ `swap_horiz_rounded` + ⓘ |
| Ödünleşim | anlatılmıyordu | dokununca açılan açıklamada |

Aktarmalı durum da aynı biçime çekildi ("Aktarmalı bağlantı" +
açıklama). İki yeni anahtar **16 dilde** eklendi:
`call_ip_visible_detail`, `call_ip_hidden_detail`.

Türkçe açıklama:

> *Bu arama iki cihaz arasında doğrudan kuruluyor; kalite en iyi,
> gecikme en az olur. Ses her hâlükârda şifrelidir, ancak bağlantıyı
> kurmak için IP adresin karşı tarafla paylaşılır — bu, kabaca hangi
> bölgede olduğunu gösterebilir.*

Bilgi **azalmadı, arttı**: eski rozet ödünleşimi hiç anlatmıyordu.

### ⚠️ Asıl risk: "yumuşatma" sonra "kaldırma"ya dönüşür

Bu tür bir değişiklik, bir sonraki elde metni büsbütün silmenin ilk
adımı olabilir. Bunu **kapıya bağladık**:
`test/features/call/ip_disclosure_test.dart` (49 test) 16 dilin
tamamında şunu zorunlu kılar:

1. `call_ip_visible_detail` boş olamaz,
2. içinde **IP** ibaresi geçmek zorunda,
3. açıklama, etiketin kopyası olamaz (uzunluğu etiketin 2 katından
   fazla olmalı).

**Kırılganlık denemesi (ikisi de testi düşürdü):** Türkçe açıklamadan
"IP" ibaresi çıkarıldığında ve açıklama etiketin kopyası yapıldığında
kapı kırmızıya döndü.

### Bu bir düzeltme DEĞİL, erteleme

IP açığı **duruyor**. TURN kurulduğunda (`TURN_KURULUMU.md`) rozet
kendiliğinden "Aktarmalı bağlantı"ya döner ve açık kapanır. Metin
değişikliği yalnızca durumu doğru ANLATIR; durumu değiştirmez.

---

## 4az. 🔴 KÖK NEDEN: ALICI, MESAJIN E2EE BAŞLIĞINI KENDİ SİLİYORDU

**Bu bölüm §4au/§4av/§4ax'ten daha temeldir.** Onlar gerçek hatalardı ama
"karşı taraf bana yazamıyor" şikâyetini ayakta tutan asıl sebep buydu.

### Belirtiler (kullanıcı, 2026-09-11)

1. Karşı taraf gönderilen **fotoğraf / video / resim / belgeyi göremiyor**
2. **Ankete oy veremiyor**
3. Tek-gönderimlik resim görünmüyor, buna rağmen **tekrar tekrar
   açılabiliyor** (tüketilmiyor)

### Tek satırlık kök neden

`MessageModel.copyWithContent` dört alanı taşımıyordu:
`pollOptions`, `pollVotes`, `pollClosed` ve — kritik olanı —
**`e2eeHeader`**.

Zararsız görünüyordu; değildi, çünkü **çağrı yeri** şurası:

```dart
// message_repository_impl.dart — _decryptMessages
final messages = rawMessages
    .map((m) => m.withResolvedSender(UsernameResolver.cached(m.senderId)))
    .toList(growable: false);        // ⬅ ÇÖZMEDEN ÖNCE
```

`withResolvedSender` → `copyWithContent`. Yani **her gelen mesaj, daha
çözülmeden önce X3DH başlığını kaybediyordu.** Alıcı oturumu kuramıyor →
"bu mesaj bu cihazda çözülemiyor".

Bu yol §4k yüzünden var: metadata gizliliği için `senderUsername` artık
sunucuya yazılmıyor, gösterim anında uid'den çözülüyor. Gizlilik
düzeltmesi, şifrelemeyi sessizce kırmıştı.

### Asimetriyi de bu açıklıyor

`withResolvedSender` yalnızca ad BOŞSA ve çözülebiliyorsa kopya üretir:

| Mesaj | `senderUsername` | Kopya üretilir mi | Başlık | Sonuç |
|---|---|---|---|---|
| **Kendi** mesajım | dolu (yerel önbellek) | hayır | durur | ✅ "kendimle sorun yok" |
| **Gelen** mesaj | boş (sunucuya yazılmıyor) | **evet** | **SİLİNİR** | ❌ "başkası yazamıyor" |

### ⚠️ Gece turundaki ölçümü de bu açıklıyor

O turda cihaz günlüğünden şu ölçülmüştü ve hipotez çürütülmüştü:

> "Başlıktan yeniden kurma yeter → kurtarma HİÇ tetiklenmedi,
> **gelen mesajlarda başlık YOK**."

Ölçüm doğruydu, **yorumu yanlıştı**. Başlığı gönderen koymamış değildi;
**alıcı kendi belleğinde siliyordu.** Doğru ölçümden yanlış sonuç
çıkarmanın ders niteliğinde örneği.

### Medya ve anket neden bundan etkilendi

* **Medya:** ek şifreleme anahtarı (`mediaKey`) şifreli `content` içinde
  taşınır. Başlık silinince içerik çözülemiyor → `AttachmentRef` ayrılamıyor
  → `mediaKey` null → `SecureMediaImage` eki açamıyor. **Alıcı hiçbir şey
  göremiyor.**
* **Tek-gönderimlik:** tüketim ancak resim GERÇEKTEN gösterilince
  tetikleniyor (`_openFullScreen` true dönerse). Gösterilemediği için hiç
  tüketilmiyor → sonsuz kez dokunulabiliyor.
* **Anket:** `pollOptions` düşünce alıcıda oylanacak seçenek kalmıyor.

### Düzeltme

`copyWithContent` artık `copyWithStatus` gibi TÜM alanları taşır.

**Kapı:** `test/features/messaging/data/models/copy_with_content_test.dart`
(6 test). Düzeltmeden ÖNCE çalıştırıldı: **3 test kırmızıydı** — biri tam
olarak gerçek çağrı yolunu (`withResolvedSender`) ölçüyor.

### Yanında çıkan iki kusur

**1. Başarısız çözüm önbelleğe alınıyordu.** `_rememberPlain` nöbetçi
değeri de saklıyordu; oturum sonradan onarılsa bile mesaj uygulama
yeniden başlayana kadar "çözülemiyor" kalıyordu — kurtarma çalışır ama
kullanıcı çalıştığını göremez. Artık nöbetçi önbelleğe alınmıyor.

**2. 🪤 NÖBETÇİ NEREDEYSE SESSİZCE DEĞİŞTİRİLDİ.** `lostMarker` kaynakta
`' E2EE_LOST'` gibi görünür ama baştaki karakter **boşluk değil, NUL**
(U+0000) — dosyanın `grep` tarafından "ikili" sayılmasının sebebi de bu.
Sabit arayüze taşınırken boşlukla yeniden yazıldı ve değer değişti;
`repr()` ile ölçülmeseydi arayüz "çözülemedi" uyarısı yerine **ham
nöbetçi metnini** gösterecekti. Derleyici bunu yakalamaz.

Artık: tek tanım arayüzde, **kaçış dizisiyle** (`'\u0000E2EE_LOST'`)
yazılı — hem görünür hem `grep`lenebilir. Kapı:
`test/features/messaging/data/datasources/lost_marker_test.dart`.

### GRUP SOHBETLERİ: hangisi etkilendi (ölçüldü)

Kullanıcı "aynı durumlar grupta da var mı" diye sordu. Çözme yolu
okundu: **grup dalı `e2eeHeader`'a HİÇ bakmaz** — sender key zarfı
2. adımda erken döner, başlık işleme 4. adımdadır.

| Belirti | Birebir | Grup | Neden |
|---|---|---|---|
| Medya görünmüyor | ✅ vardı | ❌ **yok** | grup çözmesi başlığa bağlı değil |
| Ankete oy verilemiyor | ✅ vardı | ✅ **vardı** | `pollOptions` sohbet türünden bağımsız düşüyordu |
| Tek-gönderimlik görünmüyor | ✅ vardı | ❌ **yok** | medya zaten görünüyordu |
| Tek-gönderimlik dosya sunucuda kalıyor | ✅ | ✅ | aşağıdaki bulgu — **ikisinde de** |

Anket asıl olarak bir GRUP özelliğidir; yani anket hatası grupta daha
çok kişiyi vurmuştur.

### ❌ GERİ ALINAN BULGU: "tek gönderimlik sunucuda silinmiyor" — YANLIŞTI

Denetimde şu iddia edilmişti: `consumeViewOnce` içindeki Storage silme
her çağrıda reddediliyor (doğru), bu yüzden dosya sunucuda kalıyor
(**YANLIŞ**) ve doğru çözüm bir Cloud Function yazmak (**zaten yazılmış**).

**Ölçüm:** `cleanupSoftDeletedMedia` üretimde ETKİN
(`firebase functions:list` → v2, europe-west1, nodejs22) ve koşulu tam
olarak bu durumu yakalıyor:

```js
const justConsumed =
  before.mediaUrl && !after.mediaUrl && after.viewOnce === true;
```

İstemci `{'mediaUrl': ''}` yazınca tetikleniyor ve Admin SDK ile —
kuralları atlayarak — dosyayı siliyor. Yani **söz tutuluyor**;
istemcideki silme denemesi yalnızca gereksizdi.

**Hatanın kaynağı ÖLÜ KODDU.** `consumeViewOnce` içinde başarısız olmaya
mahkûm bir `storage.delete()` duruyordu, hatası yutuluyordu ve yanındaki
yorum "gercekten sil" diyordu. Kodu okuyan (ben) "demek ki silme burada
yapılmalı ve olmuyor" sonucuna vardı; sunucu tarafına bakmadan.

**Ders:** ölü kod yalnızca gereksiz değildir, **olmayan bir arıza
uydurabilir.** Ölü çağrı kaldırıldı; iki uca da karşılıklı referans
yazıldı, böylece sözleşme tek uçtan okunduğunda yanıltmaz.

> Kalan gerçek sınır: dosya yalnızca ALICI mesajı açtığında siliniyor.
> Hiç açılmazsa Storage'da bekler — tasarım gereği (henüz görülmedi).
> Süresi dolan mesajların medyası `cleanupExpiredMessages` kapsamında.

### Hâlâ AÇIK

Tek-gönderimlik medyanın **alıcıda anlık tüketilmemesi** (§4az/3'ün
kalanı) bu düzeltmeden sonra yeniden ölçülmeli: tüketim yolu, medyanın
gösterilebilmesine bağlıydı ve medya artık gösterilebiliyor. Ayrıca
`SecureMediaCache`'teki ÇÖZÜLMÜŞ yerel kopyanın tüketimde silinip
silinmediği denetlenmedi — silinmiyorsa tek-gönderimlik medya cihazda
kalıcı olur.

---

## 4ba. 🔴 "TEK GÖRÜNTÜLÜK" FOTOĞRAF SINIRSIZ AÇILIYORDU

🐞 **GERÇEK KULLANICIDA ÖLÇÜLDÜ (2026-09-11):** *"Tek gönderimlik fotolar
bulanık da olsa sınırsız görülüyor. Bastıkça görebiliyorsun."*

Hata kriptoda değil, **ROTA SONUCUNDAYDI.**

### Zincir

Tüketim şuna bağlı:

```dart
final seen = await FullScreenImage.open(context, url, mediaKey: ...);
if (seen) onConsumeViewOnce(url);   // mediaUrl temizlenir → dosya silinir
```

`FullScreenImage` ise şöyleydi:

```dart
return PopScope(
  canPop: true,
  onPopInvokedWithResult: (didPop, _) {},   // ← BOŞ
  ...
  leading: IconButton(onPressed: () => Navigator.pop(_loaded)),  // yalnız X
```

Yani **yalnızca X düğmesi** sonucu döndürüyordu. Geri tuşu/jesti rotayı
**sonuçsuz** kapatıyor, `open()` `seen ?? false` ile `false` döndürüyor,
tüketim hiç tetiklenmiyordu. Android'de tam ekrandan doğal çıkış yolu
geri jesti olduğu için pratikte fotoğraf **hiç tüketilmiyordu**.

Üstelik kodun yorumu *"Geri tuşu/jesti ile çıkışta da yükleme durumunu
bildir"* diyordu — niyet doğru yazılmış, gövdesi boş bırakılmıştı.

### İkinci kusur: "görüldü" ÖLÇÜLMÜYORDU

`_loaded`, ilk kareden **600 ms sonra koşulsuz** true oluyordu:

```dart
Future<void>.delayed(const Duration(milliseconds: 600),
    () => setState(() => _loaded = true));
```

Yani görüntü hiç çizilmese bile (çözülemeyen ek, kopuk bağlantı)
"görüldü" sayılıyordu. Bu, birinci kusur düzeltilince **tehlikeli hâle
gelirdi**: geri tuşu artık sonucu bildirdiği için, açılmayan bir
fotoğraf da yanardı. Bu yüzden ikisi BİRLİKTE düzeltildi.

### Düzeltme

* `PopScope<bool>(canPop: false, …)` → geri çağrısı rotayı `_loaded` ile
  kapatır. Çıkış yolu ne olursa olsun sonuç bildirilir.
* `SecureMediaImage`'a `onLoaded` eklendi; **gerçekten çizilebilir hâle
  geldiğinde** bir kez ateşlenir (iki dalda da: şifreli `FutureBuilder`
  ve eski `CachedNetworkImage`). `_loaded` artık ona bağlı, zamana değil.

**Kapı:** `test/core/widgets/full_screen_image_pop_test.dart` (3 test).
Kırılganlık denemesi: `canPop: true` + boş geri çağrısına dönüldüğünde
**üçü de düştü.**

### ⚠️ Testle ÖLÇÜLMEYEN yön (dürüstlük)

"Görüntü gerçekten çizildiğinde tüketilir" yönü testte doğrulanamadı:
birim testinde ağ/dosya olmadığı için görüntü hiç çizilemiyor. Testler
regresyonu (geri tuşu) ve "çizilmeyen yanmaz" yönünü kapsıyor; "çizilen
yanar" yönü yalnızca kod okumasıyla doğrulandı — cihazda denenmeli.

---

## 5. Kalan bilinçli sınırlar

Bunlar **giderilmedi** çünkü mimari değişiklik gerektiriyor; kullanıcıya
karşı dürüstlük için burada ve `MIGRATION_STATUS.md` içinde açıkça yazılı:

1. ~~Grup/kanal mesajları E2EE değildir~~ → **GİDERİLDİ** (bkz. §4c, G-01).
2. ~~DH ratchet yoktur~~ → **GİDERİLDİ** (bkz. §4g, G-03). Yalnızca bu
   sürümden ÖNCE kurulmuş oturumlar v2'de kalır; taraflardan biri
   uygulamayı yeniden kurduğunda oturum v3 olarak yeniden kurulur.
3. ~~Düzenlenen mesajlar düz metne düşer~~ → **GİDERİLDİ** (bkz. §4h).
   Düzenleme artık yeni bir ratchet mesajı olarak şifrelenir.
4. **TURN sunucusu KURULMALIDIR** — uygulama tarafı hazır (§4f) ama
   sunucu yok; o kurulana kadar arama P2P kurulur ve taraflar birbirinin
   IP'sini görür. Arayüz bunu kullanıcıya söylüyor: arama ekranındaki
   "Doğrudan bağlantı" rozetine dokununca IP'nin paylaşıldığı açıkça
   yazıyor (§4ay). Kurulum: `TURN_KURULUMU.md`.
5. **İstemci taraflı root/hook tespiti atlatılabilir** — asıl koruma E2EE
   ve sunucu kurallarıdır.
6. **Güvenlik numarası için QR okuyucu yoktur** — kod karşılaştırma
   içindir, tarama yapılamaz (bkz. §4e).
7. **Metadata yalnızca KISMEN gizli** — kullanıcı ADLARI sunucudan
   çıktı (mesajlarda §4k, sohbet dokümanında §4o) ama `senderId`,
   `memberIds`, `readBy` ve zaman damgaları hâlâ açık. Bunlar kural
   motorunun üyelik ve yazarlık denetimini yaptığı alanlar; kaldırılmaları
   mimari değişiklik ister (3. aşama: sohbet-içi takma kimlik).

---

## 6. Yayın öncesi zorunlu adımlar

```bash
# 1. Kuralları ve indeksleri DAĞIT (bunlar olmadan hiçbir düzeltme aktif değil)
firebase deploy --only firestore:rules,firestore:indexes,storage

# 1b. ⚠️ SERVİSLER ARASI İZİN — DAĞITIM BUNU YAPMAZ (§4aq/1)
#     storage.rules içindeki isChatMember() Firestore'u okur. Storage
#     servis hesabına ek IAM rolü verilmezse çağrı çalıştırılamaz, koşul
#     REDDEDİLİR ve MEDYA YÜKLEME SESSİZCE ÖLÜ KALIR.
#     Console → Storage → Rules → "Fix issue" → "Attach permissions"
#     Doğrulama: avatar yüklenir ama GRUP fotoğrafı yüklenmezse izin yok.

# 2. Cloud Functions (claimPreKey + deleteAccountData + temizlik işleri)
firebase deploy --only functions

# 3. Gizlilik politikası ve hesap silme sayfaları
firebase deploy --only hosting

# 4. Sırlarla derleme (anahtarlar artık koda gömülü değil)
flutter build appbundle --release --dart-define=GIPHY_API_KEY=...
```

> TURN kimlik bilgileri ARTIK `--dart-define` ile verilmez; sunucudan
> kısa ömürlü alınır (§4f). Kurulum için `TURN_KURULUMU.md`.

**Ayrıca:**
- `android/key.properties` içindeki yayın imzalama parolası denetim
  sırasında görüntülendi → **ifşa kabul edilmeli**. Play App Signing
  kullanılıyorsa yükleme anahtarını döndürün.
- Giphy anahtarını Giphy panelinden **iptal edip yenileyin** (eski anahtar
  yayınlanmış APK'larda gömülüydü).
- Google Cloud Console'da Firebase API anahtarına **uygulama kısıtlaması**
  tanımlayın.
- R8 açıldı → yayından önce **gerçek cihazda release testi** yapın.

## Testleri çalıştırma

```bash
flutter test          # 422 test
firebase emulators:exec --only firestore --project secreter-rules-test "npm --prefix test/rules test"   # 116 test
```
