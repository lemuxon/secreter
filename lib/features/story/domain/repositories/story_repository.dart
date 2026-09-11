import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/story_entity.dart';

/// Hikaye veri erişiminin sözleşmesi (soyut arayüz).
abstract class StoryRepository {
  /// Tüm aktif hikayeleri kullanıcı bazında canlı dinle
  Stream<Either<Failure, List<UserStoriesEntity>>> watchActiveStories();

  /// Metin durumu paylaş
  Future<Either<Failure, Unit>> postTextStory({
    required String text,
    required String backgroundColor,
  });

  /// Fotoğraf durumu paylaş
  Future<Either<Failure, Unit>> postImageStory({
    required File imageFile,
    String? caption,
  });

  /// Hikayeyi görüntülendi işaretle
  Future<Either<Failure, Unit>> markViewed(String storyId);

  /// Hikayeyi sil
  Future<Either<Failure, Unit>> deleteStory(String storyId);
}
