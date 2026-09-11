import '../core/call/call_document.dart';

enum CallType { audio, video }

enum CallStatus {
  ringing, // Çalıyor (henüz cevaplanmadı)
  ongoing, // Görüşme devam ediyor
  ended, // Bitti
  rejected, // Reddedildi
  missed, // Cevapsız
}

class CallModel {
  final String id;
  final String callerId;
  final String callerUsername;
  final String calleeId;
  final String calleeUsername;
  final CallType type;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  CallModel({
    required this.id,
    required this.callerId,
    required this.callerUsername,
    required this.calleeId,
    required this.calleeUsername,
    required this.type,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  /// ⚠️ BU MODEL CANLI YOLDUR — `CallService` bunu kullanır.
  ///
  /// Doküman ORTAK şemadan üretilir (`buildCallDocument`). Clean
  /// katmanındaki model de aynı yeri kullanır; §4u'da iki modelin
  /// sessizce ayrışması gelen aramayı tamamen kırmıştı.
  Map<String, dynamic> toMap() => buildCallDocument(
        id: id,
        callerId: callerId,
        calleeId: calleeId,
        type: type.name,
        status: status.name,
        createdAt: createdAt,
        answeredAt: answeredAt,
        endedAt: endedAt,
      );

  factory CallModel.fromMap(Map<String, dynamic> map) => CallModel(
        id: map['id'] ?? '',
        callerId: map['callerId'] ?? '',
        callerUsername: map['callerUsername'] ?? '',
        calleeId: map['calleeId'] ?? '',
        calleeUsername: map['calleeUsername'] ?? '',
        type: CallType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => CallType.audio,
        ),
        status: CallStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => CallStatus.ended,
        ),
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        answeredAt: DateTime.tryParse(map['answeredAt'] ?? ''),
        endedAt: DateTime.tryParse(map['endedAt'] ?? ''),
      );

  /// Görüşme süresi
  Duration? get duration {
    if (answeredAt == null || endedAt == null) return null;
    return endedAt!.difference(answeredAt!);
  }
}
