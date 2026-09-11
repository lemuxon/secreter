import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/premium/blind_signature.dart';

/// 🎭 KÖR İMZA — "biri ödedi", "bu kişi ödedi" DEĞİL
///
/// Premium'un naif çözümü `users/{uid}.isPremium = true` yazmaktır. Bu,
/// anonim hesabı Google Play satın almasına bağlar ve şu zinciri kurar:
///
///     gerçek kimlik → Play hesabı → satın alma → SECRETER uid → sohbetler
///
/// Uygulamanın tüm iddiası bu zincirin kurulamamasına dayanıyor.
///
/// Buradaki testler matematiğin doğru olduğunu DEĞİL, **bağlanamazlık
/// özelliğinin gerçekten sağlandığını** kontrol eder.

/// Test için küçük ama gerçek bir RSA anahtar çifti.
/// (Üretimde 2048+ bit; testte hız için 512 bit yeterli — güvenlik
/// iddiası burada değil, ÖZELLİK doğrulanıyor.)
class _TestKeys {
  final BigInt n, e, d;
  const _TestKeys(this.n, this.e, this.d);

  RsaPublicKey get pub => RsaPublicKey(n: n, e: e);

  /// Sunucunun yaptığı iş: kör değeri imzala.
  BigInt sign(BigInt blinded) => blinded.modPow(d, n);
}

/// Sabit test anahtarı (deterministik testler için).
/// p, q güvenli asallar değil; yalnızca matematiği çalıştırmak için.
_TestKeys _keys() {
  // Gerçek asallar (Miller-Rabin ile doğrulanmış, 256 bit).
  final p = BigInt.parse(
      '10209453239199199943666919671731766974358345964286075860489022709992'
      '1956007333');
  final q = BigInt.parse(
      '90039300443480510546724173767609720752290018806196037719036933908073'
      '147498221');
  final n = p * q;
  final e = BigInt.from(65537);
  final phi = (p - BigInt.one) * (q - BigInt.one);
  final d = e.modInverse(phi);
  return _TestKeys(n, e, d);
}

void main() {
  final keys = _keys();
  final pub = keys.pub;

  group('gidiş-dönüş', () {
    test('körlük kaldırıldıktan sonra imza DOĞRULANIR', () {
      final req = BlindSignature.blind(pub);
      final blindSig = keys.sign(req.blinded);
      final sig = BlindSignature.unblind(pub, req, blindSig);

      expect(BlindSignature.verify(pub, req.nonce, sig), isTrue);
    });

    test('nonce 32 bayt (tahmin edilemez)', () {
      expect(BlindSignature.blind(pub).nonce.length, 32);
    });

    test('her çağrı FARKLI nonce üretir', () {
      final a = BlindSignature.blind(pub).nonce;
      final b = BlindSignature.blind(pub).nonce;
      expect(a, isNot(equals(b)));
    });
  });

  group('🎭 BAĞLANAMAZLIK — asıl mesele', () {
    test('sunucunun GÖRDÜĞÜ değer, sonradan SUNULAN değer DEĞİLDİR', () {
      // ⚠️ ÖZELLİĞİN KALBİ. Sunucu `blinded`i görür; kullanıcı sonradan
      // `nonce` + `sig` sunar. İkisi eşleşirse sunucu satın almayı
      // kullanıma bağlayabilirdi — yani anonimlik biterdi.
      final req = BlindSignature.blind(pub);
      final blindSig = keys.sign(req.blinded);
      final sig = BlindSignature.unblind(pub, req, blindSig);

      expect(req.blinded, isNot(equals(sig)),
          reason: 'sunucunun imzaladığı değer sunulan imzayla AYNI olmamalı');
      expect(
          req.blinded.toString(),
          isNot(contains(
              BlindSignature.fullDomainHash(req.nonce, pub).toString())),
          reason: 'körleştirilmiş değer özeti açığa vermemeli');
    });

    test('AYNI nonce, farklı körleştirmeyle farklı görünür', () {
      // Sunucu iki isteği aynı kişiye ait diye eşleştiremez.
      final nonce = Uint8List.fromList(List.filled(32, 7));
      final a = BlindSignature.blind(pub, nonce: nonce);
      final b = BlindSignature.blind(pub, nonce: nonce);
      expect(a.blinded, isNot(equals(b.blinded)));
    });

    test('sunucu körleştirilmiş değerden nonce ÇIKARAMAZ', () {
      // Körleştirme çarpanı olmadan geri dönüş yok. Burada "çıkaramaz"ı
      // kanıtlayamayız (kriptografik varsayım), ama en azından değerin
      // özetle DOĞRUDAN ilişkili olmadığını gösterebiliriz.
      final req = BlindSignature.blind(pub);
      final m = BlindSignature.fullDomainHash(req.nonce, pub);
      expect(req.blinded, isNot(equals(m)));
    });
  });

  group('sahtecilik reddedilir', () {
    test('KURCALANMIŞ imza doğrulanmaz', () {
      final req = BlindSignature.blind(pub);
      final sig = BlindSignature.unblind(pub, req, keys.sign(req.blinded));
      expect(BlindSignature.verify(pub, req.nonce, sig + BigInt.one), isFalse);
    });

    test('BAŞKA nonce ile aynı imza geçmez', () {
      final req = BlindSignature.blind(pub);
      final sig = BlindSignature.unblind(pub, req, keys.sign(req.blinded));
      final other = Uint8List.fromList(List.filled(32, 1));
      expect(BlindSignature.verify(pub, other, sig), isFalse);
    });

    test('imzasız (uydurma) değer geçmez', () {
      final req = BlindSignature.blind(pub);
      expect(
          BlindSignature.verify(pub, req.nonce, BigInt.from(12345)), isFalse);
    });

    test('sınır değerler reddedilir', () {
      final req = BlindSignature.blind(pub);
      expect(BlindSignature.verify(pub, req.nonce, BigInt.zero), isFalse);
      expect(BlindSignature.verify(pub, req.nonce, pub.n), isFalse);
    });

    test('BAŞKA anahtarla üretilen imza geçmez', () {
      // Sunucu anahtarı değişirse eski yetkiler düşer — istenen davranış.
      final req = BlindSignature.blind(pub);
      final sig = BlindSignature.unblind(pub, req, keys.sign(req.blinded));
      final otherKeys = _TestKeys(pub.n, BigInt.from(3), keys.d);
      expect(
        BlindSignature.verify(otherKeys.pub, req.nonce, sig),
        isFalse,
      );
    });
  });

  group('tam alan özeti', () {
    test('modülüsten KESİN küçük (mod indirgemesi gerekmez)', () {
      // İndirgeme yapılsaydı yanlılık oluşurdu; bir bayt eksik üretilir.
      for (var i = 0; i < 20; i++) {
        final nonce = BlindSignature.blind(pub).nonce;
        expect(BlindSignature.fullDomainHash(nonce, pub) < pub.n, isTrue);
      }
    });

    test('deterministiktir', () {
      final nonce = Uint8List.fromList(List.filled(32, 3));
      expect(BlindSignature.fullDomainHash(nonce, pub),
          BlindSignature.fullDomainHash(nonce, pub));
    });

    test('SHA-256 den UZUNDUR (FDH gereği)', () {
      final nonce = Uint8List.fromList(List.filled(32, 3));
      final h = BlindSignature.fullDomainHash(nonce, pub);
      expect(h.bitLength, greaterThan(256));
    });
  });

  group('rastgelelik', () {
    test('sahte rastgelelikle deterministik (test edilebilirlik)', () {
      final n1 = BlindSignature.blind(pub,
              nonce: Uint8List.fromList(List.filled(32, 9)), random: Random(1))
          .blinded;
      final n2 = BlindSignature.blind(pub,
              nonce: Uint8List.fromList(List.filled(32, 9)), random: Random(1))
          .blinded;
      expect(n1, n2);
    });
  });
}
