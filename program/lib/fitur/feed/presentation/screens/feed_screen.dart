import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers/firebase_providers.dart';
import '../../../notification/presentation/providers/notification_provider.dart';
import '../../../post/domain/entities/post.dart';
import '../../../post/presentation/providers/post_provider.dart';
import '../../domain/entities/feed_filter.dart';
import '../providers/feed_filter_provider.dart';
import '../widgets/post_widget.dart';
import '../widgets/short_widget.dart';
import '../../../story/presentation/widgets/stories_list_widget.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final currentFilter = ref.watch(feedFilterProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Auth Error: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(authStateChangesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            body: const Center(
              child: Text('Silakan login terlebih dahulu'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ngoper'),
            actions: [
              Consumer(
                builder: (context, ref, _) {
                  final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

                  return IconButton(
                    icon: Stack(
                      children: [
                        const Icon(Icons.notifications_none),
                        if (unreadCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () {
                      context.push('/notifications');
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  context.push('/cart');
                },
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () {
                  context.push('/chat-list');
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Section Stories
              _buildStoriesSection(),
              const Divider(height: 1, thickness: 1),

              // Filter buttons
              _buildFilterSection(ref, currentFilter),

              // List Postingan
              Expanded(
                child: _buildPostsSection(ref, currentFilter),
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget _buildStoriesSection() {
  //   return Container(
  //     height: 100,
  //     padding: const EdgeInsets.symmetric(vertical: 8.0),
  //     child: ListView.builder(
  //       scrollDirection: Axis.horizontal,
  //       itemCount: 5, // Reduced for demo
  //       itemBuilder: (context, index) {
  //         return Padding(
  //           padding: const EdgeInsets.symmetric(horizontal: 8.0),
  //           child: Column(
  //             children: [
  //               CircleAvatar(
  //                 radius: 30,
  //                 backgroundColor: Colors.grey[300],
  //                 child: Icon(Icons.person, size: 30, color: Colors.grey[600]),
  //               ),
  //               const SizedBox(height: 4),
  //               Text(
  //                 'User $index',
  //                 style: const TextStyle(fontSize: 12),
  //               ),
  //             ],
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

  Widget _buildStoriesSection() {
    return const StoriesListWidget();
  }

  Widget _buildFilterSection(WidgetRef ref, FeedFilter currentFilter) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: FeedFilter.values.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                  currentFilter == filter ? Colors.blue.shade100 : null,
                  side: BorderSide(
                    color: currentFilter == filter ? Colors.blue : Colors.grey,
                  ),
                ),
                onPressed: () {
                  ref.read(feedFilterProvider.notifier).setFilter(filter);
                },
                child: Text(filter.label),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPostsSection(WidgetRef ref, FeedFilter currentFilter) {
    final postsAsyncValue = ref.watch(postsProvider);

    return postsAsyncValue.when(
      data: (posts) {
        print('📊 Total posts loaded: ${posts.length}'); // Debug log

        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.post_add, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Belum ada postingan.'),
                Text('Jadilah yang pertama membuat post!'),
              ],
            ),
          );
        }

        // Filter berdasarkan pilihan - PERBAIKAN LOGIC
        final filteredPosts = _filterPosts(posts, currentFilter);
        print('📊 Filtered posts (${currentFilter.label}): ${filteredPosts.length}'); // Debug log

        if (filteredPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_alt_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Tidak ada postingan ${currentFilter.label.toLowerCase()}.'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    ref.read(feedFilterProvider.notifier).setFilter(FeedFilter.all);
                  },
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
          );
        }

        // Layout khusus untuk shorts
        if (currentFilter == FeedFilter.short) {
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: filteredPosts.length,
            itemBuilder: (context, index) {
              final post = filteredPosts[index];
              return ShortsWidget(post: post);
            },
          );
        }

        // Layout biasa untuk filter lainnya
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(postsProvider);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filteredPosts.length > 20 ? 20 : filteredPosts.length,
            itemBuilder: (context, index) {
              final post = filteredPosts[index];
              print('🎯 Rendering post ${post.id}: ${post.title}');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: PostWidget(post: post),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat postingan...'),
          ],
        ),
      ),
      error: (err, stack) {
        print('❌ Feed error: $err'); // Debug log
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Terjadi kesalahan:', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(err.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(postsProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Post> _filterPosts(List<Post> posts, FeedFilter filter) {
    switch (filter) {
      case FeedFilter.all:
        return posts;
      case FeedFilter.short:
        return posts.where((post) => post.type == PostType.short).toList();
      case FeedFilter.request:
        return posts.where((post) => post.type == PostType.request).toList();
      case FeedFilter.jastip:
        return posts.where((post) => post.type == PostType.jastip).toList();
      default:
        return posts;
    }
  }
}
