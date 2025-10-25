import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/fitur/search_explore/presentation/providers/search_provider.dart';
import 'package:go_router/go_router.dart';

import '../../../post/domain/entities/post.dart';

class SearchExploreScreen extends ConsumerWidget {
  const SearchExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResults = ref.watch(userSearchProvider(searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Pengguna'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              autofocus: true, // Langsung fokus ke search bar
              decoration: const InputDecoration(
                hintText: 'Cari username...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (query) {
                ref.read(searchQueryProvider.notifier).state = query;
              },
            ),
          ),

          // Suggested ads section
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


          Expanded(
            child: searchResults.when(
              // Kondisi saat stream memberikan data (termasuk data kosong)
              data: (snapshot) {
                final filteredDocs = snapshot.docs.where((d) {
                  final m = d.data() as Map<String, dynamic>;
                  // tampilkan jika deleted tidak ada atau false
                  return !m.containsKey('deleted') || m['deleted'] == false;
                }).toList();

                // Jika belum ada input, tampilkan pesan awal
                if (searchQuery.isEmpty) {
                  return const Center(child: Text('Masukkan nama pengguna untuk memulai pencarian.'));
                }
                // Jika sudah ada input tapi tidak ada hasil
                if (snapshot.docs.isEmpty || filteredDocs.isEmpty) {
                  return const Center(child: Text('Pengguna tidak ditemukan.'));
                }

                // Jika ada hasil, tampilkan list
                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final userDoc = filteredDocs[index];
                    final userData = userDoc.data() as Map<String, dynamic>;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(userData['username']?[0].toUpperCase() ?? '?'),
                      ),
                      title: Text(userData['username'] ?? ''),
                      onTap: () {
                        context.push('/user/${userDoc.id}');
                      },
                    );
                  },
                );
              },
              // Kondisi saat stream sedang menunggu data pertama kali
              loading: () {
                // Jika belum ada input, jangan tampilkan apa-apa (atau pesan awal)
                if (searchQuery.isEmpty) {
                  return const Center(child: Text('Masukkan nama pengguna untuk memulai pencarian.'));
                }
                // Jika sudah ada input, tampilkan loading indicator
                return const Center(child: CircularProgressIndicator());
              },
              // Kondisi jika terjadi error (seperti permission-denied sebelumnya)
              error: (err, stack) => Center(child: Text('Terjadi kesalahan: $err')),
            ),
          )
        ],
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
      height: 120,
      child: adsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            // Jika tidak ada ads, tampilkan strip kosong agar UI tetap ringan
            return const SizedBox.shrink();
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
        loading: () => const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
        error: (e, s) => const SizedBox.shrink(),
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
