import 'package:equatable/equatable.dart';

/// Hikaye/durum tipi
enum StoryMediaType { text, image, video }

/// Hikayenin domain temsili — veri kaynağından bağımsız.
class StoryEntity extends Equatable {
  final String id;
  final String userId;
  final String username;
  final StoryMediaType type;
  final String? mediaUrl;
  final String? text;
  final String? backgroundColor;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;

  const StoryEntity({
    required this.id,
    required this.userId,
    required this.username,
    required this.type,
    this.mediaUrl,
    this.text,
    this.backgroundColor,
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
  });

  /// İş kuralı: 24 saat doldu mu?
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Belirli kullanıcı gördü mü?
  bool isViewedBy(String uid) => viewedBy.contains(uid);

  int get viewCount => viewedBy.length;

  @override
  List<Object?> get props =>
      [id, userId, type, mediaUrl, text, createdAt, expiresAt, viewedBy];
}

/// Bir kullanıcının tüm aktif hikayeleri (görüntüleyici için gruplanmış).
class UserStoriesEntity extends Equatable {
  final String userId;
  final String username;
  final List<StoryEntity> stories;

  const UserStoriesEntity({
    required this.userId,
    required this.username,
    required this.stories,
  });

  /// Bu kullanıcının tüm hikayelerini gördü mü? (halka rengi için)
  bool allViewedBy(String uid) => stories.every((s) => s.isViewedBy(uid));

  @override
  List<Object?> get props => [userId, username, stories];
}
