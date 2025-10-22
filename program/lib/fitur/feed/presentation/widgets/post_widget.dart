import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:program/fitur/cart/domain/entities/cart_item.dart';
import 'package:program/fitur/cart/presentation/providers/cart_provider.dart';
import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/post/presentation/providers/post_provider.dart';
import 'package:program/fitur/post/presentation/widgets/video_player_widgets.dart';

/// Util ringan untuk menyisipkan transform Cloudinary secara aman
String _optimizeCloudinaryUrl(String originalUrl, {int? width, bool isVideo = false}) {
  try {
    if (!originalUrl.contains('res.cloudinary.com') || !originalUrl.contains('/upload/')) {
      return originalUrl; // bukan Cloudinary -> biarkan
    }
    final idx = originalUrl.indexOf('/upload/');
    final before = originalUrl.substring(0, idx + 8); // termasuk '/upload/'
    final after = originalUrl.substring(idx + 8);

    final params = <String>[];
    if (width != null) params.add('w_$width');
    // q_auto:eco untuk video, q_auto untuk image
    params.add(isVideo ? 'q_auto:eco' : 'q_auto');
    params.add('f_auto');

    return '$before${params.join(',')},/$after';
  } catch (_) {
    return originalUrl; // fallback aman
  }
}

/// PostWidget versi hemat bandwidth:
/// - Gambar di-resize via Cloudinary transforms
/// - Video hanya diload saat terlihat (lazy) menggunakan VisibilityDetector
class PostWidget extends ConsumerStatefulWidget {
  final Post post;
  const PostWidget({super.key, required this.post});

  @override
  ConsumerState<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends ConsumerState<PostWidget> {
  bool _shouldLoadVideo = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return GestureDetector(
      onTap: () => context.push('/post-detail/${post.id}'),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(post),
            _buildMedia(post),
            _buildDetails(post),
            _buildActionRow(context, post),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Post post) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnPost = currentUser?.uid == post.userId;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blueGrey,
            child: Text(
              post.username.isNotEmpty ? post.username[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (post.location?.isNotEmpty == true)
                  Text(
                    post.location!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value, post),
            itemBuilder: (context) {
              if (isOwnPost) {
                return [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus'),
                      ],
                    ),
                  ),
                ];
              } else {
                return [
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Laporkan'),
                      ],
                    ),
                  ),
                ];
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, Post post) {
    switch (action) {
      case 'edit':
        context.push('/edit-post/${post.id}');
        break;
      case 'delete':
        _showDeleteConfirmation(post);
        break;
      case 'report':
        _showReportDialog(post);
        break;
    }
  }

  void _showDeleteConfirmation(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Post'),
        content: Text('Apakah Anda yakin ingin menghapus "${post.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(postNotifierProvider.notifier).deletePost(post.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post berhasil dihapus'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur laporan akan segera tersedia'),
        backgroundColor: Colors.orange,
      ),
    );
  }



  Widget _buildMedia(Post post) {
    final hasVideo = post.videoUrl?.isNotEmpty == true;
    final hasImage = post.imageUrls.isNotEmpty;

    if (!hasVideo && !hasImage) {
      return const SizedBox.shrink();
    }

    final mediaChild = Container(
      width: double.infinity,
      height: 300,
      color: Colors.black,
      child: hasVideo
          ? (_shouldLoadVideo
          ? VideoPlayerWidget(
        url: _optimizeCloudinaryUrl(post.videoUrl!, width: 600, isVideo: true),
        autoPlay: post.type == PostType.short,
        showControls: true,
      )
          : GestureDetector(
        onTap: () {
          setState(() => _shouldLoadVideo = true);
        },
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline, color: Colors.white, size: 64),
              SizedBox(height: 8),
              Text('Tap atau scroll untuk memutar video',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ))
          : CachedNetworkImage(
        imageUrl: _optimizeCloudinaryUrl(post.imageUrls.first, width: 600),
        fit: BoxFit.contain,
        memCacheWidth: 600,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) =>
        const Center(child: Icon(Icons.error, color: Colors.white, size: 48)),
      ),
    );

    // Gunakan VisibilityDetector untuk lazy loading video
    if (hasVideo) {
      return VisibilityDetector(
        key: Key('post_vis_${post.id}'),
        onVisibilityChanged: (info) {
          final fraction = info.visibleFraction;
          // Untuk short, threshold 0.3 agar lebih mudah play
          final threshold = post.type == PostType.short ? 0.3 : 0.5;

          if (fraction > threshold && !_shouldLoadVideo) {
            setState(() => _shouldLoadVideo = true);
          } else if (fraction < 0.1 && _shouldLoadVideo && post.type != PostType.short) {
            // Untuk post biasa, boleh unload. Untuk short, tetap loaded
            setState(() => _shouldLoadVideo = false);
          }
        },
        child: mediaChild,
      );
    }

    return mediaChild;
  }

  Widget _buildDetails(Post post) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          Text('Jenis: ${post.type.name.toUpperCase()}'),
          if (post.category?.isNotEmpty == true)
            Text('Kategori: ${post.category}'),
          const SizedBox(height: 8),
          if (post.type == PostType.request)
            _buildRequestInfo(post)
          else
            _buildRegularPrice(post),
        ],
      ),
    );
  }

  Widget _buildRequestInfo(Post post) {
    final isExpired = post.isActive;
    final currentOffers = post.currentOffers;
    final maxOffers = post.maxOffers ?? 1;
    final isFull = currentOffers >= maxOffers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.isActive == false)
          Text(
            'Tidak Aktif',
            style: TextStyle(
              color: isExpired ? Colors.red : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (post.isActive == true)
          Text(
            'Aktif',
            style: TextStyle(
              color: !isExpired ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        Text('Penawaran: $currentOffers/$maxOffers'),
        if (!isExpired)
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
        fontSize: 18,
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, Post post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => ref.read(postNotifierProvider.notifier).toggleLike(post.id),
                child: Row(
                  children: [
                    Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text('${post.likesCount}'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => context.push('/post-detail/${post.id}'),
                child: Row(
                  children: [
                    const Icon(Icons.comment_outlined, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${post.commentsCount}'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (post.type == PostType.jastip || post.type == PostType.short)
                InkWell(
                  onTap: () {
                    final cartItem = CartItem(
                      id: '',
                      postId: post.id,
                      title: post.title,
                      price: post.price ?? 0,
                      imageUrl: post.imageUrls.isNotEmpty ? post.imageUrls.first : '',
                      sellerId: post.userId,
                      sellerUsername: post.username,
                      addedAt: Timestamp.now(),
                      isActive: post.isActive,
                      quantity: 1,
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
                  child: const Icon(Icons.shopping_cart_outlined, color: Colors.grey),
                ),
            ],
          ),
          if (post.type == PostType.request)
            _buildRequestActionButton(context, post)
          else
            _buildBuyButton(context, post),
        ],
      ),
    );
  }

  Widget _buildRequestActionButton(BuildContext context, Post post) {
    final isExpired = post.isActive;
    final currentOffers = post.currentOffers;
    final maxOffers = post.maxOffers ?? 1;
    final isFull = currentOffers >= maxOffers;

    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnPost = currentUser?.uid == post.userId;

    if (isExpired || isFull || isOwnPost) {
      if (isOwnPost) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Colors.grey, size: 16),
              SizedBox(width: 4),
              Text(
                'Postingan Anda',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: () => _takeOrder(context, post),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: const Text('Ambil Pesanan'),
    );
  }

  Widget _buildBuyButton(BuildContext context, Post post) {
    return ElevatedButton(
      onPressed: () => context.push('/post-detail/${post.id}'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: const Text('Beli Sekarang'),
    );
  }

  void _takeOrder(BuildContext context, Post post) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ambil Pesanan'),
        content: Text('Apakah Anda yakin ingin mengambil pesanan "${post.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(postNotifierProvider.notifier).takeOrder(post.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pesanan berhasil diambil!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Ya, Ambil'),
          ),
        ],
      ),
    );
  }
}
