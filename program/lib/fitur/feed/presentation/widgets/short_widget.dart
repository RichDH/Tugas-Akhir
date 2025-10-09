import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../post/presentation/widgets/video_player_controller.dart';

class ShortsWidget extends ConsumerWidget {
  final Map<String, dynamic> post;

  const ShortsWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoUrl = post['videoUrl'] as String?;

    return Stack(
      children: [
        // Full Screen Video
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: videoUrl != null
              ? VideoPlayerWidget(
            url: videoUrl,
            autoPlay: true,
            showControls: false,
          )
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
                label: '${post['likesCount'] ?? 0}',
                onTap: () {
                  // Toggle like
                },
              ),
              const SizedBox(height: 20),

              // Comment button
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: '${post['commentsCount'] ?? 0}',
                onTap: () {
                  context.push('/post-detail/${post['id']}');
                },
              ),
              const SizedBox(height: 20),

              // Cart button
              _buildActionButton(
                icon: Icons.shopping_cart_outlined,
                label: '',
                onTap: () {
                  // Add to cart
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
                '@${post['username'] ?? 'user'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                post['title'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (post['price'] != null)
                Text(
                  'Rp ${post['price']}',
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
