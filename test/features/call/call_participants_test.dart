import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/features/call/data/models/call_model.dart';
import 'package:gizli_chat/features/call/domain/entities/call_entity.dart';
import 'package:gizli_chat/models/call_model.dart' as live;

/// 👥 ÇAĞRI ŞEMASI — İKİ KİŞİDEN N KİŞİYE
///
/// Sinyalleşme `callerId`/`calleeId` ikilisine ÇAKILIYDI: güvenlik
/// kuralları, gelen arama sorgusu ve ICE aday yolları hep "iki taraf"
/// varsayıyordu. Grup araması bu varsayım kırılmadan eklenemezdi.
///
/// Üyeliğin tek kaynağı artık `participants`; eski alanlar birebir
/// aramada anlamlı olduğu için korunur.
CallModel _call({
  String caller = 'uidA',
  String callee = 'uidB',
  List<String> participants = const [],
}) =>
    CallModel(
      id: 'c1',
      callerId: caller,
      callerUsername: '',
      calleeId: callee,
      calleeUsername: '',
      participants: participants,
      type: CallType.audio,
      status: CallStatus.ringing,
      createdAt: DateTime.utc(2026, 9, 4),
    );

/// Sunucuya gerçekten yazan model (`CallService` bunu kullanır).
live.CallModel _liveCall() => live.CallModel(
      id: 'c1',
      callerId: 'uidA',
      callerUsername: '',
      calleeId: 'uidB',
      calleeUsername: '',
      type: live.CallType.audio,
      status: live.CallStatus.ringing,
      createdAt: DateTime.utc(2026, 9, 4),
    );

void main() {
  setUp(() => CallEntity.nameResolver = null);
  tearDown(() => CallEntity.nameResolver = null);

  group('metadata gizliliği — çağrı adları', () {
    test('kullanıcı adları SUNUCUYA YAZILMAZ', () {
      // ⚠️ REGRESYON KORUMASI. Çağrı dokümanı "kim kimi aradı"yı
      // ADLARIYLA taşıyordu — §4k mesajlardan, §4o sohbet dokümanından
      // temizlemişti; aramalar gözden kaçmıştı.
      final map = _liveCall().toMap();
      expect(map.containsKey('callerUsername'), isFalse);
      expect(map.containsKey('calleeUsername'), isFalse);
    });

    test('kimlikler YAZILMAYA devam eder (yetki için gerekli)', () {
      // Dürüstlük notu: bu adım adı gizler, kimliği değil. Kural motoru
      // üyelik denetimini `participants` ve `callerId` ile yapıyor.
      final map = _liveCall().toMap();
      expect(map['callerId'], 'uidA');
      expect(map['calleeId'], 'uidB');
    });

    test('ad uid çözümünden gelir', () {
      CallEntity.nameResolver = (uid) => uid == 'uidA' ? 'ayse' : 'mehmet';
      expect(_call().callerName, 'ayse');
      expect(_call().calleeName, 'mehmet');
    });

    test('ESKİ çağrılarda kayıtlı ad okunmaya devam eder', () {
      final c = CallModel.fromMap(const {
        'id': 'eski',
        'callerId': 'uidA',
        'callerUsername': 'ayse',
        'calleeId': 'uidB',
        'calleeUsername': 'mehmet',
        'type': 'audio',
        'status': 'ended',
      });
      expect(c.callerName, 'ayse');
      expect(c.calleeName, 'mehmet');
    });

    test('çözüm ESKİ addan önce gelir (ad değişmiş olabilir)', () {
      CallEntity.nameResolver = (_) => 'yeni_ad';
      final c = CallModel.fromMap(const {
        'id': 'eski',
        'callerId': 'uidA',
        'callerUsername': 'eski_ad',
        'calleeId': 'uidB',
        'type': 'audio',
        'status': 'ended',
      });
      expect(c.callerName, 'yeni_ad');
    });

    test('hiçbiri yoksa arayan ADSIZ görünmez', () {
      final c = _call(caller: 'abcdefghij');
      expect(c.callerName, 'abcdef');
    });
  });

  // ⚠️ YAZMA ŞEMASI ARTIK CANLI MODELDE ÖLÇÜLÜR.
  // Bu grup eskiden Clean modelin `toMap()`ini sınıyordu; o metot
  // `calls`'a yazan ÖLÜ yolun parçasıydı ve §4aj'de kaldırıldı.
  // Sunucuya gerçekten ne yazıldığını yalnızca `CallService`in modeli
  // belirliyor, o yüzden koruma da orada olmalı.
  group('sunucuya yazılan şema (CANLI model)', () {
    test('participants YAZILIR (birebir aramadan türetilir)', () {
      // Çağıranın her seferinde elle yazmasını beklemek, bir gün
      // unutulup çağrının kimseye görünmemesiyle biterdi.
      expect(_liveCall().toMap()['participants'], ['uidA', 'uidB']);
    });

    test('eski alanlar korunur (birebir arama + engel kontrolü)', () {
      final map = _liveCall().toMap();
      expect(map['callerId'], 'uidA');
      expect(map['calleeId'], 'uidB');
    });
  });

  group('geriye uyumluluk', () {
    test('ESKİ doküman (participants YOK) iki taraftan türetilir', () {
      // ⚠️ Şema değişiminin tam o anında DEVAM EDEN bir arama, dizisi
      // olmadığı için erişilemez hâle gelirdi — konuşma ortasında
      // koparadı. Kural motorunda da aynı yedek var.
      final c = CallModel.fromMap(const {
        'id': 'eski',
        'callerId': 'uidA',
        'calleeId': 'uidB',
        'type': 'audio',
        'status': 'ongoing',
      });
      expect(c.participants, ['uidA', 'uidB']);
      expect(c.includes('uidA'), isTrue);
      expect(c.includes('uidB'), isTrue);
      expect(c.includes('uidYabanci'), isFalse);
    });

    test('YENİ doküman diziyi olduğu gibi okur', () {
      final c = CallModel.fromMap(const {
        'id': 'yeni',
        'callerId': 'uidA',
        'calleeId': 'uidB',
        'participants': <String>['uidA', 'uidB', 'uidC'],
        'type': 'audio',
        'status': 'ongoing',
      });
      expect(c.participants, ['uidA', 'uidB', 'uidC']);
      expect(c.includes('uidC'), isTrue);
    });
  });

  group('üyelik yardımcıları', () {
    test('birebir aramada karşı taraf bulunur', () {
      expect(_call().peerOf('uidA'), 'uidB');
      expect(_call().peerOf('uidB'), 'uidA');
    });

    test('GRUP aramasında tek bir "karşı taraf" YOKTUR', () {
      // Arayüz "karşı taraf" varsayarak çizim yaparsa grup aramasında
      // yanlış kişiyi gösterir; null dönmesi bunu çağıranın fark
      // etmesini sağlar.
      final g = _call(participants: const ['uidA', 'uidB', 'uidC']);
      expect(g.peerOf('uidA'), isNull);
    });

    test('katılımcı olmayan kişi dışarıdadır', () {
      final g = _call(participants: const ['uidA', 'uidB']);
      expect(g.includes('uidMallory'), isFalse);
    });
  });
}
