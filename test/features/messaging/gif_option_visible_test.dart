import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';

/// GIF/ÇIKARTMA SEÇENEĞİ SESSİZCE KAYBOLAMAZ (§4bc).
///
/// 🐞 GERÇEK KULLANICIDA YAŞANDI (2026-09-11): *"Mesajlara çıkartma ve gif
/// gönderme sekmesi neden silindi??"*
///
/// Silinmemişti — GİZLENMİŞTİ. Ek menüsündeki iki seçenek
/// `if (GiphyService.isEnabled)` ile sarılmıştı. Gerekçe makuldü:
/// anahtarsız derlemede sekme açılıp BOŞ kalıyordu. Ama hiçbir derlemeye
/// `--dart-define=GIPHY_API_KEY` konmadığı için özellik kullanıcıdan
/// TAMAMEN kayboldu ve kimse nedenini öğrenemedi.
///
/// ── ALINAN DERS ──
/// Sessizce yok olan özellik, hata mesajından KÖTÜDÜR. Kullanıcı
/// "bozuk" demez, "silinmiş" der ve haklıdır. Seçenek durmalı; açıldığında
/// neden çalışmadığı yazmalı.
///
/// Bu kapı, aynı "koşullu gizleme" çözümünün sessizce geri gelmesini
/// engeller. Kaynak taraması, bu kod tabanındaki yerleşik bir yöntemdir
/// (bkz. `test/tooling/secret_scan_test.dart`).
void main() {
  final ekran = File('lib/features/messaging/presentation/screens/'
      'messaging_screen.dart');

  test('ek menüsü GIF seçeneğini KOŞULA BAĞLAMAZ', () {
    expect(ekran.existsSync(), isTrue, reason: 'ekran dosyası taşınmış');
    final kaynak = ekran.readAsStringSync();

    expect(kaynak, contains("opt(Icons.gif_box_outlined, 'GIF'"),
        reason: 'GIF seçeneği ek menüsünden kaldırılmış');

    expect(kaynak, isNot(contains('if (GiphyService.isEnabled) ...[')),
        reason: 'seçeneği koşullu gizlemek, özelliğin kullanıcıdan sessizce '
            'kaybolmasına yol açıyordu — kapalıysa AÇIKLAMA gösterilmeli');
  });

  test('kapalıyken gösterilecek açıklama 16 dilde VAR', () {
    // Açıklama eksikse arayüz yine boş bir sayfa gösterirdi; yani
    // düzeltme yalnızca metinle birlikte anlamlı.
    final diller = AppLocalizations.keysByLanguage;
    expect(diller.length, 16);

    for (final giris in diller.entries) {
      final metin = AppLocalizations.valuesFor(giris.key);
      expect(metin['gif_unavailable'], isNotNull,
          reason: '[${giris.key}] başlık yok');
      expect(metin['gif_unavailable']!.trim(), isNotEmpty);
      expect(metin['gif_unavailable_detail'], isNotNull,
          reason: '[${giris.key}] açıklama yok');
      expect(metin['gif_unavailable_detail']!.trim(), isNotEmpty);
    }
  });
}
