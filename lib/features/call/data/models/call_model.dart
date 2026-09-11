import '../../domain/entities/call_entity.dart';
import '../../../../core/call/call_document.dart';

/// Call DTO — çağrı dokümanının **OKUMA** görünümü.
///
/// ⚠️ `toMap()` YOK, bilerek. Bu modelin bir zamanlar `toMap()`i vardı
/// ve `calls` koleksiyonuna doküman yazıyordu (ölü `createCall` yolu).
/// §4t'de `participants` yalnızca ona eklenince canlı doküman alanı
/// taşımadı ve gelen arama sessizce kırıldı (§4u).
///
/// §4v ayrışmayı ortak şemayla test altına aldı; §4aj ölü yazma yolunu
/// tamamen kaldırdı. `calls`'a yazan tek model artık
/// `lib/models/call_model.dart` (CANLI, `CallService`) — yani iki
/// yazarın ayrışması **yapısal olarak** imkânsız.
///
/// Geriye gerçek bir bağ kalıyor ve testle korunuyor: **canlı modelin
/// yazdığını bu modelin `fromMap`i okuyabilmeli.** Okuyamazsa gelen
/// arama yine sessizce boş döner — §4u'nun okuma tarafındaki hâli.
/// (`test/features/call/call_schema_parity_test.dart`)
class CallModel extends CallEntity {
  const CallModel({
    required super.id,
    required super.callerId,
    required super.callerUsername,
    required super.calleeId,
    required super.calleeUsername,
    super.participants,
    super.isGroup,
    super.groupChatId,
    super.joinedIds,
    required super.type,
    required super.status,
    required super.createdAt,
    super.answeredAt,
    super.endedAt,
  });

  factory CallModel.fromMap(Map<String, dynamic> map) => CallModel(
        id: map['id'] ?? '',
        callerId: map['callerId'] ?? '',
        callerUsername: map['callerUsername'] ?? '',
        calleeId: map['calleeId'] ?? '',
        calleeUsername: map['calleeUsername'] ?? '',
        participants: readParticipants(map),
        // 👥 §4bq — grup araması alanları. Birebir aramada yoktur;
        // varsayılanlar eski dokümanları da güvenle okur.
        isGroup: map[CallFields.isGroup] == true,
        groupChatId: (map[CallFields.groupChatId] ?? '').toString(),
        joinedIds: (map[CallFields.joinedIds] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[],
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
}
