import 'package:equatable/equatable.dart';

enum ConversationType { direct, group, channel }

/// Sohbet listesindeki bir konuşmanın domain temsili.
class ConversationEntity extends Equatable {
  /// 🕵️ uid → görünen ad çözümleyici (METADATA GİZLİLİĞİ 2. AŞAMA).
  ///
  /// Sohbet dokümanı artık `memberUsernames` YAZMIYOR; başlıktaki ad
  /// gösterim anında uid'den çözülür. Domain katmanı Firestore'a
  /// bağlanmasın diye çözümleyici bir fonksiyon olarak DIŞARIDAN takılır
  /// (`initDependencies` → `UsernameResolver.cached`). Takılmamışsa
  /// (birim testleri, erken açılış) yalnızca eski dokümanlardaki dizi
  /// kullanılır — başlık boş kalmaz.
  static String? Function(String uid)? nameResolver;

  /// 🌐 Yedek başlıkların çevirisi (`title_group_fallback`,
  /// `title_chat_fallback`).
  ///
  /// Bu sınıf `BuildContext` göremez ama ürettiği metin doğrudan ekrana
  /// çıkar. Sabit Türkçe bırakılırsa 16 dilli uygulamada bir Alman
  /// kullanıcı "Sohbet" görürdü. Çeviri de [nameResolver] gibi dışarıdan
  /// takılır (`main.dart`, dil değişiminde tazelenir); takılı değilse
  /// Türkçe'ye düşer — başlık asla boş kalmaz.
  static String Function(String key)? labelResolver;

  static String _label(String key, String fallback) =>
      labelResolver?.call(key) ?? fallback;

  final String id;
  final ConversationType type;
  final List<String> memberIds;

  /// ⚠️ ESKİ DOKÜMAN YEDEĞİ — yeni sohbetlerde BOŞ gelir.
  /// Bu alan artık sunucuya yazılmaz; yalnızca 2. aşamadan önce
  /// oluşturulmuş dokümanlarda dolu olduğu için okunmaya devam eder.
  final List<String> memberUsernames;
  final String? groupName;
  final String? avatarUrl;
  final String? adminId;
  final bool incognito;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCounts;
  final DateTime? lastMessageTime;
  final int memberCount;

  const ConversationEntity({
    required this.id,
    required this.type,
    required this.memberIds,
    this.memberUsernames = const [],
    this.groupName,
    this.avatarUrl,
    this.adminId,
    this.incognito = false,
    this.lastMessage,
    this.lastMessageSenderId,
    this.unreadCounts = const {},
    this.lastMessageTime,
    this.memberCount = 0,
  });

  bool get isDirect => type == ConversationType.direct;
  bool get isChannel => type == ConversationType.channel;
  bool get isGroup => type == ConversationType.group;

  /// Listede gösterilecek başlık.
  /// Direkt sohbette karşı tarafın adı, grup/kanalda grup adı.
  ///
  /// Sıra ÖNEMLİ: önce canlı çözüm (`nameResolver`), sonra eski
  /// dokümandaki dizi. Dizi bayat kalabiliyordu — kullanıcı adını
  /// değiştirdiğinde sohbet dokümanı güncellenmiyordu; çözümleyici ise
  /// `users/{uid}` üzerinden güncel adı verir.
  String displayTitle(String myUid) {
    if (!isDirect) {
      return groupName ?? _label('title_group_fallback', 'Grup');
    }
    final otherId = otherUserId(myUid);
    if (otherId != null) {
      final resolved = nameResolver?.call(otherId);
      if (resolved != null && resolved.isNotEmpty) return resolved;
    }
    final idx = memberIds.indexWhere((id) => id != myUid);
    if (idx != -1 && idx < memberUsernames.length) {
      final legacy = memberUsernames[idx];
      if (legacy.isNotEmpty) return legacy;
    }
    return _label('title_chat_fallback', 'Sohbet');
  }

  /// Avatar baş harfi
  /// Bu kullanici grubu/kanali silebilir mi (yalnizca yonetici).
  bool isAdmin(String uid) => adminId != null && adminId == uid;

  /// Benim okunmamis mesaj sayim (rozet icin).
  int unreadFor(String uid) => unreadCounts[uid] ?? 0;

  /// 1-1 sohbette karşı kullanıcının uid'i (grup/kanalda null).
  String? otherUserId(String myUid) {
    if (type != ConversationType.direct) return null;
    final idx = memberIds.indexWhere((id) => id != myUid);
    return idx >= 0 ? memberIds[idx] : null;
  }

  String avatarLetter(String myUid) {
    final t = displayTitle(myUid);
    return t.isNotEmpty ? t[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [
        id,
        type,
        memberIds,
        lastMessage,
        lastMessageTime,
        lastMessageSenderId,
        memberCount,
        groupName,
        avatarUrl,
        adminId,
        unreadCounts,
        incognito,
      ];
}
