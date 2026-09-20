import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';
import 'package:gizli_chat/core/proje_kimligi.dart';

/// 📖 "AÇIK KAYNAK" İDDİASI DOĞRULANABİLİR OLMALI
///
/// ── NEDEN VAR ──
/// Kullanıcı şunu istedi: *"İnsanların uygulamanın açık kaynak olduğunu
/// bilmesini istiyorum."* İstek meşru ama bir sırası var: 2026-09-20'de
/// proje açık kaynak DEĞİLDİ — `LICENSE` yoktu, uzak depo yoktu.
///
/// Gizlilik iddiası taşıyan bir uygulamada "açık kaynak" yazıp kodu
/// yayımlamamak, güven kazandırmaz; biri kontrol etmek isteyip hiçbir
/// şey bulamayınca **en çok o iddia zarar görür.**
///
/// Bu kapı, iddianın kendi kendini tutmasını sağlıyor: arayüz satırı
/// `depoAdresi` boşken ÇİZİLMEZ. Yani iddia, ancak gidip bakılabilecek
/// bir adres varsa ortaya çıkar — unutkanlığa değil, koda bağlı.
///
/// ⚠️ Bu dosyayı "artık gerek yok" diye gevşetme. Depo adresi bir gün
/// geri alınırsa (özel yapılırsa, taşınırsa) iddia da kendiliğinden
/// geri çekilmeli.
void main() {
  group('iddia ile kanıt birbirine bağlı', () {
    test('adres YOKSA arayüz "açık kaynak" DEMEZ', () {
      // Kapının kalbi: boş adres → gösterme yok.
      expect(acikKaynakGosterilebilir, depoAdresi.trim().isNotEmpty,
          reason: 'gösterim kararı, adresin varlığından BAŞKA bir şeye '
              'bağlanmış — iddia kanıttan koptu');
    });

    test('adres VARSA gerçek bir bağlantı olmalı', () {
      if (depoAdresi.trim().isEmpty) return; // henüz yayımlanmadı
      final u = Uri.tryParse(depoAdresi);
      expect(u, isNotNull, reason: 'depoAdresi ayrıştırılamıyor');
      expect(u!.scheme, 'https',
          reason: 'düz http bağlantısı doğrulanabilirlik sağlamaz');
      expect(u.host, isNotEmpty);
      expect(depoAdresi, isNot(contains(' ')));
    });
  });

  group('lisans', () {
    test('LICENSE dosyası VAR ve boş değil', () {
      final f = File('LICENSE');
      expect(f.existsSync(), isTrue,
          reason: 'lisanssız kod hukuken "tüm hakları saklı"dır; '
              'yayımlamak onu açık kaynak YAPMAZ');
      expect(f.lengthSync(), greaterThan(1000),
          reason: 'lisans metni eksik görünüyor');
    });

    test('LICENSE, koddaki lisans adıyla AYNI şeyi söylüyor', () {
      // İkisinin ayrışması sessiz bir yanlış beyandır: arayüz bir şey
      // der, dosya başka bir şey.
      final metin = File('LICENSE').readAsStringSync();
      expect(lisansAdi, 'AGPL-3.0');
      expect(metin, contains('GNU AFFERO GENERAL PUBLIC LICENSE'),
          reason: 'arayüz $lisansAdi diyor ama LICENSE başka bir lisans');
      expect(metin, contains('Version 3, 19 November 2007'));
    });
  });

  group('çeviriler', () {
    test('16 dilin tamamında HAKKINDA anahtarları var', () {
      for (final dil in AppLocalizations.keysByLanguage.keys) {
        final v = AppLocalizations.valuesFor(dil);
        for (final k in ['sec_about', 'open_source', 'open_source_sub']) {
          expect(v[k], isNotNull, reason: '$dil dilinde $k yok');
          expect(v[k]!.trim(), isNotEmpty, reason: '$dil dilinde $k boş');
        }
      }
    });

    test('lisans adı METNE GÖMÜLÜ değil, yer tutucuyla geliyor', () {
      // Lisans bir gün değişirse 16 dili tek tek düzeltmek gerekmesin —
      // ve daha kötüsü, biri unutulup YANLIŞ lisans göstermesin.
      for (final dil in AppLocalizations.keysByLanguage.keys) {
        final metin = AppLocalizations.valuesFor(dil)['open_source_sub']!;
        expect(metin, contains('{lisans}'),
            reason: '$dil: yer tutucu yok, lisans adı metne gömülmüş');
        expect(metin, isNot(contains('AGPL')),
            reason: '$dil: lisans adı sabit yazılmış');
      }
    });
  });
}
