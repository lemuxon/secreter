import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/widgets/full_screen_image.dart';

/// TEK GÖRÜNTÜLÜK FOTOĞRAF SINIRSIZ AÇILIYORDU (§4ba).
///
/// 🐞 GERÇEK KULLANICIDA ÖLÇÜLDÜ (2026-09-11): "Tek gönderimlik fotolar
/// bulanık da olsa sınırsız görülüyor. Bastıkça görebiliyorsun."
///
/// Sebep, kriptoda değil ROTA SONUCUNDAYDI. Tüketim şuna bağlı:
///
///     final seen = await FullScreenImage.open(...);   // pop sonucu
///     if (seen) onConsumeViewOnce(url);
///
/// `FullScreenImage` ise `PopScope(canPop: true, onPopInvokedWithResult:
/// (didPop, _) {})` kullanıyordu — yani geri tuşu/jesti rotayı
/// **sonuçsuz** kapatıyor, `open()` `seen ?? false` ile `false`
/// döndürüyor ve tüketim HİÇ tetiklenmiyordu. Sonucu yalnızca X düğmesi
/// döndürüyordu; Android'de doğal çıkış yolu ise geri jestidir.
///
/// Yani "bir kez görülür" sözü pratikte hiç işlemiyordu.
void main() {
  Future<bool?> ac(WidgetTester tester) async {
    bool? sonuc;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            sonuc = await FullScreenImage.open(context, 'https://ornek/x.jpg');
          },
          child: const Text('aç'),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return sonuc;
  }

  testWidgets('🔴 geri tuşu rotayı SONUÇSUZ kapatamaz', (tester) async {
    await ac(tester);

    final kapsam = tester.widget<PopScope<bool>>(find.byType(PopScope<bool>));

    expect(kapsam.canPop, isFalse,
        reason: '`canPop: true` olursa geri tuşu rotayı sonuçsuz kapatır; '
            'tüketim tetiklenmez ve fotoğraf sınırsız açılır');
    expect(kapsam.onPopInvokedWithResult, isNotNull,
        reason: 'geri çağrısı boş bırakılırsa sonuç yine bildirilmez');
  });

  testWidgets('geri çağrısı rotayı sonucu BİLDİREREK kapatır', (tester) async {
    bool? sonuc;
    var dondu = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            sonuc = await FullScreenImage.open(context, 'https://ornek/x.jpg');
            dondu = true;
          },
          child: const Text('aç'),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(dondu, isFalse, reason: 'ekran hâlâ açık olmalı');

    // Geri jestini taklit et: framework `didPop: false` ile haber verir.
    tester
        .widget<PopScope<bool>>(find.byType(PopScope<bool>))
        .onPopInvokedWithResult!(false, null);
    await tester.pumpAndSettle();

    expect(find.byType(PopScope<bool>), findsNothing,
        reason: 'geri çağrısı rotayı KAPATMALI — kapatmazsa kullanıcı '
            'ekrandan çıkamaz');
    expect(dondu, isTrue,
        reason: 'sonuç bildirilmezse `open()` hiç dönmez ve tüketim '
            'kararı verilemez');
    expect(sonuc, isFalse);
  });

  testWidgets('resim ÇİZİLMEDİYSE hak yanmaz', (tester) async {
    // Testte ağ/dosya yok → görüntü hiç çizilemez → "görüldü" sayılmamalı.
    // ⚠️ Eskiden bu, kareden 600 ms sonra KOŞULSUZ true oluyordu; yani
    // çözülemeyen bir fotoğraf da tüketilebiliyordu.
    bool? sonuc;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            sonuc = await FullScreenImage.open(context, 'https://ornek/x.jpg');
          },
          child: const Text('aç'),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // eski 600 ms'i AŞAR

    tester
        .widget<PopScope<bool>>(find.byType(PopScope<bool>))
        .onPopInvokedWithResult!(false, null);
    await tester.pumpAndSettle();

    expect(sonuc, isFalse,
        reason: 'çizilmeyen görüntü "görüldü" sayılırsa kullanıcı hiç '
            'görmediği tek görüntülük fotoğrafı kaybeder');
  });
}
