import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/observability/handled_error.dart';

/// 🔦 YUTULAN HATA RAPORLAMASI
///
/// Bu geçidin iki sözü var ve ikisi de test edilmeli:
///  1. Telemetriye TANIMLAYICI SIZDIRMAZ — aksi halde §4o ile sohbet
///     dokümanından kaldırılan metadata, hata raporları üzerinden geri
///     verilmiş olurdu.
///  2. ASLA FIRLATMAZ — bir hatayı raporlarken hata üretmek, düzeltmeye
///     çalıştığımız "sessiz bozulma" sorununun ta kendisidir.
void main() {
  group('hata imzası — tanımlayıcı sızdırmaz', () {
    test('Firestore hatasının KODU alınır, mesajı ALINMAZ', () {
      // Gerçek hayattaki hata metni şuna benzer:
      //   "... permission-denied ... /chats/uidAlice_uidBob/messages/m1"
      // Sohbet kimliği iki tarafın uid'sinden türediği için bu metin
      // TEK BAŞINA sosyal grafiği ele verir.
      final e = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Kural reddetti: /chats/uidAlice_uidBob/messages/m1',
      );

      final sig = errorSignature(e);

      expect(sig, contains('permission-denied'));
      expect(sig, isNot(contains('uidAlice')));
      expect(sig, isNot(contains('uidBob')));
      expect(sig, isNot(contains('chats')));
    });

    test('kodsuz hatada YALNIZCA tip adı kalır', () {
      final sig = errorSignature(StateError('gizli: uidAlice_uidBob'));
      expect(sig, 'StateError');
      expect(sig, isNot(contains('uidAlice')));
    });

    test('serbest metinli hata İÇERİĞİ hiç geçmez', () {
      final sig = errorSignature(Exception('mesaj içeriği: merhaba dünya'));
      expect(sig, isNot(contains('merhaba')));
    });
  });

  group('arıza-emniyeti', () {
    test('DI kayıtlı DEĞİLKEN bile fırlatmaz', () {
      // Birim testinde ne AppLogger ne CrashReporter kayıtlı; uygulamanın
      // erken açılışında da durum budur.
      expect(
        () => reportHandled('sınama', StateError('x'),
            stack: StackTrace.current, context: const {'a': 1}),
        returnsNormally,
      );
    });

    test('bağlam ve yığın verilmeden de çalışır', () {
      expect(() => reportHandled('sınama', 'düz metin hata'), returnsNormally);
    });
  });
}
