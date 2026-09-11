# Bu iki sayfayı 10 dakikada yayına alma

Play, gizlilik politikası için **herkese açık bir URL** ister ve hesap
oluşturan uygulamalarda **uygulama dışından erişilebilir bir hesap silme
sayfası** şart koşar. İki dosya da hazır; yapman gerekenler:

## 1. Doldur (5 dk)
Her iki dosyada köşeli parantezli alanları değiştir:
- `[E-POSTA]` → iletişim adresin (ikisinde de birkaç yerde geçiyor)
- `[TARİH]` / `[DATE]` → bugünün tarihi (örn. 27.07.2026)
- `[ADIN / ŞİRKET]`, `[ADRES]` → veri sorumlusu bilgileri

Not Defteri'nde **Ctrl+H** ile toplu değiştirebilirsin.

## 2. GitHub Pages ile yayınla (ücretsiz, 5 dk)
1. github.com'da yeni bir **public** depo aç: `secreter-legal`
2. `index.html` ve `hesap-silme.html` dosyalarını sürükleyip yükle → Commit
3. Depo → **Settings → Pages** → Source: **Deploy from a branch**
   → Branch: `main`, klasör `/ (root)` → **Save**
4. 1-2 dakika sonra adresin hazır:
   `https://KULLANICIADIN.github.io/secreter-legal/`

**Play'e vereceğin URL'ler:**
- Gizlilik politikası: `https://KULLANICIADIN.github.io/secreter-legal/`
- Hesap silme: `https://KULLANICIADIN.github.io/secreter-legal/hesap-silme.html`

### Alternatifler
- **Google Sites** — sürükle-bırak, kod yok (ama tasarım bozulur, metni yapıştırırsın)
- **Netlify Drop** — netlify.com/drop adresine klasörü sürükle, anında yayında
- Kendi alan adın varsa: dosyaları herhangi bir statik barındırmaya at

## 3. Uygulamaya bağla (opsiyonel ama iyi olur)
Ayarlar ekranına "Gizlilik Politikası" satırı ekleyip bu URL'yi açtırabiliriz —
söylersen eklerim.

## 4. Play Console'a gir
- **Store listing** → Privacy policy URL
- **App content → Data safety** → formu doldur (PLAY_DATA_SAFETY.md dosyasındaki
  cevapları kullan) → "Data deletion" bölümünde hesap silme URL'sini ver
