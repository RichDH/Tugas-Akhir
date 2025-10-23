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
import 'package:program/fitur/admin/application/admin_user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../admin/application/admin_user_service.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../post/domain/entities/post.dart';

class ProfileScreen extends ConsumerWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final targetUserId = userId ?? authUid;

    if (targetUserId == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Pengguna tidak ditemukan.")));
    }

    final isMyProfile = targetUserId == authUid;

    final userProfileAsync = ref.watch(userProfileStreamProvider(targetUserId));
    final userPostsAsync = ref.watch(userPostsStreamProvider(targetUserId));
    final userRequestsAsync = ref.watch(userRequestsStreamProvider(targetUserId));
    final userShortsAsync = ref.watch(userShortsStreamProvider(targetUserId));
    final userLiveHistoryAsync = ref.watch(userLiveHistoryStreamProvider(targetUserId));
    final followersCount = ref.watch(followersCountStreamProvider(targetUserId)).value ?? 0;
    final followingCount = ref.watch(followingCountStreamProvider(targetUserId)).value ?? 0;

    // FILTER CLIENT-SIDE: tampilkan jika deleted tidak ada ATAU deleted == false
    int _safeCount(AsyncValue<QuerySnapshot> av) {
      final docs = av.value?.docs ?? const [];
      return docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return !data.containsKey('deleted') || data['deleted'] == false;
      }).length;
    }

    final totalPostsCount = _safeCount(userPostsAsync) + _safeCount(userRequestsAsync);


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
                              Text('Saldo Anda', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                'Rp $formattedSaldo',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'topup',
                        child: ListTile(leading: Icon(Icons.add_card, color: Colors.green), title: Text('Top Up Saldo')),
                      ),
                      if (verificationStatus == 'verified')
                        const PopupMenuItem<String>(
                          enabled: false,
                          child: ListTile(leading: Icon(Icons.verified, color: Colors.green), title: Text('Akun Terverifikasi')),
                        )
                      else if (verificationStatus == 'pending')
                        const PopupMenuItem<String>(
                          enabled: false,
                          child: ListTile(leading: Icon(Icons.hourglass_top, color: Colors.orange), title: Text('Verifikasi Ditinjau')),
                        )
                      else
                        const PopupMenuItem<String>(
                          value: 'verification',
                          child: ListTile(leading: Icon(Icons.security, color: Colors.blue), title: Text('Verifikasi Akun')),
                        ),
                      const PopupMenuItem<String>(
                        value: 'chat-admin',
                        child: ListTile(leading: Icon(Icons.support_agent, color: Colors.blue), title: Text('Chat Admin')),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text('Bisnis & Pesanan', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'list-interested-order',
                        child: ListTile(leading: Icon(Icons.assignment_turned_in, color: Colors.orange), title: Text('List Pesanan'), subtitle: Text('Kelola pesanan masuk')),
                      ),
                      const PopupMenuItem<String>(value: 'cart', child: ListTile(leading: Icon(Icons.shopping_cart, color: Colors.blue), title: Text('Keranjang'))),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text('Riwayat', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const PopupMenuItem<String>(value: 'transaction-history', child: ListTile(leading: Icon(Icons.history, color: Colors.green), title: Text('Riwayat Transaksi'))),
                      const PopupMenuItem<String>(value: 'request-history', child: ListTile(leading: Icon(Icons.request_page, color: Colors.purple), title: Text('Riwayat Request'))),
                      const PopupMenuItem<String>(value: 'return-response-list', child: ListTile(leading: Icon(Icons.assignment_return, color: Colors.red), title: Text('Return Response'))),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Logout', style: TextStyle(color: Colors.red)))),
                    ];
                  },
                  onSelected: (value) {
                    switch (value) {
                      case 'topup':
                        context.push('/top-up');
                        break;
                      case 'verification':
                        context.push('/verification');
                        break;
                      case 'chat-admin':
                        context.push('/chat-admin');
                        break;
                      case 'list-interested-order':
                        context.push('/list-interested-order');
                        break;
                      case 'cart':
                        context.push('/cart');
                        break;
                      case 'transaction-history':
                        context.push('/transaction-history');
                        break;
                      case 'request-history':
                        context.push('/request-history');
                        break;
                      case 'return-response-list':
                        context.push('/return-response-list');
                        break;
                      case 'logout':
                        ref.read(authProvider.notifier).logout();
                        break;
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
              _buildGrid(asyncValue: userRequestsAsync, emptyMessage: "Belum ada postingan request.", errorMessage: "Gagal memuat request."),
              userShortsAsync.when(
                data: (snapshot) {
                  // Filter client-side untuk shorts jika suatu saat ada field deleted
                  final filtered = snapshot.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return !data.containsKey('deleted') || data['deleted'] == false;
                  }).toList();

                  if (filtered.isEmpty) return const Center(child: Text('Belum ada shorts.'));
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final short = filtered[index].data() as Map<String, dynamic>;
                      final videoUrl = short['videoUrl'] as String? ?? '';
                      if (videoUrl.isEmpty) return const SizedBox.shrink();
                      return VideoThumbnailWidget(videoUrl: videoUrl);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const Center(child: Text('Gagal memuat shorts')),
              ),
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
                          ? DateFormat('d MMM yyyy, HH:mm').format(timestamp.toDate())
                          : 'Tanggal tidak tersedia';
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
        // Filter client-side: tampilkan dokumen tanpa field 'deleted' atau dengan 'deleted' == false
        final filteredDocs = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return !data.containsKey('deleted') || data['deleted'] == false;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(child: Text(emptyMessage));
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
          ),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final postDoc = filteredDocs[index];
            final postMap = postDoc.data() as Map<String, dynamic>;
            final imageUrls = (postMap['imageUrls'] as List<dynamic>?)?.cast<String>() ?? const <String>[];

            return GestureDetector(
              onTap: () => context.push('/post-detail/${postDoc.id}'),
              child: imageUrls.isNotEmpty
                  ? Image.network(
                imageUrls.first,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.error),
              )
                  : _VideoOrPlaceholder(postMap: postMap),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text(errorMessage)),
    );
  }

  Future<void> _showCloseAccountDialog(
      BuildContext context,
      WidgetRef ref,
      String targetUserId,
      String username,
      ) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Tutup Akun @$username'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Akun akan dinonaktifkan dan semua postingan disembunyikan.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan Penutupan *',
                  border: OutlineInputBorder(),
                  helperText: 'Alasan ini akan ditampilkan kepada user',
                ),
                maxLines: 3,
                maxLength: 200,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Alasan tidak boleh kosong';
                  }
                  if (value.trim().length < 10) {
                    return 'Alasan minimal 10 karakter';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop({
                  'reason': reasonController.text.trim(),
                  'username': username,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tutup Akun'),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if (result != null && context.mounted) {
      await _processCloseAccount(context, ref, targetUserId, result);
    }
  }

  Future<void> _processCloseAccount(
      BuildContext context,
      WidgetRef ref,
      String targetUserId,
      Map<String, String> data,
      ) async {
    final reason = data['reason']!;
    final username = data['username']!;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Menutup akun...'),
          ],
        ),
      ),
    );

    try {
      final currentUser = ref.read(firebaseAuthProvider).currentUser;
      final adminEmail = currentUser?.email ?? 'unknown';

      final service = AdminUserService(FirebaseFirestore.instance);
      await service.closeUserAccount(
        targetUserId: targetUserId,
        reason: reason,
        closedBy: adminEmail,
      );

      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Akun @$username berhasil ditutup'),
            backgroundColor: Colors.green,
          ),
        );

        context.go('/admin');
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menutup akun: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
    return Consumer(
      builder: (context, ref, child) {
        final userProfileAsync = ref.watch(userProfileStreamProvider(targetUserId));

        return userProfileAsync.when(
          data: (doc) {
            final userData = doc.data() as Map<String, dynamic>? ?? {};
            final bio = userData['bio'] as String? ?? '';
            final profileImageUrl = userData['profileImageUrl'] as String? ?? '';
            final name = userData['name'] as String? ?? username;
            final followersCount = ref.watch(followersCountStreamProvider(targetUserId)).value ?? 0;
            final followingCount = ref.watch(followingCountStreamProvider(targetUserId)).value ?? 0;
            final isAdmin = ref.watch(isAdminProvider);

            return Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                      child: profileImageUrl.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
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
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('@$username', style: const TextStyle(color: Colors.grey)),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(bio, style: const TextStyle(fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Consumer(
                  builder: (context, ref, child) {
                    final isAdmin = ref.watch(isAdminProvider);

                    if (isMyProfile) {
                      return ElevatedButton(
                        onPressed: () => context.push('/edit-profile'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        child: const Text('Edit Profil'),
                      );
                    } else if (isAdmin) {
                      // Admin melihat profil user lain
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showCloseAccountDialog(context, ref, targetUserId, username),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 36),
                          ),
                          child: const Text('Tutup Akun'),
                        ),
                      );
                    }
                    else {
                      return Row(
                        children: [
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) {
                                final isFollowingAsync = ref.watch(isFollowingProvider(targetUserId));
                                final followNotifier = ref.read(followProvider.notifier);
                                final followState = ref.watch(followProvider);

                                final isFollowing = isFollowingAsync.value ?? false;
                                final isLoading = followState.isLoading;

                                return ElevatedButton(
                                  onPressed: isLoading ? null : () => followNotifier.toggleFollow(targetUserId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowing ? Colors.grey.shade300 : Theme.of(context).primaryColor,
                                    foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                                    minimumSize: const Size(double.infinity, 36),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                      : Text(isFollowing ? 'Unfollow' : 'Follow'),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                try {
                                  final chatRoomId = await ref
                                      .read(chatNotifierProvider.notifier)
                                      .createOrGetChatRoom(targetUserId);
                                  context.push('/chat/$targetUserId', extra: {
                                    'username': username,
                                    'chatRoomId': chatRoomId,
                                  });
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Gagal memulai chat: $e")),
                                  );
                                }
                              },
                              child: const Text('Message'),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => Text('Error loading profile: $e'),
        );
      },
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

class _VideoOrPlaceholder extends StatelessWidget {
  final Map<String, dynamic> postMap;
  const _VideoOrPlaceholder({required this.postMap});

  @override
  Widget build(BuildContext context) {
    final videoUrl = (postMap['videoUrl'] as String?) ?? '';
    if (videoUrl.isNotEmpty) {
      return VideoThumbnailWidget(videoUrl: videoUrl);
    }
    return Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported));
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
    return Container(color: Theme.of(context).scaffoldBackgroundColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
