// ============================================================
// SECRETER — Cloud Functions
//
// Sorumluluklar:
//  1. Push bildirimleri (mesaj, arama, cevapsız çağrı)
//  2. Zamanlanmış mesajların gönderimi
//  3. E2EE tek kullanımlık ön-anahtar TÜKETİMİ (atomik)
//  4. Maliyet/gizlilik temizliği (hikâye, medya, arama, kullanıcı adı)
//  5. Hesap verilerinin TAM silinmesi
//  6. TURN icin KISA OMURLU kimlik bilgisi uretimi
//
// GİZLİLİK NOTU: Push gövdesi asla mesaj içeriği taşımaz. FCM token'ı
// `users/{uid}/private/push` alt dokümanında tutulur; güvenlik kuralları
// bunu diğer kullanıcılara KAPATIR, Admin SDK ise kurallardan bağımsız okur.
// ============================================================

const {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const crypto = require("crypto");
// TURN kimlik üretimi ayrı ve SAF (test edilebilsin diye): turn.js
const { buildTurnCredential } = require("./turn");

// MALİYET KORUMASI: sınırsız ölçekleme, hatalı bir döngüde faturayı
// patlatabilir. Tüm fonksiyonlar tek bölgede toplanır (tetikleyicilerle
// zamanlayıcıların ayrı bölgede olması gereksiz gecikme üretiyordu).
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

admin.initializeApp();
const db = admin.firestore();
// ⚠️ TEMBEL: bucket MODUL YUKLENIRKEN alinmamalidir.
//
// `admin.storage().bucket()` cagrisi, ortamda storageBucket
// yapilandirilmamissa FIRLATIR. Dagitim sirasinda Firebase CLI kodu
// analiz icin yerel bir surecte yukler; orada bucket adi bulunmayinca
// modul yuklenemiyor ve dagitim "User code failed to load. Cannot
// determine backend specification" ile DUSUYORDU — hangi fonksiyonun
// sorunlu oldugunu soylemeden.
//
// Ilk kullanimda alinir; yalnizca medya silme yolunda gerekli.
let _bucket = null;
function storageBucket() {
  if (!_bucket) _bucket = admin.storage().bucket();
  return _bucket;
}
const FieldValue = admin.firestore.FieldValue;

const MAX_CONTENT = 16384;

// ─────────────────────────────────────────────────────────────
// YARDIMCILAR
// ─────────────────────────────────────────────────────────────

/** Kullanıcının FCM token'ını gizli alt dokümandan oku. */
async function getPushToken(uid) {
  try {
    const snap = await db.doc(`users/${uid}/private/push`).get();
    return snap.exists ? snap.data().fcmToken || null : null;
  } catch (e) {
    console.error("push token okunamadı", uid, e);
    return null;
  }
}

/** Birden fazla kullanıcının token'ını tek turda oku. */
async function getPushTokens(uids) {
  if (uids.length === 0) return new Map();
  const refs = uids.map((uid) => db.doc(`users/${uid}/private/push`));
  const snaps = await db.getAll(...refs);
  const out = new Map();
  snaps.forEach((snap, i) => {
    if (snap.exists) {
      const t = snap.data().fcmToken;
      if (t) out.set(uids[i], t);
    }
  });
  return out;
}

/** Geçersiz hale gelmiş token'ları temizle. */
async function pruneInvalidTokens(responses, orderedUids) {
  const dead = [];
  responses.forEach((r, i) => {
    if (
      !r.success &&
      r.error &&
      (r.error.code === "messaging/registration-token-not-registered" ||
        r.error.code === "messaging/invalid-registration-token")
    ) {
      dead.push(orderedUids[i]);
    }
  });
  await Promise.all(
    dead.map((uid) =>
      db
        .doc(`users/${uid}/private/push`)
        .set({ fcmToken: FieldValue.delete() }, { merge: true })
        .catch((e) => console.error("token silinemedi", uid, e))
    )
  );
}

/**
 * Firebase Storage indirme URL'inden nesne yolunu çıkarır.
 * Örnek: .../o/images%2Fabc.jpg?alt=media  ->  images/abc.jpg
 */
function storagePathFromUrl(url) {
  if (!url || typeof url !== "string") return null;
  const m = url.match(/\/o\/([^?]+)/);
  if (!m) return null;
  try {
    return decodeURIComponent(m[1]);
  } catch (e) {
    return null;
  }
}

async function deleteStorageObject(path) {
  if (!path) return false;
  try {
    await storageBucket().file(path).delete();
    return true;
  } catch (e) {
    if (e.code !== 404) console.error("dosya silinemedi:", path, e);
    return false;
  }
}

// ─────────────────────────────────────────────────────────────
// 1) YENİ MESAJ BİLDİRİMİ
// ─────────────────────────────────────────────────────────────
exports.sendMessageNotification = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const msg = event.data ? event.data.data() : null;
    if (!msg || !msg.senderId) return;

    const chatId = event.params.chatId;

    const chatSnap = await db.collection("chats").doc(chatId).get();
    if (!chatSnap.exists) return;
    const chat = chatSnap.data() || {};

    const recipients = (chat.memberIds || []).filter(
      (id) => id && id !== msg.senderId
    );
    if (recipients.length === 0) return;

    const isGroupLike = chat.type === "group" || chat.type === "channel";
    // ── METADATA GIZLILIGI ──
    // Birebir bildirim basligi "@kullaniciadi" idi. Bu, gonderenin adini
    // hem FCM'e (yani Google'a) hem de KILIT EKRANINA tasiyordu — icerik
    // maskeliyken bile "kiminle konustugun" disari sizmis oluyordu.
    // Baslik artik notrdur; kim yazdigi uygulama acilinca gorulur.
    const title = isGroupLike ? chat.groupName || "SECRETER" : "SECRETER";

    // @bahsetme tespiti — yalnızca ŞİFRESİZ grup mesajlarında mümkün.
    //
    // DÜZELTME: burada `msg.isEncrypted` okunuyordu ama istemci alanı
    // `isE2EE` olarak yazıyor. Sonuç: koşul her zaman false, bahsetme
    // bildirimi HİÇ çalışmıyordu. Alan adı istemciyle hizalandı.
    const plain =
      isGroupLike && msg.isE2EE !== true ? String(msg.content || "") : "";

    const escapeRe = (u) => u.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const mentions = (uname) => {
      if (!uname || !plain) return false;
      return new RegExp("@" + escapeRe(uname) + "(?![\\w])", "i").test(plain);
    };

    const mutedBy = chat.mutedBy || [];
    const muteMentionOk = chat.muteMentionOk || [];

    // Kullanıcı adlarını (bahsetme eşleşmesi için) ve token'ları topla
    const [tokenMap, userSnaps] = await Promise.all([
      getPushTokens(recipients),
      db.getAll(...recipients.map((uid) => db.collection("users").doc(uid))),
    ]);
    const usernameOf = new Map();
    userSnaps.forEach((s) => {
      if (s.exists) usernameOf.set(s.id, String((s.data() || {}).username || ""));
    });

    const mentionedUids = [];
    const normalUids = [];
    for (const uid of recipients) {
      if (!tokenMap.has(uid)) continue;
      const mentioned = mentions(usernameOf.get(uid));
      if (mutedBy.includes(uid)) {
        // Susturulmuş: yalnızca etiket istisnası açıksa bildirim gider
        if (mentioned && muteMentionOk.includes(uid)) mentionedUids.push(uid);
        continue;
      }
      (mentioned ? mentionedUids : normalUids).push(uid);
    }

    if (normalUids.length === 0 && mentionedUids.length === 0) return;

    async function send(uids, body) {
      if (uids.length === 0) return { responses: [] };
      return admin.messaging().sendEachForMulticast({
        tokens: uids.map((u) => tokenMap.get(u)),
        notification: { title, body },
        android: {
          priority: "high",
          notification: { channelId: "gizlichat_channel" },
        },
        data: { chatId, type: "message" },
      });
    }

    // GİZLİLİK: içerik ASLA bildirimde görünmez; etiket bildirimi de
    // yalnızca "sizden bahsetti" bilgisidir, mesaj metni sızmaz.
    const [rNormal, rMention] = await Promise.all([
      send(normalUids, "Yeni mesaj"),
      send(mentionedUids, "Sizden bahsetti"),
    ]);

    await pruneInvalidTokens(
      [...rNormal.responses, ...rMention.responses],
      [...normalUids, ...mentionedUids]
    );
  }
);

// ─────────────────────────────────────────────────────────────
// 2) ZAMANLANMIŞ MESAJLAR
// ─────────────────────────────────────────────────────────────
exports.sendScheduledMessages = onSchedule(
  { schedule: "every 1 minutes" },
  async () => {
    const nowIso = new Date().toISOString();

    const due = await db
      .collection("scheduledMessages")
      .where("sendAt", "<=", nowIso)
      .limit(50)
      .get();

    if (due.empty) return;

    for (const doc of due.docs) {
      const s = doc.data() || {};
      try {
        // ── GİRDİ DOĞRULAMASI ──
        // Bozuk kayıt sonsuza kadar kuyruğun başını tıkıyordu (her dakika
        // aynı 50 kayıt çekilip aynı hatayı veriyordu). Artık geçersiz
        // kayıt hemen düşürülür.
        if (
          typeof s.chatId !== "string" ||
          !s.chatId ||
          typeof s.senderId !== "string" ||
          !s.senderId ||
          typeof s.content !== "string" ||
          !s.content.length ||
          s.content.length > MAX_CONTENT
        ) {
          console.warn("scheduled: geçersiz kayıt düşürüldü", doc.id);
          await doc.ref.delete();
          continue;
        }

        const chatRef = db.collection("chats").doc(s.chatId);
        const chatSnap = await chatRef.get();
        if (!chatSnap.exists) {
          await doc.ref.delete();
          continue;
        }

        const members = chatSnap.get("memberIds") || [];

        // ── KRİTİK YETKİ KONTROLÜ ──
        // Bu fonksiyon Admin SDK ile çalışır ve güvenlik kurallarını ATLAR.
        // Üyelik burada doğrulanmazsa, kullanıcı üyesi OLMADIĞI herhangi
        // bir sohbete (özel birebir sohbetler dâhil) mesaj enjekte edebilir.
        if (!members.includes(s.senderId)) {
          console.warn("scheduled: gönderen artık üye değil", doc.id);
          await doc.ref.delete();
          continue;
        }

        // Susturulmuş / yalnız-yönetici kuralına da SUNUCUDA saygı duy
        const mutedUids = chatSnap.get("mutedUids") || [];
        const adminUids = chatSnap.get("adminUids") || [];
        const adminId = chatSnap.get("adminId") || "";
        const onlyAdmins = chatSnap.get("onlyAdminsCanPost") === true;
        const isAdmin = s.senderId === adminId || adminUids.includes(s.senderId);
        if (mutedUids.includes(s.senderId) || (onlyAdmins && !isAdmin)) {
          console.warn("scheduled: gönderim izni yok", doc.id);
          await doc.ref.delete();
          continue;
        }

        const sentIso = new Date().toISOString();
        const batch = db.batch();

        // 1) Mesajı oluştur (push bildirimi mevcut tetikleyiciyle otomatik)
        const msgRef = chatRef.collection("messages").doc();
        batch.set(msgRef, {
          id: msgRef.id,
          senderId: s.senderId,
          // `senderUsername` YAZILMAZ (metadata gizliligi): ad, gosterim
          // aninda uid'den istemcide cozulur.
          content: s.content,
          type: "text",
          status: "sent",
          // Sunucu ratchet işletemez (bilinçli ödün); alan adı istemciyle aynı.
          isE2EE: false,
          isDeleted: false,
          isEdited: false,
          timestamp: sentIso,
          readBy: [],
          deletedFor: [],
          // ŞEMA: istemci `reactions`'ı MAP olarak okur (uid -> emoji).
          // Buraya dizi yazmak istemcide tip hatasına ve sohbetin
          // tamamen açılmamasına yol açıyordu.
          reactions: {},
        });

        // 2) Sohbet özeti — GİZLİLİK: içerik önizlemeye YAZILMAZ.
        const upd = {
          lastMessage: "🔒 Mesaj",
          lastMessageTime: sentIso,
          lastMessageSenderId: s.senderId,
        };
        for (const uid of members) {
          if (uid !== s.senderId) {
            upd["unreadCounts." + uid] = FieldValue.increment(1);
          }
        }
        batch.update(chatRef, upd);

        // 3) Zamanlanmış kaydı kaldır
        batch.delete(doc.ref);
        await batch.commit();
      } catch (e) {
        console.error("scheduled send failed", doc.id, e);
        // ── ZEHİRLİ KAYIT KORUMASI ──
        // Sürekli hata veren kayıt kuyruğu sonsuza kadar tıkamasın.
        const attempts = (s.attempts || 0) + 1;
        if (attempts >= 3) {
          console.error("scheduled: 3 denemede başarısız, düşürüldü", doc.id);
          await doc.ref.delete().catch(() => {});
        } else {
          await doc.ref.update({ attempts }).catch(() => {});
        }
      }
    }
  }
);

// ─────────────────────────────────────────────────────────────
// 3) E2EE — TEK KULLANIMLIK ÖN-ANAHTAR TÜKETİMİ (ATOMİK)
//
// Neden sunucuda: istemci karşı tarafın `keyBundles/{uid}` dokümanını
// güncelleyemez (kural: yalnızca sahibi yazar) — bu yüzden eski istemci
// kodu PERMISSION_DENIED alıyor ve E2EE oturumu HİÇ kurulamıyordu.
// Ayrıca iki istemci aynı anda aynı ön-anahtarı alıp "tek kullanımlık"
// garantisini bozuyordu. Transaction ikisini de çözer.
// ─────────────────────────────────────────────────────────────
exports.claimPreKey = onCall(async (req) => {
  if (!req.auth) {
    throw new HttpsError("unauthenticated", "Oturum gerekli");
  }
  const userId = req.data && req.data.userId;
  if (typeof userId !== "string" || !userId) {
    throw new HttpsError("invalid-argument", "userId gerekli");
  }

  const ref = db.collection("keyBundles").doc(userId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const d = snap.data() || {};
    const opks = Array.isArray(d.oneTimePreKeys) ? d.oneTimePreKeys : [];
    const opk = opks.length > 0 ? opks[0] : null;
    if (opk) {
      tx.update(ref, { oneTimePreKeys: opks.slice(1) });
    }
    return {
      identityKey: d.identityKey || null,
      signedPreKey: d.signedPreKey || null,
      // Hangi SPK'nin verildigi: karsi taraf on-anahtarlarini
      // tazelemis olsa bile dogru ozel anahtari secebilsin diye.
      signedPreKeyId: d.signedPreKeyId || null,
      // Istemcinin destekledigi ratchet surumu (yoksa 2 = DH ratchet yok)
      ratchetVersion: d.ratchetVersion || 2,
      signedPreKeySignature: d.signedPreKeySignature || null,
      signingPublicKey: d.signingPublicKey || null,
      oneTimePreKeyId: opk ? opk.keyId : null,
      oneTimePreKey: opk ? opk.publicKey : null,
      remainingPreKeys: opk ? opks.length - 1 : 0,
    };
  });
});

// ─────────────────────────────────────────────────────────────
// 4) GELEN ARAMA BİLDİRİMİ
// ─────────────────────────────────────────────────────────────
exports.sendCallNotification = onDocumentCreated(
  "calls/{callId}",
  async (event) => {
    const call = event.data ? event.data.data() : null;
    if (!call || !call.calleeId || !call.callerId) return;

    const status = call.status || "dialing";
    if (status !== "dialing" && status !== "ringing") return;

    const token = await getPushToken(call.calleeId);
    if (!token) return;

    const isVideo = call.type === "video";
    const caller = call.callerUsername || "";

    try {
      await admin.messaging().send({
        token,
        notification: {
          title: caller ? "@" + caller : "SECRETER",
          body: isVideo ? "Görüntülü arama" : "Sesli arama",
        },
        data: {
          type: "incoming_call",
          callId: event.params.callId,
          callerId: String(call.callerId),
          callerUsername: String(caller),
          callType: isVideo ? "video" : "audio",
        },
        android: {
          priority: "high",
          ttl: 45000, // çağrı süresi kadar; sonradan düşmesin
          notification: {
            channelId: "gizlichat_channel",
            sound: "default",
            priority: "max",
          },
        },
      });
    } catch (e) {
      console.error("Arama bildirimi gönderilemedi:", e);
    }
  }
);

// ─────────────────────────────────────────────────────────────
// 5) CEVAPSIZ ÇAĞRI BİLDİRİMİ
// ─────────────────────────────────────────────────────────────
exports.sendMissedCallNotification = onDocumentCreated(
  "callLogs/{callId}",
  async (event) => {
    const log = event.data ? event.data.data() : null;
    if (!log || log.status !== "missed" || !log.calleeId) return;

    const token = await getPushToken(log.calleeId);
    if (!token) return;

    try {
      await admin.messaging().send({
        token,
        notification: {
          title: log.callerUsername ? "@" + log.callerUsername : "SECRETER",
          body: "Cevapsız çağrı",
        },
        data: {
          type: "missed_call",
          callId: String(log.callId || ""),
          callerId: String(log.callerId || ""),
        },
        android: {
          priority: "high",
          notification: { channelId: "gizlichat_channel" },
        },
      });
    } catch (e) {
      console.error("Cevapsız çağrı bildirimi gönderilemedi:", e);
    }
  }
);

// ─────────────────────────────────────────────────────────────
// 6) SÜRESİ DOLAN HİKÂYELERİ TEMİZLE (doküman + dosya)
// ─────────────────────────────────────────────────────────────
exports.cleanupExpiredStories = onSchedule(
  { schedule: "every 60 minutes" },
  async () => {
    const now = new Date();
    const nowIso = now.toISOString();

    // DAYANIKLILIK: `expiresAt` bazı kayıtlarda ISO string, bazılarında
    // Timestamp olabilir. Tek tipte sorgulamak, diğer tipteki kayıtları
    // SONSUZA KADAR temizlenmemiş bırakıyordu (sürekli artan depolama
    // gideri). Bu yüzden iki sorgu birleştirilir.
    const [byString, byStamp] = await Promise.all([
      db.collection("stories").where("expiresAt", "<=", nowIso).limit(200).get(),
      db
        .collection("stories")
        .where("expiresAt", "<=", admin.firestore.Timestamp.fromDate(now))
        .limit(200)
        .get()
        .catch(() => ({ docs: [] })),
    ]);

    const seen = new Set();
    const docs = [];
    for (const d of [...byString.docs, ...(byStamp.docs || [])]) {
      if (!seen.has(d.id)) {
        seen.add(d.id);
        docs.push(d);
      }
    }
    if (docs.length === 0) return;

    let files = 0;
    for (const doc of docs) {
      const s = doc.data() || {};
      const path = storagePathFromUrl(s.mediaUrl || s.imageUrl || "");
      if (await deleteStorageObject(path)) files++;
      await doc.ref.delete();
    }
    console.log(`Hikâye temizliği: ${docs.length} kayıt, ${files} dosya`);
  }
);

// ─────────────────────────────────────────────────────────────
// 6b) SÜRESİ DOLAN MESAJLARI TEMİZLE ("kaybolan mesaj")
//
// ── NEDEN VAR ──
// Kaybolan mesajı SUNUCUDAN silen tek şey OKUYAN İSTEMCİYDİ:
// `MessageRepositoryImpl` akıştaki mesajın `isExpired` olduğunu görünce
// `hardDeleteMessage` çağırıyordu. Yani vaat üç koşula bağlıydı:
//
//   1. birinin o sohbeti AÇMASI,
//   2. istemcinin değiştirilmemiş olması,
//   3. silme çağrısının başarılı olması.
//
// Üçü de tutmazsa mesaj sunucuda SÜRESİZ kalırdı — kullanıcı ise
// "kayboldu" sanıyordu. Hikâyelerde bu iş `cleanupExpiredStories` ile
// zaten sunucuda yapılıyordu; mesajlarda karşılığı yoktu.
//
// Bu, C-07'nin ("çözülmüş mesajlar cihazda sonsuza kadar kalıyordu")
// sunucu tarafındaki eşidir.
//
// ── ⚠️ İKİ SORGU ŞART: EŞİTSİZLİK SÜZGEÇLERİ **TİP KAPSAMLIDIR** ──
// Emülatörde ölçüldü: Firestore'da `<=` karşılaştırması yalnızca
// KARŞILAŞTIRILAN TİPTEKİ değerleri döndürür. Yani
//
//     .where("expiresAt", "<=", nowIso)      // string
//
// `expiresAt` alanı Timestamp olarak yazılmış bir mesajı **hiçbir
// zaman** eşleştirmez — o kayıt sessizce temizlenmeden kalır. Bu tam
// olarak `cleanupExpiredStories`in belgelediği durum: aynı alan bu
// projede "bazı kayıtlarda ISO string, bazılarında Timestamp".
//
// İstemci bugün ISO string yazıyor (`MessageModel.toMap()`), ama tek
// tipe güvenmek hikâyelerde zaten bir kez sonsuza kadar temizlenmeyen
// kayıt üretmişti. Bu yüzden iki sorgu birleştirilir.
//
// ⚠️ Ölçmeden önce buraya iki YANLIŞ gerekçe yazıldı ("null tuzağı",
// "Timestamp'ler yanlışlıkla eşleşir"); ikisini de emülatör çürüttü.
// Sorgu davranışını değiştirecek olan, önce
// `test/rules/firestore.rules.test.js` içindeki ölçüm testlerine
// baksın — varsayımla yazmak burada VERİ KAYBI demek.
// ─────────────────────────────────────────────────────────────
exports.cleanupExpiredMessages = onSchedule(
  { schedule: "every 30 minutes" },
  async () => {
    const now = new Date();
    const nowIso = now.toISOString();
    const BATCH = 200; // Firestore toplu yazma sınırı 500
    const MAX_ROUNDS = 5; // tek çalıştırmada üst sınır (maliyet/süre)

    let total = 0;
    for (let round = 0; round < MAX_ROUNDS; round++) {
      const [byString, byStamp] = await Promise.all([
        db
          .collectionGroup("messages")
          .where("expiresAt", "<=", nowIso)
          .limit(BATCH)
          .get(),
        db
          .collectionGroup("messages")
          .where("expiresAt", "<=", admin.firestore.Timestamp.fromDate(now))
          .limit(BATCH)
          .get()
          .catch(() => ({ docs: [], size: 0 })),
      ]);

      const seen = new Set();
      const refs = [];
      for (const d of [...byString.docs, ...(byStamp.docs || [])]) {
        if (seen.has(d.ref.path)) continue;
        seen.add(d.ref.path);
        refs.push(d.ref);
      }
      if (refs.length === 0) break;

      // Medya dosyaları BURADA silinmez: `cleanupDeletedMessageMedia`
      // onDelete tetikleyicisi zaten her silinen mesajın ekini
      // topluyor. İki yerde silmek, ayrışabilecek ikinci bir yol
      // açmak olurdu.
      const batch = db.batch();
      for (const ref of refs) batch.delete(ref);
      await batch.commit();

      total += refs.length;
      // Her iki sorgu da dolmadıysa elde kalan yok.
      if (byString.size < BATCH && (byStamp.size || 0) < BATCH) break;
    }

    if (total > 0) {
      console.log(`Kaybolan mesaj temizliği: ${total} kayıt silindi`);
    }
  }
);

// ─────────────────────────────────────────────────────────────
// 7) SİLİNEN MESAJIN MEDYASINI DA SİL
//
// İki tetikleyici gerekir:
//  • onDelete → "kendini imha" ve kalıcı silme (doküman gider)
//  • onUpdate → "herkesten sil" (doküman KALIR, isDeleted=true olur)
// Eskiden yalnızca onDelete vardı; "herkesten sil" akışı dokümanı
// güncellediği için medya dosyaları Storage'da YETİM kalıyordu ve
// mediaUrl temizlendiği için bir daha bulunamıyordu.
// ─────────────────────────────────────────────────────────────
exports.cleanupDeletedMessageMedia = onDocumentDeleted(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const msg = event.data ? event.data.data() : null;
    if (!msg) return;
    await deleteStorageObject(
      storagePathFromUrl(msg.mediaUrl || msg.mediaUrlBackup || "")
    );
  }
);

// ⚠️ İSTEMCİYLE SÖZLEŞME — TEK GÖRÜNTÜLÜK MEDYA
//
// İstemci `storage.delete()` ÇAĞIRAMAZ: `storage.rules` sohbet medyası
// için `allow update, delete: if false;` diyor (bilinçli — yoksa
// herhangi bir üye başkasının medyasını silebilirdi). Dosyayı SİLEN
// yer burasıdır.
//
// Tetikleyen: `message_remote_datasource.dart → consumeViewOnce`,
// mesaj dokümanına `{'mediaUrl': ''}` yazar. Aşağıdaki koşul TAM OLARAK
// o yazmaya bakar; istemci `mediaUrl`'i boş dizeden başka bir şeye
// çevirirse (placeholder, null yerine metin vb.) bu silme SESSİZCE
// çalışmaz ve dosya Storage'da yetim kalır.
exports.cleanupSoftDeletedMedia = onDocumentUpdated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    // Yeni silinmiş VEYA tek görüntülük tüketilmiş
    const justDeleted = !before.isDeleted && after.isDeleted === true;
    const justConsumed =
      before.mediaUrl && !after.mediaUrl && after.viewOnce === true;
    if (!justDeleted && !justConsumed) return;

    const url = before.mediaUrl || "";
    if (!url) return;
    await deleteStorageObject(storagePathFromUrl(url));
  }
);

// ─────────────────────────────────────────────────────────────
// 8) ESKİ ARAMA KAYITLARINI TEMİZLE
//
// GİZLİLİK: `calls/*/callerCandidates` ve `calleeCandidates` ICE
// adayları IP ADRESİ içerir. Bu dokümanlar hiç silinmiyordu; yani her
// aramanın iki tarafının IP'si veritabanında SONSUZA KADAR kalıyordu.
// ─────────────────────────────────────────────────────────────
exports.cleanupStaleCalls = onSchedule(
  { schedule: "every 30 minutes" },
  async () => {
    const cutoff = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const stale = await db
      .collection("calls")
      .where("createdAt", "<=", cutoff)
      .limit(200)
      .get();
    if (stale.empty) return;

    for (const doc of stale.docs) {
      for (const sub of ["callerCandidates", "calleeCandidates"]) {
        const kids = await doc.ref.collection(sub).get();
        if (kids.empty) continue;
        const batch = db.batch();
        kids.docs.forEach((k) => batch.delete(k.ref));
        await batch.commit();
      }
      await doc.ref.delete();
    }
    console.log(`Eski arama temizliği: ${stale.size} kayıt`);
  }
);

// ─────────────────────────────────────────────────────────────
// 9) SÜRESİ DOLAN KULLANICI ADI REZERVASYONLARINI TEMİZLE
//
// Eskiden bunu İSTEMCİ yapmaya çalışıyordu; güvenlik kuralı silmeyi
// reddettiği için, süresi dolmuş bir adı almak isteyen kullanıcının
// KAYDI TAMAMEN PATLIYORDU. Temizlik sunucuya taşındı.
// ─────────────────────────────────────────────────────────────
exports.cleanupReleasedUsernames = onSchedule(
  { schedule: "every 24 hours" },
  async () => {
    const nowIso = new Date().toISOString();
    const expired = await db
      .collection("releasedUsernames")
      .where("releaseAt", "<=", nowIso)
      .limit(500)
      .get();
    if (expired.empty) return;

    // ── 🔴 SİLMEDEN ÖNCE SAHİPLİĞİ DOĞRULA (§4cm) ──
    //
    // Eskiden burada `usernames/<belgeKimliği>` KÖRÜ KÖRÜNE siliniyordu.
    // Bu, güvenlik kuralındaki boşlukla birleşince kullanıcı adı
    // hırsızlığına yol açıyordu: saldırgan kurbanın adıyla geçmiş
    // tarihli bir rezervasyon yazıyor, bu fonksiyon da kurbanın dizin
    // kaydını siliyordu.
    //
    // Kural artık sahipliği zorunlu kılıyor ama BURADA DA doğruluyoruz:
    // tek katmana güvenmek, o katman bir gün gevşetilirse sessizce
    // açığı geri getirir. İki yerde birden kontrol etmek, kuralın
    // ileride değişmesine karşı bağışıklık sağlar.
    //
    // ⚠️ FAIL-SAFE: rezervasyonda `uid` yoksa (bu düzeltmeden ÖNCE
    // yazılmış eski kayıtlar) dizin kaydına DOKUNULMAZ. En kötü ihtimalle
    // bir ad gereğinden uzun rezerve kalır — yanlış kişinin adını silmek
    // ise geri alınamaz.
    const batch = db.batch();
    let dizinSilinen = 0;
    let atlanan = 0;

    for (const d of expired.docs) {
      batch.delete(d.ref); // rezervasyon her hâlükârda kalkar

      const rezervUid = d.data() && d.data().uid;
      if (!rezervUid) {
        atlanan++;
        continue;
      }

      const dizinRef = db.collection("usernames").doc(d.id);
      const dizin = await dizinRef.get();
      if (dizin.exists && dizin.data().uid === rezervUid) {
        batch.delete(dizinRef);
        dizinSilinen++;
      } else {
        // Dizin kaydı başkasına ait ya da hiç yok: DOKUNMA.
        atlanan++;
      }
    }

    await batch.commit();
    console.log(
      `Kullanıcı adı rezervasyonu temizliği: ${expired.size} rezervasyon, ` +
        `${dizinSilinen} dizin kaydı silindi, ${atlanan} atlandı`
    );
  }
);

// ─────────────────────────────────────────────────────────────
// 10) KAMUYA AÇIK KANAL DİZİNİNİ SENKRONLA
//
// NEDEN GEREKLİ: Kanal arama eskiden `chats` koleksiyonunu sorguluyordu;
// bu, üye OLMAYAN birinin her kanalın ÜYE LİSTESİNİ, üye adlarını, son
// mesajını ve ayarlarını okuyabilmesi demekti. Güvenlik kuralı artık
// `chats` listelemeyi yalnızca kişinin KENDİ sohbetleriyle sınırlıyor.
//
// Keşif için gereken az miktarda alan bu ayrı dizinde tutulur. Tek
// yazıcısı bu fonksiyondur (istemci yazamaz) — böylece dizin her zaman
// doğru kalır ve üyelik/yasak bilgisi ASLA sızmaz.
// ─────────────────────────────────────────────────────────────
exports.syncChannelDirectory = onDocumentWritten(
  "chats/{chatId}",
  async (event) => {
    const chatId = event.params.chatId;
    const after = event.data.after.exists ? event.data.after.data() : null;
    const ref = db.collection("channels").doc(chatId);

    // Kanal değilse (veya silindiyse) dizinden kaldır
    if (!after || after.type !== "channel") {
      await ref.delete().catch(() => {});
      return;
    }

    const name = String(after.groupName || "");
    await ref.set(
      {
        chatId,
        name,
        // Önek araması için küçük harfli kopya (index'li sorgu)
        nameLower: name.toLowerCase(),
        description: String(after.description || ""),
        avatarUrl: after.avatarUrl || null,
        memberCount:
          typeof after.memberCount === "number"
            ? after.memberCount
            : (after.memberIds || []).length,
        updatedAt: new Date().toISOString(),
      },
      { merge: true }
    );
  }
);

// ─────────────────────────────────────────────────────────────
// 11) HESAP VERİLERİNİ TAM SİL (KVKK/GDPR silme hakkı)
//
// İstemci yalnızca kendi kullanıcı dokümanını silebiliyordu; anahtar
// paketi, sohbet üyelikleri, çağrı kayıtları, buluşma kodları, hikâye
// medyası ve zamanlanmış mesajlar GERİDE KALIYORDU.
// ─────────────────────────────────────────────────────────────
exports.deleteAccountData = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Oturum gerekli");
  const uid = req.auth.uid;

  // 1) Anahtar paketi + gizli alt dokümanlar
  await db.recursiveDelete(db.collection("users").doc(uid)).catch(() => {});
  await db.collection("keyBundles").doc(uid).delete().catch(() => {});

  // 2) Sohbetlerden çıkar (üyeliği kalan sohbetler "hayalet üye" gösteriyordu)
  const chats = await db
    .collection("chats")
    .where("memberIds", "array-contains", uid)
    .get();
  for (const c of chats.docs) {
    const members = c.get("memberIds") || [];
    if (members.length <= 1) {
      // Son üye: tüm sohbeti ve mesajlarını sil
      await db.recursiveDelete(c.ref).catch(() => {});
    } else {
      await c.ref
        .update({
          memberIds: FieldValue.arrayRemove(uid),
          memberCount: FieldValue.increment(-1),
          adminUids: FieldValue.arrayRemove(uid),
          mutedUids: FieldValue.arrayRemove(uid),
          [`unreadCounts.${uid}`]: FieldValue.delete(),
        })
        .catch(() => {});
    }
  }

  // 3) Hikâyeler (doküman + medya)
  const stories = await db
    .collection("stories")
    .where("userId", "==", uid)
    .get();
  for (const s of stories.docs) {
    await deleteStorageObject(
      storagePathFromUrl((s.data() || {}).mediaUrl || "")
    );
    await s.ref.delete().catch(() => {});
  }

  // 4) Profil fotoğrafı
  await deleteStorageObject(`avatars/${uid}.jpg`);

  // 5) Zamanlanmış mesajlar + buluşma kodları
  for (const [col, field] of [
    ["scheduledMessages", "senderId"],
    ["meetCodes", "ownerUid"],
    ["inviteCodes", "ownerUid"],
  ]) {
    const snap = await db.collection(col).where(field, "==", uid).get();
    if (snap.empty) continue;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit().catch(() => {});
  }

  // 6) Çağrı kayıtlarını anonimleştir (karşı taraf için kayıt kalmalı)
  const logs = await db
    .collection("callLogs")
    .where("participants", "array-contains", uid)
    .get();
  for (const l of logs.docs) {
    await l.ref
      .update({ deletedFor: FieldValue.arrayUnion(uid) })
      .catch(() => {});
  }

  // 7) Auth kullanıcısını sil
  await admin.auth().deleteUser(uid).catch((e) => {
    console.error("auth kullanıcısı silinemedi", uid, e);
  });

  return { ok: true };
});


// ─────────────────────────────────────────────────────────────
// 12) TURN KİMLİK BİLGİSİ — KISA ÖMÜRLÜ
//
// NEDEN SUNUCUDAN: TURN parolasını `--dart-define` ile APK'ya gömmek,
// Giphy anahtarında yaşanan sorunun (H-19) aynısıdır — APK'dan
// çıkarılabilir, herkes sunucuyu kullanabilir ve döndürmek için yeni
// sürüm yayınlamak gerekir. Coturn'ün `use-auth-secret` şemasında sır
// YALNIZCA sunucuda durur; istemciye saatlerle ölçülen, kendiliğinden
// geçersizleşen bir kimlik verilir.
//
//   username = <bitiş-zaman-damgası>:<opak-kimlik>
//   password = base64(HMAC-SHA1(TURN_SECRET, username))
//
// GİZLİLİK: kullanıcı adında uid KULLANILMAZ, rastgele opak bir değer
// üretilir. TURN sunucusu zaten iki tarafın IP'sini görür; oraya bir de
// hesap kimliği yazmak IP ile hesabı kalıcı olarak ilişkilendirirdi.
// Bunun bedeli, kötüye kullanımın kullanıcı bazında izlenememesidir —
// bu uygulamada bağlanamazlık bilinçli olarak önceliklidir.
//
// YAPILANDIRMA (ikisi de process.env üzerinden okunur):
//   TURN_SECRET       — coturn `static-auth-secret` ile AYNI değer
//   TURN_URLS         — virgülle ayrılmış liste (turn:/turns:)
//   TURN_TTL_SECONDS  — isteğe bağlı, varsayılan 43200 (12 saat)
//
// Basit kurulum: `functions/.env` (git'e girmez).
// Daha iyisi: Secret Manager —
//   firebase functions:secrets:set TURN_SECRET
// ve aşağıdaki onCall seçeneklerine `secrets: ["TURN_SECRET"]` eklenir;
// bağlanan sır yine process.env üzerinden okunur, gövde DEĞİŞMEZ.
// (Varsayılanda bağlanmaz: sır tanımlı değilken bağlamak, TURN
// kullanmayan bir projede `firebase deploy --only functions` komutunu
// tamamen kırardı.)
//
// Ayrıntılı kurulum: TURN_KURULUMU.md
// ─────────────────────────────────────────────────────────────
const TURN_TTL_DEFAULT = 43200; // 12 saat
const TURN_TTL_MIN = 300; // 5 dk — çok kısa olursa arama ortasında düşer
const TURN_TTL_MAX = 86400; // 24 saat — çalınan kimliğin ömrü sınırlı kalsın

function turnTtlSeconds() {
  const raw = parseInt(process.env.TURN_TTL_SECONDS || "", 10);
  if (!Number.isFinite(raw)) return TURN_TTL_DEFAULT;
  return Math.min(Math.max(raw, TURN_TTL_MIN), TURN_TTL_MAX);
}

exports.getTurnCredentials = onCall(async (req) => {
  if (!req.auth) {
    throw new HttpsError("unauthenticated", "Oturum gerekli");
  }

  const secret = (process.env.TURN_SECRET || "").trim();
  const urls = (process.env.TURN_URLS || "")
    .split(",")
    .map((u) => u.trim())
    .filter(Boolean);

  // YAPILANDIRILMAMIŞSA HATA FIRLATMA. TURN yokken de arama kurulabilmeli
  // (STUN'a düşer, IP görünür). Burada hata fırlatmak, TURN'ü hiç
  // kurmamış bir projede TÜM aramaları kıracaktı.
  if (!secret || urls.length === 0) {
    return { configured: false };
  }

  const ttl = turnTtlSeconds();
  const expiresAt = Math.floor(Date.now() / 1000) + ttl;
  // Opak kimlik: hesapla ilişkilendirilemez, çakışma olasılığı ihmal
  // edilebilir (72 bit).
  const opaque = crypto.randomBytes(9).toString("base64url");
  const { username, credential } = buildTurnCredential(
    secret,
    expiresAt,
    opaque,
  );

  return { configured: true, urls, username, credential, expiresAt, ttl };
});

// ─────────────────────────────────────────────────────────────
// 🎟️ PREMIUM YETKİSİ — KÖR İMZA İLE (hesaba BAĞLANMAZ)
//
// ── NEDEN BÖYLE ──
// Akla ilk gelen `users/{uid}.isPremium = true` yazmaktır. Bu, telefon
// numarası istemeyen bir uygulamada anonim hesabı Google Play satın
// almasına bağlar ve şu zinciri kurar:
//
//     gerçek kimlik → Play hesabı → satın alma → SECRETER uid → sohbetler
//
// Uygulamanın tüm iddiası bu zincirin kurulamamasına dayanıyor.
//
// Bunun yerine sunucu, GÖRMEDİĞİ bir değeri imzalar (Chaum kör imzası).
// İstemci körlüğü kaldırır; elinde sunucunun hiç görmediği bir gövde
// üzerine geçerli imza kalır. Yetki sunulduğunda sunucu "bu geçerli"
// der ama "bu şu satın almadan geldi" DİYEMEZ.
//
// ── ⚠️ KİMLİK DOĞRULAMA YOK — KASITLI ──
// Bu fonksiyon `onCall` DEĞİL, `onRequest`tir ve Firebase kimliği
// İSTEMEZ. `onCall` kullanılsaydı sunucu çağrıyla birlikte uid'yi
// görürdü ve kör imzanın tüm anlamı kaybolurdu. Kanıt, satın alma
// jetonunun kendisidir.
//
// ── ⚠️ NE SAKLANIR, NE SAKLANMAZ ──
// Saklanan: satın alma jetonunun ÖZETİ + körleştirilmiş değerin ÖZETİ.
// SAKLANMAYAN: körleştirilmiş değerin KENDİSİ ve kör imza.
//
// Sebep kritik: sunucu `blinded` ve `blindSignature` değerlerini
// saklarsa, sonradan sunulan (nonce, sig) için
//     r' = blindSignature · sig⁻¹   ve   blinded =? FDH(nonce) · r'ᵉ
// eşitliğini sınayıp sunumu satın almaya BAĞLAYABİLİR. Yani jetonu
// saklamak, kör imzayı anlamsız kılar.
//
// Özet saklamak bu saldırıyı mümkün kılmaz (özetten `blinded` geri
// getirilemez) ama TEKRAR DENEMEYİ mümkün kılar: ağ koptuysa istemci
// AYNI körleştirilmiş değerle tekrar çağırır, sunucu özetin eşleştiğini
// görüp yeniden imzalar. RSA imzası deterministik olduğu için sonuç
// aynıdır. Böylece "kullanıcı ödedi ama yetki alamadı" durumu oluşmaz.
// ─────────────────────────────────────────────────────────────

/// Dönem anahtarları. Her dönem AYRI anahtar kullanılır çünkü yetkinin
/// son kullanma tarihi jetonun içine yazılamaz (sunucu körleştirilmiş
/// değeri görmez). Geçerlilik penceresi ANAHTARIN kendisindedir.
///
/// ⚠️ Anonimlik kümesi = o dönemde yetki alan HERKES. Dönem ne kadar
/// kısa olursa küme o kadar küçülür ve bağlanabilirlik artar; aylıktan
/// daha kısa yapılmamalıdır.
///
/// Özel anahtarlar ortam değişkeninden gelir (PEM):
///   ENTITLEMENT_KEY_<KIMLIK>   ör. ENTITLEMENT_KEY_PREM_2026_10
function entitlementPrivateKey(keyId) {
  const envName = "ENTITLEMENT_KEY_" + keyId.toUpperCase().replace(/-/g, "_");
  const pem = process.env[envName];
  if (!pem) return null;
  return crypto.createPrivateKey(pem);
}

/// Ham RSA imzalama: s = b^d mod n.
///
/// Doldurma (padding) YOK — kör imzada doldurmayı istemci yapar (FDH).
/// `RSA_NO_PADDING` ile `privateDecrypt` tam olarak modüler üs alma
/// yapar; Node'da ham RSA'ya erişmenin yolu budur.
function rawRsaSign(privateKey, blindedHex) {
  const keyBytes = privateKey.asymmetricKeyDetails.modulusLength / 8;
  const buf = Buffer.from(blindedHex.padStart(keyBytes * 2, "0"), "hex");
  if (buf.length !== keyBytes) throw new Error("blinded_size");
  const out = crypto.privateDecrypt(
    { key: privateKey, padding: crypto.constants.RSA_NO_PADDING },
    buf
  );
  return out.toString("hex").replace(/^0+/, "") || "0";
}

const sha256Hex = (s) =>
  crypto.createHash("sha256").update(String(s)).digest("hex");

exports.issueEntitlement = onRequest(
  { cors: true },
  async (req, res) => {
    try {
      if (req.method !== "POST") return res.status(405).json({ error: "method" });

      const { purchaseToken, productId, blinded, keyId } = req.body || {};
      if (!purchaseToken || !productId || !blinded || !keyId) {
        return res.status(400).json({ error: "missing_fields" });
      }
      if (!/^[0-9a-fA-F]+$/.test(blinded)) {
        return res.status(400).json({ error: "bad_blinded" });
      }

      const privateKey = entitlementPrivateKey(keyId);
      if (!privateKey) return res.status(400).json({ error: "unknown_key" });

      // ⚠️ TODO — GOOGLE PLAY DOĞRULAMASI.
      // Burada `androidpublisher.purchases.subscriptionsv2.get` (ya da
      // ürün için `purchases.products.get`) çağrılmalı ve şunlar
      // doğrulanmalı: jeton bu ürüne ait, ödeme tamamlanmış, iptal/iade
      // edilmemiş. Bunun için Play Console'da bir hizmet hesabı ve
      // "Finansal veriler" yetkisi gerekir.
      //
      // Doğrulama olmadan bu uç nokta HERKESE premium dağıtır; bu
      // yüzden anahtar yoksa zaten `unknown_key` ile düşer ve üretimde
      // anahtar tanımlanmadan çalıştırılmamalıdır.
      const purchaseVerified = false; // ← Play doğrulaması bağlanınca true
      if (!purchaseVerified) {
        return res.status(501).json({ error: "play_verification_not_configured" });
      }

      // ── TEK KULLANIM + GÜVENLİ TEKRAR DENEME ──
      const ref = db.collection("entitlementRedemptions").doc(sha256Hex(purchaseToken));
      const blindedHash = sha256Hex(blinded);

      const decision = await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) {
          tx.set(ref, {
            // ⚠️ Satın alma jetonu ve körleştirilmiş değer SAKLANMAZ —
            // yalnızca özetleri. Bkz. yukarıdaki gerekçe.
            blindedHash,
            productId,
            keyId,
            createdAt: new Date().toISOString(),
          });
          return "sign";
        }
        // Aynı istek tekrar geldi → aynı imzayı üret (deterministik).
        if (snap.data().blindedHash === blindedHash) return "sign";
        // Farklı bir körleştirilmiş değer → aynı satın almadan İKİNCİ
        // yetki çıkarma denemesi.
        return "already_redeemed";
      });

      if (decision !== "sign") {
        return res.status(409).json({ error: "already_redeemed" });
      }

      return res.json({ signature: rawRsaSign(privateKey, blinded), keyId });
    } catch (e) {
      console.error("issueEntitlement hatası:", e && e.message);
      return res.status(500).json({ error: "internal" });
    }
  }
);
