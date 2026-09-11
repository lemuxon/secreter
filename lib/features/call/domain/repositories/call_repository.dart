import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/call_entity.dart';

/// ⚠️ ÇAĞRI DOKÜMANINI **OKUR**, OLUŞTURMAZ.
///
/// `calls` koleksiyonuna yazan tek yer `lib/services/call_service.dart`
/// (offer/answer/ICE/sonlandırma). Bu sözleşme yalnızca o dokümanları
/// dinler ve tek bir durum geçişi yapar (reddetme).
///
/// ── 🐞 NEDEN YAZMA YÜZEYİ YOK (§4t/§4u/§4aj) ──
/// Burada bir zamanlar `createCall`/`answerCall`/`endCall`/`getAnswer`
/// vardı; hiçbiri çağrılmıyordu ama `calls`'a TAM BİR DOKÜMAN yazacak
/// koda sahiptiler. §4t'de alan yalnızca bu katmana eklenince canlı
/// doküman `participants` taşımadı ve gelen arama sessizce kırıldı
/// (§4u). Ölü yazma yolu §4aj'de kaldırıldı: tek yazar kaldığı için o
/// ayrışma artık **yapısal olarak** imkânsız.
///
/// ⚠️ Buraya yazma metodu ekleme. Çağrı başlatma/cevaplama
/// `CallService`e aittir; ikinci bir yazar §4u'yu geri getirir.
abstract class CallRepository {
  /// Gelen çağrıları dinle (kendine gelen)
  Stream<Either<Failure, CallEntity?>> watchIncomingCall();

  /// Belirli bir çağrının durumunu dinle
  Stream<Either<Failure, CallEntity>> watchCall(String callId);

  /// Çağrı durumunu güncelle (reddetme yolu).
  Future<Either<Failure, Unit>> updateStatus(String callId, CallStatus status);
}
