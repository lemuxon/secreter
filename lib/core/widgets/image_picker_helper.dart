import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/app_theme.dart';
import '../observability/handled_error.dart';
import 'photo_editor_screen.dart';

/// Kırpma ekranının sunduğu seçenek kümesi.
enum KirpmaModu {
  /// SERBEST: oran kilidi yok, hazır oran düğmesi de YOK.
  ///
  /// ⚠️ Oran düğmeleri `aspectRatioPresets: []` ile KALDIRILAMAZ —
  /// uCrop boş liste görünce KENDİ varsayılanlarını (4:3, 16:9…)
  /// geri koyar. Tek yol alt kontrol çubuğunu gizlemektir; bedeli
  /// döndürme/ölçek sekmelerinin de gitmesidir.
  serbest,

  /// 1:1 KİLİTLİ — çerçeve daima kare.
  kare,

  /// Serbest + hazır oran düğmeleri (özgün, 1:1, 4:3, 16:9).
  oranli,
}

/// 🖼️ FOTOĞRAF SEÇ + KIRP — tek kapı
///
/// Uygulamada beş ayrı yerde fotoğraf seçiliyordu (sohbet, hikâye,
/// profil, grup, sohbet arka planı) ve her biri kendi kodunu taşıyordu.
/// Kırpma özelliğini beş yere ayrı ayrı eklemek yerine tek yardımcıda
/// topluyoruz: davranış her yerde aynı olur, ileride değişiklik tek
/// yerden yapılır.
///
/// KIRPMA EKRANI kullanıcıya şunları verir:
///  • Serbest veya sabit oranlı kırpma
///  • 90° adımlarla DÖNDÜRME
///  • Yakınlaştırma / kaydırma
class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Galeriden veya kameradan fotoğraf seç, ardından kırpma ekranını aç.
  ///
  /// [square] true ise 1:1 zorlanır (profil ve grup fotoğrafları için —
  /// yuvarlak avatarda taşma olmasın).
  /// [maxWidth] kaynak çözünürlük sınırı (maliyet + hız).
  ///
  /// DÖNÜŞ: kırpılmış dosyanın yolu; kullanıcı vazgeçerse null.
  /// [allowEdit] true ise kırpmadan SONRA çizim/yazı editörü sunulur
  /// (sohbet fotoğrafı ve hikâye için; profil/grup avatarında gereksiz).
  static Future<String?> pickAndCrop(
    BuildContext context, {
    required ImageSource source,
    KirpmaModu mod = KirpmaModu.oranli,
    bool allowEdit = false,
    int maxWidth = 1600,
    int imageQuality = 85,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
      imageQuality: imageQuality,
    );
    if (picked == null) return null;

    if (!context.mounted) return null;
    // ✏️ DOĞRUDAN EDİTÖR (allowEdit)
    //
    // Eskiden akış üç adımdı: kırp → "düzenlemek ister misin?" →
    // editör. Ara soru gereksiz sürtünmeydi; kırpma zaten editörün
    // İÇİNDE olduğu için tek ekranda hallolur.
    if (allowEdit && context.mounted) {
      final edited = await PhotoEditorScreen.open(context, picked.path);
      return edited; // iptal → null (fotoğraf gönderilmez)
    }

    // Editörsüz akış (profil/grup avatarı): yalnızca kırpma
    return cropExisting(context, picked.path, mod: mod);
  }

  /// Zaten seçilmiş bir dosyayı kırp (yeniden seçtirmeden).
  static Future<String?> cropExisting(
    BuildContext context,
    String path, {
    KirpmaModu mod = KirpmaModu.oranli,
  }) async {
    try {
      final kare = mod == KirpmaModu.kare;
      final serbest = mod == KirpmaModu.serbest;
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        aspectRatio: kare ? const CropAspectRatio(ratioX: 1, ratioY: 1) : null,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'SECRETER',
            toolbarColor: AppTheme.background,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: AppTheme.primary,
            // SERBEST modda alt çubuk tamamen gizlenir: oran düğmesi
            // kalmaz, geriye yalnızca çerçeveyi sürükleyerek kırpma
            // kalır. (Boş `aspectRatioPresets` işe yaramaz — bkz. enum.)
            hideBottomControls: serbest,
            lockAspectRatio: kare,
            initAspectRatio: kare
                ? CropAspectRatioPreset.square
                : CropAspectRatioPreset.original,
            aspectRatioPresets: kare
                ? [CropAspectRatioPreset.square]
                : [
                    CropAspectRatioPreset.original,
                    CropAspectRatioPreset.square,
                    CropAspectRatioPreset.ratio4x3,
                    CropAspectRatioPreset.ratio16x9,
                  ],
          ),
          IOSUiSettings(
            title: 'SECRETER',
            aspectRatioLockEnabled: kare,
            resetAspectRatioEnabled: !kare,
            rotateButtonsHidden: false,
          ),
        ],
      );
      // Kullanıcı kırpmadan vazgeçtiyse ORİJİNALİ kullan — fotoğrafı
      // tamamen kaybetmesin.
      return cropped?.path ?? path;
    } catch (e, st) {
      // ⚠️ SESSİZ YUTMA DEĞİL: kırpma çökerse kullanıcı fotoğrafını
      // kaybetmesin diye orijinale dönülür, ama bu SESSİZCE olmaz —
      // aksi hâlde "kırpma ekranı hiç açılmıyor" arızası ölçülemez
      // kalırdı (§4p).
      reportHandled('Kırpma başarısız — orijinal kullanıldı', e, stack: st);
      return path;
    }
  }
}
