import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/media/attachment_crypto.dart';

Uint8List _bytes(int n, [int seed = 1]) {
  final r = Random(seed);
  return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
}

void main() {
  group('AttachmentCrypto', () {
    test('şifrele → çöz orijinal baytları döndürür', () async {
      final key = AttachmentCrypto.newKey();
      for (final size in [0, 1, 16, 1024, 64 * 1024]) {
        final plain = _bytes(size);
        final cipher = await AttachmentCrypto.encryptBytesInline(plain, key);
        final back = await AttachmentCrypto.decryptBytesInline(cipher, key);
        expect(back, plain, reason: '$size baytta bozuldu');
      }
    });

    test('şifreli çıktı orijinalden FARKLI ve daha uzun (nonce+mac)', () async {
      final key = AttachmentCrypto.newKey();
      final plain = _bytes(500);
      final cipher = await AttachmentCrypto.encryptBytesInline(plain, key);
      expect(cipher, isNot(plain));
      // 12 bayt nonce + 16 bayt MAC
      expect(cipher.length, plain.length + 28);
    });

    test('aynı dosya her seferinde FARKLI şifreli çıktı verir', () async {
      final key = AttachmentCrypto.newKey();
      final plain = _bytes(256);
      final a = await AttachmentCrypto.encryptBytesInline(plain, key);
      final b = await AttachmentCrypto.encryptBytesInline(plain, key);
      expect(a, isNot(b), reason: 'nonce yeniden kullanılıyor olabilir');
    });

    test('YANLIŞ anahtarla çözme başarısız olur', () async {
      final key = AttachmentCrypto.newKey();
      final other = AttachmentCrypto.newKey();
      final cipher =
          await AttachmentCrypto.encryptBytesInline(_bytes(300), key);
      await expectLater(
        AttachmentCrypto.decryptBytesInline(cipher, other),
        throwsA(anything),
      );
    });

    // GCM bütünlük sağlar: sunucuda değiştirilen bir dosya sessizce bozuk
    // görüntü olarak açılmaz, çözme HATA verir.
    test('KURCALANMIŞ şifreli ek reddedilir', () async {
      final key = AttachmentCrypto.newKey();
      final cipher =
          await AttachmentCrypto.encryptBytesInline(_bytes(300), key);
      final tampered = Uint8List.fromList(cipher);
      tampered[tampered.length ~/ 2] ^= 0xFF;

      await expectLater(
        AttachmentCrypto.decryptBytesInline(tampered, key),
        throwsA(anything),
      );
    });

    test('çok kısa/bozuk veri güvenle reddedilir', () async {
      final key = AttachmentCrypto.newKey();
      for (final n in [0, 5, 27]) {
        await expectLater(
          AttachmentCrypto.decryptBytesInline(_bytes(n), key),
          throwsA(anything),
        );
      }
    });

    test('anahtar 32 bayt ve her seferinde farklı', () {
      final a = AttachmentCrypto.newKey();
      final b = AttachmentCrypto.newKey();
      expect(a, isNot(b));
      expect(base64Url.decode(base64Url.normalize(a)).length, 32);
    });

    // Anahtar doğrulaması SENKRON yapılır (çağrı anında fırlatır); böylece
    // hatalı anahtar hiç isolate'e gönderilmez.
    test('geçersiz uzunlukta anahtar reddedilir', () {
      expect(
        () => AttachmentCrypto.encryptBytesInline(
            _bytes(10), base64Url.encode([1, 2, 3])),
        throwsArgumentError,
      );
    });
  });

  group('AttachmentRef', () {
    test('kodla → çöz anahtarı korur', () {
      final key = AttachmentCrypto.newKey();
      final encoded =
          const AttachmentRef(key: 'K', caption: 'merhaba').encode();
      final parsed = AttachmentRef.tryParse(encoded);
      expect(parsed, isNotNull);
      expect(parsed!.key, 'K');
      expect(parsed.caption, 'merhaba');

      // Gerçek anahtar base64url karakterleri içerir ('-' ve '_')
      final withReal = AttachmentRef(key: key).encode();
      expect(AttachmentRef.tryParse(withReal)!.key, key);
    });

    test('açıklamada boru işareti olsa bile anahtar bozulmaz', () {
      final encoded =
          const AttachmentRef(key: 'ABC', caption: 'a|b|c').encode();
      final parsed = AttachmentRef.tryParse(encoded)!;
      expect(parsed.key, 'ABC');
      expect(parsed.caption, 'a|b|c');
    });

    test('ek olmayan içerik null döner', () {
      expect(AttachmentRef.tryParse('düz metin'), isNull);
      expect(AttachmentRef.tryParse(''), isNull);
      expect(AttachmentRef.tryParse('ATT1|'), isNull);
      expect(AttachmentRef.isAttachment('merhaba'), isFalse);
    });
  });
}
