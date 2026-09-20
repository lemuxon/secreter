import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';
import 'package:gizli_chat/features/messaging/data/datasources/encryption_datasource.dart';

/// ♻️ YENİDEN GÖNDERİM İSTEĞİ (§4cl) — SÖZLEŞME KAPISI
///
/// ── NEDEN VAR ──
/// §4cc oturumu onarıyordu ama İÇERİĞİ kurtarmıyordu. Sahada bedeli
/// ölçüldü (§4ck): testçi B'nin iki mesajı kalıcı kayboldu ve gönderenin
/// istemcisi bunu hiç öğrenmedi.
///
/// Bu kapı, kurtarmanın **kullanıcıya doğru şeyi söylemesini** koruyor.
/// Ağ/Firestore davranışı burada test EDİLEMEZ (emülatör işi, kural
/// testleri orada); burada sözleşme ölçülüyor.
void main() {
  group('iki işaret AYRI şeyler söyler', () {
    test('işaretler birbirinden farklı', () {
      // 🔴 KAPININ KALBİ. İkisi eşitlenirse arayüz "kalıcı gitti" ile
      // "tekrarı istendi, yolda"yı ayırt EDEMEZ ve vakaların yarısında
      // kullanıcıya yanlış bilgi verir.
      expect(EncryptionDataSource.lostMarker,
          isNot(equals(EncryptionDataSource.lostRetryMarker)));
    });

    test('ikisi de NUL ile başlar — kullanıcı metniyle çarpışamaz', () {
      // Gerçek bir mesaj bu değerlerle başlayamaz; yoksa kullanıcının
      // yazdığı metin "çözülemedi" balonuna dönüşürdü.
      for (final m in [
        EncryptionDataSource.lostMarker,
        EncryptionDataSource.lostRetryMarker,
      ]) {
        expect(m.codeUnitAt(0), 0, reason: '"$m" NUL ile başlamıyor');
      }
    });

    test('biri diğerinin ÖNEKİ değil', () {
      // `startsWith` ile karşılaştıran bir kod ileride eklenirse, önek
      // ilişkisi iki durumu sessizce birbirine karıştırırdı.
      expect(
          EncryptionDataSource.lostRetryMarker
              .startsWith(EncryptionDataSource.lostMarker),
          isFalse,
          reason: 'tekrar işareti, kayıp işaretiyle başlıyor — önek '
              'karşılaştırması ikisini karıştırır');
    });
  });

  group('metinler', () {
    test('16 dilde tekrar metni var ve BOŞ değil', () {
      for (final dil in AppLocalizations.keysByLanguage.keys) {
        final v = AppLocalizations.valuesFor(dil)['e2ee_lost_retry'];
        expect(v, isNotNull, reason: '$dil dilinde e2ee_lost_retry yok');
        expect(v!.trim(), isNotEmpty, reason: '$dil dilinde metin boş');
      }
    });

    test('tekrar metni, kalıcı kayıp metninin KOPYASI değil', () {
      // Aynı metni iki yere koymak, kapıyı geçmenin en kolay ama en
      // yanıltıcı yolu olurdu: ayrım kodda kalır, kullanıcıda kaybolur.
      for (final dil in AppLocalizations.keysByLanguage.keys) {
        final v = AppLocalizations.valuesFor(dil);
        expect(v['e2ee_lost_retry'], isNot(equals(v['e2ee_lost'])),
            reason: '$dil: iki durum aynı metni gösteriyor');
      }
    });

    test('kalıcı kayıp metni "tekrar gelecek" VAAT ETMEZ', () {
      // Türkçe/İngilizce örneklem: kalıcı kayıp metni umut vermemeli,
      // çünkü o vakada gerçekten gelmeyecek.
      for (final dil in ['tr', 'en']) {
        final kalici = AppLocalizations.valuesFor(dil)['e2ee_lost']!;
        expect(kalici.toLowerCase(), isNot(contains('tekrar')));
        expect(kalici.toLowerCase(), isNot(contains('again')));
      }
    });
  });
}
