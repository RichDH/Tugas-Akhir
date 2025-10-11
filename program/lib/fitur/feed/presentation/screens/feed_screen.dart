import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/feed/presentation/providers/feed_filter_provider.dart';
import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/cart/presentation/providers/cart_provider.dart';
import 'package:program/fitur/post/presentation/widgets/video_player_widgets.dart';
import 'package:program/fitur/post/presentation/providers/post_provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../cart/domain/entities/cart_item.dart';
import '../../domain/entities/feed_filter.dart';
import '../widgets/short_widget.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ GUNAKAN PROVIDER YANG BENAR
    final postsAsyncValue = ref.watch(postsProvider);
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

          // Filter buttons
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

                // Filter berdasarkan pilihan
                final filteredPosts = posts.where((post) {
                  if (currentFilter == FeedFilter.all) return true;
                  if (currentFilter == FeedFilter.short) return post.type == PostType.short;
                  if (currentFilter == FeedFilter.request) return post.type == PostType.request;
                  if (currentFilter == FeedFilter.jastip) return post.type == PostType.jastip;
                  return false;
                }).toList();

                if (filteredPosts.isEmpty) {
                  return const Center(child: Text('Tidak ada postingan untuk ditampilkan.'));
                }

                // Special layout untuk shorts
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

// ✅ POST WIDGET YANG DIPERBAIKI
class PostWidget extends ConsumerWidget {
  final Post post;

  const PostWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        context.push('/post-detail/${post.id}');
      },
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Penjual
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(post.location ?? ''),
            ),

            // Media
            if (post.videoUrl != null)
              Container(
                width: double.infinity,
                height: 300,
                color: Colors.black,
                child: VideoPlayerWidget(url: post.videoUrl!),
              )
            else if (post.imageUrls.isNotEmpty)
              Container(
                width: double.infinity,
                height: 300,
                color: Colors.black,
                child: Image.network(
                  post.imageUrls.first,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    return progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) =>
                  const Center(child: Icon(Icons.error, color: Colors.white)),
                ),
              ),

            // Detail Post
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (post.description?.isNotEmpty == true)
                    Text(
                      post.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Text('Kategori: ${post.category ?? '–'}'),
                  const SizedBox(height: 8),

                  // Logic berbeda untuk request vs jastip/short
                  if (post.type == PostType.request)
                    _buildRequestInfo(post)
                  else
                    _buildRegularPrice(post),
                ],
              ),
            ),

            // Action Buttons
            _buildActionButtons(context, ref, post),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestInfo(Post post) {
    final now = DateTime.now();
    final isExpired = post.deadline?.toDate().isBefore(now) ?? false;
    final currentOffers = post.currentOffers;
    final maxOffers = post.maxOffers ?? 1;
    final isFull = currentOffers >= maxOffers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.deadline != null)
          Text(
            'Deadline: ${DateFormat('dd/MM/yyyy HH:mm').format(post.deadline!.toDate())}',
            style: TextStyle(
              color: isExpired ? Colors.red : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        Text('Penawaran: $currentOffers/$maxOffers'),
        if (isExpired)
          const Text(
            'EXPIRED',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          )
        else if (isFull)
          const Text(
            'PENUH',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildRegularPrice(Post post) {
    final formattedPrice = post.price != null
        ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(post.price!)
        : 'Free';

    return Text(
      formattedPrice,
      style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green,
          fontSize: 18
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Post post) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: post.isLiked ? Colors.red : null,
                ),
                onPressed: () {
                  ref.read(postNotifierProvider.notifier).toggleLike(post.id);
                },
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () {
                  context.push('/post-detail/${post.id}');
                },
              ),
              // Cart button hanya untuk jastip/short
              if (post.type == PostType.jastip || post.type == PostType.short)
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () {
                    final cartItem = CartItem(
                      id: '',
                      postId: post.id,
                      title: post.title,
                      price: post.price ?? 0,
                      imageUrl: post.imageUrls.isNotEmpty ? post.imageUrls.first : '',
                      sellerId: post.userId,
                      sellerUsername: post.username,
                      addedAt: Timestamp.now(),
                      deadline: post.deadline,
                    );
                    ref.read(cartProvider.notifier).addToCart(cartItem);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ditambahkan ke keranjang'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
            ],
          ),

          // Button berbeda untuk request vs jastip
          if (post.type == PostType.request)
            _buildRequestButton(context, ref, post)
          else
            ElevatedButton(
              onPressed: () {
                context.push('/post-detail/${post.id}');
              },
              child: const Text('Beli Sekarang'),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestButton(BuildContext context, WidgetRef ref, Post post) {
    final now = DateTime.now();
    final isExpired = post.deadline?.toDate().isBefore(now) ?? false;
    final currentOffers = post.currentOffers;
    final maxOffers = post.maxOffers ?? 1;
    final isFull = currentOffers >= maxOffers;
    final isOwnPost = false; // TODO: Check if current user is the post owner

    // Jangan tampilkan tombol jika expired, full, atau post sendiri
    if (isExpired || isFull || isOwnPost) {
      return const SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: () {
        _takeOrder(context, ref, post);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      child: const Text('Ambil Pesanan'),
    );
  }

  void _takeOrder(BuildContext context, WidgetRef ref, Post post) {
    // ✅ GUNAKAN PROVIDER YANG SUDAH DIBUAT
    ref.read(postNotifierProvider.notifier).takeOrder(post.id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pesanan berhasil diambil!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
