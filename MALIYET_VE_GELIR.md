# SECRETER — Maliyet kontrolü ve gelir yol haritası

## 1. ŞİMDİ YAP: Bütçe alarmı (5 dakika, en kritik)

Blaze planı kullanıma göre ücretlendirir ve **üst sınırı yoktur**. Bir hata
(sonsuz döngü, bot trafiği) faturayı hızla büyütebilir.

1. **console.cloud.google.com/billing** → projeni seç
2. **Budgets & alerts → Create budget**
3. Aylık tutar: **$10** (başlangıç için)
4. Uyarı eşikleri: **%50, %90, %100** → e-postana gelsin
5. Kaydet

> Bu bir *sınır* değil, *alarm*. Google servisi otomatik durdurmaz —
> ama sen erken haberdar olursun.

**Ayrıca:** Firebase Console → Usage and billing → günlük tüketimi
haftada bir kontrol et. İlk aylarda ücretsiz kotanın içinde kalmalısın.

---

## 2. Bu pakette yapılan düzeltmeler

### 🔴 Süresi dolan hikâyeler (en büyük sızıntı)
**Sorun:** Hikâyeler 24 saat sonra yalnızca *gizleniyordu*. Firestore
kaydı ve Storage dosyası **sonsuza kadar** duruyordu — kimse göremiyor,
ama depolama ücreti işlemeye devam ediyordu.

**Çözüm:** `cleanupExpiredStories` — saatlik çalışır, süresi dolan
hikâyelerin hem kaydını hem dosyasını siler.

*Etki:* 100 aktif kullanıcı × günde 1 hikâye × 500 KB = **ayda ~1.5 GB
birikim**. Artık sıfır.

### 🔴 Silinen mesajların medyası
**Sorun:** Mesaj silinince Storage'daki dosya "yetim" kalıyordu.

**Çözüm:** `cleanupDeletedMessageMedia` — mesaj silinince dosyası da
silinir.

### 🟡 Hikâye fotoğrafı sıkıştırma
Çözünürlük sınırı yoktu; 12 MP telefon fotoğrafları olduğu gibi
yükleniyordu. Artık 1280 px sınırı var → dosya boyutu **5-10 kat** küçük.

*(Sohbet fotoğrafları ve profil fotoğrafı zaten sıkıştırılıyordu.)*

### 🟡 Büyük video uyarısı
500 MB sınırı korundu ama 50 MB üzeri videolarda onay isteniyor:
yükleme süresi ve veri kullanımı konusunda kullanıcı bilinçli seçim yapar.

---

## 3. Deploy

```powershell
firebase deploy --only functions
```

Yeni function'lar: `cleanupExpiredStories`, `cleanupDeletedMessageMedia`

> Zamanlanmış function ilk kez deploy edilirken Google Cloud Scheduler
> etkinleştirilmesi istenebilir — onayla (ücretsiz kotada 3 job).

---

## 4. İzlenecek maliyet kalemleri

| Kalem | Ücretsiz kota (aylık) | Ne zaman ödersin |
|---|---|---|
| Firestore okuma | 50K/gün | Aktif kullanıcı × sohbet açma |
| Firestore yazma | 20K/gün | Her mesaj, her durum güncellemesi |
| Storage | 5 GB | Medya biriktikçe **kalıcı** |
| Storage indirme | 1 GB/gün | Medya görüntüleme |
| Cloud Functions | 2M çağrı | Bildirimler + temizlik |

**En riskli kalem: Storage.** Diğerleri kullanımla dalgalanır, depolama
ise **birikir**. Bu yüzden temizlik function'ları kritik.

### İleride gerekirse
- **Medya saklama süresi:** 90 gün sonra otomatik sil (kullanıcıya duyurarak)
- **Video transcode:** yüklemeden önce cihazda sıkıştırma (`video_compress`)
- **Firestore okuma azaltma:** sohbet listesi için sayfalama

---

## 5. Gelir yol haritası (sıralı)

### Aşama 1 — Yayın (şimdi)
**Tamamen ücretsiz.** Hedef gelir değil; **kalıcı kullanıcı** ve gerçek
geri bildirim. Ödeme altyapısı bu aşamada dikkat dağıtır.

### Aşama 2 — ~500-1.000 kullanıcı
Premium'u aç. Çekirdek: **şifreli bulut yedek** (gerçek acı noktası:
telefon kaybolunca geçmiş gidiyor).

| Ücretsiz kalacak | Premium |
|---|---|
| Sınırsız mesaj, arama | Şifreli yedek + geri yükleme |
| 25 MB dosya / 100 MB video | 500 MB video, sınırsız dosya |
| 3 klasör | Sınırsız klasör, özel temalar |
| **Tüm güvenlik özellikleri** | — |

> ⚠️ **Kural:** Uygulama kilidi, sahte PIN, panik jesti, kaybolan
> mesajlar **asla** ücretli olmasın. Bunlar ürünün vaadi; parayla
> korunan güvenlik, güvenlik değildir.

**Fiyat (bölgesel):**

| | Türkiye | Global |
|---|---|---|
| Aylık | ₺49-79 | $2.99 |
| Yıllık | ₺399-499 | $19.99 |
| Ömür boyu | ₺999 | $49.99 |

Rakip referansı: Telegram Premium ~$4.99/ay · Threema ~€5.99 tek
seferlik. Bilinirliğin yokken **altlarında** kal.

### Aşama 3 — B2B (asıl gelir potansiyeli)
Hukuk büroları, gazeteciler, sağlık, KVKK/GDPR hassasiyeti olan
şirketler. Kullanıcı başı aylık $5-10 ödemeye alışkındırlar.
**20 kişilik tek kurum ≈ 5.000 bireysel kullanıcı geliri.**

Gerekenler: kurumsal iletişim sayfası, veri işleme sözleşmesi (DPA),
yönetici paneli.

### Aşama 4 — Altyapı marjı
Kullanıcı sayısı büyüyünce Firebase maliyeti kullanıcı başına düşer;
gerekirse kendi sunucu altyapısına geçiş marjı artırır.

---

## 6. Dürüst beklenti

Mesajlaşma, para kazanması en zor kategorilerden biridir — rakipler
ücretsiz ve kullanıcının arkadaşları zaten oradadır. İlk 6 ayda gelir
beklemek gerçekçi değil. Bu sürede ölçmen gereken tek şey:

**"Kullanıcılar bir hafta sonra hâlâ açıyor mu?"**

Bu evetse gelir modeli kurulabilir. Hayırsa hiçbir fiyatlandırma
kurtarmaz.
