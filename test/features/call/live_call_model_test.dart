import 'package:flutter_test/flutter_test.dart';
import 'package:gizli_chat/models/call_model.dart';

/// 🐞 CANLI ÇAĞRI MODELİ — İKİ MODELİN ŞEMASI AYRIŞMAMALI
///
/// Bu projede çağrı için İKİ model var:
///  * `lib/models/call_model.dart`  → **CANLI YOL** (`CallService` kullanır)
///  * `features/call/data/models/`  → Clean katmanı (büyük ölçüde ölü)
///
/// §4t `participants` alanını yalnızca İKİNCİSİNE ekledi. Sonuç: çağrı
/// dokümanı alanı taşımıyordu ve gelen arama dinleyicisi
/// `where('participants', arrayContains: me)` HİÇBİR ZAMAN eşleşmiyordu —
/// hata vermeden. Kullanıcı arama alamıyordu.
///
/// Bu dosya canlı modeli ayrıca kilitler; aynı sessiz ayrışma tekrar
/// ederse test kırılır.
CallModel _call() => CallModel(
      id: 'c1',
      callerId: 'uidA',
      callerUsername: 'ayse',
      calleeId: 'uidB',
      calleeUsername: 'mehmet',
      type: CallType.audio,
      status: CallStatus.ringing,
      createdAt: DateTime.utc(2026, 9, 4),
    );

void main() {
  group('canlı çağrı dokümanı', () {
    test('participants YAZILIR (gelen arama sorgusu buna dayanıyor)', () {
      final map = _call().toMap();
      expect(map['participants'], ['uidA', 'uidB']);
    });

    test('kullanıcı adları YAZILMAZ', () {
      // §4k/§4o'nun aramalardaki hâli: sunucuda "kim kimi aradı"
      // adlarıyla duruyordu.
      final map = _call().toMap();
      expect(map.containsKey('callerUsername'), isFalse);
      expect(map.containsKey('calleeUsername'), isFalse);
      expect(map.values.map((v) => v.toString()).join(' '),
          isNot(contains('ayse')));
      expect(map.values.map((v) => v.toString()).join(' '),
          isNot(contains('mehmet')));
    });

    test('kimlikler ve durum yazılmaya devam eder', () {
      final map = _call().toMap();
      expect(map['callerId'], 'uidA');
      expect(map['calleeId'], 'uidB');
      expect(map['status'], 'ringing');
    });

    test('ESKİ dokümandaki ad okunmaya devam eder', () {
      final c = CallModel.fromMap(const {
        'id': 'eski',
        'callerId': 'uidA',
        'callerUsername': 'ayse',
        'calleeId': 'uidB',
        'calleeUsername': 'mehmet',
        'type': 'audio',
        'status': 'ended',
      });
      expect(c.callerUsername, 'ayse');
      expect(c.calleeUsername, 'mehmet');
    });
  });
}
