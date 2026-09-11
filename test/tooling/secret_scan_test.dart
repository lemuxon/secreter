import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🔐 DEPO HİJYENİ — gömülü sır ve ölü dosya taraması
///
/// ── NEDEN VAR ──
/// Bu iki kontrol, projede GERÇEKTEN yaşanmış iki hata sınıfını
/// makineye devreder:
///
/// 1. **Gömülü sır.** Denetimde imzalama parolası ve Giphy anahtarı
///    ifşa oldu. `.gitignore` yalnızca DOSYA sızıntısını engeller;
///    birinin anahtarı doğrudan bir `.dart` dosyasına yazmasını
///    engellemez.
///
/// 2. **Ölü dosya.** Bu projede ölü kod ÜÇ kez gerçek hataya yol açtı:
///    `chat_service.dart` + eski `message_model.dart`,
///    `models/chat_model.dart` (§4o) ve `conversations_screen.dart`.
///    Tehlike yer kaplaması değil — bir sonraki geliştirici onu CANLI
///    sanıp düzeltir ve düzeltme hiçbir şey yapmaz. §4u'da tam olarak
///    bu oldu ve kırık hâliyle üretime çıktı.
List<String> _dartFiles(String root) {
  final d = Directory(root);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => p.endsWith('.dart'))
      .toList();
}

void main() {
  group('koda gömülü sır yok', () {
    // Taranmayacaklar ve GEREKÇELERİ:
    const skipDirs = {
      'build',
      '.dart_tool',
      'node_modules',
      '.git',
      '.idea',
      'symbols',
    };
    const skipFiles = {
      // Gerçek parolayı taşır ama `.gitignore`da; yeri burasıdır.
      'key.properties',
      // Firebase İSTEMCİ anahtarları sır DEĞİLDİR (uygulamaya gömülmek
      // üzere tasarlanmışlardır). Korunma yolu gizlemek değil, Google
      // Cloud Console'da UYGULAMA KISITLAMASI tanımlamaktır.
      'google-services.json',
      'firebase_options.dart',
      // Kendi kendini tarayan dosya.
      'secret_scan_test.dart',
    };

    final patterns = <String, RegExp>{
      'Google API anahtarı': RegExp(r'AIza[0-9A-Za-z_\-]{35}'),
      'PEM özel anahtar': RegExp(r'BEGIN (RSA |EC )?PRIVATE KEY'),
      // ⚠️ TÜRKÇE ADLAR DA TARANIR. Bu depoda değişkenler Türkçe
      // adlandırılıyor; kalıp yalnızca İngilizce adlara baksaydı
      // `const sir = '...'` ya da `parola: '...'` taramadan KAÇARDI —
      // yani korumanın en çok gerektiği yerde, projenin kendi
      // diliyle yazılmış kodda deliği olurdu.
      'gömülü parola/sır ataması': RegExp(
        r'''(password|passwd|secret|apiKey|api_key|authToken|privateKey'''
        r'''|parola|sifre|şifre|gizliAnahtar|gizli_anahtar)'''
        r'''\s*[:=]\s*['"][^'"$]{12,}['"]''',
        caseSensitive: false,
      ),
    };

    test('lib/, android/, functions/, tools/ taranır', () {
      final bulgular = <String>[];

      void tara(Directory dir) {
        if (!dir.existsSync()) return;
        for (final e in dir.listSync(recursive: true, followLinks: false)) {
          if (e is! File) continue;
          final yol = e.path.replaceAll(r'\', '/');
          if (skipDirs.any((d) => yol.contains('/$d/'))) continue;
          final ad = yol.split('/').last;
          if (skipFiles.contains(ad)) continue;
          if (!RegExp(r'\.(dart|js|json|kts|gradle|properties|xml|yaml)$')
              .hasMatch(ad)) {
            continue;
          }
          final metin = e.readAsStringSync();
          patterns.forEach((isim, kalip) {
            final m = kalip.firstMatch(metin);
            if (m != null) {
              final satir =
                  '\n'.allMatches(metin.substring(0, m.start)).length + 1;
              // ⚠️ Bulunan DEĞER yazdırılmaz — hata mesajı da bir sızıntı
              // yüzeyidir (CI günlükleri çoğu zaman herkese açıktır).
              bulgular.add('$yol:$satir — $isim');
            }
          });
        }
      }

      tara(Directory('lib'));
      tara(Directory('android'));
      tara(Directory('functions'));
      // tools/ — üretim verisine dokunan tek seferlik script'ler burada.
      // Servis hesabı anahtarının yapıştırılması en muhtemel yer burasıdır;
      // taramanın dışında kalması, korumanın en çok gerektiği yerde
      // yokluğu demekti.
      tara(Directory('tools'));

      expect(bulgular, isEmpty,
          reason: 'Koda gömülü sır bulundu. Değeri BURAYA YAZMA; sırrı '
              '--dart-define ya da ortam değişkenine taşı ve DÖNDÜR:\n'
              '${bulgular.join('\n')}');
    });

    test('Giphy anahtarı derleme zamanından gelir, GÖMÜLÜ değil', () {
      // ⚠️ REGRESYON KORUMASI. Eski anahtar yayınlanmış APK'lara
      // gömülüydü; aynı hatanın tekrarı sessiz olurdu.
      final src = File('lib/core/gif/giphy_service.dart').readAsStringSync();
      expect(src, contains("String.fromEnvironment('GIPHY_API_KEY'"),
          reason: 'Giphy anahtarı derleme zamanı ortamından okunmalı');
      expect(src, isNot(RegExp(r"defaultValue:\s*'[^']{8,}'")),
          reason: 'Gömülü yedek anahtar OLMAMALI');
    });

    test('.gitignore imzalama dosyalarını korur', () {
      final gi = File('.gitignore').readAsStringSync();
      for (final z in ['key.properties', '*.jks', '*.keystore']) {
        expect(gi, contains(z), reason: '$z .gitignore içinde değil');
      }
    });
  });

  group('ölü dosya yok', () {
    test('lib/ altında hiçbir yerden import EDİLMEYEN dosya yok', () {
      final kaynak = <String, String>{};
      for (final kok in ['lib', 'test', 'integration_test']) {
        for (final p in _dartFiles(kok)) {
          kaynak[p] = File(p).readAsStringSync();
        }
      }

      final yetim = <String>[];
      for (final yol in kaynak.keys) {
        if (!yol.startsWith('lib/')) continue;
        // Giriş noktası: kimse import etmez, etmemeli.
        if (yol == 'lib/main.dart') continue;

        final ad = yol.split('/').last;
        final paket = 'package:gizli_chat/${yol.substring(4)}';

        // Regex yerine düz metin: bir import satırı dosya adını daima
        // kapanış tırnağından hemen önce taşır (`.../injection.dart'`).
        // Kaçış kurallarıyla uğraşmadan aynı işi görür ve yanlış
        // pozitif üretmez.
        final izGoreli = "$ad'";
        final izCift = '$ad"';

        final kullanildi = kaynak.entries.any((e) =>
            e.key != yol &&
            (e.value.contains(izGoreli) ||
                e.value.contains(izCift) ||
                e.value.contains(paket)));
        if (!kullanildi) yetim.add(yol);
      }

      expect(yetim, isEmpty,
          reason: 'Hiçbir yerden import edilmeyen dosya(lar) var. Bir '
              'sonraki geliştirici bunları CANLI sanıp üzerinde '
              'çalışabilir; sil ya da bağla:\n${yetim.join('\n')}');
    });
  });
}
