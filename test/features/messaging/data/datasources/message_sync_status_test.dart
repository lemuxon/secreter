import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gizli_chat/features/messaging/data/datasources/message_sync_service.dart';
import 'package:gizli_chat/features/messaging/data/models/message_model.dart';
import 'package:gizli_chat/features/messaging/domain/entities/message_entity.dart';

import '../../../../helpers/mocks.dart';

/// Kuyruğa alınmış mesajın TESLİM DURUMU.
///
/// 🐞 REGRESYON: Çevrimdışı gönderilen mesaj kuyruğa `status: sending`
/// ile girer (arayüzde SAAT ikonu). Kuyruk boşaltılırken eskiden AYNI
/// nesne gönderiliyordu; yani Firestore'a `sending` yazılıyor ve yerel
/// önbellek de `sending` kalıyordu. Mesaj karşı tarafa ULAŞSA BİLE
/// gönderende saat ikonu sonsuza kadar duruyordu — durumu ilerleten
/// başka hiçbir yol yok.
///
/// Bu testler o yolu kapatır: kuyruktan çıkan mesaj `sent` olarak
/// yazılmalı VE yerel kopya güncellenmeli.
void main() {
  late MessageSyncService service;
  late MockMessageLocalDataSource mockLocal;
  late MockMessageRemoteDataSource mockRemote;
  late MockNetworkInfo mockNetwork;

  MessageModel bekleyen({
    String id = 'm1',
    MessageDeliveryStatus status = MessageDeliveryStatus.sending,
  }) =>
      MessageModel(
        id: id,
        chatId: 'sohbet1',
        senderId: 'ben',
        senderUsername: '',
        content: 'şifreli-metin',
        type: MessageContentType.text,
        timestamp: DateTime(2026, 9, 10),
        status: status,
      );

  setUpAll(() {
    registerFallbackValue(bekleyen());
  });

  setUp(() {
    mockLocal = MockMessageLocalDataSource();
    mockRemote = MockMessageRemoteDataSource();
    mockNetwork = MockNetworkInfo();
    service = MessageSyncService(
      localDataSource: mockLocal,
      remoteDataSource: mockRemote,
      networkInfo: mockNetwork,
    );

    when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
    when(() => mockRemote.sendMessage(any(), any())).thenAnswer((_) async {});
    when(() => mockRemote.updateLastMessage(any(), any(),
        senderId: any(named: 'senderId'))).thenAnswer((_) async {});
    when(() => mockLocal.cacheMessage(any(), any())).thenAnswer((_) async {});
    when(() => mockLocal.removePendingMessage(any())).thenAnswer((_) async {});
  });

  test('kuyruktan gönderilen mesaj SUNUCUYA "sent" olarak yazılır', () async {
    when(() => mockLocal.getPendingMessages())
        .thenAnswer((_) async => [bekleyen()]);

    await service.syncPendingMessages();

    final gonderilen = verify(() => mockRemote.sendMessage(any(), captureAny()))
        .captured
        .single as MessageModel;

    expect(gonderilen.status, MessageDeliveryStatus.sent,
        reason: 'sunucuya "sending" yazılırsa alıcıda ve göndericide '
            'saat ikonu kalıcı olur');
  });

  test('YEREL önbellek de "sent" ile güncellenir', () async {
    when(() => mockLocal.getPendingMessages())
        .thenAnswer((_) async => [bekleyen()]);

    await service.syncPendingMessages();

    final onbellege = verify(() => mockLocal.cacheMessage(any(), captureAny()))
        .captured
        .single as MessageModel;

    expect(onbellege.status, MessageDeliveryStatus.sent,
        reason: 'kuyruk boşaldıktan sonra arayüz bu kopyayı gösteriyor; '
            'güncellenmezse ekranda saat ikonu kalır');
    expect(onbellege.id, 'm1', reason: 'aynı mesaj güncellenmeli');
  });

  test('durum güncellemesi mesajın İÇERİĞİNİ bozmaz', () async {
    when(() => mockLocal.getPendingMessages())
        .thenAnswer((_) async => [bekleyen()]);

    await service.syncPendingMessages();

    final gonderilen = verify(() => mockRemote.sendMessage(any(), captureAny()))
        .captured
        .single as MessageModel;

    expect(gonderilen.content, 'şifreli-metin');
    expect(gonderilen.chatId, 'sohbet1');
    expect(gonderilen.senderId, 'ben');
    expect(gonderilen.timestamp, DateTime(2026, 9, 10));
  });

  test('başarılı gönderim kuyruktan düşürülür', () async {
    when(() => mockLocal.getPendingMessages())
        .thenAnswer((_) async => [bekleyen()]);

    await service.syncPendingMessages();

    verify(() => mockLocal.removePendingMessage('m1')).called(1);
  });

  test('gönderim patlarsa kuyrukta KALIR ve önbellek kirletilmez', () async {
    when(() => mockLocal.getPendingMessages())
        .thenAnswer((_) async => [bekleyen()]);
    when(() => mockRemote.sendMessage(any(), any()))
        .thenThrow(Exception('ağ yok'));

    await service.syncPendingMessages();

    verifyNever(() => mockLocal.removePendingMessage(any()));
    verifyNever(() => mockLocal.cacheMessage(any(), any()));
  });
}
