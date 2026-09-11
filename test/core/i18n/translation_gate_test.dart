import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';
import 'package:gizli_chat/core/i18n/locale_provider.dart';

/// 🚪 ÇEVİRİ KAPISI — eksik çeviri SESSİZCE birikemez.
///
/// ── NEDEN VAR ──
/// `AppLocalizations.t()` bulunmayan anahtarı İngilizce'ye düşürür.
/// Bu doğru bir davranış: arayüz asla boş görünmez, ham anahtar
/// ("err_send_message") ekrana çıkmaz. Ama bedeli şuydu: **eksik çeviri
/// hiçbir yerde görünmüyordu.**
///
/// `tr`+`en`'e bir anahtar eklemek diğer 14 dili sessizce geride
/// bırakıyordu ve kimse bakmadığı için açık **89 anahtara** kadar
/// büyümüştü — üstelik tam olarak en kritik anahtarlarda: şifreleme
/// hataları, root/hook tehdit uyarıları, grup anahtarı bandı ve
/// kurtarma anahtarı akışı. Rusça arayüz kullanan biri, mesajı
/// şifrelenemediğinde İngilizce bir uyarı görüyordu.
///
/// Bu, projede tekrar eden sınıfın ta kendisi: *çalışmayan bir şey hata
/// vermiyor, o yüzden aylarca görünmüyor.* Kapı, açığı ÖLÇÜLEBİLİR
/// kılar — bundan sonra eksik çeviri testi düşürür.
///
/// ── REFERANS NEDEN `en` ──
/// `en` yedek dildir: bir anahtar `en`'de yoksa kullanıcı ham anahtarı
/// görür. Bu yüzden kapsam ölçüsü `en`'in anahtar kümesidir.
void main() {
  final byLang = AppLocalizations.keysByLanguage;
  final ref = byLang['en']!;

  test('referans diller (tr, en) AYNI anahtar kümesini taşır', () {
    // İkisi birden elle yazılıyor; biri güncellenip diğeri unutulursa
    // yedek zinciri kopar.
    expect(byLang['tr'], isNotNull);
    expect(ref.difference(byLang['tr']!), isEmpty,
        reason: "en'de olup tr'de olmayan anahtar");
    expect(byLang['tr']!.difference(ref), isEmpty,
        reason: "tr'de olup en'de olmayan anahtar — İngilizce yedeği YOK, "
            'kullanıcı ham anahtarı görür');
  });

  test('HER dil referans anahtar setinin TAMAMINI taşır', () {
    final eksik = <String, List<String>>{};
    for (final entry in byLang.entries) {
      final miss = ref.difference(entry.value).toList()..sort();
      if (miss.isNotEmpty) eksik[entry.key] = miss;
    }

    expect(
      eksik,
      isEmpty,
      reason: 'Eksik çeviri var. Her biri kullanıcıya İNGİLİZCE görünür.\n'
          'Eksikleri listelemek için:\n'
          '  dart test test/core/i18n/translation_gate_test.dart\n'
          'Eksik: ${eksik.map((k, v) => MapEntry(k, '${v.length} anahtar: '
              '${v.take(5).join(", ")}${v.length > 5 ? "…" : ""}'))}',
    );
  });

  test('hiçbir dilde FAZLADAN anahtar yok', () {
    // Fazla anahtar = ya yazım hatası ya da silinmiş bir anahtarın
    // artığı. İkisi de ölü ağırlık; yazım hatası olanı ayrıca hiç
    // kullanılmaz ve kullanıcı ham anahtarı görür.
    for (final entry in byLang.entries) {
      final fazla = entry.value.difference(ref).toList()..sort();
      expect(fazla, isEmpty,
          reason: '${entry.key} dilinde referansta olmayan anahtar: $fazla');
    }
  });

  test('hiçbir çeviri BOŞ değil', () {
    // Boş dize `??` ile yakalanmaz — `t()` onu geçerli bir çeviri sayar
    // ve kullanıcı BOŞ bir düğme/uyarı görür. Yedeğe de düşmez.
    for (final lang in byLang.keys) {
      final values = AppLocalizations.valuesFor(lang);
      final bos = values.entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key)
          .toList()
        ..sort();
      expect(bos, isEmpty, reason: '$lang dilinde boş çeviri: $bos');
    }
  });

  test('desteklenen dil sayısı beklenen kadar', () {
    // Bir dil bloğu yanlışlıkla silinirse cihaz o dilde İngilizce'ye
    // düşer ve bu sessizdir.
    expect(byLang.keys.length, 16,
        reason: 'dil sayısı değişti: ${byLang.keys.toList()}');
  });

  test('DİL SEÇİCİ ile çeviri tablosu birebir örtüşür', () {
    // ⚠️ ASIL SESSİZ KIRILMA BURADA OLUR: `AppLanguages.all` dil
    // seçiciyi VE `MaterialApp.supportedLocales`i besliyor. Listeye
    // çeviri tablosunda karşılığı olmayan bir dil eklenirse, kullanıcı
    // onu bayrağıyla seçer ve arayüz tamamen İNGİLİZCE kalır — hiçbir
    // hata çıkmadan. Ters yön de sorunlu: tabloda olup listede olmayan
    // bir dil hiç seçilemez, yani boşa yazılmış çeviridir.
    final secici = AppLanguages.all.map((l) => l.code).toSet();
    expect(secici.difference(byLang.keys.toSet()), isEmpty,
        reason: 'seçicide sunulan ama ÇEVİRİSİ OLMAYAN dil');
    expect(byLang.keys.toSet().difference(secici), isEmpty,
        reason: 'çevrilmiş ama seçicide SUNULMAYAN dil');
  });

  test('çeviri anahtarları ASCII ve tutarlı biçimde', () {
    // `context.tr('...')` çağrılarıyla eşleşmeyen bir anahtar sessizce
    // ham metin döndürür; biçim tutarlılığı bunu azaltır.
    final bozuk = ref.where((k) => !RegExp(r'^[a-z0-9_]+$').hasMatch(k));
    expect(bozuk, isEmpty, reason: 'beklenmeyen anahtar biçimi: $bozuk');
  });
}
