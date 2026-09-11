# 🔐 SIZMIŞ SIRLARI DÖNDÜRME — adım adım

> Bu adımlar **senin konsollarında** yapılır; kod tarafında yapılacak bir
> şey kalmadı (doğrulandı: Giphy anahtarı koda gömülü değil, `.gitignore`
> imzalama dosyalarını koruyor, `flutter test` artık gömülü sır arıyor).

---

## ⚠️ ÖNCE ŞU AYRIMI YAP: parola mı sızdı, anahtar dosyası mı?

Denetimde **parola** görüntülendi (`android/key.properties`). Anahtar
deposu dosyasının (`.jks`) kendisi sızmadıysa, iş çok daha basit.

### A) Yalnızca PAROLA sızdı → parolayı değiştir (kolay yol)

Anahtar aynı kalır, yani **yükleme anahtarı sıfırlama gerekmez** ve
mevcut kullanıcılar güncellemeleri sorunsuz alır.

**Hazır betik** — sırayı, yedeği ve doğrulamayı yönetir:

```bash
bash scripts/imza_parolasi_dondur.sh
```

Betik parolayı GÖRMEZ (keytool kendisi sorar) ve şu üç şeyi elle
yapılırken atlanan yerde halleder:

| | Neden |
|---|---|
| Önce `.jks` yedeği | Depo bozulursa bu uygulamaya bir daha güncelleme yayınlayamazsın |
| `key.properties`i satır satır yeniden yazma | `sed` kullanılsaydı parolada geçen `/` `&` `\` dosyayı sessizce bozardı — `openssl rand -base64` çıktısında `/` sıktır |
| Sonunda gerçek **derleme** | `keytool -list` yalnızca DEPO parolasını doğrular; ANAHTAR parolasının yanlış olduğu ancak Gradle imzalarken anlaşılır |

Elle yapmak istersen adımlar şunlar:

```bash
# Depo parolasını değiştir
keytool -storepasswd -keystore <anahtar-deposu>.jks

# Anahtarın kendi parolasını değiştir
keytool -keypasswd -alias <takma-ad> -keystore <anahtar-deposu>.jks
```

Sonra `android/key.properties` içindeki iki parolayı güncelle.
⚠️ Dosyayı **hiçbir yere kopyalama**; `.gitignore`da olması yeterli
değil, ekran paylaşımı ve yedeklerde de dikkat et.

### B) ANAHTAR DOSYASI da sızdıysa → anahtarı değiştir

Burada kritik bir soru var: **Play App Signing kullanıyor musun?**

* **Evet** → Yalnızca *yükleme* anahtarını sıfırlarsın. Uygulamayı
  imzalayan asıl anahtar Google'da durur ve değişmez; kullanıcılar
  etkilenmez.
  Play Console → Test ve yayınla → Uygulama bütünlüğü →
  Yükleme anahtarı sertifikası → **Yükleme anahtarını sıfırlama isteği**
* **Hayır** → ⚠️ **Uygulama imzalama anahtarı DEĞİŞTİRİLEMEZ.** Değişirse
  mevcut kullanıcılar güncelleme alamaz (Android farklı imzayı farklı
  uygulama sayar). Bu durumda tek gerçekçi yol A şıkkıdır; ayrıca
  Play App Signing'e geçmeyi değerlendir.

---

## 1. Giphy anahtarı

Eski anahtar **yayınlanmış APK'lara gömülüydü** — yani onu depodan
silmek yetmez, **iptal edilmelidir**.

1. https://developers.giphy.com/dashboard → eski anahtarı **sil/iptal et**
2. Yeni anahtar oluştur
3. Derlemede ver (koda GÖMME):

```bash
flutter build appbundle --release --dart-define=GIPHY_API_KEY=<yeni-anahtar>
```

> ⚠️ **GÜNCEL DURUM (2026-09-11):** artık anahtarsız derlenmiyor —
> v20 ve v21 paketleri anahtarı İÇERİYOR. Ayrıca kullanılan anahtar bir
> sohbet penceresinde düz metin olarak paylaşıldı. Yani bu anahtar da
> **ifşa kabul edilmeli ve döndürülmeli.**
>
> Döndürme sırası önemli: önce yeni anahtarı üret, yeni sürümü onunla
> derleyip yayınla, **sonra** eskisini iptal et. Ters sırada yaparsan
> sahadaki tüm sürümlerde GIF araması anında çalışmaz olur.
>
> 💡 Giphy anahtarı istemciye gömülmek zorunda (istek doğrudan cihazdan
> gidiyor). Kalıcı çözüm gömmemek değil, Giphy panelinden anahtarı
> uygulamaya/alan adına KISITLAMAK — Firebase anahtarındaki mantığın
> aynısı (bkz. §2).

---

## 2. Firebase API anahtarı — sır değil ama KISITLANMALI

`google-services.json` ve `firebase_options.dart` içindeki `AIza...`
anahtarı bir **sır değildir**; uygulamaya gömülmek üzere tasarlanmıştır
ve gizlemenin faydası yoktur. Korunma yolu kısıtlamadır:

Google Cloud Console → API'ler ve Hizmetler → Kimlik bilgileri →
Android anahtarı → **Uygulama kısıtlamaları → Android uygulamaları**
→ paket adı `com.secreter.app` + imzalama sertifikasının SHA-1'i

⚠️ **SIRA ÖNEMLİ:** Önce imzalama anahtarını/parolasını hallet, SONRA
SHA-1 kısıtlamasını gir. Anahtar sonradan değişirse kısıtlama yanlış
parmak izini tutar ve uygulama Firebase'e erişemez.

---

## 3. Döndürdükten sonra doğrula

```bash
# Yeni imzayla derlenebiliyor mu
flutter build apk --release --split-per-abi --dart-define=GIPHY_API_KEY=<yeni>

# Cihazda: eski sürümün ÜZERİNE kurulabiliyor mu?
# (imza değiştiyse kurulmaz — B şıkkındaki uyarı)
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Gömülü sır kalmadığını makine doğrulasın
flutter test --no-pub test/tooling/secret_scan_test.dart
```

---

## 4. Bir daha olmaması için

`test/tooling/secret_scan_test.dart` artık her `flutter test`te ve CI'da
çalışıyor. Koda `AIza...`, PEM özel anahtar ya da gömülü parola/sır
ataması girerse test kırılır ve **dosya:satır** söyler — değeri
yazdırmaz, çünkü CI günlükleri çoğu zaman herkese açıktır.

Taramanın gerçekten yakaladığı, sahte bir anahtar konularak doğrulandı.
