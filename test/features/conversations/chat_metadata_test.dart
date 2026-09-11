import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/features/conversations/data/models/conversation_model.dart';
import 'package:gizli_chat/features/conversations/domain/entities/conversation_entity.dart';

/// 🕵️ METADATA GİZLİLİĞİ — 2. AŞAMA
///
/// Sohbet dokümanı `memberUsernames: ["ayse","mehmet"]` taşıyordu.
/// İçerik şifreli olsa bile bu, sosyal grafiği sunucuda ADLARIYLA okunur
/// bırakıyordu: kimin kiminle yazıştığı, uid eşlemesine bile gerek
/// kalmadan görülebiliyordu.
///
/// Alan artık YAZILMIYOR; başlıktaki ad gösterim anında uid'den çözülür.
/// Eski dokümanlar adsız kalmasın diye alan OKUNMAYA devam eder.
ConversationModel _direct({List<String> usernames = const []}) =>
    ConversationModel(
      id: 'uidA_uidB',
      type: ConversationType.direct,
      memberIds: const ['uidA', 'uidB'],
      memberUsernames: usernames,
    );

void main() {
  setUp(() => ConversationEntity.nameResolver = null);
  tearDown(() => ConversationEntity.nameResolver = null);

  group('başlık çözümü', () {
    test('ad SUNUCUDAN değil, uid çözümünden gelir', () {
      ConversationEntity.nameResolver =
          (uid) => uid == 'uidB' ? 'mehmet' : null;
      // Doküman hiç ad taşımıyor — 2. aşamadan sonraki normal durum.
      expect(_direct().displayTitle('uidA'), 'mehmet');
    });

    test('çözüm ESKİ dizinin önüne geçer (dizi bayat kalabiliyordu)', () {
      // Kullanıcı adını değiştirdiğinde sohbet dokümanı güncellenmiyordu;
      // canlı çözüm güncel adı verir.
      ConversationEntity.nameResolver = (_) => 'yeni_ad';
      expect(
        _direct(usernames: const ['ayse', 'eski_ad']).displayTitle('uidA'),
        'yeni_ad',
      );
    });

    test('ESKİ dokümanlar adsız KALMAZ (çözüm yoksa dizi kullanılır)', () {
      // ⚠️ GERİYE UYUMLULUK. Çözümleyici takılı değilken (birim testi,
      // erken açılış) ya da ad henüz çözülmemişken eski sohbetler
      // başlıksız görünmemeli.
      expect(
        _direct(usernames: const ['ayse', 'mehmet']).displayTitle('uidA'),
        'mehmet',
      );
    });

    test('boş çözüm eski diziye düşer', () {
      ConversationEntity.nameResolver = (_) => '';
      expect(
        _direct(usernames: const ['ayse', 'mehmet']).displayTitle('uidA'),
        'mehmet',
      );
    });

    test('ikisi de yoksa başlık boş kalmaz', () {
      expect(_direct().displayTitle('uidA'), 'Sohbet');
      expect(_direct().avatarLetter('uidA'), 'S');
    });

    test('grup başlığı ad çözümünden ETKİLENMEZ', () {
      ConversationEntity.nameResolver = (_) => 'birisi';
      const g = ConversationModel(
        id: 'g1',
        type: ConversationType.group,
        memberIds: ['uidA', 'uidB'],
        groupName: 'Ekip',
      );
      expect(g.displayTitle('uidA'), 'Ekip');
    });
  });

  group('geriye uyumluluk', () {
    test('ESKİ dokümandaki ad dizisi okunmaya devam eder', () {
      final c = ConversationModel.fromMap(const {
        'id': 'uidA_uidB',
        'type': 'direct',
        'memberIds': ['uidA', 'uidB'],
        'memberUsernames': ['ayse', 'mehmet'],
      });
      expect(c.memberUsernames, const ['ayse', 'mehmet']);
    });

    test('YENİ dokümanda ad dizisi boş gelir', () {
      final c = ConversationModel.fromMap(const {
        'id': 'uidA_uidB',
        'type': 'direct',
        'memberIds': ['uidA', 'uidB'],
      });
      expect(c.memberUsernames, isEmpty);
    });
  });
}
