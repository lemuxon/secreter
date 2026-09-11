import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

// Core
import '../network/network_info.dart';
import '../security/security_service.dart';
import '../security/security_service_impl.dart';
import '../auth/current_user_provider.dart';
import '../observability/app_logger.dart';
import '../observability/crash_reporter.dart';
import '../observability/crashlytics_reporter.dart';
import '../privacy/privacy_controller.dart';

// Messaging feature
import '../../features/messaging/data/datasources/message_remote_datasource.dart';
import '../../features/messaging/data/datasources/message_local_datasource.dart';
import '../../features/messaging/data/datasources/message_sync_service.dart';
import '../../features/messaging/data/datasources/encryption_datasource.dart';
import '../../features/messaging/data/datasources/encryption_datasource_impl.dart';
import '../../features/messaging/data/repositories/message_repository_impl.dart';
import '../../features/messaging/domain/repositories/message_repository.dart';
import '../../features/messaging/domain/usecases/watch_messages.dart';
import '../../features/messaging/domain/usecases/send_text_message.dart';
import '../../features/messaging/domain/usecases/manage_message.dart';

// Story feature
import '../../features/story/data/datasources/story_remote_datasource.dart';
import '../../features/story/data/repositories/story_repository_impl.dart';
import '../../features/story/domain/repositories/story_repository.dart';
import '../../features/story/domain/usecases/story_usecases.dart';

// Group feature
import '../../features/group/data/datasources/group_remote_datasource.dart';
import '../../features/group/data/repositories/group_repository_impl.dart';
import '../../features/group/domain/repositories/group_repository.dart';
import '../../features/group/domain/usecases/group_usecases.dart';

// Call feature
import '../../features/call/data/datasources/call_remote_datasource.dart';
import '../../features/call/data/repositories/call_repository_impl.dart';
import '../../features/call/domain/repositories/call_repository.dart';
import '../../features/call/domain/usecases/call_usecases.dart';

// Metadata gizliliği (uid → ad çözümü)
import '../../services/username_resolver.dart';
import '../../features/conversations/domain/entities/conversation_entity.dart';
import '../../features/group/domain/entities/group_entity.dart';

// Conversations feature
import '../../features/conversations/data/datasources/conversation_remote_datasource.dart';
import '../../features/conversations/data/repositories/conversation_repository_impl.dart';
import '../../features/conversations/domain/repositories/conversation_repository.dart';
import '../../features/conversations/domain/usecases/conversation_usecases.dart';

// Auth feature
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

// Search feature
import '../../features/search/data/datasources/search_remote_datasource.dart';
import '../../features/search/data/repositories/search_repository_impl.dart';
import '../../features/search/domain/repositories/search_repository.dart';
import '../../features/call/domain/entities/call_entity.dart';

/// Global service locator.
final getIt = GetIt.instance;

/// Tüm bağımlılıkları kaydet. main()'de bir kez çağrılır.
///
/// Kayıt türleri:
/// - registerLazySingleton: ilk istendiğinde oluşturulur, sonra tekrar kullanılır
/// - registerFactory: her istendiğinde yeni örnek
///
/// Katman sırası: dış (Firebase) → datasource → repository → usecase
Future<void> initDependencies() async {
  // ── Harici (third-party) ──
  getIt.registerLazySingleton<FirebaseFirestore>(
      () => FirebaseFirestore.instance);
  getIt.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  getIt.registerLazySingleton<Uuid>(() => const Uuid());
  getIt.registerLazySingleton<Connectivity>(() => Connectivity());

  // ── Core ──
  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(getIt()));
  getIt.registerLazySingleton<SecurityService>(() => SecurityServiceImpl());
  getIt.registerLazySingleton<CurrentUserProvider>(
      () => CurrentUserProviderImpl());

  // ── Gözlemlenebilirlik & Gizlilik ──
  getIt.registerLazySingleton<AppLogger>(() => ConsoleLogger());
  getIt.registerLazySingleton<CrashReporter>(() => CrashlyticsReporter());
  getIt.registerLazySingleton<PrivacySettingsReader>(
      () => PrivacySettingsReader());

  // ── Messaging Feature ──
  _initMessaging();

  // ── Story Feature ──
  _initStory();

  // ── Group Feature ──
  _initGroup();

  // ── Call Feature ──
  _initCall();

  // ── Conversations Feature ──
  _initConversations();

  // ── Auth Feature ──
  _initAuth();

  // ── Search Feature ──
  _initSearch();

  // ── Metadata gizliliği: uid → ad çözümü ──
  _initNameResolution();
}

/// 🕵️ Domain katmanına ad çözümleyiciyi TAK.
///
/// Sohbet dokümanı artık üye adlarını taşımıyor (§4o); başlıklar ve üye
/// listeleri adı uid'den çözer. Domain varlıkları Firestore'a doğrudan
/// bağlanmasın diye çözüm bir fonksiyon olarak buradan geçirilir —
/// varlıklar saf kalır, birim testleri Firebase istemez.
///
/// `cached` SENKRONDUR: arayüz çizim yolunda `await` edilemez. Ağ
/// okumasını depolar önceden yapar (`UsernameResolver.warm`).
void _initNameResolution() {
  ConversationEntity.nameResolver = UsernameResolver.cached;
  GroupMemberEntity.nameResolver = UsernameResolver.cached;
  CallEntity.nameResolver = UsernameResolver.cached;
}

void _initMessaging() {
  // DataSources
  getIt.registerLazySingleton<MessageRemoteDataSource>(
    () => MessageRemoteDataSourceImpl(
      firestore: getIt(),
      storage: getIt(),
      uuid: getIt(),
    ),
  );
  getIt.registerLazySingleton<MessageLocalDataSource>(
    () => MessageLocalDataSourceImpl(),
  );
  getIt.registerLazySingleton<EncryptionDataSource>(
    () => EncryptionDataSourceImpl(),
  );

  // Sync service (retry kuyruğu)
  getIt.registerLazySingleton<MessageSyncService>(
    () => MessageSyncService(
      localDataSource: getIt(),
      remoteDataSource: getIt(),
      networkInfo: getIt(),
    ),
  );

  // Repository
  getIt.registerLazySingleton<MessageRepository>(
    () => MessageRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
      encryptionDataSource: getIt(),
      networkInfo: getIt(),
      syncService: getIt(),
      userProvider: getIt(),
      privacyReader: getIt(),
      uuid: getIt(),
    ),
  );

  // Use cases
  getIt.registerFactory(() => WatchMessages(getIt()));
  getIt.registerFactory(() => SendTextMessage(getIt()));
  getIt.registerFactory(() => DeleteMessage(getIt()));
  getIt.registerFactory(() => EditMessage(getIt()));
  getIt.registerFactory(() => SetReaction(getIt()));
  getIt.registerFactory(() => SendMediaMessage(getIt()));
  getIt.registerFactory(() => ConsumeViewOnce(getIt()));
  getIt.registerFactory(() => SendGifMessage(getIt()));
  getIt.registerFactory(() => SendPollMessage(getIt()));
  getIt.registerFactory(() => MarkAsRead(getIt()));
  getIt.registerFactory(() => ClearChat(getIt()));
  getIt.registerFactory(() => DeleteForMe(getIt()));
  getIt.registerFactory(() => DeleteForEveryone(getIt()));
  getIt.registerFactory(() => GetOlderMessages(getIt()));
}

void _initStory() {
  // DataSource
  getIt.registerLazySingleton<StoryRemoteDataSource>(
    () => StoryRemoteDataSourceImpl(
      firestore: getIt(),
      storage: getIt(),
      uuid: getIt(),
    ),
  );

  // Repository
  getIt.registerLazySingleton<StoryRepository>(
    () => StoryRepositoryImpl(
      remoteDataSource: getIt(),
      userProvider: getIt(),
      uuid: getIt(),
    ),
  );

  // Use cases
  getIt.registerFactory(() => WatchActiveStories(getIt()));
  getIt.registerFactory(() => PostTextStory(getIt()));
  getIt.registerFactory(() => PostImageStory(getIt()));
  getIt.registerFactory(() => MarkStoryViewed(getIt()));
  getIt.registerFactory(() => DeleteStory(getIt()));
}

void _initGroup() {
  // DataSource
  getIt.registerLazySingleton<GroupRemoteDataSource>(
    () => GroupRemoteDataSourceImpl(firestore: getIt()),
  );

  // Repository
  getIt.registerLazySingleton<GroupRepository>(
    () => GroupRepositoryImpl(
      remoteDataSource: getIt(),
      userProvider: getIt(),
    ),
  );

  // Use cases
  getIt.registerFactory(() => WatchGroup(getIt()));
  getIt.registerFactory(() => GetInviteCode(getIt()));
  getIt.registerFactory(() => JoinByInviteCode(getIt()));
  getIt.registerFactory(() => ChangeMemberRole(getIt()));
  getIt.registerFactory(() => MuteMember(getIt()));
  getIt.registerFactory(() => RemoveMember(getIt()));
  getIt.registerFactory(() => CreateChannel(getIt()));
  getIt.registerFactory(() => CreateGroup(getIt()));
}

void _initCall() {
  // DataSource
  getIt.registerLazySingleton<CallRemoteDataSource>(
    () => CallRemoteDataSourceImpl(firestore: getIt()),
  );

  // Repository
  getIt.registerLazySingleton<CallRepository>(
    () => CallRepositoryImpl(
      remoteDataSource: getIt(),
      userProvider: getIt(),
    ),
  );

  // Use cases — çağrıyı BAŞLATAN usecase YOK, bilerek.
  // Başlatma/cevaplama `CallService`e ait; `StartCall`/`AnswerCall`/
  // `EndCall` burada kayıtlıydı ama hiç çözümlenmiyordu ve §4aj'de
  // kaldırıldı (ölü yazma yüzeyi — §4u'nun kök sebebi).
  getIt.registerFactory(() => WatchIncomingCall(getIt()));
  getIt.registerFactory(() => WatchCall(getIt()));
  getIt.registerFactory(() => RejectCall(getIt()));
}

void _initConversations() {
  // DataSource
  getIt.registerLazySingleton<ConversationRemoteDataSource>(
    () => ConversationRemoteDataSourceImpl(firestore: getIt()),
  );

  // Repository
  getIt.registerLazySingleton<ConversationRepository>(
    () => ConversationRepositoryImpl(
      remoteDataSource: getIt(),
      userProvider: getIt(),
    ),
  );

  // Use cases
  getIt.registerFactory(() => WatchConversations(getIt()));
}

void _initAuth() {
  // Repository (AuthService motorunu sarmalar)
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
}

void _initSearch() {
  // DataSource
  getIt.registerLazySingleton<SearchRemoteDataSource>(
    () => SearchRemoteDataSourceImpl(),
  );

  // Repository
  getIt.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(
      remoteDataSource: getIt(),
      userProvider: getIt(),
    ),
  );
}
