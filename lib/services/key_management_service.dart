import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'auth_service.dart';
import 'x3dh_service.dart';
import 'double_ratchet_service.dart';
import '../core/security/secure_store.dart';
import '../core/observability/handled_error.dart';

/// E2EE anahtar yönetimi (X3DH için).
///
/// Anahtar türleri:
///  • Identity Key (IK)      — KALICI X25519 kimlik
///  • Signing Key            — KALICI Ed25519 (SPK'yı imzalar)
///  • Signed PreKey (SPK)    — periyodik X25519, IK ile imzalı
///  • One-Time PreKeys (OPK) — tek kullanımlık X25519'lar
///
/// Açık kısımlar sunucuya yüklenir; özel kısımlar YALNIZCA cihazda kalır.
class KeyManagementService {
  static final _db = FirebaseFirestore.instance;
  static final _x25519 = X25519();
  static final _ed25519 = Ed25519();

  // ─────────────────────────────────────────
  // HESAP KAPSAMI (§4au)
  // ─────────────────────────────────────────
  //
  // 🐞 ANAHTARLAR KAPSAMSIZDI ve bu, ÇOKLU HESABI KIRIYORDU.
  //
  // Oturumlar (`E2EESessionService`), grup anahtarları ve sohbet
  // kilitleri aktif uid ile kapsamlanmıştı; KİMLİK ANAHTARLARI
  // atlanmıştı. Sonucu ÜRETİM VERİSİNDE ölçüldü — aynı cihazdaki iki
  // hesabın `keyBundles` belgeleri:
  //
  //   bWCIo…  identityKey: 6oop6Hy9SNf…QlDc=   signing: pQQurDjTqwc…nSKM=
  //   qYbF…   identityKey: 6oop6Hy9SNf…QlDc=   signing: pQQurDjTqwc…nSKM=
  //                       ^^^^^^^^^^^^ BİREBİR AYNI
  //
  // İKİ AYRI ARIZA:
  //
  // 1. MESAJ ÇÖZÜLEMİYOR. Her hesap KENDİ imzalı ön-anahtarını yayımlar
  //    (`spk_hm5zb5cfo4` / `spk_hm5zc5o9td` — farklı), ama özel yarısı
  //    TEK bir yere yazılır. Sonra yayımlayan öncekini EZER. Karşı taraf
  //    A ön-anahtarıyla şifreler, cihazda artık B'nin özeli vardır →
  //    "bu mesaj cihazda çözülemiyor".
  //
  // 2. HESAPLAR BİRBİRİNE BAĞLANABİLİR. `keyBundles` giriş yapmış
  //    herkese açıktır; aynı kimlik anahtarı, "bu iki hesap aynı kişi"
  //    demektir. Çoklu hesap özelliğinin var oluş sebebini yok eder.
  //    (Kod TURN kimliği için bu riski düşünmüştü, E2EE kimliği için
  //    düşünmemişti — bkz. `switchAccount` içindeki yorum.)
  static String _accountScope = '_';

  /// Aktif hesabı ayarla. `main.dart` açılışta, `switchAccount` ve
  /// `register` hesap belli olur olmaz çağırır; `signOut` null'a düşürür.
  static void setActiveAccount(String? uid) {
    _accountScope = (uid == null || uid.isEmpty) ? '_' : uid;
  }

  /// Kapsamsız DÖNEMDEN kalan anahtarlar devralındı mı?
  /// (Aynı cihazda İKİNCİ bir hesabın da devralmasını engeller.)
  static const _legacyAdopted = 'e2ee_legacy_adopted';

  // Secure storage anahtarları — hepsi hesap kapsamlı.
  static String get _identityPrivKey => 'e2ee_identity_priv_$_accountScope';
  static String get _identityPubKey => 'e2ee_identity_pub_$_accountScope';
  static String get _signingPrivKey => 'e2ee_signing_priv_$_accountScope';
  static String get _signingPubKey => 'e2ee_signing_pub_$_accountScope';
  static String get _signedPreKeyPriv => 'e2ee_spk_priv_$_accountScope';
  static String get _signedPreKeyPub => 'e2ee_spk_pub_$_accountScope';

  /// Geçerli imzalı ön-anahtarın kimliği.
  static String get _signedPreKeyId => 'e2ee_spk_id_$_accountScope';

  /// ÖNCEKİ imzalı ön-anahtar (JSON: id/priv/pub).
  ///
  /// ⚠️ NEDEN SAKLANMAK ZORUNDA:
  /// `_republishPreKeys` SPK'yı yeniler ve eski ÖZEL anahtarı silerdi.
  /// Alice paketi aldıktan SONRA Bob tazelerse, Bob gelen ilk mesajı
  /// YENİ SPK ile karşılamaya çalışır; X3DH'in DH1/DH3 adımları
  /// tutmadığı için taraflar FARKLI ortak sır türetir. Hiçbir hata
  /// verilmez — o sohbetteki tüm mesajlar sessizce çözülemez olur.
  /// Bob günlerce çevrimdışı kalabildiği için pencere geniştir.
  static String get _signedPreKeyPrev => 'e2ee_spk_prev_$_accountScope';
  static String get _oneTimePreKeysPriv =>
      'e2ee_opk_priv_$_accountScope'; // JSON map

  /// Sunucuya yüklenen tek kullanımlık ön-anahtar sayısı.
  static const int _opkCount = 100;

  /// Bu eşiğin altına düşünce ön-anahtarlar tazelenir.
  static const int _opkRefillThreshold = 10;

  // ─────────────────────────────────────────
  // ANAHTAR ÜRETİMİ
  // ─────────────────────────────────────────

  /// TÜM anahtarları sıfırdan üret ve yayınla.
  ///
  /// ⚠️ Bu, KİMLİK ANAHTARINI DA değiştirir → mevcut tüm oturumlar kırılır.
  /// Yalnızca ilk kurulumda veya kimlik gerçekten kayıpken çağırın.
  /// Ön-anahtar doldurmak için [_republishPreKeys] kullanın.
  static Future<void> generateAndUploadKeys() async {
    final uid = AuthService.currentUid;
    if (uid == null) {
      throw StateError('E2EE anahtarları için oturum gerekli');
    }

    // ── PERFORMANS ──
    // 100+ X25519 anahtar üretimi ana isolate'te yapılınca kayıt ekranı
    // gözle görülür şekilde donuyordu. Ağır üretim arka plana alınır.
    final g = await compute(_generateKeyMaterial, _opkCount);

    await SecureStore.writeOrThrow(
        key: _identityPrivKey, value: g['identityPriv'] as String);
    await SecureStore.writeOrThrow(
        key: _identityPubKey, value: g['identityPub'] as String);
    await SecureStore.writeOrThrow(
        key: _signingPrivKey, value: g['signingPriv'] as String);
    await SecureStore.writeOrThrow(
        key: _signingPubKey, value: g['signingPub'] as String);
    await SecureStore.writeOrThrow(
        key: _signedPreKeyPriv, value: g['spkPriv'] as String);
    await SecureStore.writeOrThrow(
        key: _signedPreKeyPub, value: g['spkPub'] as String);
    await SecureStore.writeOrThrow(
        key: _signedPreKeyId, value: g['spkId'] as String);
    await SecureStore.writeOrThrow(
        key: _oneTimePreKeysPriv, value: jsonEncode(g['opkPrivMap']));
    // Yeni kimlik = yeni hesap; saklanacak eski SPK yok.
    await SecureStore.delete(_signedPreKeyPrev);

    await _publishBundle(uid, _asPublicList(g['opkPublicList']));
  }

  /// Isolate'ten gelen listeyi tip güvenli hâle getir.
  static List<Map<String, String>> _asPublicList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v.toString())))
        .toList();
  }

  /// Yalnızca ön-anahtarları tazele — KİMLİK ANAHTARINA DOKUNMAZ.
  ///
  /// ⚠️ Eski kod, ön-anahtarlar tükendiğinde `generateAndUploadKeys()`
  /// çağırıyordu; bu kimlik anahtarını da yeniliyor ve kullanıcının TÜM
  /// mevcut oturumlarını (yani tüm sohbetlerinin okunabilirliğini) yok
  /// ediyordu. ~100 oturumdan sonra kaçınılmaz olarak tetikleniyordu.
  static Future<void> _republishPreKeys() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;

    final g = await compute(_generatePreKeysOnly, _opkCount);

    // ── ÖNCEKİ SPK'YI SAKLA (üzerine yazmadan ÖNCE) ──
    // Yolda olan bir X3DH başlığı hâlâ eski SPK'ya işaret ediyor olabilir.
    final oldPriv = await SecureStore.read(_signedPreKeyPriv);
    final oldPub = await SecureStore.read(_signedPreKeyPub);
    final oldId = await SecureStore.read(_signedPreKeyId);
    if (oldPriv != null && oldPub != null) {
      await SecureStore.writeOrThrow(
        key: _signedPreKeyPrev,
        value: jsonEncode({
          // Kimliksiz eski kurulumlar için sabit bir etiket: gelen
          // başlıkta kimlik yoksa da bu anahtar denenebilsin.
          'id': oldId ?? _legacySpkId,
          'priv': oldPriv,
          'pub': oldPub,
        }),
      );
    }

    await SecureStore.writeOrThrow(
        key: _signedPreKeyPriv, value: g['spkPriv'] as String);
    await SecureStore.writeOrThrow(
        key: _signedPreKeyPub, value: g['spkPub'] as String);
    await SecureStore.writeOrThrow(
        key: _signedPreKeyId, value: g['spkId'] as String);
    await SecureStore.writeOrThrow(
        key: _oneTimePreKeysPriv, value: jsonEncode(g['opkPrivMap']));

    await _publishBundle(uid, _asPublicList(g['opkPublicList']));
  }

  /// Açık anahtar paketini imzalayıp Firestore'a yaz.
  static Future<void> _publishBundle(
      String uid, List<Map<String, String>> opkPublicList) async {
    final identityPub = await SecureStore.readOrThrow(key: _identityPubKey);
    final spkPub = await SecureStore.readOrThrow(key: _signedPreKeyPub);
    final signingPub = await SecureStore.readOrThrow(key: _signingPubKey);
    if (identityPub == null || spkPub == null || signingPub == null) {
      throw StateError('Anahtar paketi yayınlanamadı: yerel anahtar eksik');
    }

    // İmzalı ön-anahtarı GERÇEKTEN imzala. Bu olmadan alan adı yalan
    // oluyordu ve karşı taraf hiçbir doğrulama yapamıyordu (MITM riski).
    final signingKeyPair = await getSigningKeyPair();
    final signature = await X3DHService.signPreKey(
      signedPreKeyPublicBytes: base64.decode(spkPub),
      signingKeyPair: signingKeyPair,
    );

    await _db.collection('keyBundles').doc(uid).set({
      'identityKey': identityPub,
      'signingPublicKey': signingPub,
      'signedPreKey': spkPub,
      'signedPreKeyId': await SecureStore.read(_signedPreKeyId) ?? _legacySpkId,
      // ── RATCHET SÜRÜM ANLAŞMASI ──
      // Karşı taraf buna bakıp bizimle v3 (DH ratchet) oturum kurup
      // kuramayacağına karar verir. Eski bir istemciye v3 paket
      // göndermek, onun zincir türetmesiyle uyuşmadığı için o sohbeti
      // TAMAMEN kırardı. Alan yoksa v2 varsayılır.
      'ratchetVersion': DoubleRatchetService.currentVersion,
      'signedPreKeySignature': signature,
      'oneTimePreKeys': opkPublicList,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// E2EE anahtarları kurulu mu?
  static Future<bool> hasKeys() async =>
      await SecureStore.read(_identityPrivKey) != null;

  // ─────────────────────────────────────────
  // ÖZEL ANAHTAR ERİŞİMİ (yalnızca cihazda)
  // ─────────────────────────────────────────

  static Future<SimpleKeyPair> getIdentityKeyPair() async {
    final privB64 = await SecureStore.readOrThrow(key: _identityPrivKey);
    if (privB64 == null) {
      throw StateError('Kimlik anahtarı bulunamadı');
    }
    return _x25519.newKeyPairFromSeed(base64.decode(privB64));
  }

  static Future<SimpleKeyPair> getSigningKeyPair() async {
    final privB64 = await SecureStore.readOrThrow(key: _signingPrivKey);
    if (privB64 == null) {
      throw StateError('İmzalama anahtarı bulunamadı');
    }
    return _ed25519.newKeyPairFromSeed(base64.decode(privB64));
  }

  /// Kimliksiz (bu sürümden önce üretilmiş) SPK etiketi.
  static const String _legacySpkId = 'spk_legacy';

  /// Gelen X3DH başlığının işaret ettiği imzalı ön-anahtar çiftini seç.
  ///
  /// [wantedId] null ise (eski istemci) geçerli anahtar kullanılır — bu
  /// durumda rotasyon olmuşsa uyuşmazlık hâlâ mümkündür ve önlenemez;
  /// gönderen hangi anahtarı kullandığını söylemiyor.
  ///
  /// Kimlik verilmiş ama hiçbir anahtarla eşleşmiyorsa SESSİZCE devam
  /// EDİLMEZ: farklı bir sırla kurulmuş oturum, kullanıcıya hata bile
  /// göstermeden sohbeti kalıcı olarak kırardı.
  static Future<SimpleKeyPair> getSignedPreKeyPairById(String? wantedId) async {
    final currentId = await SecureStore.read(_signedPreKeyId) ?? _legacySpkId;
    if (wantedId == null || wantedId == currentId) {
      return getSignedPreKeyPair();
    }

    final rawPrev = await SecureStore.read(_signedPreKeyPrev);
    if (rawPrev != null) {
      try {
        final prev = Map<String, dynamic>.from(jsonDecode(rawPrev) as Map);
        if (prev['id'] == wantedId) {
          debugPrint('E2EE: ÖNCEKİ imzalı ön-anahtar kullanılıyor ($wantedId)');
          return _x25519
              .newKeyPairFromSeed(base64.decode(prev['priv'] as String));
        }
      } catch (e) {
        debugPrint('Önceki SPK okunamadı: $e');
      }
    }

    throw X3DHException(
      'err_e2ee_prekey_missing',
      'İmzalı ön-anahtar bulunamadı ($wantedId); oturum kurulamaz.',
    );
  }

  /// Yayınlanmış paketteki SPK kimliği (başlıkta taşınır).
  static Future<String> currentSignedPreKeyId() async =>
      await SecureStore.read(_signedPreKeyId) ?? _legacySpkId;

  static Future<SimpleKeyPair> getSignedPreKeyPair() async {
    final privB64 = await SecureStore.readOrThrow(key: _signedPreKeyPriv);
    if (privB64 == null) {
      throw StateError('İmzalı ön-anahtar bulunamadı');
    }
    return _x25519.newKeyPairFromSeed(base64.decode(privB64));
  }

  /// Bir ön-anahtarın özel kısmını al ve kullandıktan sonra sil.
  static Future<SimpleKeyPair?> consumeOneTimePreKey(String keyId) async {
    final mapJson = await SecureStore.readOrThrow(key: _oneTimePreKeysPriv);
    if (mapJson == null) return null;

    final map = Map<String, String>.from(jsonDecode(mapJson) as Map);
    final privB64 = map[keyId];
    if (privB64 == null) return null;

    map.remove(keyId);
    await SecureStore.writeOrThrow(
        key: _oneTimePreKeysPriv, value: jsonEncode(map));

    return _x25519.newKeyPairFromSeed(base64.decode(privB64));
  }

  // ─────────────────────────────────────────
  // PAKET YAYIN GARANTİSİ
  // ─────────────────────────────────────────

  /// KAPSAMSIZ DÖNEMDEN kalan anahtarları AKTİF hesaba devret (§4au).
  ///
  /// Kapsamlama olmadan önce anahtarlar `e2ee_identity_priv` gibi düz
  /// adlarla duruyordu. Kapsamlı adlara geçerken hiçbir şey yapmazsak
  /// MEVCUT HERKESİN kimliği "kayıp" sayılır, yeniden üretilir ve
  /// ÇALIŞAN tüm oturumlar kırılır — tek hesaplı kullanıcılar dahil.
  /// Oysa onların bir sorunu yok.
  ///
  /// Bu yüzden eski anahtarlar, güncellemeden sonra ÇALIŞAN İLK HESABA
  /// devredilir:
  ///   • Tek hesaplı kullanıcı (çoğunluk) → hiçbir şey değişmez.
  ///   • Çoklu hesaplı cihaz → biri devralır, DİĞERİ yeni kimlik üretip
  ///     paketini yeniden yayımlar. Aranan davranış budur; hatanın
  ///     kaynağı zaten ikisinin aynı anahtarı paylaşmasıydı.
  ///
  /// ⚠️ DEVRALMA TEK SEFERLİKTİR: eski kayıtlar devirden sonra SİLİNİR.
  /// Silinmezse ikinci hesap da aynı anahtarları devralır ve hata
  /// olduğu gibi geri gelir.
  @visibleForTesting
  static Future<void> adoptLegacyKeysIfAny() async {
    // Bu hesabın kimliği zaten varsa devralmaya gerek yok.
    if (await SecureStore.read(_identityPrivKey) != null) return;
    // Eski kayıtlar başka bir hesap tarafından devralınmış olabilir.
    if (await SecureStore.read(_legacyAdopted) != null) return;

    const eskiler = <String>[
      'e2ee_identity_priv',
      'e2ee_identity_pub',
      'e2ee_signing_priv',
      'e2ee_signing_pub',
      'e2ee_spk_priv',
      'e2ee_spk_pub',
      'e2ee_spk_id',
      'e2ee_spk_prev',
      'e2ee_opk_priv',
    ];

    final eskiKimlik = await SecureStore.read('e2ee_identity_priv');
    if (eskiKimlik == null) return; // devralınacak bir şey yok

    for (final eski in eskiler) {
      final deger = await SecureStore.read(eski);
      if (deger == null) continue;
      final yeni = '${eski}_$_accountScope';
      if (!await SecureStore.write(yeni, deger)) {
        // Yazamadıysak DEVRALMAYI YARIDA BIRAKMA: yarım devir, kimliği
        // olan ama imzalı ön-anahtarı olmayan bir hesap bırakır.
        reportHandled('Eski E2EE anahtarı devralınamadı',
            StateError('legacy_adopt_failed: $eski'));
        return;
      }
    }

    // Devir tamam → eskileri sil ki İKİNCİ hesap devralmasın.
    await SecureStore.write(_legacyAdopted, _accountScope);
    for (final eski in eskiler) {
      await SecureStore.delete(eski);
    }
    debugPrint('E2EE: kapsamsız anahtarlar $_accountScope hesabına devredildi');
  }

  /// Her açılışta çağrılır: paket yok/eskimişse yeniden yayınlanır.
  static Future<void> ensureKeysPublished() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    // Kapsam bu noktada kurulmuş olmalı; olmadıysa hesapla eşitle.
    if (_accountScope != uid) setActiveAccount(uid);
    await adoptLegacyKeysIfAny();
    try {
      final doc = await _db
          .collection('keyBundles')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      final myIdentity = await getMyIdentityPublicKey();
      final data = doc.data();
      final serverIdentity = data?['identityKey'] as String?;

      // Yerel kimlik anahtarı YOKSA gerçekten sıfırdan üretmek gerekir.
      if (myIdentity.isEmpty) {
        debugPrint('E2EE: yerel kimlik yok — anahtarlar üretiliyor');
        await generateAndUploadKeys();
        return;
      }

      // 🐞 İMZALI ÖN-ANAHTAR UYUMU DA DENETLENMELİ (§4au).
      //
      // Eskiden yalnızca KİMLİK karşılaştırılıyordu. Ama bozulmanın
      // kaynağı kimlik değil, İMZALI ÖN-ANAHTARDI: `e2ee_spk_priv`
      // kapsamsız olduğu için aynı cihazdaki diğer hesap tarafından
      // EZİLİYORDU. Kimlik aynı kaldığı için bu denetim "her şey yolunda"
      // diyor, oysa sunucudaki AÇIK ön-anahtarın ÖZEL yarısı cihazda
      // artık yok. Karşı taraf o ön-anahtarla şifreliyor, biz
      // çözemiyoruz — sessizce.
      //
      // Kapsamlama bunu ileriye dönük engelliyor; bu denetim ise
      // ZATEN BOZULMUŞ cihazları KENDİ KENDİNE ONARIR: uyuşmazlık
      // görülünce paket kimlik korunarak yeniden yayımlanır.
      final localSpkPub = await SecureStore.read(_signedPreKeyPub);
      final serverSpkPub = data?['signedPreKey'] as String?;
      final spkUyusmuyor = localSpkPub == null ||
          serverSpkPub == null ||
          localSpkPub != serverSpkPub;

      // Sunucudaki paket yok ya da BU cihazın kimliğiyle uyuşmuyor:
      // kimliği DEĞİŞTİRMEDEN paketi yeniden yayınla.
      if (!doc.exists ||
          serverIdentity == null ||
          serverIdentity != myIdentity ||
          data?['signedPreKeySignature'] == null ||
          spkUyusmuyor) {
        debugPrint('E2EE: anahtar paketi yeniden yayınlanıyor'
            '${spkUyusmuyor ? " (imzalı ön-anahtar uyuşmuyor)" : ""}');
        await _republishPreKeys();
        return;
      }

      // Ön-anahtarlar azaldıysa DOLDUR (kimliği koruyarak).
      final opks = (data?['oneTimePreKeys'] as List?) ?? const [];
      if (opks.length <= _opkRefillThreshold) {
        debugPrint('E2EE: ön-anahtarlar azaldı (${opks.length}) — tazeleniyor');
        await _republishPreKeys();
      }
    } catch (e, s) {
      // ⚠️ Bu başarısızsa karşı taraf bu hesaba E2EE oturumu KURAMAZ.
      reportHandled('Anahtar paketi kontrolü başarısız', e, stack: s);
    }
  }

  /// Karşı tarafın paketini al ve bir ön-anahtar TÜKET.
  ///
  /// ⚠️ Tüketim artık SUNUCUDA yapılır. Eski kod, karşı tarafın
  /// `keyBundles/{uid}` dokümanını istemciden güncellemeye çalışıyordu;
  /// güvenlik kuralı bunu reddettiği için (yalnızca sahibi yazabilir)
  /// çağrı PERMISSION_DENIED ile patlıyor ve E2EE oturumu HİÇ kurulamıyordu.
  /// Ayrıca iki istemci aynı anda aynı ön-anahtarı alıp "tek kullanımlık"
  /// garantisini bozuyordu — transaction ikisini de çözer.
  static Future<PreKeyBundle?> fetchPreKeyBundle(String userId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('claimPreKey');
      final res = await callable.call<Map<String, dynamic>?>(
          {'userId': userId}).timeout(const Duration(seconds: 15));

      final data = res.data;
      if (data == null) return null;

      final identityKey = data['identityKey'] as String?;
      final signedPreKey = data['signedPreKey'] as String?;
      if (identityKey == null || signedPreKey == null) return null;

      return PreKeyBundle(
        identityKey: identityKey,
        signedPreKey: signedPreKey,
        signedPreKeyId: data['signedPreKeyId'] as String?,
        ratchetVersion: (data['ratchetVersion'] as num?)?.toInt() ?? 2,
        signedPreKeySignature: data['signedPreKeySignature'] as String?,
        signingPublicKey: data['signingPublicKey'] as String?,
        oneTimePreKeyId: data['oneTimePreKeyId'] as String?,
        oneTimePreKey: data['oneTimePreKey'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Ön-anahtar alınamadı (${e.code}): ${e.message}');
      return null;
    } on FirebaseException catch (e) {
      debugPrint('Ön-anahtar alınamadı: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Ön-anahtar alınamadı: $e');
      return null;
    }
  }

  static Future<String> getMyIdentityPublicKey() async =>
      (await SecureStore.read(_identityPubKey)) ?? '';

  /// Cihazdaki tüm E2EE anahtarlarını sil (çıkış / hesap silme).
  static Future<void> wipeLocalKeys() async {
    for (final k in [
      _identityPrivKey,
      _identityPubKey,
      _signingPrivKey,
      _signingPubKey,
      _signedPreKeyPriv,
      _signedPreKeyPub,
      _signedPreKeyId,
      _signedPreKeyPrev,
      _oneTimePreKeysPriv,
    ]) {
      await SecureStore.delete(k);
    }
  }
}

// ─────────────────────────────────────────
// ARKA PLAN ÜRETİMİ (isolate)
//
// NOT: Isolate sınırından YALNIZCA basit tipler (String/Map/List) geçirilir.
// Özel sınıflar teknik olarak kopyalanabilse de, basit tipler her Dart
// sürümünde garanti sendable'dır ve platformlar arası sürprizi olmaz.
// ─────────────────────────────────────────

/// Isolate girişi: kimlik + imzalama + ön-anahtarlar.
Future<Map<String, dynamic>> _generateKeyMaterial(int opkCount) async {
  final x25519 = X25519();
  final ed25519 = Ed25519();

  final identity = await x25519.newKeyPair();
  final identityPub = await identity.extractPublicKey();
  final identityPriv = await identity.extractPrivateKeyBytes();

  final signing = await ed25519.newKeyPair();
  final signingPub = await signing.extractPublicKey();
  final signingPriv = await signing.extractPrivateKeyBytes();

  final pre = await _generatePreKeysOnly(opkCount);

  return <String, dynamic>{
    'identityPriv': base64.encode(identityPriv),
    'identityPub': base64.encode(identityPub.bytes),
    'signingPriv': base64.encode(signingPriv),
    'signingPub': base64.encode(signingPub.bytes),
    ...pre,
  };
}

/// Isolate girişi: yalnızca SPK + tek kullanımlık ön-anahtarlar.
Future<Map<String, dynamic>> _generatePreKeysOnly(int opkCount) async {
  final x25519 = X25519();

  final spk = await x25519.newKeyPair();
  final spkPub = await spk.extractPublicKey();
  final spkPriv = await spk.extractPrivateKeyBytes();

  final opkPrivMap = <String, String>{};
  final opkPublicList = <Map<String, String>>[];
  // Anahtar kimlikleri ZAMAN DAMGALI: eski sabit 'opk_0..99' şeması,
  // tazeleme sonrası aynı kimlikleri yeniden kullanıyordu; yolda olan
  // eski bir mesaj yeni bir anahtarla eşleşip sessiz çözme hatasına
  // yol açabiliyordu.
  final batch = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  for (var i = 0; i < opkCount; i++) {
    final pair = await x25519.newKeyPair();
    final pub = await pair.extractPublicKey();
    final priv = await pair.extractPrivateKeyBytes();
    final keyId = 'opk_${batch}_$i';
    opkPrivMap[keyId] = base64.encode(priv);
    opkPublicList.add({'keyId': keyId, 'publicKey': base64.encode(pub.bytes)});
  }

  return <String, dynamic>{
    'spkPriv': base64.encode(spkPriv),
    'spkPub': base64.encode(spkPub.bytes),
    // Rotasyon sonrası hangi SPK'nın kastedildiğini ayırt etmek için.
    'spkId': 'spk_$batch',
    'opkPrivMap': opkPrivMap,
    'opkPublicList': opkPublicList,
  };
}

/// Karşı tarafın açık anahtar paketi
class PreKeyBundle {
  final String identityKey;

  /// Hangi imzalı ön-anahtarın kullanıldığı — karşı taraf rotasyon
  /// yapmış olsa bile doğru özel anahtarı seçebilsin diye taşınır.
  /// Eski paketlerde null'dur.
  final String? signedPreKeyId;

  /// Karşı tarafın istemcisinin desteklediği ratchet sürümü.
  /// Alan yoksa 2 (DH ratchet öncesi istemci).
  final int ratchetVersion;

  /// Karşı taraf DH ratchet'i (post-compromise security) destekliyor mu?
  bool get supportsDhRatchet => ratchetVersion >= 3;
  final String signedPreKey;

  /// SPK'nın Ed25519 imzası (eski paketlerde null olabilir).
  final String? signedPreKeySignature;

  /// İmzayı doğrulamak için kalıcı Ed25519 açık anahtarı.
  final String? signingPublicKey;

  final String? oneTimePreKeyId;
  final String? oneTimePreKey;

  PreKeyBundle({
    required this.identityKey,
    required this.signedPreKey,
    this.signedPreKeyId,
    this.ratchetVersion = 2,
    this.signedPreKeySignature,
    this.signingPublicKey,
    this.oneTimePreKeyId,
    this.oneTimePreKey,
  });

  /// İmza doğrulaması yapılabildi mi? (arayüzde "doğrulanmadı" uyarısı için)
  bool get isVerifiable =>
      signedPreKeySignature != null && signingPublicKey != null;
}
