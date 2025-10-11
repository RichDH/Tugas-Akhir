import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/profile/presentation/providers/profile_provider.dart';
import 'package:program/fitur/auth/presentation/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:program/fitur/profile/presentation/widgets/video_thumbnail_widget.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../../chat/presentation/providers/chat_provider.dart';

class ProfileScreen extends ConsumerWidget {
  // PERBAIKAN 1: Tambahkan parameter opsional untuk menerima userId dari luar
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tentukan ID siapa yang akan ditampilkan
    final authUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final targetUserId = userId ?? authUid;

    if (targetUserId == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Pengguna tidak ditemukan.")));
    }

    // PERBAIKAN 2: Buat flag untuk mengecek apakah ini profil kita sendiri
    final isMyProfile = targetUserId == authUid;

    // Gunakan targetUserId untuk semua provider
    final userProfileAsync = ref.watch(userProfileStreamProvider(targetUserId));
    final userPostsAsync = ref.watch(userPostsStreamProvider(targetUserId));
    final followersCount = ref.watch(followersCountProvider(targetUserId)).value ?? 0;
    final followingCount = ref.watch(followingCountProvider(targetUserId)).value ?? 0;
    final userRequestsAsync = ref.watch(userRequestsStreamProvider(targetUserId));
    final userShortsAsync = ref.watch(userShortsStreamProvider(targetUserId));
    final userLiveHistoryAsync = ref.watch(userLiveHistoryStreamProvider(targetUserId));
    final totalPostsCount = (userPostsAsync.value?.docs.length ?? 0) + (userRequestsAsync.value?.docs.length ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: userProfileAsync.when(
          data: (doc) => Text(doc.data() != null ? (doc.data() as Map<String, dynamic>)['username'] ?? 'Profil' : 'Profil'),
          loading: () => const Text('Memuat...'),
          error: (_, __) => const Text('Profil'),
        ),
        actions: [
          if (isMyProfile)
            Consumer(
              builder: (context, ref, child) {
                final userProfileData = ref.watch(userProfileStreamProvider(targetUserId));

                return PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  itemBuilder: (BuildContext context) {
                    final data = userProfileData.when(
                      data: (doc) => doc.data() as Map<String, dynamic>?,
                      loading: () => null,
                      error: (e, s) => null,
                    );
                    final saldo = data?['saldo'] ?? 0;
                    final verificationStatus = data?['verificationStatus'] as String? ?? 'unverified';

                    final formattedSaldo = NumberFormat.decimalPattern('id_ID').format(saldo);

                    return <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saldo Anda',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rp $formattedSaldo',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),

                      // Tombol Top Up
                      const PopupMenuItem<String>(
                        value: 'topup',
                        child: ListTile(
                          leading: Icon(Icons.add_card),
                          title: Text('Top Up Saldo'),
                        ),
                      ),

                      // Status Verifikasi
                      if (verificationStatus == 'verified')
                        const PopupMenuItem<String>(
                          enabled: false,
                          child: ListTile(
                            leading: Icon(Icons.verified, color: Colors.green),
                            title: Text('Akun Terverifikasi'),
                          ),
                        )
                      else if (verificationStatus == 'pending')
                        const PopupMenuItem<String>(
                          enabled: false,
                          child: ListTile(
                            leading: Icon(Icons.hourglass_top, color: Colors.orange),
                            title: Text('Verifikasi Ditinjau'),
                          ),
                        )
                      else
                        const PopupMenuItem<String>(
                          value: 'verification',
                          child: ListTile(
                            leading: Icon(Icons.security),
                            title: Text('Verifikasi Akun'),
                          ),
                        ),

                      const PopupMenuDivider(),

                      // ✅ TAMBAHKAN MENU RIWAYAT
                      const PopupMenuItem<String>(
                        value: 'transaction-history',
                        child: ListTile(
                          leading: Icon(Icons.history),
                          title: Text('Riwayat Transaksi'),
                        ),
                      ),

                      const PopupMenuItem<String>(
                        value: 'request-history',
                        child: ListTile(
                          leading: Icon(Icons.request_page),
                          title: Text('Riwayat Request'),
                        ),
                      ),

                      const PopupMenuDivider(),

                      // Tombol Logout
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: ListTile(
                          leading: Icon(Icons.logout, color: Colors.red),
                          title: Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ];
                  },
                  onSelected: (value) {
                    if (value == 'topup') {
                      GoRouter.of(context).push('/top-up');
                    } else if (value == 'verification') {
                      GoRouter.of(context).push('/verification');
                    } else if (value == 'transaction-history') {
                      // Navigasi ke halaman Riwayat Transaksi
                      GoRouter.of(context).push('/transaction-history');
                    } else if (value == 'request-history') {
                      // Navigasi ke halaman Riwayat Request
                      GoRouter.of(context).push('/request-history');
                    }else if (value == 'return-response-list') {
                      GoRouter.of(context).push('/return-response-list');
                    } else if (value == 'logout') {
                      ref.read(authProvider.notifier).logout();
                    }
                  },
                );
              },
            ),
        ],
      ),
      body: DefaultTabController(
        length: 4,
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
                      // PERBAIKAN 4: Kirim flag dan ID ke header
                      return _buildProfileHeader(
                        context: context,
                        username: userData['username'] ?? 'Tanpa Nama',
                        email: userData['email'] ?? 'Tidak ada email',
                        postsCount: totalPostsCount,
                        followersCount: followersCount,
                        followingCount: followingCount,
                        isMyProfile: isMyProfile,
                        targetUserId: targetUserId,
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
              _buildGrid(asyncValue: userPostsAsync, emptyMessage: "Belum ada postingan jastip.", errorMessage: "Gagal memuat postingan."),
              // PERBAIKAN: Konten Tab Request
              _buildGrid(asyncValue: userRequestsAsync, emptyMessage: "Belum ada postingan request.", errorMessage: "Gagal memuat request."),
              // PERBAIKAN: Konten Tab Shorts
              userShortsAsync.when(
                data: (snapshot) {
                  if (snapshot.docs.isEmpty) return const Center(child: Text('Belum ada shorts.'));
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                    itemCount: snapshot.docs.length,
                    itemBuilder: (context, index) {
                      final short = snapshot.docs[index].data() as Map<String, dynamic>;
                      final videoUrl = short['videoUrl'] as String? ?? '';
                      if (videoUrl.isEmpty) return const SizedBox.shrink();
                      return VideoThumbnailWidget(videoUrl: videoUrl);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const Center(child: Text('Gagal memuat shorts')),
              ),
              // Konten Tab Live
              userLiveHistoryAsync.when(
                data: (lives) {
                  if (lives.docs.isEmpty) return const Center(child: Text('Belum ada riwayat siaran.'));
                  return ListView.builder(
                    itemCount: lives.docs.length,
                    itemBuilder: (context, index) {
                      final live = lives.docs[index].data() as Map<String, dynamic>;
                      final title = live['title'] ?? 'Live Shopping';
                      final timestamp = live['createdAt'] as Timestamp?;
                      final formattedDate = timestamp != null
                          ? DateFormat('d MMM yyyy, HH:mm').format(timestamp.toDate()) : 'Tanggal tidak tersedia';
                      return ListTile(
                        leading: const Icon(Icons.videocam_off_outlined),
                        title: Text(title),
                        subtitle: Text(formattedDate),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const Center(child: Text('Gagal memuat riwayat live')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid({
    required AsyncValue<QuerySnapshot> asyncValue,
    required String emptyMessage,
    required String errorMessage,
  }) {

    return asyncValue.when(
      data: (snapshot) {
        if (snapshot.docs.isEmpty) {
          return Center(child: Text(emptyMessage));
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: snapshot.docs.length,
          itemBuilder: (context, index) {
            // Ambil seluruh dokumen post, bukan hanya datanya
            final postDoc = snapshot.docs[index];
            final post = postDoc.data() as Map<String, dynamic>;
            final imageUrls = post['imageUrls'] as List<dynamic>?;

            if (imageUrls == null || imageUrls.isEmpty) {
              return Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported));

            }
            // PERBAIKAN: Bungkus gambar dengan GestureDetector
            return GestureDetector(
              onTap: () {
                // Navigasi ke halaman detail dengan mengirim ID post
                context.push('/post-detail/${postDoc.id}');
              },
              child: Image.network(imageUrls[0],
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.error)),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text(errorMessage)),
    );
  }

  // PERBAIKAN 5: Modifikasi _buildProfileHeader untuk menampilkan tombol dinamis
  Widget _buildProfileHeader({
    required BuildContext context,
    required String username,
    required String email,
    required int postsCount,
    required int followersCount,
    required int followingCount,
    required bool isMyProfile,
    required String targetUserId,
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

        // Logika untuk tombol dinamis
        if (isMyProfile)
        // Jika ini profilku, tampilkan tombol Edit Profil
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 36),
            ),
            child: const Text('Edit Profil'),
          )
        else
        // Jika ini profil orang lain, tampilkan tombol Follow dan Message
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Tambahkan logika Follow
                  },
                  child: const Text('Follow'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Consumer( // PERBAIKAN: Bungkus dengan Consumer
                  builder: (context, ref, child) {
                    return OutlinedButton(
                      onPressed: () async {
                        try {
                          // Panggil fungsi untuk membuat/mendapatkan chat room
                          final chatRoomId = await ref
                              .read(chatNotifierProvider.notifier)
                              .createOrGetChatRoom(targetUserId);

                          // Setelah berhasil, baru navigasi ke halaman chat
                          context.push('/chat/$targetUserId', extra: {
                            'username': username,
                            'chatRoomId': chatRoomId,
                          });

                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Gagal memulai chat: ${e.toString()}"))
                          );
                        }
                      },
                      child: const Text('Message'),
                    );
                  },
                ),
              ),
            ],
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