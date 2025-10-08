import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/feed/presentation/providers/feed_filter_provider.dart';
import 'package:program/fitur/feed/presentation/providers/feed_provider.dart';
import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/cart/presentation/providers/cart_provider.dart';
import 'package:program/fitur/post/presentation/widgets/video_player_widgets.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../cart/domain/entities/cart_item.dart';
import '../../../post/presentation/providers/post_provider.dart';
import '../../domain/entities/feed_filter.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsyncValue = ref.watch(postsStreamProvider);
    final currentFilter = ref.watch(feedFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngoper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              // TODO: Navigasi ke notifikasi
            },
          ),
          // ✅ TOMBOL KERANJANG DI APPBAR
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
          // Section Stories (Placeholder)
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[300],
                        child: Icon(Icons.person, size: 30, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User $index',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // ✅ FILTER BUTTONS (Riverpod-based)
          Container(
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
          ),

          // List Postingan
          Expanded(
            child: postsAsyncValue.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const Center(child: Text('Belum ada postingan.'));
                }

                // Filter berdasarkan pilihan + abaikan 'live'
                final filteredPosts = posts
                    .where((post) {
                  if (currentFilter == FeedFilter.all) return true;
                  if (currentFilter == FeedFilter.short && post.type == 'short') return true;
                  if (currentFilter == FeedFilter.request && post.type == 'request') return true;
                  if (currentFilter == FeedFilter.jastip && post.type == 'jastip') return true;
                  return false;
                })
                    .where((post) => post.type != 'live') // ✅ Abaikan live
                    .toList();

                if (filteredPosts.isEmpty) {
                  return const Center(child: Text('Tidak ada postingan untuk ditampilkan.'));
                }

                return ListView.builder(
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, index) {
                    final post = filteredPosts[index];
                    return PostWidget(post: post);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget untuk menampilkan satu postingan
class PostWidget extends ConsumerWidget {
  final Post post;

  const PostWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formattedPrice = post.price != null
        ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(post.price!)
        : 'Harga tidak tersedia';

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Penjual
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(post.username ?? 'Pengguna', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(post.location ?? ''),
          ),

          // Media: Video atau Gambar
          if (post.videoUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: VideoPlayerWidget(url: post.videoUrl!),
            )
          else if (post.imageUrls.isNotEmpty)
            Image.network(
              post.imageUrls[0],
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                return progress == null ? child : const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error)),
            ),

          // Detail Post
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.title ?? '', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(post.description ?? ''),
                const SizedBox(height: 8),
                Text('Kategori: ${post.category ?? '–'}'),
                const SizedBox(height: 8),
                Text(formattedPrice, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () {
                        ref.read(postNotifierProvider.notifier).toggleLike(post.id);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () {
                        context.push('/chat/${post.userId}');
                      },
                    ),
                    // ✅ TOMBOL KERANJANG (hanya untuk jastip/short)
                    if (post.type == 'jastip' || post.type == 'short')
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined),
                        onPressed: () {
                          final cartItem = CartItem(
                            postId: post.id,
                            title: post.title ?? '',
                            price: post.price ?? 0,
                            imageUrl: post.imageUrls.isNotEmpty ? post.imageUrls[0] : '',
                            sellerId: post.userId,
                            addedAt: Timestamp.now(),
                            deadline: post.deadline,
                          );
                          ref.read(cartProvider.notifier).addToCart(cartItem);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ditambahkan ke keranjang')),
                          );
                        },
                      ),
                  ],
                ),
                if (post.type == 'jastip')
                  ElevatedButton(
                    onPressed: () {
                      context.push('/post-detail/${post.id}');
                    },
                    child: const Text('Beli Sekarang'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}