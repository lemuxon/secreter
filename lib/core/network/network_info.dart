import 'package:connectivity_plus/connectivity_plus.dart';

/// Ağ bağlantısı durumunu sağlar.
/// Repository, online/offline karar vermek için bunu kullanır.
///
/// NOT: connectivity_plus 6.0+ sonuçları liste olarak döndürür
/// (cihaz aynı anda wifi+mobil gibi birden fazla bağlantıya sahip olabilir).
/// Bağlantı yoksa liste [ConnectivityResult.none] içerir.
abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;
  NetworkInfoImpl(this.connectivity);

  @override
  Future<bool> get isConnected async {
    final results = await connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return connectivity.onConnectivityChanged
        .map((results) => !results.contains(ConnectivityResult.none));
  }
}
