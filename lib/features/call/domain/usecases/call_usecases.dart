import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/call_entity.dart';
import '../repositories/call_repository.dart';

/// ⚠️ BU KATMAN ÇAĞRIYI **BAŞLATMAZ** — YALNIZCA DİNLER VE REDDEDER.
///
/// Çağrı akışının motoru `lib/services/call_service.dart`tır; `calls`
/// koleksiyonuna yazan **tek** yer orasıdır. Bu Clean katmanı o
/// dokümanları OKUR (`WatchIncomingCall`, `WatchCall`) ve tek bir
/// durum güncellemesi yapar (`RejectCall`).
///
/// ── 🐞 NEDEN BU AYRIM ÖNEMLİ (§4t/§4u) ──
/// §4t'de `participants` alanı YALNIZCA bu katmandaki modele eklendi,
/// canlı yol atlandı. Çağrı dokümanı alanı taşımadı ve gelen arama
/// dinleyicisi HİÇ eşleşmedi — hata vermeden. Kırık hâliyle üretime
/// çıktı (§4u).
///
/// Kök sebep "iki model" değil, **`calls`'a yazan iki yol** idi. §4v
/// ortak şemayla ayrışmayı test altına aldı; §4aj ölü yazma yolunu
/// (`StartCall`/`AnswerCall`/`EndCall` ve altlarındaki
/// `createCall`/`setAnswer`/`deleteCall`) tamamen KALDIRDI. Artık tek
/// yazar var, yani o ayrışma **yapısal olarak** imkânsız.
///
/// ⚠️ Buraya bir YAZMA usecase'i eklemek istiyorsan: yapma. Çağrı
/// başlatma/cevaplama `CallService`e aittir; ikinci bir yazar §4u'yu
/// geri getirir.

/// Gelen çağrıları dinle
class WatchIncomingCall implements StreamUseCase<CallEntity?, NoParams> {
  final CallRepository repository;
  WatchIncomingCall(this.repository);

  @override
  Stream<Either<Failure, CallEntity?>> call(NoParams params) =>
      repository.watchIncomingCall();
}

/// Çağrı durumunu dinle
class WatchCall implements StreamUseCase<CallEntity, String> {
  final CallRepository repository;
  WatchCall(this.repository);

  @override
  Stream<Either<Failure, CallEntity>> call(String callId) =>
      repository.watchCall(callId);
}

/// Çağrıyı reddet
class RejectCall implements UseCase<Unit, String> {
  final CallRepository repository;
  RejectCall(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String callId) =>
      repository.updateStatus(callId, CallStatus.rejected);
}
