import 'package:flutter/material.dart';
import 'secure_media_image.dart';
import '../security/native_security_bridge.dart';
import '../../services/privacy_service.dart';

/// Paylaşılan tam ekran resim görüntüleyici (pinch-zoom).
/// Açıkken FLAG_SECURE ile ekran görüntüsü + ekran kaydını engeller.
/// (messaging + profil ekranlarındaki kopyalar bununla tekilleştirildi.)
class FullScreenImage extends StatefulWidget {
  final String url;

  /// Şifreli ek anahtarı. null ise medya şifresizdir (eski mesajlar).
  final String? mediaKey;

  const FullScreenImage({super.key, required this.url, this.mediaKey});

  /// Kolay açma yardımcısı.
  ///
  /// DÖNÜŞ: `true` = resim GERÇEKTEN yüklendi ve gösterildi.
  /// `false` = yükleme tamamlanmadan çıkıldı veya hata oluştu.
  ///
  /// NEDEN ÖNEMLİ: Tek görüntülük medyada içerik, kullanıcı ekrandan
  /// çıkınca siliniyordu — resim yüklenmemiş olsa bile. Yavaş bağlantıda
  /// kullanıcı boş ekran görüp hakkını kaybediyordu. Artık tüketim
  /// yalnızca resim GÖRÜLDÜYSE yapılır.
  static Future<bool> open(BuildContext context, String url,
      {String? mediaKey}) async {
    final seen = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FullScreenImage(url: url, mediaKey: mediaKey),
    ));
    return seen ?? false;
  }

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  /// Resim en az bir kez başarıyla çizildi mi?
  ///
  /// Tek görüntülük medyanın TÜKETİLMESİ buna bağlıdır: yavaş bağlantıda
  /// ya da çözme başarısızken resim görünmeden çıkılırsa kullanıcı
  /// hakkını kaybetmemeli.
  ///
  /// ⚠️ Eskiden bu, kareden 600 ms sonra KOŞULSUZ true yapılıyordu —
  /// yani hiç çizilmeyen (çözülemeyen) bir fotoğraf da "görüldü"
  /// sayılabiliyordu. Artık sinyal `SecureMediaImage.onLoaded`'dan,
  /// yani gerçekten çizilebilir hâle gelmesinden geliyor (§4ba).
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Tam ekran görselde koruma — kullanıcı tercihine bağlı.
    // (Tek görüntülük medya zaten kendi mekanizmasıyla korunuyor:
    //  izlendikten sonra sunucudan siliniyor.)
    PrivacyService.isScreenshotBlocked().then((blocked) {
      if (!mounted) return;
      if (blocked) NativeSecurityBridge.acquire('fullscreen');
    });
  }

  @override
  void dispose() {
    NativeSecurityBridge.release('fullscreen');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ GERİ TUŞU/JESTİ DE SONUCU BİLDİRMELİ (§4ba).
    //
    // 🐞 GERÇEK KULLANICIDA ÖLÇÜLDÜ: tek görüntülük fotoğraf SINIRSIZ
    // kez açılabiliyordu. Sebep buydu: `canPop: true` + boş geri
    // çağrısı, geri tuşuyla çıkışta rotayı SONUÇSUZ kapatıyordu.
    // `open()` ise `seen ?? false` döndürdüğü için tüketim hiç
    // tetiklenmiyordu. Yalnızca X düğmesi sonucu döndürüyordu —
    // Android'de doğal çıkış yolu ise geri jestidir, yani pratikte
    // fotoğraf hiç tüketilmiyordu.
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_loaded);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(_loaded),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: SecureMediaImage(
              url: widget.url,
              mediaKey: widget.mediaKey,
              fit: BoxFit.contain,
              onLoaded: () {
                if (mounted && !_loaded) setState(() => _loaded = true);
              },
              placeholder: const Center(child: CircularProgressIndicator()),
              errorWidget: const Center(
                child:
                    Icon(Icons.broken_image, color: Colors.white54, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
