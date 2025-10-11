import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        // ✅ NAVIGASI KE DETAIL POST
        context.push('/post-detail/${post.id}');
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ HEADER POST (USER INFO)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blueGrey,
                    child: Text(
                      post.username.isNotEmpty ? post.username.toUpperCase() : '?',
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
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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

            // ✅ MEDIA (VIDEO ATAU GAMBAR) DENGAN BACKGROUND HITAM
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
                  fit: BoxFit.contain, // ✅ JANGAN CROP GAMBAR PORTRAIT
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.error, color: Colors.white, size: 48),
                  ),
                ),
              ),

            // ✅ DETAIL POST
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Judul
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

                  // ✅ DESKRIPSI (HANDLE NULL)
                  if (post.description?.isNotEmpty == true)
                    Text(
                      post.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),

                  // Info tambahan
                  Text('Jenis: ${post.type.name.toUpperCase()}'),
                  if (post.category?.isNotEmpty == true)
                    Text('Kategori: ${post.category}'),
                  const SizedBox(height: 8),

                  // ✅ HARGA ATAU INFO REQUEST
                  if (post.type == PostType.request)
                    _buildRequestInfo(post)
                  else
                    _buildRegularPrice(post),
                ],
              ),
            ),

            // ✅ ACTION BUTTONS
            _buildActionButtons(context, ref, post),
          ],
        ),
      ),
    );
  }

  // ✅ WIDGET UNTUK INFO REQUEST
  Widget _buildRequestInfo(Post post) {
    final now = DateTime.now();
    final isExpired = post.deadline?.toDate().isBefore(now) ?? false;
    final currentOffers = post.currentOffers; // ✅ GUNAKAN currentOffers BUKAN offersCount
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

  // ✅ WIDGET UNTUK HARGA REGULAR
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

  // ✅ ACTION BUTTONS
  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Post post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Like, Comment, Cart buttons
          Row(
            children: [
              // ✅ LIKE BUTTON
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

              // ✅ COMMENT BUTTON
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

              // ✅ CART BUTTON (HANYA UNTUK JASTIP/SHORT)
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
                      deadline: post.deadline,
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

              // ✅ OFFERS BUTTON (KHUSUS REQUEST)
              if (post.type == PostType.request) ...[
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    // TODO: Navigasi ke halaman daftar tawaran
                    context.push('/post-detail/${post.id}');
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_outlined, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${post.currentOffers}'), // ✅ GUNAKAN currentOffers
                    ],
                  ),
                ),
              ],
            ],
          ),

          // ✅ ACTION BUTTON (BELI/AMBIL PESANAN)
          if (post.type == PostType.request)
            _buildRequestActionButton(context, ref, post)
          else
            _buildBuyButton(context, post),
        ],
      ),
    );
  }

  // ✅ TOMBOL AMBIL PESANAN (REQUEST)
  Widget _buildRequestActionButton(BuildContext context, WidgetRef ref, Post post) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: const Text('Ambil Pesanan'),
    );
  }

  // ✅ TOMBOL BELI (JASTIP/SHORT)
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

  // ✅ FUNGSI AMBIL PESANAN
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
