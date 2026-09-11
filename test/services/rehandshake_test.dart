import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/security/secure_store.dart';
import 'package:gizli_chat/services/e2ee_session_service.dart';

/// YENİDEN EL SIKIŞMANIN tanınması (§4ax).
///
/// 🐞 GERÇEK KULLANICIDA ÖLÇÜLDÜ: kimliğini KORUYAN hesap
/// (§4au'da eski anahtarları devralan) karşı taraftan mesaj ALAMIYORDU;
/// kimliği DEĞİŞEN hesap sorunsuz çalışıyordu.
///
/// Sebep: `ensureSessionFromHeader` oturumu yalnızca karşı tarafın
/// KİMLİK anahtarı değişince yeniliyordu. Karşı taraf oturumu yeniden
/// kurduğunda kimlik AYNI kalır, değişen EFEMERAL anahtardır — bu ayırt
/// edilemediği için yeniden el sıkışma sessizce yok sayılıyor ve sohbet
/// ölü kalıyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'ben';
  const chatId = 'sohbet1';
  String anahtar(String c) => 'e2ee_session_${uid}_$c';

  SessionState oturum({String? kimlik, String? efemeral}) => SessionState(
        sendingChainKey: const [1, 2, 3],
        receivingChainKey: const [4, 5, 6],
        sendCounter: 0,
        recvCounter: 0,
        skipped: const {},
        peerIdentityKey: kimlik,
        peerEphemeralKey: efemeral,
      );

  E2EEInitHeader baslik({required String kimlik, required String efemeral}) =>
      E2EEInitHeader(identityKey: kimlik, ephemeralKey: efemeral);

  Future<void> kur(SessionState s) async {
    FlutterSecureStorage.setMockInitialValues({
      anahtar(chatId): jsonEncode(s.toJson()),
    });
    E2EESessionService.setActiveAccount(uid);
  }

  Future<SessionState?> oku() async {
    final raw = await SecureStore.read(anahtar(chatId));
    if (raw == null) return null;
    return SessionState.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  group('efemeral anahtar kalıcı', () {
    test('toJson/fromJson efemerali TAŞIR', () {
      final s = oturum(kimlik: 'KIMLIK_A', efemeral: 'EF_1');
      final geri = SessionState.fromJson(s.toJson());
      expect(geri.peerEphemeralKey, 'EF_1');
      expect(geri.peerIdentityKey, 'KIMLIK_A');
    });

    test('ESKİ kayıtlarda efemeral yoktur (null) ve bozulmaz', () {
      final eski = SessionState.fromJson({
        'sck': base64.encode(const [1]),
        'rck': base64.encode(const [2]),
        'sc': 0,
        'rc': 0,
        'skp': <String, String>{},
        'pik': 'KIMLIK_A',
      });
      expect(eski.peerEphemeralKey, isNull);
      expect(eski.peerIdentityKey, 'KIMLIK_A');
    });

    test('copyWith efemerali korur', () {
      final s = oturum(kimlik: 'KIMLIK_A', efemeral: 'EF_1');
      expect(s.copyWith(sendCounter: 5).peerEphemeralKey, 'EF_1');
    });
  });

  group('oturum yenileme kararı', () {
    test('🔴 AYNI kimlik + YENİ efemeral → YENİDEN KURULUR', () async {
      // Karşı taraf kendi oturumunu sıfırlayıp yeni X3DH başlattı.
      // Kimliği değişmedi; eskiden bu durum sessizce yok sayılıyordu.
      await kur(oturum(kimlik: 'KIMLIK_A', efemeral: 'EF_ESKI'));

      // Yeniden kurma X3DH gerektirir; testte gerçek kimlik anahtarı yok.
      // Ölçtüğümüz şey HANGİ DALIN seçildiği: erken dönmek yerine yeniden
      // kurmaya gidildiğinin kanıtı, krypto katmanına ulaşılmasıdır.
      await expectLater(
        E2EESessionService.ensureSessionFromHeader(
          chatId: chatId,
          header: baslik(kimlik: 'KIMLIK_A', efemeral: 'EF_YENI'),
        ),
        throwsA(isA<StateError>()),
        reason: 'erken dönseydi hiç fırlatmazdı — yeniden el sıkışma '
            'tanınmazsa sohbet kalıcı olarak ölür',
      );
    });

    test('AYNI kimlik + AYNI efemeral → DOKUNULMAZ', () async {
      // Zinciri sıfırlamak, yolda olan mesajları çözülemez yapardı.
      await kur(oturum(kimlik: 'KIMLIK_A', efemeral: 'EF_1'));

      await E2EESessionService.ensureSessionFromHeader(
        chatId: chatId,
        header: baslik(kimlik: 'KIMLIK_A', efemeral: 'EF_1'),
      );

      final sonra = await oku();
      expect(sonra?.sendingChainKey, const [1, 2, 3],
          reason: 'çalışan oturum yeniden kurulmamalı');
      expect(sonra?.recvCounter, 0);
    });

    test('ESKİ oturum (efemeral null) → davranış DEĞİŞMEZ', () async {
      // Sahadaki eski kayıtlarda efemeral yok; yalnızca kimlik denetimi
      // çalışmalı, aksi hâlde her başlıkta zincir sıfırlanırdı.
      await kur(oturum(kimlik: 'KIMLIK_A'));

      await E2EESessionService.ensureSessionFromHeader(
        chatId: chatId,
        header: baslik(kimlik: 'KIMLIK_A', efemeral: 'EF_YENI'),
      );

      final sonra = await oku();
      expect(sonra?.sendingChainKey, const [1, 2, 3],
          reason: 'efemeral bilinmiyorsa yeniden kurma kararı verilemez');
    });
  });
}
