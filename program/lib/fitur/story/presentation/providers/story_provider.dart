// lib/fitur/story/presentation/providers/story_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/story_repository_impl.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepositoryImpl(FirebaseFirestore.instance);
});

final activeStoriesProvider = StreamProvider<List<Story>>((ref) {
  final repository = ref.watch(storyRepositoryProvider);
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return Stream.value([]);
  }

  return repository.getActiveStoriesFromFollowing(currentUser.uid);
});

final currentUserStoryProvider = FutureProvider<Story?>((ref) {
  final repository = ref.watch(storyRepositoryProvider);
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return Future.value(null);
  }

  return repository.getUserActiveStory(currentUser.uid);
});

final storyNotifierProvider = StateNotifierProvider<StoryNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(storyRepositoryProvider);
  return StoryNotifier(repository);
});

class StoryNotifier extends StateNotifier<AsyncValue<void>> {
  final StoryRepository _repository;

  StoryNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> createStory({
    required String filePath,
    required StoryType type,
    String? text,
  }) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User tidak login');

      // Upload media
      final mediaUrl = await _repository.uploadStoryMedia(
        filePath,
        currentUser.uid,
        type,
      );

      // Create story dengan expires 2 menit dari sekarang
      final story = Story(
        id: '',
        userId: currentUser.uid,
        username: currentUser.displayName ?? 'Anonymous',
        userAvatarUrl: currentUser.photoURL ?? '',
        mediaUrl: mediaUrl,
        text: text,
        type: type,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(Duration(minutes: 2)),
      );

      await _repository.createStory(story);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> markAsViewed(String storyId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _repository.markStoryAsViewed(storyId, currentUser.uid);
    } catch (e) {
      print('Error marking story as viewed: $e');
    }
  }
}
