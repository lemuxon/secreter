import '../../services/auth_service.dart';

/// Mevcut kullanıcı bilgisine erişim soyutlaması.
///
/// NEDEN: Repository ve servisler doğrudan statik `AuthService.currentUid`
/// çağırırsa test edilemez (statik mock'lanamaz). Bu arayüz enjekte edilir,
/// testte sahte (fake) bir versiyonu verilir.
///
/// Bu, eski statik AuthService'i yeni mimariye köprüleyen ince bir katman.
abstract class CurrentUserProvider {
  String? get currentUid;
  Future<String?> get currentUsername;
}

/// Üretim implementasyonu — eski statik AuthService'i sarmalar.
class CurrentUserProviderImpl implements CurrentUserProvider {
  @override
  String? get currentUid => AuthService.currentUid;

  @override
  Future<String?> get currentUsername async {
    final user = await AuthService.getCurrentUserData();
    return user?.username;
  }
}
