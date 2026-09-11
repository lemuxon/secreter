# GizliChat — Metadata Gizliliği ve Tehdit Modeli

Mesaj *içeriği* uçtan uca şifreli (E2EE). Ama içerik şifreli olsa bile
**metadata** sızabilir: kim kime yazdı, ne zaman, ne sıklıkta, hangi
boyutta. Bu döküman neyin ele alındığını ve neyin — dürüstçe — Firebase
mimarisinde ele alınamayacağını açıklar.

---

## Ne yapıldı (v15)

### 1. Mesaj dolgusu (uzunluk gizleme) ✅
**Sızıntı:** Şifreli metnin uzunluğu, orijinal mesajın boyutunu ele verir.
"OK" ile uzun bir paragraf, şifreliyken bile ayırt edilebilir → trafik analizi.

**Çözüm:** `MessagePadding` mesajı şifrelemeden ÖNCE sabit kovalara
(64/256/1024/4096 karakter) doldurur. Çoğu kısa mesaj artık aynı boyutta
görünür. `EncryptionDataSourceImpl` içine entegre; çözerken otomatik çıkarılır.
Test: `test/core/privacy/message_padding_test.dart`.

### 2. Metadata kontrolleri (opt-out sinyaller) ✅
`PrivacySettings` + `PrivacyController` ile kullanıcı şunları kapatabilir:
- **Okundu bilgisi:** Kapalıysa karşı tarafa "gördüm" sinyali gitmez
  (`MessageRepositoryImpl.markAsRead` bunu kontrol eder — entegre ✅).
- **Yazıyor göstergesi:** "yazıyor..." sinyali gönderilmez.
- **Çevrimiçi/son görülme:** Presence paylaşılmaz.
- **Kaba zaman damgası:** Saniye yerine dakika hassasiyeti — zamanlama
  korelasyonunu zorlaştırır (`sendTextMessage` bunu uygular — entegre ✅).

Varsayılanlar **gizlilik-önce**: hassas sinyaller kapalı başlar.

### 3. Telemetri onayı (opt-in) ✅
Kilitlenme raporlama varsayılan KAPALI. Açılırsa bile mesaj içeriği,
kullanıcı adı, UID, token PII temizleyiciyle maskelenir
(`CrashlyticsReporter._scrub`).

---

## ⚠️ Firebase'in TEMELDE gizleyemediği şeyler (dürüst sınırlar)

Bu kısım kritik. Aşağıdakiler bu uygulamanın mimarisinde **çözülemez** —
çünkü Firebase modeli bunları gerektirir:

### Sunucu (Google) her şeyi görür
Firebase Firestore Google'ın sunucularında çalışır. Google şunları görebilir:
- **Sosyal grafik:** Hangi UID hangi sohbet dökümanına yazıyor/okuyor.
- **Zamanlama:** Her okuma/yazma isteğinin zamanı (kaba zaman damgası
  *döküman içindeki* alanı yuvarlar, ama Google'ın gördüğü *istek zamanını*
  değil).
- **IP adresi:** Her bağlantının kaynağı (VPN/Tor olmadan).
- **Cihaz parmak izi:** FCM token, cihaz modeli vb.

### "Sealed sender" Firebase'de mümkün değil
Signal'in sealed sender'ı, sunucunun bile göndereni bilmemesini sağlar.
Firebase'de bu **yapılamaz**, çünkü güvenlik kuralları `senderId ==
request.auth.uid` doğrulaması yapar — yani sunucu göndereni bilmek
ZORUNDA. Kuralları gevşetmek başka güvenlik açar.

### Plaintext kullanıcı adı (bilinen sızıntı)
Şu an `MessageModel` her mesajda `senderUsername`'i düz metin saklıyor.
Bu bir metadata sızıntısıdır — DB'yi okuyan biri mesajı kullanıcıya
eşleyebilir. **Düzeltme yolu:** Sadece `senderId` sakla, kullanıcı adını
istemci tarafında üye listesinden çöz; veya sohbet-özel takma ad kullan.
Bu, çalışan akışı bozmamak için henüz uygulanmadı — önerilen sonraki adım.

---

## Gerçekten metadata-dirençli olmak için

Eğer tehdit modelin "devlet düzeyinde aktöre karşı anonimlik" ise, Firebase
**yanlış temeldir**. Metadata koruması mimarinin köküne gömülü olmalı:

1. **Signal Protocol + Signal sunucusu** — sealed sender, private contact
   discovery, minimal metadata. Hayati gizlilik için altın standart.
2. **Matrix + kendi homeserver'ın** — federe, kendi verini barındırırsın.
3. **Tor üzerinden bağlanma** — IP sızıntısını engeller (hangi backend olursa olsun).
4. **SimpleX Chat** — tasarım gereği kullanıcı kimliği/hesabı yok (en
   metadata-minimal mimarilerden).

Bu uygulama **pratik gizlilik** sunar (içerik E2EE, uzunluk gizli, sinyaller
opsiyonel) ama **Firebase'e güvenmek zorunda olduğun** gerçeğini değiştirmez.
Bunu kullanıcılara açıkça söyle — yanlış güvenlik hissi gerçek tehlikedir.

---

## Özet tablo

| Metadata | Durum | Not |
|----------|-------|-----|
| Mesaj içeriği | 🟢 Gizli | E2EE (X3DH + Ratchet) |
| Mesaj uzunluğu | 🟢 Gizli | Dolgu (v15) |
| Okundu/yazıyor/çevrimiçi | 🟡 Opsiyonel | Kapatılabilir (v15) |
| Zaman damgası (döküman) | 🟡 Kabalaştırılabilir | Dakika hassasiyeti (v15) |
| Kullanıcı adı (DB'de) | 🔴 Sızıyor | Düzeltme yolu belgelendi |
| Sosyal grafik (Google'a) | 🔴 Görünür | Firebase mimarisi gereği |
| İstek zamanı/IP (Google'a) | 🔴 Görünür | Tor + farklı backend gerekir |
| Sealed sender | 🔴 Yok | Firebase'de imkansız |

🟢 çözüldü · 🟡 kullanıcı kontrolünde · 🔴 mimari sınır
