const test = require("node:test");
const assert = require("node:assert");
const crypto = require("node:crypto");

/// 🔀 TURN KİMLİĞİ — COTURN İLE BİÇİM SÖZLEŞMESİ
///
/// ── NEDEN BU TEST VAR ──
/// `iceTransportPolicy: relay` açıkken TURN tek aday kaynağıdır. Kimlik
/// biçimi coturn'ün beklediğinden bir karakter saparsa sunucu kimliği
/// REDDEDER ve arama STUN'a düşmez — **hiç kurulmaz**. Kullanıcının
/// gördüğü tek şey "arama bir şekilde olmuyor"dur; sunucu ayakta,
/// sertifika geçerli, portlar açıktır. Bu, saatlerce yanlış yerde
/// aranan türden bir arızadır.
///
/// coturn `use-auth-secret` kipinde şunu bekler:
///   username   = <bitiş-zaman-damgası>:<herhangi bir metin>
///   credential = base64(HMAC-SHA1(paylaşılan sır, username))
///
/// ⚠️ Bu dosya hesabı İKİNCİ KEZ yazmaz — ürünün fonksiyonunu çağırır.
/// Kopya bir uygulama, asıl koddan sessizce ayrışabilirdi (bu depoda
/// §4u tam olarak böyle oldu: iki yazar, biri güncellendi, diğeri
/// kalmadı ve kimse fark etmedi). `getTurnCredentials` da AYNI
/// fonksiyonu çağırır; ikisi ayrışamaz.
const { buildTurnCredential } = require("../turn.js");

test("kullanıcı adı `bitiş:opak` biçimindedir", () => {
  const { username } = buildTurnCredential("sir", 1789000000, "abc");
  assert.strictEqual(username, "1789000000:abc");
});

test("parola, RFC'nin istediği HMAC-SHA1 + base64'tür", () => {
  const sir = "s1r-1";
  const expiresAt = 1789000000;
  const opaque = "Zm9vYmFy";

  const { username, credential } = buildTurnCredential(
    sir,
    expiresAt,
    opaque,
  );

  // Beklenen değer BAĞIMSIZ olarak hesaplanır: ürün kodunun kendi
  // ifadesini tekrarlamak, yanlış bir hesabı "doğrulamış" olurdu.
  const beklenen = crypto
    .createHmac("sha1", sir)
    .update(`${expiresAt}:${opaque}`)
    .digest("base64");

  assert.strictEqual(credential, beklenen);
  assert.strictEqual(username, `${expiresAt}:${opaque}`);
  // base64 SHA-1 = 28 karakter (20 bayt). Uzunluk kayarsa digest ya da
  // kodlama değişmiş demektir.
  assert.strictEqual(credential.length, 28);
});

test("sır değişince parola da değişir", () => {
  const a = buildTurnCredential("sir-1", 1789000000, "abc").credential;
  const b = buildTurnCredential("sir-2", 1789000000, "abc").credential;
  assert.notStrictEqual(a, b);
});

test("kullanıcı adı uid TAŞIMAZ — çağıran ne verdiyse o", () => {
  // Gizlilik kararı: kullanıcı adında uid olsaydı TURN sunucusu IP ile
  // hesabı KALICI olarak ilişkilendirebilirdi. Fonksiyon opak değeri
  // dışarıdan alır; üreten taraf `crypto.randomBytes` kullanır.
  const { username } = buildTurnCredential("sir", 1789000000, "rastgele");
  assert.ok(!username.includes("uid"));
  assert.strictEqual(username.split(":").length, 2);
});
