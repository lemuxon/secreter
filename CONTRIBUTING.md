# Katkı rehberi · Contributing

*[English below](#english)*

Bu proje **aktif olarak geliştirilmiyor** ama katkıya açık. Kod, biri
faydalanabilsin ve geliştirebilsin diye yayımlandı.

Bakımcı tarafında garanti yok: PR'ların incelenmesi gecikebilir veya
hiç olmayabilir. Buna rağmen fork'layıp kendi yolunda devam etmek
tamamen serbesttir (AGPL-3.0).

---

## Nereden başlamalı

**[Issues](https://github.com/lemuxon/secreter/issues)** sekmesinde
bilinen sorunlar etiketlenmiş olarak duruyor. Her biri şunu içerir:
ne olduğu, hangi dosya/satırda, neden önemli olduğu ve düzeltme fikri.

Etiketler:

| Etiket | Anlamı |
|---|---|
| `security` | Güvenlik açığı veya sertleştirme |
| `known-limitation` | Bilinen, belgelenmiş mimari sınır |
| `good-first-issue` | Küçük, kapsamı net, projeyi tanımadan yapılabilir |
| `infra` | CI, derleme, depo hijyeni |

---

## Geliştirme ortamı

| Araç | Sürüm | Ne için |
|---|---|---|
| Flutter SDK | 3.x | uygulama |
| JDK | **17** | Android derlemesi |
| JDK | **21** | Firestore kural testleri (`firebase-tools` şartı) |
| Node.js | 20+ | Cloud Functions ve kural testleri |

> ⚠️ İki ayrı JDK gerekiyor. Kural testleri 21'in altında çalışmaz.

Kurulumun tamamı ve kendi Firebase projeni bağlama adımları:
[`README.md`](README.md#kurulum).

---

## 🚦 Doğrulama kapıları — PR açmadan önce hepsi geçmeli

Bu projede her değişiklik beş kapıdan geçer. Bir kapı düşüyorsa PR
hazır değildir.

```bash
# 1 — biçim
dart format --output=none --set-exit-if-changed lib test

# 2 — statik analiz (SIFIR bulgu olmalı)
flutter analyze

# 3 — Dart testleri
flutter test

# 4 — Cloud Functions
node --check functions/index.js
cd functions && node --test

# 5 — Firestore güvenlik kuralları (JDK 21 + emülatör şart)
cd test/rules && npm install
firebase emulators:exec --only firestore --project secreter-rules-test "npm test"
```

Şu anki durum: analyzer **0 bulgu** · **635 Dart testi** · **175 kural
testi** · **4 functions testi**.

---

## Bu projenin alışkanlıkları

Katkın kabul edilme ihtimalini artıran şeyler — bunlar keyfi kurallar
değil, yaşanmış hatalardan çıkmış:

**1. Güvenlik kuralı değiştiriyorsan TEST yaz.**
`test/rules/firestore.rules.test.js` içinde. Hem izin verilen hem
**reddedilen** durumu ölç. Bu projede bir kural testi "sorgu izinli mi"
ölçüyordu ama "doğru sonucu dönüyor mu" ölçmüyordu; kırık hâlde de
geçiyordu.

**2. `catch` bloğunda varsayılan değer döndürmeden önce dur ve sor:**
*bu değer bir sonraki katmanda geçerli bir DURUM gibi mi okunacak?*
Bu projede üye listesi okunamayınca `const []` dönülüyordu ve şifreleme
katmanı bunu "dejenere grup" sanıp mesajı **düz metin** gönderiyordu.
Ya istisnayı yukarı bırak ya `reportHandled`a bağla.

**3. Yorumda NEDEN'i yaz, NE'yi değil.** Kodda bol yorum var ve
hepsi "bu neden böyle, neyi önlüyor" anlatıyor. Bir tuzağı
kaldırıyorsan, tuzağın kaydını bırak.

**4. Kullanıcıya gösterilen metin eklersen 16 dile ekle.**
`lib/core/i18n/app_localizations.dart`. Çeviri kapısı eksik anahtarda
düşer — bir dile eklemek yetmez.

**5. Belirsizliği gizleme.** Bu projenin belgelerinde "bilinen sınır"
başlıkları var ve dürüstçe yazılmış. Eksik bir şey yapıyorsan öyle
söyle; sessizce bırakmak daha kötü.

---

## PR gönderirken

* Dalın adı serbest; hedef dal **`master`**.
* Açıklamada: ne değişti, **neden**, hangi kapılar çalıştırıldı.
* Güvenlikle ilgiliyse önce [`SECURITY.md`](SECURITY.md)'yi oku —
  bazı şeyler açık PR yerine özel bildirim ister.

---

## Dil

Kod yorumları ve belgeler **Türkçe**. Bu, projenin yazıldığı dildi.

Katkıda bulunurken:
* **Kod ve testler:** İngilizce de yazabilirsin, sorun değil.
* **Belgeler:** hangi dilde rahatsan.
* İngilizce özet: [`README.en.md`](README.en.md).

Türkçe bilmemek engel olmasın — kodun kendisi standart Dart ve
değişken adlarının çoğu İngilizce.

---
---

<a name="english"></a>

# Contributing (English)

This project is **not actively maintained**, but contributions are
welcome. The code was published so that someone could learn from it or
build on it.

No guarantees from the maintainer side: PR reviews may be slow or may
not happen. Forking and going your own way is entirely fine (AGPL-3.0).

## Where to start

The **[Issues](https://github.com/lemuxon/secreter/issues)** tab lists
known problems, each with: what it is, which file/line, why it matters,
and a fix idea.

Labels: `security`, `known-limitation`, `good-first-issue`, `infra`.

## Dev environment

| Tool | Version | For |
|---|---|---|
| Flutter SDK | 3.x | the app |
| JDK | **17** | Android build |
| JDK | **21** | Firestore rules tests (`firebase-tools` requirement) |
| Node.js | 20+ | Cloud Functions and rules tests |

> ⚠️ Two different JDKs are needed. Rules tests will not run below 21.

Full setup, including pointing the app at **your own** Firebase project:
[`README.en.md`](README.en.md#setup).

## 🚦 Verification gates — all must pass before a PR

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze                       # must be 0 issues
flutter test                          # 635 tests
node --check functions/index.js
cd functions && node --test           # 4 tests
cd test/rules && npm install && \
  firebase emulators:exec --only firestore --project secreter-rules-test "npm test"
```

## House habits

These come from real bugs, not taste:

1. **Changing a security rule? Write a test** in
   `test/rules/firestore.rules.test.js`. Assert both the allowed **and
   the denied** case. A rule test here once asserted "the query is
   permitted" but not "it returns the right thing" — it passed while
   broken.
2. **Before returning a default from a `catch`, ask:** will the next
   layer read this as a valid *state*? Here, an unreadable member list
   returned `const []`, and the crypto layer read that as "degenerate
   group" and sent the message in **plaintext**. Rethrow, or route it
   through `reportHandled`.
3. **Comments explain WHY, not what.** If you remove a trap, leave a
   record of the trap.
4. **New user-facing string? Add all 16 languages**
   (`lib/core/i18n/app_localizations.dart`). The translation gate fails
   on a missing key.
5. **Don't hide uncertainty.** This project's docs have honest
   "known limitations" sections. If your change is partial, say so.

## Sending a PR

* Branch name is up to you; target branch is **`master`**.
* In the description: what changed, **why**, which gates you ran.
* Security-related? Read [`SECURITY.md`](SECURITY.md) first — some
  things warrant private disclosure instead of a public PR.

## Language

Code comments and docs are in **Turkish** — that's the language the
project was written in. Contribute in whichever language you're
comfortable with; the code itself is standard Dart and most identifiers
are English.
