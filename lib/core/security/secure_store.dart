import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/observability/handled_error.dart';

/// 🔐 GÜVENLİ DEPOLAMA — TEK YAPILANDIRMA
///
/// Android'de `encryptedSharedPreferences: true` kullanılır: veriler
/// AES-256 ile şifreli tutulur ve Keystore'a doğrudan bağımlılık azalır.
/// Bu, paket adı değişimi (com.gizlichat.gizli_chat → com.secreter.app)
/// sonrası yaşanan `PlatformException` dalgasının çözümüydü.
///
/// ⚠️ `resetOnError` NEDEN KAPALI:
/// Açıkken, okunamayan tek bir girdi SESSİZCE SİLİNİYORDU. Bu depoda
/// kimlik anahtarı, E2EE oturum durumu ve hesap kurtarma parolası duruyor;
/// yani "bozuk girdiyi sil" davranışı, kullanıcının TÜM hesabını ve mesaj
/// geçmişini haber vermeden yok edebiliyordu. Artık hata YUTULMAZ:
/// [readOrThrow] gerçek istisnayı yükseltir, çağıran taraf kullanıcıya
/// kurtarma akışı gösterebilir. [read] ise yalnızca "kritik olmayan"
/// okumalar için yumuşak sürümdür.
class SecureStore {
  SecureStore._();

  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Depo erişilemez hâle geldiğinde en az bir kez tetiklenir.
  /// Arayüz buna bağlanıp kullanıcıya "kurtarma anahtarınla gir" diyebilir.
  static VoidCallback? onStorageFailure;

  static bool _failureReported = false;

  static void _reportFailure(Object error) {
    debugPrint('SecureStore ERİŞİM HATASI: $error');
    if (_failureReported) return;
    _failureReported = true;
    try {
      onStorageFailure?.call();
    } catch (_) {
      // bildirim başarısız olsa da akışı kırma
    }
  }

  /// Kritik okuma — hata durumunda İSTİSNA FIRLATIR.
  /// Kripto anahtarları ve oturum durumu için bunu kullan: sessizce
  /// "anahtar yok" varsaymak, yeni anahtar üretilmesine ve tüm eski
  /// mesajların okunamaz hâle gelmesine yol açar.
  static Future<String?> readOrThrow({required String key}) async {
    try {
      return await instance.read(key: key);
    } catch (e) {
      _reportFailure(e);
      throw SecureStoreException('Güvenli depo okunamadı ($key): $e');
    }
  }

  /// Yumuşak okuma — yalnızca kritik OLMAYAN tercihler için.
  static Future<String?> read(String key) async {
    try {
      return await instance.read(key: key);
    } catch (e) {
      _reportFailure(e);
      return null;
    }
  }

  /// Kritik yazma — hata durumunda İSTİSNA FIRLATIR.
  static Future<void> writeOrThrow({
    required String key,
    required String? value,
  }) async {
    try {
      await instance.write(key: key, value: value);
    } catch (e) {
      _reportFailure(e);
      throw SecureStoreException('Güvenli depoya yazılamadı ($key): $e');
    }
  }

  /// Yumuşak yazma — başarı durumunu bool olarak döner.
  static Future<bool> write(String key, String? value) async {
    try {
      await instance.write(key: key, value: value);
      return true;
    } catch (e) {
      _reportFailure(e);
      return false;
    }
  }

  static Future<void> delete(String key) async {
    try {
      await instance.delete(key: key);
    } catch (e, s) {
      reportHandled('Güvenli depodan silinemedi', e, stack: s);
    }
  }

  /// Verilen önekle başlayan TÜM anahtarları sil.
  /// Çıkış, hesap değişimi ve mesaj silme temizliği için gerekir —
  /// bu olmadan eski hesabın düz metin mesajları cihazda kalıyordu.
  /// TÜM girdileri TEK platform çağrısıyla oku.
  ///
  /// ⚠️ NEDEN VAR: düz metin önbelleği mesaj başına ayrı `read()` yapıyordu.
  /// Android'de her okuma EncryptedSharedPreferences'a bir platform kanalı
  /// çağrısıdır; 200 mesajlık bir sohbette 200 çağrı demektir ve sohbet
  /// saniyelerce "yükleniyor" kalır (§4bi). Bu metot N çağrıyı 1'e indirir.
  ///
  /// Hata durumunda BOŞ döner (yumuşak): ısınma başarısız olursa tek tek
  /// okumaya geri düşülür, veri kaybı olmaz.
  static Future<Map<String, String>> readAll() async {
    try {
      return await instance.readAll();
    } catch (e) {
      _reportFailure(e);
      return const {};
    }
  }

  static Future<void> deleteByPrefix(String prefix) async {
    try {
      final all = await instance.readAll();
      // Anahtarların KOPYASI üzerinde dön: bazı uygulamalar readAll'dan
      // canlı bir görünüm döndürür ve silerken üzerinde gezmek
      // ConcurrentModificationError üretir (silme yarıda kalır).
      for (final key in all.keys.toList()) {
        if (key.startsWith(prefix)) {
          await instance.delete(key: key);
        }
      }
    } catch (e, s) {
      // ⚠️ C-07: bu temizlik çıkış ve hesap değişiminde çalışır;
      // başarısız olursa ESKİ HESABIN düz metin mesajları cihazda kalır.
      reportHandled('Güvenli depo önek temizliği başarısız', e, stack: s);
    }
  }
}

class SecureStoreException implements Exception {
  final String message;
  const SecureStoreException(this.message);
  @override
  String toString() => message;
}
