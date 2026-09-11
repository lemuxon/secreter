import 'dart:async';
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/story_entity.dart';
import '../../domain/usecases/story_usecases.dart';

/// Hikaye listesi durumu
class StoryState extends Equatable {
  final List<UserStoriesEntity> userStories;
  final bool isLoading;
  final String? error;
  final bool isPosting;

  const StoryState({
    this.userStories = const [],
    this.isLoading = false,
    this.error,
    this.isPosting = false,
  });

  factory StoryState.initial() => const StoryState(isLoading: true);

  StoryState copyWith({
    List<UserStoriesEntity>? userStories,
    bool? isLoading,
    String? error,
    bool? isPosting,
    bool clearError = false,
  }) {
    return StoryState(
      userStories: userStories ?? this.userStories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isPosting: isPosting ?? this.isPosting,
    );
  }

  @override
  List<Object?> get props => [userStories, isLoading, error, isPosting];
}

/// Hikaye durumunu yöneten notifier
class StoryNotifier extends StateNotifier<StoryState> {
  final WatchActiveStories _watchStories;
  final PostTextStory _postText;
  final PostImageStory _postImage;
  final MarkStoryViewed _markViewed;
  final DeleteStory _deleteStory;

  StreamSubscription? _sub;

  StoryNotifier()
      : _watchStories = getIt<WatchActiveStories>(),
        _postText = getIt<PostTextStory>(),
        _postImage = getIt<PostImageStory>(),
        _markViewed = getIt<MarkStoryViewed>(),
        _deleteStory = getIt<DeleteStory>(),
        super(StoryState.initial()) {
    _start();
  }

  void _start() {
    _sub = _watchStories(const NoParams()).listen((either) {
      either.fold(
        (failure) =>
            state = state.copyWith(isLoading: false, error: failure.message),
        (stories) => state = state.copyWith(
          userStories: stories,
          isLoading: false,
          clearError: true,
        ),
      );
    });
  }

  Future<bool> postText(String text, String backgroundColor) async {
    state = state.copyWith(isPosting: true);
    final result = await _postText(
      PostTextStoryParams(text: text, backgroundColor: backgroundColor),
    );
    return result.fold(
      (failure) {
        state = state.copyWith(isPosting: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isPosting: false, clearError: true);
        return true;
      },
    );
  }

  Future<bool> postImage(File image, String? caption) async {
    state = state.copyWith(isPosting: true);
    final result = await _postImage(
      PostImageStoryParams(imageFile: image, caption: caption),
    );
    return result.fold(
      (failure) {
        state = state.copyWith(isPosting: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isPosting: false, clearError: true);
        return true;
      },
    );
  }

  Future<void> markViewed(String storyId) async {
    await _markViewed(storyId);
  }

  Future<void> deleteStory(String storyId) async {
    await _deleteStory(storyId);
  }

  void clearError() => state = state.copyWith(clearError: true);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final storyNotifierProvider =
    StateNotifierProvider.autoDispose<StoryNotifier, StoryState>(
  (ref) => StoryNotifier(),
);
