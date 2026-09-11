#!/usr/bin/env node
/**
 * SECRETER — `usernames` DİZİNİ GERİYE DÖNÜK DOLDURMA
 *
 * NEDEN VAR (DEVAM.md madde 12):
 * `usernames` dizini sonradan eklendi (§4l atomik ad rezervasyonu) ve eski
 * hesaplar için doldurulmadı. 2026-09-10 ölçümü: `users` içinde 20 hesap,
 * `usernames` içinde 1 kayıt. Sonucu:
 *   • O hesaplar aramada BULUNAMIYOR (findUserByUsername dizine bakar).
 *   • Ad tekilliği fiilen çalışmıyor — var olan bir ad "müsait" görünüyor.
 *   • Biri, var olan bir kullanıcının adıyla hesap açabiliyor (taklit).
 *
 * ⚠️ BU SCRIPT ÜRETİM VERİSİNE YAZAR. Varsayılanı KURU ÇALIŞMADIR:
 * hiçbir şey yazmaz, yalnızca ne yapacağını söyler. Yazmak için açıkça
 * `--apply` vermek gerekir.
 *
 * ÇAKIŞMALARI ASLA KENDİ BAŞINA ÇÖZMEZ. Aynı adı iki hesap taşıyorsa
 * (üretimde `secreter` için durum budur) o ad ATLANIR ve rapora düşer.
 * Körlemesine yazmak, birinin adını sessizce diğerine kaptırmak olurdu.
 *
 * ─────────────── KİMLİK BİLGİSİ ───────────────
 * Admin SDK erişimi gerekir. Servis hesabı anahtarını SEN indirir ve
 * ortam değişkeniyle verirsin; anahtarın içeriği bu script'te DURMAZ:
 *
 *   Google Cloud Console → IAM ve Yönetici → Hizmet Hesapları
 *   → anahtar oluştur (JSON) → indir
 *
 *   # Windows (Git Bash)
 *   export GOOGLE_APPLICATION_CREDENTIALS="/c/yol/anahtar.json"
 *
 * ⚠️ Anahtar dosyasını depoya KOYMA, kimseyle paylaşma. İş bittiğinde
 * Cloud Console'dan anahtarı SİL — tek seferlik bir iş için kalıcı bir
 * sır bırakmanın anlamı yok.
 *
 * ─────────────── KULLANIM ───────────────
 *   node tools/backfill_usernames.js                # KURU ÇALIŞMA (rapor)
 *   node tools/backfill_usernames.js --apply        # gerçekten yaz
 *   node tools/backfill_usernames.js --apply --force-conflicts   # ÖNERİLMEZ
 */

const admin = require("firebase-admin");

const APPLY = process.argv.includes("--apply");
const FORCE = process.argv.includes("--force-conflicts");

admin.initializeApp();
const db = admin.firestore();

/** Kayıt akışıyla AYNI normalizasyon — `AuthService.register`: toLowerCase. */
const normalize = (raw) => String(raw || "").trim().toLowerCase();

/** Kayıt akışının kabul ettiği biçim (`AuthService.register` regex'i). */
const GECERLI_AD = /^[a-zA-Z0-9_]{3,20}$/;

async function main() {
  console.log(
    APPLY
      ? "🔴 UYGULAMA MODU — üretim verisine YAZILACAK\n"
      : "🧪 KURU ÇALIŞMA — hiçbir şey yazılmayacak (yazmak için --apply)\n"
  );

  // ── 1. Mevcut durumu oku ────────────────────────────────────────────
  const [usersSnap, indexSnap] = await Promise.all([
    db.collection("users").get(),
    db.collection("usernames").get(),
  ]);

  const mevcutDizin = new Map(); // ad -> uid
  indexSnap.forEach((d) => mevcutDizin.set(d.id, (d.data() || {}).uid || ""));

  console.log(`users     : ${usersSnap.size} hesap`);
  console.log(`usernames : ${indexSnap.size} dizin kaydı\n`);

  // ── 2. Adları grupla (çakışma tespiti için) ─────────────────────────
  const adaGore = new Map(); // ad -> [{uid, ham, olusturma}]
  const bosAdli = [];
  const bicimsiz = [];

  usersSnap.forEach((doc) => {
    const d = doc.data() || {};
    const ham = d.username;
    const ad = normalize(ham);
    if (!ad) {
      bosAdli.push(doc.id);
      return;
    }
    if (!GECERLI_AD.test(ad)) {
      bicimsiz.push({ uid: doc.id, ad });
      return;
    }
    if (!adaGore.has(ad)) adaGore.set(ad, []);
    adaGore.get(ad).push({
      uid: doc.id,
      ham,
      // Sıralama için: hesabın kendi zamanı yoksa null kalır.
      olusturma: d.createdAt || d.lastSeen || null,
    });
  });

  // ── 3. Sınıflandır ──────────────────────────────────────────────────
  const yazilacak = [];
  const zatenVar = [];
  const cakisma = [];
  const uyusmazlik = [];

  for (const [ad, sahipler] of adaGore) {
    if (sahipler.length > 1) {
      cakisma.push({ ad, sahipler });
      continue;
    }
    const { uid } = sahipler[0];
    if (mevcutDizin.has(ad)) {
      const dizinUid = mevcutDizin.get(ad);
      if (dizinUid === uid) zatenVar.push(ad);
      else uyusmazlik.push({ ad, dizinUid, profilUid: uid });
      continue;
    }
    yazilacak.push({ ad, uid });
  }

  // ── 4. Rapor ────────────────────────────────────────────────────────
  console.log(`✅ Yazılacak (eksik dizin kaydı) : ${yazilacak.length}`);
  console.log(`➖ Zaten doğru                    : ${zatenVar.length}`);
  console.log(`🔴 ÇAKIŞMA (aynı ad, çok hesap)   : ${cakisma.length}`);
  console.log(`🔴 UYUŞMAZLIK (dizin≠profil)      : ${uyusmazlik.length}`);
  console.log(`⚠️  Boş kullanıcı adı              : ${bosAdli.length}`);
  console.log(`⚠️  Biçimsiz ad                    : ${bicimsiz.length}\n`);

  if (cakisma.length) {
    console.log("🔴 ÇAKIŞMALAR — bunlar ATLANIYOR, elle karar gerekir:");
    for (const { ad, sahipler } of cakisma) {
      console.log(`   "${ad}" → ${sahipler.length} hesap:`);
      for (const s of sahipler) {
        console.log(`      ${s.uid}   (createdAt: ${s.olusturma || "yok"})`);
      }
    }
    console.log(
      "   Karar: adı hangi hesap tutacak? Diğerinin `users/{uid}.username`\n" +
        "   alanı değiştirilmeli, SONRA bu script tekrar çalıştırılmalı.\n"
    );
  }

  if (uyusmazlik.length) {
    console.log("🔴 UYUŞMAZLIK — dizin başka bir uid gösteriyor, ATLANIYOR:");
    for (const u of uyusmazlik) {
      console.log(`   "${u.ad}": dizin=${u.dizinUid}  profil=${u.profilUid}`);
    }
    console.log("");
  }

  if (bosAdli.length) {
    console.log(`⚠️  Boş kullanıcı adlı hesaplar: ${bosAdli.join(", ")}`);
    console.log("   Bunlar aramada zaten bulunamaz; ayrı ele alınmalı.\n");
  }

  if (bicimsiz.length) {
    console.log("⚠️  Kayıt akışının kabul etmeyeceği adlar (ATLANIYOR):");
    for (const b of bicimsiz) console.log(`   ${b.uid} → "${b.ad}"`);
    console.log("");
  }

  if (!yazilacak.length) {
    console.log("Yazılacak bir şey yok.");
    return;
  }

  console.log("Yazılacak kayıtlar:");
  for (const y of yazilacak) console.log(`   usernames/${y.ad} → ${y.uid}`);
  console.log("");

  if (!APPLY) {
    console.log("🧪 Kuru çalışma bitti. Yazmak için: --apply");
    return;
  }

  if (cakisma.length && !FORCE) {
    console.log(
      "🔴 ÇAKIŞMA VARKEN YAZMA YAPILMADI.\n" +
        "   Önce çakışmaları çöz. Yine de devam etmek istiyorsan\n" +
        "   --force-conflicts ver (çakışan adlar YİNE atlanır, yalnızca\n" +
        "   geri kalanı yazılır)."
    );
    return;
  }

  // ── 5. Yaz ──────────────────────────────────────────────────────────
  // `create` kullanılır, `set` DEĞİL: aradaki sürede biri o adı gerçekten
  // rezerve etmişse üzerine yazmayalım (yarış güvenliği — §4l'in mantığı).
  let basarili = 0;
  const yarisKaybi = [];
  for (const { ad, uid } of yazilacak) {
    try {
      await db.collection("usernames").doc(ad).create({
        uid,
        createdAt: new Date().toISOString(),
        backfilled: true, // sonradan doldurulduğu belli olsun
      });
      basarili++;
    } catch (e) {
      if (e && e.code === 6 /* ALREADY_EXISTS */) {
        yarisKaybi.push(ad);
      } else {
        console.error(`   HATA "${ad}": ${e && e.message}`);
      }
    }
  }

  console.log(`\n✅ Yazıldı: ${basarili}/${yazilacak.length}`);
  if (yarisKaybi.length) {
    console.log(
      `⚠️  Bu adlar arada başkası tarafından alınmış, dokunulmadı: ${yarisKaybi.join(", ")}`
    );
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("ÇÖKTÜ:", e);
    process.exit(1);
  });
