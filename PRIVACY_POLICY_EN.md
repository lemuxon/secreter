# SECRETER — Privacy Policy

**Last updated:** [DATE]
**Contact:** [YOUR EMAIL]

> **Fill in:** the date, the email, and the "Data controller" section at the
> end. This document was not prepared by a lawyer and is not legal advice.
> Have a legal professional review it before commercial release.

---

## 1. In short

SECRETER is a messaging app that works without a phone number or email
address. To register you only pick a username. We do not collect personal
identity information.

This policy describes what is collected, where it is stored, and what is
encrypted — plainly, without marketing language.

---

## 2. Data we collect

### 2.1 Account data
| Data | Required | Purpose |
|---|---|---|
| Username | Yes | So other users can find you |
| Account identifier (randomly generated) | Yes | Technically identify your account |
| Profile photo | No | Shown on your profile |
| "About" text | No | Shown on your profile |

**We do not collect:** phone number, email address, real name, address,
government ID, contact list, location history, advertising identifiers.

### 2.2 Messages and content
- **Text messages in one-to-one chats:** end-to-end encrypted on your
  device (X3DH + Double Ratchet); only the encrypted form exists on the
  server.
- **Group and channel text messages:** end-to-end encrypted using the
  "sender key" scheme. The key is rotated when membership changes.
- **Media (photos, videos, voice notes, files):** encrypted on your
  device with AES-256-GCM; only encrypted bytes reach cloud storage.
  The decryption key travels inside the message's encrypted content and
  is never given to the server.
- **Edited messages:** delivered as a new encrypted message.
- **Polls:** **not** end-to-end encrypted. The question and options are
  stored in plain text so votes can be aggregated — a deliberate
  trade-off.
- **Scheduled messages:** **not** end-to-end encrypted. The server
  performs the delivery, so the content stays in plain text until it is
  sent.
- **GIFs and stickers:** the content is served by Giphy; the message
  carries only a public link, which is not encrypted.
- **Stories:** automatically deleted after 24 hours; not encrypted.

Section 5 explains exactly what this means.

### 2.3 Usage and technical data
- **Push notification token:** to deliver notifications to you.
- **Online status / last seen / typing indicator:** you can turn these
  **off** in Settings → Privacy.
- **Read receipts:** can be turned off.
- **Crash reports:** **off by default.** Sent only if you enable them;
  before sending, identifier-like patterns (IDs, tokens, email-like
  strings) are automatically masked.

### 2.4 Data that stays on your device only
The following is **never sent to our servers**:
- App lock and chat lock passcodes (stored only as salted cryptographic
  hashes in secure storage)
- Decoy chat content
- Your hidden-message markers
- Folders, contact labels (nicknames), starred-message markers
- Chat background and theme preferences
- Your selected app language

---

## 3. Third parties that process data

| Service | Purpose | What is sent |
|---|---|---|
| **Google Firebase** (Authentication, Firestore, Storage, Cloud Messaging, Functions) | Accounts, message/media storage, notifications | Account identifier, message data (scope in 2.2), media files, push token |
| **Firebase Crashlytics** | Crash reporting | **Only if you enable it:** masked error text and technical device info |
| **Giphy** | GIF/sticker search | Your search term and IP address go to Giphy |
| **Translation services** (Google Translate endpoint / MyMemory) | Message translation | **Only the text of messages you choose to translate.** Explicit consent is requested on first use. |

We do **not** sell your data, do not share it with ad networks, and do not
show ads.

---

## 4. Retention and deletion

- Messages are stored until you or the other party deletes them.
- With **disappearing messages** enabled, messages are hidden and deleted
  from the server after the period you choose.
- In **secret chat** mode, every time you leave the chat all of its
  messages are permanently deleted for both sides.
- **Account deletion:** Settings → Remove my account. Your profile,
  photos and stories are deleted; your username is reserved for 14 days
  (to prevent accidental identity takeover), then released.
- Short-lived remnants may persist in the cloud provider's backups,
  subject to Google's infrastructure policies.

---

## 5. Honest note about encryption

**End-to-end encrypted:**
- Text messages in one-to-one chats (X3DH + Double Ratchet)
- Group and channel text messages (sender key; rotated on membership
  change)
- Media files — photos, videos, voice notes, files (AES-256-GCM)
- Edited messages

The server cannot read these.

**NOT end-to-end encrypted:** polls, scheduled messages, GIFs and
stickers, stories. These are protected by TLS in transit and encrypted
at rest by the provider, but **the party operating the server can
technically access this content.**

We do not hide the reasons: polls must be aggregated to count votes,
scheduled messages are delivered by the server, and GIF content is
already public on Giphy.

**Encryption protects CONTENT, not METADATA.** Even for encrypted
messages, the server can still see who is talking to whom (user IDs),
message timestamps, read receipts and group memberships. User **names**
have been removed from chat and message records on the server;
identifiers cannot be removed, because the server uses them to enforce
access control.

**Device security:** Features such as app lock, decoy PIN and the panic
gesture are designed for situations where your phone falls into someone
else's hands. They operate on the device and do not encrypt your
server-side data.

---

## 6. Your rights

Depending on your jurisdiction (e.g. GDPR, KVKK) you may have rights to
access, correct, delete, object to processing, and port your data.
Requests: **[YOUR EMAIL]**

Available directly in the app:
- Delete your account and content (Settings → Remove my account)
- Export your chats (chat menu → Export chat)
- Turn off telemetry, read receipts and online status

---

## 7. Children

SECRETER is not directed to children under 13, and we do not knowingly
collect data from users under 13. Where your country sets a higher age
limit, that limit applies.

---

## 8. Security

We use TLS in transit, Firebase Authentication for account verification,
and salted cryptographic hashes with secure storage for local passcodes.
No system is 100% secure; we cannot guarantee perfect security.

---

## 9. Changes

If this policy changes, the date at the top is updated. Significant
changes will be announced in the app.

---

## 10. Data controller and contact

**Controller:** [YOUR NAME / COMPANY]
**Address:** [ADDRESS — may be required for GDPR/KVKK]
**Email:** [YOUR EMAIL]
