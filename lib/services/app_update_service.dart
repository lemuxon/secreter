import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/observability/handled_error.dart';

/// 🔄 GÜNCELLEME BİLDİRİMİ (§4bl)
///
/// ── NEDEN PLAY'İN API'Sİ, SUNUCU DEĞİL ──
/// Alternatif, Firestore'da "en son sürüm kodu" tutan bir belgeydi. O
/// yaklaşım her yayında elle güncelleme ister ve unutulduğu an sessizce
/// yanlış cevap verir — bu projede tam olarak bu sınıf hatalardan yeterince
/// var. Play'in kendi API'si kaynağı doğrudan mağazadan okur; bakım
/// gerektirmez ve yanlış pozitif üretmez.
///
/// ── HATA YUTMAK BURADA DOĞRU ──
/// `checkForUpdate`, Play'den KURULMAMIŞ derlemelerde (yan yükleme,
/// emülatör, dahili uygulama paylaşımı) istisna fırlatır. Bu bir arıza
/// değil, beklenen durumdur: güncelleme kontrolü yapılamıyorsa uygulama
/// normal çalışmalıdır. Yine de sessiz DEĞİL — `reportHandled` ile
/// ölçülebilir kalır, çünkü "hiç kimseye güncelleme bildirimi gitmiyor"
/// arızası ancak böyle fark edilir.
class AppUpdateService {
  AppUpdateService._();

  static const String _paketAdi = 'com.secreter.app';

  /// Aynı açılışta tekrar tekrar sorulmasın.
  static bool _soruldu = false;

  /// Play'e göre yeni bir sürüm var mı?
  ///
  /// Play dışı kurulumda ve hata durumunda **false** döner: bilmiyorsak
  /// kullanıcıyı rahatsız etmeyiz.
  static Future<bool> guncellemeVarMi({bool zorla = false}) async {
    if (_soruldu && !zorla) return false;
    _soruldu = true;
    try {
      final bilgi = await InAppUpdate.checkForUpdate();
      return bilgi.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (e) {
      // Play dışı kurulum ya da mağazaya ulaşılamıyor.
      reportHandled('Güncelleme kontrolü yapılamadı', e);
      return false;
    }
  }

  /// Mağazadaki uygulama sayfasını aç.
  ///
  /// Önce `market://` denenir (Play uygulamasını doğrudan açar); o
  /// yoksa web adresine düşülür. İkisi de olmazsa sessizce vazgeçilir —
  /// kullanıcıya "açılamadı" demek, yapabileceği bir şey olmadığı için
  /// gürültüden ibaret olurdu.
  static Future<void> magazayiAc() async {
    final adresler = [
      Uri.parse('market://details?id=$_paketAdi'),
      Uri.parse('https://play.google.com/store/apps/details?id=$_paketAdi'),
    ];
    for (final adres in adresler) {
      try {
        if (await launchUrl(adres, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // sıradakini dene
      }
    }
    reportHandled('Mağaza sayfası açılamadı', StateError('store_unreachable'));
  }
}
