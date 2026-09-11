import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/auth/current_user_provider.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/repositories/story_repository.dart';
import '../datasources/story_remote_datasource.dart';
import '../models/story_model.dart';
import '../../../../core/observability/handled_error.dart';

/// StoryRepository implementasyonu.
///
/// İş mantığı: süresi dolan hikayeleri filtreler + auto-delete tetikler,
/// hikayeleri kullanıcı bazında gruplar.
class StoryRepositoryImpl implements StoryRepository {
  final StoryRemoteDataSource remoteDataSource;
  final CurrentUserProvider userProvider;
  final Uuid uuid;

  StoryRepositoryImpl({
    required this.remoteDataSource,
    required this.userProvider,
    required this.uuid,
  });

  @override
  Stream<Either<Failure, List<UserStoriesEntity>>> watchActiveStories() {
    return remoteDataSource.watchStories().map((stories) {
      try {
        final active = <StoryModel>[];
        for (final s in stories) {
          if (s.isExpired) {
            // Süresi dolanı sil (fire-and-forget)
            remoteDataSource.deleteStory(s.id).catchError((_) {});
          } else {
            active.add(s);
          }
        }

        // Kullanıcıya göre grupla
        final grouped = <String, List<StoryModel>>{};
        for (final s in active) {
          grouped.putIfAbsent(s.userId, () => []).add(s);
        }

        final userStories = grouped.entries
            .map((e) => UserStoriesEntity(
                  userId: e.key,
                  username: e.value.first.username,
                  stories: e.value,
                ))
            .toList();

        return Right<Failure, List<UserStoriesEntity>>(userStories);
      } catch (e, s) {
        reportHandled('watchStories', e, stack: s);
        return const Left<Failure, List<UserStoriesEntity>>(
            UnexpectedFailure());
      }
    }).handleError((Object error, StackTrace st) {
      reportHandled('watchStories', error, stack: st);
      return const Left<Failure, List<UserStoriesEntity>>(ServerFailure());
    });
  }

  @override
  Future<Either<Failure, Unit>> postTextStory({
    required String text,
    required String backgroundColor,
  }) async {
    try {
      final username = await userProvider.currentUsername;
      final now = DateTime.now();
      final story = StoryModel(
        id: uuid.v4(),
        userId: userProvider.currentUid!,
        username: username ?? '',
        type: StoryMediaType.text,
        text: text,
        backgroundColor: backgroundColor,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );
      await remoteDataSource.createStory(story);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('postTextStory', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> postImageStory({
    required File imageFile,
    String? caption,
  }) async {
    try {
      final username = await userProvider.currentUsername;
      final storyId = uuid.v4();
      final now = DateTime.now();

      final url = await remoteDataSource.uploadImage(storyId, imageFile);

      final story = StoryModel(
        id: storyId,
        userId: userProvider.currentUid!,
        username: username ?? '',
        type: StoryMediaType.image,
        mediaUrl: url,
        text: caption,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );
      await remoteDataSource.createStory(story);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('postImageStory', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> markViewed(String storyId) async {
    try {
      final uid = userProvider.currentUid;
      if (uid == null) return const Left(AuthFailure());
      await remoteDataSource.markViewed(storyId, uid);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('markViewed', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteStory(String storyId) async {
    try {
      await remoteDataSource.deleteStory(storyId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e, s) {
      reportHandled('deleteStory', e, stack: s);
      return const Left(UnexpectedFailure());
    }
  }
}
