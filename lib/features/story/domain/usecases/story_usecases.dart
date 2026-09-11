import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/story_entity.dart';
import '../repositories/story_repository.dart';

/// Aktif hikayeleri canlı dinle
class WatchActiveStories
    implements StreamUseCase<List<UserStoriesEntity>, NoParams> {
  final StoryRepository repository;
  WatchActiveStories(this.repository);

  @override
  Stream<Either<Failure, List<UserStoriesEntity>>> call(NoParams params) {
    return repository.watchActiveStories();
  }
}

/// Metin durumu paylaş (validasyon: boş olamaz, maks 280 karakter)
class PostTextStory implements UseCase<Unit, PostTextStoryParams> {
  final StoryRepository repository;
  PostTextStory(this.repository);

  @override
  Future<Either<Failure, Unit>> call(PostTextStoryParams params) async {
    final trimmed = params.text.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('err_status_empty'));
    }
    if (trimmed.length > 280) {
      return const Left(ValidationFailure('err_status_too_long'));
    }
    return repository.postTextStory(
      text: trimmed,
      backgroundColor: params.backgroundColor,
    );
  }
}

class PostTextStoryParams extends Equatable {
  final String text;
  final String backgroundColor;
  const PostTextStoryParams({
    required this.text,
    required this.backgroundColor,
  });

  @override
  List<Object?> get props => [text, backgroundColor];
}

/// Fotoğraf durumu paylaş
class PostImageStory implements UseCase<Unit, PostImageStoryParams> {
  final StoryRepository repository;
  PostImageStory(this.repository);

  @override
  Future<Either<Failure, Unit>> call(PostImageStoryParams params) {
    return repository.postImageStory(
      imageFile: params.imageFile,
      caption: params.caption,
    );
  }
}

class PostImageStoryParams extends Equatable {
  final File imageFile;
  final String? caption;
  const PostImageStoryParams({required this.imageFile, this.caption});

  @override
  List<Object?> get props => [imageFile.path, caption];
}

/// Hikayeyi görüntülendi işaretle
class MarkStoryViewed implements UseCase<Unit, String> {
  final StoryRepository repository;
  MarkStoryViewed(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String storyId) {
    return repository.markViewed(storyId);
  }
}

/// Hikayeyi sil
class DeleteStory implements UseCase<Unit, String> {
  final StoryRepository repository;
  DeleteStory(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String storyId) {
    return repository.deleteStory(storyId);
  }
}
