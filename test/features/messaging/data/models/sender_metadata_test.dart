import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/features/messaging/data/models/message_model.dart';
import 'package:gizli_chat/features/messaging/domain/entities/message_entity.dart';

/// 🕵️ METADATA GİZLİLİĞİ — gönderen adı sunucuya gitmez.
///
/// İçerik şifreli olsa bile, her mesajda gönderenin ADININ düz metin
/// durması sunucuya sosyal grafiğin tamamını okunabilir hâlde veriyordu:
/// "@ayse → @mehmet, 14:32, okundu 14:33". Telefon numarası istemeyen,
/// anonimlik vaat eden bir uygulamada asıl açık buydu.
MessageModel _msg({String senderUsername = 'ayse'}) => MessageModel(
      id: 'm1',
      chatId: 'c1',
      senderId: 'uid-7f3a',
      senderUsername: senderUsername,
      content: 'şifreli-gövde',
      type: MessageContentType.text,
      timestamp: DateTime.utc(2026, 8, 29, 14, 32),
    );

void main() {
  group('sunucuya yazılan alanlar', () {
    test('gönderen ADI sunucuya YAZILMAZ', () async {
      // ⚠️ REGRESYON KORUMASI. Bu alan geri gelirse sosyal grafik yine
      // adlarla okunabilir olur.
      final map = _msg().toMap();

      expect(map.containsKey('senderUsername'), isFalse);
      expect(map.values.map((v) => v.toString()).join(' '),
          isNot(contains('ayse')));
    });

    test('gönderen KİMLİĞİ hâlâ yazılır (yetkilendirme için gerekli)', () {
      // Dürüstlük notu: bu aşama adı gizler, uid'yi değil. Kural motoru
      // yazarlık denetimini `senderId` ile yapıyor.
      expect(_msg().toMap()['senderId'], 'uid-7f3a');
    });
  });

  group('geriye uyumluluk', () {
    test('ESKİ mesajlardaki ad okunmaya devam eder', () {
      // Bu değişiklikten önce yazılmış mesajlarda alan dolu; onları
      // adsız göstermek gerileme olurdu.
      final m = MessageModel.fromMap({
        'id': 'eski',
        'chatId': 'c1',
        'senderId': 'uid-7f3a',
        'senderUsername': 'ayse',
        'content': 'x',
        'type': 'text',
        'timestamp': DateTime.utc(2026).toIso8601String(),
      }, 'c1');
      expect(m.senderUsername, 'ayse');
    });

    test('yeni mesajlarda ad boş gelir', () {
      final m = MessageModel.fromMap({
        'id': 'yeni',
        'chatId': 'c1',
        'senderId': 'uid-7f3a',
        'content': 'x',
        'type': 'text',
        'timestamp': DateTime.utc(2026).toIso8601String(),
      }, 'c1');
      expect(m.senderUsername, isEmpty);
    });
  });

  group('yerel ad çözümü', () {
    test('boş ad çözülmüş adla doldurulur', () {
      final filled = _msg(senderUsername: '').withResolvedSender('mehmet');
      expect(filled.senderUsername, 'mehmet');
      expect(filled.content, 'şifreli-gövde', reason: 'içerik bozulmamalı');
      expect(filled.id, 'm1');
    });

    test('DOLU ad EZİLMEZ (eski mesaj korunur)', () {
      final kept = _msg(senderUsername: 'ayse').withResolvedSender('baskasi');
      expect(kept.senderUsername, 'ayse');
    });

    test('çözülemeyen ad mesajı bozmaz', () {
      final m = _msg(senderUsername: '');
      expect(m.withResolvedSender(null).senderUsername, isEmpty);
      expect(m.withResolvedSender('').senderUsername, isEmpty);
      // Mesaj yine de gösterilebilir olmalı.
      expect(m.withResolvedSender(null).content, 'şifreli-gövde');
    });

    test('çözülmüş ad SUNUCUYA geri yazılmaz', () {
      // Yerelde doldurulan ad, bir sonraki yazımda sunucuya sızmamalı.
      final filled = _msg(senderUsername: '').withResolvedSender('mehmet');
      expect(filled.toMap().containsKey('senderUsername'), isFalse);
    });
  });
}
