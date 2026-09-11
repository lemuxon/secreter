import 'package:flutter/foundation.dart';

/// 📊 YÜKLEME İLERLEMESİ — tek merkez
///
/// Fotoğraf/video yüklenirken yüzdeyi arayüze taşır. Basit bir
/// `ValueNotifier`: mesaj balonu bunu dinler, yüzdeyi gösterir.
///
/// NEDEN GLOBAL: Yükleme, mesaj gönderme akışının derinlerinde
/// (datasource katmanı) gerçekleşiyor. İlerlemeyi oradan arayüze
/// taşımak için tüm katmanlara parametre eklemek gerekirdi —
/// bu tek dosya çok daha az müdahaleyle aynı işi görüyor.
class UploadProgress {
  UploadProgress._();
  static final instance = UploadProgress._();

  /// 0.0 – 1.0 arası. `null` = yükleme yok.
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);

  void update(double value) {
    progress.value = value.clamp(0.0, 1.0);
  }

  void finish() {
    progress.value = null;
  }
}
