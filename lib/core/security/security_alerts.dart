import 'package:shared_preferences/shared_preferences.dart';

import '../observability/handled_error.dart';

/// 🛡️ KULLANICIYA GÖRÜNMESİ GEREKEN GÜVENLİK DURUMLARI (yerel).
///
/// ── NEDEN VAR ──
/// §4p ile yutulan hatalar GELİŞTİRİCİYE görünür oldu. Ama bazı
/// başarısızlıklar bir güvenlik SÖZÜNÜ bozuyor ve bunu bilmesi gereken
/// kişi kullanıcı:
///
/// * **Grup anahtarı rotasyonu başarısız.** Bir üye gruptan atıldığında
///   anahtar yenilenmezse, o kişi ELİNDEKİ anahtarla sonraki mesajları
///   çözmeye devam edebilir. Arayüzde her şey normal görünür; kullanıcı
///   "onu attım, artık okuyamaz" sanır. Bu, yanlış bir güvenlik hissidir
///   ve sessiz kalması kabul edilemez.
///
/// * **Sohbet hiç doğrulanmadı.** Güvenlik numarası ekranı var ama
///   hiçbir yer kullanıcıyı oraya yönlendirmiyordu; özellik pratikte
///   kullanılmıyordu.
///
/// ── NEDEN SUNUCUDA DEĞİL ──
/// Bu durumlar cihazın kendi bilgisidir ve sunucuya yazmak metadata
/// üretir (§4o: sohbet dokümanına gereksiz alan eklemiyoruz). Ayrıca
/// "anahtar yenilenemedi" bilgisi sunucuya söylenecek bir şey değildir.
///
/// ── NEDEN KAPATILABİLİR ──
/// Doğrulama önerisi KAPATILABİLİR, uyarı bandı DEĞİL. Kapatılamayan bir
/// öneri gürültüye dönüşür ve kullanıcı tüm bantları görmezden gelmeye
/// başlar — o noktada gerçek uyarı da işe yaramaz.
class SecurityAlerts {
  SecurityAlerts._();

  static const _rotationPrefix = 'sec_rotfail_';
  static const _verifyDismissPrefix = 'sec_verifyoff_';
  static const _plaintextPrefix = 'sec_plain_';

  /// Grup anahtarı rotasyonu başarısız oldu mu? (üyelik değişimi sonrası)
  static Future<bool> groupKeyRotationFailed(String chatId) =>
      _read('$_rotationPrefix$chatId');

  /// Rotasyon sonucunu kaydet. Başarılıysa bayrak TEMİZLENİR.
  static Future<void> setGroupKeyRotationFailed(String chatId, bool failed) =>
      _write('$_rotationPrefix$chatId', failed);

  /// 🔓 Bu grupta mesajlar ŞİFRESİZ gidiyor mu?
  ///
  /// §4x arıza yolunu kapattı (istisnada mesaj gönderilmiyor). Geriye
  /// **bilinçli** tercih kaldı: hiçbir üyeye anahtar ulaştırılamadıysa
  /// mesaj şifresiz gider — aksi halde HERKES için okunmaz olurdu.
  ///
  /// Sorun bu tercihin GÖRÜNMEZ olmasıydı: arayüzde şifreli mesajlar
  /// kilit ikonu taşıyor, şifresiz olan yalnızca kilidin YOKLUĞUYLA
  /// belli oluyordu — kimsenin fark etmediği bir sinyal.
  ///
  /// ⚠️ Bayrak MESAJ değil GRUP düzeyindedir. Balon başına rozet
  /// koymak yanlış araç olurdu: `isEncrypted == false` gönderim
  /// sırasındaki geçici yer tutucularda, GIF'lerde, anketlerde ve
  /// geri yüklenen yedeklerde de doğrudur ve hepsi meşrudur. Hepsini
  /// işaretlemek §4s'in tuzağına düşerdi — gürültü, gerçek uyarıyı da
  /// görünmez kılar.
  static Future<bool> groupSendsPlaintext(String chatId) =>
      _read('$_plaintextPrefix$chatId');

  /// Şifreleme durumunu kaydet. Şifreleme başarılıysa bayrak TEMİZLENİR.
  static Future<void> setGroupSendsPlaintext(String chatId, bool value) =>
      _write('$_plaintextPrefix$chatId', value);

  /// Kullanıcı bu sohbette doğrulama önerisini kapattı mı?
  static Future<bool> verifyPromptDismissed(String chatId) =>
      _read('$_verifyDismissPrefix$chatId');

  /// Öneriyi bu sohbet için bir daha gösterme.
  static Future<void> dismissVerifyPrompt(String chatId) =>
      _write('$_verifyDismissPrefix$chatId', true);

  static Future<bool> _read(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(key) ?? false;
    } catch (e, s) {
      // Okunamıyorsa uyarı GÖSTERİLMEZ. Alternatifi (varsayılan true)
      // her sohbette sahte uyarı çıkarırdı.
      reportHandled('Güvenlik uyarısı okunamadı', e, stack: s);
      return false;
    }
  }

  static Future<void> _write(String key, bool value) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (value) {
        await p.setBool(key, true);
      } else {
        await p.remove(key);
      }
    } catch (e, s) {
      reportHandled('Güvenlik uyarısı yazılamadı', e, stack: s);
    }
  }
}
