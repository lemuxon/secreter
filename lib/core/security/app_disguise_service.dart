import 'package:flutter/services.dart';
import '../../core/observability/handled_error.dart';

/// 🥸 UYGULAMA KILIĞI
///
/// Başlatıcıda görünen ad ve simgeyi sıradan bir hesap makinesiyle
/// değiştirir. Uygulamanın kendisi değişmez; yalnızca dışarıdan nasıl
/// göründüğü değişir.
///
/// **Neden sahte PIN'den farklı:** sahte PIN, telefon açıldıktan ve
/// uygulama başlatıldıktan SONRA korur. Kılık ise uygulamanın
/// VARLIĞINI gizler — cihaz incelenirken uygulama listesinde "SECRETER"
/// diye bir şey görünmez. İkisi birbirinin yerine geçmez; birlikte
/// anlamlıdır.
///
/// ⚠️ **Sınırları dürüstçe:**
/// * Ayarlar → Uygulamalar listesinde gerçek paket adı
///   (`com.secreter.app`) görünmeye devam eder. Kılık başlatıcı
///   simgesini gizler, uygulamayı sistemden SİLMEZ.
/// * Bazı başlatıcılar simgeyi birkaç saniye gecikmeyle tazeler; nadiren
///   başlatıcının yeniden başlatılması gerekir.
class AppDisguiseService {
  AppDisguiseService._();

  static const _channel = MethodChannel('com.gizlichat.app/security');

  /// Kılık şu an açık mı?
  ///
  /// Gerçek kaynak SİSTEMDİR (bileşen durumu), yerel bir bayrak değil:
  /// kullanıcı uygulamayı yeniden kursa ya da veriyi temizlese bile
  /// arayüz gerçeği gösterir.
  static Future<bool> isDisguised() async {
    try {
      return await _channel.invokeMethod<bool>('isDisguised') ?? false;
    } on PlatformException catch (e, s) {
      // ⚠️ ARAYÜZ "KILIK KAPALI" GÖSTERİR AMA GERÇEK BİLİNMİYOR. Bu
      // ekranın tüm değeri SİSTEMİN gerçeğini yansıtmasıydı (yorumda
      // yazdığı gibi); okuma patladığında anahtar yanlış konumda görünür
      // ve kullanıcı kılığın kapalı olduğunu sanarak yeniden açmaya
      // çalışır ya da açık sanıp korumasız kalır.
      reportHandled('Kılık durumu okunamadı — ARAYÜZ GERÇEĞİ GÖSTERMİYOR', e,
          stack: s);
      return false;
    } on MissingPluginException {
      // Android dışı / eski derleme
      return false;
    }
  }

  /// Kılığı aç veya kapat.
  ///
  /// Başarısızlıkta `false` döner — çağıran taraf kullanıcıya bunu
  /// göstermelidir. Sessizce başarılı saymak, kullanıcının "gizlendim"
  /// sanmasına yol açardı ve bu özellikte yanlış güven, özelliğin
  /// olmamasından daha tehlikelidir.
  static Future<bool> setDisguised(bool enabled) async {
    try {
      await _channel.invokeMethod<bool>('setDisguise', {'enabled': enabled});
      return true;
    } on PlatformException catch (e) {
      reportHandled('Uygulama kılığı değiştirilemedi', e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
