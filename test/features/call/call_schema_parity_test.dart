import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/core/call/call_document.dart';
import 'package:gizli_chat/models/call_model.dart' as live;
import 'package:gizli_chat/features/call/data/models/call_model.dart' as clean;
import 'package:gizli_chat/features/call/domain/entities/call_entity.dart'
    as clean_entity;

/// 🔒 CANLI YAZAR → CLEAN OKUR: bu tur KOPARSA gelen arama SESSİZCE ölür.
///
/// ── NE DEĞİŞTİ (§4v → §4aj) ──
/// Bu dosya eskiden **iki yazarın şema eşitliğini** ölçüyordu:
/// `calls` koleksiyonuna hem `CallService` (canlı) hem Clean katmanı
/// yazıyordu ve §4t alanı yalnızca birine eklemişti — doküman
/// `participants` taşımadı, gelen arama dinleyicisi HİÇ eşleşmedi,
/// hata vermeden üretime çıktı (§4u).
///
/// §4aj ölü yazma yolunu kaldırdı: artık `calls`'a yazan **tek** model
/// var. İki yazarın ayrışması bu yüzden test edilecek bir şey değil —
/// **yapısal olarak imkânsız.** Eşitlik testi de anlamsızlaştı.
///
/// ── GERİYE KALAN GERÇEK BAĞ ──
/// Clean katmanı o dokümanları OKUYOR: `watchIncomingCall` ve
/// `watchCall`, `CallService`in yazdığı dokümanı `CallModel.fromMap` ile
/// çözüyor. Yazan ile okuyan ayrışırsa sonuç §4u'nun AYNISIDIR, sadece
/// okuma tarafından: sorgu kurulur, doküman gelir, alanlar boş çözülür
/// ve gelen arama ekranı hiç açılmaz.
///
/// Bu dosya artık o turu ölçüyor — ve canlı kodun gerçekten çalıştırdığı
/// yolu ölçtüğü için eski eşitlik testinden daha güçlü.
live.CallModel _live({
  live.CallStatus status = live.CallStatus.ringing,
  DateTime? answeredAt,
  DateTime? endedAt,
}) =>
    live.CallModel(
      id: 'c1',
      callerId: 'uidA',
      callerUsername: 'ayse',
      calleeId: 'uidB',
      calleeUsername: 'mehmet',
      type: live.CallType.audio,
      status: status,
      createdAt: DateTime.utc(2026, 9, 4),
      answeredAt: answeredAt,
      endedAt: endedAt,
    );

void main() {
  setUp(() => clean_entity.CallEntity.nameResolver = null);
  tearDown(() => clean_entity.CallEntity.nameResolver = null);

  group('canlı yazar → Clean okur', () {
    test('gelen arama sorgusunun dayandığı alanlar TURU GEÇER', () {
      // ⚠️ ASIL REGRESYON KORUMASI (§4u). `participants` canlı dokümanda
      // yoksa `where('participants', arrayContains: me)` hiç eşleşmez;
      // varsa ama Clean tarafı okuyamazsa üyelik boş çözülür. İkisi de
      // gelen aramayı SESSİZCE öldürür.
      final yazilan = _live().toMap();
      final okunan = clean.CallModel.fromMap(yazilan);

      expect(okunan.participants, ['uidA', 'uidB'],
          reason: 'üyelik turu koptu — gelen arama eşleşmez');
      expect(okunan.callerId, 'uidA',
          reason: 'callerId koptu — kendi aramam gelen arama sanılır');
      expect(okunan.status, clean_entity.CallStatus.ringing,
          reason: 'durum koptu — "ringing" süzgeci tutmaz');
      expect(okunan.id, 'c1');
      expect(okunan.type, clean_entity.CallType.audio);
      expect(okunan.createdAt, DateTime.utc(2026, 9, 4));
    });

    test('zaman damgaları turu geçer (çağrı geçmişi süresi)', () {
      final yazilan = _live(
        status: live.CallStatus.ended,
        answeredAt: DateTime.utc(2026, 9, 4, 10),
        endedAt: DateTime.utc(2026, 9, 4, 10, 2),
      ).toMap();
      final okunan = clean.CallModel.fromMap(yazilan);

      expect(okunan.answeredAt, DateTime.utc(2026, 9, 4, 10));
      expect(okunan.endedAt, DateTime.utc(2026, 9, 4, 10, 2));
      expect(okunan.status, clean_entity.CallStatus.ended);
    });

    test('her CallStatus turu geçer', () {
      // Bir durum adı iki enum arasında ayrışırsa `orElse` sessizce
      // `ended`e düşer: çalan bir arama "bitmiş" görünür.
      for (final s in live.CallStatus.values) {
        final okunan = clean.CallModel.fromMap(_live(status: s).toMap());
        expect(okunan.status.name, s.name,
            reason: '${s.name} durumu Clean tarafında karşılıksız');
      }
    });

    test('her CallType turu geçer', () {
      for (final t in live.CallType.values) {
        final yazilan = live.CallModel(
          id: 'c1',
          callerId: 'uidA',
          callerUsername: '',
          calleeId: 'uidB',
          calleeUsername: '',
          type: t,
          status: live.CallStatus.ringing,
          createdAt: DateTime.utc(2026),
        ).toMap();
        expect(clean.CallModel.fromMap(yazilan).type.name, t.name);
      }
    });

    test('ESKİ doküman (participants YOK) hâlâ okunur', () {
      // §4m'nin dersi: şema değişimi anında DEVAM EDEN arama kopmamalı.
      final eski = _live().toMap()..remove(CallFields.participants);
      expect(clean.CallModel.fromMap(eski).participants, ['uidA', 'uidB']);
    });

    test('GRUP araması turu geçer — üçüncü kişi KAYBOLMAZ', () {
      // ⚠️ BU VAKA OLMADAN TUR TESTİ ZAYIF.
      // Birebir aramada `readParticipants` alan eksikse listeyi
      // `callerId`+`calleeId`'den TÜRETİYOR (§4m geriye uyumluluğu).
      // Yani 1:1 turunda alanın hiç yazılmaması bile fark edilmez —
      // §4u'nun tam hatası böyle gizlenebilir.
      //
      // Üç kişide yedek çalışmaz: türetilen liste iki kişiliktir ve
      // ÜÇÜNCÜ katılımcı sessizce düşer. O kişinin cihazında
      // `arrayContains` eşleşmez, yani çağrı ekranı hiç açılmaz.
      final yazilan = buildCallDocument(
        id: 'g1',
        callerId: 'uidA',
        calleeId: 'uidB',
        type: 'audio',
        status: 'ringing',
        createdAt: DateTime.utc(2026, 9, 4),
        participants: const ['uidA', 'uidB', 'uidC'],
      );
      final okunan = clean.CallModel.fromMap(yazilan);

      expect(okunan.participants, ['uidA', 'uidB', 'uidC'],
          reason: 'grup üyeliği turda kayboldu — üçüncü kişi arama almaz');
      expect(okunan.includes('uidC'), isTrue);
    });
  });

  group('metadata gizliliği — canlı yazar', () {
    test('kullanıcı adları SUNUCUYA YAZILMAZ', () {
      // §4u: `calls` dokümanı "kim kimi aradı"yı ADLARIYLA taşıyordu.
      // Artık tek yazar canlı model olduğu için koruma da orada.
      final map = _live().toMap();
      expect(map.containsKey('callerUsername'), isFalse);
      expect(map.containsKey('calleeUsername'), isFalse);
      final flat = map.values.map((v) => v.toString()).join(' ');
      expect(flat, isNot(contains('ayse')));
      expect(flat, isNot(contains('mehmet')));
    });
  });

  group('ortak şema yardımcıları', () {
    test('participants verilmezse iki taraftan türetilir', () {
      final d = buildCallDocument(
        id: 'c1',
        callerId: 'uidA',
        calleeId: 'uidB',
        type: 'audio',
        status: 'ringing',
        createdAt: DateTime.utc(2026),
      );
      expect(d[CallFields.participants], ['uidA', 'uidB']);
    });

    test('verilen participants korunur (grup araması)', () {
      final d = buildCallDocument(
        id: 'c1',
        callerId: 'uidA',
        calleeId: 'uidB',
        type: 'audio',
        status: 'ringing',
        createdAt: DateTime.utc(2026),
        participants: const ['uidA', 'uidB', 'uidC'],
      );
      expect(d[CallFields.participants], ['uidA', 'uidB', 'uidC']);
    });

    test('ESKİ doküman okunurken iki taraftan türetilir', () {
      expect(readParticipants(const {'callerId': 'uidA', 'calleeId': 'uidB'}),
          ['uidA', 'uidB']);
    });

    test('YENİ doküman diziyi olduğu gibi verir', () {
      expect(
        readParticipants(const {
          'callerId': 'uidA',
          'calleeId': 'uidB',
          'participants': <String>['uidA', 'uidB', 'uidC'],
        }),
        ['uidA', 'uidB', 'uidC'],
      );
    });
  });
}
