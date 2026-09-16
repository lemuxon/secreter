import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';

/// ARAMADA IP AÇIKLAMASI — yumuşatıldı, SİLİNMEDİ.
///
/// ── NEDEN VAR ──
/// Rozet eskiden uyarı sarısıyla "IP adresin karşı tarafa görünüyor"
/// diyordu. Kullanıcılar bunu "arama güvensiz / bir şey bozuk" diye
/// okuyor ve rahatsız oluyordu — oysa doğrudan (P2P) bağlantı WebRTC'nin
/// normal hâlidir ve ses her iki durumda da şifrelidir.
///
/// Bu yüzden rozet kısa ve nötr bir etikete indirildi
/// ("Doğrudan bağlantı"), gerçek ödünleşim ise dokununca açılan
/// açıklamaya taşındı.
///
/// ⚠️ ASIL RİSK BURADA: "yumuşatma" adımı, bir sonraki elde sessizce
/// "kaldırma"ya dönüşebilir. TURN kurulana kadar IP paylaşımı GERÇEK bir
/// açıktır (TURN_KURULUMU.md) ve numara istemeyen bir uygulamada IP,
/// kimliğin en güçlü belirleyicilerinden biridir. Bunu kullanıcıdan
/// gizlemek yanıltmak olurdu.
///
/// Bu kapı, açıklamanın 16 dilin HİÇBİRİNDE boşalmamasını ve IP'den söz
/// etmeyi bırakmamasını garanti eder.
///
/// ───────────────────────────────────────────────────────────────────
/// 🔴 2026-09-16 — KAPININ KAPSAMI DARALDI. OKUMADAN GEÇME.
///
/// Yukarıda öngörülen şey OLDU: kullanıcı isteğiyle **birebir arama
/// ekranındaki dokunmalı açıklama kaldırıldı**
/// (`call_screen.dart:_buildPrivacyBadge`). Rozet artık yalnızca
/// "Doğrudan bağlantı" diyor; bilgi simgesi ve diyalog yok.
///
/// Yani bu dosyadaki `call_ip_visible_detail` / `call_ip_hidden_detail`
/// testleri artık **kullanıcıya ULAŞAN bir metni değil, yalnızca
/// sözlükte DURAN bir metni** ölçüyor. Bu tam olarak §4am'de yakalanan
/// sınıf: yeşil yanan ama hiçbir şey kanıtlamayan kapı. Yeşil olmaları
/// "kullanıcı IP'sinin paylaşıldığını öğreniyor" demek DEĞİLDİR.
///
/// Silmek yerine tutuluyorlar çünkü kararı geri almak `detail:`
/// argümanını geri eklemekten ibaret; metinler o gün 16 dilde hazır
/// olsun.
///
/// ✅ HÂLÂ GERÇEK KAPI: `group_call_*` testleri. Grup araması ekranı bu
/// değişikliğin dışında; mesh'te IP aramadaki HERKESE açıldığı için
/// açıklama orada duruyor ve gösteriliyor.
/// ───────────────────────────────────────────────────────────────────
void main() {
  final diller = AppLocalizations.keysByLanguage.keys.toList();

  String metin(String dil, String anahtar) =>
      AppLocalizations.valuesFor(dil)[anahtar] ?? '';

  test('16 dilin tamamı ölçülüyor', () {
    // Kapının kapsamı daralırsa (ör. bir dil bloğu düşerse) bunu bilmeliyiz;
    // aksi hâlde aşağıdaki testler "hiç dil yok" diye sessizce geçerdi.
    expect(diller.length, 16);
  });

  group('DOĞRUDAN bağlantı açıklaması', () {
    for (final dil in AppLocalizations.keysByLanguage.keys) {
      test('[$dil] IP paylaşımını AÇIKÇA söyler', () {
        final detay = metin(dil, 'call_ip_visible_detail');

        expect(detay, isNotEmpty,
            reason: 'açıklama boşsa rozet yalnızca "Doğrudan bağlantı" der '
                've kullanıcı IP\'sinin paylaşıldığını HİÇ öğrenemez');
        expect(detay.toUpperCase(), contains('IP'),
            reason: 'metni kısaltırken IP ibaresi düşerse yumuşatma, '
                'fiilen gizlemeye dönüşür');
      });
    }
  });

  group('AKTARMALI bağlantı açıklaması', () {
    for (final dil in AppLocalizations.keysByLanguage.keys) {
      test('[$dil] IP\'nin gizlendiğini söyler', () {
        final detay = metin(dil, 'call_ip_hidden_detail');
        expect(detay, isNotEmpty);
        expect(detay.toUpperCase(), contains('IP'));
      });
    }
  });

  // ── 👥 GRUP ARAMASI: AYNI AÇIK, DAHA GENİŞ ──
  //
  // Mesh'te her katılımcı diğer herkese DOĞRUDAN bağlanır. Yani birebir
  // aramada IP'n TEK kişiye açılırken, grup aramasında aramadaki
  // HERKESE açılır. Birebir aramanın metnini grupta kullanmak
  // ("karşı tarafa görünür") ödünleşimi olduğundan KÜÇÜK gösterirdi.
  //
  // Bu kapı iki şeyi birden zorunlu kılar: açıklama IP'den söz etmeyi
  // bırakmasın VE grup boyutunu (birden çok kişi) söylemeyi bırakmasın.
  group('GRUP araması — doğrudan bağlantı açıklaması', () {
    // "herkes/hepsi/tüm katılımcılar" fikrini taşıyan sözcükler.
    // Bir dilde metin yeniden yazılırsa ve çoğulluk düşerse test düşer.
    const cogulIzi = <String, List<String>>{
      'tr': ['herkes'],
      'en': ['everyone'],
      'ru': ['всем'],
      'ar': ['جميع'],
      'zh': ['所有人'],
      'fr': ['toutes'],
      'pt': ['todos'],
      'uk': ['усі'],
      'it': ['tutti'],
      // ⚠️ SONDAKİ SİGMA: Dart'ın `toLowerCase()`i Σ'yı her zaman σ'ya
      // çevirir, sözcük sonunda beklenen ς'ye DEĞİL. Tam sözcük aramak
      // bu yüzden tutmaz; kök yeter.
      'el': ['ολου'],
      'ja': ['全員'],
      'ko': ['모든'],
      'pl': ['wszystkim'],
      'sv': ['alla'],
      'fi': ['kaikkien'],
      'de': ['allen'],
    };

    for (final dil in AppLocalizations.keysByLanguage.keys) {
      test('[$dil] IP paylaşımını AÇIKÇA söyler', () {
        final detay = metin(dil, 'group_call_ip_visible_detail');
        expect(detay, isNotEmpty,
            reason: 'grup aramasında rozet açıklaması boşsa, kullanıcı '
                'IP\'sinin TÜM katılımcılara açıldığını hiç öğrenemez');
        expect(detay.toUpperCase(), contains('IP'));
      });

      test('[$dil] IP\'nin BİRDEN ÇOK kişiye açıldığını söyler', () {
        final detay = metin(dil, 'group_call_ip_visible_detail').toLowerCase();
        final izler = cogulIzi[dil]!;
        expect(izler.any(detay.contains), isTrue,
            reason: 'metin "karşı taraf" diline dönerse grup aramasının '
                'asıl ödünleşimi — IP\'nin HERKESE açılması — kaybolur');
      });

      test('[$dil] birebir metninin KOPYASI değil', () {
        // Aynı metni iki yere koymak, kapıyı geçmenin en kolay ama en
        // yanıltıcı yolu olurdu.
        expect(metin(dil, 'group_call_ip_visible_detail'),
            isNot(equals(metin(dil, 'call_ip_visible_detail'))));
      });
    }
  });

  group('GRUP araması — aktarmalı bağlantı açıklaması', () {
    for (final dil in AppLocalizations.keysByLanguage.keys) {
      test('[$dil] IP\'nin gizlendiğini söyler', () {
        final detay = metin(dil, 'group_call_ip_hidden_detail');
        expect(detay, isNotEmpty);
        expect(detay.toUpperCase(), contains('IP'));
      });
    }
  });

  group('rozet etiketi ile açıklama AYRI şeylerdir', () {
    for (final dil in AppLocalizations.keysByLanguage.keys) {
      test('[$dil] açıklama etiketin kopyası değil', () {
        // Açıklamayı etiketle aynı yapmak, bilgiyi geri getirmeden
        // kapıyı geçmenin en kolay yolu olurdu.
        for (final durum in ['visible', 'hidden']) {
          final etiket = metin(dil, 'call_ip_$durum');
          final detay = metin(dil, 'call_ip_${durum}_detail');
          expect(etiket, isNotEmpty);
          expect(detay, isNot(equals(etiket)));
          expect(detay.length, greaterThan(etiket.length * 2),
              reason: 'açıklama, rozete sığmayan ödünleşimi anlatmalı');
        }
      });
    }
  });
}
