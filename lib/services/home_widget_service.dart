import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// #18 ANA EKRAN WIDGET'I — gizlilik-oncelikli:
/// Widget'ta ASLA mesaj icerigi/isim gosterilmez; yalnizca toplam
/// okunmamis sayisi. Native taraf (Kotlin provider + XML layout)
/// kullanici tarafindan eklenene kadar bu cagrilar zararsiz no-op'tur
/// (hatalar yutulur) — uygulama hicbir kosulda etkilenmez.
class HomeWidgetService {
  static int? _last;

  static Future<void> updateUnread(int totalUnread) async {
    if (totalUnread == _last) return; // degisiklik yoksa native'e inme
    _last = totalUnread;
    try {
      await HomeWidget.saveWidgetData<int>('unread_total', totalUnread);
      await HomeWidget.updateWidget(
        name: 'UnreadWidgetProvider',
        // FIX: paket adi tahminine birakma — TAM nitelikli ad ile
        // dogru provider'a yayin garantilenir (widget guncellenmiyordu).
        qualifiedAndroidName:
            // PAKET ADI DEĞİŞİMİ: bu değer Kotlin sınıfının TAM adıdır ve
            // paket adıyla birlikte değişmek ZORUNDADIR. Eski değerle
            // widget "sağlayıcı bulunamadı" hatası verir.
            'com.secreter.app.UnreadWidgetProvider',
      );
    } catch (e) {
      // native provider henuz kurulmamis olabilir — sessizce gec
      debugPrint('HomeWidget güncellenemedi (kurulum bekliyor olabilir): $e');
    }
  }
}
