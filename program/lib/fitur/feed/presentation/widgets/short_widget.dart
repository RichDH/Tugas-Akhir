import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../post/domain/entities/post.dart';
import '../../../post/presentation/widgets/video_player_widgets.dart'; // Import yang sudah ada
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../post/presentation/providers/post_provider.dart';

class ShortsWidget extends ConsumerStatefulWidget {
  final Post post; // ✅ Ubah ke Post entity

  const ShortsWidget({super.key, required this.post});

  @override
  ConsumerState<ShortsWidget> createState() => _ShortsWidgetState();
}

class _ShortsWidgetState extends ConsumerState<ShortsWidget> {
  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final formattedPrice = post.price != null
        ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(post.price!)
        : 'Free';

    return GestureDetector(
      onTap: () {
        context.push('/post-detail/${post.id}');
      },
      child: Stack(
        children: [
          // Full Screen Video
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: post.videoUrl != null
                ? VideoPlayerWidget(url: post.videoUrl!) // ✅ Gunakan widget yang sudah ada
                : const Center(
              child: Icon(Icons.error, color: Colors.white, size: 64),
            ),
          ),

          // Overlay dengan info post (kanan bawah)
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                // Like button
                _buildActionButton(
                  icon: Icons.favorite_border,
                  label: '${post.likesCount}',
                  onTap: () {
                    ref.read(postNotifierProvider.notifier).toggleLike(post.id);
                  },
                ),
                const SizedBox(height: 20),

                // Comment button
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '${post.commentsCount}',
                  onTap: () {
                    context.push('/post-detail/${post.id}');
                  },
                ),
                const SizedBox(height: 20),

                // Cart button
                _buildActionButton(
                  icon: Icons.shopping_cart_outlined,
                  label: '',
                  onTap: () {
                    final cartItem = CartItem(
                      postId: post.id,
                      title: post.title,
                      price: post.price ?? 0,
                      imageUrl: post.imageUrls.isNotEmpty ? post.imageUrls[0] : '',
                      sellerId: post.userId,
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
          ),

          // Info post (kiri bawah)
          Positioned(
            left: 12,
            right: 80,
            bottom: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${post.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (post.price != null)
                  Text(
                    formattedPrice,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
