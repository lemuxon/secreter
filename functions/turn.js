const crypto = require("crypto");

/**
 * 🔀 TURN KİMLİĞİ ÜRETİMİ — coturn `use-auth-secret` sözleşmesi.
 *
 * ── NEDEN AYRI DOSYA ──
 * Hesabın kendisi SAF: sır + zaman damgası + opak kimlik girer, kimlik
 * çıkar. Ayrı durunca test edilebilir ve `index.js` yalnızca gerçek
 * tetikleyicileri dışa aktarmaya devam eder (dağıtım keşfi, tetikleyici
 * olmayan bir dışa aktarmayı görmemeli).
 *
 * ── BİÇİM NEDEN KRİTİK ──
 *   username   = <bitiş-zaman-damgası>:<opak-kimlik>
 *   credential = base64(HMAC-SHA1(TURN_SECRET, username))
 *
 * Bir karakteri kayarsa coturn kimliği REDDEDER. İstemcide
 * `iceTransportPolicy: relay` açık olduğu için başka aday kaynağı
 * yoktur: arama STUN'a düşmez, **hiç kurulmaz**. Kullanıcı "arama bir
 * şekilde olmuyor" görür; sunucu ayakta, sertifika geçerli, portlar
 * açıktır. Arıza yalnızca bu hesapta olur ve hiçbir yerde hata vermez.
 * Bu yüzden biçim `functions/test/turn.test.js` ile kilitli.
 *
 * ⚠️ [opaque] GİZLİLİK KARARIDIR. Kullanıcı adında uid kullanılsaydı
 * TURN sunucusu IP adresiyle hesabı KALICI olarak ilişkilendirebilirdi.
 * Çağıran taraf buraya rastgele, hesapla ilişkisiz bir değer verir.
 */
function buildTurnCredential(secret, expiresAt, opaque) {
  const username = `${expiresAt}:${opaque}`;
  const credential = crypto
    .createHmac("sha1", secret)
    .update(username)
    .digest("base64");
  return { username, credential };
}

module.exports = { buildTurnCredential };
