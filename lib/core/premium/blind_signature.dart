import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 🎭 KÖR İMZA (Chaum) — "biri ödedi", "bu kişi ödedi" DEĞİL.
///
/// ── NEDEN BU KADAR UĞRAŞ ──
/// Premium için akla ilk gelen `users/{uid}.isPremium = true` yazmaktır.
/// Ama bu, telefon numarası istemeyen, kimliği yalnızca cihazda tutan bir
/// uygulamada **anonim hesabı bir Google Play satın almasına bağlar**.
/// Google zaten satın almayı gerçek kimliğe bağlıdır; sunucumuz da uid'yi
/// öğrenirse zincir tamamlanır:
///
///     gerçek kimlik → Play hesabı → satın alma → SECRETER uid → sohbetler
///
/// Uygulamanın tüm iddiası bu zincirin kurulamamasına dayanıyor.
///
/// ── ÇÖZÜM ──
/// Sunucu, **görmediği** bir değeri imzalar:
///
///  1. İstemci rastgele bir `nonce` üretir ve onu **körleştirir**.
///  2. Sunucuya körleştirilmiş değer + Play satın alma jetonu gider.
///  3. Sunucu satın almayı Google'a doğrular, jetonu "kullanıldı"
///     işaretler ve körleştirilmiş değeri imzalar.
///  4. İstemci körlüğü kaldırır: elinde, sunucunun **hiç görmediği**
///     `nonce` üzerine geçerli bir imza kalır.
///
/// Sonuç: yetki sunulduğunda sunucu imzayı doğrulayabilir ama onu hangi
/// satın almanın ürettiğini **bilemez**. "Biri ödedi" der.
///
/// ── MATEMATİK (RSA) ──
///     m   = FDH(nonce)                 (tam genişlikte özet)
///     b   = m · rᵉ  mod n              (körleştirme)
///     s   = b^d     mod n              (sunucu imzalar)
///     sig = s · r⁻¹ mod n              (körlük kalkar)
///     doğrulama:  sigᵉ mod n == m
///
/// `r` yalnızca cihazda kalır; sunucu `b`'den `m`'i çıkaramaz çünkü `r`
/// düzgün rastgeledir.
///
/// ── ⚠️ SINIRLAR (dürüstlük) ──
///  * Bu, klasik Chaum kör imzasıdır (FDH ile). Üretimde RFC 9474
///    (RSABSSA) tercih edilebilir; buradaki kurulum daha basit ama aynı
///    aileden.
///  * İmza anahtarı YALNIZCA yetki için kullanılmalıdır. Aynı RSA
///    anahtarını başka bir amaçla kullanmak "bir-fazla imza" saldırısına
///    kapı açar.
///  * Kör imza, sunucunun **ağ katmanında** öğrendiklerini gizlemez:
///    yetki sunulurken IP görülür. Bu, TURN'deki sorunla aynı sınıf
///    (bkz. §4f) ve ayrı bir konudur.
class RsaPublicKey {
  final BigInt n;
  final BigInt e;

  const RsaPublicKey({required this.n, required this.e});

  /// `n` ve `e` onaltılık dizeden. Sunucunun açık anahtarı istemciye bu
  /// biçimde gömülür (gizli değildir).
  factory RsaPublicKey.fromHex({required String n, required String e}) =>
      RsaPublicKey(
        n: BigInt.parse(n, radix: 16),
        e: BigInt.parse(e, radix: 16),
      );

  /// Modülüs bit uzunluğu — körleştirme ve FDH bunu kullanır.
  int get bits => n.bitLength;
}

/// Körleştirilmiş istek. `blinded` sunucuya gider; diğer ikisi CİHAZDA
/// KALIR ve asla dışarı çıkmaz.
class BlindedRequest {
  /// Sunucuya gönderilecek değer.
  final BigInt blinded;

  /// Körleştirme çarpanı — bu sızarsa sunucu bağlantıyı kurabilir.
  final BigInt blindingFactor;

  /// Yetkinin gerçek gövdesi. Sunucu bunu HİÇ görmez.
  final Uint8List nonce;

  const BlindedRequest({
    required this.blinded,
    required this.blindingFactor,
    required this.nonce,
  });
}

class BlindSignature {
  BlindSignature._();

  /// Nonce uzunluğu (bayt). 32 bayt = 256 bit tahmin edilemezlik.
  static const int nonceBytes = 32;

  /// Yeni bir körleştirilmiş istek üret.
  ///
  /// [nonce] ve [random] yalnızca TEST içindir; üretimde ikisi de
  /// verilmez ve kriptografik rastgelelik kullanılır.
  static BlindedRequest blind(
    RsaPublicKey key, {
    Uint8List? nonce,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final n0 = nonce ?? _randomBytes(nonceBytes, rng);
    final m = fullDomainHash(n0, key);

    // r: 1 < r < n ve n ile aralarında asal. RSA modülüsünde bu koşul
    // pratikte her zaman sağlanır; yine de kontrol edilir — sağlanmazsa
    // körleştirme tersinir olmaz ve imza kurtarılamazdı.
    BigInt r;
    do {
      r = _randomBigInt(key.n, rng);
    } while (r <= BigInt.one || r.gcd(key.n) != BigInt.one);

    final blinded = (m * r.modPow(key.e, key.n)) % key.n;
    return BlindedRequest(blinded: blinded, blindingFactor: r, nonce: n0);
  }

  /// Sunucunun döndürdüğü kör imzadan körlüğü kaldır.
  static BigInt unblind(
    RsaPublicKey key,
    BlindedRequest request,
    BigInt blindSignature,
  ) {
    final rInv = request.blindingFactor.modInverse(key.n);
    return (blindSignature * rInv) % key.n;
  }

  /// İmzayı doğrula: `sigᵉ mod n == FDH(nonce)`.
  static bool verify(RsaPublicKey key, Uint8List nonce, BigInt signature) {
    if (signature <= BigInt.zero || signature >= key.n) return false;
    return signature.modPow(key.e, key.n) == fullDomainHash(nonce, key);
  }

  /// TAM ALAN ÖZETİ (Full Domain Hash).
  ///
  /// Düz SHA-256 (256 bit) 2048 bitlik bir modülüsün yanında çok
  /// kısadır; FDH güvenlik kanıtı özetin modülüs genişliğinde olmasını
  /// ister. MGF1 ile genişletilir ve `n`'den KESİN KÜÇÜK olacak şekilde
  /// bir bayt eksik üretilir — böylece mod indirgemesi ve onun getirdiği
  /// yanlılık hiç gerekmez.
  static BigInt fullDomainHash(Uint8List nonce, RsaPublicKey key) {
    final len = (key.bits - 1) ~/ 8;
    final bytes = _mgf1(nonce, len);
    return _bytesToBigInt(bytes);
  }

  /// MGF1 (PKCS#1) — SHA-256 tabanlı maske üretimi.
  static Uint8List _mgf1(Uint8List seed, int length) {
    final out = BytesBuilder();
    var counter = 0;
    while (out.length < length) {
      final c = ByteData(4)..setUint32(0, counter, Endian.big);
      out.add(sha256.convert([...seed, ...c.buffer.asUint8List()]).bytes);
      counter++;
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  static Uint8List _randomBytes(int n, Random rng) =>
      Uint8List.fromList(List.generate(n, (_) => rng.nextInt(256)));

  static BigInt _randomBigInt(BigInt max, Random rng) {
    final bytes = (max.bitLength + 7) ~/ 8;
    while (true) {
      final v = _bytesToBigInt(_randomBytes(bytes, rng));
      if (v < max) return v;
    }
  }

  static BigInt _bytesToBigInt(Uint8List b) {
    var r = BigInt.zero;
    for (final byte in b) {
      r = (r << 8) | BigInt.from(byte);
    }
    return r;
  }
}
