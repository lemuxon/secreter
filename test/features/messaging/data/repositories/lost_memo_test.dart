import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';
import 'package:gizli_chat/core/error/failures.dart';
import 'package:gizli_chat/core/privacy/privacy_controller.dart';
import 'package:gizli_chat/core/privacy/privacy_settings.dart';
import 'package:gizli_chat/features/messaging/data/datasources/encryption_datasource.dart';
import 'package:gizli_chat/features/messaging/data/models/message_model.dart';
import 'package:gizli_chat/features/messaging/data/repositories/message_repository_impl.dart';
import 'package:gizli_chat/features/messaging/domain/entities/message_entity.dart';

import '../../../../helpers/mocks.dart';

/// ÇÖZÜLEMEYEN MESAJIN ÖNBELLEKLENMESİ — iki uç da yanlıştı (§4az).
///
/// • Başarısızlığı önbelleğe ALMAK: karşı taraf yeniden el sıkışıp
///   oturum onarılsa bile mesaj, uygulama YENİDEN BAŞLAYANA kadar
///   "çözülemiyor" kalıyordu. Kurtarma çalışır, kullanıcı göremez.
/// • Hiç ALMAMAK: her Firestore anlık görüntüsünde bozuk mesajların
///   tamamı yeniden çözülmeye kalkılır (güvenli depo okuması + ratchet).
///   Bozuk mesajı çok olan sohbet takılır.
///
/// Seçilen orta yol: önbelleğe alınır, ama BAŞLIK taşıyan bir mesaj
/// geldiği anda — kurtarmanın mümkün hâle geldiği TEK an — atılır.
///
/// Bu test tam olarak o ödünleşimi ölçer: gereksiz iş YAPILMIYOR,
/// kurtarma penceresi ise KAÇIRILMIYOR.
void main() {
  late MessageRepositoryImpl repository;
  late MockMessageRemoteDataSource mockRemote;
  late MockMessageLocalDataSource mockLocal;
  late MockEncryptionDataSource mockEncryption;
  late MockNetworkInfo mockNetwork;
  late MockMessageSyncService mockSync;
  late MockCurrentUserProvider mockUserProvider;

  const chatId = 'user1_user2';
  const baslik = {'ik': 'KIMLIK', 'ek': 'EFEMERAL'};

  MessageModel gelen(String id, {Map<String, dynamic>? header}) => MessageModel(
        id: id,
        chatId: chatId,
        senderId: 'user2',
        senderUsername: '',
        content: 'ŞİFRELİ',
        type: MessageContentType.text,
        timestamp: DateTime(2026, 9, 11),
        isEncrypted: true,
        e2eeHeader: header,
      );

  setUp(() {
    mockRemote = MockMessageRemoteDataSource();
    mockLocal = MockMessageLocalDataSource();
    mockEncryption = MockEncryptionDataSource();
    mockNetwork = MockNetworkInfo();
    mockSync = MockMessageSyncService();
    mockUserProvider = MockCurrentUserProvider();

    when(() => mockUserProvider.currentUid).thenReturn('user1');
    when(() => mockEncryption.cachePlaintext(any(), any()))
        .thenAnswer((_) async {});
    // §4bi: çözme yolu artık önbelleği tek çağrıyla ısıtıyor.
    when(() => mockEncryption.warmPlaintextCache()).thenAnswer((_) async {});
    when(() => mockLocal.getCachedMessages(any()))
        .thenAnswer((_) async => <MessageModel>[]);
    when(() => mockLocal.cacheMessages(any(), any())).thenAnswer((_) async {});

    // Her çözme denemesi BAŞARISIZ: nöbetçi döner.
    when(() => mockEncryption.decrypt(
          chatId: any(named: 'chatId'),
          ciphertext: any(named: 'ciphertext'),
          isFromMe: any(named: 'isFromMe'),
          messageId: any(named: 'messageId'),
          e2eeHeader: any(named: 'e2eeHeader'),
          isGroup: any(named: 'isGroup'),
        )).thenAnswer((_) async => EncryptionDataSource.lostMarker);

    repository = MessageRepositoryImpl(
      remoteDataSource: mockRemote,
      localDataSource: mockLocal,
      encryptionDataSource: mockEncryption,
      networkInfo: mockNetwork,
      syncService: mockSync,
      userProvider: mockUserProvider,
      privacyReader: PrivacySettingsReader()
        ..update(PrivacySettings.standard()),
      uuid: const Uuid(),
    );
  });

  int cozmeSayisi() => verify(() => mockEncryption.decrypt(
        chatId: any(named: 'chatId'),
        ciphertext: any(named: 'ciphertext'),
        isFromMe: any(named: 'isFromMe'),
        messageId: any(named: 'messageId'),
        e2eeHeader: any(named: 'e2eeHeader'),
        isGroup: any(named: 'isGroup'),
      )).callCount;

  /// Verilen partileri sırayla yayınlar ve hepsinin işlenmesini bekler.
  Future<void> yayinla(List<List<MessageModel>> partiler) async {
    final kontrol = StreamController<List<MessageModel>>();
    when(() => mockRemote.watchMessages(any()))
        .thenAnswer((_) => kontrol.stream);

    final gelenler = <Either<Failure, List<MessageEntity>>>[];
    final abone = repository.watchMessages(chatId).listen(gelenler.add);

    for (final p in partiler) {
      kontrol.add(p);
      // asyncMap sırayla işler; her parti için mikro görevlere yer aç.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }
    await kontrol.close();
    await Future<void>.delayed(Duration.zero);
    await abone.cancel();
  }

  test('🔴 uid HER YAYIMDA taze okunur (§4bh)', () async {
    // 🐞 GERÇEK KULLANICIDA GÖRÜLDÜ: *"ilk ekrana girince tüm mesajlar
    // silinmiş gibi göründü, sonra geç güncellendi."*
    //
    // Firebase Auth oturumu ASENKRON geri yükler. Ekran ondan önce
    // açılırsa `currentUid` NULL yakalanır; akış bunu BİR KEZ okuyup
    // ömrü boyunca kullanırsa KENDİ mesajlarımız "karşıdan gelmiş"
    // sayılır, çözülemez ve arayüzde gri "çözülemiyor" kutusuna döner —
    // yani sohbet silinmiş gibi görünür.
    var cagri = 0;
    when(() => mockUserProvider.currentUid).thenAnswer((_) {
      cagri++;
      return cagri == 1 ? null : 'user1'; // ilk okuma oturum OTURMAMIŞ
    });

    // Kendi gönderdiğimiz mesaj: uid doğru okunursa `isFromMe` TRUE olur.
    final benimki = MessageModel(
      id: 'm1',
      chatId: chatId,
      senderId: 'user1',
      senderUsername: '',
      content: 'ŞİFRELİ',
      type: MessageContentType.text,
      timestamp: DateTime(2026, 9, 11),
      isEncrypted: true,
    );

    await yayinla([
      [benimki]
    ]);

    final cagrilar = verify(() => mockEncryption.decrypt(
          chatId: any(named: 'chatId'),
          ciphertext: any(named: 'ciphertext'),
          isFromMe: captureAny(named: 'isFromMe'),
          messageId: any(named: 'messageId'),
          e2eeHeader: any(named: 'e2eeHeader'),
          isGroup: any(named: 'isGroup'),
        )).captured;

    expect(cagrilar, isNotEmpty, reason: 'mesaj hiç çözülmeye kalkılmadı');
    expect(cagrilar.last, isTrue,
        reason: 'uid akış başında bir kez okunursa null kalır ve kendi '
            'mesajımız "karşıdan gelmiş" sayılır');
  });

  test('🔴 aynı bozuk mesaj TEKRAR TEKRAR çözülmeye kalkılmaz', () async {
    // Aynı mesaj üç anlık görüntüde geliyor (okundu bilgisi, yazıyor
    // sinyali… her biri yeni bir snapshot demek).
    await yayinla([
      [gelen('m1')],
      [gelen('m1')],
      [gelen('m1')],
    ]);

    expect(cozmeSayisi(), 1,
        reason: 'her anlık görüntüde yeniden çözmeye kalkmak, bozuk '
            'mesajı çok olan sohbette takılma demektir');
  });

  test('🔴 BAŞLIK gelince kurtarma için YENİDEN denenir', () async {
    // Karşı taraf yeniden el sıkıştı: yeni mesaj başlık taşıyor.
    // Daha önce çözülemeyen m1 artık çözülebilir olabilir.
    await yayinla([
      [gelen('m1')],
      [gelen('m1'), gelen('m2', header: baslik)],
    ]);

    expect(cozmeSayisi(), greaterThan(2),
        reason: 'başlık geldiğinde memo atılmazsa kurtarma çalışsa bile '
            'kullanıcı uygulamayı yeniden başlatana kadar göremez');
  });

  test('🔴 AYNI başlık ikinci kez pencere AÇMAZ', () async {
    // `e2eeHeader` mesaj belgesinde KALICIDIR: oturumu başlatan mesaj
    // görünür pencerede durduğu sürece her anlık görüntüde yeniden
    // gelir. Ölçüt "başlık var mı" olsaydı memo hiç tutmaz, bozuk
    // mesajlar sonsuza dek yeniden çözülmeye kalkılırdı.
    await yayinla([
      [gelen('m1')],
      [gelen('m1'), gelen('m2', header: baslik)],
      [gelen('m1'), gelen('m2', header: baslik)],
      [gelen('m1'), gelen('m2', header: baslik)],
    ]);

    // 1: m1 · 2: pencere açıldı → m1 + m2 · 3-4: yeni başlık yok.
    expect(cozmeSayisi(), 3,
        reason: 'aynı başlık tekrar tekrar pencere açarsa önbelleğin '
            'varlık sebebi ortadan kalkar');
  });

  test('başlıksız partiler memo\'yu ATMAZ', () async {
    // Yalnızca "başlık geldi" anı pencereyi açmalı; aksi hâlde birinci
    // testteki tasarruf kaybolurdu.
    await yayinla([
      [gelen('m1')],
      [gelen('m1'), gelen('m2')],
    ]);

    expect(cozmeSayisi(), 2,
        reason: 'm1 bir kez, m2 bir kez — m1 yeniden denenmemeli');
  });
}
