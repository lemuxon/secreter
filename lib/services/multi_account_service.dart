import 'dart:convert';
import '../core/security/secure_store.dart';

/// Cihazda birden fazla anonim hesabı saklar ve aralarında geçişi yönetir.
/// Her hesabın uid, kullanıcı adı ve şifreleme anahtarı güvenli depoda tutulur.
class MultiAccountService {
  static const _secure = SecureStore.instance;
  static const _accountsKey = 'saved_accounts';
  static const _activeAccountKey = 'active_account_uid';

  /// Kayıtlı hesap özeti
  static Future<List<SavedAccount>> getAccounts() async {
    final raw = await _secure.read(key: _accountsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SavedAccount.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Yeni hesap kaydet (kayıt veya girişten sonra)
  /// Cihazda tutulabilecek EN FAZLA hesap sayısı.
  /// Sınır: her hesap ayrı E2EE anahtar seti ve oturum taşır; sınırsız
  /// hesap hem güvenli depolamayı şişirir hem kullanıcı için karışıklık
  /// yaratır.
  static const int maxAccounts = 3;

  /// Yeni hesap eklenebilir mi? (mevcut hesaplar sınırın altında mı)
  static Future<bool> canAddAccount() async {
    try {
      final list = await getAccounts();
      return list.length < maxAccounts;
    } catch (_) {
      return true; // okunamadıysa engelleme
    }
  }

  static Future<void> saveAccount(SavedAccount account) async {
    final accounts = await getAccounts();
    // Aynı uid varsa güncelle
    final index = accounts.indexWhere((a) => a.uid == account.uid);
    if (index != -1) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }
    await _secure.write(
      key: _accountsKey,
      value: jsonEncode(accounts.map((a) => a.toMap()).toList()),
    );
    await setActiveAccount(account.uid);
  }

  /// Aktif hesabı değiştir
  static Future<void> setActiveAccount(String uid) async {
    await _secure.write(key: _activeAccountKey, value: uid);
  }

  static Future<String?> getActiveAccountUid() async {
    return await _secure.read(key: _activeAccountKey);
  }

  /// Hesabı cihazdan kaldır (sunucudaki veri silinmez)
  static Future<void> removeAccount(String uid) async {
    final accounts = await getAccounts();
    accounts.removeWhere((a) => a.uid == uid);
    await _secure.write(
      key: _accountsKey,
      value: jsonEncode(accounts.map((a) => a.toMap()).toList()),
    );
  }

  static Future<bool> hasMultipleAccounts() async {
    return (await getAccounts()).length > 1;
  }
}

class SavedAccount {
  final String uid;
  final String username;
  final String encryptionKey;

  /// Gizli geri-donus sifresi (email/password ile yeniden girise izin verir).
  /// Eski surumde olusturulan hesaplarda bos olur -> gecis yapilamaz.
  final String password;

  SavedAccount({
    required this.uid,
    required this.username,
    required this.encryptionKey,
    this.password = '',
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'encryptionKey': encryptionKey,
        'password': password,
      };

  factory SavedAccount.fromMap(Map<String, dynamic> map) => SavedAccount(
        uid: map['uid'] ?? '',
        username: map['username'] ?? '',
        encryptionKey: map['encryptionKey'] ?? '',
        password: map['password'] ?? '',
      );
}
