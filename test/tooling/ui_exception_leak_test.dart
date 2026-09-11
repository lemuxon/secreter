import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🚪 HAM İSTİSNA ARAYÜZE BASILAMAZ — KALICI KAPI
///
/// ── NEDEN VAR ──
/// §4q "ham istisna sızıntısı 43 → 0" diye kapatılmıştı. §4ao'da
/// yeniden ölçüldü: **10 yer** ham istisnayı kullanıcıya gösteriyordu
/// (`SnackBar(content: Text('$e'))` ve benzeri). Yani sayı sıfırlanmış
/// ama sıfır kalmasını sağlayan bir şey yokmuş.
///
/// Neden önemli — bu kozmetik değil, METADATA SIZINTISI:
///
///     [cloud_firestore/permission-denied] ... /chats/uidA_uidB/messages/m1
///
/// Firestore hataları doküman YOLU taşır. Birebir sohbet kimliği
/// `sıralı(uid1,uid2)` olduğu için bu metin **iki tarafın uid'ini**
/// ekrana basar. Hata ekranları paylaşılır, ekran görüntüsü alınır.
/// §4o'nun sohbet dokümanından kullanıcı adlarını temizlemek için
/// harcadığı iş, tek bir hata mesajıyla geri verilir.
///
/// ── DOĞRU DESEN ──
/// Ayrıntı `reportHandled`a (yerel + imzalı telemetri), kullanıcıya
/// çevrilmiş bir metin: `context.tr('err_...')`.
void main() {
  test('lib/ içinde arayüze ham istisna basan satır YOK', () {
    // `Text(...)` ya da `SnackBar(...)` içeren bir satırda `$e`,
    // `${e}` ya da `e.toString()` görünüyorsa istisna ekrana gidiyor
    // demektir.
    final metinSatiri = RegExp(r'SnackBar|\bText\(');
    final istisna = RegExp(r'\$e\b|\$\{e\}|\be\.toString\(\)');

    final bulunanlar = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final satirlar = f.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        final s = satirlar[i];
        if (s.trimLeft().startsWith('//')) continue; // yorum
        if (metinSatiri.hasMatch(s) && istisna.hasMatch(s)) {
          bulunanlar.add('${f.path}:${i + 1}  ${s.trim()}');
        }
      }
    }

    expect(
      bulunanlar,
      isEmpty,
      reason: 'Ham istisna arayüze basılıyor. Firestore hataları doküman '
          'yolu (= uid) taşır.\nAyrıntıyı `reportHandled`a ver, '
          'kullanıcıya `context.tr(...)` göster.\n'
          '${bulunanlar.join('\n')}',
    );
  });
}
