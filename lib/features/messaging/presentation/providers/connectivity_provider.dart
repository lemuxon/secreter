import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/network_info.dart';

/// Ağ bağlantısı durumunu canlı sağlayan provider.
/// UI offline banner göstermek için bunu dinler.
final connectivityProvider = StreamProvider<bool>((ref) {
  final networkInfo = getIt<NetworkInfo>();
  // PERFORMANS: bazi cihazlar (ozellikle MIUI) AYNI degeri tekrar tekrar
  // yayinlar; distinct ile tekillestir — gereksiz rebuild kaynaginda kesilir.
  return networkInfo.onConnectivityChanged.distinct();
});

/// Anlık bağlantı durumu (başlangıç değeri için)
final isConnectedProvider = FutureProvider<bool>((ref) async {
  final networkInfo = getIt<NetworkInfo>();
  return networkInfo.isConnected;
});
