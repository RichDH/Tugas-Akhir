// lib/fitur/story/presentation/widgets/stories_list_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/story_provider.dart';
import '../../domain/entities/story.dart';

// lib/fitur/story/presentation/widgets/stories_list_widget.dart

class StoriesListWidget extends ConsumerWidget {
  const StoriesListWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(activeStoriesProvider);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      print('❌ No current user');
      return const SizedBox.shrink();
    }

    // Listen untuk story creation success untuk invalidate provider
    ref.listen(storyNotifierProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          // Story berhasil dibuat, refresh current user story provider
          print('🔄 Story created successfully, invalidating currentUserStoryProvider');
          ref.invalidate(currentUserStoryProvider);
        },
      );
    });

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: storiesAsync.when(
        data: (stories) {
          print('📊 StoriesListWidget - received ${stories.length} stories');

          // Group stories by user (exclude current user dari list ini)
          final Map<String, List<Story>> groupedStories = {};
          for (final story in stories) {
            if (story.userId != currentUser.uid) { // Exclude current user
              if (groupedStories[story.userId] == null) {
                groupedStories[story.userId] = [];
              }
              groupedStories[story.userId]!.add(story);
            }
          }

          print('👥 Other users with stories: ${groupedStories.keys.length}');

          final otherUsersStories = groupedStories.entries.toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: otherUsersStories.length + 1, // +1 untuk current user
            itemBuilder: (context, index) {
              if (index == 0) {
                // Current user story (selalu di posisi pertama)
                return Consumer(
                  builder: (context, ref, _) {
                    final currentUserStoryAsync = ref.watch(currentUserStoryProvider);

                    return currentUserStoryAsync.when(
                      data: (story) {
                        final hasStory = story != null && !story.isExpired;
                        print('📱 WIDGET: Current user story status - hasStory: $hasStory, storyId: ${story?.id}');

                        return _buildCurrentUserStory(
                          context,
                          ref,
                          currentUser,
                          story,
                          hasStory,
                        );
                      },
                      loading: () {
                        print('📱 WIDGET: Loading current user story...');
                        return _buildCurrentUserStoryLoading(currentUser);
                      },
                      error: (error, stack) {
                        print('❌ WIDGET: Error loading current user story: $error');
                        return _buildCurrentUserStory(context, ref, currentUser, null, false);
                      },
                    );
                  },
                );
              }

              // Other users' stories
              final userStoriesEntry = otherUsersStories[index - 1];
              final userId = userStoriesEntry.key;
              final userStoriesList = userStoriesEntry.value;
              final latestStory = userStoriesList.first;

              final hasViewed = latestStory.hasBeenViewedBy(currentUser.uid);

              return _buildStoryCircle(
                context,
                latestStory,
                hasViewed,
                    () => context.push('/story-viewer/$userId'),
              );
            },
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, stack) {
          print('❌ Stories loading error: $error');
          return Center(
            child: Text(
              'Error: $error',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentUserStoryLoading(User currentUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey, width: 2),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Your Story', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCurrentUserStory(
      BuildContext context,
      WidgetRef ref,
      User currentUser,
      Story? userStory,
      bool hasStory,
      ) {
    print('📱 BUILDING: Current user story widget - hasStory: $hasStory, storyId: ${userStory?.id}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () {
          print('🔄 TAPPED: Current user story - hasStory: $hasStory');
          if (hasStory) {
            // Ada story aktif -> buka viewer
            print('➡️ NAVIGATION: Opening story viewer for current user');
            context.push('/story-viewer/${currentUser.uid}');
          } else {
            // Tidak ada story -> buka create
            print('➡️ NAVIGATION: Opening create story');
            context.push('/create-story');
          }
        },
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get(),
          builder: (context, snapshot) {
            final userData = snapshot.data?.data() as Map<String, dynamic>?;
            final profileImageUrl = userData?['profileImageUrl'] ?? currentUser.photoURL;
            final username = userData?['username'] ?? currentUser.displayName ?? 'You';

            return Stack(
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
                        backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                            ? CachedNetworkImageProvider(profileImageUrl)
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: profileImageUrl == null || profileImageUrl.isEmpty
                            ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
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
                        'Your Story',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Plus icon hanya muncul jika TIDAK ada story
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
            );
          },
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
                backgroundImage: story.profileImageUrl != null && story.profileImageUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(story.profileImageUrl!)
                    : null,
                backgroundColor: Colors.grey[300],
                child: story.profileImageUrl == null || story.profileImageUrl!.isEmpty
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
