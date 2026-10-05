# SECRETER

**An end-to-end encrypted Android messenger that asks for no phone number.**
Built with Flutter + Firebase. It doesn't ask for an email either — the
account is created from a key generated on the device.

📦 `com.secreter.app` · 🧩 Flutter (Dart) + Cloud Firestore + Cloud Functions
· 📄 [AGPL-3.0](LICENSE) · 🌍 UI in 16 languages

> 🇹🇷 Türkçe sürüm: [`README.md`](README.md) — the Turkish README is the
> canonical one and is more detailed.

---

## ⚠️ Project status — read this first

**This project is not actively developed and runs no service.**

* It **never shipped to production** on Google Play. 24 builds went out
  to a closed test (~12 testers); production access was granted but
  never used.
* The **Firebase backend is being shut down.** The `firebase_options.dart`
  and `google-services.json` in this repo point at a project that no
  longer works — if you fork it, **you must set up your own Firebase
  project** (see below).
* The code is published as-is so someone can learn from it or build on
  it. No support, roadmap, or security-update promise.

> 🔐 **Don't use this app if you actually need privacy.** The E2EE layer
> has not been independently audited and has known limitations (listed
> honestly below). If you're a journalist, activist, or otherwise at
> risk, use **[Signal](https://signal.org)**.

---

## What it does

| | |
|---|---|
| 🔑 **No-phone-number signup** | No phone or email; identity is generated on-device |
| 🔒 **E2EE (1-to-1)** | X25519 + AES-256-GCM + HKDF; X3DH handshake, ratchet |
| 👥 **Groups & channels** | Sender-key group encryption, channel broadcast |
| 📞 **Voice/video calls** | WebRTC; IP is hidden when TURN is configured |
| 🕑 **Disappearing messages** | Deleted from the device **and the server** on expiry |
| 🧹 **Metadata controls** | Read receipts / typing / online can be turned off; message padding; coarse timestamps |
| 🎭 **Disguise mode** | The app can appear as "Calculator" in the launcher |
| 🛡️ **Device hardening** | Root/Frida/debugger detection, `FLAG_SECURE` |
| 📤 **Data portability** | Chat export, account deletion |

**185 Dart files**, **60 test files**.
Verification gates: analyzer clean · **635 Dart tests** · **175 Firestore
rules tests** · 4 functions tests.

---

## Architecture

| Document | Contents | Language |
|---|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Clean Architecture layers, Riverpod, DI | 🇹🇷 |
| [`METADATA_PRIVACY.md`](METADATA_PRIVACY.md) | Honest threat model, Firebase's limits | 🇹🇷 |
| [`TURN_KURULUMU.md`](TURN_KURULUMU.md) | coturn setup (required to hide IPs) | 🇹🇷 |
| [`GUVENLIK_DUZELTMELERI.md`](GUVENLIK_DUZELTMELERI.md) | The **reasoning** behind every security fix | 🇹🇷 |
| [`DEVAM.md`](DEVAM.md) | Development log — what, when, and why | 🇹🇷 |

> Most docs are in Turkish. `DEVAM.md` and `GUVENLIK_DUZELTMELERI.md` are
> working notes kept during development — not polished documentation, but
> the real record. If you wonder *why* a decision was made the way it was,
> the answer is probably in there.

---

<a name="setup"></a>

## Setup

### Requirements

| Tool | Version | For |
|---|---|---|
| Flutter SDK | 3.x | the app |
| JDK | **17** | Android build |
| JDK | **21** | Firestore rules tests (`firebase-tools` requirement) |
| Node.js | 20+ | Cloud Functions and rules tests |
| Firebase CLI | latest | deployment |

> ⚠️ Two different JDKs are needed. The rules tests **will not run**
> below 21; the Android build uses 17.

### 1. Set up your own Firebase project

The config in this repo belongs to a project that is being shut down.
Create your own and wire it up:

```bash
flutterfire configure     # generates firebase_options.dart + google-services.json
```

### 2. 🔴 Deploy the server side — skipping this leaves your app unprotected

This step is not optional. Security lives in the **rules**, not the client:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

* Without `firestore.rules` / `storage.rules`, **your data is world-readable**
* Without `firestore.indexes.json`, queries **silently return empty**
* Without `functions/`, E2EE sessions can't be established (`claimPreKey`)

> 💸 **Cloud Functions require the Blaze plan** (pay-as-you-go). On the
> Spark plan, v2 functions appear deployed but silently do nothing. That
> is exactly what happened to this project — see `DEVAM.md` §4cn.

### 3. Build

```bash
flutter pub get
flutter build apk --release --split-per-abi
# or an app bundle for Play:
flutter build appbundle --release
```

---

## Not in this repo — you must supply these

`.gitignore` deliberately keeps these out:

| File / value | Purpose |
|---|---|
| `android/key.properties` | signing passwords — template: `key.properties.ORNEK` |
| `*.jks` / `*.keystore` | signing key (generate with `keytool`) |
| `functions/.env` | `TURN_SECRET`, `TURN_URLS` — see `TURN_KURULUMU.md` |
| `--dart-define=GIPHY_API_KEY=...` | GIF tab; the feature is disabled without it |

`google-services.json` and `lib/firebase_options.dart` **are** in the
repo. The Firebase API key inside them is public by design (it ships in
every APK) and security comes from Firestore rules, not from hiding it.
Still, restrict your own key in Google Cloud Console to **Android app +
SHA-1**.

---

## Verification gates

Every change in this project passes five gates:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze                       # must be 0 issues
flutter test                          # 635 tests
node --check functions/index.js
cd functions && node --test           # 4 tests

# Firestore rules (175 tests) — requires JDK 21 and the emulator:
cd test/rules && npm install
firebase emulators:exec --only firestore --project secreter-rules-test "npm test"
```

> ⚠️ `.github/workflows/ci.yml` triggers on `main`/`develop`, but this
> repo's branch is `master` — CI does not run as-is. Fix the trigger for
> your branch if you fork.

---

## 🔐 E2EE architecture and its honest limits

**Audited primitives** (the `cryptography` package):
X25519 · AES-256-GCM · HKDF-SHA256

**Protocol layer** (written in this project):

* **X3DH** — two parties derive a shared secret without exchanging
  private keys; works while the other side is offline (prekey bundle).
* **Symmetric ratchet** — the key changes with every message → forward
  secrecy.
* Private keys live **only on the device** (secure storage). The server
  only ever sees public prekey bundles.

### ⚠️ Known limitations — stated plainly

1. **The protocol layer is unaudited.** The primitives are sound, but
   this X3DH/ratchet *implementation* has not had a professional
   security review.
2. **Simplified ratchet.** The DH-ratchet step of a full Double Ratchet
   is missing (symmetric only). Out-of-order messages can fail to
   decrypt.
3. **Signed prekey signature verification is incomplete** — full MITM
   protection needs this finished.
4. **No key backup.** Losing the device means the history can't be
   decrypted. Good for security, but users must be warned.
5. **No TURN server configured** → in calls, both parties learn each
   other's real IP. For an app that asks for no phone number, IP is one
   of the strongest identifiers. See `TURN_KURULUMU.md`.

**Recommendation:** this layer demonstrates *how* E2EE works and offers
reasonable protection, but for life-critical privacy it should be
replaced with official `libsignal` bindings.

---

## 🛡️ Device hardening and its honest limits

On startup the app checks for root/jailbreak, Frida/Xposed hooking,
attached debuggers, and emulators; `FLAG_SECURE` blocks screenshots,
screen recording and the recents preview.

**These are not absolute.** A determined attacker can bypass root
detection with Magisk Hide/Zygisk, bypass port scanning with Frida
gadget injection, or simply repackage the app without the checks.

This is a *raised bar*, not a wall. The real protection is **E2EE** and
**server-side rules**. Client-side checks can always be bypassed;
anything critical must be verified on the server.

---

## Contributing

Known problems are tracked as
**[Issues](https://github.com/lemuxon/secreter/issues)** — each with
what it is, where, why it matters, and a fix idea. Start there.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the dev environment, the
five gates, and this project's house habits.

Found a vulnerability? Read [`SECURITY.md`](SECURITY.md) first — please
report privately rather than opening a public Issue.

---

## License

**GNU Affero General Public License v3.0** — see [`LICENSE`](LICENSE).

In short: you may use, study, modify and distribute this code. If you
**distribute** a modified version (or offer it as a network service),
you must **release your source** under the same license. No warranty.

AGPL is a deliberate choice for an app that makes privacy claims: code
that can't be closed and repackaged keeps the user's "is this really
doing what it says?" question answerable.
