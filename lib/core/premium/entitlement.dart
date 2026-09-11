import 'dart:convert';
import 'dart:typed_data';

import 'blind_signature.dart';

/// 🎟️ YETKİ JETONU — hesaba BAĞLANMAYAN premium kanıtı.
///
/// `BlindSignature` matematiği sağlar; bu dosya onu kullanılabilir bir
/// yetkiye çevirir.
///
/// ── ⚠️ SON KULLANMA TARİHİ NEDEN JETONUN İÇİNDE DEĞİL ──
/// Akla ilk gelen, sunucunun "premium, 2026-10'a kadar" diye imzalaması.
/// **Yapılamaz:** sunucu körleştirilmiş değeri görmez, içine bir şey
/// yazamaz. İstemci kendi yazsa da işe yaramaz — istediği tarihi uydurur.
///
/// Çözüm: geçerlilik **anahtarın kendisinde** durur. Sunucu her dönem
/// için ayrı bir imza anahtarı kullanır (`prem-2026-10` gibi) ve o
/// anahtarın geçerlilik penceresi yetkinin ömrüdür. Doğrulayıcı hangi
/// anahtarla imzalandığına bakar; tarih oradan gelir.
///
/// Bu, Privacy Pass'in "epoch key" yaklaşımıdır. Yan etkisi kabul
/// edilmiştir: aynı dönemde yetki alan herkes aynı anahtarı paylaşır,
/// yani **anonimlik kümesi bir dönemin tüm ödeyenleridir**. Küme ne
/// kadar büyükse gizlilik o kadar iyidir — bu yüzden dönem çok kısa
/// TUTULMAMALIDIR (aylık makul; günlük olsaydı küme küçülür ve
/// bağlanabilirlik artardı).
class EntitlementKey {
  /// Anahtar kimliği — jeton bunu taşır, doğrulayıcı bununla eşleştirir.
  final String id;

  final RsaPublicKey key;

  /// Geçerlilik penceresi. Yetkinin ömrü BUDUR.
  final DateTime notBefore;
  final DateTime notAfter;

  const EntitlementKey({
    required this.id,
    required this.key,
    required this.notBefore,
    required this.notAfter,
  });

  bool coversTime(DateTime t) => !t.isBefore(notBefore) && t.isBefore(notAfter);
}

/// Cihazda saklanan yetki. Hiçbir alanı kullanıcıyı tanımlamaz.
class Entitlement {
  /// Hangi dönem anahtarıyla imzalandı.
  final String keyId;

  /// Sunucunun HİÇ GÖRMEDİĞİ rastgele gövde.
  final Uint8List nonce;

  /// Körlüğü kaldırılmış imza.
  final BigInt signature;

  const Entitlement({
    required this.keyId,
    required this.nonce,
    required this.signature,
  });

  /// Cihazda saklamak / sunucuya sunmak için taşınabilir biçim.
  String encode() => jsonEncode({
        'k': keyId,
        'n': base64Url.encode(nonce),
        's': signature.toRadixString(16),
      });

  /// Bozuk/eksik girdide `null` döner — fırlatmaz. Bozuk bir yetki,
  /// yetkisizlikten farksızdır ve uygulamayı kırmamalıdır.
  static Entitlement? decode(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final k = m['k'], n = m['n'], s = m['s'];
      if (k is! String || n is! String || s is! String) return null;
      if (k.isEmpty || n.isEmpty || s.isEmpty) return null;
      return Entitlement(
        keyId: k,
        nonce: base64Url.decode(n),
        signature: BigInt.parse(s, radix: 16),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Yetki doğrulayıcı — hem istemcide (arayüzü açmak) hem sunucuda
/// (özelliği gerçekten vermek) aynı mantık kullanılır.
///
/// ⚠️ İSTEMCİ TARAFI DOĞRULAMA BİR KAPI DEĞİLDİR. Değiştirilmiş bir
/// istemci bu kontrolü atlar. Sunucuda uygulanan premium özellikler
/// jetonu SUNUCUYA göndermeli ve orada doğrulanmalıdır — kör imza tam
/// da bunu güvenli kılmak için var: sunucu doğrular ama kimin olduğunu
/// öğrenmez.
class EntitlementVerifier {
  final List<EntitlementKey> keys;

  const EntitlementVerifier(this.keys);

  EntitlementKey? keyFor(String id) {
    for (final k in keys) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Yetki şu anda geçerli mi?
  bool isValid(Entitlement? e, {required DateTime now}) {
    if (e == null) return false;
    final k = keyFor(e.keyId);
    if (k == null) return false; // bilinmeyen/geri çekilmiş anahtar
    if (!k.coversTime(now)) return false; // süresi dolmuş dönem
    return BlindSignature.verify(k.key, e.nonce, e.signature);
  }
}
