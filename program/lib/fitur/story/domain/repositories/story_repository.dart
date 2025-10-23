// lib/fitur/story/domain/repositories/story_repository.dart
import '../entities/story.dart';

abstract class StoryRepository {
  Future<void> createStory(Story story);
  Future<String> uploadStoryMedia(String filePath, String userId, StoryType type);
  Stream<List<Story>> getActiveStoriesFromFollowing(String currentUserId);
  Future<Story?> getUserActiveStory(String userId);
  Future<void> markStoryAsViewed(String storyId, String userId);
  Future<void> deleteExpiredStories();
}
