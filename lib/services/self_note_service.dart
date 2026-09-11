import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../core/error/exceptions.dart';
import 'auth_service.dart';
import 'encryption_service.dart';

/// 🗒️ KENDİNE MESAJ ("Notlarım") — ŞİFRELEME
///
/// ── NEDEN AYRI BİR YOL GEREKTİ ──
/// Kendine mesaj, `chatId`i `uid_uid` olan bir birebir sohbettir. Ama
/// iki taraf AYNI kişi olduğu için mevcut yolların hiçbiri işlemiyordu:
///
///  * **X3DH + Double Ratchet olmaz.** Ratchet iki AYRI tarafın
///    anahtarlarıyla ilerler; kendinle el sıkışmak, aynı oturumun hem
///    gönderen hem alan tarafı olmak demektir.
///  * **Sender key (grup) da olmaz.** `_extractOtherUserId` burada boş
///    döner, yani sohbet GRUP sanılır; üye sayısı 1 olduğu için
///    "dejenere grup" dalına düşer ve mesaj **DÜZ METİN** gider.
///    Özellik bu yüzden ertelenmişti: çalışır görünüp sunucuda açık
///    duran notlar bırakırdı.
///
/// Doğru çözüm simetriktir: iki taraf aynı kişiyse paylaşılacak bir sır
/// da yoktur — cihazdaki anahtarla şifrele, cihazdaki anahtarla çöz.
///
/// ── ANAHTAR NEREDEN GELİYOR (ve neden ORADAN) ──
/// Hesabın `chat_encryption_key`inden HKDF ile türetilir. Seçimin sebebi
/// **kurtarmadır**: kimlik anahtarları kurtarma anahtarına GİRMEZ (bu
/// yüzden yeniden kurulumda "güvenlik numarası değişti" uyarısı çıkar),
/// ama hesap anahtarı girer. Kimlikten türetilseydi uygulamayı silip
/// kurtarma anahtarıyla dönen kullanıcının TÜM NOTLARI sessizce
/// okunamaz hâle gelirdi — sessizce veri kaybettiren bir özellik,
/// olmayan özellikten kötüdür.
///
/// ⚠️ HESAP ANAHTARI DOĞRUDAN KULLANILMAZ. HKDF ile ayrı bir amaca
/// bağlanır (`info` etiketi): bir anahtarın iki iş görmesi, birinin
/// açığa çıkmasını diğerinin de açığa çıkması yapar.
///
/// ⚠️ NOTLAR SUNUCUDA ŞİFRELİDİR AMA YEDEKLENMEZ: anahtar yalnızca
/// cihazda ve kurtarma anahtarındadır. Kurtarma anahtarı olmadan cihaz
/// kaybı = notların kaybı. Bu, uygulamanın geri kalanıyla aynı ödünleşim.
class SelfNoteService {
  SelfNoteService._();

  /// Zarf öneki. Biçim kendini tanıtır: `chatId` denetimi bir gün
  /// kayarsa bile zarf yanlış çözücüye gitmez.
  static const String _onek = 'sn1';

  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Türetilmiş anahtarın bellek önbelleği (hesap kapsamlı).
  static String? _cachedKey;
  static String _scope = '_';

  /// Hesap değişti — önbelleği DÜŞÜR.
  ///
  /// ⚠️ Bu olmadan hesap değiştiren kullanıcı, bir önceki hesabın
  /// anahtarıyla not çözmeye çalışırdı: notlar "çözülemedi" görünürdü.
  static void setActiveAccount(String? uid) {
    final yeni = uid ?? '_';
    if (yeni == _scope) return;
    _scope = yeni;
    _cachedKey = null;
  }

  /// Kendine-sohbet kimliği. Birebir sohbet biçimiyle AYNI kalır
  /// (`sıralı uid'ler`), böylece var olan sorgular ve kurallar değişmez.
  static String selfChatId(String uid) => '${uid}_$uid';

  /// Bu sohbet, [uid]'nin kendisiyle sohbeti mi?
  static bool isSelfChat(String chatId, String? uid) =>
      uid != null && uid.isNotEmpty && chatId == selfChatId(uid);

  /// Bu metin bu servisin ürettiği bir zarf mı?
  static bool isSelfEnvelope(String value) => value.startsWith('$_onek.');

  /// Notu şifrele. Başarısızlıkta FIRLATIR — asla düz metin döndürmez.
  static Future<String> encrypt(String plaintext) async {
    final key = await _anahtar();
    return '$_onek.${await EncryptionService.encrypt(plaintext, key)}';
  }

  /// Notu çöz. Başarısızlıkta fırlatır (çağıran "çözülemedi" gösterir).
  static Future<String> decrypt(String envelope) async {
    if (!isSelfEnvelope(envelope)) {
      throw const EncryptionException('err_crypto');
    }
    final key = await _anahtar();
    return EncryptionService.decrypt(
      envelope.substring(_onek.length + 1),
      key,
    );
  }

  /// Not anahtarını türet (hesap kapsamlı, bellekte önbelleklenir).
  static Future<String> _anahtar() async {
    final onbellek = _cachedKey;
    if (onbellek != null) return onbellek;

    final uid = AuthService.currentUid;
    final hesapAnahtari = await AuthService.getEncryptionKey();
    if (uid == null || hesapAnahtari == null || hesapAnahtari.isEmpty) {
      // Anahtar yoksa ŞİFRESİZ YAZMAYA DÜŞME. Notun açıkta durmasındansa
      // gönderilmemesi yeğdir (§C-06'nın dersi: şifreleme hatası sessizce
      // düz metne dönmemeli).
      throw const EncryptionException('err_crypto');
    }

    final key = await deriveKey(hesapAnahtari, uid);
    _cachedKey = key;
    return key;
  }

  /// Not anahtarını türet — SAF hesap (depo okuması yok).
  ///
  /// ⚠️ AYRI DURMASININ SEBEBİ TEST DEĞİL, DRIFT. Parametreler
  /// (`info` etiketi, tuz, uzunluk) bir gün değişirse **var olan tüm
  /// notlar sessizce okunamaz** hâle gelir. Test bu fonksiyonu
  /// çağırır ve altın bir vektörle kilitler; hesap ikinci kez
  /// yazılsaydı testteki kopya değişmeden kalır ve kayma fark
  /// edilmezdi (bu depoda §4u tam olarak böyle oldu).
  ///
  /// Biçim değiştirmek gerekirse: yeni bir `info` sürümü (`v2`) ekle,
  /// eski zarfları eski anahtarla çözmeye devam et.
  static Future<String> deriveKey(String hesapAnahtari, String uid) async {
    final turetilmis = await _hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(hesapAnahtari)),
      // Tuz olarak uid: aynı cihazdaki iki hesap aynı anahtarı üretmesin.
      nonce: utf8.encode(uid),
      // Amaç etiketi: hesap anahtarının başka bir işte kullanılması, bu
      // anahtarı ETKİLEMEZ.
      info: utf8.encode('secreter/self-notes/v1'),
    );
    return base64Url.encode(await turetilmis.extractBytes());
  }
}
