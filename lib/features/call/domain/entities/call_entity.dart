import 'package:equatable/equatable.dart';

enum CallType { audio, video }

enum CallStatus {
  // ⚠️ `dialing`i SİLME — "kullanılmıyor" gibi görünür ama OKUMA
  // yedeğidir. Canlı motor (`CallService`) bu değeri hiç yazmaz
  // (`ringing` ile başlar) ve onu yazan tek yer olan ölü `createCall`
  // §4aj'de kaldırıldı. Ama ESKİ `calls` dokümanlarında bulunabilir;
  // değer silinirse `fromMap`in `orElse`i onları sessizce `ended`
  // yapar — çalan bir arama "bitmiş" görünür.
  dialing, // Arıyor (yalnızca eski dokümanlarda)
  ringing, // Çalıyor (karşı tarafta)
  ongoing, // Devam ediyor
  ended, // Bitti
  rejected, // Reddedildi
  missed, // Cevapsız
}

/// Çağrının domain temsili — sinyalleşme meta verisi.
/// NOT: Canlı RTCPeerConnection bu entity'de DEĞİL; o presentation
/// katmanındaki CallSessionService'te yaşar (UI-ömürlü kaynak).
class CallEntity extends Equatable {
  /// 🕵️ uid → görünen ad çözümleyici (METADATA GİZLİLİĞİ).
  ///
  /// Çağrı dokümanı `callerUsername`/`calleeUsername` alanlarını DÜZ
  /// METİN yazıyordu; yani sunucuda "kim kimi aradı" adlarıyla
  /// duruyordu. §4k mesajlardan, §4o sohbet dokümanından temizlemişti —
  /// aramalar gözden kaçmıştı.
  ///
  /// Alan artık yazılmıyor; ad gösterim anında uid'den çözülür.
  /// Domain katmanı Firestore'a bağlanmasın diye çözüm dışarıdan
  /// takılır (`initDependencies`), tıpkı `ConversationEntity`de olduğu
  /// gibi.
  static String? Function(String uid)? nameResolver;

  final String id;
  final String callerId;

  /// ⚠️ ESKİ DOKÜMAN YEDEĞİ — yeni çağrılarda BOŞ gelir.
  /// Gösterim için [callerName] kullanın.
  final String callerUsername;
  final String calleeId;

  /// ⚠️ ESKİ DOKÜMAN YEDEĞİ — gösterim için [calleeName].
  final String calleeUsername;

  /// 👥 Çağrının KATILIMCILARI — yetkinin tek doğruluk kaynağı.
  ///
  /// Şema eskiden `callerId`/`calleeId` ikilisine ÇAKILIYDI: güvenlik
  /// kuralları, gelen arama sorgusu ve ICE aday yolları hep "iki taraf"
  /// varsayıyordu. Grup araması bu varsayımı kıramadan eklenemezdi.
  ///
  /// `callerId` KORUNUR (kim başlattı + engel kontrolü), `calleeId` de
  /// birebir aramada anlamlıdır; ama ÜYELİK artık bu dizidir.
  final List<String> participants;

  /// 👥 GRUP ARAMASI MI? (§4bq)
  ///
  /// Gelen arama ekranı buna bakar: grup aramasında "reddet" çağrıyı
  /// BİTİREMEZ — bitirseydi bir kişinin reddi herkesin aramasını
  /// kapatırdı. Birebir aramada ise reddetmek tam olarak budur.
  final bool isGroup;

  /// Grup aramasının bağlı olduğu sohbet (grup aramasında dolu).
  final String groupChatId;

  /// 🔗 MESH'E BAĞLI OLANLAR. `participants` çağrının taraflarıdır
  /// (grupta: tüm üyeler); bu ise KABUL EDİP bağlananlar.
  final List<String> joinedIds;

  final CallType type;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  const CallEntity({
    required this.id,
    required this.callerId,
    required this.callerUsername,
    required this.calleeId,
    required this.calleeUsername,
    this.participants = const [],
    this.isGroup = false,
    this.groupChatId = '',
    this.joinedIds = const [],
    required this.type,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  /// Arayanın gösterilecek adı: önce canlı çözüm, sonra eski alan.
  String get callerName => _display(callerId, callerUsername);

  /// Aranan tarafın gösterilecek adı.
  String get calleeName => _display(calleeId, calleeUsername);

  static String _display(String uid, String legacy) {
    final resolved = nameResolver?.call(uid);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    if (legacy.isNotEmpty) return legacy;
    return uid.length > 6 ? uid.substring(0, 6) : uid;
  }

  bool get isVideo => type == CallType.video;
  bool get isActive =>
      status == CallStatus.dialing ||
      status == CallStatus.ringing ||
      status == CallStatus.ongoing;

  /// Çağrı süresi (cevaplandıysa)
  Duration? get duration {
    if (answeredAt == null) return null;
    final end = endedAt ?? DateTime.now();
    return end.difference(answeredAt!);
  }

  /// Bu kullanıcı çağrının tarafı mı? (kural motorundaki `isParticipant`
  /// ile aynı mantık; eski dokümanlarda dizi boş olabilir.)
  bool includes(String uid) => participants.isEmpty
      ? (uid == callerId || uid == calleeId)
      : participants.contains(uid);

  /// Birebir aramada karşı taraf (grup aramasında null).
  String? peerOf(String myUid) {
    final others = participants.isEmpty
        ? [callerId, calleeId].where((u) => u != myUid && u.isNotEmpty)
        : participants.where((u) => u != myUid);
    return others.length == 1 ? others.first : null;
  }

  @override
  List<Object?> get props => [
        id,
        callerId,
        calleeId,
        participants,
        isGroup,
        groupChatId,
        joinedIds,
        type,
        status,
        createdAt,
        answeredAt,
        endedAt
      ];
}
