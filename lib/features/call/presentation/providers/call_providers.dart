import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/usecases/call_usecases.dart';

/// Gelen çağrıları canlı dinleyen provider.
/// UI bunu izleyip gelen çağrı ekranını açar.
///
/// NOT: Asıl WebRTC bağlantı yönetimi (RTCPeerConnection, MediaStream,
/// kamera/mikrofon) eski CallService'te kalır — bunlar UI-ömürlü canlı
/// kaynaklar olduğu için Clean Architecture'ın "data" katmanına oturmaz.
/// Bu provider sadece sinyalleşme durumunu (kim arıyor) sağlar.
final incomingCallProvider = StreamProvider<CallEntity?>((ref) {
  final watchIncoming = getIt<WatchIncomingCall>();
  return watchIncoming(const NoParams()).map(
    (either) => either.fold((failure) => null, (call) => call),
  );
});

/// Belirli bir çağrının durumunu dinleyen provider (family)
final callStatusProvider =
    StreamProvider.family<CallEntity?, String>((ref, callId) {
  final watchCall = getIt<WatchCall>();
  return watchCall(callId).map(
    (either) => either.fold((failure) => null, (call) => call),
  );
});
