# Güvenlik politikası · Security policy

*[English below](#english)*

## ⚠️ Önce bunu oku

**Bu uygulamayı gerçek gizlilik ihtiyacı için kullanma.**

* E2EE katmanı **bağımsız güvenlik denetiminden geçmedi.** Kriptografik
  primitifler (X25519, AES-256-GCM, HKDF) denetlenmiş kütüphanelerden
  geliyor, ama X3DH/ratchet **uygulaması** bu projede yazıldı.
* Bilinen sınırlar [`README.md`](README.md) içinde dürüstçe yazılı:
  DH-ratchet yok, signed prekey imza doğrulaması tam değil.
* Proje **aktif olarak geliştirilmiyor** ve çalışan bir hizmeti yok.

Gazeteci, aktivist veya risk altındaki biriysen **[Signal](https://signal.org)**
kullan.

---

## Desteklenen sürümler

| Sürüm | Destek |
|---|---|
| `master` (bu depo) | En iyi çaba, garanti yok |
| Yayımlanmış APK/AAB sürümleri | **Desteklenmiyor** — Play dağıtımı kapandı |

Güvenlik yaması sözü **verilmiyor.** Bu, bakımı durmuş bir projedir.

---

## Açık bildirmek

**Lütfen açığı herkese açık Issue olarak AÇMA** — kodu fork'lamış ve
kendi sunucusunda çalıştıran biri olabilir; önce onların yama şansı
olsun.

**Nasıl bildirilir:**
[GitHub Security Advisories](https://github.com/lemuxon/secreter/security/advisories/new)
üzerinden özel bildirim aç. Depo sahibi dışında kimse göremez.

**Bildirimde faydalı olanlar:**
* Hangi dosya/satır veya hangi Firestore kuralı
* Saldırganın ne yapabildiği (sadece "şu kural gevşek" değil)
* Yeniden üretme adımları veya çalıştırdığın komut
* Varsa düzeltme fikri

**Ne bekleyebilirsin:** Bakım durduğu için **yanıt süresi garantisi
yok.** Ama bildirimin okunacak; kritikse `README`'ye uyarı eklenmesi
veya açığın Issue olarak açılması muhtemeldir.

---

## Zaten bilinen ve AÇIK olan konular

Bunları yeniden bildirmene gerek yok — Issues'ta kayıtlılar:

| Konu | Durum |
|---|---|
| TURN sunucusu yok → aramada IP karşı tarafa açılıyor | Bilinen, belgelenmiş |
| `keyBundles` listelenebiliyor → kullanıcı numaralandırma | Bilinen |
| App Check yok + anonim giriş → `signedIn()` bedava elde edilebilir | Bilinen |
| Storage'a herkes yükleyebiliyor, kimse silemiyor | Bilinen |
| Hesap kurtarma boşluğu — uygulama silinince hesap erişilemez | Bilinen |
| E2EE: DH-ratchet yok, signed prekey imzası tam doğrulanmıyor | Bilinen, belgelenmiş |

---

## Fork'layacaksan

🔴 **Sunucu tarafını kendin dağıtmazsan uygulaman korumasız çalışır.**

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

* `firestore.rules` / `storage.rules` dağıtılmazsa **veri herkese açıktır**
* `functions/` olmadan E2EE oturumu kurulamaz (`claimPreKey`)
* Cloud Functions **Blaze planı** ister; Spark'ta dağıtılmış görünüp
  sessizce durur

Ayrıca kendi Firebase API anahtarını Google Cloud Console'dan
**Android uygulaması + SHA-1** ile kısıtla.

---
---

<a name="english"></a>

# Security policy (English)

## ⚠️ Read this first

**Do not use this app where real privacy is at stake.**

* The E2EE layer has **not been independently audited.** The primitives
  (X25519, AES-256-GCM, HKDF) come from audited libraries, but the
  X3DH/ratchet **implementation** was written in this project.
* Known limits are documented honestly in [`README.en.md`](README.en.md):
  no DH ratchet, signed prekey signature verification incomplete.
* The project is **not actively maintained** and runs no service.

If you're a journalist, activist, or otherwise at risk, use
**[Signal](https://signal.org)**.

## Supported versions

| Version | Support |
|---|---|
| `master` (this repo) | Best effort, no guarantees |
| Released APK/AAB builds | **Unsupported** — Play distribution has ended |

No security patches are promised. This is an unmaintained project.

## Reporting a vulnerability

**Please do not open a public Issue for a vulnerability** — someone may
have forked this and be running it on their own server; give them a
chance to patch first.

**How:** open a private report via
[GitHub Security Advisories](https://github.com/lemuxon/secreter/security/advisories/new).
Only the repository owner can see it.

**Useful to include:**
* File/line, or which Firestore rule
* What an attacker can actually do (not just "this rule looks loose")
* Reproduction steps or the command you ran
* A fix idea, if you have one

**What to expect:** because maintenance has stopped, there is **no
guaranteed response time**. Your report will be read; if it's critical,
a warning in the README or a public Issue is the likely outcome.

## Already known and open

No need to re-report these — they're tracked in Issues:

| Issue | Status |
|---|---|
| No TURN server → caller/callee IPs are exposed | Known, documented |
| `keyBundles` is listable → user enumeration | Known |
| No App Check + anonymous auth → `signedIn()` is free | Known |
| Anyone can upload to Storage, nobody can delete | Known |
| Account recovery gap — uninstalling loses the account | Known |
| E2EE: no DH ratchet, signed prekey signature not fully verified | Known, documented |

## If you fork

🔴 **If you don't deploy the server side yourself, your app runs unprotected.**

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

* Without `firestore.rules` / `storage.rules`, **your data is world-readable**
* Without `functions/`, E2EE sessions can't be established (`claimPreKey`)
* Cloud Functions require the **Blaze plan**; on Spark they appear
  deployed but silently do nothing

Also restrict your own Firebase API key in Google Cloud Console to
**Android app + SHA-1**.
