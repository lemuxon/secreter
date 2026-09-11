import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/features/messaging/data/datasources/encryption_datasource.dart';
import 'package:gizli_chat/features/messaging/data/datasources/encryption_datasource_impl.dart';

/// ÇÖZÜLEMEDİ NÖBETÇİSİ tek değerdir (§4az).
///
/// 🐞 NEREDEYSE KIRILIYORDU: nöbetçi kaynakta `'\u0000E2EE_LOST'` gibi
/// görünüyor ama baştaki karakter BOŞLUK DEĞİL, **NUL** (U+0000). Sabiti
/// arayüze taşırken boşlukla yeniden yazıldı; değer sessizce değişmişti.
///
/// Bu neden tehlikeli: arayüz katmanı çözülemeyen mesajı
/// `msg.content == '\u0000E2EE_LOST'` karşılaştırmasıyla tanıyor
/// (`messaging_screen.dart`). Nöbetçi kayarsa karşılaştırma tutmaz ve
/// kullanıcı "bu mesaj çözülemiyor" uyarısı yerine **ekranda ham
/// nöbetçi metnini** görür. Derleyici bunu yakalamaz — iki taraf da
/// geçerli String'dir.
///
/// NUL bilinçli seçilmiştir: hiçbir gerçek kullanıcı metni onunla
/// başlayamayacağı için nöbetçi, meşru bir mesajla ASLA çarpışmaz.
void main() {
  test('nöbetçi NUL ile başlar — boşlukla DEĞİL', () {
    expect(EncryptionDataSource.lostMarker.codeUnitAt(0), 0,
        reason: 'boşluğa (0x20) dönerse gerçek bir mesaj nöbetçiyle '
            'çarpışabilir ve yanlışlıkla "çözülemedi" gösterilir');
    expect(EncryptionDataSource.lostMarker.codeUnitAt(0), isNot(0x20));
  });

  test('nöbetçinin TAM değeri sabittir', () {
    // Arayüz katmanındaki karşılaştırma bu değere gömülü.
    expect(EncryptionDataSource.lostMarker, '\u0000E2EE_LOST');
  });

  test('impl ile arayüz AYNI değeri kullanır', () {
    expect(EncryptionDataSourceImpl.lostMarker, EncryptionDataSource.lostMarker,
        reason: 'iki ayrı sabit tanımı kaçınılmaz olarak birbirinden '
            'ayrışır; impl arayüzü göstermeli');
  });
}
