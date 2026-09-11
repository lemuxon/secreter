import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/error/exceptions.dart';
import 'package:gizli_chat/services/encryption_service.dart';

void main() {
  group('EncryptionService (AES-256-GCM)', () {
    test('şifrele → çöz orijinal metni döndürür', () async {
      final key = EncryptionService.generateKey();
      final cases = <String>[
        '',
        'OK',
        'Merhaba dünya',
        'çğışöü ÇĞİŞÖÜ',
        '🔒🎉 emoji ve\nsatır sonu',
        'uzun mesaj ' * 500,
      ];
      for (final text in cases) {
        final cipher = await EncryptionService.encrypt(text, key);
        expect(await EncryptionService.decrypt(cipher, key), text);
      }
    });

    test('üretilen anahtar 32 bayt ve her seferinde farklı', () {
      final a = EncryptionService.generateKey();
      final b = EncryptionService.generateKey();
      expect(a, isNot(b));
      expect(base64Url.decode(base64Url.normalize(a)).length, 32);
    });

    test('aynı metin her şifrelemede FARKLI çıktı verir (nonce)', () async {
      final key = EncryptionService.generateKey();
      final c1 = await EncryptionService.encrypt('aynı metin', key);
      final c2 = await EncryptionService.encrypt('aynı metin', key);
      expect(c1, isNot(c2), reason: 'Nonce yeniden kullanılıyor olabilir');
    });

    // ⚠️ EN KRİTİK REGRESYON TESTİ.
    // Eski kod `catch (e) { return plainText; }` yapıyordu: anahtar bozuk
    // ya da kısa olduğunda şifreli metin yerine DÜZ METNİ döndürüyor ve
    // çağıran taraf bunu "şifrelenmiş" sanıp sunucuya yazıyordu. Kullanıcı
    // kilit simgesi görürken içerik açıktaydı.
    test('geçersiz anahtarda ASLA düz metin döndürmez, FIRLATIR', () async {
      const secret = 'çok gizli mesaj';
      for (final badKey in ['', 'kısa', 'AAAA', '!!!not-base64!!!']) {
        await expectLater(
          EncryptionService.encrypt(secret, badKey),
          throwsA(isA<EncryptionException>()),
          reason: 'Anahtar "$badKey" için istisna beklendi',
        );
      }
    });

    test('yanlış anahtarla çözme başarısız olur (kimlik doğrulama)', () async {
      final key = EncryptionService.generateKey();
      final other = EncryptionService.generateKey();
      final cipher = await EncryptionService.encrypt('gizli', key);
      await expectLater(
        EncryptionService.decrypt(cipher, other),
        throwsA(anything),
      );
    });

    // AES-GCM bütünlük sağlar: kurcalanmış veri sessizce yanlış sonuç
    // vermez. Eski AES-CBC uygulamasında bu koruma YOKTU.
    test('kurcalanmış şifreli metin reddedilir', () async {
      final key = EncryptionService.generateKey();
      final cipher = await EncryptionService.encrypt('gizli mesaj', key);
      final parts = cipher.split('.');
      // Şifreli gövdenin son karakterini değiştir
      final body = parts[2];
      final tampered =
          body.substring(0, body.length - 1) + (body.endsWith('A') ? 'B' : 'A');
      final broken = [parts[0], parts[1], tampered, parts[3]].join('.');

      await expectLater(
        EncryptionService.decrypt(broken, key),
        throwsA(anything),
      );
    });

    test('tanınmayan biçim reddedilir', () async {
      final key = EncryptionService.generateKey();
      for (final bad in ['düz metin', 'a.b', 'v1.a.b.c', '']) {
        await expectLater(
          EncryptionService.decrypt(bad, key),
          throwsA(isA<EncryptionException>()),
        );
      }
    });

    test('isCipherText yalnızca kendi biçimini tanır', () async {
      final key = EncryptionService.generateKey();
      final cipher = await EncryptionService.encrypt('x', key);
      expect(EncryptionService.isCipherText(cipher), isTrue);
      expect(EncryptionService.isCipherText('düz metin'), isFalse);
      // Eski CBC biçimi (iv.ct) artık şifreli sayılmaz
      expect(EncryptionService.isCipherText('abc.def'), isFalse);
    });
  });
}
