import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/double_ratchet_service.dart';

List<int> _rootKey() {
  final r = Random(7);
  return List<int>.generate(32, (_) => r.nextInt(256));
}

void main() {
  group('DoubleRatchetService', () {
    test('sıralı mesajlar doğru çözülür', () async {
      var sendChain = _rootKey();
      var recvChain = _rootKey();
      var recvIndex = 0;
      var skipped = <String, String>{};

      for (var i = 0; i < 10; i++) {
        final enc = await DoubleRatchetService.encrypt(
          chainKey: sendChain,
          plaintext: 'mesaj $i',
          messageNumber: i,
        );
        sendChain = enc.newChainKey;

        final dec = await DoubleRatchetService.decrypt(
          chainKey: recvChain,
          chainIndex: recvIndex,
          skipped: skipped,
          encryptedPacket: enc.ciphertext,
        );
        expect(dec, isNotNull, reason: '$i. mesaj çözülemedi');
        expect(dec!.plaintext, 'mesaj $i');
        recvChain = dec.newChainKey;
        recvIndex = dec.newChainIndex;
        skipped = dec.skipped;
      }
    });

    // ⚠️ ASIL DÜZELTİLEN TASARIM HATASI.
    // Eski sürüm mesaj numarasını hiç kullanmıyor, her çözmede zinciri tam
    // bir adım ilerletiyordu. Gerçek ağda mesajlar SIRASIZ gelir; böyle bir
    // durumda zincir senkronizasyonunu kalıcı olarak kaybediyor ve SONRAKİ
    // TÜM MESAJLAR çözülemez hâle geliyordu.
    test('SIRASIZ mesajlar çözülebilir (atlanan anahtar saklanır)', () async {
      var sendChain = _rootKey();
      final packets = <String>[];
      for (var i = 0; i < 5; i++) {
        final enc = await DoubleRatchetService.encrypt(
          chainKey: sendChain,
          plaintext: 'm$i',
          messageNumber: i,
        );
        sendChain = enc.newChainKey;
        packets.add(enc.ciphertext);
      }

      var recvChain = _rootKey();
      var recvIndex = 0;
      var skipped = <String, String>{};

      // Önce 4. mesaj gelsin (0–3 yolda gecikti)
      var dec = await DoubleRatchetService.decrypt(
        chainKey: recvChain,
        chainIndex: recvIndex,
        skipped: skipped,
        encryptedPacket: packets[4],
      );
      expect(dec, isNotNull);
      expect(dec!.plaintext, 'm4');
      recvChain = dec.newChainKey;
      recvIndex = dec.newChainIndex;
      skipped = dec.skipped;
      expect(skipped.length, 4, reason: '0–3 anahtarları saklanmalı');

      // Şimdi gecikenler gelsin — HEPSİ çözülebilmeli
      for (final i in [0, 3, 1, 2]) {
        final late = await DoubleRatchetService.decrypt(
          chainKey: recvChain,
          chainIndex: recvIndex,
          skipped: skipped,
          encryptedPacket: packets[i],
        );
        expect(late, isNotNull, reason: 'geciken m$i çözülemedi');
        expect(late!.plaintext, 'm$i');
        skipped = late.skipped;
        recvChain = late.newChainKey;
        recvIndex = late.newChainIndex;
      }
      expect(skipped, isEmpty, reason: 'kullanılan anahtarlar silinmeli');
    });

    test('aynı mesaj iki kez çözülemez (tek kullanım)', () async {
      final enc = await DoubleRatchetService.encrypt(
        chainKey: _rootKey(),
        plaintext: 'tek',
        messageNumber: 0,
      );

      final first = await DoubleRatchetService.decrypt(
        chainKey: _rootKey(),
        chainIndex: 0,
        skipped: const {},
        encryptedPacket: enc.ciphertext,
      );
      expect(first!.plaintext, 'tek');

      // Zincir ilerledi; aynı paket tekrar çözülemez
      final second = await DoubleRatchetService.decrypt(
        chainKey: first.newChainKey,
        chainIndex: first.newChainIndex,
        skipped: first.skipped,
        encryptedPacket: enc.ciphertext,
      );
      expect(second, isNull);
    });

    test('her mesaj FARKLI anahtar kullanır (forward secrecy)', () async {
      var chain = _rootKey();
      final packets = <String>{};
      for (var i = 0; i < 5; i++) {
        final enc = await DoubleRatchetService.encrypt(
          chainKey: chain,
          plaintext: 'sabit metin',
          messageNumber: i,
        );
        chain = enc.newChainKey;
        packets.add(enc.ciphertext);
      }
      expect(packets.length, 5, reason: 'Şifreli çıktılar tekrar etmemeli');
    });

    // Kötü niyetli bir gönderen `num: 2000000000` yazarak istemciyi
    // milyarlarca HKDF turuna zorlayabilirdi (hizmet dışı bırakma).
    test('aşırı ileri mesaj numarası REDDEDİLİR (DoS koruması)', () async {
      final enc = await DoubleRatchetService.encrypt(
        chainKey: _rootKey(),
        plaintext: 'x',
        messageNumber: 0,
      );
      // Paketteki numarayı şişir
      final raw = jsonDecode(utf8.decode(base64.decode(enc.ciphertext)))
          as Map<String, dynamic>;
      raw['num'] = 2000000000;
      final evil = base64.encode(utf8.encode(jsonEncode(raw)));

      final dec = await DoubleRatchetService.decrypt(
        chainKey: _rootKey(),
        chainIndex: 0,
        skipped: const {},
        encryptedPacket: evil,
      );
      expect(dec, isNull);
    });

    test('bozuk/kurcalanmış paket null döner, fırlatmaz', () async {
      for (final bad in ['', 'çöp', 'YWJj', base64.encode(utf8.encode('{}'))]) {
        final dec = await DoubleRatchetService.decrypt(
          chainKey: _rootKey(),
          chainIndex: 0,
          skipped: const {},
          encryptedPacket: bad,
        );
        expect(dec, isNull);
      }
    });
  });
}
