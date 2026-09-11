import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gizli_chat/core/security/security_alerts.dart';
import 'package:gizli_chat/services/double_ratchet_service.dart';
import 'package:gizli_chat/services/group_key_service.dart';

/// Grup/kanal E2EE (Sender Key) — çözme tarafı ve zarf ayrımı.
///
/// BEYAZ KUTU NOTU: `encrypt` anahtar dağıtımı için Firestore'a gider,
/// bu yüzden birim testte çalıştırılamaz. Onun yerine alıcının zinciri
/// doğrudan güvenli depoya yazılıp ÇÖZME yolu ölçülüyor — asıl kırılgan
/// olan ve mesajların okunabilirliğini belirleyen taraf burası.
String _recvKey(String uid, String chatId, String senderId) =>
    'gsk_recv_${uid}_${chatId}_$senderId';

String _sendKey(String uid, String chatId) => 'gsk_send_${uid}_$chatId';

String _membersKey(String uid, String chatId) => 'gsk_members_${uid}_$chatId';

String _chainJson(List<int> chainKey, {int index = 0, int epoch = 0}) =>
    jsonEncode({
      'k': base64.encode(chainKey),
      'i': index,
      'e': epoch,
      'skp': <String, String>{},
    });

String _envelope({
  required String senderId,
  required int epoch,
  required String payload,
}) =>
    base64.encode(utf8.encode(jsonEncode({
      'v': 1,
      's': senderId,
      'e': epoch,
      'p': payload,
    })));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const me = 'benim-uid';
  const sender = 'gonderen-uid';
  const chatId = 'grup1';
  final chainKey = List<int>.filled(32, 9);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    GroupKeyService.setActiveAccount(me);
  });

  group('zarf ayrımı', () {
    test('grup zarfı tanınır', () async {
      final step = await DoubleRatchetService.encrypt(
        chainKey: chainKey,
        plaintext: 'selam',
        messageNumber: 0,
      );
      final env =
          _envelope(senderId: sender, epoch: 0, payload: step.ciphertext);

      expect(GroupKeyService.isGroupEnvelope(env), isTrue);
    });

    test('BİREBİR mesaj paketi grup zarfı SANILMAZ', () async {
      // ⚠️ Yanlış pozitif, birebir mesajı grup yoluna sokar ve o sohbeti
      // tamamen çözülemez yapardı.
      final v2 = await DoubleRatchetService.encrypt(
        chainKey: chainKey,
        plaintext: 'birebir',
        messageNumber: 0,
      );
      expect(GroupKeyService.isGroupEnvelope(v2.ciphertext), isFalse);

      final (priv, pub) = await DoubleRatchetService.newDhKeyPair();
      final v3 = await DoubleRatchetService.encryptV3(
        sendChainKey: chainKey,
        dhsPub: pub,
        sendCounter: 0,
        prevSendCount: 0,
        plaintext: 'birebir v3',
      );
      expect(priv, isNotEmpty);
      expect(GroupKeyService.isGroupEnvelope(v3.ciphertext), isFalse);
    });

    test('düz metin ve çöp veri zarf sayılmaz', () {
      expect(GroupKeyService.isGroupEnvelope('merhaba dünya'), isFalse);
      expect(GroupKeyService.isGroupEnvelope(''), isFalse);
      expect(GroupKeyService.isGroupEnvelope('!!!bozuk!!!'), isFalse);
    });
  });

  group('çözme', () {
    test('gönderenin zinciriyle çözülür ve zincir İLERLER', () async {
      FlutterSecureStorage.setMockInitialValues({
        _recvKey(me, chatId, sender): _chainJson(chainKey),
      });
      GroupKeyService.setActiveAccount(me);

      final m0 = await DoubleRatchetService.encrypt(
        chainKey: chainKey,
        plaintext: 'ilk',
        messageNumber: 0,
      );
      final m1 = await DoubleRatchetService.encrypt(
        chainKey: m0.newChainKey,
        plaintext: 'ikinci',
        messageNumber: 1,
      );

      expect(
        await GroupKeyService.decrypt(
          chatId: chatId,
          myUid: me,
          ciphertext:
              _envelope(senderId: sender, epoch: 0, payload: m0.ciphertext),
        ),
        'ilk',
      );
      expect(
        await GroupKeyService.decrypt(
          chatId: chatId,
          myUid: me,
          ciphertext:
              _envelope(senderId: sender, epoch: 0, payload: m1.ciphertext),
        ),
        'ikinci',
        reason: 'zincir ilerlemiş olmalı',
      );
    });

    test('sırasız gelen mesaj kaybolmaz', () async {
      FlutterSecureStorage.setMockInitialValues({
        _recvKey(me, chatId, sender): _chainJson(chainKey),
      });
      GroupKeyService.setActiveAccount(me);

      final m0 = await DoubleRatchetService.encrypt(
        chainKey: chainKey,
        plaintext: 'bir',
        messageNumber: 0,
      );
      final m1 = await DoubleRatchetService.encrypt(
        chainKey: m0.newChainKey,
        plaintext: 'iki',
        messageNumber: 1,
      );

      // Önce İKİNCİ mesaj gelir.
      expect(
        await GroupKeyService.decrypt(
          chatId: chatId,
          myUid: me,
          ciphertext:
              _envelope(senderId: sender, epoch: 0, payload: m1.ciphertext),
        ),
        'iki',
      );
      // Geciken birinci mesaj hâlâ açılmalı (atlanan anahtar saklanır).
      expect(
        await GroupKeyService.decrypt(
          chatId: chatId,
          myUid: me,
          ciphertext:
              _envelope(senderId: sender, epoch: 0, payload: m0.ciphertext),
        ),
        'bir',
      );
    });

    test('BAŞKA gönderenin zinciriyle çözülemez', () async {
      // Her gönderenin kendi zinciri vardır; karışırsa bir üye başkasının
      // adına mesaj "çözdürebilir".
      FlutterSecureStorage.setMockInitialValues({
        _recvKey(me, chatId, sender): _chainJson(chainKey),
      });
      GroupKeyService.setActiveAccount(me);

      final m = await DoubleRatchetService.encrypt(
        chainKey: List<int>.filled(32, 3), // farklı zincir
        plaintext: 'sahte',
        messageNumber: 0,
      );

      expect(
        await GroupKeyService.decrypt(
          chatId: chatId,
          myUid: me,
          ciphertext:
              _envelope(senderId: sender, epoch: 0, payload: m.ciphertext),
        ),
        isNull,
      );
    });

    test('zarf olmayan içerik null döner', () async {
      expect(
        await GroupKeyService.decrypt(
          chatId: chatId,
          myUid: me,
          ciphertext: 'bu bir zarf değil',
        ),
        isNull,
      );
    });
  });

  /// 🐞 KAPATILAN AÇIK: rotasyon yalnızca üyeyi ATAN cihazda yapılıyordu.
  ///
  /// Sender key deseninde her üyenin AYRI gönderen zinciri vardır.
  /// `_afterMembershipChange` yalnızca atan yöneticinin zincirini
  /// yeniliyordu; kalan üyelerin zincirleri olduğu gibi kaldığı için
  /// ATILAN kişi onların SONRAKİ mesajlarını okumaya devam edebiliyordu.
  /// Sınıf başlığındaki "ayrılan kişi sonraki mesajları okuyamaz" sözü
  /// tek cihazda tutuyordu.
  ///
  /// Bu testler sözün HER cihazda tutmasını kilitler.
  group('üyelik değişiminde rotasyon (her cihazda)', () {
    const a = 'uye-a';
    const b = 'uye-b';
    const c = 'uye-c';

    /// Gönderen zincirim duruyor mu? (rotasyon onu SİLER)
    Future<bool> sendChainExists() async =>
        await const FlutterSecureStorage().read(key: _sendKey(me, chatId)) !=
        null;

    test('ilk görülüşte rotasyon YOK, anlık görüntü kaydedilir', () async {
      FlutterSecureStorage.setMockInitialValues({
        _sendKey(me, chatId): _chainJson(chainKey),
      });
      GroupKeyService.setActiveAccount(me);

      expect(await GroupKeyService.syncMembership(chatId, [me, a, b]), isFalse,
          reason: 'karşılaştırılacak geçmiş yokken rotasyon olmamalı');
      expect(await sendChainExists(), isTrue);
      expect(
        await const FlutterSecureStorage().read(key: _membersKey(me, chatId)),
        isNotNull,
        reason: 'sonraki karşılaştırma için anlık görüntü yazılmalı',
      );
    });

    test('ÜYE ÇIKINCA zincirim rotasyona girer', () async {
      FlutterSecureStorage.setMockInitialValues({
        _sendKey(me, chatId): _chainJson(chainKey),
        _membersKey(me, chatId): jsonEncode([a, b, c, me]),
      });
      GroupKeyService.setActiveAccount(me);

      // c gruptan atıldı — ATAN BEN DEĞİLİM, ama zincirim yine de
      // yenilenmeli: aksi halde c benim sonraki mesajlarımı okur.
      expect(await GroupKeyService.syncMembership(chatId, [a, b, me]), isTrue);
      expect(await sendChainExists(), isFalse,
          reason: 'rotasyon gönderen zincirini silmeli');
    });

    test('ÜYE EKLENİNCE rotasyon OLMAZ', () async {
      FlutterSecureStorage.setMockInitialValues({
        _sendKey(me, chatId): _chainJson(chainKey),
        _membersKey(me, chatId): jsonEncode([a, me]),
      });
      GroupKeyService.setActiveAccount(me);

      // Zincir ileri ilerlediği için yeni üye geçmişi zaten açamaz;
      // her eklemede rotasyon tüm gruba gereksiz dağıtım maliyeti olurdu.
      expect(await GroupKeyService.syncMembership(chatId, [a, b, me]), isFalse);
      expect(await sendChainExists(), isTrue);
    });

    test('üyelik AYNIYSA rotasyon olmaz (sıra fark etmez)', () async {
      FlutterSecureStorage.setMockInitialValues({
        _sendKey(me, chatId): _chainJson(chainKey),
        _membersKey(me, chatId): jsonEncode([a, b, me]),
      });
      GroupKeyService.setActiveAccount(me);

      expect(await GroupKeyService.syncMembership(chatId, [me, b, a]), isFalse);
      expect(await sendChainExists(), isTrue,
          reason: 'her mesajda rotasyon, grubu sürekli yeniden dağıtıma sokar');
    });

    test('BOŞ üye listesi rotasyon TETİKLEMEZ', () async {
      // ⚠️ Boş liste bir üyelik değil, OKUNAMAMIŞ bir listedir. "Herkes
      // çıkmış" sayılsaydı her geçici okuma hatası rotasyon doğururdu.
      FlutterSecureStorage.setMockInitialValues({
        _sendKey(me, chatId): _chainJson(chainKey),
        _membersKey(me, chatId): jsonEncode([a, b, me]),
      });
      GroupKeyService.setActiveAccount(me);

      expect(await GroupKeyService.syncMembership(chatId, const []), isFalse);
      expect(await sendChainExists(), isTrue);
      expect(
        await const FlutterSecureStorage().read(key: _membersKey(me, chatId)),
        jsonEncode([a, b, me]),
        reason: 'okunamamış liste anlık görüntüyü EZMEMELİ (dokunulmadan '
            'kalmalı; ezilseydi gerçek üyelik farkı KALICI olarak kaybolurdu)',
      );
    });

    test('BOZUK anlık görüntüde güvenli taraf ROTASYONDUR', () async {
      FlutterSecureStorage.setMockInitialValues({
        _sendKey(me, chatId): _chainJson(chainKey),
        _membersKey(me, chatId): '{bozuk json',
      });
      GroupKeyService.setActiveAccount(me);

      // Kimin çıktığı bilinemiyor; bedeli tek bir yeniden dağıtım,
      // alternatifi atılmış bir üyenin okumaya devam etmesi.
      expect(await GroupKeyService.syncMembership(chatId, [a, me]), isTrue);
      expect(await sendChainExists(), isFalse);
    });

    test('başarılı rotasyon uyarı bandını KALDIRIR', () async {
      // §4s bandı eskiden yalnızca üyeyi ATAN yöneticinin cihazında
      // yönetiliyordu. Artık her cihaz kendi rotasyonunun sonucunu
      // yazıyor; başarıda asılı kalan bir bant bırakmamalı.
      SharedPreferences.setMockInitialValues({'sec_rotfail_$chatId': true});
      FlutterSecureStorage.setMockInitialValues({
        _sendKey(me, chatId): _chainJson(chainKey),
        _membersKey(me, chatId): jsonEncode([a, b, me]),
      });
      GroupKeyService.setActiveAccount(me);

      expect(await GroupKeyService.syncMembership(chatId, [a, me]), isTrue);
      expect(await SecurityAlerts.groupKeyRotationFailed(chatId), isFalse,
          reason: 'zincir silindiyse ileri gizlilik geri geldi');
    });

    test('başarılı rotasyondan sonra AYNI fark tekrar rotasyon yapmaz',
        () async {
      // Anlık görüntü güncellendiği için ikinci gönderim aynı farkı
      // yeniden görmemeli; görseydi her mesaj yeni bir zincir üretir ve
      // grup sürekli yeniden dağıtıma girerdi.
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({
        _sendKey(me, chatId): _chainJson(chainKey),
        _membersKey(me, chatId): jsonEncode([a, b, me]),
      });
      GroupKeyService.setActiveAccount(me);

      expect(await GroupKeyService.syncMembership(chatId, [a, me]), isTrue);
      expect(await GroupKeyService.syncMembership(chatId, [a, me]), isFalse);
    });

    test('anlık görüntü HESAP KAPSAMLIDIR', () async {
      FlutterSecureStorage.setMockInitialValues({
        _membersKey(me, chatId): jsonEncode([a, b, me]),
      });

      // Başka hesap bu anlık görüntüyü görmemeli; görseydi hesap
      // değişimi her grupta sahte bir "üye çıktı" farkı üretirdi.
      GroupKeyService.setActiveAccount('baska-uid');
      expect(
        await GroupKeyService.syncMembership(chatId, ['baska-uid', a]),
        isFalse,
        reason: 'kapsam dışı anlık görüntü ilk görülüş sayılmalı',
      );
    });
  });

  group('hesap kapsamı', () {
    test('başka hesabın grup anahtarı görünmez', () async {
      FlutterSecureStorage.setMockInitialValues({
        _recvKey(me, chatId, sender): _chainJson(chainKey),
      });

      final m = await DoubleRatchetService.encrypt(
        chainKey: chainKey,
        plaintext: 'gizli',
        messageNumber: 0,
      );
      final env = _envelope(senderId: sender, epoch: 0, payload: m.ciphertext);

      // BAŞKA hesap: anahtar kapsam dışında kalmalı.
      GroupKeyService.setActiveAccount('baska-uid');
      expect(
        await GroupKeyService.decrypt(
            chatId: chatId, myUid: 'baska-uid', ciphertext: env),
        isNull,
        reason: 'çoklu hesapta grup anahtarı sızmamalı',
      );
    });
  });
}
