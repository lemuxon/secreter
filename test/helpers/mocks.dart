import 'package:mocktail/mocktail.dart';
import 'package:gizli_chat/features/messaging/domain/repositories/message_repository.dart';
import 'package:gizli_chat/features/messaging/data/datasources/message_remote_datasource.dart';
import 'package:gizli_chat/features/messaging/data/datasources/message_local_datasource.dart';
import 'package:gizli_chat/features/messaging/data/datasources/encryption_datasource.dart';
import 'package:gizli_chat/core/network/network_info.dart';
import 'package:gizli_chat/core/auth/current_user_provider.dart';
import 'package:gizli_chat/features/messaging/data/datasources/message_sync_service.dart';

/// Tüm mock sınıfları burada tanımlanır.
/// mocktail codegen gerektirmez — sadece extend + implements yeterli.

class MockMessageRepository extends Mock implements MessageRepository {}

class MockMessageRemoteDataSource extends Mock
    implements MessageRemoteDataSource {}

class MockMessageLocalDataSource extends Mock
    implements MessageLocalDataSource {}

class MockEncryptionDataSource extends Mock implements EncryptionDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockMessageSyncService extends Mock implements MessageSyncService {}

class MockCurrentUserProvider extends Mock implements CurrentUserProvider {}
