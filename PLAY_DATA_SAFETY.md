# Play Console — Data Safety formu için cevaplar

Play Console → **App content → Data safety** bölümünü doldururken bunları
kullan. **Yanlış beyan = uygulamanın kaldırılması**, o yüzden burada
gerçeğe uygun yazdım; sonradan özellik eklersen formu güncelle.

---

## Genel sorular

| Soru | Cevap |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (TLS) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — uygulama içi "Hesabımı Kaldır" |

---

## Toplanan veri türleri

Aşağıdaki her satır için formda: **Collected = Yes**, **Shared = No**
(hiçbirini reklam/analiz şirketiyle paylaşmıyoruz; Firebase bizim adımıza
işleyen altyapı sağlayıcısıdır, "shared" sayılmaz).

### Personal info
| Veri türü | Toplanıyor | Zorunlu mu | Amaç |
|---|---|---|---|
| **Name** (username) | Yes | Required | App functionality |
| Email address | **No** | — | — |
| Phone number | **No** | — | — |
| Address / User IDs (government) | **No** | — | — |
| **User IDs** (hesap kimliği) | Yes | Required | App functionality, Account management |
| **Other info** ("Hakkında" metni) | Yes | **Optional** | App functionality |

### Photos and videos
| Veri türü | Toplanıyor | Zorunlu mu | Amaç |
|---|---|---|---|
| **Photos** | Yes | Optional | App functionality (mesaj/profil/hikâye) |
| **Videos** | Yes | Optional | App functionality |

### Audio files
| **Voice or sound recordings** | Yes | Optional | App functionality (sesli mesaj) |

### Files and docs
| **Files and docs** | Yes | Optional | App functionality (dosya gönderme) |

### Messages
| **Other in-app messages** | Yes | Required | App functionality |

> Not: Formda "Messages" kategorisinde *Emails* ve *SMS* seçme — sadece
> **Other in-app messages**.

### App activity
| **App interactions** | Yes | Optional | App functionality (çevrimiçi durumu, okundu bilgisi — kullanıcı kapatabilir) |

### App info and performance
| **Crash logs** | Yes | **Optional** | Diagnostics — *varsayılan KAPALI, kullanıcı onayıyla* |
| **Diagnostics** | Yes | Optional | Diagnostics |

### Toplanmayanlar (formda işaretleme)
Location, Financial info, Health & fitness, Contacts, Calendar,
Search history, Installed apps, Device or other IDs (reklam kimliği),
Purchase history, Web browsing history.

---

## Ek notlar (formun "Data usage and handling" kısmı)

Her veri türü için:
- **Is this data processed ephemerally?** → No (mesajlar saklanıyor)
- **Is data collection required?** → Yukarıdaki tabloya göre
- **Purposes** → yalnızca **App functionality** ve **Account management**;
  crash logs için **Analytics/Diagnostics**.
  ⚠️ **Advertising / Marketing / Fraud prevention / Personalization
  işaretleme** — bunları yapmıyoruz.

---

## Güvenlik bölümü

- **Data is encrypted in transit:** Yes
- **Users can request data deletion:** Yes

### 🔐 "Messages" için uçtan uca şifreleme beyanı (2026-09-10'da eklendi)

Play, **Messages** veri türünde isteğe bağlı bir "end-to-end encrypted"
işareti sunuyor. Artık işaretlenebilir — ama **kapsamı doğru anlat.**

| Şifreli mi | Ne |
|---|---|
| ✅ Evet | Birebir metin · **grup/kanal metin** · **medya (foto, video, ses, dosya)** · düzenlenen mesajlar |
| ❌ Hayır | Anketler (oy toplulaştırma) · zamanlanmış mesajlar (gönderimi sunucu yapar) · GIF/çıkartma (Giphy bağlantısı) · hikâyeler |

⚠️ **"Tamamı uçtan uca şifreli" DEME.** Anketler ve zamanlanmış mesajlar
sunucuda düz duruyor; kutuyu koşulsuz işaretlemek yanlış beyan olur.
Play açıklama alanı veriyorsa yukarıdaki ayrımı yaz, ya da gizlilik
politikasının §5'ine yönlendir.

⚠️ **Şifreleme, "collected" beyanını DEĞİŞTİRMEZ.** Mesaj verisi şifreli
olsa da saklandığı için "collected" sayılır — aşağıdaki "sık yapılan
hata" bölümüne bak.
- **Deletion mechanism URL:** uygulama içi silme yeterli, ama Play ayrıca
  web üzerinden bir "hesap silme talebi" bağlantısı isteyebilir. Basit bir
  sayfa hazırlayıp e-posta adresini yazman yeterli (bkz. aşağıdaki not).

### Hesap silme URL'si (Play zorunlu tutuyor)
Play, hesap oluşturulan uygulamalarda **uygulama dışından erişilebilir**
bir silme talimatı sayfası ister. Gizlilik politikanı barındırdığın yere
şu içerikte bir sayfa daha koy:

> **SECRETER — Hesap silme**
> Hesabını uygulama içinden silebilirsin: Ayarlar → Hesabımı Kaldır.
> Uygulamaya erişemiyorsan [E-POSTA] adresine kullanıcı adını yazarak
> talep gönder; 30 gün içinde silinir. Silinen veriler: profil, fotoğraf,
> hikâyeler, mesajlar. Kullanıcı adı 14 gün rezerve kalır.

---

## Sık yapılan hata — kaçın

❌ "Uçtan uca şifreli olduğu için hiçbir veri toplamıyoruz" demek.
Play açısından **saklama = toplama**. Şifreli olsa bile mesaj verisi
"collected" sayılır. Yanlış beyan, uygulamanın kaldırılma sebebidir.

✅ Doğru yaklaşım: topladığını dürüstçe beyan et, gizlilik politikasında
şifreleme kapsamını açıkla.
