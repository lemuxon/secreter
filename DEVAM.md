# 🔄 KALDIĞIMIZ YER — Devam Kılavuzu

> Bu dosya, sohbet geçmişi kaybolsa bile çalışmanın kaldığı yerden
> sürmesi için yazıldı. **Yeni bir oturuma başlarken bu dosyayı okut.**
>
> Son güncelleme: **2026-09-16**
>
> 📌 Kayıt İKİ yerde: **git** (ne değişti — 2026-09-12'den beri) ve
> bu dosyadaki **📓 İŞLEM GÜNLÜĞÜ** (ne zaman ne yapıldı, neden).
> Her iş günlüğe tek satır olarak eklenir.

---

## 📓 İŞLEM GÜNLÜĞÜ

> **Kural:** yapılan/düzeltilen HER iş buraya **tek satır** olarak
> eklenir — tarih · ne yapıldı · § göndergesi. Yeni kayıt **en üste**.
>
> ⚠️ Buraya ayrıntı YAZILMAZ. Gerekçe, kök neden ve tuzaklar § bölümüne
> gider; bu liste "ne zaman ne oldu" sorusunu saniyede cevaplamak için
> var. Şişerse işlevini kaybeder.
>
> 📌 2026-09-12'den beri **git var** (ilk kayıt `a17f7ac`). Git "ne
> değişti"yi tutar; bu günlük "ne zaman, neden"i tutar. İkisi ayrı
> işe yarar — git'ten önceki tarihlerin tek kaydı burasıdır.

| Tarih | İş | § |
|---|---|---|
| 09-22 | 🚀 **v24 kapalı teste (Alpha) incelemeye gönderildi** | §4cl |
| 09-20 | 📦 **v24 (1.0.13+24) derlendi ve içeriği doğrulandı** — henüz yüklenmedi | §4cl |
| 09-20 | ♻️ Yeniden gönderim isteği + onarımı görünür kılan metin **dağıtıldı** | §4cl |
| 09-20 | 🔍 Saha teshisi: §4cc ÇALIŞIYOR — ama kaybolan mesaj kurtarılmıyor, onarım görünmüyor | §4ck |
| 09-20 | 📖 Açık kaynak hazırlığı: AGPL-3.0 lisansı, sır taraması temiz, iddia kapıya bağlandı | §4cj |
| 09-20 | 🔎 v23 saha kontrolü: yayında, 0 çökme — ama testçi sayısı **tam sınırda 12** | §4ci |
| 09-20 | 📞 Grup aramasından da IP açıklaması kaldırıldı — kapı artık hiçbir ekranı ölçmüyor | §4ch |
| 09-16 | 🚀 **v23 kapalı teste (Alpha) incelemeye gönderildi** | §4cg |
| 09-16 | 📦 v23 paketi §4cd–§4cf ile YENİDEN derlendi; içeriği pakette doğrulandı | §4cd |
| 09-16 | 📞 Arama rozetinden açıklama kaldırıldı (kullanıcı isteği) — IP uyarısı artık gösterilmiyor | §4cf |
| 09-16 | ✂️ Güvenlik bantları kırpılıyordu; kimlik bandı da taşındı ve 16 dilde kilitlendi | §4ce |
| 09-16 | 🐞 "Son görülme" başlıkta okunmuyordu — genişlik bütçesi + YANLIŞ çeviri anahtarı | §4cd |
| 09-16 | ⚖️ El sıkışma çakışması hakemi — iki taraf aynı anda onarınca ayrışma | §4cc |
| 09-16 | ☁️ `handshakes` kuralları + `init` alan geçersiz kılma **dağıtıldı** | §4cc |
| 09-16 | 🤝 Sessiz yeniden el sıkışma — onarım artık kullanıcıyı beklemiyor | §4cc |
| 09-16 | 🐞 Ratchet ilerleyip düz metin yazılmadan ölüm — mesaj kalıcı kayboluyordu | §4cb |
| 09-14 | 🐞 Kırpılan resim ekran oranında kaydediliyordu — tuval görüntüye daraltıldı | §4ca |
| 09-14 | 🐞 Mesaj düzenleyince "çözülemedi" — önbellek/sunucu sırası ters | §4bz |
| 09-12 | **Git kuruldu** — `git init` + ilk kayıt (326 dosya, sır taraması temiz) | — |
| 09-12 | `.gitignore` boşlukları kapatıldı (rules node_modules, play-sa, yedekler) | — |
| 09-12 | İşlem günlüğü kuruldu (bu bölüm) | — |
| 09-12 | Üretime başvuru formu taslakları yazıldı (TR+EN, 300 krk) | §3 F |
| 09-12 | Üretim kilidinin sebebi bulundu: 12 testçi × 14 gün, sayaç 1. günde | §3 F |
| 09-12 | Yerel imzalama anahtarı geliştirici doğrulamasına eklendi | §4by |
| 09-12 | DEVAM.md açılış bloğu ve Play durumu güncellendi (10 Eyl'den kalmıştı) | — |
| 09-11 | **v22 (1.0.11) kapalı teste yayınlandı** (23:46) | §4by |
| 09-11 | Sürüm notları v20→v22 birleşik metinle değiştirildi | §4by |
| 09-11 | `scripts/play_yukle.js` yazıldı (Play Developer API, 3 kapı testli) | §4by |
| 09-11 | Hikayede tepki şeridi dokunuşları yutuyor — hikaye atlanmıyor | §4bx |
| 09-11 | Çözme hatasına telemetri eklendi (sessiz `debugPrint` idi) | §4bw |
| 09-11 | Çözülemeyen medya artık "bozuk resim" değil "çözülemedi" gösteriyor | §4bv |
| 09-11 | "Sohbeti temizle" düzeltildi — yalnızca bende, kural gevşetilmedi | §4bu |
| 09-11 | Kendine mesaj ("Notlarım") — HKDF + AES-GCM, altın vektörle kilitli | §4bt |
| 09-11 | `scripts/turn_kur.sh` + `imza_parolasi_dondur.sh` yazıldı | §4bs |
| 09-11 | Grup aramasına gizlilik rozeti (16 dil, test 49→113) | §4br |
| 09-11 | Grup araması (mesh) + `sdp` kuralları + `calls` indeksi **dağıtıldı** | §4bq |
| 09-11 | Çalma sesi, yanıt alıntısı, davet kodu, kanal katılma düzeltmeleri | §4bm–§4bp |

---

## 0. Yeni oturuma nasıl başlanır

Yeni sohbette şunu yaz:

```
<proje-dizini> projesinde çalışıyoruz.
DEVAM.md ve GUVENLIK_DUZELTMELERI.md dosyalarını oku, sonra
"Sıradaki İşler" bölümünden devam et.
```

Bu iki dosya tüm bağlamı taşır; sohbet geçmişine ihtiyaç yok.

### Projedeki belgeler ve ne işe yaradıkları

| Dosya | İçerik |
|---|---|
| **`DEVAM.md`** (bu dosya) | Nerede kaldık, sıradaki işler, doğrulama komutları |
| **`GUVENLIK_DUZELTMELERI.md`** | Her düzeltmenin GEREKÇESİ (§1–§4ao). Bir kararın nedenini merak edince buraya bak |
| `PREMIUM_MIMARISI.md` | Premium neden kör imzayla kuruldu, kalan altyapı |
| `SIR_DONDURME.md` | Sızmış sırları döndürme adımları (konsol işi) |
| `TURN_KURULUMU.md` | TURN/relay sunucu kurulumu |
| `MIGRATION_STATUS.md`, `ARCHITECTURE.md` | Mimari arka plan |
| `scripts/` | Tek komutluk işler: `turn_kur.sh` (coturn), `imza_parolasi_dondur.sh` (parola rotasyonu), `play_yukle.js` (Play'e yükleme) |

### 🔴 EN SON NEREDE KALDIK (2026-09-16)

> **Önce bunu oku.** Her maddenin tam gerekçesi bu dosyadaki tur
> bölümlerinde (§4bf–§4cf) ve `GUVENLIK_DUZELTMELERI.md`de.

#### Durum

* 🚀 **v24 (1.0.13+24) İNCELEMEDE** (2026-09-22).
  Kanal özeti: *Etkin · 24 (1.0.13) sürümü incelemede · 177 ülke/bölge*.
  Yönetilen yayınlama KAPALI → inceleme biter bitmez testçilere
  kendiliğinden sunulur. Geri çekmek: Yayın özeti → **"Değişiklikleri
  kaldır"**.
  Paket 88,6 MB, SHA-256 `c6f0754f…`, GIF anahtarıyla derlendi.
  Sürüm adı elle `24 (1.0.13)` yazıldı; sürüm notu 360/500.
  ✅ Önizlemede **"artık desteklenmeyen cihaz: 0"** — v24 hiçbir cihazı
  kaybetmiyor (12.327 telefon + 6.717 tablet aynen).

  ❓ **AÇIK SORU — YAYIN AKIŞI İKİ ADIM MI, TEK ADIM MI?**
  Bu dosyadaki "Yayın akışı" bölümü, `Kaydet`ten sonra Yayın
  özetinde **"N değişikliği incelemeye gönder"** düğmesine basmak
  gerektiğini yazıyor. v23'te o düğme GÖRÜLDÜ. v24'te `Kaydet`ten
  ~15 sn sonra Yayın özeti açıldığında değişiklik **zaten
  "incelemede"** idi ve düğme YOKTU.
  İki açıklama mümkün: (a) kullanıcı kendi penceresinden bastı,
  (b) yönetilen yayınlama kapalıyken Play kaydedileni kendiliğinden
  gönderiyor. **Hangisi olduğu doğrulanmadı** — bir sonraki sürümde
  `Kaydet`ten hemen sonra Yayın özetine bakıp düğmenin olup
  olmadığına dikkat et.

  ✅ **İçerik doğrulandı** (tarih damgasına güvenilmedi, §4cg dersi):
  manifest `1.0.13` diyor ve `1.0.12`/`1.0.11` hiç geçmiyor;
  `libapp.so` içinde `resendRequests`, `E2EE_RETRY`, `e2ee_lost_retry`,
  `open_source`, `AGPL-3.0` ve GIPHY anahtarı **var**; eski önek işaret
  `E2EE_LOST_RETRY` **yok**.

  ⚠️ **Açık kaynak satırı bu pakette GÖRÜNMEZ** — `depoAdresi` boş
  (§4cj). Depo yayımlanıp adres doldurulunca bir sonraki sürümde
  kendiliğinden belirir.

* ✅ **v23 (1.0.12) KAPALI TESTTE YAYINDA** — 16 Eyl **11:08**'de
  kullanıma sunuldu. Kanal özeti: *Etkin · Son sürüm: 23 (1.0.12) ·
  177 ülke/bölge*. Sürüm özetindeki **"Sürüm kodları: 23"** alanı
  doğrulandı (etiket değil, gerçek alan — § SÜRÜM ADI ≠ PAKET SÜRÜMÜ).
* ✅ **4 günlük sahada 0 çökme / 0 ANR** (20 Eyl kontrolü).
  Android vitals → Kilitlenmeler ve ANR'ler: 28 günlük grafik düz
  sıfır, sorun tablosu *"Sonuç yok"*. ⚠️ Sınırı için §4ci.

* ✅ **Paket derlendi ve DOĞRULANDI** (16 Eyl 03:15).
  SHA-256 `a67c132b…`, 92.842.068 bayt.
  Paket `build/app/outputs/bundle/release/app-release.aab`
  (88,5 MB, **16 Eyl 03:15**), GIF anahtarıyla derlendi.
  Sürüm notu `scripts/surum_notlari.json` (en-US, **483**/500 karakter)
  §4cd–§4ce düzeltmelerini de anlatıyor.
  **Sıradaki iş bu:** Play Console → Kapalı test → yükle.
  Sürüm kodu 23 serbest (Play'e hiç çıkmadı), bump gerekmez.

  🪤 **Paket tazeliği VARSAYILMAZ, ölçülür.** Bu turda paket bir kez
  eski kaldı: derleme 02:23'teydi, §4cd–§4cf ondan sonra yazıldı.
  Yeniden derledikten sonra iki kapı birden çalıştırıldı:

  ```
  find lib -name '*.dart' -newer build/app/outputs/bundle/release/app-release.aab
  ```
  → **boş dönmeli** (döndü).

  ⚠️ Boyut kapı DEĞİL: yeni paket eskisinden **1 bayt** farklıydı
  (88,5 MB'ın çoğu değişmeyen yerel kitaplıklar). "Boyut aynı, demek ki
  derlenmemiş" yanlış sonuç olurdu. Kesin kanıt, `libapp.so` içinde
  YENİ dizeleri aramaktır — `presence_typing`, `yazıyor` (UTF-16LE),
  `πληκτρολογεί` ve GIPHY anahtarı arandı, dördü de bulundu.
  Kodlama kuralı için `SIR_DONDURME.md` ve bu dosyadaki dize arama
  notu (üç kodlama: ascii / latin-1 / UTF-16LE).
* ✅ **v22 (1.0.11) kapalı testte yayında** — 11 Eyl 23:46.
  ⚠️ **v21 hiç yayınlanmadı**; testçiler 20'den doğrudan 22'ye atladı.
* ✅ **Doğrulama kapıları yeşil** (2026-09-16, §4cd–§4cf sonrası):
  analyzer 0 bulgu · **623** Dart testi · **153** kural testi ·
  **4** functions testi · `dart format` temiz · `node --check` OK.
* ✅ **Üretimde dağıtılmış:** `firestore:rules` (grup araması `sdp` ve
  sessiz el sıkışma `handshakes` kuralları dahil), `firestore:indexes`
  (`calls` bileşik indeksi + `init.to` alan geçersiz kılma),
  `functions`, `storage`, `hosting`.
  ⚠️ Tek bilinçli istisna hâlâ **`issueEntitlement`** (premium; Play
  doğrulaması bağlanmadan açılırsa herkese premium dağıtır).
* ✅ **GIF AÇIK** — `GIPHY_API_KEY` v20'den beri derlemeye konuyor.
  ⚠️ Anahtar bir sohbette düz metin paylaşıldı → **döndürülmeli**
  (`SIR_DONDURME.md` §1, sıra önemli).
* ✅ **Android geliştirici doğrulaması tamam** (§4by): paket kayıtlı,
  kimlik dolu, yerel imzalama anahtarı da eklendi (son tarih 30 Eyl).

#### 🗓️ 25 EYLÜL: ÜRETİME BAŞVURU AÇILIYOR

12 test kullanıcısıyla 14 gün aralıksız kapalı test şartı; sayacın
1. günü 11 Eyl. **Başvuru formu taslakları hazır** — §3 F.

⚠️ O tarihe kadar **kimse testten ayrılmamalı**; 12'nin altına
düşerse sayaç sıfırlanabilir.

#### ⏳ Cihazda HİÇ denenmemiş olanlar

Bu turda yazılan her şey testçilere v22 ile gitti ama **hiçbiri gerçek
cihazda çalışmadı**:

| Ne | Neden önemli |
|---|---|
| Grup araması (mesh) | İki-üç telefon gerekiyor; TURN yok |
| Notlarım (kendine mesaj) | Yeni şifreleme yolu, hiç çalışmadı |
| `in_app_update` | v21'de eklenen native bağımlılık |
| Hikaye dokunma düzeltmesi | **Çıkarıma dayanıyor** — bkz. §4bx |
| Resim kırpma (§4ca) | Otomatik testi YOK, layout düzeltmesi |
| **Sessiz el sıkışma (§4cc)** | 🔴 **En riskli.** E2EE oturum kurulumuna dokunuyor |

#### 📌 AÇIK UÇLAR — cevabı yalnızca kullanıcıda/testçide

Bunlar koddan çıkarılamaz; sorulmadan ilerlenmemeli.

**1. Hikaye dokunma düzeltmesi DOĞRULANMADI (§4bx).**
Testçiye sorulacak soru: *"Hikayelerde 'iki kere basmak gerekiyor'
dediğin şey, alttaki tepki emojilerine / 'yanıtla' kutusuna basarken mi
oluyordu, yoksa hikayenin ortasında herhangi bir yere basarken mi?"*
→ **"Ortasında"** derse yanlış şey düzeltilmiş demektir; şerit
dokunuşlarını yutma çözümü o vakayı kapsamaz.

**2. Sessiz el sıkışma cihazda denenmedi (§4cc).**
En değerli senaryo, iki telefonla:
```
A'da uygulamayı sil → kurtarma anahtarıyla dön   (A'nın oturumu bozulur)
B'den A'ya mesaj at
A'da HİÇBİR ŞEY YAZMADAN bekle
→ B'nin mesajları okunur hâle geliyor mu?
```
Geliyorsa asıl şikâyet kapanmış demektir.

**3. Testçilere v23 ile birlikte söylenmesi gereken:**
> *"Bu sürümde mesajlaşma onarımı değişti. Daha önce 'çözülemedi' yazan
> bir sohbet, siz bir şey yazmadan kendi kendine düzelecek. Tuhaf bir
> şey görürseniz (mesajlar kaybolursa, sohbet aniden bozulursa) hemen
> haber verin."*

**4. ✅ KAPANDI — grup arama rozeti (§4ch).** 2026-09-20'de grup
ekranındaki açıklama da kullanıcı kararıyla kaldırıldı. Artık iki
arama ekranında da rozet yalnızca etiket.

**4b. 🟡 AÇIK KAYNAK — HAZIRLIK BİTTİ, YAYIMLAMA SENDE (§4cj).**
Lisans seçildi (AGPL-3.0), `LICENSE` yazıldı, sır taraması temiz çıktı,
arayüz satırı hazır ama **depo adresi boş olduğu için görünmüyor**.
Kalan tek adım: depoyu yayımlayıp `lib/core/proje_kimligi.dart`
içindeki `depoAdresi`ni doldurmak. Aşağıdaki eski durum kaydı
tarihsel: ⤵

**4b-eski. "AÇIK KAYNAK" İDDİASI — 2026-09-20'de HENÜZ DOĞRU DEĞİLDİ.**
Kullanıcının gerekçesi: *"İnsanlar uygulamanın açık kaynak olduklarını
bilmesini istiyorum."* Ama 2026-09-20 itibarıyla proje açık kaynak
DEĞİL ve bu üç eksikle ölçülebilir:

| Ne | Durum |
|---|---|
| `LICENSE` dosyası | **YOK** — lisanssız kod "tüm hakları saklı"dır |
| Uzak depo (`git remote`) | **YOK** — kod yalnızca bu bilgisayarda |
| Uygulamada/mağazada ibare | **YOK** — hiçbir yerde geçmiyor |

⚠️ Uygulamaya "açık kaynak" yazmak, kod yayımlanmadan **yanlış
beyan** olur; gizlilik iddiası taşıyan bir uygulamada bu, güveni
kazandırmak yerine tam tersini yapar. Sıra önemli: **önce yayımla,
sonra iddia et.**

⚠️ Yayımlamadan önce yapılması gerekenler (kod tarafı hazır ama
konsol/karar işi):
* `SIR_DONDURME.md` — Giphy anahtarı ve imzalama parolası; anahtar
  `--dart-define` ile veriliyor, depoda değil, ama geçmiş taranmalı.
* `.jks` ve `key.properties` **asla** yayımlanmamalı (`.gitignore`
  kapsıyor — §4ab'deki gömülü sır kapısı bunu ölçüyor).
* Lisans seçimi kullanıcının kararı (izin verici mi, copyleft mi).

**5. Foto editöründe BİLEREK ertelenen kusur (§4ca).**
`pixelRatio: 2.0` ile ekran boyutundaki widget fotoğraflanıyor: 4000
piksellik fotoğraf ~1500'e düşüyor ve çıktı PNG (fotoğraf için JPEG'den
kat kat büyük). Kullanıcı bunu bildirmedi; düzeltmek çıktı boyutunu
büyütür. Ölçülüp ayrı iş olarak yapılmalı.

#### 🔴 TURN hâlâ yok — mesh'te bu daha ağır

Grup araması **mesh**; her katılımcı diğer herkese doğrudan bağlanıyor.
TURN olmadan IP adresi **aramadaki herkese** açılıyor (birebir aramada
tek kişiye). Rozet bunu artık söylüyor (§4br) ama söylemek çözmek değil.
Kod tarafı bitti, kalan iş VPS + alan adı → `scripts/turn_kur.sh`.

---

### 📜 GEÇMİŞ TURLAR (arşiv — güncel durum yukarıda)

#### 🔴 2026-09-10 turunun en ağır bulgusu: grup rotasyonu tek cihazdaydı
Grup E2EE'sinde her üyenin AYRI gönderen zinciri var, ama rotasyon
yalnızca üyeyi **atan** yöneticinin cihazında çalışıyordu. Kalan
üyelerin zincirleri değişmediği için **atılan kişi onların sonraki
mesajlarını okumaya devam edebiliyordu** — süresiz, ve arayüzde hiçbir
iz bırakmadan. Düzeltildi (§4af). Elle doğrulaması §6'da.

#### ✅ GELEN ARAMA artık otomatik doğrulanıyor (§4am)
Bu senaryo **iki kez, hata vermeden** kırılmıştı (§4m kural, §4u şema)
ve buraya yıllardır *"otomatik doğrulama göremiyor"* yazılıydı.
**Görebiliyormuş.** Var olan kural testi `assertSucceeds` kullanıyordu:
sorgunun İZİNLİ olduğunu ölçüyor, EŞLEŞTİĞİNİ değil — §4u kırık hâlde
de geçerdi.

Artık bir **altın dosya** (`test/fixtures/call_incoming.golden.json`)
Dart şemasıyla emülatör testini birbirine bağlıyor: belge gerçek
`buildCallDocument` çıktısı, sorgu gerçek `CallFields` sabitleri ve
test sonucun **boş olmadığını** ölçüyor. Kırılabilirlik ölçüldü — iki
tarihsel hata da taklit edildi, ikisi de yakalandı.

⚠️ Elle testin yerini TAMAMEN almaz: WebRTC sinyalleşmesi, bildirim ve
çağrı ekranının açılması hâlâ iki cihaz ister (§6). Ama sebep artık
"otomatik doğrulama göremez" değil.

#### Bu oturumda yapılanlar (2026-09-05 → 09-10)
| § | Konu |
|---|---|
| 4af | 🐞 **Grup anahtarı rotasyonu yalnızca ATAN cihazda yapılıyordu** — atılan üye diğerlerinin mesajlarını okumaya devam ediyordu |
| 4ag | 🐞 **Üye listesi okunamayınca grup mesajı ŞİFRESİZ gidiyordu** — C-06'nın §4x'te kapatılmayan ikinci kapısı |
| 4ah | Yutulan hatalar 3. tur (16 çağrı) + `AppLogger` sadeleştirildi |
| 4ai | Çeviri açığı kapandı (1246 çeviri, 16 dil %100) + **kalıcı kapı** |
| 4aj | `calls`'a yazan ölü ikinci yol silindi (−237 satır) — §4u ayrışması artık **imkânsız** |
| 4ak | 🐞 **Üye çıkarma birebir harita eşleşmesine dayanıyordu** — atılan kişi `members`'ta kalabiliyordu; ayrıca **susturulmuş üye gruptan çıkamıyordu** |
| 4al | **Kaybolan mesaj artık sunucuda da siliniyor** — vaat "birinin sohbeti açmasına" bağlıydı. ⚠️ **DAĞITIM İSTER** |
| 4am | **Gelen arama otomatik doğrulamaya girdi** — altın dosya, Dart şemasıyla emülatör sorgusunu bağlıyor; §4m ve §4u taklit edilip yakalandı |
| 4an | 🐞 **Katılma sayacı her dokunuşta artıyordu** (kanal ekranında bu NORMAL sayılmıştı) + rol değişimi işlemsiz yarış taşıyordu |
| 4ao | 🐞 **Yedek sahipliği doğrulanmıyordu** (başka hesabın yedeği sessizce "başarılı") + şikâyete engelleme eklendi + **arayüze ham istisna basan 10 yer** kapatıldı ve kapıya bağlandı |

> Bu tur §3b/2'yi (hata görünürlüğü) ve §3b/3'ü (çeviri) **kapattı**,
> §3b/5'in güvenlik riskini de kaldırdı. §4af ve §4ag §3b/2'yi
> incelerken ortaya çıktı — yani "kalan iş" sanılan maddeler
> incelenince altlarından gerçek açıklar çıkıyor.
>
> **Turun sonunda:** §4al üretime dağıtıldı ve çalıştığı doğrulandı;
> APK yeniden derlenip cihaza kuruldu. Yani kod, sunucu ve cihaz artık
> **aynı noktada** — §6'daki elle testler çalıştırılabilir.

#### Bir önceki oturumda yapılanlar (2026-09-04)
| § | Konu |
|---|---|
| 4o | Metadata 2. aşama — kullanıcı adları sohbet dokümanından çıktı |
| 4p, 4w | Yutulan hatalar görünür kılındı (19 kritik çağrı bağlandı) |
| 4q | Hata metinleri çevrilebilir; ham istisna sızıntısı 43 → 0 |
| 4r | 🐞 Buluşma kodu: uygulama kendi kopyaladığı biçimi reddediyordu |
| 4s, 4aa, 4ae | Güvenlik bantları: kimlik, anahtar rotasyonu, şifresizlik |
| 4t, 4u, 4v | Çağrı şeması N kişiye — **§4t bozuk gitti, §4u düzeltti** |
| 4x | C-06'nın grup yolu kapatıldı (arızada mesaj gönderilmiyor) |
| 4y | Premium: hesaba bağlanmayan yetki (kör imza) |
| 4z | APK 103,9 → **39,6 MB** |
| 4ab, 4ac | Kalıcı kapılar: gömülü sır + ölü dosya taraması |
| 4ad | CI kapıları yerel kapıyla eşitlendi |

#### ⚠️ İKİNCİ tekrar eden kök sebep (2026-09-05'te eklendi)
**Bir ARIZAYI yutup yerine "boş/varsayılan" değer döndürmek, onu bir
sonraki katmanda meşru bir DURUMA çeviriyor.** İki katman arasındaki
ayrım, hata yutulduğu anda kayboluyor.

* §4ag: üye listesi okunamadı → `const []` → şifreleme katmanı bunu
  "dejenere grup" sanıp mesajı **düz metin** gönderdi
* `chat_lock_service`: liste okunamadı → boş küme → **her sohbet
  kilitsiz** (§4ah'de raporlamaya bağlandı)
* `splash_screen`: kontrol patladı → `safe()` → **hiç bakılmadan
  "güvenli"** (§4ah)

**Bir `catch` bloğunda varsayılan değer döndürmeden önce sor: bu değer
bir sonraki katmanda GEÇERLİ BİR DURUM gibi mi okunacak?** Öyleyse ya
istisnayı yukarı bırak (§4x ilkesi: arızada gönderme) ya da en azından
`reportHandled`a bağla.

#### ⚠️ Tekrar eden kök sebep — YENİ OTURUM BUNU BİLSİN
2026-09-04 oturumunda **üç kez** aynı hata: *düzeltmenin canlı yola
ulaştığını varsaymak.* Bu projede aynı işi yapan iki uygulama olabiliyor.

* §4t: `participants` yalnızca Clean katmanına eklendi, canlı yol
  atlandı → gelen arama sessizce kırıldı, **üretime çıktı**
* §4o, §4ac: iki ölü ikiz bulundu (`chat_model.dart`,
  `conversations_screen.dart`)
* §4ae: `rg` bir dosyayı NUL baytı yüzünden "ikili" sayıp satırlarını
  göstermiyor → kaynak sayımı eksik kaldı

**Bir şeyi değiştirmeden önce sor: bu YOL canlı mı?** Çağrı katmanının
başında artık uyarı var. `encryption_datasource_impl.dart`'ta arama
yaparken `rg -a` kullan ya da Python ile tara.

### Bir önceki tur (2026-08-29)

Üretime ilk dağıtım yapıldı ve üç büyük şey ortaya çıktı (§4m, §4n):
`firestore:rules` ✅, `functions` ✅ (13 adet), `firestore:indexes` ✅.
Fonksiyonların çoğu üretimde HİÇ YOKTU (`claimPreKey` dahil → E2EE
oturumu kurulamıyordu); indeksler de yoktu → sohbet listesi ve arama
geçmişi boş geliyordu; `calls` kuralındaki `list: false` gelen aramayı
tamamen kırıyordu.

---

## 1. Proje nedir

**SECRETER** (`gizli_chat`) — Flutter + Firebase, gizlilik odaklı
mesajlaşma uygulaması. Telefon numarası/e-posta istemez; kimlik yalnızca
cihazda durur.

* Paket adı: `com.secreter.app`
* Firebase projesi: `gizlichat-f2a99`
* Platform: yalnızca **Android** (iOS yapılandırılmadı)
* Kaynak dosya sayısı: ~260

---

## 2. Bugüne kadar ne yapıldı

### Güvenlik denetimi (252 dosya, 96 bulgu)
Tam liste ve her bulgunun çözümü: **`GUVENLIK_DUZELTMELERI.md`**

Özet: 12 Kritik + 22 Yüksek + ~48 Orta/Düşük bulgu giderildi. En
önemlileri:

| Kod | Neydi |
|---|---|
| C-01 | Herkes herkesin özel sohbetine girip mesajları okuyabiliyordu |
| C-02 | Tüm sohbet medyası her kayıtlı kullanıcıya açıktı |
| C-03 | WebRTC ICE adayları (IP adresleri) herkese açıktı |
| C-06 | Şifreleme hatası sessizce DÜZ METNE düşüyordu |
| C-07 | Çözülmüş mesajlar cihazda sonsuza kadar kalıyordu |
| C-09 | E2EE oturumu hiç kurulamıyordu (kural/istemci çelişkisi) |
| C-11 | Derin bağlantı uygulama kilidini atlıyordu |
| C-12 | Kurallar `firebase.json`'da tanımlı olmadığı için dağıtılmıyordu |

### Sonradan eklenen özellikler
1. **Grup E2EE (Sender Key)** — `lib/services/group_key_service.dart`
   Grup/kanal mesajları artık uçtan uca şifreli. Üyelik değişiminde
   anahtar rotasyona girer — **her üyenin kendi cihazında**
   (`syncMembership`); yalnızca atan yöneticinin rotasyonu YETMEZ,
   bkz. §4af.
2. **Şifreli medya ekleri** — `lib/core/media/attachment_crypto.dart`,
   `secure_media_cache.dart`, `core/widgets/secure_media_image.dart`
   Foto/video/ses/dosya AES-256-GCM ile cihazda şifrelenip yükleniyor.
   Anahtar, mesajın E2EE'li `content` alanında taşınıyor (`ATT1|<anahtar>|`).
3. **Video kırpma** — `android/.../VideoTrimmer.kt`,
   `core/media/video_trim_service.dart`, `video_trim_screen.dart`
   MediaExtractor+MediaMuxer ile yeniden kodlamasız kırpma (+0.3 MB).
4. **Video için tek-görüntülük** — `_showVideoSourceMenu` içine switch.
5. **i18n tamamlama** — `+` menüsü ve `SecurityWarningScreen` sabit
   Türkçeydi; 21 anahtar eklendi.
6. **Güvenlik numarası doğrulaması** — `features/security/presentation/
   safety_number_screen.dart`, `E2EESessionService.safetyInfo/
   setUserVerified/acknowledgeIdentityChange/ensureSessionFromHeader`
   Numara + QR + "Doğrulandı" işaretleme; sohbet başlığında rozet;
   karşı tarafın kimlik anahtarı değişince uyarı bandı. Ayrıntı ve bu
   iş sırasında bulunan sessiz hata: `GUVENLIK_DUZELTMELERI.md` §4e.
7. **TURN altyapısı** — `services/turn_credentials_service.dart`,
   `functions/index.js` → `getTurnCredentials`, arama ekranında IP
   gizlilik rozeti. Kimlik artık SUNUCUDAN ve kısa ömürlü alınır; çoklu
   URL (UDP/TCP/TLS 443) desteklenir. Ayrıntı: `GUVENLIK_DUZELTMELERI.md`
   §4f, kurulum: `TURN_KURULUMU.md`.
   ⚠️ **Sunucu hâlâ kurulmadı** — kod hazır, relay yok.
8. **DH ratchet (v3)** — `double_ratchet_service.dart` +
   `e2ee_session_service.dart`. Post-compromise security geldi: çalınan
   durum iki tur sonra işe yaramaz olur. Eski oturumlar v2'de çalışmaya
   devam eder; sürüm anlaşması `keyBundles.ratchetVersion` üzerinden.
   Yolda **SPK rotasyonunda sessiz uyuşmazlık** hatası bulundu ve
   düzeltildi. Ayrıntı: `GUVENLIK_DUZELTMELERI.md` §4g.

8. **Uygulama kılığı** — `core/security/app_disguise_service.dart`,
   `AndroidManifest` activity-alias'ları, `MainActivity.setDisguise`
   Başlatıcıda "Hesap Makinesi" adı ve simgesiyle görünür. Sahte PIN'in
   tamamlayıcısı: sahte PIN telefon açıldıktan SONRA korur, kılık
   uygulamanın VARLIĞINI gizler. Signal/WhatsApp/Telegram'da yok.
   Ayarlar → Güvenlik'ten açılır.

9. **Metadata gizliliği — 1. aşama** — `services/username_resolver.dart`
   Gönderen adı artık sunucuya yazılmıyor; uid'den yerelde çözülüyor.
   Push bildirimi başlığı da nötrleştirildi (ad FCM'e ve kilit ekranına
   çıkıyordu). Ayrıntı ve sonraki aşamalar: `GUVENLIK_DUZELTMELERI.md`
   §4k.

10. **Kullanıcı numaralandırma kapatıldı** — `firestore.rules`
    `users` listelemesi kapatıldı (tekil okuma korundu); arama zaten var
    olan `usernames` dizinine taşındı. Eskiden giriş yapan herkes tüm
    kullanıcı tabanını dökebiliyordu. Ayrıntı: `GUVENLIK_DUZELTMELERI.md`
    §4l.

11. **Metadata gizliliği — 2. aşama** — `services/chat_metadata_scrub.dart`
    Kullanıcı adları sohbet dokümanından tamamen çıktı
    (`memberUsernames` ve `members[].username`); ad uid'den çözülüyor,
    kural sunucuda kapatıyor, eski dokümanlar temizleniyor. Ayrıntı:
    `GUVENLIK_DUZELTMELERI.md` §4o.

12. **Yutulan hatalar görünür kılındı** —
    `core/observability/handled_error.dart`
    `reportHandled()` geçidi: yerele tam ayrıntı, telemetriye yalnızca
    sabit etiket + hata kodu (ham metin **çıkmaz**, tanımlayıcı sızmaz).
    Güvenlik garantisi sessizce bozulan 7 çağrı bağlandı. Ayrıntı ve
    çalışmayan lint denemesi: `GUVENLIK_DUZELTMELERI.md` §4p.

13. **Hata metinleri çevrilebilir** — `core/error/exceptions.dart`,
    `app_localizations.dart`
    Türkçe üretici 74 → 5, ham istisna sızıntısı 43 → 0, `err_*`
    anahtarı 28 → 67. Ayrıntı: `GUVENLIK_DUZELTMELERI.md` §4q.

### Şifreleme kapsamı (şu anki durum)
| | Durum |
|---|---|
| 1:1 metin | ✅ X3DH + Double Ratchet |
| Grup/kanal metin | ✅ Sender Key |
| Medya (foto/video/ses/dosya) | ✅ AES-256-GCM |
| Son mesaj önizlemesi | ✅ maskeli (`🔒 Mesaj`) |
| Düzenlenen mesaj | ✅ yeni ratchet mesajı olarak şifreli |
| Post-compromise security | ✅ DH ratchet (yeni oturumlarda; eskiler v2) |
| Kullanıcı adları (metadata) | ✅ sunucuda YOK (§4k mesajlar, §4o sohbet dokümanı) |
| `senderId` / `memberIds` / `readBy` / zaman damgaları | ❌ hâlâ açık — 3. aşama |

---

## 3. SENDE BEKLEYENLER (kod değil, altyapı)

Bunlar kodla bitirilemez; hesap/sunucu erişimi gerektirir.

### 🔴 A. TURN sunucusunu ayağa kaldır
Uygulama tarafının tamamı bitti (kısa ömürlü kimlik, çoklu URL, arayüz
rozeti, hata ayrımı — bkz. `GUVENLIK_DUZELTMELERI.md` §4f).
**Eksik olan tek şey sunucunun kendisi.** O kurulana kadar her arama
P2P kurulur ve taraflar birbirinin IP adresini görür — uygulamanın
anonimlik iddiasındaki en büyük açık budur.

Adım adım kurulum: **`TURN_KURULUMU.md`**

Özetle:
1. VPS + alan adı (`turn.ornek.com`) — **senin alman gereken tek şey**
2. Sunucuda tek komut: `sudo bash scripts/turn_kur.sh turn.alanin.com`
   (coturn kurulumu, TLS, günlük kapatma, yenileme kancası, güvenlik
   duvarı — hepsi içinde; elle yapılınca atlanan üç sessiz arıza için
   bkz. §4bs)
3. `functions/.env` içine `TURN_SECRET` (coturn'dekiyle **aynı**) ve
   `TURN_URLS` (443/TCP başta olacak şekilde sıralı) — betik bu iki
   satırı sonunda hazır yazdırıyor
4. `firebase deploy --only functions:getTurnCredentials`
5. İki cihazla arama → rozet **"Aktarmalı bağlantı"** 🔒 demeli
   ("Doğrudan bağlantı" diyorsa TURN devrede değil)

> **443/TCP** portunu atlama: kurumsal ağlar 3478'i kapatır, 443'ü
> kapatamaz. Tek URL ile o ağlarda arama hiç kurulmaz.

### 🟠 B. Kalan dağıtımlar
✅ **Firestore kuralları DAĞITILDI** (2026-08-29, `gizlichat-f2a99`).
Dağıtım sırasında gelen aramayı kıran gizli bir kural hatası ortaya
çıktı ve düzeltildi — bkz. `GUVENLIK_DUZELTMELERI.md` §4m.

✅ **Cloud Functions DAĞITILDI** (13 fonksiyon). Çoğu üretimde HİÇ
YOKTU — `claimPreKey` dahil, yani E2EE oturumu kurulamıyordu (§4n).
✅ **İndeksler DAĞITILDI ve inşa tamamlandı** — sohbet listesi ve arama
geçmişi indekssiz çalışmıyordu; cihazda doğrulandı (indeks hatası 0).

✅ **`firestore:rules` YENİDEN DAĞITILDI** (2026-09-01) — §4o'nun ad
kısıtı ve eski dokümanları temizleme izni içinde. Yeni APK aynı gün
cihaza kuruldu, açılış temiz.

✅ **`storage` DAĞITILDI** (2026-09-02) — **C-02 nihayet aktif**; sohbet
medyası artık yalnızca o sohbetin üyelerine açık.
✅ **`hosting` DAĞITILDI** (2026-09-02) → https://gizlichat-f2a99.web.app

✅ **§4al DAĞITILDI ve ÇALIŞTIĞI DOĞRULANDI** (2026-09-10) —
`cleanupExpiredMessages` (14. fonksiyon) + `messages.expiresAt` için
COLLECTION_GROUP indeksi. İlk çalışmasında **4 kayıt sildi**: süresi
çoktan dolmuş ama sunucuda duran mesajlardı.

**Bu başlıkta yapılacak bir şey kalmadı.** Denetimdeki tüm düzeltmeler
üretimde aktif — C-12'nin ("kurallar hiç dağıtılmıyor") kapanışı ancak
burada tamamlandı.
⚠️ Tek bilinçli istisna hâlâ **`issueEntitlement`** (§4y): Play
doğrulaması bağlanmadan dağıtılırsa herkese premium dağıtır.

### 🔴 D. Hesap kurtarma boşluğu — KARAR GEREKİYOR

Uygulama kaldırılınca hesap ERİŞİLEMEZ oluyor (parola yalnızca cihazda).
Ayrıntı ve seçenekler: bu dosyada "UYGULAMAYI KALDIRMAK HESABI
KAYBETTİRİYOR" bölümü. Karar vermen gereken: kurtarma anahtarı kayıtta
ZORUNLU mu olsun, ve içine E2EE kimliği konsun mu (çalınırsa kimlik
çalınır — ödünleşim senin).

### 🟠 C. Sızmış sırları döndür → **`SIR_DONDURME.md`**
Kod tarafı hazır ve doğrulandı (§4ab); kalan iş yalnızca konsollarda.

* **İmzalama parolası** — `bash scripts/imza_parolasi_dondur.sh`
  (yedek + keytool + key.properties + doğrulama derlemesi; parolayı
  keytool sorar, betik görmez).
  ⚠️ Acil DEĞİL: parola tek başına işe yaramaz, `.jks` dosyası bu
  makineden hiç çıkmadı.
* **Giphy anahtarı** — ⚠️ **durum değişti:** artık anahtarsız
  derlenmiyor, **v20 ve v22 paketleri anahtarı İÇERİYOR** ve anahtar
  bir sohbette düz metin paylaşıldı. Döndürme SIRASI önemli: önce yeni
  anahtarla yeni sürümü yayınla, **sonra** eskisini iptal et; tersi
  sahadaki tüm sürümlerde GIF'i anında öldürür.

### 🟡 E. Play Developer API hizmet hesabı (yükleme otomasyonu)

`scripts/play_yukle.js` hazır ve kapıları test edildi (§4by) ama
çalışması için hizmet hesabı gerekiyor — **yalnızca hesap sahibi
kurabilir**:

1. Play Console → Ayarlar → **API erişimi** → Cloud projesini bağla
2. Google Cloud → Hizmet Hesapları → oluştur → **Anahtarlar → Anahtar
   ekle → JSON** (⚠️ hesabı oluşturmak anahtar ÜRETMEZ)
3. Play Console → Kullanıcılar ve izinler → hizmet hesabını davet et →
   yalnızca **"Test kanallarına sürüm yayınla"**
   (⚠️ Cloud'daki IAM rolü Play tarafında hiçbir şey yapmaz)
4. `PLAY_SERVICE_ACCOUNT_JSON=<yol>` ver, sonra:
   `node scripts/play_yukle.js --kanallar` (kurulumu doğrular)

Kurulunca yükleme tek komut olur; tarayıcıdan yüklemek **mümkün değil**
(araç sınırı 10 MB, paket 88 MB).

### 🔴 F. ÜRETİME BAŞVURU — 25 Eylül 2026'dan sonra

**Durum (20 Eyl — Play'in kendi sayacından okundu):** "Üretime
başvur" düğmesi hâlâ **pasif**. Kontrol paneli birebir şunu yazıyor:

> *"An itibarıyla **12** test kullanıcısı kesintisiz olarak **9 gündür**
> kayıtlı"*

Yani 1. gün 11 Eyl'di ve tahmin tutuyor: 14. gün ≈ **25 Eylül**.

🔴 **SAYI TAM SINIRDA: 12/12. PAYI YOK.** Şart "en az 12" ve elde tam
12 var — **bir kişi ayrılırsa sayaç sıfırlanabilir** ve 14 gün baştan
başlar.

⚠️ Buradaki sayı, uygulamayı yükleyen kişi sayısıyla AYNI DEĞİL.
Uygulama listesi "21 kullanıcı" gösteriyor ama şartı ölçen sayaç
**12**'de. Yükleme sayısına bakıp "rahatız" demek yanlış okuma olur —
ölçülen şey *teste kayıtlı kalmak*, *uygulamayı kurmuş olmak* değil.

⚠️ **SAYAÇ SIFIRLANABİLİR.** 12 kişinin **kesintisiz** kayıtlı kalması
gerekiyor. Biri testten ayrılırsa sayı 12'nin altına düşer ve gün sayacı
baştan başlayabilir. Önümüzdeki iki hafta:
* kimseyi test listesinden çıkarma,
* testçilere "uygulamayı silebilirsin ama **testten ayrılma**" de,
* yeni testçi eklemek zararsız, sayıyı artırır.

Kapalı teste sürüm yayınlamak sayacı BOZMAZ — tam tersi, 14 gün boyunca
düzeltme göndermek başvuruda işe yarar.

> ⚠️ Başvuru düğmesi **Üretim sayfasında değil, Kontrol Paneli'nde.**
> Üretim sayfası onay gelene kadar kilitli ve "Kontrol Paneli'ne git"
> diyor; oraya bakıp "başvuru kaldırılmış" sanmak kolay.

#### Başvuru formu — 3 adım

Formun yalnızca 1. adımı okunabildi (diyalog pasifken sihirbaz
ilerlemiyor). Diğer ikisinin **yalnızca başlıkları** biliniyor:

| # | Başlık | Durum |
|---|---|---|
| 1 | Kapalı testiniz hakkında | sorular aşağıda |
| 2 | Uygulamanız hakkında | ❓ içerik bilinmiyor |
| 3 | Üretime hazırlık durumunuz | ❓ içerik bilinmiyor |

#### 1. adımın soruları ve HAZIR TASLAKLAR

Her metin alanı **300 karakter** sınırlı. Taslaklar sınırın içinde
ölçüldü.

**S1 — Test kullanıcılarını nereden buldunuz?** *(272)*
```
Testçileri kendi arkadaş çevremden buldum; ücretli bir test
sağlayıcısı kullanmadım. Uygulamayı arkadaşlarıma anlatıp kapalı
teste katılmak isteyenleri davet ettim. Günlük olarak mesajlaşma
uygulaması kullanan, farklı Android cihazlara sahip kişiler
olmasına dikkat ettim.
```
*(EN, 263)*
```
I recruited testers from my own circle of friends; I did not use a
paid testing service. I described the app to friends and invited
those who wanted to join the closed test. I made sure they were
people who use messaging apps daily, on a range of Android devices.
```

**S2 — Test kullanıcısı bulmak ne kadar kolaydı?** (çoktan seçmeli:
Çok zor / Zor / Ne zor ne de kolay / Kolay / Çok kolay)
→ **Kullanıcının kendi deneyimi; taslak yazılmadı.**

**S3 — Testçilerden nasıl etkileşim aldınız?** *(255)*
```
Testçiler mesajlaşma, fotoğraf/video gönderme, grup ve kanal
özelliklerini düzenli kullandı; bu beklediğim gibiydi. Arama ve
hikaye özellikleri beklediğimden az denendi. Grup araması ve
kendine not en son sürümde geldiği için henüz yeterince
kullanılmadı.
```
*(EN, 257)*
```
Testers regularly used messaging, photo/video sharing, groups and
channels, which matched my expectations. Calls and stories were
tried less than I expected. Group calling and notes-to-self shipped
in the latest release, so they have not been used much yet.
```
⚠️ İkinci cümle **çıkarımdır.** Mesajlaşma/medya/grup/kanal kullanımı
gerçek (hepsinden hata raporu geldi); "arama ve hikaye az denendi"
tahmin. Başvuru günü gerçeğe göre düzelt.

**S4 — Geri bildirimleri özetleyin (nasıl topladığınız dahil)** *(286)*
```
Geri bildirimi testçilerle doğrudan yazışarak topladım.
Bildirilenler: GIF sekmesi açılmıyor, grup/kanal kurarken davet
kodu hatası, kanala katılırken hatalı yasaklama uyarısı, bazı
mesajların çözülememesi, bazı fotoğrafların açılmaması, hikayede
dokunmanın işlememesi. Hepsi giderildi.
```
*(EN, 300 — TAM SINIRDA, tek karakter eklenemez)*
```
I collected feedback by messaging testers directly. Reported: the
GIF tab would not open, an invite-code error when creating a group
or channel, a wrong "banned" warning when joining a channel, some
messages failing to decrypt, some photos not opening, and taps not
registering in stories. All fixed.
```

#### ⚠️ BAŞVURU GÜNÜ YAPILACAK

1. **S3 ve S4'ü TAZELE.** 14 gün boyunca yeni raporlar gelecek; başvuru
   tam da "test gerçekten yapıldı mı" sorusunu ölçüyor. Aradaki
   bulguları eklemek en güçlü kanıt.
2. İngilizce S4 tam sınırda — yer açmak gerekirse en eski ve en
   önemsiz madde olan "GIF tab would not open" çıkarılabilir.
3. 2. ve 3. adımın soruları o gün ilk kez görülecek; hazır cevap yok.



---

## 3b. SIRADAKİ KOD İŞLERİ (öncelik sırasıyla)

> ✅ **Güvenlik numarası doğrulama ekranı BİTTİ** (2026-08-18) — §4e.
> ✅ **TURN uygulama tarafı BİTTİ** (2026-08-18) — §4f.
> ✅ **DH ratchet BİTTİ** (2026-08-18) — §4g. Post-compromise security
> geldi; yolda SPK rotasyonunda sessiz bir uyuşmazlık hatası da bulunup
> düzeltildi.
> ✅ **Düzenlenen mesajlar artık ŞİFRELİ** (2026-08-18) — §4h. Düzenleme
> hem sunucuya düz gidiyordu hem de alıcıya HİÇ ulaşmıyordu.
> ✅ **Tutarlılık taraması** (2026-08-19) — §4i. Kural/istemci/fonksiyon
> katmanları arasındaki alan uyumu sistematik tarandı: iki ölü yazma
> izni kaldırıldı, birebir sohbetin kalıcı olarak açılamamasına yol açan
> bir hata bulunup giderildi.
> ✅ **Kalite ve sertleştirme turu** (2026-08-19) — §4j. `await` sonrası
> BuildContext kullanan üç gizli çökme, sessizce uygulanmayan gizlilik
> ayarı ve sessizce çöken güvenlik dedektörleri düzeltildi; analyzer
> 259 → **0**; kurtarma anahtarı, grup E2EE ve derin bağlantıya test
> eklendi (111 → 135).

### 🟡 1. "Oturum durumu okunamadı" yolu kapatılmalı mı? (§4ae)
Birebir şifrelemede bir yol var ki bir DURUM değil, bir **ARIZA**:
oturum deposu okunamıyor ve mesaj şifresiz gidiyor. §4x'in mantığıyla
(arızada gönderme) kapatılması gerekir gibi görünüyor.

⚠️ Ama önce **sıklığı ölçülmeli**: §4ae bu yolu `reportHandled`'a
bağladı. Telemetride hiç görünmüyorsa kapatmak risksiz; sık görünüyorsa
kapatmak çalışan mesajlaşmayı kırar. Ölçmeden karar verme.

> **Bu madde HÂLÂ ÖLÇÜM BEKLİYOR** — kodla ilerletilemez. Telemetri
> Crashlytics'te `E2EE oturum durumu okunamadı — mesaj ŞİFRESİZ`
> etiketiyle birikiyor; ayrıca §4ag'nin GRUP karşılığı olan
> `Grup dejenere (üye < 2) — mesaj ŞİFRESİZ` de artık ölçülüyor.
> Yeni oturum bu maddeyi açarken önce Firebase Console'a bakmalı.

### ✅ 2. Hata görünürlüğü — BİTTİ (2026-09-05, §4ah)
Üç maddenin üçü de kapandı:
* ✅ `catch` içindeki **97** `debugPrint` tarandı; ölçütü karşılayan
  **16**'sı bağlandı (`reportHandled` 121 → **142**, yutulan 97 → 78).
  Ölçüt: *kullanıcı bir garantinin geçerli olduğunu sanıyor ama
  değil.* Olağan dayanıklılık yutmalarına bilerek dokunulmadı.
* ✅ `AppLogger` **sadeleştirildi** (yaygınlaştırılmadı): çağrılmayan
  `debug`/`info`/`warning` kaldırıldı — ölü yazma yüzeyiydi ve
  maskeleme kapısını atlayan bir günlük satırı davet ediyordu.
* ✅ Rotasyon uyarısı artık **her cihazda**. Bu maddeyi incelerken
  eksiğin bildirim değil **rotasyonun kendisi** olduğu bulundu (§4af).

### ✅ 3. Çeviri — AÇIK KAPANDI (2026-09-05, §4ai)
Ölçülen açık dokümanda yazandan büyüktü: **89 anahtar × 14 dil = 1246
çeviri**. Üstelik eksikler rastgele değil, son turlarda eklenen
**güvenlik metinleriydi** (`err_*` 45, `threat_*` 10, `sec_*` 9,
`recovery_*` 8) — yani Rusça arayüz kullanan biri tam olarak mesajı
şifrelenemediğinde ya da cihazında hook aracı bulunduğunda İngilizce
metin görüyordu.

* ✅ 16 dilin hepsi **623/623 anahtar** (%100).
* ✅ **Kalıcı kapı kuruldu:** `test/core/i18n/translation_gate_test.dart`
  altı invaryantı kilitliyor (eksik/fazla/boş anahtar, `tr`↔`en`
  eşitliği, dil seçici ↔ tablo örtüşmesi, anahtar biçimi). Asıl
  düzeltme budur: çeviri yazmak açığı kapatır, kapı **tekrar
  açılmasını** engeller.
* 🐞 Yol üstünde bir test AÇIĞIN KENDİSİNİ doğruluyordu (Almanca'nın
  İngilizce'ye düştüğünü). Doğru davranış onu kırdı; düzeltildi.

> ⚠️ **KALAN İŞ — ana dili konuşan gözden geçirmesi.** 1246 çeviri o
> incelemeden GEÇMEDİ. İngilizce yedeğinden kesin olarak daha iyi
> (alternatif, kullanıcının anlamadığı bir güvenlik uyarısıydı) ama
> yayın öncesi öncelik: `sec_*` + `threat_*` (19 anahtar), sonra
> `err_*`. Biçimsel doğrulamalar yapıldı — Arapça RTL, Çince
> tam-genişlik noktalama, kesme işareti kaçışları, süre eklenen
> anahtarlarda sondaki boşluk (§4ai).

### 🟡 4. Grup araması — kalan iş (§4t'nin devamı)
Şema ve kurallar hazır. Sırada:
* **Sunucu**: LiveKit (hem TURN hem SFU) ya da coturn+ayrı SFU.
  Bu aynı zamanda §3A'daki TURN açığını da kapatır.
* İstemcide N adet `RTCPeerConnection` yönetimi (SFU ile tek
  bağlantıya iner — mesh'e göre çok daha basit).
* Grup arama için E2EE: `flutter_webrtc` `FrameCryptor`
  (Signal'in SFrame yaklaşımı). SFU şifreli kareleri çözmeden
  dağıtır.
* ⚠️ MESH YAPMA: TURN olmadan herkesin IP'si herkese açılır.

### 🟡 5. Çağrı modelleri — RİSK KALKTI, mimari iş kaldı (§4aj)
✅ **Ayrışma riski BİTTİ (2026-09-05).** Kök sebep "iki model" değil
"iki YAZAR"dı. İkinci yazar (`StartCall`/`AnswerCall`/`EndCall` ve
altlarındaki `createCall`/`setAnswer`/`getAnswer`/`deleteCall`)
üretimde HİÇ çalışmıyordu ama `calls`'a tam bir doküman yazacak koda
sahipti — §4t tam da o ölü katmana alan ekleyip canlı yolu atladığı için
bozuk gitmişti. Ölü yazma yüzeyi silindi (**−237 satır**); `calls`'a
yazan tek model kaldı, yani §4u'nun ayrışma sınıfı artık testin
yakaladığı değil **yapısal olarak imkânsız** bir şey.

Geriye kalan gerçek bağ **canlı yazar → Clean okur** turu (gelen arama
`fromMap` ile çözülüyor); eşitlik testi tur testine çevrildi ve grup
vakasıyla güçlendirildi.

**Kalan iş (mimari, güvenlik değil):** `CallService`'in Clean mimariye
taşınması. Artık risk taşımıyor, sadece tutarlılık işi — ve **cihazda
arama testi yapılabildiğinde** ele alınmalı. Gelen arama senaryosu hâlâ
doğrulanmamış (§6'nın en üstü).

### 🟡 6. Premium — KALAN altyapı (§4y'nin devamı)
✅ **Zor kısım bitti:** bağlanamazlık kuruldu ve test altında (kör imza,
yetki jetonu, doğrulayıcı, tek kullanım kaydı, kurallar). Mimarinin
tamamı ve gerekçeleri: **`PREMIUM_MIMARISI.md`**.

Kalanların hiçbiri mimariyi değiştirmez, hepsi altyapı:
1. **Play Console ürünleri** (abonelik/ürün tanımı)
2. **Hizmet hesabı + Play Developer API** — `issueEntitlement` içindeki
   `purchaseVerified` şu an `false`, fonksiyon `501` dönüyor.
   ⚠️ **Doğrulama bağlanmadan açılırsa uç nokta HERKESE premium dağıtır.**
3. **Dönem anahtarları** — RSA 2048+, ortam değişkeni
   `ENTITLEMENT_KEY_PREM_2026_10` (PEM); açık anahtar istemciye gömülür.
   Rotasyon takvimi belirlenmeli. ⚠️ Dönem aylıktan KISA olmamalı:
   anonimlik kümesi o dönemin tüm ödeyenleridir.
4. **İstemci satın alma akışı** — `in_app_purchase`, satın alma sonrası
   `issueEntitlement` çağrısı, jetonu `SecureStore`a yazma.
5. **Hangi özellikler premium?** Henüz belirlenmedi. Sunucuda uygulanan
   bir özellik varsa jeton SUNUCUYA gönderilip orada doğrulanmalı —
   istemci tarafı kontrol bir kapı değildir.

### 🟡 7. Metadata gizliliği — 3. aşama (öneri)
1. aşama (§4k) ve 2. aşama (§4o) bitti: kullanıcı adları ne mesajda ne
sohbet dokümanında duruyor. Sunucuda kalanlar ve zorlukları:

* `users/{uid}` okumasını **ortak sohbeti olanlara** kısıtlamak. Şu an
  uid'yi bilen her oturum profili okuyabiliyor (numaralandırma §4l ile
  kapalı, ama uid ele geçirilirse profil açık). Kural düzeyinde
  "ortak sohbet" kontrolü `get()` çağrısı ister → her ad çözümüne bir
  okuma maliyeti biner. Ölçülmeden yapılmamalı.
* ✅ **`members[]` eski adları — ENGEL KALKTI (§4ak).** Temizliği
  engelleyen `arrayRemove` tuzağının kendisi bir hataydı: üye çıkarma
  TÜM haritayı birebir eşleştiriyordu, yani rol/susturma/ad kaymışsa
  kişi `memberIds`'ten düşüp `members`'ta **kalıyordu** — hatasız.
  Çıkarma uid ile yapılan bir işleme taşındı; `toMap()` artık adı hiç
  yazmıyor ve işlem kalan üyelerin adlarını da düşürüyor. `members`
  dizisini yeniden yazan her yol (çıkarma, ayrılma, rol/susturma) o
  grubu **kendiliğinden temizliyor.**
  ⚠️ **Kalan:** hiç üyelik/rol değişikliği olmayan gruplarda eski adlar
  durur. Tam süpürme yönetici tarafında ayrı bir tarama ister (kural
  yalnızca yöneticiye açık — `isAdmin()`).
* `senderId` yerine sohbet-içi takma kimlik (sealed-sender benzeri) —
  kural motoru yazarlığı doğrulamak zorunda olduğu için en zoru.

### 🟡 8. Kaybolan mesajın CİHAZDAKİ düz metni (§4al'in kalanı)
Sunucu tarafı §4al ile kapandı. Cihaz tarafında bir açık duruyor —
**§4al'den önce de vardı, onun ürünü değil:**

Ratchet tek yönlü olduğu için **gönderen** kendi mesajının düz metnini
`SecureStore`'da saklıyor (`e2ee_plain_<hesap>_<mesajId>`). Bu kayıt
**süre bilgisi taşımıyor** ve yerel bir süpürme yok; tek temizleyici,
istemcinin süre-dolma yolu (`forgetPlaintext`). O da mesajı akışta
görmeyi gerektiriyor.

Yani sohbet hiç açılmazsa — ya da mesaj 500'lük yerel önbellek
sınırından düşerse — **düz metin cihazda süresiz kalır.** C-07'nin
kapatılmamış son köşesi.

Önerilen çözüm (ek, geriye uyumlu):
* Düz metin yazılırken süresi de kaydedilsin
  (`e2ee_plainexp_<hesap>_<mesajId>` = ISO)
* Açılışta bir süpürme: süresi geçmiş kayıtlar için `forgetPlaintext`
* Eski kayıtlarda süre kaydı yok → bugünkü davranışta kalırlar
* `SecureStore`'a önekle okuma gerekir (şu an yalnızca
  `deleteByPrefix` var)

### 🟡 9. Şikâyetlerin SUNUCU tarafı (§4ao'nun kalanı)
İstemci tarafı §4ao'da kapandı: şikâyet + engelleme birlikte gidiyor,
ölü `messageId` kaldırıldı. Sunucuda kalanlar:

* **Hız sınırı yok.** Bir kullanıcı `reports`'a sınırsız yazabilir;
  kural yalnızca `create`e izin veriyor, sayaç yok. Cloud Function ya
  da kural düzeyi bir sayaç gerekir.
* **Şikâyet edilen hesaba işlem akışı yok.** `reports` hiçbir istemci
  tarafından okunmuyor (doğru) ama askıya alma/yasaklama tamamen elle
  konsol işi. Play'in içerik uygulaması beklentisi bu.
* ⚠️ **Dürüst sınır:** içerik tabanlı moderasyon bu mimaride
  YAPILAMAZ — mesajlar uçtan uca şifreli. Konsol bir mesaj kimliğini
  görse bile içeriğini okuyamaz. Gerçekçi kaldıraçlar şikâyet, engelle
  ve hesap düzeyinde işlemdir; Play başvurusunda bu böyle anlatılmalı.

## 🚦 PLAY SÜRÜM DURUMU (2026-09-11, 23:46)

✅ **v22 KAPALI TESTTE YAYINDA.**

| Alan | Durum |
|---|---|
| Paket | `app-release.aab` — 88,5 MB |
| Sürüm | versionName **1.0.11**, versionCode **22** |
| Kanal | Kapalı test – **Alpha** |
| Kullanıma sunuldu | 11 Eyl **23:46** — "Belirli test kullanıcıları tarafından kullanılabilir" |
| Kapsam | 177 ülke/bölge · 19.243 cihaz |
| Yeni yükleme | 21,8 MB (güncelleme 6,96 MB) |

**Sürüm geçmişi (kapalı test):** … → 20 (1.0.9, 11 Eyl 18:30) →
**22 (1.0.11, 11 Eyl 23:46)**

⚠️ **21 HİÇ YAYINLANMADI.** Paket derlendi ama kapalı teste çıkmadı;
araya v22 girdi. Yani testçiler **20'den doğrudan 22'ye** atladı ve bu
turdaki her şeyi (§4bf–§4bx) tek seferde gördü. Saha raporlarını
okurken kritik: *"mesaj çözülemiyor / resim açılmıyor / hikayede çift
tıklama"* şikâyetlerinin hepsi **v20 davranışıdır.**

### 🪤 SÜRÜM ADI ≠ PAKET SÜRÜMÜ

Play Console listelerinde görünen `21 (1.0.10)` bir **etiket**, paket
numarası DEĞİL. İlk yüklemede otomatik doluyor ve paket değiştirilince
**eski kalıyor**.

Bu tur bir kez yanlış alarma yol açtı: yayın özetinde `21 (1.0.10)`
görülüp "yanlış sürüm gitti" sanıldı. Gerçek paket, sürüm ayrıntı
sayfasındaki **"Sürüm kodları"** satırında yazıyor — orada **22**
görüldü.

> **Sonraki sürümde:** sürüm adını elle `22 (1.0.11)` gibi güncelle.
> Kozmetik ama teşhisi bozuyor.

### Yayın akışı — bu hesapta nasıl işliyor

1. Sürüm hazırla → paket + notlar → **İleri**
2. Önizle/onayla → **Kaydet** ← *yayınlamaz*, Yayın özetine gönderir
3. Yayın özeti → **"N değişikliği incelemeye gönder"**
4. Play **gönderim öncesi kontrolleri** çalıştırır (~10-15 dk), sonra
   incelemeye otomatik gider
5. **Yönetilen yayınlama KAPALI** → inceleme biter bitmez kendiliğinden
   kullanıma sunulur

⚠️ 2. adımdaki "Kaydet"in yayınladığını sanma; 3. adım ayrı.

### Mağaza dili — bilinmesi gereken

Mağaza girişinin **tek dili `en-US`**. Sürüm notlarına `<tr-TR>` bloğu
yazılırsa Play bunu **sessizce atar** (hata vermez!) ve `<en-US>` içine
yazılan Türkçe metni **makineyle İngilizceye çevirir**. Notlar bu yüzden
İngilizce yazılıyor. Türkçe not istiyorsan önce
**Mağaza girişleri → Çevirileri yönet**'ten Türkçe eklenmeli.

Not kutusunun biçimi: `<en-US>` … `</en-US>`, gövde **dil başına en çok
500 karakter**.

### ⚠️ Kaydedilmiş sürümün paketi değiştirilemez

"Sürüm ayrıntılarını düzenle" YALNIZCA **ad ve notu** değiştirir. Paketi
değiştirmek için yeni sürüm açmak gerekir.

---

## 🔴 AÇIK: UYGULAMAYI KALDIRMAK HESABI KAYBETTİRİYOR

**2026-09-11'de gerçek kullanıcıda yaşandı** — geliştirici kendi
telefonundan uygulamayı kaldırdı ve hesabın giriş bilgisi yok oldu.

### Mekanizma (kod okundu, varsayım değil)

`AuthService.register` — `lib/services/auth_service.dart:144`:

```dart
final accountPassword = EncryptionService.generateKey();  // RASTGELE
final emailCred = EmailAuthProvider.credential(
  email: '$uid@gizlichat.local',
  password: accountPassword,
);
await authUser.linkWithCredential(emailCred);
await _storage.write(key: _pwName, value: accountPassword);  // ← TEK KOPYA
```

* Hesap **anonim** Firebase kullanıcısı olarak açılır, sonra sentetik bir
  e-posta/parola bağlanır.
* Parola **rastgele üretilir**, kullanıcı onu hiç görmez.
* Tek kopyası cihazın güvenli deposundadır. Sunucuda, yedekte, hiçbir
  yerde başka kopyası YOK.
* `SavedAccount` (`multi_account_service.dart:82`) da yalnızca yerel:
  `uid`, `username`, `encryptionKey`, `password`.

**Sonuç:** uygulama kaldırılınca (ya da "uygulama verilerini temizle"
yapılınca) o hesaba bir daha girilemez. E2EE kimliği zaten gider — ama
asıl sorun o değil, **hesabın kendisi** erişilemez olur. Kullanıcı adı
da `usernames` dizininde rezerve kalır; yetim bir kayıt olur.

### Kullanıcı bunu ÖNCEDEN bilmiyor

Kaldırma öncesi uyarı yok. "Kurtarma anahtarı" özelliği var ama:
* çıkarması isteğe bağlı,
* kayıt akışında zorunlu tutulmuyor,
* kullanıcı neyi kaybedeceğini bilmeden kaldırıyor.

Numara istemeyen bir uygulamada bu, hesap kurtarmanın **tek** yolunun
kullanıcının kendi çıkardığı bir metin olması demek.

### Kurtarma yolları (öncelik sırasıyla)

1. **Kurtarma anahtarı varsa:** `RecoveryKeyService.restore(raw, parola)`
   → giriş geri gelir. ⚠️ E2EE KİMLİĞİ geri gelmez (`SavedAccount`
   kimlik özel anahtarını taşımıyor); kimlik yeniden üretilir.
2. **Yoksa — Admin SDK:** Firebase kullanıcısı sunucuda DURUYOR.
   `admin.auth().updateUser(uid, {password: '...'})` ile yeni parola
   atanır, sonra `{uid}@gizlichat.local` + o parolayla girilir.
   uid, `usernames/{ad}` kaydından bulunur. Servis hesabı anahtarı
   gerekir.
3. Hiçbiri yoksa hesap erişilemez; kullanıcı adı yetim kalır.

### Yapılması gerekenler (KOD DEĞİŞİKLİĞİ — henüz YAPILMADI)

1. **Kayıtta kurtarma anahtarını dayat** ya da en azından ilk açılışta
   ısrarla hatırlat ("bu olmadan telefonu kaybedersen hesabın gider").
2. **Ayarlarda kalıcı uyarı bandı:** kurtarma anahtarı hiç çıkarılmamışsa
   görünür kalsın.
3. Kurtarma anahtarına **E2EE kimlik özel anahtarını da koymayı**
   değerlendir. Ödünleşim: anahtarın çalınması kimliğin çalınması olur;
   bugün çalınması yalnızca hesaba girişi verir. Bilinçli karar gerekir.
4. `cleanupReleasedUsernames` ile yetim kullanıcı adlarının ne olacağı
   netleştirilmeli.

> ⚠️ Bu, "kullanıcının deneyimleyeceği her şey doğru mu" denetiminde
> ÇIKMADI çünkü denetim çalışan akışlara bakıyordu. Arıza, kullanıcının
> uygulamayı SİLMESİYLE ortaya çıkan bir yol — test edilen bir yol değil.

---

## 🧩 KURAL–İSTEMCİ UYUŞMAZLIĞI TURU (2026-09-11) — §4bm – §4bq

Üç arıza, **ikisi aynı kökten**: güvenlik kuralı bir şey şart koşuyor,
istemci onu sağlamıyor. İkisi de kural değişikliğinin yan etkisi.

### §4bm — DAVET KODU: eksik `ownerUid`

Grup/kanal kurarken *"Davet kodu işlenemedi"*. Kural:

```
allow create: if signedIn() && !exists(...)
  && request.resource.data.ownerUid == request.auth.uid;
```

İstemci `{'chatId': chatId}` yazıyordu — `ownerUid` yok, eşitlik
tutmuyor, `permission-denied`. Kural doğruydu (sahibi olmayan kodu kimse
silemesin); eksik olan istemciydi. `ownerUid` aynı zamanda
`deleteInviteCode`'un şartı: onsuz yazılmış eski kodlar YETİM kalır.

### §4bn — KANALA KATILMA: okuma izni olmadan `tx.get`

*"Bu kanaldan yasaklandınız"* — kimse yasaklı değildi.

`addMemberToArray` işlem içinde önce `tx.get(ref)` yapıyor. Kural:

```
// TEK DOKÜMAN OKUMA: yalnızca üyeler.
allow get: if signedIn() && request.auth.uid in resource.data.memberIds;
```

Üye olmayan okuyamaz → istek **yazmaya gelmeden** reddedilir. Ekran her
`permission-denied`'ı "yasaklısın" diye gösterdiği için hata
YANILTICIYDI.

> Bu, kanal keşfinin `/channels` dizinine taşınmasıyla `allow get`ten
> `type == 'channel'` istisnasının kaldırılmasının yan etkisi. Okuma
> kısıtı bilinçli, o yüzden kural GEVŞETİLMEDİ — istemci okumasız hâle
> getirildi (`arrayUnion` + `increment`, ikisi de `isSelfJoin()`'in
> izin verdiği alanlar).

**Mesaj da dürüstleştirildi:** istemci "yasaklı" ile "zaten üye"yi
ayırt edemez; kesin olmayan suçlama yerine "Kanala katılınamadı".

### §4bo — ÇALMA SESİ: ton kodda üretilir

"diit diit" için depoya ses dosyası KONMADI: içeriğini okuyarak
denetleyemeyeceğim bir ikili dosya eklemek yerine WAV çalışma anında
sentezleniyor (8 kHz, 440 Hz, iki bip + sessizlik, döngü). Paket
büyümüyor, lisans sorusu doğmuyor.

⚠️ **Yalnızca ARAYAN tarafta.** Gelen aramada karşı taraf sistem zilini
duyar; üstüne çalmak iki sesin çakışması olurdu.

### §4bp — YANIT ALINTISI ARTIK DOKUNULABİLİR

Alıntı neye yanıt verildiğini gösteriyor ama oraya GÖTÜRMÜYORDU.
Dokununca hedefe kayıyor. Mesaj sayfalama yüzünden yüklü değilse
sessiz kalmak yerine nedeni söyleniyor.

### §4bq — GRUP ARAMASI: MESH (kullanıcı kararı)

Çok taraflı WebRTC'de iki yol vardı: **mesh** (sunucu yok, her katılımcı
herkese ayrı bağlantı kurar) ve **SFU** (ölçeklenir ama medya bir
sunucudan geçer). Kullanıcı **mesh** dedi. Bedeli açıkça yazılı:
N kişide her istemci N-1 akış YÜKLER, bu yüzden
`GroupCallService.maksKatilimci = 5` ve dolunca **sessizce bozulmak
yerine açıkça reddediliyor**.

Kazancı da açık: medya hiçbir sunucudan geçmiyor — uçtan uca şifreleme
birebir aramadaki kadar güçlü kalıyor.

#### Altyapının ZATEN hazır olan kısmı

Sinyalleşme şeması §4t'de N kişiye göre yazılmıştı:
`participants` yetkinin tek kaynağı, `candidates` `from`/`to` taşıyor ve
kural adayı yalnızca o ikisine açıyor (yani **A, B↔C'nin IP adreslerini
göremez**). Eksik olan tek şey offer/answer'ın çağrı belgesinde **TEK
alan** olarak durmasıydı — şemayı iki kişiye çiviliyordu. Yerine adresli
bir `sdp` alt koleksiyonu geldi; okuma izni adaylarla birebir aynı
sıkılıkta, çünkü **SDP de IP taşıyabilir** (trickle olmayan istemciler
adayları SDP'ye gömer).

#### İKİ LİSTE — karıştırılırsa arama çöker

| Alan | Anlamı | Kim kullanıyor |
|---|---|---|
| `participants` | çağrının TARAFLARI = grubun tüm üyeleri | yetki (`callParty()`) + **gelen arama sorgusu** |
| `joinedIds` | KABUL EDİP bağlananlar | mesh kime eş bağlantı açacak |

`participants` mesh listesi sayılsaydı arama başlar başlamaz **henüz
cevap vermemiş herkese** bağlantı açılırdı. Ayrı tutulduğu için gelen
arama yolu (`where('participants', arrayContains: me)`) **hiç
değiştirilmeden** grup aramasında da çalışıyor: telefonlar çalıyor.

#### Çakışma (glare) — pazarlık YOK

İki taraf aynı anda offer üretirse bağlantı kurulmaz. Deterministik
kural: **uid'i küçük olan** teklif eder. İki istemci de aynı sonuca
varır, mesaj alışverişi gerekmez. (`teklifiBenVeririm`, tur testiyle
kilitli: her çiftte TAM BİR taraf teklif verir.)

#### 🧟 ZOMBİ ARAMA — sonsuza dek çalan grup

Grup araması konuşma boyunca `ringing` kalır ki geç katılan onu
bulabilsin. Son ayrılan `ended` yazar — **ama uygulama öldürülürse o
yazma hiç olmaz.** Süzgeç olmasa iki yer birden bozulurdu: yeni arama
başlatan ölü aramaya "katılır" ve kimseyi bulamaz; her üyenin cihazı,
uygulama her açıldığında gelen arama ekranını açar.

Ölçüt (`grupCagrisiCanli`) ortak şema dosyasında durur çünkü **iki yer
de aynı kararı vermek zorunda**: `ringing` + bağlı en az bir kişi +
4 saatten yeni.

#### 🔔 `participants` = ÇALACAK TELEFONLAR (kural boşluğu kapatıldı)

Gelen arama sorgusu bu diziye baktığı için o, doğrudan "kimin telefonu
çalsın" listesidir. Serbest bırakılsaydı **herkes, hiç tanımadığı
kullanıcıların telefonunu çaldırabilirdi** — üstelik engelleme de
kurtarmazdı: grup çağrısında `calleeId` yok, yani `notBlockedBy` hiç
uygulanmıyor.

Kural artık grup çağrısında diziyi **grubun üyeleriyle** sınırlıyor ve
çağrıyı açanın da o grubun üyesi olmasını şart koşuyor:

```
allow create: if signedIn()
  && request.resource.data.callerId == request.auth.uid
  && request.auth.uid in request.resource.data.get('participants', [...])
  && (request.resource.data.get('isGroup', false) == true
      ? gecerliGrupCagrisi()
      : (!('calleeId' in request.resource.data)
         || notBlockedBy(request.resource.data.calleeId)));
```

⚠️ `notBlockedBy(calleeId)` **eksik alanı okumaya kalkarsa** kural
DEĞERLENDİRME HATASI verir ve istek reddedilir — grup araması hiç
başlatılamazdı. §4at'nin birebir aynısı (eksik alan → hata → RED).
Aynı tuzak `groupChatId` boşken `get()` çağırmakta da var; ternary
kısa devre yapıyor.

#### 🪤 `list` KURALI BELGEYE DEĞİL **SORGUYA** BAKAR

Bu tur sırasında yakalandı ve **üretime gitseydi grup araması hiç
çalışmayacaktı.** Kural şuydu:

```
allow list: if callParty();   // callParty → resource.data.participants
```

`resource.data`ya baktığı için "dönen her belge tek tek denetlenir"
sanılıyor. Gerçekte Firestore, sorgunun **yalnızca izinli belgeleri
döndüreceğini SORGU KISITLARINDAN kanıtlamak** zorunda; kanıtlayamazsa
sorgunun TAMAMINI reddeder.

Emülatörde ölçüldü:

| Sorgu | Sonuç |
|---|---|
| `groupChatId == x` + `status == ringing` | ❌ **reddedildi** — kullanıcı çağrının TARAFI olsa bile |
| aynısı + `participants array-contains ben` | ✅ geçti |

Yani `_canliCagriyiBul` içindeki üçüncü kısıt **süs değil, iznin
kendisi**. Silinirse kullanıcı "Grup araması başlatılamadı" görür ve
hiçbir birim testi bunu göstermez.

⚠️ Aynı sınıf, gelen aramanın iki kez kırılmasının da kökü (§4m, §4u):
kural/sorgu uyuşmazlığı **hata vermeden** boş sonuç üretir.

Kilitlendi: `test/rules/firestore.rules.test.js` → *"katılımcı kısıtı
OLMADAN sorgu REDDEDİLİR"* (+ aynı tuzağın sinyalleşme dinleyicilerindeki
hâli: adresli SDP/ICE sorguları da `to == ben` kısıtı olmadan reddedilir).

📇 **İNDEKS:** üçüncü kısıt `array-contains` + iki eşitlik demek;
`firestore.indexes.json`a bileşik indeks eklendi ve dağıtıldı. Emülatör
indeks aramaz — eksikliği yalnızca üretimde görülürdü.

#### Reddetmek ≠ aramayı bitirmek

Birebir aramada "reddet" çağrının durumunu `rejected` yapar. Grupta bu,
**tek kişinin reddi konuşan herkesin aramasını kapatmak** demekti.
Grup aramasında reddetmek yalnızca ekranı kapatır; çağrı sürer. Aynı
tuzak engellenen arayan yolunda da vardı (`home_shell`): engel artık
grup çağrısında yalnızca "ekranım açılmasın" anlamına geliyor.

#### Kabul edilen arama BİTMİŞSE yeni arama AÇILMAZ

"Kabul et"e basıldığında çağrı çoktan bitmiş olabilir. İlk hâlde kod bu
durumda yeni bir arama açıyordu: kullanıcı farkında olmadan ARAYAN olur
ve **tüm grubun telefonu çalardı** — yaptığı tek şey kabul etmekti.
Artık `arama_bitti` hatası verilip "Bu grup araması sona ermiş" deniyor.

Aynı turda kapatılan iki sessiz arıza daha:

* **EŞ KURMA YARIŞI.** `_esKur` iki yerden çağrılıyor (katılımcı
  dinleyicisi + gelen SDP). `createPeerConnection` beklenirken ikinci
  çağrı gelirse aynı kişiye İKİ bağlantı kurulur, biri sızar ve karşı
  tarafa iki teklif gider — bağlantı hiç kurulmaz. `_kuruluyor` kümesi
  ile tekilleştirildi.
* **ÖKSÜZ ARAMA.** Ekran, arama kurulurken kapatılırsa `dispose`ın
  `ayril()`i daha ortada bir şey yokken çalışır; kurulum bitince arama
  sahipsiz kalır ve grup "konuşuluyor" görünmeye devam ederdi.
  Kurulumdan sonra `mounted` denetimi eklendi.

#### Kanalda grup araması YOK

Ana ekran kanalı da `isGroup: true` ile açıyor. Kanal yayın içindir ve
üye sayısı mesh'in sınırını kat kat aşar; düğme yalnızca **gerçek
gruplarda** görünüyor (sohbet dokümanının `type` alanına bakılarak).

#### Kapılar

`flutter analyze` temiz · Dart testleri **455** (14 yeni) · kural
testleri **138** (15 yeni). Yeni kural testlerinin kapsadığı:
üye olmayan gruba arama açamaz · üye, grupta olmayan birinin telefonunu
çaldıramaz · `groupChatId` boşken çağrı açılamaz · yabancı
`joinedIds`'e giremez · birebir engel denetimi hâlâ çalışıyor ·
**katılımcı kısıtı olmadan keşif sorgusu reddedilir** · adresli SDP/ICE
dinleyicileri `to == ben` kısıtıyla geçer, kısıtsız döküm reddedilir.

✅ **KURALLAR VE İNDEKSLER DAĞITILDI** (2026-09-11, `gizlichat-f2a99`):
`sdp` alt koleksiyonu, grup çağrısı `create` dalı ve `calls` bileşik
indeksi artık üretimde. Dağıtılmadan grup araması çalışmazdı.

---

---

## ♻️ KAYBI KURTARMA (2026-09-20) — §4cl

### §4cl — YENİDEN GÖNDERİM İSTEĞİ + GÖRÜNÜR ONARIM

§4ck iki eksik saptamıştı; ikisi de kapatıldı.

#### 1. Yeniden gönderim isteği (protokol)

```
resendRequests/{chatId}/req/{messageId} = { from, to, messageId, ts }
```

Alıcı bir mesajı kalıcı olarak çözemeyince istek yazar. Gönderen bunu
**uygulama genelinde tek koleksiyon-grubu akışıyla** dinler, kendi düz
metnini yerel kasadan okur (`E2EESessionService.getPlaintext` — gönderim
anında zaten saklanıyordu), GÜNCEL oturumla yeniden şifreler ve isteği
siler.

#### 🎯 YENİ MESAJ DEĞİL, ÖZGÜN BELGE GÜNCELLENİYOR

Yeni mesaj göndermek kaybolan metni sohbetin SONUNA atardı; "çözülemedi"
balonu olduğu yerde kalır, kullanıcı iki kopya görürdü. Özgün belgeyi
güncellemek balonu **yerinde** gerçek metne çevirir.

✅ Bunun için mesaj kuralında **değişiklik gerekmedi**: `messages`
güncellemesi zaten gönderene açıktı
(`resource.data.senderId == request.auth.uid`).

⚠️ `isEdited` İŞARETLENMEZ — bu bir düzenleme değil, aynı içeriğin
yeniden şifrelenmesi. "Düzenlendi" etiketi yanlış bilgi olurdu.

#### 🪤 İSTEK MESAJ BAŞINA, EL SIKIŞMA SOHBET BAŞINA

Kolay kaçırılacak yer: §4cc'nin `_sifirlanan` kapısı **sohbet başına bir
kez** çalışır. Yeniden gönderim isteği o kapıya bağlansaydı yalnızca
İLK kayıp mesaj istenirdi — testçi B'nin ikinci mesajı yine kaybolurdu,
yani düzeltme şikâyetin yarısını çözerdi. İstek ayrı bir küme
(`_istenen`) ile mesaj başına yazılıyor.

#### 2. Onarım artık GÖRÜNÜYOR

İki ayrı işaret, iki ayrı metin:

| İşaret | Ne demek |
|---|---|
| `\u0000E2EE_LOST` | kalıcı gitti (grup, kendine not, yeniden kurulum) |
| `\u0000E2EE_RETRY` | tekrarı istendi, yolda |

⚠️ Tek metinle geçiştirmek vakaların yarısında yalan olurdu. §4ck'nın
kendisi bunun kanıtı: çalışan bir mekanizma, görünmediği için "bozuk"
diye raporlandı.

⚠️ İstek YAZILAMAZSA "tekrarı istendi" DENMEZ (`iste` bool döner).
Gelmeyecek bir şey için kullanıcıyı beklet­mek, hiç söylememekten kötü.

#### 🪤 İŞARET DEĞERİ: `E2EE_LOST_RETRY` DEĞİL, `E2EE_RETRY`

İlk yazılan değer `E2EE_LOST_RETRY`ydi ve **kendi testim yakaladı**:
o değer `E2EE_LOST`un ÖNEKİ. Bugün eşitlikle karşılaştırılıyor ama
ileride biri `startsWith` kullanırsa iki durum sessizce karışırdı.

#### 🪤 HAM NUL YAZILDI, DÜZELTİLDİ

Sabit eklenirken kaynağa **düz NUL baytı** yazıldı; dosya ikili sayılır
ve `grep` onu bulamaz hale gelirdi. `encryption_datasource.dart`
bunu zaten uyarıyordu. Kaçış dizisine çevrildi.

#### Sınırı

Gönderen düz metni kaybettiyse (uygulamayı silip kurmuşsa) kurtarma
YOKTUR; istek sessizce silinir ve alıcı kalıcı kayıp metnini görür.

#### Kapılar ve dağıtım

Kural testleri **153 → 166** (13 yeni), Dart **629 → 635**.
✅ **DAĞITILDI** (2026-09-20, `gizlichat-f2a99`): `resendRequests`
kuralları + `req.to` alan geçersiz kılma üretimde. Çıktıda §4cc'nin
öğrettiği **"released rules"** satırı doğrulandı.

⚠️ Kural ek; sahadaki v23 bu istemci koduna sahip DEĞİL. Özellik
**v24 ile** çalışmaya başlar.

---

## 🔍 SAHA TEŞHİSİ: §4cc ÇALIŞTI, KAYIP SÜRÜYOR (2026-09-20) — §4ck

### §4ck — "2 MESAJ ÇÖZÜLEMEDİ, SONRA DÜZELDİ"

Kullanıcı raporu (SECRET ↔ testçi B, 20 Eyl):

> *"SECRET selam yazıyor, testçi B 2 mesaj atıyor ama ikisi de
> çözülemedi diyor. Sonra SECRET 1 mesaj daha atıyor, sonra sohbet
> düzeliyor."*

Bu, §4cc'nin **tam olarak önlemesi gereken** senaryo gibi okunuyor.
Değilmiş.

#### 🔬 KANIT — Firestore'dan okundu, çıkarım değil

`handshakes` koleksiyonunda 4 sohbet, 5 belge var; yani sessiz el
sıkışma sahada **çalışıyor**. İlgili sohbette:

| Sohbet | Yayımlayan | ts |
|---|---|---|
| `<sohbet-kimliği>` (SECRET↔B) | SECRET | **2026-09-20T14:08:18Z** |

⚠️ **Zamanlama kanıtı koddan geliyor, damgadan değil:**
`RehandshakeService.yayinla`, YALNIZCA çözme başarısız olan yoldan
çağrılıyor (`encryption_datasource_impl.dart`) — gönderme yolundan
DEĞİL. Yani 14:08, testçi B'nin mesajlarının çözülemediği andır ve
SECRET'in 3. mesajından ÖNCEdir.

Ayrıca o sohbette **tek** belge var: testçi B karşı-yayım yapmamış,
yani onun tarafı bozulmamış — sessizce onarılmış. Çakışma (glare)
yaşanmamış.

#### ✅ Sonuç: mekanizma çalıştı, rapor YANLIŞ OKUMA

```
1. SECRET "selam"   → gider
2. testçi B 2 mesaj  → SECRET çözemez
                    → oturumu sıfırlar + el sıkışmayı YAYIMLAR (14:08)
                    → testçi B'nin istemcisi sessizce onarılır
3. SECRET 1 mesaj   → yeni oturumla gider
4. Sohbet düzgün
```

Sohbetin "SECRET yazınca düzelmesi" arıza değil: onarım 14:08'de
olmuştu, ama **14:08 ile 3. mesaj arasında kimse bir şey göndermediği
için görünür olmadı.** Fark ancak testçi B önce yazsaydı ortaya
çıkardı — eski sürümde onun mesajı da çözülemezdi.

#### 🔴 AMA İKİ GERÇEK EKSİK VAR

Rapor yanlış okumaydı; **şikâyet haklıydı.** İki mesaj kalıcı kayboldu.

**1. Yeniden gönderim isteği YOK.**
§4cc oturumu onarıyor, **içeriği kurtarmıyor.** Kod bunu zaten kabul
ediyor: *"Mesajı KURTARMAZ — sohbetin bundan SONRASINI kurtarır."*
testçi B'nin istemcisi, gönderdiği iki mesajın okunamadığını HİÇ
öğrenmiyor. Signal bunu retry-receipt ile çözer: alıcı çözemeyince
göndericiden o mesajı yeni oturumla tekrar ister.

**2. Onarım GÖRÜNMÜYOR.**
Ekranda iki "çözülemedi" balonu duruyor ve kullanıcının oturumun
düzeldiğini anlamasının hiçbir yolu yok. Bu yüzden "sohbet bozuk
kaldı, ben yazınca düzeldi" diye okunuyor — raporun kendisi bunun
kanıtı. Algı sorunu değil, **eksik geri bildirim.**

> 📌 Ders: *bir onarımın çalıştığını kullanıcıya söylemiyorsan,
> çalışmadığını varsayar ve sana öyle raporlar.* §4bv ile aynı aile
> (çözülemeyen medya "bozuk resim" görünüyordu).

---

## 📖 AÇIK KAYNAK HAZIRLIĞI (2026-09-20) — §4cj

### §4cj — İDDİAYI KANITA BAĞLAMAK

Kullanıcı: *"İnsanların uygulamanın açık kaynak olduğunu bilmesini
istiyorum."* İstek meşru ama o gün proje açık kaynak **değildi**:
`LICENSE` yok, uzak depo yok, uygulamada ibare yok.

> ⚠️ Sıra önemli: **önce yayımla, sonra söyle.** Gizlilik iddiası
> taşıyan bir uygulamada kodu açmadan "açık kaynak" yazmak, güven
> kazandırmaz — biri kontrol etmek isteyip hiçbir şey bulamayınca en
> çok o iddia zarar görür.

#### ✅ Sır taraması — TEMİZ

Yayımlamadan önceki en kritik iş (bir kez yayımlanırsa geçmişten silmek
işe yaramaz). 14 kayıtlık geçmişin tamamı tarandı:

| Aranan | Sonuç |
|---|---|
| Giphy anahtarı | **hiç git'e girmemiş** (`git log -S` boş) |
| `.jks` / `key.properties` | yok — yalnızca `key.properties.ORNEK` |
| Hizmet hesabı JSON, `.env`, TURN parolası | yok |
| `BEGIN * PRIVATE KEY`, `ghp_`, `xoxb-`, `AKIA`, `sk_live` | yok |
| `node_modules`, `firestore-debug.log` | izlenmiyor |

⚠️ Tek "bulgu" `lib/firebase_options.dart` + `google-services.json`
içindeki Firebase API anahtarı — **tasarım gereği açık**, her APK'nın
içinde gidiyor ve güvenlik ondan değil Firestore kurallarından geliyor.
Yine de Google Cloud Console'dan **Android uygulaması + SHA-1** ile
kısıtlanmalı (kota kötüye kullanımına karşı).

#### 🔒 İDDİA KODA BAĞLANDI — unutkanlığa değil

`lib/core/proje_kimligi.dart`:

```dart
const String depoAdresi = '';          // yayımlanana kadar BOŞ
bool get acikKaynakGosterilebilir => depoAdresi.trim().isNotEmpty;
```

Ayarlar → Hakkında altındaki "Açık kaynak" satırı **yalnızca adres
doluysa çiziliyor.** Yani yanlış beyan kazara yayına çıkamaz; iddia
ancak gidip bakılabilecek bir adres varsa ortaya çıkar.

Aynı bağ ters yönde de çalışır: depo bir gün özel yapılırsa satır
kendiliğinden kaybolur.

#### Lisans: AGPL-3.0 (kullanıcı kararı)

Kanonik metin `gnu.org`'dan indirildi (661 satır, 34.523 bayt) —
ezberden yazmak hata riski taşırdı. Gerekçe: değiştirilmiş bir sürümü
dağıtan kaynağını açmak zorunda; kodun kapatılıp yeniden paketlenememesi
gizlilik iddiasının kalıcı olmasını sağlıyor.

#### Kapı

`proje_kimligi_test.dart` üç şeyi birden ölçüyor:
1. adres yoksa iddia gösterilmez (gösterim kararı başka bir şeye
   bağlanmışsa düşer),
2. `LICENSE` var ve koddaki `lisansAdi` ile **aynı lisansı** söylüyor
   (ayrışması sessiz bir yanlış beyan olurdu),
3. lisans adı 16 dilin metnine **gömülü değil**, `{lisans}` yer
   tutucusuyla geliyor — lisans değişirse tek yerden değişsin ve bir
   dil unutulup yanlış lisans göstermesin.

#### 🔴 KALAN ADIM — YALNIZCA SENDE

1. Depoyu yayımla (GitHub vb.) — **ben yapmadım**, geri alınamaz ve
   senin kararın.
2. `depoAdresi`ni doldur → satır kendiliğinden görünür.
3. Giphy anahtarını **önce** döndür (`SIR_DONDURME.md`): depoda değil
   ama sahadaki pakette var; yayımlamadan önce döndürmek en temizi.
4. Firebase API anahtarını Cloud Console'dan kısıtla.

### Kapılar

`flutter analyze` temiz · Dart **629** (623 → 629) · `dart format` temiz

---

## 🔎 v23 SAHA KONTROLÜ (2026-09-20) — §4ci

### §4ci — "ÇÖKME YOK" NE KADAR KANIT?

v23 dört gündür sahada (16 Eyl 11:08). Play Console'da bakılanlar:

| Nereye | Ne çıktı |
|---|---|
| Android vitals → Kilitlenmeler ve ANR'ler | 28 gün düz **0**, tablo *"Sonuç yok"* |
| Test geri bildirimleri | En yenisi **11 Eyl** — v23'ten sonra **yeni yok** |
| Kanal durumu | Etkin, son sürüm 23 (1.0.12), 177 ülke |

#### 🪤 Crashlytics'e bakmak YANILTICI OLURDU

`crashReportingConsent` **varsayılan `false`** (`privacy_settings.dart`)
ve telemetri yalnızca kullanıcı ayarlardan açarsa başlatılıyor
(`main.dart`, ertelenmiş blok). Gizlilik açısından doğru tercih, ama
sonucu şu: **Crashlytics'in sessizliği hiçbir şey kanıtlamaz** —
testçilerin çoğu o ayarı açmamıştır.

Bu yüzden Android vitals'a bakıldı: onun verisi Google Play
Hizmetleri'nden gelir ve uygulamanın kendi onay bayrağına BAKMAZ.

> 📌 Sınıfın aynısı: *ölçmediğin bir şeyin sessizliğini "iyi haber"
> sanmak.* §4am ve §4bw ile aynı aile.

#### ⚠️ YİNE DE ZAYIF KANIT — neden

* Android vitals da yalnızca **Google'la tanılama paylaşımını açmış**
  cihazlardan veri toplar; 12–21 kişilik bir kitlede bu birkaç cihaz
  demek olabilir.
* **Kaç testçinin v23'e güncellediği ölçülmedi.** Güncellemeyen bir
  testçi çökmez — v22 çalıştırıyordur.
* Çökmeyen ama BOZAN hatalar buraya hiç düşmez. §4cc (sessiz yeniden
  el sıkışma) tam olarak bu tür: başarısız olursa uygulama çökmez,
  **mesaj okunamaz** olur. Vitals bunu göremez.

#### ✅ ASIL DOĞRULAMA HÂLÂ AÇIK

§4cc'nin iki telefonlu senaryosu (bu dosyada "AÇIK UÇLAR" md. 2)
çalıştırılmadı. Sahadan sessizlik gelmesi onun yerini tutmaz;
testçiye **sorulması** gerekiyor:

> *"Daha önce 'çözülemedi' yazan bir sohbet, sen bir şey yazmadan
> kendi kendine düzeldi mi?"*

---

## 📞 GRUP ARAMASI ROZETİ (2026-09-20) — §4ch

### §4ch — GRUP ARAMASINDAN DA IP AÇIKLAMASI KALDIRILDI

§4cf birebir aramada açıklamayı kaldırmış, grup ekranını **bilerek
dışarıda** bırakıp kullanıcıya sormuştu. Cevap geldi: grup da aynı
olsun.

Artık iki arama ekranında da rozet yalnızca etiket ("Doğrudan
bağlantı" / "Aktarmalı bağlantı"); bilgi simgesi ve dokunmalı diyalog
yok.

#### 🔴 Bu, §4cf'den DAHA ağır bir kayıp

Mesh'te her katılımcı diğer **herkese** doğrudan bağlanıyor. Birebir
aramada IP tek kişiye açılırken grupta **aramadaki herkese** açılıyor
(§4br bu yüzden yazılmıştı). TURN kurulana kadar (§3 A) bu gerçek ve
sürekli.

Metinler (`group_call_ip_*_detail`) 16 dilde **silinmedi**; geri
getirmek `detay:` argümanını eklemekten ibaret.

#### ⚠️ `ip_disclosure_test.dart` ARTIK HİÇBİR EKRANI ÖLÇMÜYOR

Bu turdan sonra kapının 113 testinin tamamı — birebir ve grup —
yalnızca **sözlükte duran** metinleri ölçüyor. Yeşil olması artık
"kullanıcı IP'sinin paylaşıldığını öğreniyor" DEMEK DEĞİL; yalnızca
"geri getirilmek istenirse metinler 16 dilde hazır" demek.

Bu, §4am'de yakalanan sınıfın ta kendisi (yeşil ama hiçbir şey
kanıtlamayan kapı), bu yüzden test dosyasının başına büyük harflerle
yazıldı. **Silinmedi**, çünkü silmek metinleri de götürürdü.

> 📌 Asıl çözüm rozet metni değil: **TURN kurulursa** aramalar aktarma
> üzerinden gider ve IP hiç paylaşılmaz. Ödünleşim kökten kalkar.

#### Kapılar

`flutter analyze` temiz · Dart **623** · `dart format` temiz

---

## 📤 v23 YÜKLEME TURU (2026-09-16) — §4cg

### §4cg — 🪤 "SÜRÜM KODU DAHA ÖNCE KULLANILDI"

Yükleme üç kez denendi ve ikisi başarısız göründü. Gerçek sebep
sonunda Play'in kendi hata metninden çıktı:

> **"23 sürüm kodu daha önce kullanıldı. Başka bir sürüm kodunu
> deneyin."**

#### Ne olmuştu

İlk yükleme **başarılıydı** (16 Eyl 07:27) ama paket **sürüme
bağlanmadı**; Play onu *kütüphaneye* aldı. Sürüm hazırlama sayfası
boş göründüğü için "yükleme olmadı" sanıldı ve aynı dosya tekrar
yüklendi — bu kez Play reddetti, çünkü **bir sürüm kodu Play'de bir
kez kullanılır ve asla geri gelmez** (paket hiçbir sürüme bağlanmamış
olsa bile).

#### 🔴 Doğru çözüm: YENİDEN DERLEME DEĞİL, "Kitaplıktan ekle"

İlk refleks `pubspec`'i `+24`'e çıkarıp yeniden derlemekti. **Gereksiz
olurdu ve yanlıştı:** paket zaten Play'deydi. Doğru yol:

```
Sürüm hazırla → Uygulama paketleri → "Kitaplıktan ekle" → 23'ü seç
```

⚠️ Sürüm kodunu bump etmek burada sessiz bir maliyet yaratırdı: 23
sonsuza dek "kullanılmış ama hiç yayınlanmamış" olarak kalır ve
sürüm geçmişinde §4by'deki v21 gibi bir boşluk daha açılırdı.

#### 🪤 Teşhisi zorlaştıran üç şey

1. **"Dahil olmayanlar" başlığı yanıltıyor.** Sürüm sayfasındaki
   tabloda `22 (1.0.11)` görünüyordu ve bu "yüklenen paket" sanıldı.
   Oysa o bölüm *önceki sürümden gelen ve bu sürüme DAHİL EDİLMEYECEK*
   paketleri listeler. Dahil edilen paketler ayrı bir tabloda.
2. **Hata metni katlanmış durumdaydı.** Reddedilen dosya kutuda
   kırmızı bir satır olarak duruyordu ama sayfa dar pencerede
   kaydırılmadan görünmüyordu.
3. **Konsol o gün ayrıca `637A51D4` hatası veriyordu** ve kapalı test
   sayfası bir kez tamamen boş yüklendi — bu da "yükleme düştü"
   izlenimini güçlendirdi.

#### ✅ Hangi derlemenin yüklendiği NASIL doğrulandı

02:23'teki **eski** paket de `1.0.12+23`'tü ve arayüz düzeltmelerini
içermiyordu — yani "kod 23" tek başına yeterli kanıt değildi.

Diskteki tüm `.aab` dosyaları tarandı: yalnızca iki kopya vardı
(proje çıktısı ve `Downloads`), **SHA-256'ları birebir aynı**
(`a67c132b…`) ve ikisi de 03:15 derlemesi. Eski paket yerine yazılmış,
başka kopyası kalmamış. Play'e 07:27'de giren dosya bu olabilirdi
yalnızca.

> 📌 Ders: **paket kimliği tarih/boyutla değil, ÖZETLE doğrulanır.**
> Aynı sürüm kodunu taşıyan iki farklı derleme olabilir.

### Sürüm notu

`scripts/surum_notlari.json` (en-US, 483/500) `<en-US>…</en-US>`
bloğuyla yapıştırıldı; §4cd–§4ce düzeltmeleri de listede.

---

## 🖥️ ARAYÜZ OKUNABİLİRLİĞİ TURU (2026-09-16) — §4cd – §4cf

Kullanıcı üç şey bildirdi; ikisi aynı sınıf (**metin sığmıyor, kırpma
bilgiyi tamamen yok ediyor**), üçüncüsü bilinçli bir kaldırma. Ayrıca
birincisini incelerken **bildirilmemiş bir hata** çıktı (§4cd/2).

### §4cd — SOHBET BAŞLIĞINDA "SON GÖRÜLME" OKUNMUYORDU

Şikâyet: *"'Son görülme....' yazıyor ama o metin sığmadığından tamamen
okunmuyor. İnsanlar son görülme aktifliğini göremiyor."*

**İki ayrı sebep vardı ve ikisi de sessizdi.**

#### 1. Genişlik bütçesi — bu bir ARİTMETİK hatası, çizim hatası değil

Başlık çubuğundaki her sabit genişlikli düğme, başlığın ve alt satırın
payından düşüyor. 360dp'lik bir telefonda:

```
dolgu 16 + geri 48 + avatar 38 + boşluk 12 + 4×48 düğme = 306
→ başlık + alt satıra kalan:                              54 dp
```

54dp'ye "son görülme 14:32" sığmaz. `TextOverflow.ellipsis` devreye
girip **bilginin tamamını** yutuyordu: kullanıcı "Son görülme…" görüp
saati hiç göremiyordu — yani satır hiçbir işe yaramıyordu.

**Düzeltme üç parçalı:**

* **Arama düğmesi taşma menüsüne alındı.** Dördüncü düğme bütçeyi
  bitiriyordu; WhatsApp ve Telegram da sohbet içi aramayı menüde tutar.
* **Kalan düğmeler sıkıştırıldı** (`VisualDensity`, 48 → 40dp).
  ⚠️ `PopupMenuButton` `visualDensity` almaz ama `style`ını içteki
  `IconButton`a geçirir; sıkıştırma oraya böyle ulaşıyor.
* **Kırpma yerine küçültme** (`FittedBox(scaleDown)`). Uzun dillerde
  hiçbir bütçe yetmez — ama küçülen metin okunur, kırpılan okunmaz.

Pay 54 → **134dp**. Ayrıca "son görülme dün 14:32" biçimindeki ön ek
kaldırıldı ("dün 14:32"); ismin altında zaten son görülme olarak okunur
ve Almanca/Yunanca/Portekizcede payı aşan biçim buydu. **Tarih
biçiminde ön ek KALDI** — yalnız "28.02" ne olduğu belirsiz kalırdı.

#### 2. 🐞 BİLDİRİLMEMİŞ HATA: "yazıyor" satırı yanlış anahtarı okuyordu

`presence.dart`, "yazıyor" için `typing_indicator` anahtarını
okuyordu — **o bir AYAR BAŞLIĞIDIR** ("Yazıyor göstergesi" / "Typing
indicator", `typing_indicator_sub` ile birlikte ayarlar ekranında
kullanılıyor). Sohbet başlığında şu yazıyordu:

| Dil | Görünen | Olması gereken |
|---|---|---|
| tr | `Yazıyor göstergesi...` | `yazıyor...` |
| en | `Typing indicator...` | `typing...` |

**Hiçbir kapı düşmedi:** anahtar 16 dilde tamdı, metin boş değildi,
analyzer temizdi. Yalnızca YANLIŞ anahtardı. Yeni anahtar
`presence_typing` 16 dile eklendi.

Yanında ikinci bir hata: çağıran taraf stili **Türkçe dizeyle**
karşılaştırarak seçiyordu.

```dart
final isTyping = text == 'yazıyor...';       // HİÇ tutmuyordu (1 yüzünden)
color: isTyping || text == 'çevrimiçi' ...   // yalnızca Türkçede tutar
```

Yani "yazıyor" ve "çevrimiçi" vurgusu 15 dilde sessizce kayboluyordu —
ve Türkçede de kayıptı, çünkü metin zaten eşleşmiyordu. `presenceText`
artık `PresenceLabel(text, kind)` döndürüyor; **vurgu metinden değil,
veriden geliyor.**

> 📌 Sınıf tanıdık: *çalışmayan bir şey hata vermiyor, o yüzden
> görünmüyor.* §4ai (çeviri) ve §4ah (yutulan hata) ile aynı aile.

#### Kapılar

* `chat_appbar_budget_test.dart` — bütçeyi ekranın KULLANDIĞI
  sabitlerden okur; beşinci bir düğme eklenirse düşer. `kAppBarIconSize`
  varsayılmıyor, **çizilip ölçülüyor**.
* `presence_label_test.dart` — 16 dilde ayar başlığının durum satırına
  sızmadığını ve vurgunun türden geldiğini ölçer.
  **Kırılabilirlik ölçüldü:** eski anahtar geri kondu, kapı düştü.

### §4ce — GÜVENLİK BANTLARI KIRPILIYORDU

Şikâyet: *"Aynısı 'güvenlik numarası karşılaştırarak bu sohb....'
kısmında da öyle."*

Bantların hepsi `kSecurityBannerHeight = 38` ile **tek satıra**
sıkıştırılmıştı. Yarısı görünen bir güvenlik bandı, görünmeyenle aynı
işe yarar: kullanıcı ne istendiğini anlamaz.

#### 🪤 Sözleşme zaten TUTMUYORDU

Bant yüksekliği tek sabitti ve sohbet ekranı `kSecurityBannerHeight * i`
ile dizip `* banners.length` ile liste dolgusu hesaplıyordu. Ama
**kimlik değişimi bandı** sohbet ekranının içinde ayrı yazılmıştı ve
yüksekliği elle `38` girilmişti. Sabit değişseydi bantlar mesaj
listesiyle çakışacaktı — sessizce. (Üstelik o bant `maxLines: 1` idi,
yani en ağır uyarı — *araya girme girişimi olabilir* — de kırpılıyordu.)

O bant `security_banners.dart`'a taşındı: kardeşleriyle aynı yerde,
aynı kapının altında.

#### Ortak yükseklik yanlış cevaptı

Gereken satır sayısı 16 dilde **gerçek Roboto metrikleriyle** ölçüldü:

| Bant | Gereken satır | Ne zaman görünür |
|---|---|---|
| Doğrulama önerisi | 2 | neredeyse HER doğrulanmamış sohbette |
| Şifresiz grup | 3 | şifreleme kurulamadığında |
| Kimlik değişimi | 3 | anahtar değiştiğinde |
| Anahtar rotasyonu | 4 | rotasyon başarısız olduğunda (nadir) |

Hepsini en uzuna (4 satır ≈ 84dp) eşitlemek, **en sık görünen bandın**
bedelini en nadirine ödetirdi. Her bant artık kendi yüksekliğini
söylüyor (`Banner.height`), ekran kümülatif topluyor.

#### 🪤 Çevrilmiş DÜĞME, uyarı metninin payını yiyor

Rotasyon bandındaki "Tekrar dene" bazı dillerde çok geniş
("Спробувати ще раз", "Erneut versuchen") ve metne kalan payı
daraltıyordu — Almanca 4 satıra bile sığmıyordu. Düğme 84dp ile
sınırlandı ve etiketi `FittedBox` ile küçülüyor: **düğme kısalır,
uyarı metni kırpılmaz.**

#### Kapı

`security_banners_test.dart` → `kırpılma` grubu, **16 dil × 4 bant**,
`didExceedMaxLines` ile ölçüyor.

⚠️ **Gerçek font ŞART.** Widget testinde varsayılan yedek font her
glifi 1em genişlikte çizer (Roboto'da Latin harfler ~yarısı). Yedek
fontla ölçmek yanlış alarm veriyordu: altı bandın altısı da düşüyordu.
Roboto artık `FLUTTER_ROOT` önbelleğinden yükleniyor.

**Kırılabilirlik ölçüldü:** `maxLines` 1'e çekildi, 12 test düştü.

### §4cf — ARAMA ROZETİNDEN AÇIKLAMA KALDIRILDI (kullanıcı kararı)

İstek: *"Arayınca doğrudan bağlantı yazsın sadece, üzerinde bakınca
açıklama yazmasın."*

Birebir arama ekranındaki rozet artık yalnızca etiket: bilgi simgesi ve
dokununca açılan diyalog yok.

#### 🔴 BİLİNÇLİ KAYIP — yeni oturum bunu bilsin

**TURN kurulana kadar HER arama doğrudan kurulur**, yani IP adresi
karşı tarafa açılır (§3 A). Kaldırılan açıklama, kullanıcının bunu
öğrenebileceği **tek yerdi.**

Bu tam olarak `ip_disclosure_test.dart`'ın önceden yazıp uyardığı adım:
*"yumuşatma, bir sonraki elde sessizce kaldırmaya dönüşebilir."*

**Ne yapıldı, ne yapılmadı:**

* Metinler (`call_ip_*_detail`) 16 dilde **SİLİNMEDİ**; geri getirmek
  `detail:` argümanını eklemekten ibaret.
* **Grup araması ekranı DIŞARIDA bırakıldı.** Mesh'te IP tek kişiye
  değil aramadaki HERKESE açılıyor; istek "arayınca" diyordu ve daha
  ağır olan yolu istenmeden değiştirmek doğru olmazdı.
  → **Karar bekliyor:** grup da aynı olsun mu?
* `ip_disclosure_test.dart`'ın başına kapsam daralması yazıldı. Testler
  hâlâ yeşil ama birebir yol için artık **kullanıcıya ulaşan** bir
  metni değil, yalnızca sözlükte duran bir metni ölçüyorlar — §4am'de
  yakalanan "yeşil ama hiçbir şey kanıtlamayan kapı" sınıfı. Yeşil
  olmaları "kullanıcı IP'sinin paylaşıldığını öğreniyor" demek DEĞİL.

### Kapılar

`flutter analyze` temiz · Dart **623** (549 → 623, +74) · kural **153**
· functions **4** · `dart format` temiz · `node --check` OK

---

## 🔍 SAHA RAPORU TURU (2026-09-11 → 09-14) — §4bv – §4cc

Testçiden üç şikâyet. **İkisi aynı kökten**, üçüncüsü jest tuzağı.

### §4bv — ÇÖZÜLEMEYEN MEDYA "BOZUK RESİM" GÖRÜNÜYORDU

Şikâyet: *"Galeri resimleri açılmıyor ama video gelmiş"* — aynı sohbette
bazı mesajlar da "çözülemedi" diyordu. **İkisi aynı arıza.**

Ek anahtarı mesajın ŞİFRELİ `content`i içinde taşınır:

```
content (E2EE) → "ATT1|<anahtar>|<açıklama>"
```

İçerik çözülemezse anahtar da çıkmaz. Eski kod mesajı OLDUĞU GİBİ
bırakıyordu; `mediaKey` null kalınca `SecureMediaImage` eki **şifresiz
sanıp** ham URL'i indiriyor ve şifreli baytları çözmeye çalışıyordu →
kırık resim simgesi.

Kullanıcıya "ağ sorunu / bozuk dosya" gibi görünen şey, metin
mesajlarındakiyle AYNI durumdu: çözülememiş bir mesaj. Metin dürüst bir
kutu gösteriyordu, medya göstermiyordu. Artık medya da aynı kutuyu
gösterir.

⚠️ Yalnızca ÇÖZÜLEMEME işaretlenir. Çözülüp de ayrıştırılamayan içerik
ESKİ BİÇİMLİ bir ektir; davranışı aynen korunur — ikisi karıştırılsaydı
eski mesajların medyası açılmaz olurdu. (`lost_media_test.dart`)

### §4bw — EN SIK DÜŞÜLEN BAŞARISIZLIK YOLU ÖLÇÜLMÜYORDU

`decrypt`in son `catch`i yalnızca `debugPrint` çağırıyordu — **yayın
derlemesinde hiçbir yere gitmez.** Bu dosyadaki diğer bütün
düz-metin/başarısızlık yolları `reportHandled` ile ölçülüyor; en sık
düşülen yolun ölçülmemesi "bazı mesajlar çözülemiyor" şikâyetinin
teşhisini bu turda tıkadı: hata mı, null mu, hangi aşama — hiçbiri
bilinemiyordu.

Aynı sessizlik `SecureMediaImage`de de vardı: çözme düşünce kullanıcı
yalnızca bir simge görüyordu.

⚠️ İkisinde de `chatId` RAPORLANMAZ — iki uid taşır, yani telemetriye
kim-kiminle bilgisi gider (§4k/§4o'nun aynı ilkesi).

> 📌 Tasarım gereği kalan durum: **oturum bozukken gelen mesajlar kalıcı
> olarak çözülemez kalır.** Kurtarma sohbetin bundan SONRASINI onarır.
> Bu bir arıza değil, ratchet'in doğası — ama artık telemetriyle "eski
> kırık pencere" ile "yeni arıza" ayırt edilebilir.

### §4bx — HİKAYE: ŞERİTTEKİ BOŞLUKLAR HİKAYEYİ İLERLETİYORDU

Şikâyet: *"tek tıklama yerine çift tıklamak gerekiyor."*

Hikaye ekranında `onDoubleTap` **hiç yok**; tarif ilk bakışta oturmadı.
Sebep şuydu: ekranın tamamında "sağa dokun → sonraki hikaye" jesti var,
ama alttaki tepki şeridinde yalnızca EMOJİLERİN ve yanıt kutusunun
kendi `GestureDetector`ı vardı. Aralarındaki boşluklar (`spaceEvenly`
dağıtıyor, boşluk emojiden geniş) alttaki jeste düşüyordu: emojiye
ıskalayan dokunuş hikayeyi atlatıyor, kullanıcı ikinci kez dokunuyor —
ve bunu "çift tıklama gerekiyor" diye yaşıyor.

Şerit artık `HitTestBehavior.opaque` ile dokunuşları yutar.

⚠️ **BU BİR ÇIKARIM.** Testçiye "emojiye/yanıt kutusuna dokunurken mi
oluyordu?" diye soruldu; doğrulanmadı.

### §4cc — SESSİZ YENİDEN EL SIKIŞMA (onarım kullanıcıyı beklemiyor)

Kullanıcının itirazı §4cb'deki "tasarım gereği" gerekçesini geçersiz
kıldı ve haklıydı:

> *"WhatsApp ve Signal'de bu böyle çalışmaz. Hem karşı tarafa aynı şeyi
> tekrar tekrar anlatmak zorunda bıraktırır… 3 saat sonra mesajımı yeni
> gören biri için yeniden açıklama yaptırmak tam bir eziyet olur."*

Doğru: Signal'de çözme başarısız olunca istemci karşı tarafı yeni
oturuma **kendisi** zorlar (null message / oturum arşivleme); kullanıcı
müdahalesi beklenmez. Bizim yaptığımız o mekanizmanın eksik hâliydi.

#### Nasıl çalışıyor

Ölü oturum tespit edilince istemci:
1. kendi oturumunu sıfırlar,
2. **X3DH'i başlatır** (karşı tarafın açık paketiyle),
3. init başlığını yayımlar:

```
handshakes/{chatId}/init/{gonderenUid} = { from, to, header, ts }
```

Karşı taraf bunu **uygulama genelinde tek bir koleksiyon-grubu akışıyla**
dinler ve `ensureSessionFromHeader` ile kendi tarafını onarır.

> ⚠️ **Dinleyici sohbet ekranına BAĞLANMAZ.** Onarımın bütün değeri,
> karşı tarafın o sohbeti açmasını beklememesinde; sohbete bağlı bir
> dinleyici bu değeri tamamen yok ederdi.

Sohbete **görünür hiçbir mesaj düşmez**.

#### Replay koruması bedava geliyor

`ensureSessionFromHeader` yalnızca EFEMERAL anahtar değişmişse oturumu
yeniler (§4ax). Aynı belge tekrar okunsa bile ikinci kezinde efemeral
aynıdır → hiçbir şey olmaz. Ayrı bir "en son ne uyguladım" durumu
tutmaya gerek kalmadı.

#### Güvenlik sınırı

Yazma yalnızca **sohbetin üyesi** ve yalnızca **kendi adına**. Yabancı
yazabilseydi istediği kişinin oturumunu sürekli sıfırlatabilirdi —
sohbeti yeniden kurduran bir hizmet reddi. Okuma da iki tarafla sınırlı:
başlık açık anahtar taşır ama "kim kiminle el sıkışıyor" üstveridir.

⚠️ Koleksiyon-grubu `list` kuralı **sorguya** bakar: istemcideki
`where('to', ==, ben)` kısıtı süsleme değil, iznin kendisi (§4bq dersi).
Test bunu ayrıca ölçüyor.

#### ⚖️ ÇAKIŞAN EL SIKIŞMA — onarım onarmaya çalıştığını bozabilirdi

Göndermeden önce yakalandı: iki taraf da aynı anda ölü oturum tespit
edip yayımlarsa, her biri **diğerininkini** benimser ve farklı
oturumlarda kalır. Sohbet tamamen kırılır.

Çözüm, grup aramasındaki desenin aynısı (§4bq): pazarlık yok,
**deterministik hakem — uid'i küçük olan kazanır.**

| Durum | A (küçük uid) | B |
|---|---|---|
| İkisi de yayımladı | kendi oturumunda kalır | A'nınkini benimser |
| Yalnız A yayımladı | — | benimser |
| Yalnız B yayımladı | benimser | — |

⚠️ Hakem **yalnızca çakışmada** devreye girer. "Ben yayımlamadıysam
gelen başlığı her zaman benimserim" — asıl senaryo budur (genelde tek
taraf bozuktur) ve orada kazanmaya çalışmak onarımı hiç yaptırmazdı.

Kilit: `rehandshake_glare_test.dart` — her çiftte TAM BİR tarafın
kazandığını ölçüyor (ikisi de kazanırsa ayrışma, ikisi de kaybederse
onarım yok).

#### 🪤 İNDEKS: BİLEŞİK DEĞİL, ALAN GEÇERSİZ KILMA

İlk dağıtım denemesi şununla düştü:

```
HTTP 400: this index is not necessary,
configure using single field index controls
```

Tek alanlı koleksiyon-grubu sorgusu (`where('to', ==, ben)`) bileşik
indeks istemez; **`fieldOverrides` içinde COLLECTION_GROUP kapsamlı tek
alan indeksi** ister. ⚠️ O denemede kurallar da yayımlanmadı — indeks
adımı düşünce dağıtım tümden durdu; çıktıda "released rules" satırının
olmaması bunun işareti.

#### Kapılar ve dağıtım

Kural testleri **144 → 153** (9 yeni). ✅ **DAĞITILDI** (2026-09-16, `gizlichat-f2a99`): `handshakes` kuralları
+ `init.to` alan geçersiz kılma üretimde.

Güvenli bozulma korunuyor: yayımlama bir sebeple başarısız olursa eski
davranışa düşülür (kullanıcı yazınca onarım) ve `reportHandled` ile
ölçülür — sessizce ölmez.

### §4cb — "ARKA PLANDAN SİLİNCE MESAJ ULAŞMIYOR" — ÖLÜM PENCERESİ

Şikâyet (iki parçalı): *"Bazı kişilere ben mesaj göndermediğim sürece
mesajları çözülemedi geliyor… Ama telefonum kapalıyken veya arka plandan
sildiğimde mesajları bana ulaşmıyor."*

#### Bulunan: iki yazma arasında ÖLÜM PENCERESİ

`decryptMessage` başarılı çözmeden sonra ratchet durumunu kalıcı
yazıyordu; düz metin önbelleği ise ÇAĞIRAN tarafta, **ayrı bir
yazmayla** tutuluyordu:

```
decryptMessage() → _saveSession()   ← zincir İLERLEDİ, kalıcı
      ↓  (uygulama burada ölürse)
cachePlaintext()                    ← HİÇ ÇALIŞMADI
```

Açılışta mesaj yeniden çözülmeye çalışılır ama zincir o mesajın ötesine
geçmiştir. Anahtar `skipped` haritasına da girmemiştir: **atlanmadı,
TÜKETİLDİ.** Sonuç: o mesaj **kalıcı olarak** "çözülemedi".

"Arka plandan silince" tam olarak bu pencereyi açan davranış.

**Düzeltme — sıra:** `decryptMessage` artık `messageId` alıyor ve düz
metni **ratchet kaydından önce** yazıyor. Ters sırada risk yok: düz
metin yazılıp ratchet kaydedilmezse mesaj önbellekten okunur (çözme
yolunun ilk adımı) ve zincir olduğu yerde kalır.

> 📌 §4bz ile **aynı sınıf** hata: iki kalıcı yazma arasındaki sıra.
> Orada Firestore/önbellek, burada ratchet/önbellek.

Kilit: `ratchet_kill_window_test.dart` — tüketilen anahtarın geri
gelmediğini ve bunun "atlanan" durumdan farkını ölçüyor.

#### ⏳ ŞİKÂYETİN İLK YARISI HÂLÂ AÇIK

*"Ben yazana kadar çözülemedi"* kısmı **tasarım gereği** ve
düzeltilmedi. Oturum bozulduğunda kurtarma yolu şu:

```
çözemedim → kendi oturumumu sıfırla → KULLANICI bir şey yazınca
X3DH baştan kurulur ve başlık gider → karşı taraf onarılır
```

Yani onarım **kullanıcının yazmasını bekliyor**; o ana kadar gelen her
mesaj çözülemez ve kalıcı kaybolur. §4av bunu zaten "yama, tasarım
düzeltmesi değil" diye kaydetmişti.

**Önerilen çözüm (yapılmadı, karar bekliyor):** oturum ölü tespit
edilince istemci, kullanıcı hiçbir şey yazmadan **sessiz bir el
sıkışma** yayımlasın. Grup anahtar dağıtımındaki desenin aynısı:

```
e2eeHandshakes/{chatId}/{gonderenUid} = { init başlığı, ts }
```

Karşı taraf bunu dinleyip `ensureSessionFromHeader` çağırır. Sohbete
görünür mesaj düşmez.

⚠️ Bu bir **protokol değişikliği**: yeni koleksiyon + yeni güvenlik
kuralı + dağıtım gerektirir ve uygulamanın en hassas yerine dokunur.
Kullanıcı onayı olmadan yapılmadı.

### §4ca — KIRPILAN RESİM EKRAN ORANINDA KAYDEDİLİYORDU

Şikâyet: *"9:16 bir resmi 1:1 kırptım; bıraktığı arka plan kırpılma
boyutunda değil, 9:16'lık boşluk bırakıyor."*

**Kök neden:** `_save()` görüntüyü değil, **ekrandaki tuvali**
fotoğraflıyor:

```dart
final b = _canvasKey.currentContext!.findRenderObject()
    as RenderRepaintBoundary;
final img = await b.toImage(pixelRatio: 2.0);
```

`RepaintBoundary` ise tüm kullanılabilir alanı kaplıyordu
(`width: box.maxWidth, height: box.maxHeight`) ve görüntü onun içine
`BoxFit.contain` ile **ortalanıyordu**. Kaydedilen PNG = ekran
dikdörtgeni + ortasında kırpılmış resim. Telefon ekranı kabaca 9:16
olduğu için semptom tam olarak bildirilen şekilde görünüyordu.

**Düzeltme:** tuval görüntünün oranında —
`AspectRatio` → `LayoutBuilder` → `RepaintBoundary`. Oran dosyadan
okunuyor (`ui.instantiateImageCodec`) ve **kırpma sonrası tazeleniyor**.

> 📐 **Koordinatlar neden bozulmadı:** öğeler ORANSAL
> (`pos.dx * _canvas.width`), çizimler tuvale YEREL. `_canvas` zaten
> `LayoutBuilder`ın kutusundan geliyor; kutu daralınca ikisi de
> kendiliğinden doğru yere düşüyor.

⚠️ **OTOMATİK TESTİ YOK.** Widget testi yazıldı ama bu ortamda
çalışmadı: `ui.PictureRecorder().toImage()` / kodek çağrıları
`flutter_test` içinde asılı kalıyor (üç denemede de "did not
complete"). Emeğini savunamayan test bırakmak yerine silindi.
**Cihazda doğrulanmalı** — bkz. açılış bloğundaki "cihazda hiç
denenmemiş olanlar".

#### 🔎 AYNI FONKSİYONDA İKİNCİ KUSUR (düzeltilmedi)

`pixelRatio: 2.0` ile **ekran boyutundaki** bir widget fotoğraflanıyor.
Yani 4000 piksellik bir fotoğraf ekran çözünürlüğüne (~1500 px)
düşürülerek gönderiliyor — editörden geçen HER fotoğrafta, kırpma olsun
olmasın. Çıktı ayrıca PNG, yani bir fotoğraf için JPEG'den kat kat
büyük.

Kapsam dışı bırakıldı: kullanıcı bunu bildirmedi ve düzeltmek çıktı
boyutunu büyütür. Ölçülüp ayrı iş olarak yapılmalı.

### §4bz — MESAJ DÜZENLEYİNCE "ÇÖZÜLEMEDİ"

Şikâyet: *"Bir mesajı düzenlediğimde çözülemedi hatası verdi."*

**Kök neden: sıra.** `editMessage` sunucuya ÖNCE yazıyor, düz metni
SONRA önbelleğe alıyordu.

```
enc → remoteDataSource.editMessage()   ← Firestore
    → forgetPlaintext / cachePlaintext ← önbellek (GEÇ)
```

Firestore yazması yereldeki dinleyiciyi **anında** tetikler (iyimser
yazma). Akış yeni `editedAt` ile çözmeye başlar, önbellek anahtarı
`<id>#<zaman>` henüz yazılmamıştır ve **gönderen kendi şifreli metnini
çözemez** (ratchet tek yönlü) → `lostMarker`.

⚠️ **VE KALICI OLUR.** O sonuç `_plainMemo`ya yazılır; sonraki her
yayımda kısa devre yapar. Birkaç milisaniye sonra gerçek düz metin
depoya yazılsa bile mesaj "çözülemedi" kalır — memo'yu düşüren bir şey
olmadıkça.

**Düzeltme:** sıra tersine çevrildi. Kendi içinde de sıra önemli:

1. `forgetPlaintext(messageId)` — eskiyi sil (`<id>#*` sürümleri dahil)
2. `cachePlaintext(<id>#<zaman>, yeniMetin)` — yeniyi yaz
3. `remoteDataSource.editMessage(...)` — **en son** sunucu

(2'yi 1'den önce yapmak yeni metni sildirirdi: `forgetPlaintext`
düzenleme sürümlerini de temizliyor.)

> 📌 **Diğer iki yol zaten DOĞRUYDU.** `sendTextMessage` (500→507) ve
> `sendMediaMessage` (637→643) önce önbelleğe yazıyor. Düzenleme tek
> istisnaydı — yani hata "bilinmeyen bir tuzak" değil, var olan
> desene uymama.

Kilit: `message_repository_impl_test.dart` → *"DÜZ METİN SUNUCUDAN ÖNCE
ÖNBELLEĞE YAZILIR"* (`verifyInOrder`) + damganın ISO-8601 **UTC**
olduğunu ölçen ikinci test. Kırılabilirlik denetlendi: sıra geri
alınınca test düşüyor.

### §4by — YAYIN VE GELİŞTİRİCİ DOĞRULAMASI (tarayıcıdan)

v22 Play Console'dan yayına alındı ve Android geliştirici doğrulaması
denetlendi. Burada kayda değer olan **araçların sınırları**:

#### 🪤 TARAYICI OTOMASYONU PAKETİ YÜKLEYEMEZ

Dosya yükleme aracının sınırı **10 MB**, paket **88,5 MB**. Yani
"Chrome'a bağlan ve yükle" teknik olarak mümkün değil — tarayıcıdan
yapılabilen tek şey, paket ZATEN yüklendikten sonraki adımlar (notlar,
inceleme, gönderim).

Kalıcı çözüm yazıldı: **`scripts/play_yukle.js`** (Play Developer API
v3). API'de 10 MB sınırı yok; `google-auth-library` zaten kurulu olduğu
için yeni bağımlılık gerekmedi. Üç kapısı test edildi:

| Kapı | Ne engelliyor |
|---|---|
| `--track` zorunlu | kanalı tahmin etmek = yanlış kişilere sürüm |
| `production` fazladan bayrak ister | tek kelimelik fark, geri alınamaz yayın |
| Notlar 500 karakter denetimi | Play, paketi YÜKLEDİKTEN sonra reddeder |

`--kanallar` modu hem kurulumu doğrular hem kanal kimliklerini listeler.

⏳ **Kullanılabilmesi için hizmet hesabı gerekiyor** (Play Console → API
erişimi → Cloud projesi → hizmet hesabı → JSON anahtar → Play'de
"Test kanallarına sürüm yayınla" izni). Kurulmadı; bu sürüm elle yüklendi.

⚠️ Cloud'da hizmet hesabı **oluşturmak anahtar üretmez** — ayrıca
"Anahtarlar → Anahtar ekle → JSON" gerekiyor. Ve Cloud'daki IAM rolü
Play tarafında hiçbir şey yapmaz; Play Console'da ayrıca davet şart.

#### ✅ ANDROID GELİŞTİRİCİ DOĞRULAMASI — TAMAM

Son tarih **30 Eylül 2026**: o tarihe kadar kaydedilmeyen uygulamalar
Play'den kaldırılıyor, kayıtsız anahtarla imzalı APK'lar da bazı
ülkelerde sertifikalı cihazlara kurulamıyor.

| | Durum |
|---|---|
| Paket adı `com.secreter.app` | **Kayıtlı** (31 Tem 2026) |
| Kimlik (ad + adres) | Dolu, geliştirici hesabından geliyor |
| Anahtarlar | 3 → **4** |

**Yerel imzalama anahtarı sonradan eklendi.** Kayıtlı üçü Play'in
tarafına aitti; `.aab`'yi imzalayan anahtar listede YOKTU:

```
27:70:E2:27:3E:3E:57:37:64:1E:D8:AF:D9:7D:5F:5D:
B0:8C:BA:43:3E:45:FF:63:2F:13:E2:FF:82:A6:6C:82   (CN=SECRETER)
```

Play üzerinden dağıtımda bu eksiklik zararsızdır — Play App Signing
paketi kendi anahtarıyla yeniden imzalar. Ama **Play dışında dağıtılan
APK** (testçiye doğrudan gönderilen, `adb install` edilen) bu anahtarla
imzalıdır ve 30 Eylül sonrası kurulamazdı. Eklendi, durumu "İncelemede".

💡 **Parmak izini parolasız okumanın yolu:**
```bash
keytool -printcert -jarfile <paket>.aab
```
Anahtar deposunu açmaz, parola istemez — sertifika parmak izi zaten
imzalı her pakete gömülü, gizli bir değer değil.

#### 🪤 PAKETTE DİZE ARAMA — KODLAMA TUZAĞI (tekrar düşüldü)

Derlemenin doğruluğunu ölçerken `libapp.so` içinde metin arandı ve
"Mesaj çözülemedi" **YOK** raporlandı — yanlıştı, dize derlemedeydi.

Kural (bu dosyada §"APK bir zip'tir" altında zaten yazıyordu): Dart
dizeleri **üç** kodlamada saklar. Tüm karakterler Latin-1'e sığıyorsa
(`ç ö ü`) tek bayt, sığmıyorsa (`ş ı ğ Ş İ`) UTF-16LE, saf ASCII düz
bayt. Yani:

* `Mesaj çözülemedi` → **latin-1**
* `Şifreli medya açılamadı` → **UTF-16LE**

Tek kodlamaya bakmak, dize derlemede OLSA BİLE "yok" dedirtir.
Hafızaya da yazıldı.


### Kapılar
`flutter analyze` temiz · Dart **549** · kural **153** · functions **4**

## 🛡️ KALİTE VE GİZLİLİK TURU (2026-09-11 gece) — §4br – §4bu

Kullanıcının önceliği: *"Uygulama kalitesi ve gizliliği benim için çok
değerli."* Sıradaki beş maddenin üçü bitti, biri altyapıya bağlı.

### §4br — GRUP ARAMASINDA GİZLİLİK ROZETİ YOKTU

Birebir aramada rozet vardı ("Doğrudan bağlantı", dokununca IP
paylaşımını açıkça söyleyen açıklama — 16 dil, test kilitli). **Grup
arama ekranında hiç yoktu.** Üstelik ödünleşim orada daha ağır:

| | IP kime açılır |
|---|---|
| Birebir arama | karşı taraf — **1 kişi** |
| Grup araması (mesh) | **aramadaki herkes** (N-1 kişi) |

Mesh'te her katılımcı diğer herkese DOĞRUDAN bağlanır. Birebir aramanın
metnini ("karşı tarafa görünür") grupta kullanmak ödünleşimi olduğundan
küçük gösterirdi; bu yüzden grup için AYRI metinler yazıldı ve
`ip_disclosure_test.dart` iki şeyi birden zorunlu kılacak şekilde
genişletildi (49 → 113 test):

1. açıklama IP'den söz etmeyi bırakmasın,
2. **çoğulluğu** söylemeyi bırakmasın ("herkes/alla/全員/…" — 16 dilin
   her biri için ayrı iz).

> ⚠️ DEVAM.md'nin kendisi bu turdan ÖNCE şöyle diyordu: *"MESH YAPMA:
> TURN olmadan herkesin IP'si herkese açılır."* Kullanıcı mesh'i seçti ve
> yapıldı — ama uyarının koşulu hâlâ geçerli. Rozet, o koşulu
> kullanıcıya görünür kılar. Gerçek çözüm TURN'dür (§4bs).

Ek olarak grup aramasına **hoparlör düğmesi** (grupta varsayılan AÇIK —
ahizeden başlarsa kullanıcı "ses gelmiyor" sanır) ve relay erişilemezlik
rozeti eklendi.

### §4bs — TURN: KOD TARAFI BİTTİ, SUNUCU BEKLİYOR

`getTurnCredentials` zaten dağıtılmış ve `configured:false` dönüyor
(sır tanımlı değil). Bu turda yapılanlar:

* Kimlik üretimi `functions/turn.js`e **saf fonksiyon** olarak ayrıldı ve
  4 testle kilitlendi. Biçim coturn'ün `use-auth-secret` kipiyle birebir
  uyuşmak zorunda: **bir karakter saparsa coturn kimliği reddeder, ICE
  başka aday bulamaz** (`iceTransportPolicy: relay`) ve arama STUN'a
  düşmez — HİÇ KURULMAZ. Hiçbir yerde hata çıkmaz.
* `scripts/turn_kur.sh` — sunucuda tek komut. Elle yapılırken atlanan ve
  hepsi **sessiz arızaya** yol açan üç şeyi kendiliğinden halleder:

| Atlanırsa | Ne olur |
|---|---|
| `external-ip` | NAT arkasında aday toplanır, medya HİÇ akmaz |
| Günlük kapatma | Relay iki tarafın IP'sini görür ve diske yazar |
| Yenileme kancası | Sertifika 90 gün sonra eskir, `turns:` çalışmaz |

⏳ **KALAN:** VPS + alan adı (kullanıcı kararı, ~5 $/ay). Sunucu hazır
olunca `functions/.env`e iki değer ve tek dağıtım.

### §4bt — KENDİNE MESAJ ("Notlarım")

Önceki turda **bilerek yapılmamıştı** ve gerekçesi şuydu: `uid_uid`
sohbetinde `_extractOtherUserId` boş döner → sohbet GRUP sanılır → üye
sayısı 1 olduğu için "dejenere grup" dalına düşer → mesaj **DÜZ METİN**
gider. Yani özellik *çalışıyor görünür*, notlar sunucuda açıkta durur,
hiçbir hata çıkmaz.

Doğru çözüm simetrik: iki taraf aynı kişiyse paylaşılacak sır da yoktur.

* **X3DH + ratchet olmaz** — ratchet iki AYRI tarafın anahtarlarıyla
  ilerler; kendinle el sıkışmak aynı oturumun iki ucu olmaktır.
* **Sender key de olmaz** — yukarıdaki dejenere grup tuzağı.

`SelfNoteService`: hesabın `chat_encryption_key`inden **HKDF** ile
türetilmiş simetrik anahtar + AES-256-GCM.

> 🔑 **ANAHTAR NEDEN HESAP ANAHTARINDAN?** Kimlik anahtarları kurtarma
> anahtarına GİRMEZ (yeniden kurulumda "güvenlik numarası değişti"
> uyarısının sebebi budur), hesap anahtarı girer. Kimlikten
> türetilseydi, uygulamayı silip kurtarma anahtarıyla dönen kullanıcının
> **tüm notları sessizce okunamaz** hâle gelirdi. Sessizce veri
> kaybettiren bir özellik, olmayan özellikten kötüdür.

⚠️ Hesap anahtarı DOĞRUDAN kullanılmaz; HKDF `info` etiketiyle ayrı bir
amaca bağlanır. Bir anahtarın iki iş görmesi, birinin açığa çıkmasını
diğerinin de açığa çıkması yapar. Türetme parametreleri **altın
vektörle** kilitli: değişirse test gürültülü biçimde düşer, çünkü o
değişiklik var olan tüm notları okunamaz yapar.

Düz metin önbelleğe **yazılmaz** (bilerek): diğer yollarda önbellek
zorunlu — ratchet ileri gittiği için gönderen kendi metnini çözemez.
Burada anahtar simetrik ve sabit, zarf her zaman yeniden çözülebilir;
önbellek yalnızca cihazda fazladan bir düz metin kopyası bırakırdı.

Arayüzde: `+` menüsünde "Notlarım", listede ve başlıkta doğru ad, ve
kendine sohbette **arama düğmeleri ile güvenlik numarası gizli** (üçü de
"karşı taraf" varsayar).

### §4bu — "SOHBETİ TEMİZLE" HER BİREBİR SOHBETTE KIRIKTI

§4aw'de "düzeltilmedi" diye yazılmıştı. Kök sebep:

```
allow delete: if member() && (senderId == request.auth.uid || isChatAdmin())
```

İstemci her mesaj BELGESİNİ siliyordu. **Birebir sohbette yönetici
yoktur**, yani karşı tarafın tek bir mesajı bile toplu yazmayı tümden
reddettiriyordu. Kullanıcı her seferinde "Temizlenemedi" görüyordu.

⚠️ **DÜZELTME KURALI GEVŞETMEK DEĞİLDİ.** "Karşı tarafın mesajlarını da
sil" izni, bir sohbetin tarafına diğerinin geçmişini **tek taraflı yok
etme** yetkisi verirdi — söylediklerinin kaydını silmek isteyen biri
için hazır bir araç. Temizleme artık "yalnızca bende"dir: kendi
mesajların silinir, karşı tarafınkiler senden gizlenir (`deletedFor`).
WhatsApp/Signal'deki "Clear chat" de budur.

Diyalog metni de düzeltildi: eskiden "her iki taraftan da kalıcı olarak
silinecek" diyordu — ne oluyordu ne de olmalıydı. Artık ne olduğunu
söylüyor, 16 dilde.

### Kapılar

`flutter analyze` temiz · Dart **533** · kural **153** · functions **4**
· `node --check` OK


## 🧰 ÖZELLİK TURU (2026-09-11 akşam) — §4bf – §4bl

Kullanıcının istediği altı madde + bulunan iki performans/deneyim hatası.

| # | İş | Bölüm | Durum |
|---|---|---|---|
| 1 | Güncelleme bildirimi | §4bl | ✅ `in_app_update` |
| 2 | Sohbet açılışında 3+5 sn gecikme, mesajlar "silinmiş" görünüyor | §4bi | ✅ kök neden bulundu |
| 3 | GIF/çıkartma çalışmıyor | — | ✅ anahtar derlemeye kondu |
| 4 | Kendine mesaj | — | ⛔ **YAPILMADI** — aşağıya bak |
| 5 | Ana ekranda tema rengi | §4bj | ✅ |
| 6 | Serbest iyileştirme | §4bk | ✅ kaybolan metin |
| + | Yanıt çubuğu geç kapanıyor | §4bf | ✅ |
| + | Çift tıkla 👍 | §4bg | ✅ |
| + | Sohbete girince her şey "silinmiş" | §4bh | ✅ |

### §4bi — SOHBET AÇILIŞI: N PLATFORM ÇAĞRISI

`getPlaintext` her mesaj için ayrı `SecureStore.read()` yapıyordu.
Android'de her okuma EncryptedSharedPreferences'a bir **platform kanalı
çağrısıdır**; 200 mesajlık sohbette 200 çağrı demektir.

Kullanıcının tarifi birebir uyuyor: *"3 sn yükleme, sonra mesajlar
silinmiş gibi, 5 sn sonra tüm sohbet açılıyor."* Mesajlar geç dolduğu
için çözülemeyen olarak çizilip **ortalanmış gri kutulara** dönüşüyor,
sonra gerçek içerik gelince düzeliyordu.

**Düzeltme:** `SecureStore.readAll()` + `warmPlaintextCache()` — N çağrı
1'e indi. Arayüz üzerinden geçer (`EncryptionDataSource`), repository
somut servise bağlanmaz.

### §4bh — `currentUid` AKIŞ BAŞINDA BİR KEZ OKUNUYORDU

Firebase Auth oturumu asenkron geri yükler; ekran ondan önce açılırsa
uid `null` yakalanıp akışın TÜM ömrü boyunca null kalıyordu. Sonuç:
`isFromMe` hep false → KENDİ mesajlarımız çözülmeye kalkılıp
başarısız oluyor → hepsi gri kutu. §4bd ile **aynı sınıf** hata
(auth hazır değilken okunan değerin kalıcılaşması), ikinci yeri.

### §4bl — GÜNCELLEME BİLDİRİMİ: NEDEN PLAY API'Sİ

Alternatif Firestore'da "son sürüm kodu" tutmaktı; her yayında elle
güncelleme ister ve unutulunca **sessizce yanlış cevap verir** — bu
projede fazlasıyla görülen sınıf. `in_app_update` kaynağı doğrudan
mağazadan okur, bakım istemez.

⚠️ Play dışı kurulumda `checkForUpdate` İSTİSNA fırlatır (yan yükleme,
emülatör). Yutulur ama `reportHandled` ile ölçülebilir kalır; aksi
hâlde "kimseye bildirim gitmiyor" arızası görünmezdi.

### ⛔ #4 KENDİNE MESAJ — BİLEREK YAPILMADI

Naif hâli **gizlilik açığı** olurdu: `chatId` = `uid_uid` olunca
`_extractOtherUserId` boş döner, sohbet GRUP sayılır, üye sayısı 1
olduğu için `encrypt()` düz metne düşer. Crashlytics'teki
*"Grup dejenere (üye < 2) — mesaj ŞİFRESİZ"* kaydı tam bu yol.

Doğru çözüm: kendine sohbeti ayrı ele alıp mesajları hesabın KENDİ
anahtarıyla şifrelemek. Ayrı bir iş; kullanıcı onayı bekliyor.

---

## 🔬 ELEME TURU (2026-09-11) — §4bb / §4bc / §4bd

Kullanıcı haklı olarak sordu: *"İlk zamanlarda harika çalışan E2EE neden
bu kadar sorunlu?"* Cevap ölçüldü.

### §4bb — EKSİK KAPI: iki taraflı el sıkışma hiç test edilmemiş

```
$ grep -rl "establishFromHeader\|initiateSession" test/
(sonuç yok)
```

Şifreleme katmanı aylarca değişti (v2→v3 DH ratchet, hesap kapsamı,
oturum kurtarma, başlık taşıma) ve her değişiklik KENDİ parçasının
testiyle doğrulandı. Borunun tamamı hiç akıtılmadı. Dört tur boyunca
"karşı taraf bana yazamıyor" arızasında hep başka bir parçaya bakıldı.

**Yazıldı:** `test/services/e2ee_round_trip_test.dart` (8 test).
İki cihaz, aynı `chatId` altında farklı hesap kapsamıyla temsil edilir;
bootstrap'lar üretim kodundaki adımların birebir aynısıyla kurulur.

**SONUÇ — ÖNEMLİ OLUMSUZ BULGU: hepsi GEÇTİ.**

| Sınanan | Sonuç |
|---|---|
| A→B tek yön, arka arkaya üç mesaj | ✅ |
| **B→A cevap** (dört turdur şüphelenilen yer) | ✅ **sağlam** |
| Karşılıklı sohbet | ✅ |
| Sırasız teslim (atlanan anahtarlar) | ✅ |
| Aynı paketi İKİNCİ kez çözme | ❌ çözülemez — **tasarım gereği doğru** |

X3DH bootstrap'ı, DH ratchet ve zincir türetme **doğru çalışıyor**. En
büyük şüpheli elendi.

> Son satır uygulamanın kırılgan yerini kayda geçiriyor: şifreli metin
> TAM BİR KEZ çözülebilir, ama arayüz her Firestore anlık görüntüsünde
> tüm listeyi yeniden çözmeye kalkar. Bunu yalnızca düz metin önbelleği
> engeller — **önbellek bir kez ıskalarsa o mesaj kalıcı olarak gider.**

### §4bd — 🔴 HESAP KAPSAMI AÇILIŞ YARIŞI (elemeden sonra bulundu)

Kapsam `main.dart`'ta **bir kez**, `AuthService.currentUid`'den
kuruluyordu ve `authStateChanges` dinleyicisi **hiç yoktu**. Ama
`FirebaseAuth.currentUser`, `initializeApp()` ardından HENÜZ NULL
olabilir — kaydedilmiş oturum asenkron yüklenir.

Yarışı kaybeden açılışta kapsam `'_'` kalır:

* oturum anahtarı `e2ee_session___{chatId}` → **kayıtlı oturum
  bulunamaz** → gelen her mesaj "çözülemiyor",
* giden mesajlar `'_'` altında yeni oturum kurar → sonraki açılışta
  doğru uid ile okunduğunda **öksüz** kalır → karşı tarafın cevapları da
  çözülemez.

**Her açılışta yeniden zar atılır** → arıza ARALIKLI görünür:
*"bir ara düzeldi, sonra yine bozuldu."*

**Düzeltme:** kapsam tek yerden kurulur (`_hesapKapsaminiKur`) ve
`AuthService.activeUidChanges` akışına abone olunur.
**Kapı:** `test/core/account_scope_startup_test.dart` (3 test).

> ⚠️ **KANIT DEĞİL, MEKANİZMA.** Yarışın varlığı koddan kesin; kullanıcının
> arızasının TEK sebebi olduğu kanıtlanmadı. Kanıt: v17'de iki taraf
> karşılıklı yazsın, bozulmuyorsa sebep buydu.

### §4bc — GIF/ÇIKARTMA SEKMESİ SESSİZCE KAYBOLMUŞTU

Kullanıcı: *"Mesajlara çıkartma ve gif gönderme sekmesi neden silindi??"*

Silinmemişti, `if (GiphyService.isEnabled)` ile GİZLENMİŞTİ. Gerekçe
makuldü (anahtarsız derlemede sekme boş kalıyordu) ama hiçbir derlemeye
`--dart-define=GIPHY_API_KEY` konmadığı için özellik kullanıcıdan
TAMAMEN kayboldu.

**Ders:** sessizce yok olan özellik, hata mesajından KÖTÜDÜR. Kullanıcı
"bozuk" demez, "silinmiş" der.

**Düzeltme:** seçenek her zaman görünür; kapalıysa nedenini söyleyen bir
sayfa açılır (16 dil). **Kapı:** `gif_option_visible_test.dart` (2 test)
— koşullu gizleme geri gelirse düşer.

⏳ **Bekleyen:** `GIPHY_API_KEY` kullanıcıdan alınıp derlemeye konmalı;
o zaman GIF gerçekten çalışır.

### ✅ v17 (1.0.6+17) derlendi — 13:46:59

Kapılar: analyze 0 · **435** test · format temiz.
Paket doğrulandı: versionCode 17, kaynak md5 derleme boyunca sabit,
`libapp.so` taramasında yeni dizeler var.

---

## 📸 TEK GÖRÜNTÜLÜK TURU (2026-09-11) — §4ba

**Kullanıcı:** *"Tek gönderimlik fotolar bulanık da olsa sınırsız
görülüyor. Bastıkça görebiliyorsun."*

Hata kriptoda değil **rota sonucundaydı**: `FullScreenImage`
`PopScope(canPop: true, onPopInvokedWithResult: (didPop, _) {})`
kullanıyordu. Geri tuşu/jesti rotayı SONUÇSUZ kapatıyor, `open()`
`false` döndürüyor, tüketim hiç tetiklenmiyordu. Sonucu yalnızca X
düğmesi döndürüyordu — Android'de doğal çıkış yolu ise geri jestidir.

Yorum satırı *"Geri tuşu/jesti ile çıkışta da yükleme durumunu bildir"*
diyordu; **gövde boştu.** Niyet yazılmış, kod yazılmamıştı.

**İkinci kusur:** `_loaded` ilk kareden 600 ms sonra KOŞULSUZ true
oluyordu — görüntü hiç çizilmese bile. Birinci kusuru tek başına
düzeltmek bunu tehlikeli hâle getirirdi (açılmayan fotoğraf yanardı),
o yüzden ikisi birlikte düzeltildi: `SecureMediaImage.onLoaded` eklendi,
`_loaded` artık gerçek çizime bağlı.

**Kapı:** `full_screen_image_pop_test.dart` (3) — eski davranışa
dönüldüğünde üçü de düşüyor.

> ⚠️ **Testle ölçülmeyen yön:** "çizilen fotoğraf yanar" yönü birim
> testinde doğrulanamadı (ağ/dosya yok). Cihazda denenmeli.

### 🚦 Play durumu

* **15 (1.0.4) YAYINDA** — 11 Eyl **11:04**. §4az (kök neden) testçilere
  ulaştı.
* **16 (1.0.5)** — §4ba ile derleniyor; yüklenmeyi bekliyor.

---

## 🔴 KÖK NEDEN TURU (2026-09-11) — §4az

Kullanıcı dört yeni belirti bildirdi; **üçü tek bir satırdan geliyordu.**

| # | Belirti | Kök neden | Durum |
|---|---|---|---|
| 1 | Karşı taraf foto/video/belge göremiyor | `copyWithContent` `e2eeHeader`'ı düşürüyor → içerik çözülemiyor → `mediaKey` çıkmıyor | ✅ |
| 2 | Ankete oy veremiyor | aynı metot `pollOptions`'ı düşürüyor → seçenek kalmıyor | ✅ |
| 3 | Tek-gönderimlik resim görünmüyor, defalarca açılabiliyor | görünmeyen resim TÜKETİLEMİYOR (tüketim gösterime bağlı) | 🟡 kısmen |
| 4 | Tüketim alıcıda anlık işlemiyor | ölçülmedi — medya gösterilemiyorken ölçülemezdi | 🟡 **AÇIK** |

### Neden bu kadar uzun saklandı

`withResolvedSender` her GELEN mesajı, **daha çözülmeden** kopyalıyor
(§4k metadata gizliliği: `senderUsername` sunucuya yazılmıyor). Kopya
başlığı taşımıyordu. **Kendi** mesajlarımızda ad zaten dolu olduğu için
o dal hiç çalışmıyor — "kendimle sorun yok, başkası yazamıyor"
asimetrisinin tam kaynağı buydu.

> ⚠️ **Gece turundaki ölçüm doğruydu, YORUMU yanlıştı.** "Gelen
> mesajlarda başlık YOK" diye ölçmüştük ve başlıktan kurtarma
> hipotezini çürütmüştük. Başlığı gönderen koymamış değildi; **alıcı
> kendi belleğinde siliyordu.** Doğru ölçümden yanlış sonuç çıkarmanın
> ders niteliğinde örneği — hipotezi çürütürken "neden yok?" diye bir
> adım daha sorulmalıydı.

### Yanında çıkan iki kusur

* Başarısız çözüm önbelleğe alınıyordu → oturum onarılsa bile mesaj
  uygulama yeniden başlayana kadar "çözülemiyor" kalıyordu. Düzeltildi.
* 🪤 **`lostMarker` neredeyse sessizce bozuluyordu:** nöbetçi
  `' E2EE_LOST'` gibi görünür ama baştaki karakter **NUL**'dur.
  Sabiti arayüze taşırken boşlukla yazıldı; `repr()` ile ölçülmeseydi
  arayüz "çözülemedi" yerine ham nöbetçiyi gösterecekti. Artık kaçış
  dizisiyle yazılı ve teste bağlı.

### Kapılar

```
flutter analyze → 0 bulgu
flutter test    → 415 test (406 → +9)
dart format     → temiz
node -e require → OK
```

Yeni kapılar: `copy_with_content_test.dart` (6) — düzeltmeden önce
**3'ü kırmızıydı** — ve `lost_marker_test.dart` (3).

### Grup sohbetleri denetlendi (kullanıcı sorusu)

| Belirti | Birebir | Grup |
|---|---|---|
| Medya görünmüyor | ✅ vardı | ❌ yok — grup çözmesi başlığa bakmaz |
| Ankete oy verilemiyor | ✅ vardı | ✅ **vardı** (anket zaten çoğunlukla grup özelliği) |
| Tek-gönderimlik görünmüyor | ✅ vardı | ❌ yok |
| Tek-gönderimlik dosya sunucuda kalıyor | ✅ | ✅ **ikisinde de** |

### ❌ GERİ ALINAN BULGU: "tek gönderimlik sunucuda silinmiyor"

**Bu bulgu YANLIŞTI, düzeltildi.** `cleanupSoftDeletedMedia`
fonksiyonu üretimde ETKİN ve `mediaUrl` boşaltılan `viewOnce`
mesajının dosyasını Admin SDK ile siliyor. Yani söz tutuluyor.

Yanılgının sebebi ÖLÜ KOD: istemcide başarısız olmaya mahkûm bir
`storage.delete()` denemesi ve yanında "gercekten sil" diyen bir
yorum vardı. Sunucu tarafına bakılmadan okununca "silme burada
yapılmalı ve olmuyor" sonucu çıkıyordu.

Ölü çağrı kaldırıldı; `functions/index.js` ile
`message_remote_datasource.dart` birbirine referans veriyor.

> **Ders:** ölü kod yalnızca gereksiz değil — olmayan bir arıza
> uydurabilir. Bir turluk yanlış öncelik buna mal oldu.

### ✂️ Profil fotoğrafında SERBEST kırpma (kullanıcı isteği)

Kırpma altyapısı zaten vardı (`ImagePickerHelper`) ve profil fotoğrafı
**1:1 kilitliydi**. İstek: oran ayarı olmasın, serbest kırpma olsun.

`KirpmaModu` enum'u eklendi: `serbest` / `kare` / `oranli`.
Profil → `serbest`, grup avatarı → `kare` (davranışı değişmedi).

> 🪤 **Oran düğmeleri `aspectRatioPresets: []` ile KALDIRILAMIYOR:**
> uCrop boş liste görünce KENDİ varsayılanlarını (4:3, 16:9…) geri
> koyuyor. Tek yol `hideBottomControls: true`; bedeli döndürme/ölçek
> sekmelerinin de gitmesi. Serbest modda alt çubuk gizli.
>
> ⚠️ Avatar `CircleAvatar` ile çiziliyor; o da görüntüyü kare alana
> kırpıp yuvarlağa oturtuyor. Kilidi kaldırmak kullanıcıya hangi
> BÖLGENİN kullanılacağını seçtirir, dairenin kendisini değiştirmez.

Ayrıca kırpma çökerse sessizce orijinale dönülüyordu; artık
`reportHandled` ile görünür (§4p).

### ✅ v15 DERLENDİ (2026-09-11 10:05)

| Alan | Değer |
|---|---|
| Paket | `build/app/outputs/bundle/release/app-release.aab` — 88,1 MB |
| Sürüm | versionName **1.0.4**, versionCode **15** |
| İçerik | §4az (kök neden) · grup denetimi · serbest profil kırpma · görünür Storage hatası |
| Kapılar | analyze 0 · **418** test · **116** kural testi · format temiz · node OK |

Doğrulamalar: Gradle çıkış kodu **0**, paket damgası **10:05** (tuzak
kontrolü), manifest `versionCode="15" versionName="1.0.4"`, `libapp.so`
taramasında yeni dizeler VAR ("Tek gonderimlik medya Storage…",
"Kırpma başarısız…").

**Play sürüm notları (`en-US`):**

```
Photos, videos, files and polls the other person could not open

• Media you send is now visible to the other person, and polls can be voted on. This was a single bug that stripped part of the message before it was decrypted.
• Profile photos can now be cropped freely before upload.
• Group chats were affected only by the poll problem; media there already worked.
```

### ✅ YAYIN ÖNCESİ SON DENETİM (2026-09-11) — ne ÖLÇÜLDÜ, ne ÖLÇÜLMEDİ

Kullanıcı "günlük kullanımda sıkıntı çıkmayacağından emin ol" dedi.
Ölçülenler:

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | ✅ 0 bulgu |
| Dart testleri | ✅ **419** |
| Firestore kural testleri | ✅ **116 passing** (bu oturumda gerçekten çalıştırıldı) |
| `dart format` | ✅ temiz |
| `node -e require` | ✅ OK |
| §4az hata sınıfı taraması (alan düşüren kopya) | ✅ `lib/` genelinde **0** — tarayıcı bilerek bozulan örnekle doğrulandı |
| Kırpma onay düğmesi kayboldu mu? | ✅ hayır — `menu_crop` ✓ **araç çubuğunda**, `hideBottomControls` yalnızca `controls_wrapper`'ı gizliyor (uCrop 2.2.10 layout'undan okundu) |
| Diğer kırpma akışları etkilendi mi? | ✅ hayır — sohbet fotoğrafı ve hikâye `allowEdit: true` ile `PhotoEditorScreen`'e gidiyor, `cropExisting`'e hiç uğramıyor |
| Sunucu tarafı dağıtım gerekiyor mu? | ✅ **hayır** — bugün yalnızca istemci dosyaları değişti (`firestore.rules` 10.09, `storage.rules` 13.08, `functions/` 10.09) |

### ⚠️ ÖLÇÜLEMEYEN: CİHAZDA AÇILIŞ TESTİ

`adb devices` **boş** — telefon bağlı değil. Önceki turlarda bu kontrol
gerçek arızalar yakalamıştı (R8 çökmesi, dispose, ölü dinleyici).
**Bu turda yapılamadı.**

Riski azaltan olgu: bugünkü değişikliklerin tamamı **saf Dart**.
R8 keep kuralları, native kod, manifest, bağımlılık listesi
DEĞİŞMEDİ — yani açılışta çökme sınıfına dokunan bir şey yok. Ama bu
bir çıkarım, ölçüm değil.

### 🪤 BU TURDA YAKALANAN KENDİ HATAM

Arka planda derleme sürerken, test anlamlılığını sınamak için
`message_repository_impl.dart`'ı geçici olarak BOZDUM. Derleme o
pencerede kaynağı okumuş olabilirdi. Paket **silindi** ve temiz
kaynaktan yeniden derlendi.

> **Kural:** arka planda derleme varken kaynak dosyalara dokunma.
> Dokunulduysa paketi at, yeniden derle — damgaya bakmak yetmez,
> çünkü paket damgası derlemenin BİTİŞ anını gösterir.

### 🚦 PLAY: v15 taslağı hazır (2026-09-11 10:2x)

Kapalı test → Alpha → **sürüm 11** taslağı: sürüm adı `15 (1.0.4)`,
`en-US` notları dolu, **kaydedildi**. Kalan tek adım kullanıcıda:
`.aab`'yi sürükle (88 MB, ajan yükleyemiyor) → "İleri" → **"1
değişikliği incelemeye gönder"**.

Paket: `app-release.aab`, **10:18:11**, versionCode **15**,
versionName **1.0.4**. Kaynak md5'i derleme bitiminde ve sonrasında
AYNI → derleme sırasında mutasyon YOK.

### ⏭️ Sırada

1. **v15 (1.0.4+15)** derlenip Play'e yüklenmeli. §4az olmadan §4ax'in
   etkisi sınırlı: başlık zaten siliniyordu.
2. Tek-gönderimlik tüketimi (3 ve 4) v15 sonrası **yeniden ölçülmeli**.
3. Denetlenmedi: `SecureMediaCache`'teki çözülmüş yerel kopya tüketimde
   siliniyor mu? Silinmiyorsa tek-gönderimlik medya cihazda kalıcıdır.

---

## ☀️ SABAH TURU (2026-09-11) — §4ax / §4ay + yazım hatası

Kullanıcının sıraladığı **üç iş**, sırayla. Hepsi bitti; **hiçbiri henüz
Play'de değil** — v14 derlemesi bekliyor.

| # | İstenen | Sonuç |
|---|---|---|
| 1 | Aramadaki IP paylaşım metni rahatsız ediyor, kaldıralım | 🔶 **kaldırılmadı, yumuşatıldı** (§4ay) — gerekçe aşağıda |
| 2 | `kaybederesen` → `kaybedersen` | ✅ `app_localizations.dart` |
| 3 | `secreter` hesabıyla yazınca gelen mesajlar alınmıyor | ✅ **§4ax** — yeniden el sıkışma tanınmıyordu |

### 1. IP metni: neden SİLİNMEDİ

Silinip silinemeyeceği önce **ölçüldü**:

* `functions/.env` **yok**,
* `firebase functions:config:get` → boş `{}`,
* hiçbir derleme betiğinde `SECRETER_TURN_*` dart-define'ı geçmiyor.

→ **TURN hiçbir yerde yapılandırılmamış.** Yani "IP adresin karşı tarafa
görünüyor" cümlesi **doğruydu** ve gerçek bir açığı bildiriyordu. Doğru
bir gizlilik açıklamasını silmek, kullanıcıyı yanıltmak olurdu.

Sorun metnin doğruluğunda değil, **tonundaydı**: uyarı sarısı + 🌐
simgesi "arama güvensiz / bir şey bozuk" gibi okunuyordu. Oysa doğrudan
bağlantı WebRTC'nin normal hâli ve ses her iki durumda da şifreli.

**Yapılan:** rozet kısa ve nötr bir etikete indi ("Doğrudan bağlantı",
camgöbeği, ⇄ + ⓘ), gerçek ödünleşim **dokununca açılan açıklamaya**
taşındı. 16 dilde iki yeni anahtar. Bilgi azalmadı — eski rozet
ödünleşimi hiç anlatmıyordu.

> **Kullanıcı kararı (2026-09-11):** *"Şimdilik erteleyelim, metni
> yumuşatalım."* TURN kurulumu **ertelendi**, açık **duruyor**
> (madde A / `TURN_KURULUMU.md`). TURN kurulduğunda rozet kendiliğinden
> "Aktarmalı bağlantı"ya döner.

**Kapı:** `test/features/call/ip_disclosure_test.dart` — 16 dilin
tamamında açıklamanın boşalmamasını ve **IP ibaresini kaybetmemesini**
zorunlu kılar. Bu, bir sonraki elde "yumuşatma"nın sessizce
"kaldırma"ya dönmesini engellemek için var.

### 3. `secreter` neden mesaj alamıyordu (§4ax)

§4au anahtarları hesap kapsamına aldıktan sonra iki farklı davranış
oluştu ve ayrım tam olarak buradaydı:

* kimliği **değişen** hesaplar → çalışıyordu,
* kimliği **koruyan** (eski anahtarları devralan) hesaplar → **mesaj
  alamıyordu**. `secreter` bunlardan biriydi.

Sebep: `ensureSessionFromHeader` oturumu yalnızca karşı tarafın **kimlik**
anahtarı değişince yeniliyordu. Karşı taraf oturumunu sıfırlayıp yeni bir
X3DH başlattığında kimlik **aynı** kalır; değişen **efemeral** anahtardır.
Ayırt edilemediği için yeniden el sıkışma sessizce yok sayılıyor ve
sohbet kalıcı olarak ölüyordu.

`SessionState` artık efemeral anahtarı da taşıyor. **Eski kayıtlarda
efemeral yok (`null`) ve o durumda eski davranış korunuyor** — aksi hâlde
her gelen başlıkta zincir sıfırlanır, yoldaki mesajlar çözülemezdi.

### Bu turun kapıları

```
flutter analyze   → 0 bulgu
flutter test      → 406 test (357 → +49: ip_disclosure_test)
dart format       → temiz
node -e require   → functions modülü yükleniyor
```

### 🪤 TUZAK: `pubspec.yaml`'a dokununca İLK release derlemesi ÇÖKER

**2026-09-11'de ölçüldü.** Sürüm numarasını `1.0.2+13` → `1.0.3+14`
yaptıktan sonraki ilk `flutter build appbundle --release` şununla düştü:

```
GeneratedPluginRegistrant.java:109: error:
package dev.flutter.plugins.integration_test does not exist
> Execution failed for task ':app:compileReleaseJavaWithJavac'
```

**Mekanizma:** `pubspec.yaml` değişince `flutter build` içeride örtük bir
`pub get` çalıştırır; o adım `GeneratedPluginRegistrant.java`'yı
**dev bağımlılıklarını DAHİL EDEREK** yeniden üretir. `integration_test`
bir dev bağımlılığıdır (`integration_test/app_test.dart` onu kullanır) ve
release derlemesinde AAR'ı sınıf yoluna eklenmez → Java derlemesi patlar.

**Ölçüm (varsayım değil):**

| An | `GeneratedPluginRegistrant.java` içinde `integration_test` | Sonuç |
|---|---|---|
| pubspec düzenlendikten sonraki 1. derleme | **var** (yazılma anı 01:10:32, derlemenin içi) | ❌ BUILD FAILED |
| değişiklik olmadan 2. derleme | **yok (0)** | ✅ |

**Çözüm:** `pubspec.yaml` değiştiyse derlemeyi **iki kez** çalıştır ya da
önce ayrı bir `flutter pub get`, sonra derleme.

> ⚠️ Bu tuzak, "arka plan derlemesi başarılı göründü ama Gradle düştü"
> hatasıyla birleşince tehlikelidir: paket klasöründe ÖNCEKİ derlemenin
> `.aab`'si durur ve yanlışlıkla o yüklenir. **Her derlemeden sonra hem
> çıkış kodunu hem paketin zaman damgasını doğrula.**

### ✅ v14 DERLENDİ (2026-09-11 01:13) — Play'e YÜKLENMEYİ bekliyor

| Alan | Değer |
|---|---|
| Paket | `build/app/outputs/bundle/release/app-release.aab` — **88,1 MB** |
| Sürüm | versionName **1.0.3**, versionCode **14** |
| İçindekiler | §4ax (yeniden el sıkışma) · §4ay (IP metni) · yazım hatası |
| Kapılar | analyze 0 · **406** Dart testi · format temiz · node OK |
| GIF | ⚠️ **KAPALI** — `GIPHY_API_KEY` verilmedi (önceki yayınlar da öyleydi) |

**Doğrulamalar (varsayım değil, ölçüm):**

* Gradle çıkış kodu **0** ve paketin zaman damgası **01:13** — yani
  klasördeki `.aab` gerçekten bu derlemenin (yukarıdaki 🪤 tuzağı
  yüzünden bu kontrol şart).
* Birleştirilmiş manifest: `versionCode="14" versionName="1.0.3"`.
* `libapp.so` taraması (Dart, Türkçe metinleri **UTF-16LE** saklar —
  düz `grep` YANLIŞ "yok" der):

  | Aranan | Sonuç |
  |---|---|
  | `call_ip_visible_detail` | ✅ var |
  | "Doğrudan bağlantı" / "Aktarmalı bağlantı" | ✅ var |
  | "IP adresin karşı tarafla paylaşılır" | ✅ var (bilgi korunmuş) |
  | "IP adresin karşı tarafa görünüyor" (eski) | ✅ yok |
  | "kaybedersen" | ✅ var — "kaybederesen" ✅ yok |

**Cihaza APK KURULMADI, bilinçli:** telefondaki sürüm Play'den geldi,
yerel imzayla imzalanmış APK onun üzerine kurulamaz (Play App Signing).
Bu paketin cihaza ulaşmasının tek yolu Play.

### 🚦 PLAY DURUMU — ✅ **14 (1.0.3) YAYINDA** (2026-09-11 01:53)

Kapalı test → Alpha kanalında **sürüm 14 (1.0.3) kullanıma sunuldu**
(11 Eyl 01:53, 117 ülke/bölge). İçinde §4ax + §4ay + yazım hatası var.

**Kullanıcının kendi doğrulaması (2026-09-11 sabaha karşı):** uygulama
telefondan SİLİNDİ, Play'den yeniden kuruldu, **iki YENİ hesap** açıldı ve
aynı telefondan kendine mesaj atıldı → **sorunsuz.**

> ⚠️ Bu test neyi kanıtlar, neyi KANITLAMAZ (karıştırılmasın):
> * ✅ **Kanıtlar:** paket sağlam, E2EE uçtan uca çalışıyor ve §4au
>   kapsamlama tutuyor — aynı cihazdaki iki hesap AYRI kimlik alıyor.
>   (§4au'nun kendisi tam bu senaryonun ÇÖKMESİYLE bulunmuştu.)
> * ❌ **Kanıtlamaz:** §4ax. Yeni açılan hesapların eski anahtarı yoktur,
>   kimliklerini "korumazlar" ve oturumları sıfırdan kurulur. §4ax ise
>   YALNIZCA kimliğini koruyan hesap + karşı tarafın yeniden el sıkışması
>   durumunda tetikleniyordu. Yani bu, hep çalışan kolay yol.
>
> Gerçek sınav testçilerde: **eski hesap + zaten bozulmuş oturum.**

### 🚦 (eski kayıt) PLAY DURUMU — TEK TIK KALMIŞTI

Kapalı test → Alpha → **sürüm 10** taslağı hazırlandı ve **Yayın özetine
gönderildi**. Kalan tek işlem kullanıcının onayı:
**"1 değişikliği incelemeye gönder"**.

| Adım | Durum |
|---|---|
| Paket yüklendi | ✅ `App bundle 14 (1.0.3)` · API 24+ · hedef SDK 36 · 3 ABI |
| Sürüm adı | ✅ `14 (1.0.3)` |
| Sürüm notları (`en-US`) | ✅ dolduruldu |
| Önizleme | ✅ **"Yayınlamaya hazır"** — engelleyici hata yok |
| Cihaz kaybı | ✅ **0** (telefon 12.475 · tablet 6.679 · otomobil 8 · Chromebook 72 — hepsi aynı) |
| Kullanıma sunum | 100 % (kapalı test, 117 testçi) |
| İncelemeye gönderme | ⛔ **kullanıcıya bırakıldı** |

⚠️ **`.aab` ajan tarafından YÜKLENEMEZ:** tarayıcı dosya yükleme aracı
10 MB ile sınırlı, paket 88 MB. Denendi ve reddedildi. Paketi her seferinde
kullanıcı sürükleyecek. (Kalıcı çözüm istenirse: Play Developer API +
servis hesabı ile `androidpublisher.edits.bundles.upload`.)

### 📝 Play sürüm notları (mağaza dili yalnızca `en-US`)

```
Fixes for chats that showed "cannot be decrypted"

• Messages from some contacts stayed unreadable after the previous update. Fixed. Both people need this version, and one of you has to send a new message in the affected chat to repair it.
• The call screen now names the connection type and explains what it means when you tap it, instead of only showing a warning.
• Fixed a Turkish typo on the recovery key screen.
```

### ⏭️ SIRADAKİ ADIM: v14

§4ax **cihazda değil**. `secreter` hesabının onarılması için:

1. ✅ v14 derlendi (yukarıda) — Play'e **yüklenmesi** gerekiyor,
2. **her iki taraf** güncellemeli,
3. **birinin yeni mesaj yazması** gerekir (§4av'nin aynı koşulu).

---

## 🌙 GECE TURU (2026-09-10 → 11) — §4au / §4av / §4aw

Testçilerden gelen "mesaj çözülemiyor" şikâyetiyle başlayan tur.
**Dört hipotez veriyle ÇÜRÜTÜLDÜ**, beşincisi doğru çıktı.

### Çürütülen hipotezler (kayda geçsin, tekrar denenmesin)

| Hipotez | Nasıl çürütüldü |
|---|---|
| Annenin sürümünde §4e düzeltmesi yok | §4e erken bir bölüm; 1.0.1'de olup olmadığı BELİRLENEMEDİ — sürüm geçmişi tutulmuyor |
| Eksik `signedPreKeySignature` mesajlaşmayı engelliyor | Kod geçiş dönemini AÇIKÇA ele alıyor: imza yoksa oturum kurulur, `verified:false` işaretlenir |
| `claimPreKey` patlıyor | Fonksiyon günlüğü hatasız; yalnızca App Check uyarısı (enforcement kapalı) |
| Başlıktan yeniden kurma yeter | Cihaz günlüğü: kurtarma HİÇ tetiklenmedi — gelen mesajlarda başlık YOK |

**Doğru olan:** E2EE kimlik anahtarları hesap kapsamsızdı (§4au) ve
bozulan oturumun kurtarma yolu yoktu (§4av).

### Bu turda üretime çıkanlar

* `firestore.rules` — `notBlockedBy` null koruması (§4at) — **dağıtıldı**
* `usernames` dizini 6 → 23 (madde 12) — **dolduruldu**
* Play kapalı test **8 (1.0.2)** — **yayında** (22:40)
* Play kapalı test **13 (1.0.2)** — ✅ **YAYINDA** (11 Eyl 00:34);
  testçiler güncelledi, **mesajlaşma çalışıyor**

### ⚠️ AÇIK VE ÖNEMLİ

**1. Yama, tasarım düzeltmesi değil (§4av).** Doğru çözüm: oturum
onaylanana kadar başlığın HER mesaja eklenmesi. Bugünkü yama iki tarafın
da güncellemesini VE birinin yeni mesaj yazmasını gerektiriyor.

**2. ~~"Sohbeti temizle" bozuk (§4aw)~~ — ✅ ÇÖZÜLDÜ (§4bu).**

**3. ✅ DOĞRULANDI (2026-09-11).** Sürüm 13 kapalı teste sunuldu
(00:34), testçiler güncelledi ve **mesajlaşma çalıştı**. Yani testçilerin
kendi aralarındaki sorun gerçekten aynı kökten geliyormuş; §4au + §4av
onu da kapattı.

> 🔍 Bu, gece boyunca ÖLÇÜLEMEYEN tek varsayımdı ve doğru çıktı. Ama
> doğru çıkması, ölçülmüş olmasıyla aynı şey değildi — o yüzden
> "varsayıldı" diye yazılmıştı. Kayıt böyle tutulmalı.

**4. Sürüm geçmişi tutulmuyor.** "Hangi düzeltme hangi pakette" sorusuna
bu gece İKİ kez cevap verilemedi ve her ikisinde de teşhis tıkandı.
Bu, ayrı bir iş olarak duruyor (bkz. madde 11).

### Testçilere söylenmesi gerekenler

1. **Herkes güncellemeli** — tek taraf yetmez
2. **Bozuk sohbeti onarmak için birinin yeni mesaj yazması** gerekir
3. **Eski mesajlar geri gelmez**

---

## 📱 CİHAZ GÜNLÜĞÜ TURU (2026-09-10 akşam) — §4as

`adb logcat` ile gerçek kullanım izlendi. **Beş arıza çıktı, hiçbiri
statik incelemede görünmüyordu.** Ayrıntı: `GUVENLIK_DUZELTMELERI.md` §4as.

| # | Belirti | Kök neden | Durum |
|---|---|---|---|
| 1 | Sürekli çökme (15+/tur) | R8 full mode Gson `TypeToken` alt sınıfını buduyor | ✅ kural eklendi |
| 2 | Karşı taraf seni hep "yazıyor" görüyor | `dispose()` içinde `ref` → dispose yarıda kesiliyor | ✅ bildirici initState'te |
| 3 | Mesaj "gitmiyor" / saat donuyor / anlık gelmiyor | Hesap değişiminde TÜM dinleyiciler ölüyor, kimse kurmuyor | ✅ iki geçiş yolunda da invalidate |
| 4 | Foto/video/ses açılmıyor | Şifreli medya çözülmeden oynatıcıya veriliyordu | ✅ üçü de `SecureMediaCache` ile |
| 5 | "Dizin oluşturulmalı" diyen izin hatası | Kod yanlış teşhis raporluyor | 🟡 **AÇIK** |

### 🔑 Bu turun asıl dersi

Kullanıcının **üç ayrı** "gitmiyor" şikâyeti (saat donması, anlık
gelmeme, GIF/video/ses gitmemesi) **tek bir ölü stream'di**. Bunu
anlamanın tek yolu Firestore Console'da mesajların `status: "sent"`
olarak DURDUĞUNU görmekti. Sunucudaki gerçeğe bakılmadan üçü de
"gönderim hatası" sanılıyordu.

İkinci ders: §4aq/4'te olduğu gibi burada da **eskimiş bir yorum** yanlış
yönlendirdi. `messagingNotifierProvider` "bilerek invalidate edilmiyor"
diyordu; gerekçesi olan `markAsRead` çağrısı çoktan kaldırılmıştı ama
yorum kalmıştı.

### ⚠️ Kapanmamış uç

v8'de açılıştan hemen sonra hâlâ 3 adet `Failed to decode image` var
(mesaj medyası testleri geçmeden önce). Kaynağı bulunamadı; muhtemelen
avatar ya da GIF karesi. Mesaj medyası yolları temiz.

### Cihaz test döngüsü (işe yarayan yöntem)

```bash
adb logcat -c && adb logcat -v time > logcat.txt &     # yakala
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# ... kullanıcı test eder ...
grep -c "TypeToken must be created" logcat.txt          # önce/sonra SAY
```

Belirtiyi tarif etmek yerine **sayarak** ölçmek, üç düzeltmenin de
gerçekten tuttuğunu kanıtladı (15+ → 0, var → 0).

---

## 🔎 AKIŞ DENETİMİ (2026-09-10) — §4ar

"Kullanıcının deneyimlediği her şey doğru mu" sorusuyla akış akış
yürütülen denetim. **Bir hata çıktı, düzeltildi.**

### Bulunan: aramada herkes hep "çevrimiçi"

`users` belgesinde iki çevrimiçi alanı vardı; `UserModel.fromMap` ÖLÜ
olanı (`isOnline`) okuyordu. Ayrıntı ve düzeltme: `GUVENLIK_DUZELTMELERI.md`
§4ar. Yan etkisi ayrıca gizlilikti: *"varlığımı paylaş"* ayarı arama
ekranında hiç geçerli değildi.

### Doğrulanan (sorun çıkmadı)

| Akış | Kanıt |
|---|---|
| Firestore kuralları | **113 kural testi emülatörde geçti** |
| Mesaj gönderme, emoji tepkileri | kural testleri + `onlyChanges` incelemesi |
| Yazıyor göstergesi | uçtan uca bağlı (`messaging_screen:210` ↔ `presenceProvider`) |
| Kanal / grup oluşturma, rol değişimi | kural testleri (§4an dahil) |
| Arama (WebRTC sinyalleşme) | kural testleri (ICE, gelen arama sorgusu, grup) |
| Koleksiyon kapsaması | kodun kullandığı 18 koleksiyonun hepsinde kural var |
| Storage yolları | 4 yolun 4'ü kural kapsamında |
| Tek görüntülük medya | `cleanupSoftDeletedMedia` telafi ediyor, dağıtılmış |

### 🟡 Kayda geçen, bugün etkisi olmayan

* **`issueEntitlement` DAĞITILMAMIŞ.** Kodda 15 fonksiyon, üretimde 14.
  İstemci onu çağırmıyor (yalnızca `claimPreKey`, `deleteAccountData`,
  `getTurnCredentials` kullanılıyor, üçü de dağıtılmış). **Premium
  açılırsa dağıtmayı unutma.**
* **Avatar/hikâye yüklemede `contentType` açıkça verilmiyor.** Eklenti
  dosya uzantısından çıkarıyor, kural `image/*` şart koşuyor. Üretilen
  dosyalar `.jpg`/`.png` olduğu için çalışıyor — ama kırılgan.
  `SettableMetadata(contentType: 'image/jpeg')` bunu kapatır.

### ⚠️ Bu denetimin SINIRI

Denetim **statiktir**. Bugünkü en ağır iki hata — Storage servisler arası
izni (§4aq/1) ve E2EE anahtar kapsamı (§4aq/3) — **hiçbir statik
incelemeyle bulunamazdı**: biri sunucu yapılandırmasıydı, diğeri ancak
uygulama kapatılıp açılınca ortaya çıkıyordu. Rapor "her şey doğru"
demez, "kontrol edilebilenler doğru" der. Cihazdaki elle doğrulama
listesi (yukarıda) hâlâ asıl kapıdır.

Denenip **işe yaramayan** iki yöntem de kayda geçsin: koleksiyon/kural
otomatik karşılaştırması yanlış alarm verdi (iç içe `match` bloklarını
görmüyor), sessiz-`catch` taraması 92 sonucun çoğu meşru olduğu için
sinyal üretmedi. Alan adı uyuşmazlıkları ancak **yazan uç ile okuyan uç
yan yana konunca** görünüyor.

---

## 🧪 CİHAZ TESTİNİN ÇIKARDIKLARI (2026-09-10) — §4aq

Kapalı test paketi hazırken cihazda elle denenince **altı ayrı arıza**
çıktı. Beşi kodda düzeltildi, biri yapılandırmaydı.

| # | Belirti | Kök neden | Durum |
|---|---|---|---|
| 1 | "Medya yüklenemedi" (resim + dosya) | Storage kuralları `firestore.get()` kullanıyor; servisler arası çağrı izni YOKTU → her yükleme reddediliyordu | ✅ Console'dan izin verildi |
| 2 | Saat ikonu hiç geçmiyor | Kuyruk boşaltılırken `status: sending` olduğu gibi gönderiliyordu | ✅ `copyWithStatus(sent)` |
| 3 | Kendi mesajım "çözülemiyor" | `register()` E2EE anahtar kapsamını kurmuyordu | ✅ `setActiveAccount(uid)` |
| 4 | Çıkış sonrası kapsam eski hesapta kalıyor | `signOut()` sıfırlamıyordu | ✅ `setActiveAccount(null)` |
| 5 | Yeni hesabın adı aramada çıkmıyor | `users` yazımı patlarsa `usernames` dizini öksüz kalıyordu | ✅ geri alma eklendi |
| 6 | GIF/çıkartma boş | Arayüz `GiphyService.isEnabled`'ı kontrol etmiyordu | ✅ kapıya bağlandı |

> 🔍 **#1 KOD DEĞİL, YAPILANDIRMA.** `firebase deploy --only storage`
> kuralları yükler ama servisler arası izni VERMEZ. Kurallar dağıtılmış
> görünürken medya sessizce ölü kalır. Yeni proje/yeni kovada tekrar
> gerekir — **dağıtım kontrol listesine eklendi (§6)**.
>
> Teşhis imzası: `avatars/` ve `stories/` çalışır (yalnızca `signedIn()`),
> `chats/**` ve `group_avatars/**` çalışmaz (`isChatMember` kullanır).

### ⚠️ Test edilemeyen kaldı

`AuthService` statik `FirebaseFirestore.instance` / `FirebaseAuth.instance`
tekillerine bağlı; `register()` ve `signOut()` **birim testi yazılamıyor**.
#3, #4 ve #5 bu yüzden yalnızca kod okumasıyla doğrulandı — kapsam
mekanizmasının kendisi `account_scope_test.dart` ile sabitlendi ama
`register()`'ın onu ÇAĞIRDIĞI test edilmiyor. Bunu kapatmak
`AuthService`'i enjekte edilebilir hâle getirmeyi ister (ayrı iş).

**Elle doğrulama şart (§6 listesine ek):**
1. Yeni hesap aç → mesaj gönder → **uygulamayı tamamen kapat, aç** →
   kendi mesajın hâlâ okunabiliyor mu? (#3)
2. Hesap ekle → yeni hesapta mesaj → kapat/aç → okunabiliyor mu? (#4)
3. Çevrimdışıyken mesaj at → çevrimiçi ol → saat ikonu tike dönüyor mu? (#2)
4. Grup fotoğrafı yükle (#1 teşhisini doğrular)
5. Kayıt sırasında ağı kes → ad "alınmış" diye kilitlenmiş mi? (#5)

---

### 🔴 10. ARAMA ARKA PLANDA SÜRMÜYOR (§4ap'te ortaya çıktı)

§4ap'te Play beyanı incelenirken ölçüldü: manifestte
`FOREGROUND_SERVICE_MICROPHONE` / `FOREGROUND_SERVICE_CAMERA` izinleri
vardı ama **`foregroundServiceType` beyan eden hiçbir servis yoktu** ve
kodda `startForeground()` hiç çağrılmıyordu. Manifest yorumu bu izinlerin
"aramanın ekran kapanınca düşmesini" çözdüğünü söylüyordu; çözmüyordu.

Yani şu an: **kullanıcı arama sırasında uygulamadan çıkarsa ya da ekranı
kapatırsa Android 14+ mikrofon/kamera erişimini keser ve arama düşer.**
Atıl izinler §4ap'te kaldırıldı (Play'de yanlış beyan zorunluluğu
doğuruyorlardı) — ama **asıl eksik iş duruyor.**

**Yapılacak (sırayla):**

1. `android:foregroundServiceType="camera|microphone"` beyan eden bir
   `Service` yaz (Kotlin, `android/app/src/main/kotlin/...`).
2. Aramanın başında `startForeground()`, bitiminde `stopSelf()` — çağrı
   durumu zaten `CallService`/sinyalleşme katmanında biliniyor (§4am'de
   sözleşmesi teste bağlandı).
3. `FOREGROUND_SERVICE_MICROPHONE` / `_CAMERA` izinlerini manifeste GERİ
   ekle — bu sefer karşılığı olduğu için.
4. Play Console → **Uygulama içeriği → Ön plan hizmeti izinleri**
   beyanını doldur (Kamera: "arka planda kamera görüntü akışı",
   Mikrofon: "arka planda ses girişi"). Artık doğru beyan olur.
5. Gerçek cihazda ölç: arama sırasında ana ekrana çık, 30 sn bekle, ses
   kesiliyor mu?

> ⚠️ **Beyanı 1–3 yapılmadan doldurma.** Beyan edip karşılığını
> yazmamak, Play'de "yanlış beyan" ihlâlidir ve uygulamanın
> kaldırılmasına yol açar. §4ap'in kaldırma kararının sebebi buydu.

### 🔴 11. BOZULAN E2EE OTURUMUNUN KURTARMA YOLU YOK

**GERÇEK KULLANICIDA GÖRÜLDÜ (2026-09-10).** Kullanıcı, Play kapalı
testinden **1.0.1** kullanan birine (annesi) mesaj attı; karşı tarafta
mesaj **"bu mesaj cihazda çözülemiyor"** olarak düştü.

#### Neden ciddi

`E2EESessionService.resetSession(chatId)` **kodda var ama HİÇBİR YERDEN
ÇAĞRILMIYOR** — ölü kod:

```bash
grep -rn "resetSession" lib --include=*.dart
# lib/services/e2ee_session_service.dart:359  ← yalnızca tanım
```

Yani bir sohbetin E2EE oturumu bozulduğunda kullanıcının uygulama
içinde onarma yolu **yoktur**. `GUVENLIK_DUZELTMELERI.md` §4e bunu zaten
yazıyor: *"hiçbir hata, hiçbir uyarı, kurtarma yolu yok."* §4e o cümleyi
ÇÖZME tarafı için yazmıştı; kullanıcıya sunulan bir kurtarma eylemi ise
hâlâ eklenmedi.

Elde kalan tek çare **uygulamayı silip yeniden kurmak** — ve bu,
kurtarma anahtarı yoksa **hesabı kalıcı olarak kaybetmek** demek
(anahtarlar yalnızca cihazda). Yani "sohbetim çözülmüyor" sorununun
bedeli "hesabımı kaybettim" olabiliyor.

#### Yapılacak

1. Sohbet menüsüne **"Güvenli oturumu sıfırla"** eylemi ekle →
   `resetSession(chatId)` + karşı tarafa yeni başlıkla ilk mesaj.
2. Sıfırlamanın **ne yaptığını** açıkça söyle: eski mesajlar
   çözülemez KALIR, yalnızca bundan sonrası düzelir. (Yanlış beklenti
   kurmak, sessiz hatadan daha kötüdür.)
3. Güvenlik uyarısı: oturum sıfırlama **güvenlik numarasını değiştirir**;
   ekran bunu göstermeli ki kullanıcı MITM ile karıştırmasın.
4. Otomatik yol da düşünülmeli: aynı sohbette üst üste N mesaj
   çözülemiyorsa kullanıcıya "oturumu sıfırla" öner.

> ⚠️ **TEŞHİS EDİLEMEDİ.** Annenin cihazının günlüğü alınamadığı için
> KÖK NEDEN bilinmiyor. Gönderen taraf temizdi (şifreleme hatasız,
> "anahtar paketi yok" uyarısı da yok). Olasılıklar: kimlik anahtarı
> değişimi, tüketilmiş tek kullanımlık ön-anahtar, ya da yerel
> anahtarlarla sunucudaki paketin ayrışması. **Çözülmemiş.**
>
> Not: §4e'deki "gelen başlıkla oturumu yenile" düzeltmesinin 1.0.1'de
> olup olmadığı belirlenemedi — sürüm geçmişi tutulmuyor. Hangi
> düzeltmenin hangi pakette olduğunu bilmek bu tür teşhislerde şart;
> bunu kayıt altına almak ayrı bir iş.

### ✅ 12. `usernames` DİZİNİ DOLDURULDU (2026-09-10, kapandı)

**SONUÇ:** dizin **6 → 23 kayda** çıktı. Aritmetik doğrulandı:
6 mevcut + 17 yazılan = 23, ve 26 hesap − 3 boş adlı = 23.

Çakışma (`secreter` iki hesapta) önce elle çözüldü: eski hesabın
(`hsnfyZxo…`, bio *"Secreter Official"*, son görülme 8 Ağu) `username`
alanı **`secreter_official`** yapıldı. Script çakışma varken yazmayı
zaten reddediyordu.

#### Nasıl yapıldı — anahtar İNDİRİLMEDİ

İlk plan `tools/backfill_usernames.js` idi ama Admin SDK erişimi için
servis hesabı ANAHTARI gerekiyordu; anahtar indirmek makinede kalıcı bir
sır bırakmak demek. Onun yerine **geçici bir Cloud Function** kullanıldı:

1. `_admin/{id}` tetikleyicisi olarak dağıtıldı (Cloud Functions zaten
   Admin SDK yetkisine sahip — anahtar hiç var olmadı)
2. Konsoldan `_admin/backfill` belgesi, `apply: false` → **kuru çalışma**
3. Rapor `_adminRaporlar/backfill`'e yazıldı, okundu, doğrulandı
4. `apply: true` → 17 kayıt yazıldı
5. Fonksiyon `firebase functions:delete` ile **silindi**, koddan çıkarıldı
6. `firebase firestore:delete` ile iki geçici koleksiyon **silindi**

> 🔑 **NEDEN GÜVENLİYDİ:** `_admin` koleksiyonu güvenlik kurallarında
> TANIMSIZ, yani istemciler oraya yazamaz (kural testi:
> *"tanımsız koleksiyon varsayılan olarak KAPALI"*). Tetikleme yalnızca
> konsoldan/Admin SDK ile mümkündü.
>
> ⚠️ Rapor AYNI belgeye değil `_adminRaporlar`'a yazıldı — aynı belgeye
> yazmak tetikleyiciyi tekrar çalıştırıp SONSUZ DÖNGÜ olurdu.

#### Kalan

**3 hesabın kullanıcı adı BOŞ** (`AtaUtADd…`, `V8RUF6KI…`, `qYbF9GVC…`).
Dizine girmediler ve aramada bulunamazlar. `qYbF9GVC…` kullanıcının
kendi ikinci hesabı — nasıl boş kaldığı incelenmedi.

`tools/backfill_usernames.js` dosyası duruyor: aynı iş bir daha
gerekirse (ya da servis hesabı anahtarı zaten varsa) kullanılabilir.

### 🗑️ (kapandı) Eski 12. madde metni

**ÜRETİM VERİSİNDEN ÖLÇÜLDÜ (2026-09-10, Firestore Console):**

| Koleksiyon | Kayıt |
|---|---|
| `users` (hesaplar) | **20** |
| `usernames` (arama dizini) | **1** |

20 hesabın **19'unun** dizinde kaydı yok. Ayrıca:
* **İki hesap aynı adı taşıyor:** `secreter` → `bWCIo1l9…` ve `hsnfyZxo…`
* Bir hesabın kullanıcı adı **boş** (`AtaUtADd97O1tS`)

#### Üç sonucu

1. **O 19 kişi aramada BULUNAMIYOR.** `findUserByUsername` önce
   `usernames/{ad}` dizinine bakar; kayıt yoksa `null` döner. Kullanıcının
   "adı arattım çıkmadı" şikâyetinin gerçek sebebi budur.
   ⚠️ Bu, §4aq/4'te tahmin edilen "öksüz dizin kaydı"ndan FARKLI: kayıt
   öksüz değil, **hiç yok**. O tahmin yanlıştı, ölçüm düzeltti.
2. **Ad tekilliği fiilen çalışmıyor.** Dizin boş olduğu için var olan bir
   ad "müsait" görünür. İki `secreter` hesabı böyle oluştu.
3. **Taklit yüzeyi açık.** Biri, var olan bir kullanıcının adıyla hesap
   açabilir; atomik rezervasyon (§4l) onu durdurmaz çünkü dizin boş.

#### Muhtemel sebep

`usernames` dizini sonradan eklendi (§4l atomik rezervasyon) ve **eski
hesaplar için geriye dönük DOLDURULMADI**. Bugün açılan hesabın kaydı var
çünkü yeni akıştan geçti.

#### Yapılacak

1. **Geriye dönük doldurma (backfill).** `users` koleksiyonunu tarayıp
   `username` alanı dolu olan her hesap için `usernames/{ad}` oluştur.
   Admin SDK ile tek seferlik bir script ya da geçici bir Cloud Function.
2. **ÇAKIŞMALARI ÖNCE ÇÖZ.** İki `secreter` hesabı var; hangisinin adı
   kalacağına karar verilmeli (ilk oluşturulan mı?). Backfill körlemesine
   yazarsa biri sessizce diğerinin adını kapar.
3. **Boş kullanıcı adlı hesap** (`AtaUtADd97O1tS`) ayrıca ele alınmalı.
4. Backfill'den SONRA tekillik gerçekten sağlanmış olur.

> ⚠️ **TESTÇİ SAYISI ARTMADAN YAPILMALI.** Dizin boş kaldıkça her yeni
> kayıt, var olan bir adı kapabilir ve çakışma sayısı artar.

### 🔴 13. ESKİ SÜRÜMDE HESAP AÇILAMIYOR (kural ↔ istemci sürüm kayması)

**GERÇEK TESTÇİLERDE (2026-09-10):** kayıt ekranında
*"Kullanıcı adı kontrol edilemedi"* + `cloud_firestore/permission-denied`.

`AuthService.isUsernameAvailable` iki okuma yapar
(`releasedUsernames/{ad}` ve `usernames/{ad}`); **ikisi de kuralda
`signedIn()` şartına bağlı**. `permission-denied` demek, isteğin
Firestore'a **kimliksiz** ulaştığı demektir.

Mevcut kodda bunun çaresi var:

```dart
// OTURUM GARANTİSİ: ... gerekirse burada anonim oturum açılır.
await _ensureAnonymousSession();
```

Bu bir DÜZELTME — yani bir zamanlar yoktu. En tutarlı açıklama:
**kurallar `signedIn()` ile sertleştirildi, istemcideki oturum garantisi
daha sonraki bir sürümde geldi.** 1.0.1'de kalan testçiler kimliksiz
sorgu atıyor ve reddediliyorlar.

**Elenenler (ölçüldü):** Firebase Auth'ta Anonim ve E-posta/Parola
sağlayıcılarının **ikisi de Enabled**; sağlayıcı engel değil.
Kullanıcının kendi v8 cihazında aynı akış çalışıyor.

> ⚠️ **KANITLANAMADI:** `_ensureAnonymousSession`'ın hangi sürümde
> eklendiği belirlenemedi — sürüm geçmişi tutulmuyor (bkz. madde 11).
> Bugün bu duvara İKİNCİ kez çarpıldı.

#### Kural gevşetilmemeli

`usernames/{ad}` dokümanı **`uid` içerir**. Kimliksiz okumaya açmak,
herkesin bir kullanıcı adını uid'ine bağlamasına izin verir — gizlilik
uygulamasında kabul edilemez. Alan bazlı filtreleme kurallarda yok.

#### Çözüm

Yeni sürümü dağıtmak. Bu madde, kapalı test sürümünü göndermenin artık
"iyi olur" değil **engelleyici** olduğunu gösterir: yeni testçi hiç
hesap açamıyor.

### 🟡 14. Diğer (küçük, isteğe bağlı)
* **Canlı sesli mesaj transkripsiyonu** — kullanıcı istedi. Android'in
  `SpeechRecognizer`'ı KAYITLI DOSYAYI çeviremez (mikrofondan çalışır);
  yapılabilir sürüm "kayıt sırasında canlı çeviri". Karar bekliyor.
* Güvenlik numarası için QR OKUYUCU — kamera bağımlılığı gerekir;
  APK boyutu ve R8 riski nedeniyle bilinçli ertelendi
* iOS desteği — büyük iş

> **YAPILMAYACAKLAR (gerekçeli):**
> * *Ekran görüntüsü bildirimi* — ekran görüntüsü zaten varsayılan
>   engelli, bildirim UYGULANAMAZ (değiştirilmiş istemci göndermez;
>   Signal bu yüzden koymuyor), minSdk 24'te güvenilmez.
> * *Sohbet başına kendi takma adın* — `senderId` her mesajda var ve
>   `users/{uid}` okunabilir olduğu için SAHTE koruma olurdu. Yerel
>   kişi etiketi ise ZATEN VAR (`core/prefs/user_aliases.dart`).

---

## 4. ⚠️ MUTLAKA BİLİNMESİ GEREKENLER

### IDE düzenlemeleri geri alıyor (TEKRARLAYAN SORUN)
Çalışma boyunca **birçok kez** yapılan düzenlemeler geri geldi: i18n
anahtarları (16 tanesi bir kerede), `_picker` temizliği, UTC zaman
damgaları, `photo_editor_screen.dart` importu.

**Sebep:** Android Studio açıkken bellek içi tamponunu diske yazıyor.
**Çözüm:** Kod düzenlemesi yapılacaksa **IDE'yi kapat**. Düzenleme
sonrası `flutter analyze` çalıştırıp doğrula.

### minSdk 24 — platform API seviyesi kontrol et
`compileSdk` yüksek olduğu için derleme geçer ama eski cihazda çöker.
Yakalanan örnek: `MediaMetadataRetriever.use{}` (AutoCloseable) API 29+;
Android 7–9'da `NoSuchMethodError` verirdi. Analyzer bunu YAKALAMAZ.

### Cihazda arayüz SÜRÜLEMEZ — `adb input` MIUI'de engelli
`adb shell input tap/text` şu hatayı verir:
`SecurityException: Injecting input events requires ... INJECT_EVENTS`.
Yani ekranları gezerek otomatik doğrulama YAPILAMAZ.

**Girdi gerektirmeden okunabilenler:**
* `adb shell uiautomator dump /sdcard/ui.xml` → ekrandaki metinler
  `content-desc` alanlarından okunur. Sohbet listesi başlıkları bu
  yolla doğrulandı. ⚠️ Git Bash `/sdcard/` yolunu bozar (Windows yoluna
  çevirir) — PowerShell kullan ya da `MSYS_NO_PATHCONV=1` ver.
* Ekran görüntüsü SİYAH gelir — `FLAG_SECURE` çalışıyor demektir,
  arıza değil.
* 🐞 **Bir metnin derlemeye girip girmediği — ESKİ TARİF YANLIŞTI.**
  Burada `grep -a "metin" app-release.apk` yazıyordu. 2026-09-10'da
  ölçüldü: bu **yanlış negatif** veriyor ve "çeviriler derlemeye
  girmemiş" gibi görünmesine yol açıyor. İki ayrı sebep:

  1. **APK bir zip'tir.** Dizeler `lib/<abi>/libapp.so` içinde; önce
     ayıklamak gerekir.
  2. **Dart dizeleri ÜÇ FARKLI kodlamada saklar.** Kod noktalarına
     göre `OneByteString` (ASCII/**Latin-1**) ya da `TwoByteString`
     (**UTF-16LE**). Yani `ş`/`ı` içeren Türkçe bir dize UTF-16LE,
     `ä` içeren Fince bir dize **Latin-1**, saf ASCII bir İngilizce
     dize ise düz bayt olarak durur. Tek kodlamaya bakmak, dize
     derlemede olsa bile "yok" dedirtir.

  Doğrusu — üç kodlamayı da dene:
  ```bash
  unzip -o -q app-arm64-v8a-release.apk "lib/arm64-v8a/libapp.so"
  python -c "
  import io,sys
  b=io.open('lib/arm64-v8a/libapp.so','rb').read(); t=sys.argv[1]
  for e in ('latin-1','utf-8','utf-16-le'):
      try:
          if t.encode(e) in b: print('BULUNDU', e); break
      except UnicodeEncodeError: pass
  else: print('YOK')
  " "Bu kişiyi de engelle"
  ```

**ÇÖZÜM (2026-09-04): ayarı açtıktan sonra CİHAZI YENİDEN BAŞLAT.**
Yeniden başlatma sonrası `input tap` çalıştı ve arayüz otomatik
doğrulanabildi. Ayrıca cihazın ADB arayüzünü hiç açmadığı bir durum da
yaşandı; USB **ürün kimliğinden** anlaşılıyor:
`PID_FF48` = MTP + ADB (doğru), `PID_FF40` = yalnızca MTP (ADB yok).
`adb devices` boşsa önce buna bak:
`Get-PnpDevice -PresentOnly | ? InstanceId -match 'VID_2717'`

**Önceki başarısız deneme (2026-09-02):** MIUI → Geliştirici
seçenekleri → "USB hata ayıklama (Güvenlik ayarları)" açıldı ama
`input tap` yine `SecurityException` verdi — adb sunucusu tamamen
yeniden başlatıldıktan sonra bile. Ölçüm:

```
global/adb_enabled = 1        development_settings_enabled = 1
secure/adb_install_need_confirm = null   ← açık olsaydı 0 olurdu
Mi hesabı: VAR (com.xiaomi)
```

Yani anahtar **kalıcı olmamış**; MIUI'de bu tipik. Tekrar denenecekse
ayarı açtıktan sonra cihazı YENİDEN BAŞLAT ve `adb_install_need_confirm`
değerinin `0` olduğunu doğrula. Olmuyorsa arayüz doğrulaması ELLE
yapılmalı — bu iş için tur harcama.

### R8 keep kuralları — SİLMEYİN
`android/app/proguard-rules.pro` içindeki `androidx.work.**` /
`androidx.room.**` kuralları bir kez "kullanılmıyor" denilip silindi ve
uygulama release'te AÇILIŞTA çöktü. WorkManager `pubspec.yaml`'da
GÖRÜNMEZ — `firebase_messaging` üzerinden transitif gelir.

### Kurallar dağıtılmadan hiçbir düzeltme aktif değil
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions,hosting
```
Firebase Console → Firestore → Rules sekmesinden dağıtıldığını doğrula.

⚠️ **`functions` HEDEFSİZ DAĞITILMAZ** — `issueEntitlement` de gider ve
uç nokta doğrulama bağlanmadan **herkese premium dağıtır** (§4y).
Fonksiyon dağıtırken adıyla hedefle:
`firebase deploy --only functions:<ad>`

### 🐞 Dağıtımdan ÖNCE indeks diff'i al
`firebase deploy --only firestore:indexes` **tüm dosyayı** uygular.
Yereldeki dosya üretimden geriyse var olan indeksleri düşürebilir ve
bunu ancak sorgular boş dönmeye başlayınca fark edersin (§4n'in sınıfı).
Dağıtımdan önce karşılaştır:
```bash
firebase firestore:indexes --project gizlichat-f2a99 > /tmp/prod.json
# yerel firestore.indexes.json ile diff al; SİLİNEN indeks olmamalı
```
§4al dağıtılırken bu yapıldı: 6 bileşik indeks birebir aynıydı, yalnızca
bir `fieldOverride` eklendi.

### 🐞 Zamanlanmış fonksiyon `:00/:30`'da değil, +30 dk'da tetiklenir
`every 30 minutes` ile dağıtılan bir fonksiyon, saat başı/buçukta değil
**oluşturulduktan 30 dakika sonra** çalışır. §4al'de fonksiyon 10:14'te
dağıtıldı, ilk çalışma **10:45**'teydi; 10:30 penceresi beklenip boş
görülünce bir an "çalışmıyor" sanıldı.
Doğrulama:
```bash
firebase functions:log --only <ad> --project gizlichat-f2a99
```
⚠️ Arka arkaya iki kez çağırma — API geçici olarak
`Failed to list log entries` döndürüyor ve bu **fonksiyon hatası
sanılabiliyor.**

### Sızmış sırlar — döndürülmeli
* `android/key.properties` içindeki yayın imzalama parolası denetim
  sırasında görüntülendi → ifşa kabul et (Play App Signing kullanıyorsan
  yükleme anahtarını döndür).
* Eski Giphy anahtarı yayınlanmış APK'larda gömülüydü → iptal et, yenisini
  `--dart-define=GIPHY_API_KEY=...` ile ver.

---

## 5. DOĞRULAMA KOMUTLARI (kopyala-çalıştır)

### Dart tarafı
```bash
cd <proje-dizini>
dart format .
flutter analyze --no-pub     # BEKLENEN: "No issues found!" (SIFIR bulgu)
flutter test --no-pub        # BEKLENEN: 310/310 geçer
```

### Firestore güvenlik kuralları (113 test)
Emulator **JDK 21+** ister; sistemde Java 8 var, Android Studio'nun JDK'sı
kullanılmalı:
```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
export PATH="$JAVA_HOME/bin:$PATH"
cd <proje-dizini>
firebase emulators:exec --only firestore --project secreter-rules-test \
  "npm --prefix test/rules test"
# BEKLENEN: 113 passing
```
(İlk kez: `npm --prefix test/rules install`)

> ⚠️ **8080 portu doluysa** ("Could not start Firestore Emulator, port
> taken") emülatör hiç başlamaz. `firebase.json`'a dokunmadan geçici bir
> kopyayla başka porttan çalıştır:
> ```bash
> sed 's/"firestore": { "port": 8080 }/"firestore": { "port": 8085 }/' \
>   firebase.json > firebase.emutest.json
> firebase emulators:exec --only firestore --project secreter-rules-test \
>   --config firebase.emutest.json "npm --prefix test/rules test"
> rm firebase.emutest.json
> ```
> (Portu tutan süreci bulmak için:
> `Get-NetTCPConnection -LocalPort 8080 -State Listen`)

### Cloud Functions
```bash
node --check functions/index.js
```

### 📦 APK BOYUTU — hangi derlemeyi kullanmalı

Ölçüm (§4z): APK'nın **%87'si üç mimari için yerel kütüphaneler**.
Kesilecek gereksiz kütüphane YOK — WebRTC 12,1 MB, Flutter motoru
11,6 MB, derlenmiş Dart 10,7 MB; hepsi gerekli. Kazanç tek dosyada üç
mimari taşımamaktan geliyor.

| Derleme | Boyut | Kim indirir |
|---|---|---|
| Evrensel (`app-release.apk`) | 103,9 MB | herkes, üç mimariyi birden |
| **arm64-v8a** | **39,6 MB** | neredeyse tüm modern telefonlar |
| armeabi-v7a | 32,6 MB | eski 32-bit cihazlar |
| x86_64 | 44,8 MB | ⚠️ yalnızca emülatör/Chromebook |

```bash
# Play Store → Play mimariyi kendi ayırır, kullanıcı ~40 MB indirir
flutter build appbundle --release

# Doğrudan dağıtım (APK paylaşımı) → BÖLÜNMÜŞ derle
flutter build apk --release --split-per-abi
# Dağıt: app-arm64-v8a-release.apk  (+ istersen armeabi-v7a)
# ⚠️ x86_64'ü DAĞITMA — gerçek telefonlarda kullanılmıyor, en büyüğü o.
```

Evrensel APK yalnızca "hangi cihaz olursa olsun kurulsun" kolaylığı
içindir; kullanıcıya dağıtılmamalıdır.

### Cihazda çalıştırma
`flutter run` terminali kilitler; bunun yerine:
```bash
export PATH="$PATH:<ANDROID_SDK>/platform-tools"
adb devices -l                      # ÖNCE: cihaz görünmüyorsa derleme boşa
# Test cihazı arm64 → yalnızca onu derlemek daha hızlı ve daha küçük
flutter build apk --release --split-per-abi          # ~3,5 dk
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb logcat -c && adb shell am force-stop com.secreter.app
adb shell am start -n com.secreter.app/.MainActivity
sleep 6
PID=$(adb shell pidof com.secreter.app | tr -d '\r')   # PID dönmeli
timeout 15 adb logcat -v brief --pid=$PID > secreter.log
grep -E "FATAL EXCEPTION|E/flutter" secreter.log  # boş olmalı
adb shell pidof com.secreter.app                  # SONRA da ayakta olmalı
```

> ⚠️ **`-r` ŞART: veri korunur.** Onsuz kurulum hesabı ve E2EE
> kimliğini siler — yani cihazdaki tüm oturumlar ve mesaj geçmişi
> gider. (Debug derlemesi kurmak da release'i kaldırmayı gerektirdiği
> için aynı sonucu doğurur; §4s'in bandı bu yüzden cihazda
> denenememişti.)

> ⚠️ **`E/` satırlarının ÇOĞU MIUI GÜRÜLTÜSÜDÜR.** Temiz bir açılışta
> bile `gralloc4`, `libEGL`, `Zygote`, `libMiGL` gibi kaynaklardan
> onlarca `E/` satırı gelir. Kabul kapısı bunlar DEĞİL; yalnızca
> `FATAL EXCEPTION` ve `E/flutter`.

> 📦 **Beklenen boyut: arm64 ≈ 39,6 MB.** Belirgin sapma varsa bir
> bağımlılık büyümüş demektir (§4z'nin ölçümü).

> 🐞 **`--pid` ŞART — yoksa YANLIŞ POZİTİF alırsın.**
> Bu komut eskiden `adb logcat -d | grep -E "FATAL EXCEPTION|E/flutter"`
> idi ve **tüm sistem günlüğünü** tarıyordu. 2026-09-01'de tam da bu
> yüzden var olmayan bir çökme kovalandı: görünen
> `E/flutter (7949): Unhandled Exception: Task didn't run` satırı
> SECRETER'a (PID 7936) değil, telefondaki **başka bir Flutter
> uygulamasına** (`io.ente.photos`, `workmanager` arka plan işi) aitti.
> Cihazda başka Flutter uygulaması varsa bu her seferinde tekrarlanır.
> Süreç kimliğini yazdır, günlüğü ona kilitle.

**Ortam yolları:**
* Flutter: `C:\flutter\bin`
* adb: `<ANDROID_SDK>\platform-tools`
* JDK 21: `C:\Program Files\Android\Android Studio\jbr`
* Test cihazı: Xiaomi 2201116TG (Android 13)

---

## 6. Elle test edilmesi gerekenler

Bunlar birim testle kapsanamaz.

> ✅ **HAZIR (2026-09-10):** cihazdaki APK güncel (§4af–§4ao içinde),
> sunucu tarafı dağıtık, kapılar yeşil. Listedeki testler çalıştırılabilir.
>
> **En çok değer verenler, sırayla:**
> 1. **Grup rotasyonu — atılan üye okuyamamalı (§4af).** ÜÇ hesap ister;
>    iki hesapla bu hata GÖRÜNMEZ.
> 2. **Susturulmuş üye gruptan çıkabilmeli (§4ak).** Eskiden gruba
>    kilitleniyordu.
> 3. **Kanal üye sayacı şişmemeli (§4an).** Zaten üye olduğun kanala
>    arka arkaya dokun.
> 4. **Gelen arama (§4am).** Sinyalleşme katmanı artık otomatik kapıda;
>    bu test WebRTC + bildirim + çağrı ekranı için.
>
> ⚠️ Bu derlemede **GIF sekmesi yok** — `GIPHY_API_KEY` verilmeden
> derlendi. GIF ile ilgili bir test yapacaksan önce anahtarla yeniden
> derle (bkz. §0 Durum).

- [ ] **Video kırpma** — galeriden uzun video seç, uçları sürükle, gönder
      (hata olursa: `adb logcat -s VideoTrimmer`)
- [ ] **Video tek-görüntülük** — `+` → Video → üstteki anahtarı aç
- [ ] **Gelen arama** — İki cihazla/hesapla ara; ARANAN tarafta çağrı
      ekranı açılmalı.
      ✅ **Sinyalleşme katmanı artık otomatik kapıda (§4am):** doğru
      şemayla yazılmış çalan bir çağrının, kuralların altında, aranan
      kişinin sorgusuyla EŞLEŞTİĞİ emülatörde ölçülüyor. §4m ve §4u'nun
      ikisi de taklit edilip yakalandığı doğrulandı.
      Bu elle test artık **kalan katmanlar** için: WebRTC sinyalleşmesi
      (offer/answer/ICE), push bildirimi ve arayüzün çağrı ekranını
      açması. Başarısızsa logcat'i sürece kilitleyip bak (§5) — ve
      önce `flutter test` + kural testlerinin geçtiğini doğrula ki
      hatanın şema/kural katmanında OLMADIĞINI bilesin.
- [ ] **Kullanıcı arama** — aramadan bir kullanıcı adı ara; bulunmalı.
      (Arama artık `users` sorgusu değil, `usernames` dizini üzerinden.)
      Var olmayan bir ad "bulunamadı" vermeli, hata değil.
- [ ] **Kayıt** — yeni hesapta ad uygunluk kontrolü çalışmalı; alınmış
      bir adı denediğinde "zaten alınmış" demeli
- [ ] **Gönderen adı (grup)** — grupta karşı taraftan mesaj al; balonda
      gönderen adı DOĞRU görünmeli (artık sunucudan değil, uid'den
      çözülüyor). Eski mesajlarda da ad korunmalı.
- [ ] **Bildirim başlığı** — birebir mesajda bildirim başlığı artık
      "@kullanıcıadı" değil "SECRETER" olmalı (ad kilit ekranına ve
      FCM'e çıkmıyor)
- [ ] **Uygulama kılığı** — Ayarlar → Güvenlik → "Uygulama kılığı" aç.
      Başlatıcıda simge "Hesap Makinesi" olmalı ve uygulama ORADAN
      açılmalı. Sonra kapat, "SECRETER" geri gelmeli.
      ⚠️ Bu anahtar OTOMATİK TEST EDİLEMEDİ: adb başka bir uygulamanın
      bileşen durumunu değiştiremiyor (`SecurityException: Shell cannot
      change component state`). Manifest/alias kurulumu ve başlatıcıdan
      açılış doğrulandı; anahtarın kendisi elle denenmeli.
      Bazı başlatıcılar simgeyi birkaç saniye gecikmeyle tazeler.
- [ ] **Aramadan sohbet açma** — daha önce yazıştığın biri için aramadan
      sohbeti yeniden aç; "Sohbet oluşturulamadı" hatası ÇIKMAMALI (§4i)

#### Metadata gizliliği 2. aşaması (§4o) — hepsi Console'dan bakılmalı
- [x] **Sohbet listesi başlığı** — ✅ 2026-09-02 cihazda DOĞRULANDI.
      Erişilebilirlik ağacından okunan başlıklar gerçek kullanıcı
      adlarıydı (`annabllae202`, `kirito`, `erenkadak`, `parzival`,
      `helios`, `wandering`, `pin207`) ve hiçbiri `Sohbet` yedeğine
      düşmedi; grup adı da doğru (`SECRETER GÜNCELLEMELERİ`). Son mesaj
      önizlemesi maskeli (`🔒 Mesaj`).
      Kalan kontrol: Firebase Console → `chats/<id>` içinde
      **`memberUsernames` alanı OLMAMALI**.
- [ ] **Eski sohbet temizliği** — bu güncellemeden ÖNCE var olan bir
      sohbette Console'da alan hâlâ duruyorsa, uygulamayı aç ve sohbet
      listesinin yüklenmesini bekle; alan **kaybolmalı**
      (`ChatMetadataScrub`). Kaybolmuyorsa kurallar dağıtılmamıştır.
- [ ] **Yeni grup** — grup kur; Console'da `memberUsernames` olmamalı ve
      `members[]` girdilerinde **`username` alanı bulunmamalı**.
- [ ] **Grup üye listesi** — Grup bilgisi ekranında üye adları doğru
      görünmeli (uid kısaltması görünüyorsa ad çözümü çalışmıyor).
- [ ] **@bahsetme** — grupta `@` yaz; üye adları önerilmeli (öneri
      kaynağı artık `memberIds` + ad çözümü).
- [x] **Doğrulama önerisi bandı (§4s)** — ✅ 2026-09-04 cihazda
      DOĞRULANDI. Doğrulanmamış birebir sohbette bant çıkıyor
      ("Güvenlik numarasını karşılaştırarak bu sohbeti doğrula" +
      "Şimdi değil") ve dokununca güvenlik numarası ekranını açıyor
      (30 hane + QR + dürüstlük uyarıları görüldü).
- [x] **Grup anahtarı uyarı bandı (§4s)** — ✅ widget testiyle
      doğrulandı (çizim, çeviri, "Tekrar dene", kapatılamazlık).
      ⚠️ CİHAZDA denenemedi: rotasyon başarısızlığı zorlanamıyor ve
      debug derlemesi kurmak release'i kaldırmayı — yani cihazdaki
      hesabı ve E2EE kimliğini SİLMEYİ — gerektiriyordu.
      Gerçek hayatta görmek istersen: grup bilgisinden bir üye at;
      rotasyon başarısız olursa kırmızı bant çıkar, başarılıysa (normal
      durum) hiçbir şey görünmez.
- [ ] **Hata metinleri (§4q)** — dili İngilizce yap, sonra kasten hata
      ürettir (geçersiz davet kodu gir). Eskiden Türkçe "Geçersiz davet
      kodu" çıkıyordu; artık **"Invalid invite code"** çıkmalı. Ham
      Firebase metni (`[cloud_firestore/permission-denied] ...`) HİÇ
      görünmemeli.
      *(Her iki metnin de release APK'sının içinde olduğu doğrulandı;
      eksik olan yalnızca ekranda görülmesi.)*
- [ ] **Kanala katılma** — kanal aramasından bir kanala katıl; kural
      değişti, `permission-denied` ÇIKMAMALI.
- [ ] **Üye atma (§4ak ile düzeltildi)** — Grupta bir üyeyi at; kişi hem
      listeden hem Console'daki **`members` dizisinden** düşmeli ve
      `memberCount` listenin uzunluğuna eşit olmalı.
      Çıkarma artık **uid ile** yapılıyor, yani rol/susturma/ad kaymış
      olsa da eşleşmeli. Eskiden birebir harita eşleşmesi gerekiyordu ve
      kayma varsa kişi `memberIds`'ten düşüp `members`'ta KALIYORDU —
      hatasız. En sert deneme: **başka bir yöneticiyle o üyeyi terfi
      ettir/sustur, sonra ilk cihazdan (ekranı tazelemeden) at.**
- [ ] **Eski adlar temizleniyor mu (§4ak / §3b/7)** — §4o'dan ÖNCE
      kurulmuş bir grupta Console'da `members[]` girdilerinde `username`
      varsa: bir üye at ya da birinin rolünü değiştir. Dizi yeniden
      yazılır ve **kalan üyelerin `username` alanları da düşmeli.**
- [ ] **🐞 SUSTURULMUŞ üye gruptan ÇIKABİLMELİ (§4ak)** — Bir üyeyi
      sustur, sonra o hesapla gruptan ayrıl. Eskiden istemci `mutedUids`
      de yazdığı için kural `onlyChanges`ten düşüyor ve **ayrılma
      tamamen reddediliyordu** — kişi gruba kilitleniyordu.
      Ayrıldıktan sonra Console'da `mutedUids`te KALMASI normaldir ve
      bilinçlidir: ayrılıp yeniden katılarak susturmadan kaçılamamalı.
- [ ] **🐞 Kanal üye sayacı ARTIK ŞİŞMİYOR (§4an)** — kanal aramasından
      **zaten üye olduğun** bir kanala arka arkaya 3-4 kez dokun.
      Console'da `chats/<id>.memberCount` **DEĞİŞMEMELİ.** Eskiden her
      dokunuşta bir artıyordu (kod bunu normal sayıyordu) ve kanal
      listesindeki sayı, kaç kez dokunulduğunu sayıyordu.
      Ayrıca yanlışlıkla "bu kanaldan yasaklısın" mesajı da
      ÇIKMAMALI — zaten üyeyken hiç yazma yapılmıyor.
- [ ] **Rol/susturma değişimi (§4an)** — grupta birini yönetici yap,
      sonra sustur. Console'da hem `members[]` girdisi hem `adminUids`/
      `mutedUids` düz dizileri tutarlı olmalı. Değişim uygulanmazsa
      sessiz kalmamalı: artık hata dönüyor.
- [ ] **Gruptan ayrılma (yönetici)** — yönetici hesabıyla ayrıl;
      Console'da **`adminUids`'ten de düşmeli.** Düşmezse o kişi
      ayrıldığı gruba yönetici olarak hükmetmeye devam eder
      (`isAdmin()` üyelik denetimi yapmıyor).
- [ ] **Mesaj düzenleme** — bir mesaj gönder, KARŞI cihazda okunduğunu
      gör, sonra düzenle. Karşı cihazda **yeni metin** görünmeli (eskiden
      eski metin kalıyordu). Firebase Console'da `content` alanı
      **okunamaz** olmalı
- [ ] **Kaybolan mesaj SUNUCUDAN siliniyor mu (§4al)**
      ✅ Fonksiyon 2026-09-10'da dağıtıldı ve **üretimde çalıştığı
      günlükten doğrulandı** (10:45'te 4 kayıt sildi). Bu elle test
      artık uçtan uca akışı (gerçek bir sohbette, gerçek bir mesajla)
      doğrulamak için:
      1. Kısa süreli (ör. 5 sn) kaybolan mesaj gönder.
      2. **Sohbeti KİMSE açmasın** — testin bütün anlamı bu; eski
         davranışta silme yalnızca sohbet açılınca oluyordu.
      3. En fazla 30 dk sonra Firebase Console → `chats/<id>/messages`
         içinde o doküman **OLMAMALI**.
      4. Storage'da eki de gitmeli (`cleanupDeletedMessageMedia`).
      Fonksiyon günlüğünde `Kaybolan mesaj temizliği: N kayıt silindi`
      satırı görünmeli. Görünmüyorsa önce **indeks** dağıtıldı mı bak:
      koleksiyon-grubu sorgusu indekssiz hata verir.
- [ ] **Şikâyet + engelleme (§4ao)** — bir kişiyi şikâyet et; sayfada
      **"Bu kişiyi de engelle"** kutusu AÇIK gelmeli. Gönderdikten
      sonra kişi engellenenler listesinde görünmeli. Kutuyu kapatıp
      gönderirsen engellenmemeli.
- [ ] **Başka hesabın yedeği (§4ao)** — A hesabıyla yedek al, B
      hesabına geç, o dosyayı geri yüklemeyi dene. **Açık hata
      çıkmalı** ("başka bir hesaba ait"). Eskiden "N mesaj geri
      yüklendi" deyip hiçbir şey göstermiyordu.
      Kendi yedeğin normal geri yüklenmeli.
- [ ] **Hata metinlerinde uid görünmüyor (§4ao)** — kasten hata
      ürettir (uçak modunda kanal ara, yedek al, hikâyeye yanıt ver).
      Çıkan mesajlarda `[cloud_firestore/...]`, `chats/`, `users/`
      ya da herhangi bir uid **GÖRÜNMEMELİ.**
- [ ] **Grup E2EE** — iki cihazla gruba mesaj at, ikisinde de okunuyor mu
- [ ] **🔴 GRUP ROTASYONU — ATILAN ÜYE OKUYAMAMALI (§4af, YENİ)**
      ÜÇ hesap gerekir; iki hesapla bu hata GÖRÜNMEZ (kusur tam olarak
      "atan olmayan üye"de yaşıyordu).
      1. A (yönetici), B ve C ile bir grup kur; üçü de mesajlaşsın
         (herkesin zinciri dağılsın).
      2. A, **C'yi** gruptan atsın.
      3. **B** gruba yeni bir mesaj yazsın. ← kritik adım
      4. C'nin cihazında o mesaj **AÇILMAMALI**.
      Eskiden C, B'nin mesajını rahatça okuyordu (yalnızca A'nın zinciri
      yenileniyordu). Adım 3'ü atlarsan hatayı göremezsin: rotasyon
      B'nin İLK gönderiminde tetiklenir.
      ⚠️ C'yi gruptan attıktan sonra C'nin uygulamasını KAPATMA — eski
      anahtarla çözmeyi deneyebilmesi lazım.
- [ ] **Grup mesajı: ağ arızasında GÖNDERİLMEMELİ (§4ag, YENİ)**
      Telefonu uçak moduna al, gruba mesaj yaz. Hata görünmeli ve mesaj
      sunucuya çıkmamalı. Firebase Console'da o gruba **düz okunabilir**
      bir mesaj DÜŞMEMELİ. (Eskiden üye listesi okunamadığı için mesaj
      şifresiz gidebiliyordu.)
- [ ] **DH ratchet (v3)** — iki cihazda uygulamayı SIFIRDAN kur (eski
      oturum kalmasın), karşılıklı 4-5 mesaj at. Hepsi okunmalı.
      Ardından bir cihazı uçak moduna al, diğerinden 2 mesaj gönder,
      moddan çık: gecikmiş mesajlar da açılmalı (atlanan anahtarlar)
- [ ] **Eski oturum bozulmadı mı** — güncellemeden ÖNCE var olan bir
      sohbette yazışmaya devam et; v2 yolunda çalışmalı
- [ ] **Şifreli medya** — fotoğraf gönder, karşı tarafta açılıyor mu;
      Firebase Storage'dan indirilen dosya **okunamaz olmalı**
- [ ] **Arama** — iki cihazla. Arama ekranında gizlilik rozetine bak:
      TURN kuruluysa 🔒 "IP adresin gizli", değilse ⚠️ "IP adresin karşı
      tarafa görünüyor" yazmalı. TURN kurulu ama erişilemiyorsa ☁️
      "Relay sunucusuna ulaşılamıyor" çıkar (bkz. `TURN_KURULUMU.md` §5)
- [ ] **16 dil** — dili değiştir, `+` menüsü ve güvenlik ekranı çevrildi mi
- [ ] **Güvenlik metinleri çevrildi mi (§4ai, YENİ)** — dili Rusça ya da
      Almanca yap, sonra kasten hata ürettir (geçersiz davet kodu gir).
      Metin **o dilde** çıkmalı; İngilizce çıkıyorsa anahtar eksik
      demektir (kapı testi bunu yakalar, ama cihazda da bak).
- [ ] **Arapça RTL (§4ai, YENİ)** — dili Arapça yap. Arayüz SAĞDAN SOLA
      dönmeli (geri oku, mesaj balonları, liste hizası). Dönmüyorsa
      sorun çeviride değil, `GlobalWidgetsLocalizations`
      yapılandırmasındadır. Uzun metinleri de kontrol et: kurtarma
      anahtarı parolası ekranı ve tehdit uyarı ekranı taşmamalı.
- [ ] **Güvenlik numarası** — iki cihazda sohbet başlığındaki kalkana
      dokun; **aynı 30 hane** ve **aynı QR** görünmeli. Birinde
      "Doğrulandı" işaretle → kalkan yeşile dönmeli
- [ ] **Kimlik değişimi uyarısı** — bir cihazda uygulamayı kaldırıp
      yeniden kur, sonra karşı tarafa mesaj at. KARŞI cihazda sohbetin
      üstünde kırmızı uyarı bandı çıkmalı ve önceki "Doğrulandı"
      işareti DÜŞMELİ. (Bu senaryo eskiden sessizce tüm mesajları
      çözülemez yapıyordu — bkz. GUVENLIK_DUZELTMELERI.md §4e.)

---

## 7. Mimari harita (kısa)

```
lib/
├── core/
│   ├── media/          ← ek şifreleme, güvenli medya önbelleği, video kırpma
│   ├── security/       ← secure_store, pin_hasher, chat_lock, native köprü
│   ├── privacy/        ← PrivacySettings (TEK gizlilik kaynağı), dolgu
│   └── i18n/           ← app_localizations.dart (16 dil, tek dosya)
├── features/           ← Clean Architecture (domain/data/presentation)
│   ├── messaging/      ← ana mesaj akışı (repository + datasource'lar)
│   ├── group/ call/ story/ search/ security/ settings/ auth/
└── services/           ← MOTORLAR (kripto, auth, arama, bildirim)
    ├── e2ee_session_service.dart    ← 1:1 oturum + düz metin yaşam döngüsü
    ├── group_key_service.dart       ← grup E2EE (sender key)
    ├── x3dh_service.dart            ← anahtar anlaşması + SPK imza
    └── double_ratchet_service.dart  ← zincir + atlanan mesaj anahtarları
```

**Eski motor SİLİNDİ:** `lib/services/chat_service.dart` ve
`lib/models/message_model.dart` kaldırıldı (iki farklı şema yazıp üç
kritik hataya sebep oluyorlardı). Mesaj modeli artık YALNIZCA
`features/messaging/data/models/message_model.dart`.
