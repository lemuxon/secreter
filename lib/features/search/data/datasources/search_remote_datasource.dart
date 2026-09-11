import '../../../../core/error/exceptions.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/direct_chat_service.dart';
import '../../domain/entities/found_user.dart';
import '../../../../core/observability/handled_error.dart';

/// Arama + sohbet başlatma uzak kaynağı.
/// AuthService (kullanıcı bulma) + DirectChatService (sohbet oluşturma)
/// servislerini sarmalar.
abstract class SearchRemoteDataSource {
  Future<FoundUser?> findByUsername(String username);
  Future<String> getOrCreateDirectChat(String username);
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  @override
  Future<FoundUser?> findByUsername(String username) async {
    try {
      final user = await AuthService.findUserByUsername(username);
      if (user == null) return null;
      return FoundUser(
        uid: user.uid,
        username: user.username,
        isOnline: user.isOnline,
      );
    } catch (e, s) {
      reportHandled('Kullanıcı aranamadı', e, stack: s);
      throw const ServerException('err_user_search');
    }
  }

  @override
  Future<String> getOrCreateDirectChat(String username) async {
    try {
      final user = await AuthService.findUserByUsername(username);
      if (user == null) {
        throw const ServerException('err_user_gone');
      }
      return await DirectChatService.getOrCreate(user);
    } on ServerException {
      rethrow;
    } catch (e, s) {
      reportHandled('Sohbet oluşturulamadı', e, stack: s);
      throw const ServerException('err_chat_create');
    }
  }
}
