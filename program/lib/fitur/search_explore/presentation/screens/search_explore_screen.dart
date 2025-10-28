import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/fitur/search_explore/presentation/providers/search_provider.dart';
import 'package:program/fitur/search_explore/presentation/widgets/filter_dialog.dart';
import 'package:go_router/go_router.dart';

import '../../../post/domain/entities/post.dart';
import '../../domain/entities/search_filter.dart';

class SearchExploreScreen extends ConsumerWidget {
  const SearchExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final filter = ref.watch(searchFilterProvider);
    final hasActiveFilter = !filter.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pencarian'),
      ),
      body: Column(
        children: [
          // Search Bar dengan Filter Button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Cari pengguna atau barang...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (query) {
                      ref.read(searchQueryProvider.notifier).state = query;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: hasActiveFilter ? Colors.blue : null,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const FilterDialog(),
                    );
                  },
                ),
              ],
            ),
          ),

          // Filter indicator
          if (hasActiveFilter)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.filter_alt, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Filter aktif',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      ref.read(searchFilterProvider.notifier).state = const SearchFilter();
                    },
                    child: Text(
                      'Hapus',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Suggested ads section (tetap sama)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Icon(Icons.recommend, color: Colors.purple, size: 18),
                  const SizedBox(width: 6),
                  Text('Suggested', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SuggestedAdsStrip(),
          const Divider(height: 16),

          // Search Results
          Expanded(
            child: searchQuery.isEmpty
                ? const Center(child: Text('Masukkan kata kunci untuk memulai pencarian.'))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hasil Barang
                  _SearchSection(
                    title: 'Barang',
                    icon: Icons.shopping_bag,
                    child: _PostSearchResults(query: searchQuery),
                  ),
                  const SizedBox(height: 24),

                  // Hasil Pengguna
                  _SearchSection(
                    title: 'Pengguna',
                    icon: Icons.people,
                    child: _UserSearchResults(query: searchQuery),
                  ),

                  // Location-based results (jika ada filter lokasi)
                  if (filter.location?.isNotEmpty == true) ...[
                    const SizedBox(height: 24),
                    _SearchSection(
                      title: 'Barang di sekitar ${filter.location}',
                      icon: Icons.location_on,
                      child: _LocationSearchResults(location: filter.location!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget untuk section hasil pencarian
class _SearchSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SearchSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _PostSearchResults extends ConsumerWidget {
  final String query;

  const _PostSearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postSearchProvider);

    return postsAsync.when(
      data: (posts) {
        // ✅ PERUBAHAN: Berikan feedback yang lebih informatif
        if (posts.isEmpty && query.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tidak ada barang ditemukan untuk "$query".'),
              const SizedBox(height: 8),
              Text(
                'Tips: Coba gunakan kata kunci yang lebih umum atau periksa filter yang aktif.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          );
        }

        if (posts.isEmpty && query.isEmpty) {
          return const Text('Masukkan kata kunci untuk mencari barang.');
        }

        // Tampilkan maksimal 3 untuk preview
        final displayPosts = posts.take(3).toList();
        final hasMore = posts.length > 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Tampilkan info jumlah hasil
            if (query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Ditemukan ${posts.length} hasil untuk "$query"',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: displayPosts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final post = displayPosts[index];
                  return _PostCard(post: post);
                },
              ),
            ),
            if (hasMore) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _showAllPostsDialog(context, posts);
                },
                child: Text('Lihat semua ${posts.length} hasil'),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Error: $err'),
          const SizedBox(height: 8),
          Text(
            'Terjadi kesalahan saat mencari. Silakan coba lagi.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showAllPostsDialog(BuildContext context, List<Post> posts) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Semua Hasil Barang (${posts.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _PostCardLarge(post: post);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget card untuk post yang lebih besar
class _PostCardLarge extends StatelessWidget {
  final Post post;

  const _PostCardLarge({required this.post});

  @override
  Widget build(BuildContext context) {
    final img = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop(); // Close dialog
        context.push('/post-detail/${post.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: img != null
                    ? Image.network(
                  img,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported)
                  ),
                )
                    : Container(
                  color: Colors.grey.shade200,
                  width: double.infinity,
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    if (post.price != null)
                      Text(
                        'Rp ${post.price!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (post.location != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        post.location!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Widget untuk hasil pencarian user
class _UserSearchResults extends ConsumerWidget {
  final String query;

  const _UserSearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(filteredUserSearchProvider(query));

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return const Text('Tidak ada pengguna ditemukan.');
        }

        return Column(
          children: users.map((userData) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: userData['profileImageUrl'] != null
                    ? NetworkImage(userData['profileImageUrl'])
                    : null,
                child: userData['profileImageUrl'] == null
                    ? Text(userData['username']?[0].toUpperCase() ?? '?')
                    : null,
              ),
              title: Row(
                children: [
                  Text(userData['username'] ?? ''),
                  if (userData['isVerified'] == true) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Colors.blue, size: 16),
                  ],
                ],
              ),
              subtitle: userData['fullName'] != null
                  ? Text(userData['fullName'])
                  : null,
              onTap: () {
                context.push('/user/${userData['id']}');
              },
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error: $err'),
    );
  }
}

// Widget untuk hasil pencarian berdasarkan lokasi
class _LocationSearchResults extends ConsumerWidget {
  final String location;

  const _LocationSearchResults({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(locationBasedPostSearchProvider(location));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return const Text('Tidak ada barang ditemukan di sekitar lokasi tersebut.');
        }

        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              return _PostCard(post: post);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error: $err'),
    );
  }
}

// Widget card untuk post
class _PostCard extends StatelessWidget {
  final Post post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final img = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;

    return InkWell(
      onTap: () => context.push('/post-detail/${post.id}'),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))
          ],
        ),
        child: Column(
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: img != null
                    ? Image.network(
                  img,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported)
                  ),
                )
                    : Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  if (post.price != null)
                    Text(
                      'Rp ${post.price!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedAdsStrip extends ConsumerWidget {
  const _SuggestedAdsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsAsync = ref.watch(suggestedAdsProvider);

    return SizedBox(
      height: 110,
      child: adsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            // ✅ Tampilkan "No suggestions" ketika kosong
            return Center(
              child: Text(
                'No suggestions',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final p = posts[index];
              return _SuggestedCard(post: p);
            },
          );
        },
        loading: () => const Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2)
            )
        ),
        error: (e, s) => Center(
          child: Text(
            'No suggestions',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestedCard extends StatelessWidget {
  final Post post;
  const _SuggestedCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final img = (post.imageUrls.isNotEmpty) ? post.imageUrls.first : null;
    final isShort = post.type == PostType.short;
    final badgeText = 'L${post.adsLevel ?? 0}';

    return InkWell(
      onTap: () => context.push('/post-detail/${post.id}'),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Column(
          children: [
            // Thumbnail
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: img != null
                    ? Image.network(img, fit: BoxFit.cover, width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported)))
                    : Container(color: Colors.grey.shade200, child: Icon(isShort ? Icons.play_circle_fill : Icons.image, color: Colors.grey.shade600)),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  // Ads badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.withOpacity(0.2)),
                    ),
                    child: Text('Ad $badgeText', style: TextStyle(fontSize: 10, color: Colors.purple.shade700, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Icon(isShort ? Icons.smart_display : Icons.shopping_bag, size: 14, color: Colors.grey.shade600),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
