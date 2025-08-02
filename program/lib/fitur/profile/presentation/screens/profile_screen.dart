import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/profile/presentation/providers/profile_provider.dart';
import 'package:program/fitur/auth/presentation/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Pengguna tidak ditemukan.")));
    }

    final userProfileAsync = ref.watch(userProfileStreamProvider(currentUserId));
    final userPostsAsync = ref.watch(userPostsStreamProvider(currentUserId));
    final followersCount = ref.watch(followersCountProvider(currentUserId)).value ?? 0;
    final followingCount = ref.watch(followingCountProvider(currentUserId)).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: userProfileAsync.when(
          data: (doc) => Text(doc.data() != null ? (doc.data() as Map<String, dynamic>)['username'] ?? 'Profil' : 'Profil'),
          loading: () => const Text('Memuat...'),
          error: (_, __) => const Text('Profil'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          )
        ],
      ),
      body: DefaultTabController(
        length: 4, // Jumlah tab
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: userProfileAsync.when(
                    data: (userDoc) {
                      if (!userDoc.exists || userDoc.data() == null) {
                        return const Text('Gagal memuat profil.');
                      }
                      final userData = userDoc.data() as Map<String, dynamic>;
                      return _buildProfileHeader(
                        context: context,
                        username: userData['username'] ?? 'Tanpa Nama',
                        email: userData['email'] ?? 'Tidak ada email',
                        postsCount: userPostsAsync.value?.docs.length ?? 0,
                        followersCount: followersCount,
                        followingCount: followingCount,
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Terjadi kesalahan: $err')),
                  ),
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverTabBarDelegate(
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.grid_on), text: "Post"),
                      Tab(icon: Icon(Icons.record_voice_over), text: "Request"),
                      Tab(icon: Icon(Icons.video_collection_outlined), text: "Shorts"),
                      Tab(icon: Icon(Icons.live_tv), text: "Live"),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            children: [
              userPostsAsync.when(
                data: (posts) {
                  if (posts.docs.isEmpty) {
                    return const Center(child: Text('Belum ada postingan.'));
                  }
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: posts.docs.length,
                    itemBuilder: (context, index) {
                      final post = posts.docs[index].data() as Map<String, dynamic>;
                      final imageUrls = post['imageUrls'] as List<dynamic>?;

                      if (imageUrls == null || imageUrls.isEmpty) {
                        return Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported));
                      }

                      return Image.network(imageUrls[0], fit: BoxFit.cover);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const Center(child: Text('Gagal memuat post')),
              ),
              const Center(child: Text('Halaman Request')),
              const Center(child: Text('Halaman Shorts')),
              const Center(child: Text('Halaman Live')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required BuildContext context,
    required String username,
    required String email,
    required int postsCount,
    required int followersCount,
    required int followingCount,
  }) {
    return Column(
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn("Postingan", postsCount.toString()),
                  _buildStatColumn("Pengikut", followersCount.toString()),
                  _buildStatColumn("Mengikuti", followingCount.toString()),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(email, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {},
          child: const Text('Edit Profil'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 36),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}