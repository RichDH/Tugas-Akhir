// lib/fitur/story/presentation/widgets/stories_list_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/story_provider.dart';
import '../../domain/entities/story.dart';

class StoriesListWidget extends ConsumerWidget {
  const StoriesListWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(activeStoriesProvider);
    final currentUserStoryAsync = ref.watch(currentUserStoryProvider);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: storiesAsync.when(
        data: (stories) {
          // Group stories by user
          final Map<String, List<Story>> groupedStories = {};
          for (final story in stories) {
            if (groupedStories[story.userId] == null) {
              groupedStories[story.userId] = [];
            }
            groupedStories[story.userId]!.add(story);
          }

          // Convert to list of user stories
          final List<MapEntry<String, List<Story>>> userStories =
          groupedStories.entries.toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: userStories.length + 1, // +1 untuk current user
            itemBuilder: (context, index) {
              if (index == 0) {
                // Current user story atau add story button
                return currentUserStoryAsync.when(
                  data: (userStory) => _buildCurrentUserStory(
                    context,
                    ref,
                    currentUser,
                    userStory,
                  ),
                  loading: () => _buildCurrentUserStory(
                    context,
                    ref,
                    currentUser,
                    null,
                  ),
                  error: (_, __) => _buildCurrentUserStory(
                    context,
                    ref,
                    currentUser,
                    null,
                  ),
                );
              }

              final userStoriesEntry = userStories[index - 1];
              final userId = userStoriesEntry.key;
              final userStoriesList = userStoriesEntry.value;

              // Skip current user karena sudah ditampilkan di index 0
              if (userId == currentUser?.uid) {
                return const SizedBox.shrink();
              }

              final latestStory = userStoriesList.first;
              final hasViewed = currentUser != null &&
                  latestStory.hasBeenViewedBy(currentUser.uid);

              return _buildStoryCircle(
                context,
                latestStory,
                hasViewed,
                    () => context.push('/story-viewer/${latestStory.userId}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildCurrentUserStory(
      BuildContext context,
      WidgetRef ref,
      User? currentUser,
      Story? userStory,
      ) {
    final hasStory = userStory != null && !userStory.isExpired;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () {
          if (hasStory) {
            context.push('/story-viewer/${currentUser?.uid}');
          } else {
            context.push('/create-story');
          }
        },
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasStory ? Colors.red : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundImage: currentUser?.photoURL != null
                        ? CachedNetworkImageProvider(currentUser!.photoURL!)
                        : null,
                    backgroundColor: Colors.grey[300],
                    child: currentUser?.photoURL == null
                        ? Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.grey[600],
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Story',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (!hasStory)
              Positioned(
                right: 0,
                bottom: 20,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCircle(
      BuildContext context,
      Story story,
      bool hasViewed,
      VoidCallback onTap,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasViewed ? Colors.grey : Colors.red,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: story.userAvatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(story.userAvatarUrl)
                    : null,
                backgroundColor: Colors.grey[300],
                child: story.userAvatarUrl.isEmpty
                    ? Text(
                  story.username.isNotEmpty
                      ? story.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                story.username,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
