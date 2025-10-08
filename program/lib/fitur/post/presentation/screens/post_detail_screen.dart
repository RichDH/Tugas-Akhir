import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:program/fitur/post/presentation/providers/post_provider.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:program/fitur/chat/presentation/screens/chat_individu.dart';
import 'package:program/fitur/post/presentation/widgets/video_player_widgets.dart';
import 'package:program/fitur/cart/presentation/providers/cart_provider.dart';

import '../../../cart/domain/entities/cart_item.dart'; // Tambahkan import ini

class PostDetailScreen extends ConsumerWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailStreamProvider(postId));
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text("Detail Postingan")),
      body: postAsync.when(
        data: (postDoc) {
          if (!postDoc.exists || postDoc.data() == null) {
            return const Center(child: Text("Postingan tidak ditemukan."));
          }
          final postData = postDoc.data() as Map<String, dynamic>;
          final sellerId = postData['userId'] as String? ?? '';
          final imageUrls = List<String>.from(postData['imageUrls'] ?? []);
          final videoUrl = postData['videoUrl'] as String?;
          final likes = List<String>.from(postData['likes'] ?? []);
          final isLiked = likes.contains(currentUserId);
          final postType = postData['type'] as String? ?? 'jastip';
          final price = postData['price'] as num?;
          final formattedPrice = price != null
              ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(price)
              : 'Harga tidak tersedia';

          // Ambil username seller dari Firestore
          final sellerUserAsync = ref.watch(userProvider(sellerId));

          // ✅ SIMPAN DATA POST KE VARIABEL LOKAL DI SINI — SEBELUM RETURN
          final String? title = postData['title'] as String?;
          final double? priceValue = (postData['price'] as num?)?.toDouble();
          final List<String> imageUrlsList = List<String>.from(postData['imageUrls'] ?? []);
          final Timestamp? deadline = postData['deadline'] as Timestamp?;

          return ListView(
            children: [
              // Header Pengguna
              if (sellerId.isNotEmpty)
                sellerUserAsync.when(
                  data: (userDoc) {
                    if (!userDoc.exists) return const SizedBox.shrink();
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final sellerUsername = userData['username'] ?? 'Pengguna';
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(sellerUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(postData['location'] ?? ''),
                    );
                  },
                  loading: () => const ListTile(title: Text("Memuat penjual...")),
                  error: (e, s) => const ListTile(title: Text("Gagal memuat penjual")),
                ),

              // Media: Video atau Gambar
              if (videoUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VideoPlayerWidget(url: videoUrl),
                )
              else if (imageUrlsList.isNotEmpty)
                Image.network(
                  imageUrlsList[0],
                  height: 300,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    return progress == null ? child : const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error)),
                ),

              // Tombol Aksi
              _buildActionButtons(
                context: context,
                ref: ref,
                postId: postId,
                isLiked: isLiked,
                postType: postType,
                currentUserId: currentUserId,
                sellerId: sellerId,
                sellerUserAsync: sellerUserAsync,
                title: title, // ✅ Lewatkan ke button
                price: priceValue, // ✅ Lewatkan ke button
                imageUrls: imageUrlsList, // ✅ Lewatkan ke button
                deadline: deadline, // ✅ Lewatkan ke button
              ),

              // Detail
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(postData['title'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(postData['description'] ?? ''),
                    const SizedBox(height: 12),
                    Text('Jenis: ${postType.toUpperCase()}'),
                    Text('Kategori: ${postData['category'] ?? '–'}'),
                    const SizedBox(height: 8),
                    Text(formattedPrice, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                  ],
                ),
              ),

              const Divider(height: 24),

              // Komentar
              InkWell(
                onTap: () => _showCommentsBottomSheet(context, ref, postId),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text("Lihat semua komentar", style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildActionButtons({
    required BuildContext context,
    required WidgetRef ref,
    required String postId,
    required bool isLiked,
    required String postType,
    required String currentUserId,
    required String sellerId,
    required AsyncValue<DocumentSnapshot> sellerUserAsync,
    required String? title, // ✅ Diterima dari build()
    required double? price, // ✅ Diterima dari build()
    required List<String> imageUrls, // ✅ Diterima dari build()
    required Timestamp? deadline, // ✅ Diterima dari build()
  }) {
    if (currentUserId == sellerId || sellerId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : null),
                onPressed: () => ref.read(postNotifierProvider.notifier).toggleLike(postId),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () {
                  String sellerUsername = 'Penjual';
                  if (sellerUserAsync.valueOrNull?.exists == true) {
                    final userData = sellerUserAsync.valueOrNull!.data() as Map<String, dynamic>?;
                    sellerUsername = userData?['username'] ?? 'Penjual';
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        otherUserId: sellerId,
                        otherUsername: sellerUsername,
                        postId: postId,
                        isOfferMode: postType == 'request',
                      ),
                    ),
                  );
                },
              ),
              // ✅ TOMBOL TAMBAH KE KERANJANG (hanya untuk jastip/short)
              if (postType == 'jastip' || postType == 'short')
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () {
                    final cartItem = CartItem(
                      postId: postId,
                      title: title ?? '',
                      price: price ?? 0,
                      imageUrl: imageUrls.isNotEmpty ? imageUrls[0] : '',
                      sellerId: sellerId,
                      addedAt: Timestamp.now(),
                      deadline: deadline, // Ambil deadline dari post
                    );
                    ref.read(cartProvider.notifier).addToCart(cartItem);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ditambahkan ke keranjang')));
                  },
                ),
            ],
          ),
          // ✅ TOMBOL BELI SEKARANG (tetap ada)
          if (postType == 'jastip')
            ElevatedButton(
              onPressed: () => _handleOrder(context, ref, postId, sellerId),
              child: const Text('Beli Sekarang'),
            )
          else if (postType == 'request')
            ElevatedButton(
              onPressed: () => _handleMakeOffer(context, ref, postId, sellerId),
              child: const Text('Buat Penawaran'),
            ),
        ],
      ),
    );
  }

  void _handleOrder(BuildContext context, WidgetRef ref, String postId, String sellerId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
    final postData = postDoc.data() as Map<String, dynamic>?;
    if (postData == null) return;

    final amount = (postData['price'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harga tidak valid')));
      return;
    }

    await ref.read(transactionProvider.notifier).createTransaction(
      postId: postId,
      buyerId: currentUser.uid,
      sellerId: sellerId,
      amount: amount,
      isEscrow: true,
      escrowAmount: amount,
    );

    _showSuccessDialog(context, 'Transaksi berhasil dibuat!\nSilakan tunggu konfirmasi dari jastiper.');
    if (context.mounted) Navigator.pop(context);
  }

// Helper: Popup sukses
  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleMakeOffer(BuildContext context, WidgetRef ref, String postId, String sellerId) {
    String sellerUsername = 'Penjual';
    final sellerUserDoc = ref.read(userProvider(sellerId)).valueOrNull;
    if (sellerUserDoc?.exists == true) {
      final userData = sellerUserDoc!.data() as Map<String, dynamic>?;
      sellerUsername = userData?['username'] ?? 'Penjual';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: sellerId,
          otherUsername: sellerUsername,
          postId: postId,
          isOfferMode: true,
        ),
      ),
    );
  }

  void _showCommentsBottomSheet(BuildContext context, WidgetRef ref, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final commentsAsync = ref.watch(commentsStreamProvider(postId));
        final commentController = TextEditingController();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                const Text("Komentar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                Expanded(
                  child: commentsAsync.when(
                       data: (snapshot) {
                      if (snapshot.docs.isEmpty) {
                        return const Center(child: Text("Belum ada komentar"));
                      }
                      return ListView.builder(
                        itemCount: snapshot.docs.length,
                        itemBuilder: (context, index) {
                          final comment = snapshot.docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(comment['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(comment['text'] ?? ''),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text("Error: $e")),
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          hintText: 'Tambahkan komentar...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        if (commentController.text.trim().isNotEmpty) {
                          ref.read(postNotifierProvider.notifier).addComment(postId, commentController.text);
                          commentController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}