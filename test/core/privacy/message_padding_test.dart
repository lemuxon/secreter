import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/privacy/message_padding.dart';

int bytes(String s) => utf8.encode(s).length;

void main() {
  group('MessagePadding', () {
    test('pad → unpad orijinal metni aynen döndürür', () {
      const cases = [
        '',
        'OK',
        'Merhaba dünya',
        'Boşlukla biten   ',
        '   boşlukla başlayan',
        'Özel karakterler: çğışöü 🔒 \n satır',
        'Pipe içeren | mesaj | tehlikeli',
        'P1|kendi önekimizi taşıyan metin',
        '3|abcdefgh',
        '2024|olaylar',
      ];
      for (final original in cases) {
        final padded = MessagePadding.pad(original);
        final restored = MessagePadding.unpad(padded);
        expect(restored, original, reason: 'Başarısız: "$original"');
      }
    });

    // ⚠️ ASIL GÜVENLİK ÖZELLİĞİ BAYT CİNSİNDENDİR.
    //
    // Eski test `padded.length` (UTF-16 karakter sayısı) karşılaştırıyordu
    // ve bu yüzden GERÇEK hatayı gizliyordu: dolgu karakter sayısına göre
    // yapıldığı için Türkçe/emoji içeren mesajlar şifrelendiğinde 64–256
    // bayt arasında değişiyor, yani şifreli metnin uzunluğu içerik
    // hakkında bilgi SIZDIRMAYA devam ediyordu. Şifreleme UTF-8 baytlar
    // üzerinde çalıştığı için doğru ölçüt bayt sayısıdır.
    test('kısa mesajlar AYNI BAYT boyutuna doldurulur (uzunluk gizlenir)', () {
      final samples = [
        'OK',
        'Merhaba nasılsın',
        'çğışöü ÇĞİŞÖÜ',
        '🔒🎉 emoji',
        'a',
        '',
      ];
      final sizes = samples.map((s) => bytes(MessagePadding.pad(s))).toSet();
      expect(sizes, {64},
          reason: 'Tüm kısa mesajlar 64 baytlık kovaya düşmeli, '
              'bulunan boyutlar: $sizes');
    });

    test('ÇOK BAYTLI karakterler kovayı büyütmez (regresyon)', () {
      // Aynı KARAKTER sayısı, farklı BAYT sayısı → dolgu sonrası eşit olmalı
      final ascii = MessagePadding.pad('aaaaaaaaaaaaaaaaaaaa'); // 20 bayt
      final turkish = MessagePadding.pad('şşşşşşşşşşşşşşşşşşşş'); // 40 bayt
      expect(bytes(ascii), bytes(turkish));
    });

    test('uzun mesaj bir üst kovaya çıkar', () {
      final short = MessagePadding.pad('kısa');
      final long = MessagePadding.pad('a' * 300);
      expect(bytes(long), greaterThan(bytes(short)));
      expect(bytes(long), 1024);
    });

    test('her kova sınırı tam olarak tutturulur', () {
      for (final size in [64, 256, 1024, 4096]) {
        // Kovanın hemen altını dolduran bir metin üret
        final text = 'a' * (size - 10);
        expect(bytes(MessagePadding.pad(text)), size,
            reason: '$size baytlık kova tutturulamadı');
      }
    });

    test('dolgusuz (eski) metin unpad ile değişmeden döner', () {
      const oldMessage = 'eski şifresiz mesaj';
      expect(MessagePadding.unpad(oldMessage), oldMessage);
    });

    // ⚠️ REGRESYON: eski `unpad` ilk '|' karakterini başlık ayırıcısı
    // sayıyordu. Dolgusuz bir mesaj "3|abcdefgh" biçimindeyse çözerken
    // "abc" olarak KIRPILIYORDU — sessiz veri bozulması.
    test('sayı+pipe ile başlayan eski metin BOZULMAZ', () {
      const traps = [
        '3|abcdefgh',
        '0|',
        '12|kısa',
        '2024|olaylar oldu',
        '5|merhaba dünya',
      ];
      for (final t in traps) {
        expect(MessagePadding.unpad(t), t, reason: 'Bozuldu: "$t"');
      }
    });

    test('çok uzun mesaj 4096 katına yuvarlanır', () {
      final huge = MessagePadding.pad('x' * 5000);
      expect(bytes(huge) % 4096, 0);
    });

    test('bozuk dolgu başlığı metni bozmadan döndürür', () {
      expect(MessagePadding.unpad('P1|abc|veri'), 'P1|abc|veri');
      expect(MessagePadding.unpad('P1|999999|kısa'), 'P1|999999|kısa');
      expect(MessagePadding.unpad('P1|'), 'P1|');
    });
  });
}
