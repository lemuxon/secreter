import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/multi_account_service.dart';
import 'package:gizli_chat/services/recovery_key_service.dart';

/// Kurtarma anahtarı = HESABIN KENDİSİ.
///
/// H-18'de düzeltilen açık: anahtar düz base64'tü, yani QR'ı gören
/// (fotoğraflayan, omuz üstünden bakan) herkes hesabı devralabiliyordu.
/// Artık parola ile AES-256-GCM sarmalanıyor. Bu testler o güvencenin
/// gerçekten var olduğunu ölçer.
SavedAccount _account() => SavedAccount(
      uid: 'uid-123',
      username: 'kullanici',
      encryptionKey: 'ANAHTAR-BASE64==',
      password: 'gizli-parola',
    );

void main() {
  const pass = 'dogru-parola-123';

  group('kurtarma anahtarı — gidiş dönüş', () {
    test('doğru parolayla hesap aynen geri gelir', () async {
      final a = _account();
      final encoded = await RecoveryKeyService.encode(a, pass);
      final back = await RecoveryKeyService.decode(encoded, pass);

      expect(back.uid, a.uid);
      expect(back.username, a.username);
      expect(back.encryptionKey, a.encryptionKey);
      expect(back.password, a.password);
    });

    test('kodlanmış metin hesabı AÇIKÇA TAŞIMAZ', () async {
      // Anahtarın kendisi ya da kullanıcı adı düz görünüyorsa sarmalama
      // hiçbir işe yaramaz.
      final a = _account();
      final encoded = await RecoveryKeyService.encode(a, pass);

      expect(encoded.contains(a.encryptionKey), isFalse);
      expect(encoded.contains(a.username), isFalse);
      expect(encoded.contains(a.password), isFalse);
      expect(encoded.contains(a.uid), isFalse);
    });
  });

  group('kurtarma anahtarı — güvenlik', () {
    test('YANLIŞ parola hesabı AÇMAZ', () async {
      // H-18'in özü: anahtarı ele geçirmek TEK BAŞINA yetmemeli.
      final encoded = await RecoveryKeyService.encode(_account(), pass);

      expect(
        () => RecoveryKeyService.decode(encoded, 'yanlis-parola-123'),
        throwsA(isA<RecoveryKeyError>()),
      );
    });

    test('KISA parola reddedilir', () async {
      expect(
        () => RecoveryKeyService.encode(_account(), 'kisa'),
        throwsA(isA<RecoveryKeyError>()),
      );
    });

    test('KURCALANMIŞ anahtar reddedilir', () async {
      // AES-GCM bütünlük sağlar: değiştirilen bir anahtar sessizce
      // bozuk veri döndürmemeli, açıkça reddedilmeli.
      final encoded = await RecoveryKeyService.encode(_account(), pass);
      final parts = encoded.split(' ');
      // Şifreli metnin son karakterini değiştir.
      final ct = parts[3];
      parts[3] =
          ct.substring(0, ct.length - 1) + (ct.endsWith('A') ? 'B' : 'A');

      expect(
        () => RecoveryKeyService.decode(parts.join(' '), pass),
        throwsA(isA<RecoveryKeyError>()),
      );
    });

    test('aynı hesap her seferinde FARKLI anahtar üretir', () async {
      // Sabit tuz/nonce olsaydı iki kurtarma anahtarı birbirinin aynısı
      // olur ve karşılaştırmayla hesap eşleştirilebilirdi.
      final a = _account();
      final first = await RecoveryKeyService.encode(a, pass);
      final second = await RecoveryKeyService.encode(a, pass);

      expect(first, isNot(second));
      // Yine de ikisi de aynı hesabı açmalı.
      expect((await RecoveryKeyService.decode(second, pass)).uid, a.uid);
    });
  });

  group('kurtarma anahtarı — biçim', () {
    test('bozuk metin reddedilir', () async {
      for (final bad in ['SKP2', 'SKP2 a b', 'SKP2 a b c d e f']) {
        expect(
          () => RecoveryKeyService.decode(bad, pass),
          throwsA(isA<RecoveryKeyError>()),
          reason: 'reddedilmeliydi: $bad',
        );
      }
    });

    test('yeni biçim ESKİ sayılmaz', () async {
      final encoded = await RecoveryKeyService.encode(_account(), pass);
      expect(RecoveryKeyService.isLegacyFormat(encoded), isFalse);
      expect(RecoveryKeyService.isLegacyFormat('rastgele-eski-metin'), isTrue);
    });

    test('baştaki/sondaki boşluk anahtarı bozmaz', () async {
      // Kullanıcı anahtarı kopyala-yapıştır yaparken boşluk taşır.
      final encoded = await RecoveryKeyService.encode(_account(), pass);
      final back = await RecoveryKeyService.decode('  $encoded \n', pass);
      expect(back.uid, 'uid-123');
    });
  });
}
