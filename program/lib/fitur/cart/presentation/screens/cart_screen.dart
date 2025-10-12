import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItemsAsync = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: cartItemsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.refresh(cartProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (cartItems) {
          if (cartItems.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Keranjang kosong',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // ✅ ITEM IMAGE DENGAN SUPPORT SHORTS THUMBNAIL
                            _buildItemImage(context, item),
                            const SizedBox(width: 16),

                            // Item details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Penjual: ${item.sellerUsername}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    NumberFormat.currency(
                                      locale: 'id_ID',
                                      symbol: 'Rp ',
                                      decimalDigits: 0,
                                    ).format(item.price),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Quantity controls
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: item.quantity > 1
                                            ? () => cartNotifier.updateQuantity(
                                            item.id,
                                            item.quantity - 1
                                        )
                                            : null,
                                        icon: const Icon(Icons.remove_circle_outline),
                                        iconSize: 20,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => cartNotifier.updateQuantity(
                                            item.id,
                                            item.quantity + 1
                                        ),
                                        icon: const Icon(Icons.add_circle_outline),
                                        iconSize: 20,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Delete button
                            IconButton(
                              onPressed: () => _showDeleteConfirmation(
                                context,
                                cartNotifier,
                                item.id,
                                item.title,
                              ),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ✅ BOTTOM CHECKOUT SECTION DENGAN CEK SALDO
              _buildCheckoutSection(context, cartItems, cartNotifier),
            ],
          );
        },
      ),
    );
  }

  // ✅ BUILD ITEM IMAGE DENGAN SUPPORT SHORTS THUMBNAIL
  Widget _buildItemImage(BuildContext context, item) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('posts').doc(item.postId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final postData = snapshot.data!.data() as Map<String, dynamic>?;
        final postType = postData?['type']?.toString() ?? '';
        final videoUrl = postData?['videoUrl'] as String?;
        final imageUrls = postData?['imageUrls'] as List<dynamic>?;

        // ✅ JIKA POST ADALAH SHORTS DAN ADA VIDEO
        if (postType.contains('short') && videoUrl != null && videoUrl.isNotEmpty) {
          return _buildShortsVideoThumbnail(videoUrl);
        }

        // ✅ JIKA ADA IMAGE URL DARI ITEM ATAU POST
        String? imageUrl = item.imageUrl;
        if ((imageUrl == null || imageUrl.isEmpty) && imageUrls != null && imageUrls.isNotEmpty) {
          imageUrl = imageUrls.first as String?;
        }

        return _buildRegularImage(imageUrl);
      },
    );
  }

  // ✅ BUILD SHORTS VIDEO THUMBNAIL (INSPIRASI DARI PROFILE_SCREEN)
  Widget _buildShortsVideoThumbnail(String videoUrl) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Video placeholder/thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 80,
              color: Colors.grey[800],
              child: const Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          // Overlay shorts indicator
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Shorts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ BUILD REGULAR IMAGE
  Widget _buildRegularImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || !_isValidUrl(imageUrl)) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.shopping_bag,
          color: Colors.grey,
          size: 32,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 80,
          height: 80,
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 32,
          ),
        ),
      ),
    );
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ✅ CHECKOUT SECTION DENGAN CEK SALDO
  Widget _buildCheckoutSection(BuildContext context, List cartItems, cartNotifier) {
    final totalAmount = cartItems.fold<double>(
      0,
          (sum, item) => sum + (item.price * item.quantity),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(totalAmount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: cartItems.isNotEmpty
                  ? () => _processCheckout(context, cartItems, totalAmount, cartNotifier)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Bayar Semua (${NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(totalAmount)})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ PROCESS CHECKOUT DENGAN CEK SALDO
  Future<void> _processCheckout(BuildContext context, List cartItems, double totalAmount, cartNotifier) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda harus login terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userBalance = (userDoc.data()?['saldo'] as num?)?.toDouble() ?? 0.0;

      if (userBalance < totalAmount) {
        // ✅ SALDO TIDAK MENCUKUPI
        _showInsufficientBalanceDialog(context, totalAmount, userBalance);
        return;
      }

      // ✅ SALDO MENCUKUPI, PROSES CHECKOUT
      await _createCartTransaction(cartItems, totalAmount, user.uid);

      // ✅ KURANGI SALDO USER
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'balance': FieldValue.increment(-totalAmount),
      });

      // ✅ HAPUS SEMUA ITEM DARI CART
      for (final item in cartItems) {
        cartNotifier.removeFromCart(item.id);
      }

      // ✅ TAMPILKAN POPUP SUKSES
      _showCartCheckoutSuccessDialog(context, totalAmount);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses checkout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ CREATE INTERESTED ORDERS DARI CART (BUKAN LANGSUNG PAID)
  Future<void> _createCartTransaction(List cartItems, double totalAmount, String userId) async {
    // Group items by seller untuk membuat transaksi per penjual
    final Map<String, List> itemsBySeller = {};

    for (final item in cartItems) {
      if (!itemsBySeller.containsKey(item.sellerId)) {
        itemsBySeller[item.sellerId] = [];
      }
      itemsBySeller[item.sellerId]!.add(item);
    }

    // ✅ BUAT INTERESTED ORDER UNTUK SETIAP PENJUAL
    for (final sellerId in itemsBySeller.keys) {
      final sellerItems = itemsBySeller[sellerId]!;
      final sellerTotal = sellerItems.fold<double>(
        0,
            (sum, item) => sum + (item.price * item.quantity),
      );

      await FirebaseFirestore.instance.collection('transactions').add({
        'buyerId': userId,
        'sellerId': sellerId,
        'amount': sellerTotal,
        'status': 'pending', // ✅ STATUS PENDING = INTERESTED
        'createdAt': FieldValue.serverTimestamp(),
        'items': sellerItems.map((item) => {
          'postId': item.postId,
          'title': item.title,
          'price': item.price,
          'quantity': item.quantity,
          'imageUrl': item.imageUrl,
        }).toList(),
        'isEscrow': true,
        'escrowAmount': sellerTotal,
        'isAcceptedBySeller': false, // ✅ BELUM DITERIMA PENJUAL
        'type': 'cart_checkout',
      });
    }
  }

// ✅ GANTI DIALOG SUCCESS UNTUK CART
  void _showCartCheckoutSuccessDialog(BuildContext context, double totalAmount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pesanan Berhasil Dibuat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_send,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Semua pesanan telah dikirim ke penjual!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keranjang telah dikosongkan',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: const [
                  Text(
                    '🔒 Saldo telah dipotong dan disimpan aman',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Menunggu persetujuan penjual',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/transaction-history');
            },
            child: const Text('Lihat Status Pesanan'),
          ),
        ],
      ),
    );
  }


  // ✅ DIALOG SALDO TIDAK MENCUKUPI (SAMA SEPERTI POST DETAIL)
  void _showInsufficientBalanceDialog(BuildContext context, double totalAmount, double userBalance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saldo Tidak Mencukupi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Saldo Anda: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(userBalance)}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Total yang dibutuhkan: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Kurang: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount - userBalance)}',
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to top-up page
              context.push('/topup');
            },
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
  }

  // ✅ DIALOG CHECKOUT BERHASIL
  // void _showCartCheckoutSuccessDialog(BuildContext context, double totalAmount) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Checkout Berhasil'),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           const Icon(
  //             Icons.check_circle,
  //             size: 64,
  //             color: Colors.green,
  //           ),
  //           const SizedBox(height: 16),
  //           const Text(
  //             'Semua item berhasil dibeli!',
  //             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //           ),
  //           const SizedBox(height: 8),
  //           Text(
  //             'Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount)}',
  //             style: const TextStyle(fontSize: 16),
  //           ),
  //           const SizedBox(height: 8),
  //           const Text(
  //             'Keranjang telah dikosongkan',
  //             style: TextStyle(fontSize: 14, color: Colors.grey),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         ElevatedButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             context.push('/transaction-history');
  //           },
  //           child: const Text('Lihat Riwayat'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _showDeleteConfirmation(
      BuildContext context,
      cartNotifier,
      String itemId,
      String itemTitle,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Item'),
        content: Text('Apakah Anda yakin ingin menghapus "$itemTitle" dari keranjang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              cartNotifier.removeFromCart(itemId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Item dihapus dari keranjang'),
                  backgroundColor: Colors.red,
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
}
