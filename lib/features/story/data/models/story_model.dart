import '../../domain/entities/story_entity.dart';

/// Hikayenin data temsili — entity + Firestore serileştirme.
class StoryModel extends StoryEntity {
  const StoryModel({
    required super.id,
    required super.userId,
    required super.username,
    required super.type,
    super.mediaUrl,
    super.text,
    super.backgroundColor,
    required super.createdAt,
    required super.expiresAt,
    super.viewedBy,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'username': username,
        'type': type.name,
        'mediaUrl': mediaUrl,
        'text': text,
        'backgroundColor': backgroundColor,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'viewedBy': viewedBy,
      };

  factory StoryModel.fromMap(Map<String, dynamic> map) => StoryModel(
        id: map['id'] ?? '',
        userId: map['userId'] ?? '',
        username: map['username'] ?? '',
        type: StoryMediaType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => StoryMediaType.text,
        ),
        mediaUrl: map['mediaUrl'],
        text: map['text'],
        backgroundColor: map['backgroundColor'],
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        expiresAt: DateTime.tryParse(map['expiresAt'] ?? '') ??
            DateTime.now().add(const Duration(hours: 24)),
        viewedBy: List<String>.from(map['viewedBy'] ?? []),
      );
}
