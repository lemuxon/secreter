class UserModel {
  final String uid;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final bool isOnline;
  final DateTime lastSeen;
  final String publicKey; // Şifreleme için

  UserModel({
    required this.uid,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.isOnline = false,
    required this.lastSeen,
    required this.publicKey,
  });

  /// ⚠️ `isOnline` BİLEREK YAZILMAZ (§4ar).
  ///
  /// Bu alan yalnızca kayıt anında bir kez `true` yazılıyor ve bir daha
  /// GÜNCELLENMİYORDU. Çevrimiçi durumunun tek yazıcısı
  /// `PresenceService`tir ve o `online` alanına yazar. İki alan yan yana
  /// durunca arama sonucu ölü olanı okuyup HERKESİ hep "çevrimiçi"
  /// gösteriyordu. Ölü alanı yazmayı bırakıyoruz.
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'lastSeen': lastSeen.toIso8601String(),
        'publicKey': publicKey,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] ?? '',
        username: map['username'] ?? '',
        avatarUrl: map['avatarUrl'],
        bio: map['bio'],
        // 🐞 ESKİDEN `map['isOnline']` OKUNUYORDU. O alan yalnızca kayıtta
        // `true` yazılıp bir daha güncellenmediği için arama sonucundaki
        // nokta HERKES için hep yeşil yanıyordu — kişi aylardır girmemiş
        // olsa bile. Üstelik kullanıcının "varlığımı paylaşma" ayarını da
        // yok sayıyordu: PresenceService ayar kapalıyken `online: false`
        // yazar, ama kimse o alana bakmıyordu.
        isOnline: map['online'] == true,
        lastSeen: DateTime.tryParse(map['lastSeen'] ?? '') ?? DateTime.now(),
        publicKey: map['publicKey'] ?? '',
      );
}
