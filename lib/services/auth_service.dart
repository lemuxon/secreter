import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/presence/presence.dart';
import '../core/security/chat_lock_service.dart';
import '../models/user_model.dart';
import '../core/media/secure_media_cache.dart';
import 'e2ee_session_service.dart';
import 'group_key_service.dart';
import 'encryption_service.dart';
import 'key_management_service.dart';
import 'turn_credentials_service.dart';
import 'chat_metadata_scrub.dart';
import 'username_resolver.dart';
import 'multi_account_service.dart';
import 'notification_service.dart';
import '../core/security/secure_store.dart';
import '../core/observability/handled_error.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _storage = SecureStore.instance;

  static const String _keyName = 'chat_encryption_key';
  static const String _uidName = 'chat_uid';
  static const String _pwName = 'chat_account_password';

  /// Mevcut kullanıcı
  static User? get currentUser => _auth.currentUser;
  static String? get currentUid => _auth.currentUser?.uid;

  /// AKTİF HESAP DEĞİŞİMLERİ — yalnızca uid, tip sızdırmadan.
  ///
  /// ⚠️ NEDEN GEREKLİ: `currentUser`, `Firebase.initializeApp()` hemen
  /// ardından HENÜZ NULL olabilir; kaydedilmiş oturum ASENKRON geri
  /// yüklenir. Açılışta kapsam bir kez `currentUid`'den kurulduğu için,
  /// o an null ise kapsam `'_'` olarak KALIYOR ve tüm uygulama çalışması
  /// boyunca yanlış anahtarlarla okuma/yazma yapılıyordu (§4bd).
  static Stream<String?> get activeUidChanges =>
      _auth.authStateChanges().map((u) => u?.uid);

  /// Şifreleme anahtarını güvenli depoya kaydet
  static Future<void> _saveEncryptionKey(String key) async {
    await _storage.write(key: _keyName, value: key);
  }

  /// Şifreleme anahtarını al
  static Future<String?> getEncryptionKey() async {
    return await _storage.read(key: _keyName);
  }

  /// Kullanıcı adı biçim kuralı — TEK KAYNAK.
  ///
  /// 🐞 Bu kural eskiden YALNIZCA `register()` içindeydi; kayıt ekranındaki
  /// canlı kontrol biçime hiç bakmıyordu. Sonuç: kullanıcı adını yazıyor,
  /// hiçbir uyarı görmüyor, "Kaydet"e basınca reddediliyordu.
  ///
  /// ⚠️ ASCII KISITI BİLİNÇLİDİR, gevşetilmemeli. Kullanıcı adı, kişilerin
  /// birbirini tanıdığı kimliktir; Türkçe "ı/i" ve "İ/I" gibi homograf
  /// çiftleri TAKLİT yüzeyi açar. Ayrıca dizin anahtarı `toLowerCase()` ile
  /// üretiliyor ve Türkçe i/I eşlemesi bu dönüşümde tuzaklıdır.
  ///
  /// Kullanıcıya gösterilen metin (`err_username_format`) hangi karakterlere
  /// izin verildiğini AÇIKÇA yazar: "(a-z, 0-9, _)". Yalnızca
  /// "harf/rakam" demek yetmiyordu — Türkçe konuşan biri ş/ğ/ı'yı da harf
  /// sayıyor ve neden reddedildiğini anlamıyordu.
  static bool isValidUsernameFormat(String username) =>
      RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username.trim());

  /// Giriş yoksa anonim oturum aç (varsa dokunma).
  static Future<void> _ensureAnonymousSession() async {
    if (_auth.currentUser != null) return;
    // Oturum açma HIZLI olmalı; takılırsa kayıt ekranı kilitlenir.
    await _auth.signInAnonymously().timeout(const Duration(seconds: 15));
  }

  /// Kullanıcı adının müsait olup olmadığını kontrol et
  static Future<bool> isUsernameAvailable(String username) async {
    // OTURUM GARANTİSİ: Firestore kuralları okuma için giriş şartı koyar.
    // Bu kontrol kayıt ekranında kullanıcı YAZARKEN (henüz giriş yoktur)
    // da çağrıldığı için, gerekirse burada anonim oturum açılır.
    // Kayıt tamamlanırsa bu oturum gerçek hesaba dönüşür; tamamlanmazsa
    // kimliksiz bir anonim oturum kalır (zararsız).
    await _ensureAnonymousSession();

    final uname = username.toLowerCase();
    // NOT: Burada eskiden `users` koleksiyonuna ada göre SORGU atılıyordu.
    // Numaralandırmayı kapatmak için o koleksiyonda listeleme kapatıldı;
    // zaten aynı kontrol aşağıdaki `usernames` dizini üzerinden ve DAHA
    // GÜVENİLİR yapılıyor (rezervasyonun tek doğruluk kaynağı odur).
    //
    // Yan kazanç: kayıt yarıda kalıp `users` dokümanı oluşmuş ama ad
    // rezerve edilememişse, kullanıcı aynı adla tekrar deneyebilir.

    // 14 GÜN KURALI: silinen hesabın kullanıcı adı 14 gün rezerve kalır.
    //
    // ⚠️ ESKİ HATA: süresi dolan rezervasyon İSTEMCİDEN silinmeye
    // çalışılıyordu. Güvenlik kuralı `releasedUsernames` silmeyi
    // reddettiği için çağrı PERMISSION_DENIED fırlatıyor ve süresi
    // DOLMUŞ bir adı almak isteyen kullanıcının KAYDI TAMAMEN
    // PATLIYORDU. Temizlik artık sunucuda (cleanupReleasedUsernames);
    // istemci yalnızca tarihi karşılaştırır.
    final reserved = await _db.collection('releasedUsernames').doc(uname).get();
    if (reserved.exists) {
      final releaseAt =
          DateTime.tryParse((reserved.data()?['releaseAt'] ?? '').toString());
      if (releaseAt != null && DateTime.now().toUtc().isBefore(releaseAt)) {
        return false; // hâlâ rezerve
      }
      // Süresi dolmuş: ad kullanılabilir. Kayıt SİLMEYE ÇALIŞMAZ.
    }

    // Ad dizininde başkasına ait bir kayıt var mı?
    final indexed = await _db.collection('usernames').doc(uname).get();
    if (indexed.exists) {
      final ownerUid = (indexed.data()?['uid'] ?? '').toString();
      if (ownerUid.isNotEmpty && ownerUid != _auth.currentUser?.uid) {
        return false;
      }
    }
    return true;
  }

  /// Kullanıcı adını ATOMİK olarak rezerve et.
  ///
  /// ⚠️ NEDEN GEREKLİ: Eski akış "sorgula → yaz → tekrar sorgula → kaybeden
  /// geri çekilsin" şeklindeydi. `limit(2)` kullandığı için ÜÇ kişi aynı anda
  /// denediğinde tespit edemiyordu ve `authUser.delete()`
  /// `requires-recent-login` ile patlayabildiği için ortada YİNELENEN
  /// kullanıcı adı kalabiliyordu. Artık yarış SUNUCUDA çözülür:
  /// `usernames/{ad}` dokümanı yalnızca YOKSA oluşturulabilir (güvenlik
  /// kuralı), yani ikinci yazan kaybeder ve temiz bir hata alır.
  static Future<bool> _reserveUsername(String uname, String uid) async {
    try {
      await _db.collection('usernames').doc(uname).set({
        'uid': uid,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'already-exists') {
        return false; // başkası önce aldı
      }
      rethrow;
    }
  }

  /// Yeni kullanıcı kaydı (anonim auth + kullanıcı adı)
  static Future<String?> register(String username) async {
    try {
      // Kullanıcı adı kontrolü
      if (!isValidUsernameFormat(username)) {
        return 'err_username_format';
      }

      // SIRA ÖNEMLİ: Kurallar okuma için giriş şartı koyuyor. Kontrol
      // artık oturumu kendisi garanti ediyor (_ensureAnonymousSession).
      // Burada MEVCUT oturum yeniden kullanılır — canlı kontrol sırasında
      // açılmış olabilir; ikinci bir anonim hesap yaratmayız.
      final available = await isUsernameAvailable(username);
      if (!available) return 'err_username_taken';

      final authUser = _auth.currentUser ??
          (await _auth.signInAnonymously().timeout(const Duration(seconds: 15)))
              .user!;
      final uid = authUser.uid;

      // Gizli geri-donus kimligi: anonim hesaba email/sifre bagla.
      // Boylece sonradan bu hesaba yeniden girilip hesaplar arasi gecis mumkun olur.
      final accountPassword = EncryptionService.generateKey();
      try {
        final emailCred = EmailAuthProvider.credential(
          email: '$uid@gizlichat.local',
          password: accountPassword,
        );
        await authUser
            .linkWithCredential(emailCred)
            .timeout(const Duration(seconds: 10));
        await _storage.write(key: _pwName, value: accountPassword);
      } catch (_) {
        // Baglama basarisiz olursa (or. saglayici kapali) hesap anonim calisir;
        // sadece gecis yapilamaz.
        await _storage.delete(key: _pwName);
      }

      // ── ANAHTAR KAPSAMI (§ yeni hesap) ──
      // 🐞 BURASI EKSİKTİ. E2EE oturumları ve GÖNDERİLEN MESAJLARIN DÜZ
      // METİNLERİ `_accountScope` ön ekiyle saklanır; kapsam yalnızca
      // `main.dart` açılışında ve `switchAccount`ta ayarlanıyordu.
      // Yeni kayıtta ayarlanmadığı için kapsam ya `'_'` (temiz kurulum)
      // ya da ÖNCEKİ hesabın uid'i kalıyordu (signOut da sıfırlamıyordu).
      // Sonuç: bu oturumda gönderilen mesajların düz metni YANLIŞ ön ekle
      // yazılıyor, uygulama yeniden açılınca `main.dart` kapsamı doğru
      // uid'e çekiyor ve kayıtlar ERİŞİLEMEZ oluyordu — gönderen kendi
      // mesajını "bu mesaj cihazda çözülemiyor" olarak görüyordu
      // (bkz. encryption_datasource_impl.dart, `isFromMe` dalı).
      // Ayrıca yeni hesabın verisi eski hesabın ön ekiyle yazılıyordu;
      // kapsamlamanın önlemek için var olduğu şeyin ta kendisi.
      E2EESessionService.setActiveAccount(uid);
      GroupKeyService.setActiveAccount(uid);
      ChatLockService.setActiveAccount(uid);
      // §4au: yeni hesap KENDİ kimlik anahtarını üretmeli; kapsam
      // kurulmazsa cihazdaki başka hesabın anahtarını devralır.
      KeyManagementService.setActiveAccount(uid);

      final uname = username.toLowerCase();

      // ── ADI ATOMİK REZERVE ET (yazımdan ÖNCE) ──
      // Yarış artık sunucuda çözülür; "yaz sonra geri al" telafisi ve onun
      // yarattığı yinelenen-ad riski ortadan kalkar.
      if (!await _reserveUsername(uname, uid)) {
        return 'err_username_just_taken';
      }

      // Şifreleme anahtarı üret (yalnızca cihazda kalır)
      final encKey = EncryptionService.generateKey();
      await _saveEncryptionKey(encKey);

      // Kullanıcıyı Firestore'a kaydet.
      //
      // ⚠️ GİDERİLEN SIR SIZINTISI: Eski kod `publicKey`e
      // `encKey.substring(0, 16)` yazıyordu — yani SİMETRİK AES anahtarının
      // ilk 16 base64 karakteri (~96 bit gizli anahtar materyali) HERKESE
      // AÇIK bir alana konuyordu ("Sadece public kısım" yorumu yanlıştı:
      // simetrik anahtarın public kısmı yoktur). Artık E2EE açık anahtarı
      // `keyBundles` koleksiyonundan gelir ve bu alan boş bırakılır.
      final user = UserModel(
        uid: uid,
        username: uname,
        isOnline: true,
        lastSeen: DateTime.now(),
        publicKey: '',
      );

      // ── DİZİN GERİ ALMA ──
      // 🐞 `usernames/{ad}` PROFİLDEN ÖNCE yazılıyor. Bu yazma patlarsa
      // eskiden dizin ÖKSÜZ kalıyordu: ad "alınmış" görünüyor ama
      // `users/{uid}` yok. O ad artık ne aramada bulunuyor
      // (findUserByUsername profil yoksa null döner) ne de başkası
      // tarafından alınabiliyor (isUsernameAvailable dizine bakıp
      // "dolu" der). Yani ad KALICI OLARAK ÇÖPE gidiyordu.
      try {
        await _db.collection('users').doc(uid).set(user.toMap());
      } catch (e, st) {
        try {
          await _db.collection('usernames').doc(uname).delete();
        } catch (e2, st2) {
          // Geri alma da başarısız: ad gerçekten öksüz kaldı. Sessiz
          // geçmek, sorunu görünmez kılar.
          reportHandled(
              'Kullanıcı adı dizini geri alınamadı — ad öksüz kaldı', e2,
              stack: st2);
        }
        reportHandled('Kullanıcı profili yazılamadı', e, stack: st);
        return 'err_register';
      }
      await _storage.write(key: _uidName, value: uid);

      return null; // Hata yok
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'err_register';
    } catch (e) {
      return e.toString();
    }
  }

  /// Oturum devam ediyor mu kontrol et
  static Future<bool> isLoggedIn() async {
    final uid = await _storage.read(key: _uidName);
    return uid != null && _auth.currentUser != null;
  }

  /// Çevrimiçi durumu güncelle.
  ///
  /// ⚠️ ALAN ADI BİRLEŞTİRİLDİ: Bu metot `isOnline`, `PresenceService` ise
  /// `online` alanına yazıyordu. Arayüzün kullandığı `presenceProvider`
  /// yalnızca `online` okuduğu için, buradan yapılan güncellemeler HİÇ
  /// GÖRÜNMÜYORDU (MIGRATION_STATUS.md'nin uyardığı boşluk). Artık tek
  /// yazıcı `PresenceService`; bu metot ona delege eder.
  static Future<void> setOnlineStatus(bool isOnline) =>
      PresenceService.setOnline(isOnline);

  /// Kullanıcı ara (ada göre).
  ///
  /// ⚠️ `users` koleksiyonunda LİSTELEME KAPALI (numaralandırma önlemi).
  /// Arama, doküman kimliği kullanıcı adı olan `usernames` dizini
  /// üzerinden yapılır: tek bir `get`, sorgu yok.
  static Future<UserModel?> findUserByUsername(String username) async {
    final uname = username.toLowerCase();
    final indexed = await _db.collection('usernames').doc(uname).get();
    final uid = (indexed.data()?['uid'] ?? '').toString();
    if (uid.isEmpty) return null;

    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;

    final user = UserModel.fromMap(data);
    // DİZİN DOĞRULAMASI: dizin istemciden yazıldığı için, profildeki adla
    // tutmuyorsa GÜVENİLMEZ. (Biri `usernames/banka` dokümanını kendi
    // uid'siyle oluşturup başkası gibi görünmeye çalışabilir; bu kontrol
    // o denemeyi sonuçsuz bırakır.)
    if (user.username.toLowerCase() != uname) return null;
    return user;
  }

  /// Mevcut kullanıcı bilgilerini al
  static Future<UserModel?> getCurrentUserData() async {
    final uid = currentUid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  /// Çıkış — sadece local session temizle, data silinmez
  /// Hesabi KALICI olarak siler: hikayeler, profil fotografi, kullanici
  /// belgesi, kayitli hesap, lokal anahtarlar ve Firebase Auth kullanicisi.
  /// Kullanici adi 14 gun rezerve tutulur (taklit onleme), sonra bosa duser.
  /// Basarili olursa null, aksi halde hata mesaji doner.
  static Future<String?> deleteMyAccount() async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (user == null || uid == null) return 'Oturum bulunamadi';

    try {
      final profile = await getUserProfile(uid);
      final username = profile?.username ?? '';

      // 1) Kullanıcı adını 14 gün rezerve et (taklit önleme).
      //    `create` kuralına uyması için doküman YOKSA yazılır.
      if (username.isNotEmpty) {
        try {
          await _db.collection('releasedUsernames').doc(username).set({
            'username': username,
            'releaseAt': DateTime.now()
                .toUtc()
                .add(const Duration(days: 14))
                .toIso8601String(),
          });
        } catch (e, s) {
          // ⚠️ Ad rezerve edilmezse dizin kaydı oluşmaz; aynı adı bir
          // başkası alabilir (§4l'deki taklit yüzeyi).
          reportHandled('Kullanıcı adı rezerve edilemedi', e, stack: s);
        }
      }

      // 2) ── SUNUCU TARAFI TAM SİLME ──
      // Eski akış yalnızca hikâye dokümanlarını, avatarı ve kullanıcı
      // dokümanını siliyordu. GERİDE KALANLAR: keyBundles (başkaları hâlâ
      // bu kişiye şifreli oturum kurmaya çalışıyordu), sohbet üyelikleri
      // ("hayalet üye"), mesajlar, callLogs, meetCodes, inviteCodes,
      // scheduledMessages ve hikâye MEDYA dosyaları. Bu, gizlilik
      // politikasındaki silme vaadini ve KVKK/GDPR silme hakkını
      // karşılamıyordu. Artık tek bir Cloud Function hepsini temizler.
      var serverCleaned = false;
      try {
        await FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('deleteAccountData')
            .call()
            .timeout(const Duration(seconds: 45));
        serverCleaned = true;
      } catch (e, s) {
        // ⚠️ KVKK/GDPR: kullanıcı "hesabım silindi" sanır ama sunucuda
        // veri kalmıştır. Aşağıdaki yedek yol yalnızca kısmî temizler.
        reportHandled('Sunucu tarafı hesap silme başarısız', e, stack: s);
      }

      // 3) Sunucu çağrısı başarısızsa en azından erişilebilir verileri sil
      //    (kullanıcı tamamen çaresiz kalmasın).
      if (!serverCleaned) {
        try {
          final stories = await _db
              .collection('stories')
              .where('userId', isEqualTo: uid)
              .get();
          for (final doc in stories.docs) {
            await doc.reference.delete();
          }
        } catch (e, s) {
          // ⚠️ SON ŞANS DA KAÇTI: sunucu çağrısı zaten başarısızdı (yukarıda
          // raporlandı) ve bu yedek yol da tutmazsa hikâyeler sunucuda
          // KALIR. Kullanıcı "hesabım silindi" sanır — KVKK/GDPR açısından
          // bu ikinci başarısızlık birincisi kadar önemlidir.
          reportHandled('Yedek temizlik: hikâyeler silinemedi', e, stack: s);
        }
        try {
          await FirebaseStorage.instance
              .ref()
              .child('avatars/$uid.jpg')
              .delete();
        } catch (_) {
          // dosya yok — sorun değil
        }
        try {
          await _db.collection('users').doc(uid).delete();
        } catch (e, s) {
          // ⚠️ En ağırı: profil dokümanı sunucuda kalır, yani kullanıcı
          // adı DİZİNDE görünmeye ve uid'yi bilen herkes profili okumaya
          // devam eder — silinmiş sanılan bir hesap için.
          reportHandled('Yedek temizlik: kullanıcı dokümanı silinemedi', e,
              stack: s);
        }
      }

      // 4) ── CİHAZDAKİ TÜM İZLERİ SİL ──
      // Kritik: E2EE oturumları ve ÇÖZÜLMÜŞ MESAJ METİNLERİ cihazda
      // kalıyordu. Yani "hesabımı sil" dedikten sonra bile, cihaza erişen
      // biri tüm mesaj geçmişini okuyabiliyordu.
      final savedPw = await _storage.read(key: _pwName);
      await E2EESessionService.wipeAccount();
      await GroupKeyService.wipeAccount();
      await KeyManagementService.wipeLocalKeys();
      await ChatLockService.wipeAll();
      // Çözülmüş medya cihazda kalırsa "hesabımı sil" bir yanılsamadır.
      await SecureMediaCache.instance.clearAll();
      await MultiAccountService.removeAccount(uid);
      await _storage.delete(key: _uidName);
      await _storage.delete(key: _keyName);
      await _storage.delete(key: _pwName);

      // 5) Firebase Auth kullanıcısını sil (gerekirse yeniden kimlik doğrula)
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login' &&
            savedPw != null &&
            savedPw.isNotEmpty) {
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: '$uid@gizlichat.local',
              password: savedPw,
            ),
          );
          await user.delete();
        } else {
          // Auth silinemese bile veriler temizlendi; oturumu kapat
          await _auth.signOut();
        }
      }
      return null;
    } catch (e) {
      return 'Hesap silinemedi: $e';
    }
  }

  /// Eski surumde (gizli kimlik olmadan) olusturulmus ve su an AKTIF olan
  /// hesabi otomatik yeni surume yukseltir: mevcut Firebase kullanicisina
  /// email/sifre kimligi baglar, SavedAccount'u gunceller. Boylece bu hesaba
  /// sonradan gecis yapilabilir ve HICBIR VERI KAYBOLMAZ.
  /// (Yalnizca o an giris yapili hesap yukseltilebilir; giris yapili olmayan
  ///  eski hesaplara erisim yoktur cunku kimlikleri yoktur.)
  static Future<void> upgradeCurrentAccountIfNeeded() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Zaten email/sifre bagliysa (yeni surum hesabi) dokunma
    final hasPassword =
        user.providerData.any((p) => p.providerId == 'password');
    if (hasPassword) return;

    try {
      final pw = EncryptionService.generateKey();
      // AĞ ÇAĞRISI — zaman aşımı ŞART. Korumasız bırakılınca bağlantı
      // yavaşken hesap ekranı sonsuza kadar yüklenme durumunda kalıyordu.
      await user
          .linkWithCredential(
            EmailAuthProvider.credential(
              email: '${user.uid}@gizlichat.local',
              password: pw,
            ),
          )
          .timeout(const Duration(seconds: 10));
      await _storage.write(key: _pwName, value: pw);

      // SavedAccount'u guncelle: kullanici adi + anahtar korunur, password eklenir
      final accounts = await MultiAccountService.getAccounts();
      final match = accounts.where((a) => a.uid == user.uid).toList();
      final username = match.isNotEmpty ? match.first.username : '';
      final encKey = await getEncryptionKey() ?? '';
      await MultiAccountService.saveAccount(SavedAccount(
        uid: user.uid,
        username: username,
        encryptionKey: encKey,
        password: pw,
      ));
    } catch (_) {
      // Yukseltme basarisiz olursa hesap anonim calismaya devam eder.
    }
  }

  /// Mevcut kullanicinin profilini getir (foto + bio dahil)
  static Future<UserModel?> getMyProfile() async {
    final uid = currentUid;
    if (uid == null) return null;
    return getUserProfile(uid);
  }

  /// Herhangi bir kullanicinin profilini uid ile getir (foto + bio + username).
  static Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  /// Profil fotografini yukle ve kaydet; indirilebilir URL doner.
  static Future<String?> uploadAndSetAvatar(String localPath) async {
    final uid = currentUid;
    if (uid == null) return null;
    final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
    await ref.putFile(File(localPath));
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).update({'avatarUrl': url});
    return url;
  }

  /// "Hakkinda" (bio) metnini kaydet.
  static Future<void> setBio(String bio) async {
    final uid = currentUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'bio': bio});
  }

  /// Aktif hesabin gizli geri-donus sifresi
  static Future<String?> getAccountPassword() async {
    return await _storage.read(key: _pwName);
  }

  /// Kayitli baska bir hesaba gecis yapar (gizli kimlikle yeniden giris).
  /// Eski (kimliksiz) hesaplarda password bos -> gecis yapilamaz.
  static Future<String?> switchAccount(SavedAccount account) async {
    if (account.password.isEmpty) {
      // ONARIM DENEMESİ: Parola boş görünüyor olabilir çünkü güvenli
      // depolama erişilemez hâle geldi (paket adı değişimi sonrası
      // Keystore sorunu). Kayıt AKTİF hesaba aitse, parolayı depodan
      // tekrar okuyup kaydı tazeleyebiliriz.
      if (account.uid == currentUid) {
        final pw = await getAccountPassword();
        if (pw != null && pw.isNotEmpty) {
          await MultiAccountService.saveAccount(SavedAccount(
            uid: account.uid,
            username: account.username,
            encryptionKey: account.encryptionKey,
            password: pw,
          ));
          return null; // zaten bu hesaptayız, geçiş gereksiz
        }
      }
      // Gerçekten parolasız: kullanıcıya ÇÖZÜM YOLU göster.
      return 'err_account_no_password';
    }
    try {
      // Eski hesabi cevrimdisi isaretle — KRITIK DEGIL, geçişi bloklamasin
      // (Firestore yazimi asilirsa spinner sonsuza donerdi).
      unawaited(setOnlineStatus(false)
          .timeout(const Duration(seconds: 3))
          .catchError((_) {}));
      await _auth.signOut().timeout(const Duration(seconds: 6));
      // Kritik adim: yeni hesaba giris — ZAMAN ASIMI ile korunur.
      await _auth
          .signInWithEmailAndPassword(
            email: '${account.uid}@gizlichat.local',
            password: account.password,
          )
          .timeout(const Duration(seconds: 12));
      // Aktif hesabin sirlarini yerel depoya yukle (yerel, hizli)
      await _storage.write(key: _uidName, value: account.uid);
      await _storage.write(key: _keyName, value: account.encryptionKey);
      await _storage.write(key: _pwName, value: account.password);
      await MultiAccountService.setActiveAccount(account.uid);

      // ── HESAPLAR ARASI SIZINTIYI ÖNLE ──
      // E2EE oturumları, çözülmüş mesaj metinleri ve sohbet kilitleri
      // yalnızca `chatId` ile isimlendirildiğinde ÖNCEKİ hesabın verisi
      // yeni hesapta görünebiliyordu. Kapsam yeni uid'e alınır ve
      // bellekteki düz metinler temizlenir.
      E2EESessionService.setActiveAccount(account.uid);
      GroupKeyService.setActiveAccount(account.uid);
      ChatLockService.setActiveAccount(account.uid);
      // §4au: kimlik anahtarları da hesaba bağlı.
      KeyManagementService.setActiveAccount(account.uid);
      // TURN kimliği de düşürülür: aynı kimliği iki hesapta kullanmak,
      // TURN sunucusunun "bu iki hesap AYNI CİHAZ" çıkarımını yapmasına
      // izin verirdi. Sunucu zaten IP'yi görüyor; üstüne bir de hesapları
      // birbirine bağlamak, çok hesap özelliğini anlamsız kılardı.
      TurnCredentialsService.invalidate();
      // Ad önbelleği önceki hesabın gördüğü kişilere aitti.
      UsernameResolver.clear();
      // Eski ad dizisi temizliği de: sohbetler önceki hesabındı.
      ChatMetadataScrub.reset();

      // Yeni hesabın anahtar paketi yayınlanmış olsun (aksi halde karşı
      // taraf bu hesaba şifreli oturum kuramaz).
      KeyManagementService.ensureKeysPublished().catchError((Object e) {
        // ⚠️ Paket yayınlanmazsa KİMSE bu hesaba E2EE oturumu kuramaz.
        reportHandled('Anahtar paketi yayınlanamadı', e);
      });

      // HIZ: kritik olmayan yan işler beklenmez (arka planda tamamlanır)
      setOnlineStatus(true);
      NotificationService.saveTokenForCurrentUser();
      return null;
    } on TimeoutException {
      return 'err_timeout';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Giris hatasi';
    } catch (e) {
      return e.toString();
    }
  }

  /// Çıkış — oturumu kapatır ve cihazdaki OKUNABİLİR izleri temizler.
  ///
  /// ⚠️ Eski sürüm yalnızca `chat_uid` anahtarını siliyordu. Şifreleme
  /// anahtarı, hesap parolası, E2EE oturumları ve ÇÖZÜLMÜŞ MESAJ METİNLERİ
  /// cihazda kalıyordu; aynı telefonu kullanan bir sonraki kişi (veya
  /// cihaza erişen biri) önceki hesabın mesajlarını okuyabiliyordu.
  ///
  /// [forgetDevice] false ise (varsayılan) hesap çoklu-hesap listesinde
  /// kalır ve kullanıcı geri dönebilir; true ise cihazdan tamamen silinir.
  static Future<void> signOut({bool forgetDevice = false}) async {
    try {
      await setOnlineStatus(false).timeout(const Duration(seconds: 3));
    } catch (_) {
      // çevrimdışı işaretleme kritik değil
    }

    // Bellekteki düz metinleri her durumda temizle.
    E2EESessionService.clearMemoryCache();
    TurnCredentialsService.invalidate();
    UsernameResolver.clear();
    ChatMetadataScrub.reset();

    // 🐞 KAPSAM SIFIRLANMIYORDU. Çıkıştan sonra `_accountScope` hâlâ
    // ÇIKILAN hesabın uid'iydi. "Hesap ekle" akışı signOut + register
    // olduğu için, yeni hesabın E2EE oturumları ve düz metinleri ESKİ
    // hesabın ön ekiyle yazılıyordu. Kapsam burada düşürülür; register
    // ve switchAccount kendi kapsamını kendisi kurar.
    E2EESessionService.setActiveAccount(null);
    GroupKeyService.setActiveAccount(null);
    ChatLockService.setActiveAccount(null);
    KeyManagementService.setActiveAccount(null);

    if (forgetDevice) {
      final uid = currentUid;
      await E2EESessionService.wipeAccount();
      await GroupKeyService.wipeAccount();
      await KeyManagementService.wipeLocalKeys();
      await ChatLockService.wipeAll();
      await SecureMediaCache.instance.clearAll();
      if (uid != null) await MultiAccountService.removeAccount(uid);
      await _storage.delete(key: _keyName);
      await _storage.delete(key: _pwName);
    }

    await _storage.delete(key: _uidName);
    try {
      await NotificationService.deleteToken();
    } catch (e) {
      debugPrint('Push token silinemedi: $e');
    }
    await _auth.signOut();
  }
}
