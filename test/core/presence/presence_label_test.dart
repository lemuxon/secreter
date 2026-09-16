import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/i18n/app_localizations.dart';
import 'package:gizli_chat/core/presence/presence.dart';

/// 👁️ SOHBET BAŞLIĞINDAKİ VARLIK SATIRI
///
/// ── NEDEN VAR ──
/// İki hata aynı anda ve ikisi de SESSİZCE duruyordu:
///
/// 1. **Yanlış çeviri anahtarı.** "yazıyor" için `typing_indicator`
///    okunuyordu — o bir AYAR BAŞLIĞIDIR ("Yazıyor göstergesi" /
///    "Typing indicator"). Başlıkta "Yazıyor göstergesi..." yazıyordu.
///    Hiçbir kapı düşmedi: anahtar 16 dilde tamdı, metin boş değildi,
///    analyzer temizdi. Yalnızca YANLIŞ anahtardı.
///
/// 2. **Türkçe dizeyle stil kararı.** Çağıran taraf
///    `text == 'yazıyor...'` ve `text == 'çevrimiçi'` diye
///    karşılaştırıyordu. Birincisi (1) yüzünden HİÇ tutmuyordu;
///    tutsaydı bile yalnızca Türkçede tutardı — diğer 15 dilde vurgu
///    sessizce kayboluyordu.
///
/// Sınıf tanıdık: *çalışmayan şey hata vermiyor, o yüzden görünmüyor.*
/// Kapı, metni ve TÜRÜ ayrı ayrı ölçüyor.
void main() {
  /// `context.tr` bir `BuildContext` ister; en ucuz gerçek bağlam bu.
  Future<PresenceLabel> olc(
    WidgetTester tester,
    PresenceInfo p, {
    String? forChatId,
    String dil = 'tr',
  }) async {
    late PresenceLabel sonuc;
    await tester.pumpWidget(MaterialApp(
      locale: Locale(dil),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale(dil)],
      home: Builder(builder: (context) {
        sonuc = presenceLabel(context, p, forChatId: forChatId);
        return const SizedBox();
      }),
    ));
    // ⚠️ `GlobalMaterialLocalizations.delegate.load()` ASENKRON. İlk
    // karede MaterialApp henüz gövdeyi kurmaz; ikinci pump olmadan
    // `Builder` hiç çalışmaz.
    await tester.pumpAndSettle();
    return sonuc;
  }

  testWidgets('YAZIYOR: ayar başlığını değil, durum metnini kullanır',
      (tester) async {
    final l = await olc(
      tester,
      const PresenceInfo(typingIn: 'sohbet1'),
      forChatId: 'sohbet1',
    );

    expect(l.kind, PresenceKind.typing);
    expect(l.text, 'yazıyor...');

    // 🔴 ASIL KAPI: ayar başlığı geri sızarsa düş.
    final ayarBasligi = AppLocalizations.valuesFor('tr')['typing_indicator']!;
    expect(l.text, isNot(contains(ayarBasligi)),
        reason: '"$ayarBasligi" bir AYAR BAŞLIĞIDIR; başlıkta durum metni '
            'olarak görünürse yanlış anahtar geri gelmiş demektir');
  });

  testWidgets('YAZIYOR: 16 dilin hiçbirinde ayar başlığını kullanmaz',
      (tester) async {
    for (final dil in AppLocalizations.keysByLanguage.keys) {
      final l = await olc(
        tester,
        const PresenceInfo(typingIn: 'sohbet1'),
        forChatId: 'sohbet1',
        dil: dil,
      );
      final v = AppLocalizations.valuesFor(dil);
      expect(l.text, '${v['presence_typing']}...', reason: 'dil: $dil');
      expect(l.text, isNot(contains(v['typing_indicator']!)),
          reason: '$dil: ayar başlığı durum satırına sızdı');
    }
  });

  testWidgets('YAZIYOR yalnızca O sohbette gösterilir', (tester) async {
    final l = await olc(
      tester,
      const PresenceInfo(typingIn: 'baska_sohbet', online: true),
      forChatId: 'sohbet1',
    );
    expect(l.kind, PresenceKind.online,
        reason: 'başka sohbette yazıyor olması bu sohbette gösterilemez — '
            'kiminle konuştuğu üstveridir');
  });

  testWidgets('ÇEVRİMİÇİ ve YAZIYOR vurgulanır, SON GÖRÜLME vurgulanmaz',
      (tester) async {
    // ⚠️ Vurgu artık metinden değil türden geliyor; bu yüzden TÜM
    // dillerde ölçülebiliyor. Eski hâlinde yalnızca Türkçede çalışıyordu.
    for (final dil in AppLocalizations.keysByLanguage.keys) {
      final yaziyor = await olc(tester, const PresenceInfo(typingIn: 'c'),
          forChatId: 'c', dil: dil);
      expect(yaziyor.vurgulu, isTrue, reason: '$dil: yazıyor vurgusuz');

      final cevrimici =
          await olc(tester, const PresenceInfo(online: true), dil: dil);
      expect(cevrimici.vurgulu, isTrue, reason: '$dil: çevrimiçi vurgusuz');

      final gorulme =
          await olc(tester, PresenceInfo(lastSeen: DateTime.now()), dil: dil);
      expect(gorulme.vurgulu, isFalse,
          reason: '$dil: son görülme, çevrimiçiyle aynı vurguda görünüyor');
    }
  });

  testWidgets('SON GÖRÜLME: bugün saat, dün ön eksiz, eskisi tarihli',
      (tester) async {
    final simdi = DateTime.now();

    final bugun = await olc(
        tester,
        PresenceInfo(
            lastSeen: DateTime(simdi.year, simdi.month, simdi.day, 14, 32)));
    expect(bugun.kind, PresenceKind.lastSeen);
    expect(bugun.text, 'son görülme 14:32');

    final dun = simdi.subtract(const Duration(days: 1));
    final dunL = await olc(tester,
        PresenceInfo(lastSeen: DateTime(dun.year, dun.month, dun.day, 9, 5)));
    // 📏 Ön ek BİLEREK yok — başlık payına sığmıyordu.
    expect(dunL.text, 'dün 09:05');

    final eski = await olc(
        tester, PresenceInfo(lastSeen: DateTime(simdi.year - 1, 2, 28, 3, 4)));
    expect(eski.text, 'son görülme 28.02',
        reason: 'yalnız tarih gösterilirse ne olduğu belirsiz kalır; '
            'ön ek burada KALMALI');
  });

  testWidgets('veri yoksa satır BOŞ döner (yer tutucu yazılmaz)',
      (tester) async {
    final l = await olc(tester, const PresenceInfo());
    expect(l.text, isEmpty);
    expect(l.kind, PresenceKind.none);
    expect(l.vurgulu, isFalse);
  });
}
