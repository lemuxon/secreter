import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/double_ratchet_service.dart';

/// Bir tarafın ratchet durumu — `E2EESessionService`'in kalıcılaştırdığı
/// alanların test içi karşılığı.
class _Party {
  List<int> rootKey;
  String dhsPriv;
  String dhsPub;
  String? dhrPub;
  List<int> cks;
  List<int> ckr;
  int ns = 0;
  int nr = 0;
  int pn = 0;
  Map<String, String> skipped = {};

  _Party({
    required this.rootKey,
    required this.dhsPriv,
    required this.dhsPub,
    this.dhrPub,
    this.cks = const [],
    this.ckr = const [],
  });

  _Party copy() => _Party(
        rootKey: List<int>.from(rootKey),
        dhsPriv: dhsPriv,
        dhsPub: dhsPub,
        dhrPub: dhrPub,
        cks: List<int>.from(cks),
        ckr: List<int>.from(ckr),
      )
        ..ns = ns
        ..nr = nr
        ..pn = pn
        ..skipped = Map<String, String>.from(skipped);

  Future<String> send(String text) async {
    final r = await DoubleRatchetService.encryptV3(
      sendChainKey: cks,
      dhsPub: dhsPub,
      sendCounter: ns,
      prevSendCount: pn,
      plaintext: text,
    );
    cks = r.newSendChainKey;
    ns = r.newSendCounter;
    return r.ciphertext;
  }

  /// Çözülemezse null döner ve durum DEĞİŞMEZ.
  Future<String?> receive(String packet) async {
    final r = await DoubleRatchetService.decryptV3(
      rootKey: rootKey,
      dhsPriv: dhsPriv,
      dhsPub: dhsPub,
      dhrPub: dhrPub,
      sendChainKey: cks,
      recvChainKey: ckr,
      sendCounter: ns,
      recvCounter: nr,
      prevSendCount: pn,
      skipped: skipped,
      encryptedPacket: packet,
    );
    if (r == null) return null;
    rootKey = r.rootKey;
    dhsPriv = r.dhsPriv;
    dhsPub = r.dhsPub;
    dhrPub = r.dhrPub;
    cks = r.sendChainKey;
    ckr = r.recvChainKey;
    ns = r.sendCounter;
    nr = r.recvCounter;
    pn = r.prevSendCount;
    skipped = r.skipped;
    return r.plaintext;
  }
}

List<int> _sharedSecret() {
  final rnd = Random(42);
  return List<int>.generate(32, (_) => rnd.nextInt(256));
}

/// X3DH sonrası bootstrap — `E2EESessionService`'teki ile AYNI adımlar.
Future<(_Party alice, _Party bob)> _bootstrap() async {
  final sk = _sharedSecret();

  // Bob'un imzalı ön-anahtarı: başlangıçta onun DH çiftidir.
  final (bobSpkPriv, bobSpkPub) = await DoubleRatchetService.newDhKeyPair();

  // ALICE (başlatan): DHr = Bob'un SPK'sı, kendine yeni çift üretir.
  final (aPriv, aPub) = await DoubleRatchetService.newDhKeyPair();
  final dhOut = await DoubleRatchetService.dh(aPriv, bobSpkPub);
  final (aRk, aCks) = await DoubleRatchetService.kdfRoot(sk, dhOut);

  final alice = _Party(
    rootKey: aRk,
    dhsPriv: aPriv,
    dhsPub: aPub,
    dhrPub: bobSpkPub,
    cks: aCks,
  );

  // BOB (cevaplayan): DHs = kendi SPK çifti, DHr henüz yok.
  final bob = _Party(
    rootKey: sk,
    dhsPriv: bobSpkPriv,
    dhsPub: bobSpkPub,
  );

  return (alice, bob);
}

void main() {
  group('DH ratchet — temel akış', () {
    test('karşılıklı konuşma baştan sona çözülür', () async {
      final (alice, bob) = await _bootstrap();

      expect(await bob.receive(await alice.send('merhaba')), 'merhaba');
      expect(await alice.receive(await bob.send('selam')), 'selam');
      expect(await bob.receive(await alice.send('nasılsın')), 'nasılsın');
      expect(await alice.receive(await bob.send('iyiyim')), 'iyiyim');
    });

    test('ilk mesajda DH adımı atılır, aynı zincirde ATILMAZ', () async {
      final (alice, bob) = await _bootstrap();

      // Bob'un ilk alışı: yeni DHr → ratchet.
      final before = bob.dhsPub;
      await bob.receive(await alice.send('bir'));
      expect(bob.dhsPub, isNot(before), reason: 'ilk alışta DH adımı şart');

      // Aynı zincirden ikinci mesaj: ratchet ATILMAMALI (atılsaydı zincir
      // sıfırlanır ve sonraki mesajlar çözülemezdi).
      final after = bob.dhsPub;
      expect(await bob.receive(await alice.send('iki')), 'iki');
      expect(bob.dhsPub, after);
    });

    test('cevaplayan taraf, mesaj almadan gönderemez', () async {
      final (_, bob) = await _bootstrap();
      // Bob'un gönderme zinciri henüz yok; oturum katmanı bunu null ile
      // karşılar. Burada zincirin gerçekten boş olduğunu doğruluyoruz.
      expect(bob.cks, isEmpty);
    });
  });

  group('DH ratchet — post-compromise security', () {
    test('saldırgan çalınan durumla SONSUZA KADAR okuyamaz', () async {
      final (alice, bob) = await _bootstrap();

      // 1) Alice yazar, Bob alır (Bob burada yeni DH çifti üretir).
      expect(await bob.receive(await alice.send('m1')), 'm1');

      // 2) SALDIRGAN BOB'UN DURUMUNU ÇALAR.
      final attacker = bob.copy();

      // 3) Çalıntı durum GERÇEKTEN işe yarıyor mu? Yaramıyorsa sonraki
      //    başarısızlık hiçbir şey kanıtlamaz.
      final m2 = await alice.send('m2');
      expect(await attacker.receive(m2), 'm2',
          reason: 'çalınan durum aynı zincirde okuyabilmeli');
      expect(await bob.receive(m2), 'm2');

      // 4) Karşılıklı iki tur: her tur yeni DH çifti doğurur.
      expect(await alice.receive(await bob.send('r1')), 'r1');

      final m3 = await alice.send('m3');
      expect(await bob.receive(m3), 'm3');
      // Saldırgan bu adımı hâlâ takip edebilir (çalınan özel anahtar
      // geçerli); kendi rastgele çiftini üretir ve Bob'unkinden AYRILIR.
      await attacker.receive(m3);

      expect(await alice.receive(await bob.send('r2')), 'r2');

      // 5) BREAK-IN RECOVERY: Bob artık saldırganın bilmediği bir DH
      //    çiftine sahip. Alice'in yeni mesajı Bob'a açık, saldırgana
      //    KAPALI olmalı.
      final m4 = await alice.send('m4');
      expect(await bob.receive(m4), 'm4', reason: 'Bob okumaya devam etmeli');
      expect(await attacker.receive(m4), isNull,
          reason: 'saldırgan artık DIŞARIDA kalmalı');
    });
  });

  group('DH ratchet — sırasız ve kayıp mesajlar', () {
    test('aynı zincirde sırasız gelen mesaj çözülür', () async {
      final (alice, bob) = await _bootstrap();

      final a = await alice.send('a');
      final b = await alice.send('b');
      final c = await alice.send('c');

      // Sıra: a, c, b
      expect(await bob.receive(a), 'a');
      expect(await bob.receive(c), 'c');
      expect(await bob.receive(b), 'b',
          reason: 'atlanan anahtar saklanmış olmalı');
    });

    test('ÖNCEKİ zincirden geç gelen mesaj kaybolmaz', () async {
      // En çok hata yapılan yer burası: zincir değişince eski zincirin
      // kalan anahtarları saklanmazsa, yolda olan mesajlar kalıcı kayıp
      // olur. `pn` alanı tam bunun içindir.
      final (alice, bob) = await _bootstrap();

      expect(await bob.receive(await alice.send('1')), '1');

      // Alice iki mesaj daha yazar ama BUNLAR GECİKİR.
      final gec1 = await alice.send('gec1');
      final gec2 = await alice.send('gec2');

      // Bu arada Bob cevap yazar → Alice DH adımı atar → yeni zincir.
      expect(await alice.receive(await bob.send('cevap')), 'cevap');
      final yeni = await alice.send('yeni');

      // Bob önce YENİ zincirden mesaj alır (DH adımı atar),
      // sonra eski zincirin gecikmiş mesajları gelir.
      expect(await bob.receive(yeni), 'yeni');
      expect(await bob.receive(gec1), 'gec1',
          reason: 'eski zincirin anahtarı saklanmalıydı');
      expect(await bob.receive(gec2), 'gec2');
    });

    test('aynı mesaj İKİ KEZ çözülemez (tekrar koruması)', () async {
      final (alice, bob) = await _bootstrap();
      final m = await alice.send('tek');
      expect(await bob.receive(m), 'tek');
      expect(await bob.receive(m), isNull);
    });
  });

  group('DH ratchet — sağlamlık', () {
    test('kurcalanmış paket reddedilir', () async {
      final (alice, bob) = await _bootstrap();
      final m = await alice.send('gizli');

      // Son karakteri değiştir (base64 gövdesi bozulur).
      final bozuk =
          m.substring(0, m.length - 2) + (m.endsWith('A=') ? 'B=' : 'A=');
      expect(await bob.receive(bozuk), isNull);
    });

    test('v3 paketi tanınır, v2 paketi v3 sanılmaz', () async {
      final (alice, _) = await _bootstrap();
      final v3 = await alice.send('x');
      expect(DoubleRatchetService.isV3Packet(v3), isTrue);

      final v2 = await DoubleRatchetService.encrypt(
        chainKey: List<int>.filled(32, 7),
        plaintext: 'eski',
        messageNumber: 0,
      );
      expect(DoubleRatchetService.isV3Packet(v2.ciphertext), isFalse,
          reason: 'v2 paketi v3 yoluna girerse eski sohbetler kırılır');
      expect(DoubleRatchetService.isV3Packet('bozuk-veri'), isFalse);
    });

    test('atlanan anahtar kimliği zinciri de içerir', () {
      // Yalnızca mesaj numarası kullanılsaydı, her DH adımında numaralar
      // sıfırlandığı için farklı zincirlerin "5" numaralı mesajları
      // birbirini EZERDİ.
      final k1 = DoubleRatchetService.skippedKey('zincirA', 5);
      final k2 = DoubleRatchetService.skippedKey('zincirB', 5);
      expect(k1, isNot(k2));
    });

    test('aşırı ileri mesaj numarası reddedilir (DoS koruması)', () async {
      final (alice, bob) = await _bootstrap();

      // Zinciri kur.
      expect(await bob.receive(await alice.send('ilk')), 'ilk');

      // maxSkip'i aşacak kadar ileri git.
      alice.ns = DoubleRatchetService.maxSkip + 50;
      final uzak = await alice.send('cok-ileri');
      expect(await bob.receive(uzak), isNull,
          reason: 'milyarlarca HKDF turuna zorlanmamalı');
    });
  });
}
