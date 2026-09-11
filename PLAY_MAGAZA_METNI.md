# Play mağaza sayfası — hazır metinler + risk rehberi

---

## ⚠️ Önce: reddedilme riski ve dil stratejisi

Google, "gizlilik / şifreleme / gizli mod" uygulamalarını **daha sıkı**
inceler. Senin uygulamanda özellikle şunlar dikkat çeker:

| Özellik | Nasıl algılanabilir | Nasıl anlatmalı |
|---|---|---|
| Sahte PIN / decoy ekran | "kullanıcıyı aldatma" | **kişisel güvenlik**: telefon zorla alınırsa hassas sohbetleri koruma |
| Panik jesti | "kanıt gizleme" | hızlı gizlilik çıkışı, omuz sörfü koruması |
| Mesaj gizleme | "içerik saklama" | kişisel arşiv düzeni, cihazı paylaşırken mahremiyet |
| Ekran görüntüsü engeli | (sorun değil) | standart güvenlik özelliği |

**Altın kural:** metinlerde **asla** şu çağrışımları verme —
"kimseden gizle", "yakalanma", "kanıt bırakma", "izlenmeden", "takip et",
"başkasının mesajlarını gör". Bunlar stalkerware/suç kolaylaştırma
sinyalidir ve doğrudan redde götürür.

**Kullan:** "kendi mahremiyetin", "cihaz güvenliği", "kişisel veri",
"sen kontrol et".

---

## Uygulama adı (30 karakter sınırı)

```
SECRETER
```

Alternatif (arama görünürlüğü için):
```
SECRETER — Özel Mesajlaşma
```
*(26 karakter — sınıra uyuyor)*

---

## Kısa açıklama (80 karakter sınırı)

**Türkçe:**
```
Telefon numarası istemeyen, gizlilik odaklı mesajlaşma. Sen kontrol et.
```
*(70 karakter)*

**İngilizce:**
```
Privacy-first messaging with no phone number required. You stay in control.
```
*(74 karakter)*

---

## Tam açıklama — Türkçe (4000 karakter sınırı)

```
SECRETER, telefon numarası veya e-posta adresi istemeden çalışan bir
mesajlaşma uygulamasıdır. Kayıt olmak için sadece bir kullanıcı adı
seçersin — başka hiçbir kişisel bilgi istenmez.

━━━━━━━━━━━━━━━━━━━━━━
NEDEN FARKLI

• Kayıt için telefon numarası ve e-posta gerekmez
• Rehberine, konumuna veya kişi listene erişmez
• Reklam yok, reklam kimliği toplanmaz, veri satılmaz
• Kişisel verilerin üzerinde kontrol sende

━━━━━━━━━━━━━━━━━━━━━━
ŞİFRELEME — AÇIK SÖZLÜ

Uçtan uca şifreli olanlar:
• Birebir metin mesajları (X3DH + Double Ratchet)
• Grup ve kanal metin mesajları (sender key)
• Fotoğraf, video, ses kaydı ve dosyalar (AES-256-GCM)

Bunları sunucu okuyamaz.

Uçtan uca şifreli OLMAYANLAR: anketler (oylar toplanabilsin diye),
zamanlanmış mesajlar (gönderimi sunucu yapar), GIF'ler (içerik zaten
Giphy'de herkese açık) ve hikâyeler. Bunlar aktarımda TLS ile korunur.

Şifreleme İÇERİĞİ korur, ÜST VERİYİ korumaz: kimin kiminle yazıştığı ve
mesaj zamanları sunucuda görünür. Kullanıcı ADLARI sunucudaki kayıtlardan
kaldırılmıştır. Bunu gizlemek yerine yazıyoruz.

━━━━━━━━━━━━━━━━━━━━━━
CİHAZ GÜVENLİĞİ

Telefonun başkasının eline geçerse:
• Uygulama kilidi (PIN veya parmak izi)
• Sohbet kilidi — belirli sohbetlere ayrı şifre
• Mesaj gizleme — şifreyle açılan kişisel arşiv
• Ekran görüntüsü engeli (birebir sohbetlerde)
• Otomatik kilit

━━━━━━━━━━━━━━━━━━━━━━
MESAJLAŞMA ÖZELLİKLERİ

• Fotoğraf, video, sesli mesaj, dosya, GIF ve çıkartma
• Uygulama içi video oynatıcı
• Anketler — canlı sonuçlarla
• Kaybolan mesajlar (1 saat / 1 gün / 1 hafta)
• Tek görüntülük fotoğraflar
• Zamanlanmış mesajlar
• Mesaj düzenleme, yanıtlama, iletme, sabitleme, yıldızlama
• Tepkiler ve @bahsetme
• Tarih aralığıyla sohbet içi arama
• Sohbeti metin dosyası olarak dışa aktarma

━━━━━━━━━━━━━━━━━━━━━━
DÜZEN

• Klasörler — sohbetlerini grupla
• Kişi etiketleri — sadece sende görünen takma adlar
• Sessize alma + etiket bildirimi istisnası
• Arşiv, sabitleme, yıldızlı mesajlar
• Sohbet renkleri ve arka planlar
• Ana ekran widget'ı — okunmamış sayacı

━━━━━━━━━━━━━━━━━━━━━━
GRUPLAR VE KANALLAR

• Yönetici rolleri, susturma, davet kodu ve bağlantısı
• Kanallar — tek yönlü duyuru yayını

━━━━━━━━━━━━━━━━━━━━━━
16 DİL

Türkçe, İngilizce, Rusça, Arapça, Çince, Fransızca, Portekizce,
Ukraynaca, İtalyanca, Yunanca, Japonca, Korece, Lehçe, İsveççe,
Fince, Almanca.

━━━━━━━━━━━━━━━━━━━━━━
SENİN KONTROLÜNDE

• Okundu bilgisi — kapatılabilir
• Çevrimiçi durumu ve son görülme — kapatılabilir
• "Yazıyor" göstergesi — kapatılabilir
• Çökme raporları — varsayılan KAPALI, sadece sen açarsan gönderilir
• Hesabını ve tüm içeriğini uygulama içinden silebilirsin

Gizlilik politikası: [POLİTİKA BAĞLANTIN]
İletişim: [E-POSTA ADRESİN]
```

---

## Tam açıklama — İngilizce

```
SECRETER is a messaging app that works without a phone number or an email
address. To sign up you only choose a username — no other personal
information is requested.

━━━━━━━━━━━━━━━━━━━━━━
WHAT MAKES IT DIFFERENT

• No phone number or email required to register
• No access to your contacts, location or address book
• No ads, no advertising IDs, no data selling
• You stay in control of your personal data

━━━━━━━━━━━━━━━━━━━━━━
ENCRYPTION — STATED PLAINLY

Text messages in one-to-one chats are end-to-end encrypted
(X3DH + Double Ratchet). The server cannot read them.

Group messages and media files are NOT end-to-end encrypted yet; they are
protected by TLS in transit. We state this instead of hiding it — use
one-to-one text chats for sensitive content.

━━━━━━━━━━━━━━━━━━━━━━
DEVICE SECURITY

If your phone ends up in someone else's hands:
• App lock (PIN or fingerprint)
• Chat lock — a separate passcode for specific chats
• Message hiding — a personal archive behind a passcode
• Screenshot protection (in one-to-one chats)
• Auto-lock

━━━━━━━━━━━━━━━━━━━━━━
MESSAGING FEATURES

• Photos, videos, voice messages, files, GIFs and stickers
• Built-in video player
• Polls with live results
• Disappearing messages (1 hour / 1 day / 1 week)
• View-once photos
• Scheduled messages
• Edit, reply, forward, pin and star messages
• Reactions and @mentions
• In-chat search with date range
• Export a chat as a text file

━━━━━━━━━━━━━━━━━━━━━━
ORGANIZATION

• Folders to group your chats
• Contact labels — nicknames visible only to you
• Mute with an optional exception for @mentions
• Archive, pin, starred messages
• Chat colors and backgrounds
• Home screen widget with unread counter

━━━━━━━━━━━━━━━━━━━━━━
GROUPS AND CHANNELS

• Admin roles, muting, invite codes and links
• Channels for one-way announcements

━━━━━━━━━━━━━━━━━━━━━━
16 LANGUAGES

Turkish, English, Russian, Arabic, Chinese, French, Portuguese,
Ukrainian, Italian, Greek, Japanese, Korean, Polish, Swedish,
Finnish, German.

━━━━━━━━━━━━━━━━━━━━━━
YOU DECIDE

• Read receipts — can be turned off
• Online status and last seen — can be turned off
• Typing indicator — can be turned off
• Crash reports — OFF by default, sent only if you enable them
• Delete your account and all content from within the app

Privacy policy: [YOUR POLICY LINK]
Contact: [YOUR EMAIL]
```

---

## Görseller (Play zorunlu)

| Öğe | Gereksinim | Not |
|---|---|---|
| Uygulama ikonu | 512×512 PNG | Mevcut launcher ikonunu büyüt |
| Öne çıkan görsel | 1024×500 PNG/JPG | Logo + kısa slogan yeterli |
| Ekran görüntüsü | En az **2**, önerilen 4-8 (telefon) | Aşağıdaki listeye bak |

**Önerilen ekran görüntüleri (sırayla):**
1. Sohbet ekranı (renkli balonlar + medya)
2. Ana ekran (sohbet listesi + klasör sekmeleri)
3. Gizlilik ayarları (kapatılabilir seçenekler görünsün)
4. Anket veya kaybolan mesajlar
5. 16 dil seçim ekranı

⚠️ Ekran görüntülerinde **gerçek kişi adı, telefon numarası veya
tanınabilir içerik olmasın** — test hesaplarıyla temiz ekranlar üret.

---

## İçerik derecelendirmesi anketi (özet cevaplar)

- Şiddet, cinsellik, uyuşturucu, kumar → **Hayır**
- **Kullanıcılar arası iletişim var mı** → **Evet** (mesajlaşma)
- **Kullanıcı içeriği paylaşımı var mı** → **Evet**
- Konum paylaşımı → Uygulamada konum mesajı türü tanımlı; kullanmıyorsan
  **Hayır**, aktifse **Evet**
- Muhtemel sonuç: **Teen / 13+** civarı

---

## Yayın stratejisi — önemli

Yeni geliştirici hesapları için Google, üretim yayınından önce
**kapalı test** şartı arıyor (yaklaşık **12 test kullanıcısı, 14 gün
sürekli test**). Bu yüzden:

1. Önce **Closed testing** ile başlat, 12+ kişi davet et (arkadaş/aile)
2. 14 günü doldur
3. Sonra **Production**'a yükselt

Bu süreyi beklerken çeviri kalite kontrolü ve son testleri yapabilirsin.
