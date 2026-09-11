import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/security/secure_store.dart';
import 'package:gizli_chat/services/e2ee_session_service.dart';
import 'package:gizli_chat/services/key_management_service.dart';

/// Güvenlik numarası + kimlik anahtarı değişimi testleri.
///
/// BEYAZ KUTU NOTU: oturum kaydı doğrudan güvenli depoya yazılıyor.
/// Gerçek yoldan (X3DH) oturum kurmak Firestore ve Cloud Functions
/// gerektirdiği için birim testte mümkün değil; test edilen şey zaten
/// anahtar anlaşması değil, ONUN ÜSTÜNDEKİ doğrulama mantığı.
SessionState _session({
  String? peer,
  bool verified = false,
  bool userVerified = false,
  String? changedFrom,
  int sendCounter = 3,
}) =>
    SessionState(
      sendingChainKey: List<int>.filled(32, 1),
      receivingChainKey: List<int>.filled(32, 2),
      sendCounter: sendCounter,
      recvCounter: 4,
      skipped: const {'7': 'c2tpcHBlZA=='},
      peerIdentityKey: peer,
      verified: verified,
      userVerified: userVerified,
      changedFrom: changedFrom,
    );

String _sessionKey(String uid, String chatId) => 'e2ee_session_${uid}_$chatId';

/// Belirli bir hesap + sohbet için sahte cihaz durumu kur.
Future<void> _seed({
  required String uid,
  required String chatId,
  required String myIdentity,
  required SessionState state,
}) async {
  FlutterSecureStorage.setMockInitialValues({
    // §4au: kimlik anahtarları artık HESAP KAPSAMLI. Kapsamsız ad
    // yazmak, `getMyIdentityPublicKey()` boş dönmesine ve güvenlik
    // numarasının hiç üretilememesine yol açar.
    'e2ee_identity_pub_$uid': myIdentity,
    _sessionKey(uid, chatId): jsonEncode(state.toJson()),
  });
  E2EESessionService.setActiveAccount(uid);
  KeyManagementService.setActiveAccount(uid);
}

Future<SessionState> _readSession(String uid, String chatId) async {
  final raw = await SecureStore.read(_sessionKey(uid, chatId));
  return SessionState.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw!) as Map));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionState kalıcılığı', () {
    test('yeni alanlar gidiş-dönüş korunur', () {
      final st = _session(
        peer: 'PEER',
        verified: true,
        userVerified: true,
        changedFrom: 'ESKI',
      );
      final back = SessionState.fromJson(Map<String, dynamic>.from(
          jsonDecode(jsonEncode(st.toJson())) as Map));

      expect(back.peerIdentityKey, 'PEER');
      expect(back.verified, isTrue);
      expect(back.userVerified, isTrue);
      expect(back.changedFrom, 'ESKI');
      expect(back.sendCounter, st.sendCounter);
      expect(back.skipped, st.skipped);
    });

    test('ESKİ kayıt (uv/cf alanları yok) doğrulanmamış sayılır', () {
      // Bu sürümden ÖNCE kaydedilmiş oturumlar diskte duruyor. Eksik
      // alanın "doğrulandı" varsayılması, kullanıcıya hiç yapmadığı bir
      // doğrulamayı göstermek olurdu.
      final legacy = {
        'sck': base64.encode(List<int>.filled(32, 1)),
        'rck': base64.encode(List<int>.filled(32, 2)),
        'sc': 5,
        'rc': 6,
        'skp': <String, String>{},
        'pik': 'PEER',
        'ver': true,
      };
      final st = SessionState.fromJson(legacy);

      expect(st.userVerified, isFalse);
      expect(st.changedFrom, isNull);
      expect(st.verified, isTrue, reason: 'imza alanı bozulmamalı');
      expect(st.sendCounter, 5);
    });

    test('clearChangedFrom yalnızca uyarıyı siler, gerisine dokunmaz', () {
      final st = _session(
        peer: 'PEER',
        verified: true,
        userVerified: true,
        changedFrom: 'ESKI',
      );
      final cleared = st.clearChangedFrom();

      expect(cleared.changedFrom, isNull);
      expect(cleared.userVerified, isTrue);
      expect(cleared.verified, isTrue);
      expect(cleared.peerIdentityKey, 'PEER');
      expect(cleared.sendCounter, st.sendCounter);
      expect(cleared.receivingChainKey, st.receivingChainKey);
    });
  });

  group('güvenlik numarası', () {
    test('İKİ TARAFTA AYNI çıkar', () async {
      // Numaranın tek işe yarar özelliği bu: iki cihaz aynı numarayı
      // göstermezse karşılaştırma anlamsızdır.
      await _seed(
          uid: 'alice',
          chatId: 'c1',
          myIdentity: 'KEY_A',
          state: _session(peer: 'KEY_B'));
      final fromAlice = await E2EESessionService.safetyNumber('c1');

      await _seed(
          uid: 'bob',
          chatId: 'c1',
          myIdentity: 'KEY_B',
          state: _session(peer: 'KEY_A'));
      final fromBob = await E2EESessionService.safetyNumber('c1');

      expect(fromAlice, isNotNull);
      expect(fromAlice, fromBob);
    });

    test('biçim: 5’li altı grup, 30 hane', () async {
      await _seed(
          uid: 'alice',
          chatId: 'c1',
          myIdentity: 'KEY_A',
          state: _session(peer: 'KEY_B'));
      final n = await E2EESessionService.safetyNumber('c1');

      expect(n, isNotNull);
      expect(RegExp(r'^\d{5}( \d{5}){5}$').hasMatch(n!), isTrue,
          reason: 'beklenen biçim "12345 67890 ..." — gelen: $n');
      expect(n.replaceAll(' ', '').length, 30);
    });

    test('farklı karşı taraf farklı numara üretir', () async {
      await _seed(
          uid: 'alice',
          chatId: 'c1',
          myIdentity: 'KEY_A',
          state: _session(peer: 'KEY_B'));
      final withB = await E2EESessionService.safetyNumber('c1');

      await _seed(
          uid: 'alice',
          chatId: 'c1',
          myIdentity: 'KEY_A',
          state: _session(peer: 'ARAYA_GIREN'));
      final withAttacker = await E2EESessionService.safetyNumber('c1');

      expect(withB, isNot(withAttacker));
    });

    test('oturum yoksa numara yoktur', () async {
      FlutterSecureStorage.setMockInitialValues({
        'e2ee_identity_pub_alice': 'KEY_A', // §4au: hesap kapsamlı
      });
      E2EESessionService.setActiveAccount('alice');
      KeyManagementService.setActiveAccount('alice');

      expect(await E2EESessionService.safetyNumber('yok'), isNull);

      final info = await E2EESessionService.safetyInfo('yok');
      expect(info.hasSession, isFalse);
      expect(info.userVerified, isFalse);
      expect(info.identityChanged, isFalse);
    });
  });

  group('kullanıcı doğrulaması', () {
    test('işaretleme kalıcıdır', () async {
      await _seed(
          uid: 'alice',
          chatId: 'c1',
          myIdentity: 'KEY_A',
          state: _session(peer: 'KEY_B'));

      expect((await E2EESessionService.safetyInfo('c1')).userVerified, isFalse);
      expect(await E2EESessionService.setUserVerified('c1', true), isTrue);

      final info = await E2EESessionService.safetyInfo('c1');
      expect(info.userVerified, isTrue);
      expect(info.hasSession, isTrue);

      // Geri alınabilir olmalı.
      await E2EESessionService.setUserVerified('c1', false);
      expect((await E2EESessionService.safetyInfo('c1')).userVerified, isFalse);
    });

    test('oturum yokken işaretleme sessizce başarılı SAYILMAZ', () async {
      FlutterSecureStorage.setMockInitialValues({
        'e2ee_identity_pub_alice': 'KEY_A', // §4au: hesap kapsamlı
      });
      E2EESessionService.setActiveAccount('alice');
      KeyManagementService.setActiveAccount('alice');

      expect(await E2EESessionService.setUserVerified('yok', true), isFalse);
    });

    test('imza doğrulaması KULLANICI doğrulaması sayılmaz', () async {
      // Araya giren taraf kendi anahtar çiftiyle kendi geçerli imzasını
      // üretebilir; imza tek başına MITM güvencesi DEĞİLDİR. İki alan
      // birbirine karışırsa kullanıcıya yalan bir "doğrulandı" gösterilir.
      await _seed(
          uid: 'alice',
          chatId: 'c1',
          myIdentity: 'KEY_A',
          state: _session(peer: 'KEY_B', verified: true));

      final info = await E2EESessionService.safetyInfo('c1');
      expect(info.signatureVerified, isTrue);
      expect(info.userVerified, isFalse);
    });
  });

  group('kimlik anahtarı değişimi', () {
    test('uyarı kapatılınca doğrulama GERİ GELMEZ', () async {
      await _seed(
          uid: 'alice',
          chatId: 'c1',
          myIdentity: 'KEY_A',
          state: _session(peer: 'YENI', changedFrom: 'ESKI'));

      var info = await E2EESessionService.safetyInfo('c1');
      expect(info.identityChanged, isTrue);
      expect(info.previousIdentityKey, 'ESKI');

      await E2EESessionService.acknowledgeIdentityChange('c1');

      info = await E2EESessionService.safetyInfo('c1');
      expect(info.identityChanged, isFalse);
      expect(info.userVerified, isFalse,
          reason: 'uyarıyı kapatmak yeniden karşılaştırma yerine geçmez');
    });

    test('AYNI kimlik anahtarında oturuma DOKUNULMAZ', () async {
      // En pahalı hata burada olurdu: gereksiz yere yeniden kurmak
      // ratchet zincirini sıfırlar ve o sohbetteki mesajları çözülemez
      // hâle getirirdi.
      await _seed(
        uid: 'alice',
        chatId: 'c1',
        myIdentity: 'KEY_A',
        state: _session(
            peer: 'KEY_B', userVerified: true, verified: true, sendCounter: 9),
      );

      final changed = await E2EESessionService.ensureSessionFromHeader(
        chatId: 'c1',
        header: E2EEInitHeader(identityKey: 'KEY_B', ephemeralKey: 'EPH'),
      );

      expect(changed, isFalse);

      final st = await _readSession('alice', 'c1');
      expect(st.sendCounter, 9, reason: 'zincir ilerlememeli');
      expect(st.userVerified, isTrue, reason: 'doğrulama düşmemeli');
      expect(st.peerIdentityKey, 'KEY_B');
      expect(st.changedFrom, isNull);
    });
  });
}
