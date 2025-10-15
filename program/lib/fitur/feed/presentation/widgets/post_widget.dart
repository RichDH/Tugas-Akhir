import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ TAMBAHKAN IMPORT INI

import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/post/presentation/providers/post_provider.dart';
import 'package:program/fitur/cart/domain/entities/cart_item.dart';
import 'package:program/fitur/cart/presentation/providers/cart_provider.dart';
import 'package:program/fitur/post/presentation/widgets/video_player_widgets.dart';

class PostWidget extends ConsumerWidget {
  final Post post;

  const PostWidget({
    required this.post,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        context.push('/post-detail/${post.id}');
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER POST (USER INFO)
            Padding(
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
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      // TODO: Menu opsi
                    },
                  ),
                ],
              ),
            ),

            // MEDIA (VIDEO ATAU GAMBAR) DENGAN BACKGROUND HITAM
            if (post.videoUrl?.isNotEmpty == true)
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
                child: CachedNetworkImage(
                  imageUrl: post.imageUrls.first,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.error, color: Colors.white, size: 48),
                  ),
                ),
              ),

            // DETAIL POST
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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

                  // HARGA ATAU INFO REQUEST
                  if (post.type == PostType.request)
                    _buildRequestInfo(post)
                  else
                    _buildRegularPrice(post),
                ],
              ),
            ),

            // ACTION BUTTONS
            _buildActionButtons(context, ref, post),
          ],
        ),
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
        if (post.isActive ==false)
          Text(
            'Tidak Aktif',
            style: TextStyle(
              color: isExpired ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (post.isActive ==true)
          Text(
            'Aktif',
            style: TextStyle(
              color: isExpired ? Colors.red : Colors.green,
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Like, Comment, Cart buttons
          Row(
            children: [
              // LIKE BUTTON
              InkWell(
                onTap: () {
                  ref.read(postNotifierProvider.notifier).toggleLike(post.id);
                },
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

              // COMMENT BUTTON
              InkWell(
                onTap: () {
                  context.push('/post-detail/${post.id}');
                },
                child: Row(
                  children: [
                    const Icon(Icons.comment_outlined, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${post.commentsCount}'),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // CART BUTTON (HANYA UNTUK JASTIP/SHORT)
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

              // OFFERS BUTTON (KHUSUS REQUEST)
              if (post.type == PostType.request) ...[
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    context.push('/post-detail/${post.id}');
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_outlined, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${post.currentOffers}'),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // ACTION BUTTON (BELI/AMBIL PESANAN)
          if (post.type == PostType.request)
            _buildRequestActionButton(context, ref, post)
          else
            _buildBuyButton(context, post),
        ],
      ),
    );
  }

  // ✅ TOMBOL AMBIL PESANAN (REQUEST) - UPDATED
  Widget _buildRequestActionButton(BuildContext context, WidgetRef ref, Post post) {
    final isExpired = post.isActive;
    final currentOffers = post.currentOffers;
    final maxOffers = post.maxOffers ?? 1;
    final isFull = currentOffers >= maxOffers;

    // ✅ CEK APAKAH POST MILIK USER SENDIRI
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnPost = currentUser?.uid == post.userId;

    // ✅ JANGAN TAMPILKAN TOMBOL JIKA EXPIRED, FULL, ATAU POST SENDIRI
    if (isExpired || isFull || isOwnPost) {
      // ✅ TAMPILKAN WIDGET ALTERNATIF UNTUK POST SENDIRI
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
      onPressed: () {
        _takeOrder(context, ref, post);
      },
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
      onPressed: () {
        context.push('/post-detail/${post.id}');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: const Text('Beli Sekarang'),
    );
  }

  void _takeOrder(BuildContext context, WidgetRef ref, Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
