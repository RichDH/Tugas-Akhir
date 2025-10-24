// lib/fitur/story/presentation/providers/story_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/firebase_providers.dart';
import '../../data/repositories/story_repository_impl.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepositoryImpl(FirebaseFirestore.instance);
});



// lib/fitur/story/presentation/providers/story_provider.dart

// Provider untuk current user story yang reactive dan responsive terhadap user change
final currentUserStoryProvider = StreamProvider<Story?>((ref) {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    print('🚫 No current user for story provider');
    return Stream.value(null);
  }

  print('👤 Story provider initialized for user: ${currentUser.uid}');

  // Langsung listen ke Firestore dengan real-time updates
  return FirebaseFirestore.instance
      .collection('stories')
      .where('userId', isEqualTo: currentUser.uid)
      .where('isActive', isEqualTo: true)
      .where('expiresAt', isGreaterThan: Timestamp.now())
      .orderBy('expiresAt')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isNotEmpty) {
      final story = Story.fromFirestore(snapshot.docs.first);
      print('🔄 REACTIVE: Current user story found - ID: ${story.id}, User: ${story.userId}');
      return story;
    }
    print('🔄 REACTIVE: Current user ${currentUser.uid} has no active story');
    return null;
  }).handleError((error) {
    print('❌ REACTIVE: Error in currentUserStoryProvider: $error');
    return null;
  });
});

// Provider untuk active stories dengan auto-invalidation saat user berubah
final activeStoriesProvider = StreamProvider<List<Story>>((ref) {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    print('🚫 No current user for active stories');
    return Stream.value([]);
  }

  print('👥 Active stories provider initialized for user: ${currentUser.uid}');

  // Listen untuk perubahan auth state dan invalidate provider
  ref.listen(authStateChangesProvider, (previous, next) {
    next.whenOrNull(
      data: (user) {
        if (user?.uid != currentUser.uid) {
          print('🔄 User changed, invalidating story providers');
          ref.invalidateSelf();
        }
      },
    );
  });

  final repository = ref.watch(storyRepositoryProvider);
  return repository.getActiveStoriesFromFollowing(currentUser.uid);
});




final storyNotifierProvider = StateNotifierProvider<StoryNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(storyRepositoryProvider);
  return StoryNotifier(repository);
});



// lib/fitur/story/presentation/providers/story_provider.dart
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

      // Ambil data user lengkap dari Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();
      final username = userData?['username'] ??
          currentUser.displayName ??
          'Anonymous';
      final profileImageUrl = userData?['profileImageUrl'] ??
          currentUser.photoURL;

      print('👤 Creating story for: $username, profileImage: $profileImageUrl'); // Debug

      // Cek apakah user sudah punya story aktif
      final existingStory = await _repository.getUserActiveStory(currentUser.uid);
      if (existingStory != null) {
        throw Exception('Anda sudah memiliki story aktif. Tunggu hingga story sebelumnya berakhir.');
      }

      // Upload media
      final mediaUrl = await _repository.uploadStoryMedia(
        filePath,
        currentUser.uid,
        type,
      );

      // Create story dengan data user lengkap
      final story = Story(
        id: '',
        userId: currentUser.uid,
        username: username,
        profileImageUrl: profileImageUrl,
        mediaUrl: mediaUrl,
        text: text,
        type: type,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(Duration(minutes: 2)),
      );

      await _repository.createStory(story);
      state = const AsyncValue.data(null);

      print('✅ Story created successfully'); // Debug
    } catch (e, stackTrace) {
      print('❌ Error creating story: $e'); // Debug
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

