import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/media/attachment_crypto.dart';
import 'package:gizli_chat/features/messaging/data/datasources/encryption_datasource.dart';

/// 🖼️ ÇÖZÜLEMEYEN MEDYA "BOZUK RESİM" DEĞİL, "ÇÖZÜLEMEDİ" GÖSTERİR
///
/// ── GERÇEK ŞİKÂYET ──
/// *"Galeri resimleri açılmıyor ama video gelmiş"* — aynı sohbette bazı
/// mesajlar da "çözülemedi" diyordu. İkisi AYNI KÖKTEN geliyordu.
///
/// Ek anahtarı mesajın ŞİFRELİ `content`i içinde taşınır:
///
///     content (E2EE) → "ATT1|<anahtar>|<açıklama>"
///
/// İçerik çözülemezse anahtar da çıkmaz. Eski kod bu durumda mesajı
/// olduğu gibi bırakıyordu; `mediaKey` null kalınca `SecureMediaImage`
/// eki ŞİFRESİZ sanıp ham URL'i indiriyor ve şifreli baytları çözmeye
/// çalışıyordu → **kırık resim simgesi.**
///
/// Kullanıcıya "ağ sorunu / bozuk dosya" gibi görünen şey, aslında metin
/// mesajlarındakiyle AYNI durumdu. Metinde dürüst bir kutu gösteriliyor,
/// medyada gösterilmiyordu.
///
/// Bu dosya ayrımı kilitler: nöbetçi metin bir ek göndergesiyle
/// KARIŞTIRILAMAZ, ve eski biçimli (şifresiz) ekler bozulmadan kalır.
void main() {
  group('çözülemeyen içerik ek göndergesi sanılmaz', () {
    test('nöbetçi metin ek göndergesi olarak AYRIŞTIRILAMAZ', () {
      // Ayrıştırılabilseydi, çözülememiş bir mesajdan "anahtar" üretilir
      // ve medya katmanı çöp bir anahtarla çözmeye çalışırdı.
      expect(
        AttachmentRef.tryParse(EncryptionDataSource.lostMarker),
        isNull,
      );
    });

    test('geçerli ek göndergesi ayrıştırılır', () {
      final ref = AttachmentRef.tryParse(
          const AttachmentRef(key: 'k123', caption: 'merhaba').encode());
      expect(ref, isNotNull);
      expect(ref!.key, 'k123');
      expect(ref.caption, 'merhaba');
    });

    test('açıklamasız ek göndergesi de ayrıştırılır', () {
      final ref =
          AttachmentRef.tryParse(const AttachmentRef(key: 'k123').encode());
      expect(ref?.key, 'k123');
      expect(ref?.caption, isEmpty);
    });

    test('ESKİ BİÇİMLİ içerik ek göndergesi DEĞİLDİR', () {
      // ⚠️ Bu ayrım önemli: çözülüp de ayrıştırılamayan içerik eski
      // biçimli (şifresiz) bir ektir ve davranışı KORUNMALI. Yalnızca
      // ÇÖZÜLEMEME durumu "çözülemedi" diye işaretlenir; ikisi
      // karıştırılırsa eski mesajların medyası açılmaz olur.
      expect(AttachmentRef.tryParse('sadece düz bir başlık'), isNull);
      expect(AttachmentRef.tryParse(''), isNull);
    });

    test('bozuk gönderge ayrıştırılamaz', () {
      // Ayırıcısı olmayan gövde: anahtarın nerede bittiği bilinemez.
      expect(AttachmentRef.tryParse('ATT1|anahtarsiz'), isNull);
      expect(AttachmentRef.tryParse('ATT1||aciklama'), isNull);
    });
  });

  group('nöbetçi arayüzün tanıdığı değerdir', () {
    test('medya dalı ile metin dalı AYNI nöbetçiyi kullanır', () {
      // Medya mesajı çözülemediğinde içeriği bu değere ayarlanıyor;
      // arayüz de "çözülemedi" kutusunu bu değerle tanıyor
      // (`messaging_screen.dart`). İkisi ayrışırsa kullanıcı ekranda
      // ham nöbetçi metnini görür.
      expect(EncryptionDataSource.lostMarker, '\u0000E2EE_LOST');
      expect(EncryptionDataSource.lostMarker.codeUnitAt(0), 0);
    });
  });
}
