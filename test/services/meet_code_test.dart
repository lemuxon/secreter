import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/services/meet_code_service.dart';

/// 🐞 BULUŞMA KODU — uygulama KENDİ ÜRETTİĞİ biçimi kabul etmiyordu
///
/// Kod ekranda ve panoda tireli gösteriliyor (`ABCD-EFGH`) ve giriş
/// alanının ipucu da aynen `ABCD-EFGH` yazıyor. Ama ayrıştırıcı yalnızca
/// BOŞLUK siliyordu; tireli kod 9 karakter olduğu için uzunluk
/// kontrolüne takılıyor ve kullanıcı "geçersiz kod" alıyordu.
/// Tireyi elle silmek zorundaydı.
void main() {
  group('kod normalleştirme', () {
    test('KOPYALANAN tireli biçim kabul edilir', () {
      // ⚠️ Asıl hata buydu: `pretty` biçimi panoya yazılıyor ama
      // ayrıştırıcı reddediyordu.
      expect(MeetCodeService.normalize('ABCD-EFGH'), 'ABCDEFGH');
    });

    test('boşluklu yapıştırma çalışır', () {
      expect(MeetCodeService.normalize(' ABCD EFGH '), 'ABCDEFGH');
      expect(MeetCodeService.normalize('ABCD\nEFGH'), 'ABCDEFGH');
    });

    test('küçük harf yazım çalışır', () {
      expect(MeetCodeService.normalize('abcd-efgh'), 'ABCDEFGH');
    });

    test('düz kod bozulmadan geçer', () {
      expect(MeetCodeService.normalize('ABCDEFGH'), 'ABCDEFGH');
    });

    test('rakamlar korunur', () {
      expect(MeetCodeService.normalize('AB23-4789'), 'AB234789');
    });

    test('noktalama ve görünmez karakterler atılır', () {
      expect(MeetCodeService.normalize('A.B,C D–E\tF/G_H'), 'ABCDEFGH');
    });

    test('ALFABEDE OLMAYAN HARF ATILMAZ', () {
      // ⚠️ Bilinçli sınır. `S` buluşma kodu alfabesinde yok ama silmek
      // kalan karakterleri kaydırıp BAŞKASININ geçerli koduna
      // dönüştürebilirdi. Yanlış kod dürüstçe "bulunamadı" demeli.
      expect(MeetCodeService.normalize('ABCS-EFGH'), 'ABCSEFGH');
    });

    test('tamamen geçersiz girdi boş döner (uzunluk kontrolüne takılır)', () {
      expect(MeetCodeService.normalize('---'), isEmpty);
      expect(MeetCodeService.normalize(''), isEmpty);
    });
  });

  group('gösterim biçimi', () {
    test('8 karakterlik kod 4+4 gösterilir', () {
      final c = MeetCode(
          code: 'ABCDEFGH',
          expiresAt: DateTime.now().add(const Duration(hours: 1)));
      expect(c.pretty, 'ABCD-EFGH');
    });

    test('gösterim biçimi geri normalleştirilebilir (gidiş-dönüş)', () {
      // Bu testin kırılması, hatanın geri geldiği anlamına gelir.
      final c = MeetCode(
          code: 'AB234789',
          expiresAt: DateTime.now().add(const Duration(hours: 1)));
      expect(MeetCodeService.normalize(c.pretty), c.code);
    });
  });
}
