# GizliChat — Tasarım Notları (v14: "Buzlu Obsidyen")

Bu döküman tasarım yönünü, neyin bilinçli seçim olduğunu ve nasıl
genişletileceğini kaydeder.

## Yön

**Konu:** Anonim, uçtan uca şifreli mesajlaşma. "Gizli" = saklı/gizli.
Marka vaadi: hissedilen gizlilik.

**Tema: Buzlu Obsidyen.** Gizlilik görünür bir malzeme olarak ele alınır —
obsidyen derinlik + buzlu cam katmanlar (bulanıklık = koruma/katman sinyali).

**Alınan risk (imza):** Şifrelemeyi görünür kılmak. E2EE mesajlar ince bir
mint sol kenar + kilit alır; "güvenlik" bir etiket değil, bir doku.

## Palet (anlam taşır)

İki tonlu aksan — dekorasyon değil, anlam kodlar:

| Renk | Hex | Anlam |
|------|-----|-------|
| Obsidyen | `#0B0F14` | en derin zemin |
| Arduvaz | `#151B23` | yükseltilmiş yüzey |
| Buz | `#1E2730` | kart/girdi |
| **Camgöbeği** | `#35C2F0` | **etkileşim** (buton, link, "benim" baloncuk) |
| **Nane** | `#34D399` | **güvenlik** (E2EE, çevrimiçi, doğrulanmış) |
| Sis | `#7E8C9A` | ikincil metin |
| Fısıltı | `#E9EEF3` | ana metin (saf beyaz değil — OLED dostu) |
| Kor | `#FB6F8D` | tehlike (yumuşak gül-kırmızı) |

**Neden şablon değil:** Yaygın AI-defaultu "siyah üzeri asit-yeşili tek
aksan"dır. Burada birincil aksan camgöbeği (güven/dijital), nane ise
*ikincil anlam* rengi. İki-tonlu sistem tasarımı kasıtlı kılar.

## Tip ölçeği

Şu an sistem fontu + bilinçli ölçek (negatif harf aralığı = modern sıkılık,
Nothing OS / iOS 18). Üretim için `google_fonts` ile Inter/Geist eklenebilir
(çalışma anında indirir; offline derleme istiyorsan font dosyasını assets'e
koy). Font dosyası gömmedim çünkü doğrulayamadığım bir bağımlılık eklemek
istemedim.

## Hareket

`Motion` token'ları: fast 150ms, base 250ms, slow 400ms. Yaylı eğriler.
- Mesaj girişi: hafif yukarı kayma + solma (azaltılmış-harekete saygılı)
- Gönder butonu: yazarken büyür + renklenir (AnimatedScale + AnimatedContainer)
- Avatar: Hero (sohbet listesi → sohbet geçişine hazır)
- Buzlu cam: AppBar + giriş çubuğu (BackdropFilter)

## Disiplin (Chanel kuralı)

Cesaret tek yerde: E2EE güvenli malzeme + buzlu cam. Baloncuklar sessiz,
listeler hassas. Gereksiz gradyan/efekt yok.

## Dürüst sınırlar

1. **Göremedim.** Flutter SDK yok; API doğruluğu + denge kontrol edildi ama
   gerçek görünüm cihazda görülmeli. Renk dengesi/kontrast ince ayar
   gerektirebilir.
2. **Buzlu cam GPU maliyetli.** Sadece üst/alt çubukta; uzun listede her
   öğeye uygulama. Düşük donanımda `intensity` düşür.
3. **"Dynamic color" tam değil.** M3 `fromSeed` uyumlu şema üretir, ama
   Android'in duvar kağıdından renk alan gerçek Material You'su için
   `dynamic_color` paketi gerekir (opsiyonel).
4. **Sadece messaging ekranı tam elden geçti.** Tema değişikliği TÜM eski
   ekranlara otomatik yansır (paylaşılan `AppTheme`), ama story/call/group
   ekranlarının özel dokunuşları (Hero eşleştirme, özel animasyon) henüz yok.

## Genişletme sırası

1. Sohbet listesine `Hero(tag: 'avatar_$chatId')` ekle → sohbete geçiş animasyonu
2. Story görüntüleyiciye buzlu üst katman + ilerleme çubuğu animasyonu
3. Arama ekranına nane "bağlı/güvenli" göstergesi
4. `google_fonts` ile tipografiyi sabitle
