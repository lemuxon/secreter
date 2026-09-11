/// Şifreleme soyutlaması.
///
/// Repository bu arayüze bağlıdır; arkasında E2EE (X3DH/Ratchet) veya
/// ileride libsignal olabilir. Şifreleme stratejisi değişse bile
/// repository kodu değişmez.
///
/// ── DÜZ METİN YAŞAM DÖNGÜSÜ NEDEN BURADA ──
/// Ratchet tek yönlü olduğu için okunabilir metin cihazda saklanmak
/// zorundadır. Kritik olan, mesaj silindiğinde bu kopyanın DA silinmesidir;
/// aksi halde "kaybolan mesaj" ve "herkesten sil" özellikleri cihazda
/// hiçbir şey temizlemez. Repository bu metotları çağırabilsin diye
/// arayüze eklendi — böylece somut servise (statik `E2EESessionService`)
/// doğrudan bağımlılık kalmaz ve repository TEST EDİLEBİLİR olur.
abstract class EncryptionDataSource {
  /// Çözülemeyen mesaj için [decrypt]'in döndürdüğü NÖBETÇİ değer.
  ///
  /// Arayüzde durur çünkü repository'nin onu TANIMASI gerekir: başarısız
  /// çözüm sonucu önbelleğe alınırsa, oturum sonradan onarılsa bile mesaj
  /// uygulama yeniden başlayana kadar "çözülemiyor" kalır (§4az).
  ///
  /// Bastaki karakter bir BOSLUK DEGIL, NUL'dur (U+0000): gercek
  /// kullanici metniyle asla carpismasin diye. Kaynakta GORUNMEZ
  /// oldugu icin kacis dizisiyle yazilir; duz NUL yazilirsa dosya
  /// ikili sayilir ve `grep` onu bulamaz.
  static const String lostMarker = '\u0000E2EE_LOST';

  /// Verilen sohbet için metni şifrele.
  ///
  /// [otherUserId] doluysa BİREBİR (X3DH + Double Ratchet).
  /// Boşsa ve [memberIds] birden fazla üye içeriyorsa GRUP (Sender Key).
  /// İkisi de kurulamazsa sonuç `isEncrypted: false` olur ve arayüz kilit
  /// simgesi göstermez — kullanıcı durumu görebilir.
  Future<EncryptionResult> encrypt({
    required String chatId,
    required String otherUserId,
    required String plaintext,
    List<String> memberIds = const [],
  });

  /// Şifreli metni çöz.
  ///
  /// Birebir ve grup zarflarını otomatik ayırt eder.
  Future<String> decrypt({
    required String chatId,
    required String ciphertext,
    required bool isFromMe,
    required String messageId,
    Map<String, dynamic>? e2eeHeader,
    bool isGroup = false,
  });

  /// Gönderilen mesajın düz metnini cihazda sakla (gönderen kendi
  /// şifreli metnini çözemez).
  Future<void> cachePlaintext(String messageId, String plaintext);

  /// Tek bir mesajın düz metnini cihazdan sil.
  Future<void> forgetPlaintext(String messageId);

  /// Toplu sil (herkesten sil / bende sil / süresi doldu).
  Future<void> forgetPlaintexts(Iterable<String> messageIds);

  /// Bu hesabın tüm düz metinlerini sil (sohbet temizleme / çıkış).
  Future<void> wipeAllPlaintexts();

  /// Düz metin önbelleğini TEK çağrıyla belleğe ısıt (§4bi).
  ///
  /// Sohbet açılışında her mesaj için ayrı güvenli-depo okuması yapılıyor,
  /// Android'de her biri bir platform kanalı çağrısı olduğu için sohbet
  /// saniyelerce "yükleniyor" kalıyordu. Çağrı yinelenebilir; ilkinden
  /// sonrası bedavadır.
  Future<void> warmPlaintextCache();
}

class EncryptionResult {
  final String ciphertext;
  final bool isEncrypted;
  final Map<String, dynamic>? e2eeHeader;

  EncryptionResult({
    required this.ciphertext,
    required this.isEncrypted,
    this.e2eeHeader,
  });
}
