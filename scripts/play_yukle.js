#!/usr/bin/env node
/**
 * 🚀 SECRETER — Play'e paket yükle (Play Developer API v3)
 *
 * Kullanım:
 *   node scripts/play_yukle.js --track alpha
 *   node scripts/play_yukle.js --track alpha --aab <yol> --notlar <yol>
 *
 * ── NEDEN VAR ──
 * Paket 88 MB; tarayıcı otomasyonunun dosya yükleme sınırı 10 MB. Yani
 * yükleme tarayıcıdan SÜRÜLEMEZ. Play Developer API bu sınırı hiç
 * tanımaz ve yükleme tek komuta iner.
 *
 * ── ÖNCE BİR KEZ YAPILACAKLAR (yalnızca hesap sahibi yapabilir) ──
 *  1. Play Console → Ayarlar → API erişimi → Google Cloud projesini bağla
 *  2. Google Cloud → IAM → Hizmet hesabı oluştur → JSON anahtar indir
 *  3. Play Console → Kullanıcılar ve izinler → hizmet hesabını davet et
 *     → yalnızca SECRETER için "Test kanallarına sürüm yayınla" yetkisi
 *     ⚠️ "Üretime yayınla" yetkisini VERME; bu betiğin ihtiyacı yok ve
 *        kazayla üretime çıkma riskini ortadan kaldırır.
 *  4. JSON anahtarı DEPO DIŞINA koy, yolunu ortam değişkeniyle ver:
 *        export PLAY_SERVICE_ACCOUNT_JSON=C:/yol/play-sa.json
 *
 * ⚠️ ANAHTAR DEPOYA KONMAZ. `.gitignore` yetmez: anahtar bu makinede
 * kalmalı ve yolu ortam değişkeninden okunmalı.
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { GoogleAuth } = require(path.join(
  __dirname,
  "..",
  "functions",
  "node_modules",
  "google-auth-library",
));

const PAKET = "com.secreter.app";
const KOK = path.join(__dirname, "..");
const VARSAYILAN_AAB = path.join(
  KOK,
  "build",
  "app",
  "outputs",
  "bundle",
  "release",
  "app-release.aab",
);

function arg(ad, varsayilan) {
  const i = process.argv.indexOf(`--${ad}`);
  return i > -1 && process.argv[i + 1] ? process.argv[i + 1] : varsayilan;
}

async function main() {
  // ── KANALLARI LİSTELE ──
  // Kapalı test kanalının kimliği Play Console'da "Closed testing" diye
  // görünür ama API'de `alpha` ya da elle verilmiş bir ad olabilir.
  // Yanlış kanala yayın, yanlış kişilere sürüm göndermek demektir —
  // tahmin etmek yerine sor. Bu mod aynı zamanda kurulumu DOĞRULAR:
  // çalışıyorsa kimlik ve izinler tamamdır.
  const sadeceKanallar = process.argv.includes("--kanallar");

  const track = arg("track");
  if (!track && !sadeceKanallar) {
    console.error(
      "✖ --track zorunlu (ör: internal, alpha, beta).\n" +
        "  Kapalı test genelde 'alpha'dır; Play Console'daki kanal adını kullan.",
    );
    process.exit(1);
  }
  // ⚠️ ÜRETİME KAZA İLE ÇIKMA KORUMASI. Kapalı teste yüklemek ile
  // herkese yayınlamak arasındaki fark tek kelime; o kelimeyi yanlışlıkla
  // yazmak geri alınamaz bir yayın demektir.
  if (track === "production" && !process.argv.includes("--evet-uretim")) {
    console.error(
      "✖ 'production' kanalına yayın bu betikle KAZAEN yapılamaz.\n" +
        "  Gerçekten istiyorsan --evet-uretim bayrağını da ver.",
    );
    process.exit(1);
  }

  const aab = arg("aab", VARSAYILAN_AAB);
  if (!sadeceKanallar && !fs.existsSync(aab)) {
    console.error(`✖ Paket bulunamadı: ${aab}`);
    process.exit(1);
  }

  const anahtarYolu = process.env.PLAY_SERVICE_ACCOUNT_JSON;
  if (!anahtarYolu || !fs.existsSync(anahtarYolu)) {
    console.error(
      "✖ PLAY_SERVICE_ACCOUNT_JSON tanımlı değil ya da dosya yok.\n" +
        "  Kurulum adımları bu dosyanın başındaki açıklamada.",
    );
    process.exit(1);
  }

  // Sürüm notları: --notlar ile verilen JSON dosyası
  //   [{"language":"tr-TR","text":"..."}, {"language":"en-US","text":"..."}]
  const notlarYolu = arg("notlar");
  let releaseNotes;
  if (notlarYolu) {
    if (!fs.existsSync(notlarYolu)) {
      console.error(`✖ Sürüm notu dosyası yok: ${notlarYolu}`);
      process.exit(1);
    }
    releaseNotes = JSON.parse(fs.readFileSync(notlarYolu, "utf8"));
    // ⚠️ Play dil başına 500 karakter sınırı koyar ve AŞILIRSA TÜM
    // yükleme reddedilir — paket yüklendikten SONRA, yani en can sıkıcı
    // anda. Önden kontrol et.
    for (const n of releaseNotes) {
      if ((n.text || "").length > 500) {
        console.error(
          `✖ ${n.language} sürüm notu ${n.text.length} karakter (sınır 500).`,
        );
        process.exit(1);
      }
    }
  }

  const auth = new GoogleAuth({
    keyFile: anahtarYolu,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const istemci = await auth.getClient();
  const { token } = await istemci.getAccessToken();

  const temel = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PAKET}`;

  async function cagir(url, secenek = {}) {
    const r = await fetch(url, {
      ...secenek,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(secenek.headers || {}),
      },
    });
    const govde = await r.text();
    if (!r.ok) {
      throw new Error(`${r.status} ${r.statusText}\n${govde}`);
    }
    return govde ? JSON.parse(govde) : {};
  }

  console.log("▶ Düzenleme açılıyor…");
  const edit = await cagir(`${temel}/edits`, { method: "POST" });

  if (sadeceKanallar) {
    const liste = await cagir(`${temel}/edits/${edit.id}/tracks`);
    console.log("\n✅ Kimlik ve izinler ÇALIŞIYOR. Kanallar:\n");
    for (const t of liste.tracks || []) {
      const r = (t.releases || [])[0];
      const s = r ? `${r.status} — versionCode ${(r.versionCodes || []).join(",")}` : "boş";
      console.log(`   ${t.track.padEnd(16)} ${s}`);
    }
    console.log("\nYükleme için: --track <yukarıdaki adlardan biri>");
    return;
  }

  console.log(`▶ Paket : ${path.basename(aab)} (${(fs.statSync(aab).size / 1048576).toFixed(1)} MB)`);
  console.log(`▶ Kanal : ${track}`);

  console.log("▶ Paket yükleniyor (birkaç dakika sürebilir)…");
  const yuklendi = await cagir(
    `https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${PAKET}/edits/${edit.id}/bundles?uploadType=media`,
    {
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      body: fs.readFileSync(aab),
    },
  );
  console.log(`✅ Yüklendi — versionCode ${yuklendi.versionCode}`);

  console.log("▶ Kanala atanıyor…");
  await cagir(`${temel}/edits/${edit.id}/tracks/${track}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      track,
      releases: [
        {
          versionCodes: [String(yuklendi.versionCode)],
          status: "completed",
          ...(releaseNotes ? { releaseNotes } : {}),
        },
      ],
    }),
  });

  console.log("▶ Onaylanıyor…");
  await cagir(`${temel}/edits/${edit.id}:commit`, { method: "POST" });

  console.log(
    `\n✅ BİTTİ — versionCode ${yuklendi.versionCode}, '${track}' kanalında.` +
      "\n   Play Console'da birkaç dakika içinde görünür.",
  );
}

main().catch((e) => {
  // ⚠️ Yarım kalan düzenleme SORUN DEĞİL: commit edilmeyen edit kendi
  // kendine düşer ve Play'de hiçbir iz bırakmaz. Yeniden çalıştırmak
  // güvenlidir.
  console.error(`\n✖ Yükleme başarısız:\n${e.message}`);
  process.exit(1);
});
