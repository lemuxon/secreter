# SECRETER — Gizlilik Politikası

**Son güncelleme:** [TARİH YAZ]
**İletişim:** [E-POSTA ADRESİN]

> **Doldurman gerekenler:** yukarıdaki tarih ve e-posta, ayrıca en alttaki
> "Veri sorumlusu" bölümü. Bu metin bir avukat tarafından hazırlanmamıştır;
> yasal danışmanlık yerine geçmez. Ticari yayın öncesi bir hukukçuya
> okutman önerilir.

---

## 1. Kısaca

SECRETER, telefon numarası veya e-posta istemeden çalışan bir mesajlaşma
uygulamasıdır. Kayıt için yalnızca bir kullanıcı adı seçersin. Kişisel
kimlik bilgisi toplamayız.

Bu politika, hangi verilerin toplandığını, nerede saklandığını ve neyin
şifreli olduğunu **olduğu gibi** anlatır — pazarlama dili kullanmadan.

---

## 2. Topladığımız veriler

### 2.1 Hesap bilgileri
| Veri | Zorunlu mu | Amaç |
|---|---|---|
| Kullanıcı adı | Evet | Seni diğer kullanıcıların bulabilmesi |
| Hesap kimliği (rastgele üretilen kimlik) | Evet | Teknik olarak hesabını tanımlamak |
| Profil fotoğrafı | Hayır | Profilinde göstermek |
| "Hakkında" metni | Hayır | Profilinde göstermek |

**Toplamadıklarımız:** telefon numarası, e-posta adresi, ad-soyad, adres,
kimlik numarası, rehber/kişi listesi, konum geçmişi, reklam kimliği.

### 2.2 Mesajlar ve içerik
- **Metin mesajları (birebir sohbetler):** cihazında uçtan uca şifrelenir
  (X3DH + Double Ratchet); sunucuda yalnızca şifreli hâli bulunur.
- **Grup ve kanal metin mesajları:** uçtan uca şifrelenir ("sender key"
  yöntemi). Üyelik değiştiğinde anahtar yenilenir.
- **Medya (fotoğraf, video, ses kaydı, dosya):** cihazında AES-256-GCM
  ile şifrelenir; bulut depolamaya yalnızca şifreli baytlar gider.
  Açma anahtarı mesajın şifreli içeriğinde taşınır, sunucuya verilmez.
- **Düzenlenen mesajlar:** yeni bir şifreli mesaj olarak iletilir.
- **Anketler:** uçtan uca şifreli **değildir**. Oyların toplulaştırılması
  için soru ve seçenekler sunucuda düz metin durur — bilinçli bir ödün.
- **Zamanlanmış mesajlar:** uçtan uca şifreli **değildir**. Gönderimi
  sunucu yaptığı için içerik gönderim anına kadar sunucuda düz durur.
- **GIF ve çıkartmalar:** içerik Giphy'nin sunucularından gelir; mesajda
  yalnızca herkese açık bir bağlantı taşınır ve şifrelenmez.
- **Hikâyeler:** 24 saat sonra otomatik silinir; şifreli değildir.

Bunun ne anlama geldiği bölüm 5'te açıkça yazılıdır.

### 2.3 Kullanım ve teknik veriler
- **Bildirim kimliği (push token):** sana bildirim gönderebilmek için.
- **Çevrimiçi durumu / son görülme / "yazıyor" bilgisi:** uygulama içinde
  **kapatabilirsin** (Ayarlar → Gizlilik).
- **Okundu bilgisi:** kapatılabilir.
- **Çökme raporları:** **varsayılan olarak kapalıdır.** Yalnızca sen
  açarsan gönderilir; gönderilmeden önce kimlik bilgisi benzeri kalıplar
  (kimlikler, jetonlar, e-posta benzeri metinler) otomatik maskelenir.

### 2.4 Yalnızca cihazında kalan veriler
Aşağıdakiler sunucuya **hiç gönderilmez**, sadece telefonunda saklanır:
- Uygulama kilidi ve sohbet kilidi şifreleri (yalnızca kriptografik özet
  olarak, güvenli depolama alanında)
- Sahte (decoy) sohbet içerikleri
- Gizlediğin mesaj işaretleri
- Klasörler, kişi etiketleri (takma adlar), yıldızlı mesaj işaretleri
- Sohbet arka planı ve tema tercihleri
- Seçtiğin uygulama dili

---

## 3. Verileri kimler işliyor (üçüncü taraflar)

| Hizmet | Ne için | Ne gidiyor |
|---|---|---|
| **Google Firebase** (Authentication, Firestore, Storage, Cloud Messaging, Functions) | Hesap, mesaj/medya saklama, bildirim | Hesap kimliği, mesaj verisi (2.2'deki kapsamda), medya dosyaları, bildirim kimliği |
| **Firebase Crashlytics** | Çökme raporu | **Yalnızca sen açarsan:** hata metni ve teknik cihaz bilgisi (maskelenmiş) |
| **Giphy** | GIF/çıkartma araması | Aradığın kelime ve IP adresin Giphy'ye gider |
| **Çeviri servisleri** (Google Translate uç noktası / MyMemory) | Mesaj çevirisi | **Yalnızca çevirmeyi seçtiğin mesajın metni.** İlk kullanımda açık onayın alınır. |

Verilerini **satmıyoruz**, reklam ağlarıyla paylaşmıyoruz, reklam
göstermiyoruz.

---

## 4. Saklama ve silme

- Mesajlar, sen veya karşı taraf silene kadar saklanır.
- **Kaybolan mesajlar** özelliğini açarsan, seçtiğin süre sonunda mesajlar
  hem gizlenir hem sunucudan silinir.
- **Gizli sohbet** modunda, sohbetten her çıkışında o sohbetin mesajları
  iki taraftan da kalıcı olarak silinir.
- **Hesap silme:** Ayarlar → Hesabımı Kaldır. Profil, fotoğraf ve
  hikâyelerin silinir; kullanıcı adın 14 gün boyunca başkasına verilmez
  (yanlışlıkla kimlik devralınmasını önlemek için), sonra serbest kalır.
- Bulut sağlayıcısının yedeklerinde kısa süreli artıklar kalabilir; bu,
  Google'ın altyapı politikalarına tabidir.

---

## 5. Şifreleme hakkında dürüst açıklama

**Uçtan uca şifreli olan:**
- Birebir sohbetlerdeki metin mesajları (X3DH + Double Ratchet)
- Grup ve kanal metin mesajları (sender key; üyelik değişince yenilenir)
- Medya dosyaları — fotoğraf, video, ses kaydı, dosya (AES-256-GCM)
- Düzenlenen mesajlar

Bunları sunucu okuyamaz.

**Uçtan uca şifreli OLMAYAN:** anketler, zamanlanmış mesajlar, GIF ve
çıkartmalar, hikâyeler. Bunlar aktarım sırasında TLS ile korunur ve
sağlayıcının sunucularında "durağan hâlde" şifrelenir; ancak **sunucuyu
işleten taraf teknik olarak bu içeriklere erişebilir.**

Sebepleri gizlemiyoruz: anketlerde oyların toplanabilmesi, zamanlanmış
mesajlarda gönderimi sunucunun yapması, GIF'lerde içeriğin zaten
Giphy'de herkese açık olması.

**Şifreleme İÇERİĞİ korur, ÜST VERİYİ korumaz.** Şifreli mesajlarda bile
sunucuda şunlar açık durur: kimin kiminle yazıştığı (kullanıcı
kimlikleri), mesaj zamanları, okundu bilgisi ve grup üyelikleri.
Kullanıcı **adları** sunucudaki sohbet ve mesaj kayıtlarından
kaldırılmıştır; kimlikler kaldırılamaz, çünkü sunucu yetki denetimini
onlarla yapar.

**Cihaz güvenliği:** Uygulama kilidi, sahte PIN ve panik jesti gibi
özellikler, telefonun başkasının eline geçtiği durumlar için tasarlanmıştır.
Bunlar cihaz üzerinde çalışır; sunucu tarafındaki verini şifrelemez.

---

## 6. Haklarınız

Bulunduğun ülkenin mevzuatına göre (örn. KVKK, GDPR) şu haklara sahip
olabilirsin: verilerine erişim, düzeltme, silme, işlemeye itiraz,
taşınabilirlik. Talep için: **[E-POSTA ADRESİN]**

Uygulama içinden doğrudan yapabileceklerin:
- Hesabını ve içeriğini silmek (Ayarlar → Hesabımı Kaldır)
- Sohbetlerini dışa aktarmak (sohbet menüsü → Sohbeti dışa aktar)
- Telemetriyi, okundu bilgisini, çevrimiçi durumunu kapatmak

---

## 7. Çocuklar

SECRETER 13 yaşın altındaki çocuklara yönelik değildir ve bilerek
13 yaşın altındaki kullanıcılardan veri toplamayız. Bulunduğun ülkede
daha yüksek bir yaş sınırı varsa o geçerlidir.

---

## 8. Güvenlik

Aktarımda TLS, hesap doğrulamada Firebase Authentication, yerel şifrelerde
tuzlanmış kriptografik özet ve güvenli depolama kullanılır. Hiçbir sistem
%100 güvenli değildir; kusursuz güvenlik garantisi veremeyiz.

---

## 9. Değişiklikler

Bu politika değişirse bu sayfadaki tarih güncellenir. Önemli
değişikliklerde uygulama içinde bilgilendirme yapılır.

---

## 10. Veri sorumlusu ve iletişim

**Sorumlu:** [ADIN / ŞİRKET ADIN]
**Adres:** [ADRES — GDPR/KVKK için gerekli olabilir]
**E-posta:** [E-POSTA ADRESİN]
