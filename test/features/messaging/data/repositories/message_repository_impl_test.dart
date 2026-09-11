import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';
import 'package:gizli_chat/core/error/exceptions.dart';
import 'package:gizli_chat/core/error/failures.dart';
import 'package:gizli_chat/features/messaging/data/datasources/encryption_datasource.dart';
import 'package:gizli_chat/features/messaging/data/models/message_model.dart';
import 'package:gizli_chat/features/messaging/data/repositories/message_repository_impl.dart';
import 'package:gizli_chat/features/messaging/domain/entities/message_entity.dart';
import 'package:gizli_chat/core/privacy/privacy_controller.dart';
import 'package:gizli_chat/core/privacy/privacy_settings.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MessageRepositoryImpl repository;
  late MockMessageRemoteDataSource mockRemote;
  late MockMessageLocalDataSource mockLocal;
  late MockEncryptionDataSource mockEncryption;
  late MockNetworkInfo mockNetwork;
  late MockMessageSyncService mockSync;
  late MockCurrentUserProvider mockUserProvider;

  setUpAll(() {
    registerFallbackValue(
      MessageModel(
        id: 'fallback',
        chatId: 'c',
        senderId: 's',
        senderUsername: 'u',
        content: '',
        type: MessageContentType.text,
        timestamp: DateTime(2026),
      ),
    );
    registerFallbackValue(<String>[]);
    // Yükleme metotları `File`/`Uint8List` alıyor; `verifyNever(... any() ...)`
    // için mocktail'in her ikisine de geçerli bir yedek örnek istiyor.
    registerFallbackValue(File(''));
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockRemote = MockMessageRemoteDataSource();
    mockLocal = MockMessageLocalDataSource();
    mockEncryption = MockEncryptionDataSource();
    mockNetwork = MockNetworkInfo();
    mockSync = MockMessageSyncService();
    mockUserProvider = MockCurrentUserProvider();

    when(() => mockUserProvider.currentUid).thenReturn('user1');
    when(() => mockUserProvider.currentUsername)
        .thenAnswer((_) async => 'kullanici1');

    // ── DÜZ METİN YAŞAM DÖNGÜSÜ ──
    // Repository artık düz metin önbelleğini statik `E2EESessionService`
    // yerine enjekte edilen datasource üzerinden yönetiyor. Eskiden statik
    // çağrı platform kanalına (flutter_secure_storage) iniyor ve BU
    // TESTLER "Binding has not yet been initialized" ile DÜŞÜYORDU.
    when(() => mockEncryption.cachePlaintext(any(), any()))
        .thenAnswer((_) async {});
    // §4bi: çözme yolu artık önbelleği tek çağrıyla ısıtıyor.
    when(() => mockEncryption.warmPlaintextCache()).thenAnswer((_) async {});
    when(() => mockEncryption.forgetPlaintext(any())).thenAnswer((_) async {});
    when(() => mockEncryption.forgetPlaintexts(any())).thenAnswer((_) async {});
    when(() => mockEncryption.wipeAllPlaintexts()).thenAnswer((_) async {});

    final privacyReader = PrivacySettingsReader()
      ..update(PrivacySettings.standard());

    repository = MessageRepositoryImpl(
      remoteDataSource: mockRemote,
      localDataSource: mockLocal,
      encryptionDataSource: mockEncryption,
      networkInfo: mockNetwork,
      syncService: mockSync,
      userProvider: mockUserProvider,
      privacyReader: privacyReader,
      uuid: const Uuid(),
    );
  });

  const chatId = 'user1_user2';

  group('sendTextMessage', () {
    void stubEncryption() {
      when(() => mockEncryption.encrypt(
            chatId: any(named: 'chatId'),
            otherUserId: any(named: 'otherUserId'),
            plaintext: any(named: 'plaintext'),
          )).thenAnswer((_) async => EncryptionResult(
            ciphertext: 'şifreli',
            isEncrypted: true,
          ));
    }

    void stubHappyPath() {
      stubEncryption();
      when(() => mockLocal.cacheMessage(any(), any())).thenAnswer((_) async {});
      when(() => mockLocal.addPendingMessage(any())).thenAnswer((_) async {});
      when(() => mockRemote.sendMessage(any(), any())).thenAnswer((_) async {});
      when(() => mockRemote.updateLastMessage(any(), any(),
          senderId: any(named: 'senderId'))).thenAnswer((_) async {});
    }

    test('ONLINE iken: mesaj direkt remote\'a gönderilir', () async {
      stubHappyPath();
      when(() => mockNetwork.isConnected).thenAnswer((_) async => true);

      final result =
          await repository.sendTextMessage(chatId: chatId, text: 'Merhaba');

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => mockRemote.sendMessage(chatId, any())).called(1);
      verifyNever(() => mockLocal.addPendingMessage(any()));
    });

    test('OFFLINE iken: mesaj pending kuyruğuna eklenir', () async {
      stubHappyPath();
      when(() => mockNetwork.isConnected).thenAnswer((_) async => false);

      final result = await repository.sendTextMessage(
          chatId: chatId, text: 'Offline mesaj');

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => mockLocal.addPendingMessage(any())).called(1);
      verifyNever(() => mockRemote.sendMessage(any(), any()));
    });

    test('her durumda mesaj önce cache\'lenir (optimistic update)', () async {
      stubHappyPath();
      when(() => mockNetwork.isConnected).thenAnswer((_) async => true);

      await repository.sendTextMessage(chatId: chatId, text: 'Test');

      verify(() => mockLocal.cacheMessage(chatId, any())).called(1);
    });

    test('gönderilen mesajın düz metni cihazda saklanır', () async {
      stubHappyPath();
      when(() => mockNetwork.isConnected).thenAnswer((_) async => true);

      await repository.sendTextMessage(chatId: chatId, text: 'Merhaba');

      // Ratchet tek yönlü: gönderen kendi şifreli metnini çözemez, bu
      // yüzden düz metin saklanmak ZORUNDA.
      verify(() => mockEncryption.cachePlaintext(any(), 'Merhaba')).called(1);
    });

    test('önizlemeye İÇERİK yazılmaz (gizlilik)', () async {
      stubHappyPath();
      when(() => mockNetwork.isConnected).thenAnswer((_) async => true);

      await repository.sendTextMessage(
          chatId: chatId, text: 'gizli içerik burada');

      // ⚠️ REGRESYON KORUMASI: eski kod şifresiz sohbetlerde mesajın TAM
      // METNİNİ `chats.lastMessage` alanına düz yazıyordu — yani içerik
      // sunucuda açıkta duruyordu.
      final captured = verify(() => mockRemote.updateLastMessage(
            chatId,
            captureAny(),
            senderId: any(named: 'senderId'),
          )).captured;
      expect(captured.single, '🔒 Mesaj');
      expect(captured.single, isNot(contains('gizli içerik')));
    });

    test('remote hata fırlatırsa ServerFailure döner', () async {
      stubHappyPath();
      when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
      when(() => mockRemote.sendMessage(any(), any()))
          .thenThrow(const ServerException('Firestore hatası'));

      final result =
          await repository.sendTextMessage(chatId: chatId, text: 'Test');

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Hata dönmeliydi'),
      );
    });

    test('remote hata fırlatırsa mesaj KAYBOLMAZ, kuyruğa alınır', () async {
      stubHappyPath();
      when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
      when(() => mockRemote.sendMessage(any(), any()))
          .thenThrow(const ServerException('Firestore hatası'));

      await repository.sendTextMessage(chatId: chatId, text: 'Kaybolmasın');

      // ⚠️ REGRESYON KORUMASI: eski kodun yorumu "ağ hatası → pending'e
      // ekle" diyordu ama kod bunu YAPMIYORDU; gönderim patlayınca mesaj
      // kalıcı olarak kayboluyordu.
      verify(() => mockLocal.addPendingMessage(any())).called(1);
    });
  });

  /// 🐞 KAPATILAN AÇIK: üye listesi okunamayınca grup mesajı ŞİFRESİZ
  /// gidiyordu.
  ///
  /// `_membersOf` istisnayı yutup `const []` dönüyordu. Boş liste,
  /// şifreleme katmanında bir ARIZA olarak değil bir DURUM olarak
  /// okunuyordu: `encrypt()` içindeki `memberIds.length < 2` dalı
  /// "dejenere grup" sayıp mesajı düz metin gönderiyordu. Yani GEÇİCİ bir
  /// Firestore okuma hatası, grup mesajının sunucuya açık gitmesine
  /// yetiyordu — C-06'nın §4x'te kapatılan davranışı, başka bir kapıdan.
  ///
  /// §4x'in ilkesi: arızada mesaj GÖNDERİLMEZ.
  group('grup üye listesi okunamazsa mesaj GÖNDERİLMEZ', () {
    // Alt çizgiyle ikiye bölünemeyen kimlik = grup/kanal.
    const groupId = 'grup-abc';

    setUp(() {
      when(() => mockNetwork.isConnected).thenAnswer((_) async => true);
      when(() => mockLocal.cacheMessage(any(), any())).thenAnswer((_) async {});
      when(() => mockRemote.sendMessage(any(), any())).thenAnswer((_) async {});
      when(() => mockRemote.updateLastMessage(any(), any(),
          senderId: any(named: 'senderId'))).thenAnswer((_) async {});
      when(() => mockRemote.uploadMedia(any(), any(), any()))
          .thenAnswer((_) async => 'https://ornek/duz');
      when(() => mockRemote.uploadMediaBytes(any(), any(), any()))
          .thenAnswer((_) async => 'https://ornek/sifreli');

      // ⚠️ ŞİFRELEME KATMANI GERÇEĞİ TAKLİT EDER: iki üyeden az olan bir
      // grupta `encrypt()` mesajı DÜZ METİN döndürür. Bu stub olmadan
      // testler yanlış sebeple geçerdi — yutulan hata geri gelse bile
      // stublanmamış mock null döner ve gönderim zaten patlardı.
      when(() => mockEncryption.encrypt(
            chatId: any(named: 'chatId'),
            otherUserId: any(named: 'otherUserId'),
            plaintext: any(named: 'plaintext'),
            memberIds: any(named: 'memberIds'),
          )).thenAnswer((inv) async {
        final members =
            inv.namedArguments[#memberIds] as List<String>? ?? const [];
        final plaintext = inv.namedArguments[#plaintext] as String;
        return members.length < 2
            ? EncryptionResult(ciphertext: plaintext, isEncrypted: false)
            : EncryptionResult(ciphertext: 'şifreli', isEncrypted: true);
      });

      // Üye listesi okunamıyor.
      when(() => mockRemote.memberIds(any()))
          .thenThrow(const ServerException('err_server'));
    });

    test('ServerFailure döner ve mesaj SUNUCUYA HİÇ gitmez', () async {
      final result =
          await repository.sendTextMessage(chatId: groupId, text: 'gizli');

      expect(result.isLeft(), isTrue,
          reason: 'arıza kullanıcıya görünür bir hataya dönmeli');
      verifyNever(() => mockRemote.sendMessage(any(), any()));
    });

    test('ŞİFRELEME KATMANINA BOŞ ÜYE LİSTESİ GEÇİLMEZ', () async {
      // Asıl regresyon buydu: boş liste geçilirse `encrypt()` mesajı
      // "dejenere grup" sayıp DÜZ METİN döndürürdü.
      await repository.sendTextMessage(chatId: groupId, text: 'gizli');

      verifyNever(() => mockEncryption.encrypt(
            chatId: any(named: 'chatId'),
            otherUserId: any(named: 'otherUserId'),
            plaintext: any(named: 'plaintext'),
            memberIds: any(named: 'memberIds'),
          ));
    });

    test('medya yolunda da gönderilmez, dosya YÜKLENMEZ', () async {
      // ⚠️ GERÇEK bir dosya şart: `sendMediaMessage` üye listesini
      // okumadan ÖNCE `file.length()` çağırıyor. Var olmayan bir yolla
      // test, üyelik yolunu hiç çalıştırmadan "dosya bulunamadı" ile
      // geçerdi — yanlış sebeple geçen bir test, korumasız bir testtir.
      final tmp = File(
          '${Directory.systemTemp.path}/secreter_uye_testi_${DateTime.now().microsecondsSinceEpoch}.jpg')
        ..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync();
      });

      final result = await repository.sendMediaMessage(
        chatId: groupId,
        localFilePath: tmp.path,
        type: MessageContentType.image,
      );

      expect(result.isLeft(), isTrue);
      verifyNever(() => mockRemote.sendMessage(any(), any()));
      // Şifrelenmemiş dosya Storage'a HİÇ çıkmamalı.
      verifyNever(() => mockRemote.uploadMedia(any(), any(), any()));
      verifyNever(() => mockRemote.uploadMediaBytes(any(), any(), any()));
    });
  });

  group('deleteMessage', () {
    test('remote deleteMessage çağrılır ve başarı döner', () async {
      when(() => mockRemote.deleteMessage(any(), any()))
          .thenAnswer((_) async {});

      final result = await repository.deleteMessage(
        chatId: chatId,
        messageId: 'msg1',
      );

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => mockRemote.deleteMessage(chatId, 'msg1')).called(1);
    });

    test('silinen mesajın CİHAZDAKİ düz metni de silinir', () async {
      when(() => mockRemote.deleteMessage(any(), any()))
          .thenAnswer((_) async {});

      await repository.deleteMessage(chatId: chatId, messageId: 'msg1');

      // ⚠️ REGRESYON KORUMASI: çözülmüş düz metin güvenli depoda
      // saklanıyor ama hiçbir yerde silinmiyordu — bu, "kaybolan mesaj"
      // ve "herkesten sil" özelliklerini cihazda tamamen etkisiz kılıyordu.
      verify(() => mockEncryption.forgetPlaintexts(any())).called(1);
    });
  });

  group('deleteForEveryone', () {
    test('düz metin kopyaları da temizlenir', () async {
      when(() => mockRemote.deleteForEveryone(any(), any()))
          .thenAnswer((_) async {});

      final result = await repository.deleteForEveryone(chatId, ['m1', 'm2']);

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => mockEncryption.forgetPlaintexts(any())).called(1);
    });
  });

  group('editMessage', () {
    void stubEdit({bool encrypted = true}) {
      when(() => mockEncryption.encrypt(
            chatId: any(named: 'chatId'),
            otherUserId: any(named: 'otherUserId'),
            plaintext: any(named: 'plaintext'),
            memberIds: any(named: 'memberIds'),
          )).thenAnswer((_) async => EncryptionResult(
            ciphertext: encrypted ? 'ŞİFRELİ-DÜZENLEME' : 'düzeltilmiş metin',
            isEncrypted: encrypted,
          ));
      when(() => mockRemote.editMessage(
            any(),
            any(),
            any(),
            isEncrypted: any(named: 'isEncrypted'),
            editedAt: any(named: 'editedAt'),
            e2eeHeader: any(named: 'e2eeHeader'),
          )).thenAnswer((_) async {});
    }

    test('düzenlenen metin SUNUCUYA DÜZ GİTMEZ', () async {
      // ⚠️ REGRESYON KORUMASI: düzenlenen metin Firestore'a düz
      // yazılıyordu — yani bir mesajı düzeltmek, onu sunucuya açık
      // göndermek demekti.
      stubEdit();

      final result = await repository.editMessage(
        chatId: chatId,
        messageId: 'm1',
        newText: 'gizli düzeltme',
      );

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => mockRemote.editMessage(
            chatId,
            'm1',
            'ŞİFRELİ-DÜZENLEME',
            isEncrypted: true,
            editedAt: any(named: 'editedAt'),
            e2eeHeader: any(named: 'e2eeHeader'),
          )).called(1);
      // Düz metin hiçbir çağrıda sunucuya gitmemeli.
      verifyNever(() => mockRemote.editMessage(
            any(),
            any(),
            'gizli düzeltme',
            isEncrypted: any(named: 'isEncrypted'),
            editedAt: any(named: 'editedAt'),
            e2eeHeader: any(named: 'e2eeHeader'),
          ));
    });

    test('ESKİ düz metin cihazdan silinir', () async {
      // Düzenlemenin amacı çoğu zaman yazılanı geri almaktır; eski metin
      // güvenli depoda kalırsa bu boşa çıkar.
      stubEdit();

      await repository.editMessage(
        chatId: chatId,
        messageId: 'm1',
        newText: 'yeni',
      );

      verify(() => mockEncryption.forgetPlaintext('m1')).called(1);
    });

    test('düz metin SÜRÜMLÜ anahtarla önbelleğe alınır', () async {
      // Önbellek yalnızca mesaj kimliğiyle anahtarlansaydı, alıcı
      // düzenlemeden sonra da ESKİ metni görürdü.
      stubEdit();

      await repository.editMessage(
        chatId: chatId,
        messageId: 'm1',
        newText: 'yeni',
      );

      final captured =
          verify(() => mockEncryption.cachePlaintext(captureAny(), 'yeni'))
              .captured
              .single as String;
      expect(captured, startsWith('m1#'),
          reason: 'anahtar düzenleme damgasını taşımalı');
      expect(captured, isNot('m1'));
    });

    test('şifrelenemezse isE2EE FALSE yazılır', () async {
      // Yanıltıcı kilit simgesi gösterilmemeli: içerik gerçekten açıksa
      // bayrak da bunu söylemeli. (Eski kod bayrağı HİÇ yazmıyordu.)
      stubEdit(encrypted: false);

      await repository.editMessage(
        chatId: chatId,
        messageId: 'm1',
        newText: 'düzeltilmiş metin',
      );

      verify(() => mockRemote.editMessage(
            chatId,
            'm1',
            'düzeltilmiş metin',
            isEncrypted: false,
            editedAt: any(named: 'editedAt'),
            e2eeHeader: any(named: 'e2eeHeader'),
          )).called(1);
    });
  });
}
