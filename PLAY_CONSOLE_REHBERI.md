# Play Console — SECRETER için adım adım

Bu rehber genel bir Play anlatımı değil; **senin uygulamanın** özelliklerine
göre yazıldı. Sırayla git, her adımda ne yazacağın hazır.

---

## ⛔ ÖNCE BUNU OKU — ilk yüklemeden önce üç şey (2026-09-10)

Bunlar "sonra hallederiz" işleri değil; ikisi ilk yüklemeden sonra
**çok daha zor** hâle geliyor.

### 0.1 ✅ Gizlilik metinleri DÜZELTİLDİ (2026-09-10)

Bu belgeler §4c'den önce yazılmıştı ve grup/medya şifrelemesinin
olmadığını söylüyordu. Dördü de güncel kapsama göre düzeltildi:
`GIZLILIK_POLITIKASI_TR.md`, `PRIVACY_POLICY_EN.md`,
`PLAY_MAGAZA_METNI.md`, `PLAY_DATA_SAFETY.md`.

Düzeltme yapılırken **kodun kendisi okundu** — abartmamak için:

| Uçtan uca ŞİFRELİ | Şifreli DEĞİL |
|---|---|
| Birebir metin (X3DH + Double Ratchet) | Anketler — oylar toplanabilsin diye düz (`isEncrypted: false`, bilinçli ödün) |
| Grup/kanal metin (sender key) | Zamanlanmış mesajlar — gönderimi Cloud Function yapıyor, içerik düz durur (`isE2EE: false`) |
| Medya: foto, video, ses, dosya (AES-256-GCM) | GIF/çıkartma — Giphy'nin herkese açık bağlantısı |
| Düzenlenen mesajlar | Hikâyeler — 24 saatte silinir |

⚠️ Metinlere ayrıca **"şifreleme içeriği korur, üst veriyi korumaz"**
uyarısı eklendi: `senderId`, `memberIds`, `readBy` ve zaman damgaları
sunucuda açık. Kullanıcı ADLARI kaldırıldı (§4k/§4o), kimlikler
kaldırılamaz — kural motoru yetkiyi onlarla denetliyor.

### 0.2 🔴 İmzalama anahtarı kararını ŞİMDİ ver

`SIR_DONDURME.md`: denetimde **imzalama parolası görüntülendi.**

* **İlk yüklemeden ÖNCE:** `keytool -storepasswd` ile parolayı
  değiştirmek 2 dakikalık iş, kimseyi etkilemez.
* **İlk yüklemeden SONRA:** anahtar Play hesabına bağlanır. Play App
  Signing'deysen yalnızca *yükleme* anahtarını sıfırlayabilirsin ve bu
  Google'a talep açmayı gerektirir; değilsen **imzalama anahtarı hiç
  değiştirilemez.**

→ Yükleme yapmadan önce `SIR_DONDURME.md` §A'yı uygula. Yüklerken de
**Play App Signing'i AÇIK bırak** (varsayılan) — anahtarı kaybedersen
tek kurtuluş odur.

### 0.3 ⚠️ `GIPHY_API_KEY` olmadan derlersen GIF sekmesi HİÇ görünmez

Kod bunu öngörüyor (çökme yok) ama testçiler "GIF nerede?" diye sorar.
Karar ver: ya anahtarla derle, ya da sürüm notunda GIF'ten söz etme.

```bash
flutter build appbundle --release --dart-define=GIPHY_API_KEY=<anahtar>
```

---

## 0. Önce elinde ne olmalı

| Gereken | Durum |
|---|---|
| İmzalı `app-release.aab` | `flutter build appbundle` |
| Gizlilik politikası URL'si | `index.html` yayında olmalı |
| Hesap silme URL'si | `hesap-silme.html` yayında olmalı |
| 512×512 ikon | `_PLAY_IKONU/play_store_512.png` |
| 1024×500 öne çıkan görsel | Hazırlaman gerek (logo + slogan yeterli) |
| En az 2 ekran görüntüsü | Telefondan al (aşağıda liste var) |
| Kredi kartı | Tek seferlik 25 USD |

---

## 1. Geliştirici hesabı

1. **play.google.com/console** → Google hesabınla gir
2. Hesap türü: **Kişisel** (şirket yoksa)
3. **25 USD** öde
4. **Kimlik doğrulama:** Google kimlik belgesi ve adres ister.
   Onay **birkaç gün** sürebilir — bu yüzden ilk iş bunu başlat.
5. **Geliştirici adı** (kullanıcılara görünür): örn. kendi adın veya bir marka adı

> ⚠️ Kişisel hesaplarda Google, **adresini de doğrulatır** ve bu bilgi
> mağaza sayfasında görünebilir. Rahatsız olacaksan tüzel kişilik
> (şirket) hesabı düşünebilirsin — ama o da ticari sicil ister.

---

## 1b. Android geliştirici doğrulaması ve PAKET ADI

Bu, klasik Play hesap doğrulamasından **ayrı** bir şey ve kafa
karıştırıyor. Ayrımı netleştirelim:

| | Ne için | Sen ne yapacaksın |
|---|---|---|
| **Play hesap doğrulaması** | Play'de yayın yapmak | §1'deki kimlik/adres doğrulaması — bu zaten şart |
| **Android geliştirici doğrulaması** | Uygulamanın sertifikalı Android cihazlara kurulabilmesi; **Play DIŞI dağıtımı** da kapsıyor | Aşağıya bak |

### Play'den yayınlıyorsan çoğu iş kendiliğinden olur

Uygulamayı **yalnızca Play üzerinden** dağıtacaksan: Play hesabını
doğrulaman ve uygulamayı Console'da oluşturman, paket adını da senin
hesabına bağlar. Ayrı bir yerde elle "paket adı kaydet" adımı aramana
genelde **gerek kalmaz.**

Ayrı kayıt, uygulamayı **APK olarak dışarıda** (kendi siten, başka
mağaza, doğrudan paylaşım) dağıtacaksan gerekiyor. Senin `.apk`
dosyalarını arkadaşlarına gönderme senaryon buna girer.

### Paket adı: `com.secreter.app`

```
com.secreter.app
```

⚠️ **Bu ad kalıcıdır.** İlk yüklemeden sonra:
* aynı uygulamada **değiştirilemez**
* Play'de **başka kimse alamaz**
* değiştirmek istersen = **yeni uygulama**, sıfır indirme, sıfır yorum

Yükleme yapmadan önce adın istediğin ad olduğundan emin ol. Kaynakta
`android/app/build.gradle` → `applicationId = "com.secreter.app"`.

### Sende ne isteyecekler

Doğrulama akışı kişisel hesaplarda tipik olarak şunları ister:
ad-soyad, adres, e-posta, telefon, kimlik belgesi ve dağıttığın
uygulamaların **paket adları**.

> ⚠️ **Dürüst not:** Google bu doğrulamayı aşamalı yürürlüğe koyuyor ve
> Console'daki menü adları/konumları sık değişiyor. Buraya birebir
> tıklama yolu yazmıyorum — yanlış yönlendirmesin. Console'da
> **"verification" / "doğrulama"** araması yap; hesabında gerekliyse
> Play zaten üstte bir uyarı bandı gösterir ve seni akışa sokar.
> Ekranda gördüğün adlar buradakinden farklıysa ekran görüntüsünü bana
> ilet, birlikte eşleştiririz.

---

## 2. Uygulamayı oluştur

**Create app** →
- **App name:** `SECRETER`
- **Default language:** Türkçe (tr-TR) — sonra İngilizce'yi de eklersin
- **App or game:** App
- **Free or paid:** Free
- Beyanları işaretle (Developer Program Policies, US export laws)

> 📌 **Şifreleme ihracat beyanı:** Uygulaman şifreleme kullanıyor. Play,
> ABD ihracat kuralları beyanını isteyecek. Standart mesajlaşma
> şifrelemesi (TLS + uçtan uca) için normal cevap: kabul et. Bazı
> ülkelerde ek bildirim gerekebilir; ticari ölçeğe çıkarsan hukukçuya sor.

---

## 3. Mağaza sayfası (Store listing)

`PLAY_MAGAZA_METNI.md` dosyasındaki hazır metinleri kullan:

| Alan | Ne yazacaksın |
|---|---|
| App name | `SECRETER` |
| Short description | Dosyadaki 80 karakterlik metin |
| Full description | Dosyadaki uzun metin |
| App icon | 512×512 PNG |
| Feature graphic | 1024×500 |
| Phone screenshots | En az 2, önerilen 4–6 |

### Ekran görüntüsü listesi (sırayla)
1. **Sohbet ekranı** — renkli balonlar, bir medya mesajı görünsün
2. **Ana ekran** — sohbet listesi + klasör sekmeleri
3. **Gizlilik ayarları** — kapatılabilir seçenekler görünsün (güçlü satış noktası)
4. **Anket veya kaybolan mesajlar**
5. **16 dil seçim ekranı**

⚠️ Ekran görüntülerinde **gerçek isim, telefon numarası, tanınabilir
içerik olmasın.** Test hesaplarıyla temiz ekranlar üret.

---

## 4. App content — sırayla doldurulacak formlar

### 4.1 Privacy policy
Yayınladığın URL'yi yapıştır.

### 4.2 App access
**Önemli:** Uygulaman telefon/e-posta istemediği için inceleyici kendisi
kayıt olabilir. Şunu seç ve açıkla:

> **All functionality is available without special access**
> Açıklama: "Kayıt için yalnızca bir kullanıcı adı seçilir; telefon
> numarası veya e-posta gerekmez. İnceleyici doğrudan kayıt olup tüm
> özellikleri kullanabilir. İki cihaz gereken özellikler (arama,
> mesajlaşma) için iki farklı kullanıcı adı ile kayıt olunabilir."

### 4.3 Ads
**No, my app does not contain ads** — reklam yok.

### 4.4 Content rating
Anketi doldur:
- Şiddet / cinsellik / uyuşturucu / kumar → **Hayır**
- **Kullanıcılar arası iletişim** → **Evet**
- **Kullanıcı içeriği paylaşımı** → **Evet**
- Kullanıcı içeriği moderasyonu var mı → grup/kanal yöneticileri
  susturma/yasaklama yapabiliyor → **Evet** (bunu belirt)
- Konum paylaşımı → kullanmıyorsan **Hayır**

Beklenen sonuç: **Teen / 13+**

### 4.5 Target audience
- Yaş aralığı: **18+** veya **13-17 + 18+**
  (13 altını **seçme** — seçersen çok ağır çocuk güvenliği kuralları devreye girer)

### 4.6 Data safety
`PLAY_DATA_SAFETY.md` dosyasındaki cevapları birebir uygula.
**Deletion** bölümünde hesap silme URL'ni ver.

### 4.7 Government apps / Financial features / Health
Hepsi **Hayır**.

---

## 5. Sürümü yükle

### 5.0 Önce `.aab` üret — APK DEĞİL

Play yeni uygulamalarda **App Bundle** ister:

```bash
flutter build appbundle --release --dart-define=GIPHY_API_KEY=<anahtar>
# çıktı: build/app/outputs/bundle/release/app-release.aab
```

> 🐞 **`versionCode` karışıklığı — bilerek not ediliyor.**
> `pubspec.yaml` → `version: 1.0.0+1`, yani versionCode **1**.
> Ama `flutter build apk --split-per-abi` ile ürettiğin APK'da
> `versionCode=2001` görürsün. Bu bir hata değil: Flutter bölünmüş
> APK'lara **ABI ofseti** ekler (armeabi-v7a 1000+, arm64 2000+,
> x86_64 4000+).
> **App Bundle'da bu ofset YOKTUR** → Play'e giden sürüm **1**'dir.
> Yani "cihazımda 2001 yazıyordu" diye paniğe kapılma.

Sonraki her yükleme için `pubspec.yaml`'daki `+1`'i artır
(`1.0.1+2` → versionCode 2). Play aynı versionCode'u iki kez kabul
etmez.

### 5.1 Sürümü yükle

**Test → Kapalı test (Closed testing) → Yeni sürüm oluştur**

1. `app-release.aab` dosyasını yükle
2. **Play App Signing:** açık bırak (ilk yüklemede sorar — kabul et)
3. **Release name:** `1.0.0 (1)`
3. **Release notes** (TR):

```
İlk sürüm.
• Telefon numarası veya e-posta gerektirmeyen kayıt
• Birebir sohbetlerde uçtan uca şifreli metin mesajları
• Fotoğraf, video, sesli mesaj, dosya, GIF, anket
• Sesli ve görüntülü arama, çağrı geçmişi
• Uygulama kilidi, sohbet kilidi, kaybolan mesajlar
• 16 dil desteği
```

4. **Testers:** bir e-posta listesi oluştur, en az **12 kişi** ekle
   (arkadaş/aile — gerçek Google hesapları olmalı)
5. Kaydet → **Review release** → **Start rollout to Closed testing**

---

## 6. ⏳ 14 gün kuralı — planlamayı buna göre yap

Yeni kişisel geliştirici hesapları için Google:
- **12 test kullanıcısı**
- **14 gün kesintisiz** kapalı test

şartı arıyor. Testçiler bu sürede uygulamayı **gerçekten kurup açmalı**
(sadece davet kabul etmek yetmez). Süre dolmadan üretim yayını
açılmıyor.

**Bu yüzden:** kapalı testi **bugün** başlat, 14 gün işlerken kalan
işleri (çeviri kontrolü, teknik borç, şifreli yedek) hallederiz.

---

## 7. Bu uygulamaya özel red riskleri

| Risk | Nasıl önlenir |
|---|---|
| **Sahte PIN / panik jesti** "aldatıcı davranış" sayılabilir | Mağaza metninde ve politikada **kişisel cihaz güvenliği** çerçevesinde anlatılıyor. "Gizle/yakalanma/kanıt" gibi kelimeler kullanma. |
| **Şifreleme iddiası abartılı** görülebilir | Kapsam politikada açıkça yazılı olmalı. ⚠️ **Metinler güncellenmeli** — §0.1: grup ve medya artık ŞİFRELİ, belgeler hâlâ "değil" diyor. Şifreli OLMAYANLARI (`senderId`, `memberIds`, `readBy`, zaman damgaları, hikâyeler) açıkça yaz; tutarlılık koruyucudur. |
| **Data safety yanlış beyanı** | "Şifreli olduğu için toplamıyoruz" **deme**. Saklama = toplama. |
| **Kullanıcı içeriği moderasyonu** sorulabilir | ✅ Artık üç kaldıraç da var: **şikâyet** (sebep + not), **engelleme** (şikâyetle birlikte, §4ao) ve yönetici susturma/yasaklama. ⚠️ Dürüst sınır: içerik tabanlı moderasyon E2EE'de YAPILAMAZ — konsol mesajı okuyamaz. Sorulursa böyle anlat; "mesajları inceliyoruz" **deme**, yalan olur. |
| Ekran görüntüsünde gerçek kişisel veri | Test hesaplarıyla üret |

---

## 8. Yayın sonrası ilk hafta

- **Crashlytics**'i günlük kontrol et (artık aktif)
- Testçilerden gelen geri bildirimi topla
- Sürüm çıkarmak için: `pubspec.yaml` → `version: 1.0.1+2` → yeni `.aab`
- Play aynı `versionCode`'u iki kez kabul etmez, `+` sonrasını her seferinde artır

---

## Takıldığın yerde

Play Console bir formu reddederse veya anlamadığın bir uyarı çıkarsa
ekran görüntüsünü/metni bana ilet — birlikte çözeriz.
