/**
 * SECRETER — FIRESTORE GÜVENLİK KURALLARI TESTLERİ
 *
 * NEDEN BU DOSYA VAR:
 * Denetimde bulunan KRİTİK açıkların tamamı güvenlik kurallarındaydı ve
 * hiçbiri test edilmiyordu. Kural dosyası sessizce bozulabilen bir yerdir:
 * derlenmez, tip kontrolü yoktur, hata verirse yalnızca üretimde görülür.
 * Buradaki her test, giderilen GERÇEK bir açığa karşılık gelir.
 *
 * ÇALIŞTIRMA:
 *   npm --prefix test/rules ci
 *   firebase emulators:exec --only firestore "npm --prefix test/rules test"
 */

const fs = require("fs");
const path = require("path");
const { describe, it, before, after, beforeEach } = require("mocha");
const { expect } = require("chai");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  collectionGroup,
  getDocs,
  query,
  where,
  arrayUnion,
  arrayRemove,
  deleteField,
  Timestamp,
} = require("firebase/firestore");

const PROJECT_ID = "secreter-rules-test";

// Sohbet kimliği birebir sohbetlerde sıralı uid'lerden türetilir; bu,
// "chatId tahmin edilebilir" saldırısının temelidir.
const ALICE = "uidAlice";
const BOB = "uidBob";
const MALLORY = "uidMallory";
const DM = [ALICE, BOB].sort().join("_");

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../firestore.rules"),
        "utf8"
      ),
    },
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Başlangıç verisi kuralları ATLAYARAK yazılır (arrange aşaması).
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `users/${ALICE}`), { username: "alice" });
    await setDoc(doc(db, `users/${BOB}`), { username: "bob" });
    await setDoc(doc(db, `users/${MALLORY}`), { username: "mallory" });
    await setDoc(doc(db, `users/${BOB}/private/blocks`), { uids: [] });

    // Alice ↔ Bob ÖZEL birebir sohbeti
    await setDoc(doc(db, `chats/${DM}`), {
      id: DM,
      type: "direct",
      memberIds: [ALICE, BOB],
      memberUsernames: ["alice", "bob"],
      memberCount: 2,
      lastMessage: "🔒 Mesaj",
      lastMessageTime: new Date().toISOString(),
    });
    await setDoc(doc(db, `chats/${DM}/messages/m1`), {
      id: "m1",
      senderId: ALICE,
      content: "gizli içerik",
      type: "text",
      isE2EE: true,
      timestamp: new Date().toISOString(),
      readBy: [],
      deletedFor: [],
      reactions: {},
    });

    // Alice'in sahibi olduğu grup (Bob üye, Mallory değil)
    await setDoc(doc(db, "chats/group1"), {
      id: "group1",
      type: "group",
      memberIds: [ALICE, BOB],
      adminId: ALICE,
      adminUids: [ALICE],
      mutedUids: [],
      onlyAdminsCanPost: false,
      memberCount: 2,
    });

    // Açık kanal
    await setDoc(doc(db, "chats/chan1"), {
      id: "chan1",
      type: "channel",
      memberIds: [ALICE],
      memberUsernames: ["alice"],
      adminId: ALICE,
      adminUids: [ALICE],
      mutedUids: [],
      bannedIds: [MALLORY],
      onlyAdminsCanPost: true,
      memberCount: 1,
    });

    // Arama (Alice → Bob)
    await setDoc(doc(db, "calls/call1"), {
      callerId: ALICE,
      calleeId: BOB,
      participants: [ALICE, BOB],
      status: "ringing",
      createdAt: new Date().toISOString(),
    });
    // Adresli aday (yeni şema): Alice'ten Bob'a
    await setDoc(doc(db, "calls/call1/candidates/c1"), {
      from: ALICE,
      to: BOB,
      candidate: "candidate:1 1 udp 2130706431 192.168.1.42 54321 typ host",
    });
    // Adresli SDP (teklif): Alice'ten Bob'a
    await setDoc(doc(db, "calls/call1/sdp/alice__bob"), {
      from: ALICE,
      to: BOB,
      type: "offer",
      sdp: "v=0 ... a=candidate:1 1 udp 1 192.168.1.42 5000 typ host",
    });

    // GRUP çağrısı — `calleeId` YOKTUR (mesh, §4bq)
    await setDoc(doc(db, "calls/grup1"), {
      callerId: ALICE,
      participants: [ALICE, BOB],
      groupChatId: "group1",
      isGroup: true,
      status: "ringing",
      createdAt: new Date().toISOString(),
    });

    // Şema değişiminden ÖNCE yazılmış çağrı (participants YOK)
    await setDoc(doc(db, "calls/eski1"), {
      callerId: ALICE,
      calleeId: BOB,
      status: "ongoing",
      createdAt: new Date().toISOString(),
    });
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

// ────────────────────────────────────────────────────────────
describe("chats — üyelik ve katılma", () => {
  it("üye kendi sohbetini okuyabilir", async () => {
    await assertSucceeds(getDoc(doc(as(ALICE), `chats/${DM}`)));
  });

  it("üye olmayan sohbeti okuyamaz", async () => {
    await assertFails(getDoc(doc(as(MALLORY), `chats/${DM}`)));
  });

  // ⚠️ C-01: EN KRİTİK AÇIK.
  // Eski kural, kişinin yalnızca üyelik alanlarını değiştirmesi koşuluyla
  // kendini HERHANGİ bir sohbete eklemesine izin veriyordu; sohbetin açık
  // kanal olup olmadığı kontrol edilmiyordu. Birebir sohbet kimliği
  // tahmin edilebilir olduğu için herhangi bir kullanıcı iki kişinin
  // özel sohbetine girip TÜM geçmişi okuyabiliyordu.
  it("YABANCI kendini ÖZEL birebir sohbete EKLEYEMEZ", async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), `chats/${DM}`), {
        memberIds: arrayUnion(MALLORY),
      })
    );
  });

  it("YABANCI kendini ÖZEL GRUBA ekleyemez", async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), "chats/group1"), {
        memberIds: arrayUnion(MALLORY),
      })
    );
  });

  // Katılma artık YALNIZCA uid yazar; ad dizisi kaldırıldı (§4o).
  it("kullanıcı AÇIK KANALA kendini ekleyebilir", async () => {
    await assertSucceeds(
      updateDoc(doc(as(BOB), "chats/chan1"), {
        memberIds: arrayUnion(BOB),
        memberCount: 2,
      })
    );
  });

  it("YASAKLI kullanıcı kanala katılamaz", async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), "chats/chan1"), {
        memberIds: arrayUnion(MALLORY),
      })
    );
  });

  it("kanala katılırken BAŞKA alan değiştirilemez", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "chats/chan1"), {
        memberIds: arrayUnion(BOB),
        onlyAdminsCanPost: false, // yetki yükseltme denemesi
      })
    );
  });

  it("kanala katılırken BAŞKASI eklenemez", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "chats/chan1"), {
        memberIds: arrayUnion(BOB, MALLORY),
      })
    );
  });

  it("katılan kişi mevcut üyeyi ÇIKARAMAZ", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "chats/chan1"), {
        memberIds: [BOB], // Alice silindi
      })
    );
  });

  it("üye olmayan biri sohbeti SİLEMEZ", async () => {
    await assertFails(deleteDoc(doc(as(MALLORY), "chats/group1")));
  });

  // Eskiden HER ÜYE tüm sohbeti silebiliyordu.
  it("sıradan üye grubu silemez, yönetici silebilir", async () => {
    await assertFails(deleteDoc(doc(as(BOB), "chats/group1")));
    await assertSucceeds(deleteDoc(doc(as(ALICE), "chats/group1")));
  });

  it("sohbet listeleme yalnızca KENDİ sohbetlerini döndürür", async () => {
    // Kanal istisnası kaldırıldı: üye olmayan biri kanal dokümanlarını
    // (üye listesi + son mesaj dâhil) listeleyemez.
    await assertFails(
      getDocs(query(collection(as(MALLORY), "chats"), where("type", "==", "channel")))
    );
    await assertSucceeds(
      getDocs(
        query(collection(as(ALICE), "chats"), where("memberIds", "array-contains", ALICE))
      )
    );
  });
});

// ────────────────────────────────────────────────────────────
// 🕵️ METADATA GİZLİLİĞİ — 2. AŞAMA
//
// Sohbet dokümanı `memberUsernames: ["alice","bob"]` taşıyordu. İçerik
// şifreli olsa bile bu, sosyal grafiği sunucuda ADLARIYLA okunur
// bırakıyordu — telefon numarası istemeyen bir uygulamada asıl açık.
//
// İstemciden kaldırmak YETMEZ: değiştirilmiş ya da eski bir istemci
// alanı geri yazabilir. Kural bunu sunucuda kapatır.
//
// Seed verisinde `chats/${DM}` ve `chats/chan1` alanı DOLU tutulur;
// bunlar 2. aşamadan ÖNCE yazılmış dokümanları temsil eder.
describe("üye adları sohbet dokümanında tutulmaz", () => {
  it("YENİ sohbet ad dizisiyle OLUŞTURULAMAZ", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), "chats/yeni1"), {
        id: "yeni1",
        type: "direct",
        memberIds: [MALLORY, BOB],
        memberUsernames: ["mallory", "bob"],
        memberCount: 2,
      })
    );
  });

  it("YENİ sohbet adsız oluşturulabilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(MALLORY), "chats/yeni2"), {
        id: "yeni2",
        type: "direct",
        memberIds: [MALLORY, BOB],
        memberCount: 2,
      })
    );
  });

  it("kanala katılırken ad EKLENEMEZ", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "chats/chan1"), {
        memberIds: arrayUnion(BOB),
        memberUsernames: arrayUnion("bob"),
        memberCount: 2,
      })
    );
  });

  // Yönetici yolu "her şeyi değiştirebilir" olduğu için kısıt onun da
  // ÜZERİNDE durmalı; yoksa adları geri yazmanın açık kapısı kalırdı.
  it("YÖNETİCİ bile ad dizisi yazamaz", async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), "chats/chan1"), {
        memberUsernames: ["alice", "bob"],
      })
    );
  });

  it("ad dizisi BAŞKA bir değerle değiştirilemez", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), `chats/${DM}`), {
        memberUsernames: ["alice", "sahte"],
      })
    );
  });

  // "Artık yazmıyoruz" demek, YAZILMIŞ olanı ortadan kaldırmaz. Eski
  // dokümanlardaki adların temizlenebilmesi için silme bilinçli olarak
  // açıktır (ChatMetadataScrub bunu kullanır).
  it("üye ESKİ ad dizisini SİLEBİLİR", async () => {
    await assertSucceeds(
      updateDoc(doc(as(BOB), `chats/${DM}`), {
        memberUsernames: deleteField(),
      })
    );
  });

  it("ÜYE OLMAYAN ad dizisini silemez", async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), `chats/${DM}`), {
        memberUsernames: deleteField(),
      })
    );
  });

  // ⚠️ REGRESYON KORUMASI — §4m'nin dersi.
  // `request.resource.data` yazma SONRASI dokümandır: alanın varlığını
  // topyekûn yasaklamak, alanı hâlâ taşıyan ESKİ sohbetlerdeki HER
  // güncellemeyi (mesaj önizlemesi, okundu sayacı) kırardı.
  it("eski dokümandaki alan İLGİSİZ güncellemeleri kırmaz", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), `chats/${DM}`), {
        lastMessage: "🔒 Mesaj",
        lastMessageTime: new Date().toISOString(),
      })
    );
  });

  it("eski dokümanda mesaj gönderme çalışmaya devam eder", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), `chats/${DM}/messages/m2`), {
        id: "m2",
        senderId: ALICE,
        content: "şifreli",
        type: "text",
        timestamp: new Date().toISOString(),
      })
    );
  });
});

// ────────────────────────────────────────────────────────────
describe("messages — yazarlık ve yetki", () => {
  it("üye mesajları okuyabilir, yabancı okuyamaz", async () => {
    await assertSucceeds(getDoc(doc(as(BOB), `chats/${DM}/messages/m1`)));
    await assertFails(getDoc(doc(as(MALLORY), `chats/${DM}/messages/m1`)));
  });

  it("kendi adına mesaj gönderilebilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(BOB), `chats/${DM}/messages/m2`), {
        senderId: BOB,
        content: "selam",
        type: "text",
        timestamp: new Date().toISOString(),
      })
    );
  });

  it("BAŞKASININ adına mesaj gönderilemez", async () => {
    await assertFails(
      setDoc(doc(as(BOB), `chats/${DM}/messages/m3`), {
        senderId: ALICE, // kimlik taklidi
        content: "Alice'ten sahte mesaj",
        type: "text",
        timestamp: new Date().toISOString(),
      })
    );
  });

  // ⚠️ H-08: eski kural `allow update, delete: if isChatMember()` idi;
  // yani bir grup üyesi BAŞKASININ mesajını değiştirebiliyor/silebiliyordu.
  it("BAŞKASININ mesaj İÇERİĞİ değiştirilemez", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), `chats/${DM}/messages/m1`), {
        content: "değiştirilmiş içerik",
      })
    );
  });

  it("okundu/tepki alanları her üye tarafından güncellenebilir", async () => {
    await assertSucceeds(
      updateDoc(doc(as(BOB), `chats/${DM}/messages/m1`), {
        readBy: arrayUnion(BOB),
        [`reactions.${BOB}`]: "❤️",
      })
    );
  });

  it("gönderen kendi mesajını silebilir, başkası silemez", async () => {
    await assertFails(deleteDoc(doc(as(BOB), `chats/${DM}/messages/m1`)));
    await assertSucceeds(deleteDoc(doc(as(ALICE), `chats/${DM}/messages/m1`)));
  });

  // ── GRUPTAN AYRILMA ──
  //
  // Bu yol hiç test edilmiyordu. `isSelfLeave()` yalnızca
  // ['memberIds','memberUsernames','members','memberCount'] degisimine
  // izin veriyor; istemci ise `adminUids` ve `mutedUids` de yaziyordu.
  // `arrayRemove` bir sey cikarmiyorsa dizi degismez ve `affectedKeys`
  // onu gormez — yani sorun yalnizca kisi GERCEKTEN o dizideyse cikar.

  it("sıradan üye gruptan AYRILABİLİR", async () => {
    await assertSucceeds(
      updateDoc(doc(as(BOB), "chats/group1"), {
        memberIds: arrayRemove(BOB),
        memberCount: 1,
      })
    );
  });

  it("ayrılırken BAŞKASINI çıkaramaz", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "chats/group1"), {
        memberIds: arrayRemove(ALICE),
        memberCount: 1,
      })
    );
  });

  it("🐞 SUSTURULMUŞ üye ayrılırken mutedUids'e DOKUNAMAZ", async () => {
    // Susturulmus bir uye `mutedUids`ten de cikmaya calisirsa dizi
    // GERCEKTEN degisir, `onlyChanges` duser ve AYRILMA TAMAMEN
    // REDDEDILIR — kisi gruba kilitlenir.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "chats/group1"), {
        mutedUids: [BOB],
      });
    });
    await assertFails(
      updateDoc(doc(as(BOB), "chats/group1"), {
        memberIds: arrayRemove(BOB),
        memberCount: 1,
        mutedUids: arrayRemove(BOB),
      })
    );
    // Dokunmazsa ayrilabilir. Kalan `mutedUids` girdisi zararsizdir:
    // `canPost()` zaten uyelik de istiyor. Ustelik ayrilip yeniden
    // katilarak susturmadan KACILAMAZ olmasi dogru davranistir.
    await assertSucceeds(
      updateDoc(doc(as(BOB), "chats/group1"), {
        memberIds: arrayRemove(BOB),
        memberCount: 1,
      })
    );
  });

  it("YÖNETİCİ ayrılırken adminUids'ten de çıkabilir", async () => {
    // Yonetici yolu `isAdmin()` uzerinden gecer ve her alani degistirebilir.
    // ⚠️ Bu ZORUNLU: `isAdmin()` uyelik degil YALNIZCA `adminUids` bakar,
    // yani ayrilan bir yonetici dizide kalirsa gruba yonetici olarak
    // hukmetmeye devam eder.
    await assertSucceeds(
      updateDoc(doc(as(ALICE), "chats/group1"), {
        memberIds: arrayRemove(ALICE),
        adminUids: arrayRemove(ALICE),
        memberCount: 1,
      })
    );
  });

  it("üye çıkarırken `members` dizisi UID ile yeniden yazılabilir", async () => {
    // Istemci artik `arrayRemove([tamHarita])` yerine listeyi uid'e gore
    // suzup geri yaziyor (§4ak). Yonetici yolu buna izin vermeli.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "chats/group1"), {
        members: [
          { uid: ALICE, role: "owner", isMuted: false, joinedAt: "2026-01-01" },
          { uid: BOB, username: "bob", role: "member", isMuted: false,
            joinedAt: "2026-01-02" },
        ],
      });
    });
    await assertSucceeds(
      updateDoc(doc(as(ALICE), "chats/group1"), {
        memberIds: [ALICE],
        members: [
          { uid: ALICE, role: "owner", isMuted: false, joinedAt: "2026-01-01" },
        ],
        memberCount: 1,
      })
    );
  });

  it("ESKİ adlar `members` içinden temizlenebilir (§3b/7)", async () => {
    // `usernameArrayNotGrown()` yalnizca TOP-LEVEL `memberUsernames`
    // dizisini kisitliyor; `members[].username` temizligi yoneticiye
    // acik. Bu test o izni kilitler.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "chats/group1"), {
        members: [
          { uid: ALICE, username: "alice", role: "owner", isMuted: false,
            joinedAt: "2026-01-01" },
        ],
      });
    });
    await assertSucceeds(
      updateDoc(doc(as(ALICE), "chats/group1"), {
        members: [
          { uid: ALICE, role: "owner", isMuted: false, joinedAt: "2026-01-01" },
        ],
      })
    );
  });

  it("SUSTURULMUŞ üye mesaj gönderemez", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "chats/group1"), {
        mutedUids: [BOB],
      });
    });
    await assertFails(
      setDoc(doc(as(BOB), "chats/group1/messages/x"), {
        senderId: BOB,
        content: "susturulmuşum ama yazıyorum",
        type: "text",
        timestamp: new Date().toISOString(),
      })
    );
  });

  it("'yalnızca yöneticiler' açıkken sıradan üye gönderemez", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "chats/group1"), {
        onlyAdminsCanPost: true,
      });
    });
    await assertFails(
      setDoc(doc(as(BOB), "chats/group1/messages/y"), {
        senderId: BOB,
        content: "yönetici değilim",
        type: "text",
        timestamp: new Date().toISOString(),
      })
    );
    await assertSucceeds(
      setDoc(doc(as(ALICE), "chats/group1/messages/z"), {
        senderId: ALICE,
        content: "yöneticiyim",
        type: "text",
        timestamp: new Date().toISOString(),
      })
    );
  });

  it("aşırı büyük içerik reddedilir", async () => {
    await assertFails(
      setDoc(doc(as(BOB), `chats/${DM}/messages/big`), {
        senderId: BOB,
        content: "x".repeat(20000),
        type: "text",
        timestamp: new Date().toISOString(),
      })
    );
  });
});

// ────────────────────────────────────────────────────────────
describe("calls — ICE adayları (IP ifşası)", () => {
  // ⚠️ C-03: eski kural `allow read, write: if signedIn()` idi. ICE
  // adayları IP ADRESİ taşır; yani HERHANGİ bir kullanıcı her aramanın
  // iki tarafının genel/yerel IP'sini okuyabiliyor ve sahte aday
  // enjekte edebiliyordu. Anonimlik iddiasının tam çöküşü.
  it("YABANCI ICE adaylarını (IP) OKUYAMAZ", async () => {
    await assertFails(getDoc(doc(as(MALLORY), "calls/call1/candidates/c1")));
  });

  it("YABANCI sahte ICE adayı enjekte edemez", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), "calls/call1/candidates/evil"), {
        from: MALLORY,
        to: BOB,
        candidate: "candidate:evil 1 udp 1 10.0.0.1 1234 typ host",
      })
    );
  });

  it("aramanın tarafları adayları okuyup yazabilir", async () => {
    await assertSucceeds(getDoc(doc(as(BOB), "calls/call1/candidates/c1")));
    await assertSucceeds(
      setDoc(doc(as(BOB), "calls/call1/candidates/c2"), {
        from: BOB,
        to: ALICE,
        candidate: "candidate:2 1 udp 1 1.2.3.4 5678 typ srflx",
      })
    );
  });

  // ⚠️ BAŞKASI ADINA aday yazmak, çağrıya sahte rota enjekte etmek
  // demektir — kurbanın trafiği saldırganın adresine yönlendirilebilirdi.
  it("taraf bile BAŞKASI ADINA aday yazamaz", async () => {
    await assertFails(
      setDoc(doc(as(BOB), "calls/call1/candidates/sahte"), {
        from: ALICE, // Bob, Alice'miş gibi yazıyor
        to: BOB,
        candidate: "candidate:3 1 udp 1 5.6.7.8 9999 typ host",
      })
    );
  });

  // ── GRUP ARAMASININ ASIL KAZANIMI ──
  // Eski şemada bir tarafın TÜM adaylarını diğer taraf okuyabiliyordu.
  // İki kişide sorun değildi; üç kişide A, B↔C adaylarını — yani onların
  // IP ADRESLERİNİ — okuyabilirdi. C-03'ün grup hâli.
  it("ÜÇÜNCÜ KATILIMCI, diğer ikisinin adaylarını (IP) GÖREMEZ", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "calls/grup1"), {
        callerId: ALICE,
        calleeId: BOB,
        participants: [ALICE, BOB, MALLORY],
        status: "ongoing",
        createdAt: new Date().toISOString(),
      });
      await setDoc(doc(db, "calls/grup1/candidates/ab"), {
        from: ALICE,
        to: BOB,
        candidate: "candidate:1 1 udp 1 192.168.1.42 54321 typ host",
      });
    });
    // Mallory çağrının KATILIMCISI ama bu aday ona adreslenmedi.
    await assertFails(getDoc(doc(as(MALLORY), "calls/grup1/candidates/ab")));
    // Alıcısı okuyabilir.
    await assertSucceeds(getDoc(doc(as(BOB), "calls/grup1/candidates/ab")));
  });

  it("KATILIMCI çağrı dokümanını okuyabilir (grup)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "calls/grup2"), {
        callerId: ALICE,
        calleeId: BOB,
        participants: [ALICE, BOB, MALLORY],
        status: "ongoing",
      });
    });
    await assertSucceeds(getDoc(doc(as(MALLORY), "calls/grup2")));
  });

  // ⚠️ §4m'nin dersi: kural bir alanı zorunlu kılmadan önce ESKİ
  // dokümanların ne olacağı düşünülmeli. Şema değişiminin tam o anında
  // devam eden bir arama, dizisi olmadığı için kopardı.
  it("ESKİ şemadaki (participants YOK) arama erişilebilir kalır", async () => {
    await assertSucceeds(getDoc(doc(as(BOB), "calls/eski1")));
    await assertSucceeds(getDoc(doc(as(ALICE), "calls/eski1")));
    await assertFails(getDoc(doc(as(MALLORY), "calls/eski1")));
  });

  it("çağrı OLUŞTURAN kendini katılımcı yazmak ZORUNDA", async () => {
    await assertFails(
      setDoc(doc(as(ALICE), "calls/sahte1"), {
        callerId: ALICE,
        calleeId: BOB,
        participants: [BOB, MALLORY], // Alice listede yok
        status: "ringing",
        createdAt: new Date().toISOString(),
      })
    );
  });

  it("yabancı arama dokümanını okuyamaz", async () => {
    await assertFails(getDoc(doc(as(MALLORY), "calls/call1")));
  });

  it("ENGELLENEN kullanıcı arama başlatamaz", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${BOB}/private/blocks`), {
        uids: [MALLORY],
      });
    });
    await assertFails(
      setDoc(doc(as(MALLORY), "calls/call2"), {
        callerId: MALLORY,
        calleeId: BOB,
        status: "ringing",
        createdAt: new Date().toISOString(),
      })
    );
  });
});

// ────────────────────────────────────────────────────────────
describe("users — gizli alanlar", () => {
  it("profil okunabilir (arama için gerekli)", async () => {
    await assertSucceeds(getDoc(doc(as(MALLORY), `users/${ALICE}`)));
  });

  it("BAŞKASININ gizli engel listesi OKUNAMAZ", async () => {
    await assertFails(getDoc(doc(as(MALLORY), `users/${BOB}/private/blocks`)));
  });

  it("BAŞKASININ push token'ı okunamaz", async () => {
    await assertFails(getDoc(doc(as(MALLORY), `users/${BOB}/private/push`)));
  });

  it("kişi kendi gizli dokümanını okuyup yazabilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(BOB), `users/${BOB}/private/blocks`), { uids: [MALLORY] })
    );
  });

  // Hassas alanlar herkese açık dokümanda tutulmamalı.
  it("fcmToken/blockedUids kullanıcı dokümanına YAZILAMAZ", async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), `users/${ALICE}`), { fcmToken: "abc" })
    );
    await assertFails(
      updateDoc(doc(as(ALICE), `users/${ALICE}`), { blockedUids: [BOB] })
    );
  });

  it("başkasının profili değiştirilemez", async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), `users/${ALICE}`), { username: "hacked" })
    );
  });
});

// ────────────────────────────────────────────────────────────
describe("usernames — atomik rezervasyon", () => {
  it("boş adı kendi adına rezerve edebilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), "usernames/yenisim"), { uid: ALICE })
    );
  });

  it("başkası adına rezerve edilemez", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), "usernames/sahte"), { uid: ALICE })
    );
  });

  // Yarış durumu SUNUCUDA çözülür: ikinci yazan kaybeder.
  it("ALINMIŞ ad EZİLEMEZ", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), "usernames/kapisma"), { uid: ALICE })
    );
    await assertFails(
      setDoc(doc(as(MALLORY), "usernames/kapisma"), { uid: MALLORY })
    );
  });
});

// ────────────────────────────────────────────────────────────
describe("keyBundles — E2EE anahtarları", () => {
  it("herkes açık anahtar paketini okuyabilir", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `keyBundles/${BOB}`), {
        identityKey: "abc",
        oneTimePreKeys: [{ keyId: "k1", publicKey: "p1" }],
      });
    });
    await assertSucceeds(getDoc(doc(as(ALICE), `keyBundles/${BOB}`)));
  });

  // ⚠️ C-09: istemci karşı tarafın paketinden ön-anahtar TÜKETMEYE
  // çalışıyordu; kural bunu reddediyor ve E2EE oturumu HİÇ kurulamıyordu.
  // Tüketim artık sunucudaki `claimPreKey` fonksiyonunda.
  it("BAŞKASININ anahtar paketi DEĞİŞTİRİLEMEZ", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `keyBundles/${BOB}`), {
        identityKey: "abc",
        oneTimePreKeys: [{ keyId: "k1", publicKey: "p1" }],
      });
    });
    await assertFails(
      updateDoc(doc(as(ALICE), `keyBundles/${BOB}`), { oneTimePreKeys: [] })
    );
  });

  it("kişi kendi paketini yayınlayabilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), `keyBundles/${ALICE}`), {
        identityKey: "mine",
        signedPreKey: "spk",
        signedPreKeySignature: "sig",
      })
    );
  });
});

// ────────────────────────────────────────────────────────────
describe("stories / kodlar / şikâyetler", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "stories/s1"), {
        userId: ALICE,
        mediaUrl: "https://x/y.jpg",
        viewedBy: [],
        expiresAt: new Date(Date.now() + 3600e3).toISOString(),
      });
      await setDoc(doc(ctx.firestore(), "inviteCodes/CODE1234"), {
        chatId: "group1",
        ownerUid: ALICE,
      });
      await setDoc(doc(ctx.firestore(), "meetCodes/ABCD2345"), {
        ownerUid: ALICE,
        usedBy: null,
        expiresAt: new Date(Date.now() + 300e3).toISOString(),
      });
    });
  });

  // ⚠️ H-09: eski kural `allow update: if signedIn()` idi — herkes her
  // hikâyeyi TAMAMEN ezebiliyordu.
  it("başkasının hikâyesi EZİLEMEZ, yalnızca görüntülenme eklenir", async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), "stories/s1"), {
        mediaUrl: "https://evil/defaced.jpg",
      })
    );
    await assertSucceeds(
      updateDoc(doc(as(MALLORY), "stories/s1"), {
        viewedBy: arrayUnion(MALLORY),
      })
    );
  });

  it("başkasının hikâyesi silinemez", async () => {
    await assertFails(deleteDoc(doc(as(MALLORY), "stories/s1")));
    await assertSucceeds(deleteDoc(doc(as(ALICE), "stories/s1")));
  });

  // ⚠️ H-10: eskiden HERKES tüm davet kodlarını silebiliyordu (DoS).
  it("başkasının davet kodu silinemez", async () => {
    await assertFails(deleteDoc(doc(as(MALLORY), "inviteCodes/CODE1234")));
    await assertSucceeds(deleteDoc(doc(as(ALICE), "inviteCodes/CODE1234")));
  });

  it("buluşma kodunda yalnızca kullanım alanları işaretlenebilir", async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), "meetCodes/ABCD2345"), { ownerUid: MALLORY })
    );
    await assertSucceeds(
      updateDoc(doc(as(MALLORY), "meetCodes/ABCD2345"), {
        usedBy: MALLORY,
        usedByUsername: "mallory",
        usedAt: new Date().toISOString(),
      })
    );
  });

  it("KULLANILMIŞ kod tekrar işaretlenemez", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "meetCodes/ABCD2345"), {
        usedBy: BOB,
      });
    });
    await assertFails(
      updateDoc(doc(as(MALLORY), "meetCodes/ABCD2345"), { usedBy: MALLORY })
    );
  });

  it("şikâyet yazılabilir ama OKUNAMAZ", async () => {
    await assertSucceeds(
      setDoc(doc(as(BOB), "reports/r1"), {
        reporterUid: BOB,
        reportedUid: MALLORY,
        reason: "report_spam",
        createdAt: new Date().toISOString(),
      })
    );
    await assertFails(getDoc(doc(as(BOB), "reports/r1")));
  });

  it("başkası adına şikâyet yazılamaz", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), "reports/r2"), {
        reporterUid: BOB,
        reportedUid: ALICE,
        reason: "report_spam",
      })
    );
  });
});

// ────────────────────────────────────────────────────────────
describe("scheduledMessages — enjeksiyon koruması", () => {
  // ⚠️ C-10: kural yalnızca senderId kontrol ediyordu. Cloud Function
  // Admin SDK ile çalışıp kuralları ATLADIĞI için, kullanıcı üyesi
  // OLMADIĞI bir sohbete mesaj enjekte edebiliyordu.
  it("üyesi OLMADIĞIN sohbete zamanlanmış mesaj yazılamaz", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), "scheduledMessages/s1"), {
        chatId: DM,
        senderId: MALLORY,
        content: "enjekte",
        sendAt: new Date().toISOString(),
      })
    );
  });

  it("kendi sohbetine zamanlanmış mesaj yazılabilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), "scheduledMessages/s2"), {
        chatId: DM,
        senderId: ALICE,
        content: "sonra gönder",
        sendAt: new Date().toISOString(),
      })
    );
  });

  it("başkası adına zamanlanmış mesaj yazılamaz", async () => {
    await assertFails(
      setDoc(doc(as(BOB), "scheduledMessages/s3"), {
        chatId: DM,
        senderId: ALICE,
        content: "sahte",
        sendAt: new Date().toISOString(),
      })
    );
  });
});

// ────────────────────────────────────────────────────────────
describe("groupKeys — grup E2EE anahtar dağıtımı", () => {
  // Grup mesajları artık uçtan uca şifreli. Her üye kendi "sender key"ini
  // her üyeye AYRI AYRI, ikili E2EE kanalıyla şifreli yollar. Bir üyenin
  // BAŞKASINA gönderilen zarfı okuyabilmesi, o grubun TÜM mesajlarını
  // çözebilmesi demekti — bu yüzden okuma sıkı kısıtlanır.
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `groupKeys/group1/dist/${BOB}__${ALICE}`), {
        from: ALICE,
        to: BOB,
        chatId: "group1",
        epoch: 1,
        payload: "sifreli-zarf",
      });
    });
  });

  it("alıcı kendi zarfını okuyabilir", async () => {
    await assertSucceeds(
      getDoc(doc(as(BOB), `groupKeys/group1/dist/${BOB}__${ALICE}`))
    );
  });

  it("gönderen kendi yolladığı zarfı okuyabilir", async () => {
    await assertSucceeds(
      getDoc(doc(as(ALICE), `groupKeys/group1/dist/${BOB}__${ALICE}`))
    );
  });

  it("ÜÇÜNCÜ KİŞİ başkasının anahtar zarfını OKUYAMAZ", async () => {
    await assertFails(
      getDoc(doc(as(MALLORY), `groupKeys/group1/dist/${BOB}__${ALICE}`))
    );
  });

  it("üye kendi adına anahtar dağıtabilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(BOB), `groupKeys/group1/dist/${ALICE}__${BOB}`), {
        from: BOB,
        to: ALICE,
        chatId: "group1",
        epoch: 2,
        payload: "zarf",
      })
    );
  });

  it("BAŞKASI ADINA anahtar dağıtılamaz (kimlik taklidi)", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), `groupKeys/group1/dist/${BOB}__${ALICE}`), {
        from: ALICE,
        to: BOB,
        chatId: "group1",
        epoch: 9,
        payload: "sahte",
      })
    );
  });

  it("gruba ÜYE OLMAYAN kişiye anahtar yollanamaz", async () => {
    await assertFails(
      setDoc(doc(as(ALICE), `groupKeys/group1/dist/${MALLORY}__${ALICE}`), {
        from: ALICE,
        to: MALLORY, // grup üyesi değil
        chatId: "group1",
        epoch: 3,
        payload: "zarf",
      })
    );
  });

  it("üye olmayan biri gruba anahtar yazamaz", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), `groupKeys/group1/dist/${BOB}__${MALLORY}`), {
        from: MALLORY,
        to: BOB,
        chatId: "group1",
        epoch: 4,
        payload: "zarf",
      })
    );
  });

  it("başkasının zarfı silinemez, kendi zarfı silinebilir", async () => {
    await assertFails(
      deleteDoc(doc(as(MALLORY), `groupKeys/group1/dist/${BOB}__${ALICE}`))
    );
    await assertSucceeds(
      deleteDoc(doc(as(ALICE), `groupKeys/group1/dist/${BOB}__${ALICE}`))
    );
  });
});

// ────────────────────────────────────────────────────────────
describe("channels — kamuya açık kanal dizini", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "channels/chan1"), {
        chatId: "chan1",
        name: "Duyurular",
        nameLower: "duyurular",
        memberCount: 1,
      });
    });
  });

  it("herkes kanal dizinini arayabilir", async () => {
    await assertSucceeds(getDoc(doc(as(MALLORY), "channels/chan1")));
    await assertSucceeds(getDocs(collection(as(MALLORY), "channels")));
  });

  // Dizin YALNIZCA Cloud Function (Admin SDK) tarafından yazılır.
  it("istemci kanal dizinine YAZAMAZ", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), "channels/sahte"), {
        name: "Sahte Kanal",
        nameLower: "sahte kanal",
      })
    );
    await assertFails(
      updateDoc(doc(as(ALICE), "channels/chan1"), { memberCount: 99999 })
    );
    await assertFails(deleteDoc(doc(as(MALLORY), "channels/chan1")));
  });

  // Dizin üyelik/yasak bilgisi TAŞIMAZ; keşif ile mahremiyet ayrışır.
  it("dizin üye listesi sızdırmaz", async () => {
    const snap = await getDoc(doc(as(MALLORY), "channels/chan1"));
    const data = snap.data();
    expect(data.memberIds, "dizin memberIds taşımamalı").to.equal(undefined);
    expect(data.memberUsernames).to.equal(undefined);
    expect(data.bannedIds).to.equal(undefined);
    expect(data.lastMessage).to.equal(undefined);
  });
});

// ────────────────────────────────────────────────────────────
// ÖLÜ YAZMA YÜZEYİ
//
// Kurallar, hiçbir istemcinin/fonksiyonun yazmadığı iki alana izin
// veriyordu: chats.typingUids ve callLogs.seenBy. Kimse okumadığı için
// mantığı etkilemiyordu ama her üyeye o dokümana istediği veriyi yazma
// kapısı açıyordu (doküman 1 MiB'a şişirilebilir ve her üye onu her
// okumada indirir). İzinler kaldırıldı; bu testler geri gelmesini
// engeller.
// Mevcut bir sohbette `memberUsernames` ÜZERİNE YAZILAMAZ: bir üye,
// karşı tarafın sohbet listesinde kendini başka biri gibi
// gösterebilirdi (sohbet listesi adı bu diziden okur).
//
// ⚠️ Bu kural doğru; ama istemci bunu ele almıyordu: doküman farklı bir
// kullanıcı adı listesiyle oluşmuşsa (ör. ilk yazımda kendi profilimiz
// henüz yüklenmemişse) `DirectChatService.getOrCreate` kalıcı olarak
// permission-denied alıyor ve o sohbet BİR DAHA AÇILAMIYORDU.
// İstemci artık bu durumda mevcut sohbeti döndürüyor.
describe("kullanıcı adı taklidi kapalı", () => {
  it("mevcut sohbette memberUsernames ÜZERİNE YAZILAMAZ", async () => {
    await assertFails(
      setDoc(
        doc(as(ALICE), `chats/${DM}`),
        {
          memberUsernames: ["alice", "SECRETER Destek"],
          lastMessageTime: new Date().toISOString(),
        },
        { merge: true }
      )
    );
  });

  it("yalnızca izinli alanları yazmak GEÇER", async () => {
    await assertSucceeds(
      setDoc(
        doc(as(ALICE), `chats/${DM}`),
        { lastMessageTime: new Date().toISOString() },
        { merge: true }
      )
    );
  });
});

describe("ölü yazma yüzeyi kapalı", () => {
  it("üye sohbete typingUids YAZAMAZ", async () => {
    // "Yazıyor" durumu users/{uid}.typingIn'de tutulur, sohbette değil.
    await assertFails(
      updateDoc(doc(as(ALICE), `chats/${DM}`), {
        typingUids: [ALICE],
      })
    );
  });

  it("izinli alan hâlâ yazılabilir (aşırı kısıtlama yok)", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), `chats/${DM}`), {
        [`unreadCounts.${BOB}`]: 1,
      })
    );
  });

  it("katılımcı çağrı kaydına seenBy YAZAMAZ", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "callLogs/call1"), {
        participants: [ALICE, BOB],
        deletedFor: [],
      });
    });

    await assertFails(
      updateDoc(doc(as(ALICE), "callLogs/call1"), { seenBy: [ALICE] })
    );
    // "Bende sil" çalışmaya devam etmeli.
    await assertSucceeds(
      updateDoc(doc(as(ALICE), "callLogs/call1"), { deletedFor: [ALICE] })
    );
  });
});

// ────────────────────────────────────────────────────────────
// GELEN ARAMA DİNLEYİCİSİ
//
// ⚠️ Kurallar ilk kez ÜRETİME dağıtıldığında ortaya çıktı: `calls`
// koleksiyonunda `allow list: if false` vardı ama istemci gelen aramayı
// bulmak için listelemek ZORUNDA. Sonuç: kullanıcı hiç arama alamıyordu.
// Doğru kısıt "listeleme yok" değil, "yalnızca kendi araman".
describe("gelen arama dinleyicisi", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "calls/call-in"), {
        callerId: BOB,
        calleeId: ALICE,
        participants: [BOB, ALICE],
        status: "ringing",
      });
    });
  });

  // Sorgu artık `participants` üzerinden: grup aramasında "aranan" diye
  // tek bir kişi yok, davet edilen HERKES gelen aramayı görmeli.
  it("kendi gelen aramalarını LİSTELEYEBİLİR", async () => {
    await assertSucceeds(
      getDocs(query(collection(as(ALICE), "calls"),
        where("participants", "array-contains", ALICE),
        where("status", "==", "ringing")))
    );
  });

  it("arayan da kendi aramalarını görebilir", async () => {
    await assertSucceeds(
      getDocs(query(collection(as(BOB), "calls"),
        where("callerId", "==", BOB)))
    );
  });

  it("TÜM aramalar DÖKÜLEMEZ", async () => {
    await assertFails(getDocs(collection(as(MALLORY), "calls")));
  });

  it("BAŞKASININ aramaları listelenemez", async () => {
    await assertFails(
      getDocs(query(collection(as(MALLORY), "calls"),
        where("participants", "array-contains", ALICE)))
    );
  });
});

// ────────────────────────────────────────────────────────────
// KULLANICI NUMARALANDIRMA
//
// `users` okuması `if signedIn()` idi ve bu LİSTELEME sorgusunu da
// kapsıyordu: giriş yapmış herhangi biri tüm kullanıcı tabanını
// dökebiliyordu (adlar, çevrimiçi durumu, avatarlar). Telefon numarası
// istemeyen bir uygulamada "kim kayıtlı" herkese açıktı.
describe("kullanıcı numaralandırma kapalı", () => {
  it("kullanıcı listesi DÖKÜLEMEZ", async () => {
    await assertFails(getDocs(collection(as(MALLORY), "users")));
  });

  it("ada göre SORGU da çalışmaz", async () => {
    await assertFails(
      getDocs(query(collection(as(MALLORY), "users"),
        where("username", "==", "alice")))
    );
  });

  it("uid BİLİNİYORSA profil okunabilir (avatar/ad çözümü)", async () => {
    // `get` korunmalı: uid ortak sohbetten ya da ad dizininden öğrenilir.
    await assertSucceeds(getDoc(doc(as(BOB), `users/${ALICE}`)));
  });

  it("ad dizini tekil okunur ama DÖKÜLEMEZ", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "usernames/alice"), { uid: ALICE });
    });

    await assertSucceeds(getDoc(doc(as(MALLORY), "usernames/alice")));
    await assertFails(getDocs(collection(as(MALLORY), "usernames")));
  });

  it("BAŞKASININ adına dizin kaydı açılamaz", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), "usernames/yeniad"), { uid: ALICE })
    );
  });
});

// ────────────────────────────────────────────────────────────
// 🎟️ PREMIUM YETKİSİ
//
// Yetkiler kör imza ile verilir: sunucu "biri ödedi" der, "bu uid
// ödedi" DEMEZ. Kullanım kaydı koleksiyonu istemciye tamamen kapalı
// olmalı — okunabilseydi kayıt zamanları üzerinden yetkiler satın
// almalara eşleştirilebilir ve bağlanamazlık yan kanaldan delinirdi.
describe("premium yetki kayıtları kapalı", () => {
  it("istemci kullanım kaydını OKUYAMAZ", async () => {
    await assertFails(getDoc(doc(as(ALICE), "entitlementRedemptions/x")));
  });

  it("istemci kullanım kaydı YAZAMAZ (sahte yetki üretemez)", async () => {
    await assertFails(
      setDoc(doc(as(ALICE), "entitlementRedemptions/x"), {
        blindedHash: "deadbeef",
        keyId: "prem-2026-10",
      })
    );
  });

  it("koleksiyon DÖKÜLEMEZ", async () => {
    await assertFails(getDocs(collection(as(ALICE), "entitlementRedemptions")));
  });
});

// ────────────────────────────────────────────────────────────
describe("kimliksiz erişim tamamen kapalı", () => {
  it("giriş yapmamış kullanıcı hiçbir şey okuyamaz", async () => {
    await assertFails(getDoc(doc(anon(), `users/${ALICE}`)));
    await assertFails(getDoc(doc(anon(), `chats/${DM}`)));
    await assertFails(getDoc(doc(anon(), `chats/${DM}/messages/m1`)));
  });

  it("tanımsız koleksiyon varsayılan olarak KAPALI", async () => {
    await assertFails(getDoc(doc(as(ALICE), "gizliKoleksiyon/x")));
    await assertFails(setDoc(doc(as(ALICE), "gizliKoleksiyon/x"), { a: 1 }));
  });
});

// ─────────────────────────────────────────────────────────────
// KAYBOLAN MESAJ TEMİZLİĞİ — `cleanupExpiredMessages` SORGUSU
//
// ⚠️ BU BİR KURAL TESTİ DEĞİL. Zamanlanmış bir Cloud Function'ın
// dayandığı FIRESTORE DAVRANIŞINI gerçek motora karşı kilitler.
// Yanlış bir sorgu burada izin hatası değil, VERİ KAYBI ya da hiç
// temizlenmeyen kayıt demektir.
//
// ── İKİ VARSAYIM ÖLÇÜLDÜ, İKİSİ DE YANLIŞ ÇIKTI ──
// 1. "null tuzağı": `MessageModel.toMap()` süre yoksa `expiresAt: null`
//    yazıyor; `<= now` sorgusunun bunları da eşleştireceği ve temizlik
//    işinin TÜM mesajları sileceği düşünülmüştü. → ÇÜRÜDÜ.
// 2. "Timestamp'ler yanlışlıkla eşleşir": tip sıralamasında Timestamp
//    String'den önce geldiği için gelecek tarihli Timestamp kayıtların
//    silineceği düşünülmüştü. → ÇÜRÜDÜ.
//
// Ölçülen gerçek: Firestore'da eşitsizlik süzgeçleri **TİP
// KAPSAMLIDIR** — string ile karşılaştırma yalnızca string döndürür.
// Risk bu yüzden ters yönde: string sorgusu, Timestamp yazılmış bir
// kaydı **hiçbir zaman** görmez ve o mesaj sonsuza kadar temizlenmeden
// kalır. `cleanupExpiredStories` aynı dersi daha önce almış ve iki
// sorgu kullanıyor; mesaj temizliği de öyle yapar.
// ─────────────────────────────────────────────────────────────
describe("kaybolan mesaj temizliği (cleanupExpiredMessages sorgusu)", () => {
  const GECMIS = "2020-01-01T00:00:00.000Z";
  const GELECEK = "2999-01-01T00:00:00.000Z";
  const simdi = new Date("2026-09-10T00:00:00Z");

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      // Süresi DOLMUŞ, string (silinmeli)
      await setDoc(doc(db, `chats/${DM}/messages/exp1`), {
        id: "exp1", senderId: ALICE, content: "x", type: "text",
        expiresAt: GECMIS,
      });
      // Süresi DOLMAMIŞ, string (durmalı)
      await setDoc(doc(db, `chats/${DM}/messages/exp2`), {
        id: "exp2", senderId: ALICE, content: "x", type: "text",
        expiresAt: GELECEK,
      });
      // Süre YOK, alan null (istemcinin gerçek davranışı — durmalı)
      await setDoc(doc(db, `chats/${DM}/messages/kalici1`), {
        id: "kalici1", senderId: ALICE, content: "x", type: "text",
        expiresAt: null,
      });
      // Süresi DOLMUŞ ama TIMESTAMP yazılmış (silinmeli)
      await setDoc(doc(db, "chats/group1/messages/stampGecmis"), {
        id: "stampGecmis", senderId: BOB, content: "x", type: "text",
        expiresAt: Timestamp.fromDate(new Date("2020-01-01T00:00:00Z")),
      });
      // Süresi DOLMAMIŞ, Timestamp (durmalı)
      await setDoc(doc(db, "chats/group1/messages/stampGelecek"), {
        id: "stampGelecek", senderId: BOB, content: "x", type: "text",
        expiresAt: Timestamp.fromDate(new Date("2999-01-01T00:00:00Z")),
      });
    });
  });

  async function sorgula(tipler) {
    let sonuc = new Set();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      if (tipler.includes("string")) {
        const snap = await getDocs(query(collectionGroup(db, "messages"),
          where("expiresAt", "<=", simdi.toISOString())));
        snap.docs.forEach((d) => sonuc.add(d.id));
      }
      if (tipler.includes("stamp")) {
        const snap = await getDocs(query(collectionGroup(db, "messages"),
          where("expiresAt", "<=", Timestamp.fromDate(simdi))));
        snap.docs.forEach((d) => sonuc.add(d.id));
      }
    });
    return [...sonuc].sort();
  }

  it("null taşıyan mesaj HİÇBİR sorguda eşleşmez", async () => {
    // 1. varsayımın çürüdüğünü kayda geçirir: alt sınıra gerek yok.
    expect(await sorgula(["string", "stamp"])).to.not.include("kalici1");
  });

  it("🔴 YALNIZCA string sorgusu, süresi dolmuş TIMESTAMP kaydı KAÇIRIR",
    async () => {
      // ⚠️ ASIL RİSK. Eşitsizlik tip kapsamlı olduğu için bu kayıt
      // sonsuza kadar temizlenmeden kalırdı — `cleanupExpiredStories`in
      // "sürekli artan depolama gideri" notunun aynısı.
      const eslesen = await sorgula(["string"]);
      expect(eslesen).to.include("exp1");
      expect(eslesen).to.not.include("stampGecmis");
    });

  it("✅ iki sorgu birlikte süresi dolmuş HER İKİ tipi de yakalar",
    async () => {
      const eslesen = await sorgula(["string", "stamp"]);
      expect(eslesen).to.deep.equal(["exp1", "stampGecmis"]);
    });

  it("✅ süresi DOLMAMIŞ kayıtlar hiçbir tipte eşleşmez", async () => {
    const eslesen = await sorgula(["string", "stamp"]);
    expect(eslesen).to.not.include("exp2");
    expect(eslesen).to.not.include("stampGelecek");
  });
});

// ─────────────────────────────────────────────────────────────
// GELEN ARAMA — SORGU GERÇEKTEN EŞLEŞİYOR MU?
//
// ⚠️ Yukarıdaki "gelen arama dinleyicisi" testleri `assertSucceeds`
// kullanıyor: sorgunun **İZİNLİ** olduğunu ölçüyorlar, **EŞLEŞTİĞİNİ**
// değil. §4u'nun hatası tam olarak "sorgu kuruluyor ama BOŞ dönüyor"du
// — yani o testler kırık hâlde de geçerdi. Fixture'ları da elle
// yazılmış; şema değişse fark etmezdi.
//
// Buradaki testler açığı kapatır:
//   1. Belge ELLE değil, Dart şemasından üretilen ALTIN DOSYADAN gelir
//      (`test/fixtures/call_incoming.golden.json`). Dart tarafındaki
//      `incoming_call_contract_test.dart` o dosyanın gerçek şemayla
//      aynı kaldığını doğruluyor.
//   2. Sorgu alan adları da altın dosyadan okunur — elle yazılmaz.
//   3. Sonucun BOŞ OLMADIĞI ve doğru çağrıyı içerdiği ölçülür.
//
// Böylece gelen aramanın iki tarihsel kırılması da otomatik doğrulamaya
// girer: §4m (kural reddi) ve §4u (şema/sorgu uyuşmazlığı).
// ─────────────────────────────────────────────────────────────
describe("gelen arama SORGUSU eşleşiyor (altın dosya sözleşmesi)", () => {
  const golden = JSON.parse(
    fs.readFileSync(
      path.resolve(__dirname, "../fixtures/call_incoming.golden.json"),
      "utf8"
    )
  );
  const BELGE = golden.belge;
  const S = golden.sorgu;

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `calls/${BELGE.id}`), BELGE);
    });
  });

  // Altın dosya ALICE/BOB uid'lerini kullanıyor; sabitlerle
  // uyuşmazlarsa test sessizce anlamsızlaşır.
  it("altın dosya bu testin uid sabitleriyle uyuşuyor", () => {
    expect(BELGE.calleeId).to.equal(ALICE);
    expect(BELGE.callerId).to.equal(BOB);
  });

  it("🔒 ARANAN kişi çağrıyı GERÇEKTEN görüyor (boş dönmüyor)", async () => {
    const snap = await getDocs(
      query(
        collection(as(ALICE), "calls"),
        where(S.katilimciAlani, "array-contains", ALICE),
        where(S.durumAlani, "==", S.calanDurum)
      )
    );
    expect(snap.empty, "gelen arama sorgusu BOŞ döndü — §4u tekrar ediyor")
      .to.equal(false);
    expect(snap.docs.map((d) => d.id)).to.include(BELGE.id);
  });

  it("🐞 `participants` YOKSA sorgu sessizce boş döner (§4u'nun hâli)",
    async () => {
      // §4u'nun neden fark edilmediğini belgeler: hata yok, izin var,
      // sorgu kuruluyor — yalnızca sonuç boş.
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const eksik = { ...BELGE, id: "call-eksik" };
        delete eksik[S.katilimciAlani];
        await setDoc(doc(ctx.firestore(), "calls/call-eksik"), eksik);
      });
      const snap = await getDocs(
        query(
          collection(as(ALICE), "calls"),
          where(S.katilimciAlani, "array-contains", ALICE),
          where(S.durumAlani, "==", S.calanDurum)
        )
      );
      expect(snap.docs.map((d) => d.id)).to.not.include("call-eksik");
    });

  it("çağrı ÇALMIYORSA gelen arama sorgusuna düşmez", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), `calls/${BELGE.id}`), {
        [S.durumAlani]: "ended",
      });
    });
    const snap = await getDocs(
      query(
        collection(as(ALICE), "calls"),
        where(S.katilimciAlani, "array-contains", ALICE),
        where(S.durumAlani, "==", S.calanDurum)
      )
    );
    // ⚠️ `snap.empty` KULLANMA: genel fixture ALICE'i başka bir
    // "ringing" çağrının (call1) katılımcısı yapıyor. Boşluk beklemek
    // testi alakasız veriye bağlar; hedef BU belgenin düşmesi.
    expect(snap.docs.map((d) => d.id)).to.not.include(BELGE.id);
  });

  it("KATILIMCI OLMAYAN aynı sorguyu çalıştırınca hiçbir şey görmez",
    async () => {
      const snap = await getDocs(
        query(
          collection(as(MALLORY), "calls"),
          where(S.katilimciAlani, "array-contains", MALLORY),
          where(S.durumAlani, "==", S.calanDurum)
        )
      );
      expect(snap.empty).to.equal(true);
    });

  it("GRUP araması: üçüncü katılımcı da çağrıyı görür", async () => {
    // §4t'nin asıl amacı buydu: "aranan" diye tek kişi yok.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "calls/call-grup"), {
        ...BELGE,
        id: "call-grup",
        [S.katilimciAlani]: [BOB, ALICE, MALLORY],
      });
    });
    const snap = await getDocs(
      query(
        collection(as(MALLORY), "calls"),
        where(S.katilimciAlani, "array-contains", MALLORY),
        where(S.durumAlani, "==", S.calanDurum)
      )
    );
    expect(snap.docs.map((d) => d.id)).to.include("call-grup");
  });
});

// ─────────────────────────────────────────────────────────────
// §4an — KATILMA VE ROL DEĞİŞİMİ İŞLEME TAŞINDI
//
// Yazma biçimi değişti: `arrayUnion`/`increment` yerine işlem içinde
// hesaplanmış TAM DİZİLER yazılıyor. Kural bunu kabul etmezse özellik
// tamamen kırılır, o yüzden burada kilitleniyor.
// ─────────────────────────────────────────────────────────────
describe("katılma/rol yazma biçimi kuralla uyumlu (§4an)", () => {
  it("kanala katılan TAM `memberIds` listesi yazabilir", async () => {
    // İşlem, diziyi okuyup kendini ekleyip geri yazıyor. `isSelfJoin()`
    // eklenen kümenin TAM OLARAK {ben} olmasını istiyor — tam liste
    // yazmak bu koşulu bozmamalı.
    await assertSucceeds(
      updateDoc(doc(as(BOB), "chats/chan1"), {
        memberIds: [ALICE, BOB],
        memberCount: 2,
      })
    );
  });

  it("katılan BAŞKASINI da ekleyemez", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "chats/chan1"), {
        memberIds: [ALICE, BOB, MALLORY],
        memberCount: 3,
      })
    );
  });

  it("YASAKLI kullanıcı katılamaz (ekran bu koda bakıyor)", async () => {
    // `channel_search_screen` `permission-denied`i "yasaklısın" diye
    // gösteriyor; MALLORY chan1'de `bannedIds` içinde.
    await assertFails(
      updateDoc(doc(as(MALLORY), "chats/chan1"), {
        memberIds: [ALICE, MALLORY],
        memberCount: 2,
      })
    );
  });

  it("yönetici `members` + düz dizileri birlikte yazabilir (rol değişimi)",
    async () => {
      // `updateMemberFields` işlemi bu üçünü tek yazmada gönderiyor.
      await assertSucceeds(
        updateDoc(doc(as(ALICE), "chats/group1"), {
          members: [
            { uid: ALICE, role: "owner", isMuted: false,
              joinedAt: "2026-01-01" },
            { uid: BOB, role: "admin", isMuted: true,
              joinedAt: "2026-01-02" },
          ],
          adminUids: [ALICE, BOB],
          mutedUids: [BOB],
        })
      );
    });

  it("sıradan üye rol değiştiremez", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "chats/group1"), {
        members: [{ uid: BOB, role: "owner", isMuted: false,
                    joinedAt: "2026-01-02" }],
        adminUids: [BOB],
      })
    );
  });
});

// ────────────────────────────────────────────────────────────
describe("arama: HİÇ ENGELLEMEMİŞ kullanıcı aranabilmeli", () => {
  // 🐞 CİHAZDA BULUNDU: yeni açılan bir hesap ARANAMIYOR.
  //
  // `calls` create kuralı `notBlockedBy(calleeId)` çağırır; o da
  // `users/{callee}/private/blocks` dokümanını `get()` ile okur.
  // Firestore'da OLMAYAN bir dokümanda `get()` null döner ve `.data`
  // erişimi kural değerlendirmesini HATAYA düşürür — hata = REDDET.
  //
  // `blocks` dokümanı yalnızca kişi BİRİNİ ENGELLEDİĞİNDE oluşur. Yani
  // yeni açılmış her hesap için o doküman yoktur ve kimse onu arayamaz.
  //
  // ⚠️ FIXTURE BU HATAYI ÖRTÜYORDU: `beforeEach` yalnızca BOB için
  // `blocks` yazıyor, o yüzden BOB'a yapılan aramalar hep geçiyordu.
  // MALLORY'nin dokümanı yok — gerçek dünyadaki yeni hesabın hâli.
  const cagri = (callee) => ({
    id: "yeniCagri",
    callerId: ALICE,
    calleeId: callee,
    participants: [ALICE, callee],
    type: "audio",
    status: "ringing",
    createdAt: new Date().toISOString(),
  });

  it("🔴 `blocks` dokümanı HİÇ OLUŞMAMIŞ kullanıcı ARANABİLİR", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), "calls/yeniCagri"), cagri(MALLORY))
    );
  });

  it("blocks VAR ve boşsa aranabilir (fixture'ın kapsadığı tek durum)", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), "calls/yeniCagri"), cagri(BOB))
    );
  });

  it("GERÇEKTEN engellenmişse aranamaz (koruma bozulmadı)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${BOB}/private/blocks`), {
        uids: [ALICE],
      });
    });
    await assertFails(setDoc(doc(as(ALICE), "calls/yeniCagri"), cagri(BOB)));
  });
});

// ─────────────────────────────────────────────────────────────
// §4aw — "SOHBETİ TEMİZLE" HER BİREBİR SOHBETTE KIRIKTI
//
// Eski istemci her mesaj BELGESİNİ silmeye çalışıyordu. Kural ise
// silmeyi gönderene ya da GRUP YÖNETİCİSİNE veriyor — birebir sohbette
// yönetici YOKTUR. Yani karşı tarafın tek bir mesajı bile toplu yazmayı
// tümden reddettiriyor ve kullanıcı her seferinde "Temizlenemedi"
// görüyordu.
//
// Düzeltme kuralı GEVŞETMEZ (bir sohbetin tarafına diğerinin geçmişini
// tek taraflı yok etme yetkisi verilemez): temizleme artık "yalnızca
// bende"dir. Bu testler o iki ayağı kilitler.
// ─────────────────────────────────────────────────────────────
describe("sohbeti temizle — yalnızca bende (§4aw)", () => {
  it("🔴 karşı tarafın mesajını SİLEMEM (kuralın kendisi)", async () => {
    // m1 Alice'in mesajı; Bob silmeye kalkarsa reddedilmeli.
    await assertFails(deleteDoc(doc(as(BOB), `chats/${DM}/messages/m1`)));
  });

  it("karşı tarafın mesajını KENDİMDEN gizleyebilirim", async () => {
    // Temizlemenin karşı taraf mesajları için kullandığı yol.
    await assertSucceeds(
      updateDoc(doc(as(BOB), `chats/${DM}/messages/m1`), {
        deletedFor: [BOB],
      })
    );
  });

  it("kendi mesajımı silebilirim", async () => {
    await assertSucceeds(deleteDoc(doc(as(ALICE), `chats/${DM}/messages/m1`)));
  });

  it("🔴 gizleme bahanesiyle İÇERİK değiştirilemez", async () => {
    // `deletedFor` izni, başkasının mesajını yeniden yazmanın kapısı
    // olmamalı.
    await assertFails(
      updateDoc(doc(as(BOB), `chats/${DM}/messages/m1`), {
        deletedFor: [BOB],
        content: "degistirilmis",
      })
    );
  });

  it("🔴 YABANCI ne silebilir ne gizleyebilir", async () => {
    await assertFails(deleteDoc(doc(as(MALLORY), `chats/${DM}/messages/m1`)));
    await assertFails(
      updateDoc(doc(as(MALLORY), `chats/${DM}/messages/m1`), {
        deletedFor: [MALLORY],
      })
    );
  });

  it("son mesaj önizlemesi temizlenebilir", async () => {
    // Temizlemenin son adımı; reddedilirse listede eski metin kalırdı.
    await assertSucceeds(
      updateDoc(doc(as(BOB), `chats/${DM}`), { lastMessage: "" })
    );
  });
});

// ─────────────────────────────────────────────────────────────
// §4cc — SESSİZ YENİDEN EL SIKIŞMA
//
// Oturum bozulduğunda onarım KULLANICININ mesaj yazmasını bekliyordu.
// Artık istemci ölü oturumu tespit edince X3DH init başlığını yayımlıyor
// ve karşı taraf o sohbeti AÇMADAN onarılıyor.
//
// Buradaki kritik sınır: yayımlama yetkisi. Yabancı biri yazabilseydi
// başkasının oturumunu istediği zaman sıfırlatabilirdi — sohbeti sürekli
// yeniden kurduran bir hizmet reddi.
// ─────────────────────────────────────────────────────────────
describe("sessiz yeniden el sıkışma (§4cc)", () => {
  const baslik = { identityKey: "ik", ephemeralKey: "ek", ratchetVersion: 3 };

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `handshakes/${DM}/init/${ALICE}`), {
        from: ALICE,
        to: BOB,
        header: baslik,
        ts: new Date().toISOString(),
      });
    });
  });

  it("sohbetin üyesi KENDİ adına el sıkışma yayımlayabilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(BOB), `handshakes/${DM}/init/${BOB}`), {
        from: BOB,
        to: ALICE,
        header: baslik,
        ts: new Date().toISOString(),
      })
    );
  });

  it("🔴 BAŞKASININ adına el sıkışma yayımlanamaz", async () => {
    // Doküman kimliği Alice ama yazan Bob → sahte "Alice el sıkışmak
    // istiyor" sinyali üretilemez.
    await assertFails(
      setDoc(doc(as(BOB), `handshakes/${DM}/init/${ALICE}`), {
        from: ALICE,
        to: BOB,
        header: baslik,
        ts: new Date().toISOString(),
      })
    );
  });

  it("🔴 YABANCI bu sohbete el sıkışma yayımlayamaz", async () => {
    // ⚠️ ASIL KORUMA: yabancı yazabilseydi istediği kişinin oturumunu
    // sürekli sıfırlatabilirdi.
    await assertFails(
      setDoc(doc(as(MALLORY), `handshakes/${DM}/init/${MALLORY}`), {
        from: MALLORY,
        to: BOB,
        header: baslik,
        ts: new Date().toISOString(),
      })
    );
  });

  it("🔴 kendine el sıkışma gönderilemez", async () => {
    await assertFails(
      setDoc(doc(as(BOB), `handshakes/${DM}/init/${BOB}`), {
        from: BOB,
        to: BOB,
        header: baslik,
        ts: new Date().toISOString(),
      })
    );
  });

  it("alıcı kendine gelen el sıkışmayı OKUYABİLİR", async () => {
    await assertSucceeds(
      getDoc(doc(as(BOB), `handshakes/${DM}/init/${ALICE}`))
    );
  });

  it("🔴 YABANCI el sıkışmayı okuyamaz", async () => {
    // Başlık açık anahtar taşır ama "kim kiminle" bilgisi de üstveridir.
    await assertFails(
      getDoc(doc(as(MALLORY), `handshakes/${DM}/init/${ALICE}`))
    );
  });

  // ── KOLEKSİYON-GRUBU SORGUSU ──
  // İstemci TÜM sohbetleri tek akışla dinliyor. Bu sorgu çalışmazsa
  // onarım hiç tetiklenmez ve özellik sessizce ölü kalır.
  it("alıcı TÜM sohbetlerdeki el sıkışmalarını tek sorguyla bulur", async () => {
    const snap = await getDocs(
      query(collectionGroup(as(BOB), "init"), where("to", "==", BOB))
    );
    expect(snap.docs.map((d) => d.id)).to.include(ALICE);
  });

  it("🔴 `to` kısıtı OLMADAN koleksiyon-grubu sorgusu REDDEDİLİR", async () => {
    // ⚠️ `list` kuralı belgeye değil SORGUYA bakar (§4bq). İstemcideki
    // `where('to', ==, ben)` kısıtı süsleme değil, iznin kendisidir.
    await assertFails(getDocs(collectionGroup(as(BOB), "init")));
  });

  it("🔴 BAŞKASININ el sıkışmaları sorguyla dökülemez", async () => {
    const snap = await getDocs(
      query(collectionGroup(as(MALLORY), "init"), where("to", "==", MALLORY))
    );
    expect(snap.empty).to.equal(true);
  });
});

describe("grup araması — mesh sinyalleşmesi (§4bq)", () => {
  // ⚠️ GRUP ÇAĞRISINDA `calleeId` YOKTUR.
  //
  // Oluşturma kuralı `notBlockedBy(request.resource.data.calleeId)`
  // çağırıyordu; eksik alan kural motorunda DEĞERLENDİRME HATASI verir
  // ve istek reddedilir — yani grup araması hiç başlatılamazdı. §4at'de
  // birebir aynısı yaşanmıştı (eksik alan → hata → RED).
  it("calleeId OLMADAN grup çağrısı oluşturulabilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), "calls/grup2"), {
        callerId: ALICE,
        participants: [ALICE],
        groupChatId: "group1",
        isGroup: true,
        status: "ringing",
        createdAt: new Date().toISOString(),
      })
    );
  });

  it("kendini katılımcı yazmayan çağrı açamaz", async () => {
    await assertFails(
      setDoc(doc(as(ALICE), "calls/grup3"), {
        callerId: ALICE,
        participants: [BOB],
        groupChatId: "group1",
        isGroup: true,
        status: "ringing",
      })
    );
  });

  // ── 🔔 `participants` = ÇALACAK TELEFONLAR ──
  //
  // Gelen arama sorgusu `participants array-contains me` olduğu için bu
  // dizi doğrudan "kimin telefonu çalsın" listesidir. Serbest kalsaydı
  // HERKES, hiç tanımadığı kullanıcıların telefonunu çaldırabilirdi —
  // üstelik engelleme de kurtarmazdı: grup çağrısında `calleeId` yok,
  // yani `notBlockedBy` hiç uygulanmıyor.
  it("🔴 GRUBUN ÜYESİ OLMAYAN o gruba arama açamaz", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), "calls/grup4"), {
        callerId: MALLORY,
        participants: [MALLORY],
        groupChatId: "group1",
        isGroup: true,
        status: "ringing",
        createdAt: new Date().toISOString(),
      })
    );
  });

  it("🔴 üye, GRUPTA OLMAYAN birinin telefonunu çaldıramaz", async () => {
    // Alice group1'in üyesi; ama Mallory değil. Kural `participants`i
    // grubun üye listesiyle sınırlamasa Alice, Mallory'yi çağrıya
    // yazarak telefonunu çaldırabilirdi.
    await assertFails(
      setDoc(doc(as(ALICE), "calls/grup5"), {
        callerId: ALICE,
        participants: [ALICE, MALLORY],
        groupChatId: "group1",
        isGroup: true,
        status: "ringing",
        createdAt: new Date().toISOString(),
      })
    );
  });

  it("üye, grubun ÜYELERİNİ çağrıya yazabilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), "calls/grup6"), {
        callerId: ALICE,
        participants: [ALICE, BOB],
        joinedIds: [ALICE],
        groupChatId: "group1",
        isGroup: true,
        status: "ringing",
        createdAt: new Date().toISOString(),
      })
    );
  });

  // ⚠️ BOŞ KİMLİK: `get()` boş segmentle çağrılırsa kural DEĞERLENDİRME
  // HATASI verir; hata da REDdir. Kuralın bu yola hiç girmemesi gerek —
  // ama sonuç ne olursa olsun istek reddedilmeli.
  it("🔴 groupChatId OLMADAN grup çağrısı açılamaz", async () => {
    await assertFails(
      setDoc(doc(as(ALICE), "calls/grup7"), {
        callerId: ALICE,
        participants: [ALICE],
        isGroup: true,
        status: "ringing",
        createdAt: new Date().toISOString(),
      })
    );
  });

  // ── KATILMA: `joinedIds` mesh listesidir ──
  it("çağrının tarafı kendini BAĞLANANLARA ekleyebilir", async () => {
    await assertSucceeds(
      updateDoc(doc(as(BOB), "calls/grup1"), { joinedIds: [ALICE, BOB] })
    );
  });

  it("🔴 YABANCI kendini bağlananlara ekleyemez", async () => {
    await assertFails(
      updateDoc(doc(as(MALLORY), "calls/grup1"), { joinedIds: [MALLORY] })
    );
  });

  it("🔴 YABANCI grup çağrı belgesini OKUYAMAZ", async () => {
    await assertFails(getDoc(doc(as(MALLORY), "calls/grup1")));
  });

  // ── ⚠️⚠️ `list` KURALI BELGEYE DEĞİL **SORGUYA** BAKAR ──
  //
  // Kuralı okurken görünmeyen tuzak: `callParty()` `resource.data`ya
  // baktığı için "dönen her belge tek tek denetlenir" sanılıyor.
  // Gerçekte Firestore, sorgunun yalnızca izinli belgeleri
  // döndüreceğini SORGU KISITLARINDAN kanıtlamak zorunda; kanıtlayamazsa
  // sorgunun TAMAMINI reddeder.
  //
  // Bu çift test, `GroupCallService._canliCagriyiBul` içindeki
  // `participants array-contains ben` kısıtının SÜS DEĞİL İZNİN KENDİSİ
  // olduğunu kilitler. Kısıt silinirse grup araması "başlatılamadı"
  // diye kırılır ve hiçbir birim testi bunu göstermez.
  // Aynı tuzak sinyalleşme dinleyicilerinde de var: istemci
  // `where('to', ==, ben)` ile dinliyor. Kısıt olmadan kural
  // kanıtlanamaz ve dinleyici hiç veri almaz — arama sessizce kurulmaz.
  it("adresli SDP dinleyicisi (`to == ben`) SORGUSU geçer", async () => {
    const snap = await getDocs(
      query(collection(as(BOB), "calls/call1/sdp"), where("to", "==", BOB))
    );
    expect(snap.docs.map((d) => d.id)).to.include("alice__bob");
  });

  it("🔴 adres kısıtı OLMADAN SDP dökülemez", async () => {
    await assertFails(getDocs(collection(as(BOB), "calls/call1/sdp")));
  });

  it("adresli ICE dinleyicisi (`to == ben`) SORGUSU geçer", async () => {
    const snap = await getDocs(
      query(
        collection(as(BOB), "calls/call1/candidates"),
        where("to", "==", BOB)
      )
    );
    expect(snap.docs.map((d) => d.id)).to.include("c1");
  });

  it("🔴 adres kısıtı OLMADAN ICE adayları dökülemez", async () => {
    // Adaylar IP ADRESİ taşır; toplu döküm kapalı kalmalı.
    await assertFails(getDocs(collection(as(BOB), "calls/call1/candidates")));
  });

  describe("gruba ait canlı aramayı bulma sorgusu", () => {
    it("🔴 katılımcı kısıtı OLMADAN sorgu REDDEDİLİR", async () => {
      // Alice çağrının TARAFI — yine de reddedilir. Sorun yetki değil,
      // sorgunun kanıtlanamaması.
      await assertFails(
        getDocs(
          query(
            collection(as(ALICE), "calls"),
            where("groupChatId", "==", "group1"),
            where("status", "==", "ringing")
          )
        )
      );
    });

    it("katılımcı kısıtı EKLENİNCE sorgu geçer ve aramayı bulur", async () => {
      const snap = await getDocs(
        query(
          collection(as(ALICE), "calls"),
          where("groupChatId", "==", "group1"),
          where("status", "==", "ringing"),
          where("participants", "array-contains", ALICE)
        )
      );
      expect(snap.docs.map((d) => d.id)).to.include("grup1");
    });

    it("🔴 grubun ÜYESİ OLMAYAN aynı sorguda hiçbir şey görmez", async () => {
      const snap = await getDocs(
        query(
          collection(as(MALLORY), "calls"),
          where("groupChatId", "==", "group1"),
          where("status", "==", "ringing"),
          where("participants", "array-contains", MALLORY)
        )
      );
      expect(snap.empty).to.equal(true);
    });
  });

  it("BİREBİR aramada engel denetimi AYNEN sürüyor", async () => {
    // Grup dalı eklenirken birebir dalın düşmediğini kilitler:
    // `isGroup` yoksa kural hâlâ `notBlockedBy(calleeId)` yolundan
    // geçmeli.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${BOB}/private/blocks`), {
        uids: [ALICE],
      });
    });
    await assertFails(
      setDoc(doc(as(ALICE), "calls/grup8"), {
        callerId: ALICE,
        calleeId: BOB,
        participants: [ALICE, BOB],
        status: "ringing",
        createdAt: new Date().toISOString(),
      })
    );
  });

  // SDP, trickle olmayan istemcilerde ICE adaylarını İÇEREBİLİR; yani
  // IP taşır. Okuma izni adaylarla aynı sıkılıkta olmalı.
  it("🔴 YABANCI başkasının SDP'sini OKUYAMAZ", async () => {
    await assertFails(getDoc(doc(as(MALLORY), "calls/call1/sdp/alice__bob")));
  });

  it("SDP'nin tarafları okuyabilir", async () => {
    await assertSucceeds(getDoc(doc(as(BOB), "calls/call1/sdp/alice__bob")));
    await assertSucceeds(getDoc(doc(as(ALICE), "calls/call1/sdp/alice__bob")));
  });

  it("katılımcı KENDİ adına SDP yazabilir", async () => {
    await assertSucceeds(
      setDoc(doc(as(BOB), "calls/grup1/sdp/bob__alice"), {
        from: BOB,
        to: ALICE,
        type: "answer",
        sdp: "v=0 ...",
      })
    );
  });

  it("🔴 BAŞKASININ adına SDP yazılamaz (sahte teklif)", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), "calls/grup1/sdp/alice__bob"), {
        from: ALICE,
        to: BOB,
        type: "offer",
        sdp: "v=0 kotu",
      })
    );
  });

  it("🔴 çağrının TARAFI OLMAYAN SDP yazamaz", async () => {
    await assertFails(
      setDoc(doc(as(MALLORY), "calls/grup1/sdp/mallory__alice"), {
        from: MALLORY,
        to: ALICE,
        type: "offer",
        sdp: "v=0 kotu",
      })
    );
  });
});
