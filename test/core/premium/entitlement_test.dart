import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/premium/blind_signature.dart';
import 'package:gizli_chat/core/premium/entitlement.dart';

/// 🎟️ YETKİ JETONU — hesaba bağlanmayan premium
///
/// Naif çözüm `users/{uid}.isPremium = true`. Bu, anonim hesabı Google
/// Play satın almasına bağlar. Buradaki testler jetonun **kullanıcıyı
/// tanımlayan hiçbir şey taşımadığını** ve süre kontrolünün gerçekten
/// çalıştığını doğrular.
BigInt _sign(BigInt blinded, BigInt d, BigInt n) => blinded.modPow(d, n);

void main() {
  // Gerçek asallar (256 bit ×2 = 512 bit modülüs; testte hız için).
  final p = BigInt.parse(
      '10209453239199199943666919671731766974358345964286075860489022709992'
      '1956007333');
  final q = BigInt.parse(
      '90039300443480510546724173767609720752290018806196037719036933908073'
      '147498221');
  final n = p * q;
  final e = BigInt.from(65537);
  final d = e.modInverse((p - BigInt.one) * (q - BigInt.one));
  final pub = RsaPublicKey(n: n, e: e);

  final ekim = EntitlementKey(
    id: 'prem-2026-10',
    key: pub,
    notBefore: DateTime.utc(2026, 10, 1),
    notAfter: DateTime.utc(2026, 11, 1),
  );
  final verifier = EntitlementVerifier([ekim]);

  Entitlement issue() {
    final req = BlindSignature.blind(pub);
    final sig = BlindSignature.unblind(pub, req, _sign(req.blinded, d, n));
    return Entitlement(keyId: ekim.id, nonce: req.nonce, signature: sig);
  }

  group('geçerlilik', () {
    test('dönem içinde GEÇERLİ', () {
      expect(
          verifier.isValid(issue(), now: DateTime.utc(2026, 10, 15)), isTrue);
    });

    test('dönem BAŞLAMADAN geçersiz', () {
      expect(
          verifier.isValid(issue(), now: DateTime.utc(2026, 9, 30)), isFalse);
    });

    test('dönem BİTTİKTEN sonra geçersiz', () {
      // ⚠️ Süre jetonun İÇİNDE değil, ANAHTARIN penceresinde. Sunucu
      // körleştirilmiş değere tarih yazamayacağı için tek doğru yol bu.
      expect(
          verifier.isValid(issue(), now: DateTime.utc(2026, 11, 1)), isFalse);
    });

    test('BİLİNMEYEN anahtar kimliği reddedilir', () {
      final t = issue();
      final sahte = Entitlement(
          keyId: 'prem-2099-01', nonce: t.nonce, signature: t.signature);
      expect(verifier.isValid(sahte, now: DateTime.utc(2026, 10, 15)), isFalse);
    });

    test('yetki YOKSA premium yok', () {
      expect(verifier.isValid(null, now: DateTime.utc(2026, 10, 15)), isFalse);
    });
  });

  group('sahtecilik', () {
    test('UYDURMA imza reddedilir', () {
      final sahte = Entitlement(
        keyId: ekim.id,
        nonce: Uint8List.fromList(List.filled(32, 5)),
        signature: BigInt.from(42),
      );
      expect(verifier.isValid(sahte, now: DateTime.utc(2026, 10, 15)), isFalse);
    });

    test('nonce DEĞİŞTİRİLİRSE geçersiz', () {
      final t = issue();
      final sahte = Entitlement(
        keyId: t.keyId,
        nonce: Uint8List.fromList(List.filled(32, 1)),
        signature: t.signature,
      );
      expect(verifier.isValid(sahte, now: DateTime.utc(2026, 10, 15)), isFalse);
    });
  });

  group('🎭 jeton kullanıcıyı TANIMLAMAZ', () {
    test('kodlanmış jetonda uid/ad/satın alma izi YOK', () {
      // ⚠️ ASIL MESELE. Jeton cihazda saklanır ve sunucuya sunulur;
      // içinde kimliğe dair bir şey olsaydı tüm tasarım anlamsız olurdu.
      final raw = issue().encode();
      for (final iz in ['uid', 'user', 'purchase', 'order', 'email', 'play']) {
        expect(raw.toLowerCase(), isNot(contains(iz)), reason: '$iz sızıyor');
      }
    });

    test('iki yetki birbirinden AYIRT EDİLEMEZ biçimde üretilir', () {
      // Aynı dönemde alınan iki yetki yalnızca rastgele nonce ile
      // ayrışır; sıralama, sayaç ya da zaman damgası taşımaz.
      final a = Entitlement.decode(issue().encode())!;
      final b = Entitlement.decode(issue().encode())!;
      expect(a.keyId, b.keyId);
      expect(a.nonce, isNot(equals(b.nonce)));
      expect(a.nonce.length, b.nonce.length);
    });
  });

  group('taşıma biçimi', () {
    test('gidiş-dönüş bozulmaz', () {
      final t = issue();
      final r = Entitlement.decode(t.encode())!;
      expect(r.keyId, t.keyId);
      expect(r.nonce, t.nonce);
      expect(r.signature, t.signature);
      expect(verifier.isValid(r, now: DateTime.utc(2026, 10, 15)), isTrue);
    });

    test('BOZUK girdi null döner, FIRLATMAZ', () {
      // Bozuk yetki = yetkisizlik. Uygulamayı kırmamalı.
      for (final bozuk in ['', '{', 'null', '{"k":"x"}', '[]', 'düz metin']) {
        expect(Entitlement.decode(bozuk), isNull, reason: bozuk);
      }
    });
  });
}
