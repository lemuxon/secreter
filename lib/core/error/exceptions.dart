// DataSource katmanında fırlatılan exception'lar.
// Repository bunları yakalayıp Failure'a çevirir.
//
// ⚠️ VARSAYILAN MESAJLAR i18n ANAHTARIDIR, düz metin DEĞİL.
// Repository bunları `Failure(e.message)` ile aynen taşıyor ve metin
// doğrudan ekrana çıkıyor. Sabit Türkçe yazılırsa 16 dilli uygulamada
// herkes Türkçe hata görür (bkz. §4q).
//
// NOT: Hepsi `const` kurucuya sahip — sabit mesajlı istisnalar gereksiz
// tahsis yapmasın ve `throw const XException(...)` yazılabilsin.

class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'err_server']);
  @override
  String toString() => 'ServerException: $message';
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'err_network']);
  @override
  String toString() => 'NetworkException: $message';
}

class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'err_auth']);
  @override
  String toString() => 'AuthException: $message';
}

class EncryptionException implements Exception {
  final String message;
  const EncryptionException([this.message = 'err_crypto']);
  @override
  String toString() => 'EncryptionException: $message';
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'err_cache']);
  @override
  String toString() => 'CacheException: $message';
}
