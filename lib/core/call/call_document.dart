/// 📞 ÇAĞRI DOKÜMANININ TEK ŞEMASI.
///
/// ── NEDEN VAR ──
/// `calls` koleksiyonuna bir zamanlar **İKİ model** yazıyordu:
///
///  * `lib/models/call_model.dart`              → CANLI yol (`CallService`)
///  * `features/call/data/models/call_model.dart` → Clean katmanı (ölü)
///
/// §4t `participants` alanını yalnızca ikincisine ekledi. Sonuç: canlı
/// çağrı dokümanı alanı hiç taşımadı ve gelen arama dinleyicisi
/// `where('participants', arrayContains: me)` **hiçbir zaman
/// eşleşmedi — hata vermeden**. Kullanıcı arama alamıyordu; kırık hâliyle
/// üretime çıktı (§4u).
///
/// Asıl sorun "iki model olması" değil, **sessizce ayrışabilmeleriydi**.
/// §4v bu dosyayı ekleyerek ayrışmayı test altına aldı; §4aj ise ölü
/// yazma yolunu tamamen kaldırdı. **Artık `calls`'a yazan tek model
/// var** — iki yazarın ayrışması yapısal olarak imkânsız.
///
/// ── O HÂLDE BU DOSYA NEDEN DURUYOR ──
/// Alan adları hâlâ ÜÇ yerde paylaşılıyor: canlı model (yazar), Clean
/// model (`fromMap` ile okur) ve `call_remote_datasource`ın sorgusu.
/// Tek doğruluk kaynağı olmasa, yazan ile okuyanın ayrışması §4u'nun
/// aynısını okuma tarafından üretirdi: sorgu kurulur, doküman gelir,
/// üyelik boş çözülür, gelen arama ekranı hiç açılmaz.
/// Turu `test/features/call/call_schema_parity_test.dart` koruyor.
library;

/// Çağrı dokümanının alan adları — tek doğruluk kaynağı.
///
/// Kural dosyası ve Cloud Functions da bu adlara dayanır; buradaki bir
/// değişiklik onlarla BİRLİKTE yapılmalıdır.
class CallFields {
  CallFields._();

  static const id = 'id';
  static const callerId = 'callerId';
  static const calleeId = 'calleeId';

  /// 👥 Üyeliğin tek kaynağı. Gelen arama sorgusu ve güvenlik kuralları
  /// bunu kullanır (§4t).
  static const participants = 'participants';

  /// 👥 GRUP ARAMASI (§4bq) — bu çağrı bir gruba mı ait?
  static const isGroup = 'isGroup';

  /// Grup aramasının bağlı olduğu sohbet kimliği.
  static const groupChatId = 'groupChatId';

  /// 🔗 MESH'E GERÇEKTEN BAĞLI OLANLAR — `participants` DEĞİL.
  ///
  /// Grup aramasında ikisi FARKLI şeydir ve karıştırılırsa arama çöker:
  ///   • `participants` = çağrının TARAFLARI. Grup aramasında bu, grubun
  ///     tüm üyeleridir; yetki (`callParty()`) ve "gelen arama" sorgusu
  ///     buna bakar. Yani herkesin telefonu çalar.
  ///   • `joinedIds`    = KABUL EDİP bağlanmış olanlar. Mesh yalnızca
  ///     bunlara eş bağlantı kurar.
  ///
  /// `participants` mesh listesi olarak kullanılsaydı, arama başlar
  /// başlamaz henüz cevap vermemiş herkese bağlantı açılırdı.
  static const joinedIds = 'joinedIds';

  static const type = 'type';
  static const status = 'status';
  static const createdAt = 'createdAt';
  static const answeredAt = 'answeredAt';
  static const endedAt = 'endedAt';
}

/// Sunucuya yazılacak çağrı dokümanını üret.
///
/// ⚠️ KULLANICI ADI ALMAZ. Çağrı dokümanı `callerUsername` /
/// `calleeUsername` yazıyordu; sunucuda "kim kimi aradı" adlarıyla
/// duruyordu (§4k/§4o'nun aramalardaki hâli). Ad artık gösterim anında
/// uid'den çözülür. Bu fonksiyonun imzasında ad parametresi
/// BULUNMAMASI kasıtlıdır: alanı geri eklemek için önce buraya
/// dokunmak gerekir.
Map<String, dynamic> buildCallDocument({
  required String id,
  required String callerId,
  required String calleeId,
  required String type,
  required String status,
  required DateTime createdAt,
  DateTime? answeredAt,
  DateTime? endedAt,
  List<String>? participants,
}) {
  final members = (participants == null || participants.isEmpty)
      ? [callerId, calleeId].where((u) => u.isNotEmpty).toList()
      : participants;

  return {
    CallFields.id: id,
    CallFields.callerId: callerId,
    CallFields.calleeId: calleeId,
    CallFields.participants: members,
    CallFields.type: type,
    CallFields.status: status,
    CallFields.createdAt: createdAt.toIso8601String(),
    CallFields.answeredAt: answeredAt?.toIso8601String(),
    CallFields.endedAt: endedAt?.toIso8601String(),
  };
}

/// 👥 Grup araması dokümanını üret (§4bq).
///
/// Birebir aramanınkinden ayrı durur çünkü ŞEMASI FARKLI ve farkları
/// sessizce kaybolursa arama kırılır:
///
///  • `calleeId` YAZILMAZ. Grup aramasında "aranan" tek kişi yoktur.
///    Alan boş bir dizgeyle yazılsaydı kural `notBlockedBy('')` yolunu
///    seçer, `get()` boş segmentle çağrılır ve DEĞERLENDİRME HATASI
///    verirdi — yani arama sessizce reddedilirdi (§4at sınıfı).
///  • `participants` grubun TÜM üyeleridir (kimin telefonu çalacak),
///    `joinedIds` ise yalnızca bağlananlar (mesh kime bağlanacak).
///    Karışırsa ya kimse arama almaz ya da henüz cevap vermemiş
///    herkese eş bağlantı açılmaya çalışılır.
Map<String, dynamic> buildGroupCallDocument({
  required String id,
  required String callerId,
  required String groupChatId,
  required List<String> participants,
  required List<String> joinedIds,
  required String type,
  required DateTime createdAt,
  String status = 'ringing',
}) {
  return {
    CallFields.id: id,
    CallFields.callerId: callerId,
    CallFields.participants: participants,
    CallFields.joinedIds: joinedIds,
    CallFields.groupChatId: groupChatId,
    CallFields.isGroup: true,
    CallFields.status: status,
    CallFields.type: type,
    CallFields.createdAt: createdAt.toUtc().toIso8601String(),
  };
}

/// Bir grup araması hâlâ CANLI mı? (§4bq)
///
/// ⚠️ ZOMBİ ARAMA KORUMASI — ve neden burada durduğu.
/// Grup araması konuşma boyunca `ringing` kalır ki geç katılan onu
/// bulabilsin. Son ayrılan `ended` yazar, ama uygulama öldürülürse o
/// yazma HİÇ OLMAZ. O zaman iki yer birden bozulur:
///   • yeni arama başlatan istemci ölü aramaya "katılır" ve kimseyi
///     bulamaz,
///   • her üyenin cihazı, uygulama her açıldığında gelen arama ekranını
///     açar — grup sonsuza dek çalar.
/// İki yer de aynı kararı vermek zorunda olduğu için ölçüt ortak şema
/// dosyasında durur.
///
/// [canliSuresi] varsayılan 4 saat; [simdi] testten verilebilir.
bool grupCagrisiCanli(
  Map<String, dynamic> map, {
  DateTime? simdi,
  Duration canliSuresi = const Duration(hours: 4),
}) {
  if (map[CallFields.status] != 'ringing') return false;
  // Kimse bağlı değilse arama ölmüştür.
  final bagli = (map[CallFields.joinedIds] as List?) ?? const [];
  if (bagli.isEmpty) return false;
  final t = DateTime.tryParse((map[CallFields.createdAt] ?? '').toString());
  if (t == null) return false;
  final an = (simdi ?? DateTime.now()).toUtc();
  return an.difference(t.toUtc()) < canliSuresi;
}

/// Dokümandan katılımcıları oku.
///
/// ⚠️ ESKİ DOKÜMAN YEDEĞİ: bu alandan önce yazılmış çağrılarda dizi
/// yoktur; iki taraftan türetilir ki şema değişimi sırasında DEVAM EDEN
/// bir arama erişilemez hâle gelmesin (§4m'nin dersi).
List<String> readParticipants(Map<String, dynamic> map) {
  final raw = (map[CallFields.participants] as List?)
      ?.map((e) => e.toString())
      .where((e) => e.isNotEmpty)
      .toList();
  if (raw != null && raw.isNotEmpty) return raw;
  return [map[CallFields.callerId], map[CallFields.calleeId]]
      .map((e) => (e ?? '').toString())
      .where((e) => e.isNotEmpty)
      .toList();
}
