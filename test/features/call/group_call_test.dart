import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/call/call_document.dart';
import 'package:gizli_chat/features/call/data/models/call_model.dart';
import 'package:gizli_chat/services/group_call_service.dart';

/// 👥 GRUP ARAMASI — MESH SÖZLEŞMESİ (§4bq)
///
/// Burada ölçülen üç şey de **sessizce** kırılabilen türden:
///
///  1. TEKLİF SAHİPLİĞİ. İki taraf aynı anda offer üretirse ya da hiç
///     üretmezse bağlantı kurulmaz — ekran açılır, karo gelir, görüntü
///     hiç gelmez. Hata yoktur.
///  2. CANLILIK ÖLÇÜTÜ. Grup araması konuşma boyunca `ringing` kalır.
///     Ölçüt bozulursa ya ölü aramaya katılınır (kimse bulunmaz) ya da
///     grup sonsuza dek çalar.
///  3. ŞEMA TURU. `calls` dokümanını yazan ile okuyan ayrışırsa gelen
///     arama boş döner — §4u'nun aynısı.
void main() {
  group('teklif sahipliği (glare)', () {
    test('her çiftte TAM BİR taraf teklif verir', () {
      const uidler = ['a', 'b', 'c', 'zz', 'A', '0'];
      for (final x in uidler) {
        for (final y in uidler) {
          if (x == y) continue;
          final benTeklif = GroupCallService.teklifiBenVeririm(x, y);
          final oTeklif = GroupCallService.teklifiBenVeririm(y, x);
          expect(benTeklif, isNot(oTeklif),
              reason: '$x/$y: ya iki teklif çarpışır ya hiç teklif olmaz');
        }
      }
    });

    test('küçük uid teklif eder — karar DETERMİNİSTİK', () {
      expect(GroupCallService.teklifiBenVeririm('abc', 'abd'), isTrue);
      expect(GroupCallService.teklifiBenVeririm('abd', 'abc'), isFalse);
      // Aynı çağrı iki kez aynı cevabı vermeli (rastgelelik YOK).
      for (var i = 0; i < 5; i++) {
        expect(GroupCallService.teklifiBenVeririm('u1', 'u2'), isTrue);
      }
    });
  });

  group('canlılık ölçütü', () {
    Map<String, dynamic> doc({
      String status = 'ringing',
      List<String> joined = const ['a'],
      DateTime? createdAt,
    }) =>
        buildGroupCallDocument(
          id: 'g1',
          callerId: 'a',
          groupChatId: 'chat1',
          participants: const ['a', 'b', 'c'],
          joinedIds: joined,
          type: 'audio',
          createdAt: createdAt ?? DateTime.utc(2026, 9, 11, 12),
          status: status,
        );

    final an = DateTime.utc(2026, 9, 11, 12, 30);

    test('çalan + içinde biri olan + taze arama CANLI', () {
      expect(grupCagrisiCanli(doc(), simdi: an), isTrue);
    });

    test('bitmiş arama canlı DEĞİL', () {
      expect(grupCagrisiCanli(doc(status: 'ended'), simdi: an), isFalse);
    });

    test('kimse bağlı değilse canlı DEĞİL — ZOMBİ ARAMA', () {
      // Son ayrılan `ended` yazamadıysa (uygulama öldürüldü) doküman
      // `ringing` kalır. Bu süzgeç olmasa grup sonsuza dek çalardı.
      expect(grupCagrisiCanli(doc(joined: const []), simdi: an), isFalse);
    });

    test('4 saatten eski arama canlı DEĞİL', () {
      expect(
        grupCagrisiCanli(doc(), simdi: DateTime.utc(2026, 9, 11, 16, 1)),
        isFalse,
      );
      // Sınırın hemen berisi hâlâ canlı.
      expect(
        grupCagrisiCanli(doc(), simdi: DateTime.utc(2026, 9, 11, 15, 59)),
        isTrue,
      );
    });

    test('zaman damgası okunamıyorsa canlı DEĞİL', () {
      final bozuk = doc()..[CallFields.createdAt] = 'dun';
      expect(grupCagrisiCanli(bozuk, simdi: an), isFalse);
    });

    test('servis ile ortak şema dosyası AYNI kararı verir', () {
      // İkisi ayrışırsa istemci ölü aramaya katılmaya çalışırken gelen
      // arama süzgeci onu geçerli sayar (ya da tersi).
      for (final v in [doc(), doc(status: 'ended'), doc(joined: const [])]) {
        expect(GroupCallService.cagriCanli(v, simdi: an),
            grupCagrisiCanli(v, simdi: an));
      }
    });
  });

  group('grup çağrı dokümanı', () {
    final d = buildGroupCallDocument(
      id: 'g1',
      callerId: 'uidA',
      groupChatId: 'chat1',
      participants: const ['uidA', 'uidB', 'uidC'],
      joinedIds: const ['uidA'],
      type: 'video',
      createdAt: DateTime.utc(2026, 9, 11, 12),
    );

    test('calleeId YAZILMAZ', () {
      // ⚠️ Yazılsaydı kural `notBlockedBy('')` yolunu seçer, `get()`
      // boş segmentle çağrılır ve istek SESSİZCE reddedilirdi.
      expect(d.containsKey(CallFields.calleeId), isFalse);
    });

    test('iki liste AYRI: taraflar ≠ bağlananlar', () {
      expect(d[CallFields.participants], ['uidA', 'uidB', 'uidC']);
      expect(d[CallFields.joinedIds], ['uidA']);
    });

    test('grup işareti yazılır — gelen arama ekranı buna bakar', () {
      expect(d[CallFields.isGroup], isTrue);
      expect(d[CallFields.groupChatId], 'chat1');
    });

    test('kullanıcı adı SUNUCUYA YAZILMAZ', () {
      // Metadata gizliliği: çağrı dokümanı "kim kimi aradı"yı adlarla
      // taşımaz (§4k/§4o'nun aramalardaki hâli).
      final duz = d.values.map((v) => v.toString()).join(' ');
      expect(duz, isNot(contains('@')));
      expect(d.containsKey('callerUsername'), isFalse);
      expect(d.containsKey('groupName'), isFalse);
    });
  });

  group('yazan → okuyan turu', () {
    test('grup alanları Clean modele SAĞLAM ULAŞIR', () {
      final okunan = CallModel.fromMap(buildGroupCallDocument(
        id: 'g1',
        callerId: 'uidA',
        groupChatId: 'chat1',
        participants: const ['uidA', 'uidB', 'uidC'],
        joinedIds: const ['uidA', 'uidB'],
        type: 'audio',
        createdAt: DateTime.utc(2026, 9, 11, 12),
      ));

      expect(okunan.isGroup, isTrue,
          reason: 'grup işareti kayboldu — reddetmek HERKESİN aramasını '
              'kapatır');
      expect(okunan.groupChatId, 'chat1',
          reason: 'sohbet kimliği kayboldu — kabul edilen arama hangi '
              'gruba katılacağını bilemez');
      expect(okunan.joinedIds, ['uidA', 'uidB']);
      expect(okunan.participants, ['uidA', 'uidB', 'uidC']);
      expect(okunan.id, 'g1');
    });

    test('BİREBİR arama grup sanılmaz', () {
      final okunan = CallModel.fromMap(buildCallDocument(
        id: 'c1',
        callerId: 'uidA',
        calleeId: 'uidB',
        type: 'audio',
        status: 'ringing',
        createdAt: DateTime.utc(2026, 9, 11, 12),
      ));
      expect(okunan.isGroup, isFalse,
          reason: 'birebir arama grup sanılırsa "reddet" hiçbir şey '
              'yapmaz — arayan sonsuza dek çalar');
      expect(okunan.groupChatId, isEmpty);
      expect(okunan.joinedIds, isEmpty);
    });
  });
}
