import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:program/fitur/promo/presentation/providers/admin_promo_provider.dart';
import '../providers/cart_provider.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    // Auto-validate cart items saat screen dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateCartItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartItemsAsync = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Tombol refresh manual
          IconButton(
            onPressed: _isValidating ? null : () => _validateCartItems(),
            icon: _isValidating
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.refresh),
            tooltip: 'Perbarui Keranjang',
          ),
        ],
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

    // Ambil promo aktif
    final promosAsync = ref.watch(activePromosProvider);

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
      child: promosAsync.when(
        loading: () => _checkoutBlock(context, totalAmount, cartItems, cartNotifier, null),
        error: (e, s) => _checkoutBlock(context, totalAmount, cartItems, cartNotifier, null),
        data: (promos) {
          // Pilih promo terbaik yang memenuhi syarat
          final now = DateTime.now();
          final eligiblePromos = promos.where((p) {
            final withinPeriod = now.isAfter(p.startDate) && now.isBefore(p.endDate);
            return p.isActive && withinPeriod && totalAmount >= p.minimumTransaction;
          }).toList()
            ..sort((a, b) => b.discountAmount.compareTo(a.discountAmount)); // pilih potongan terbesar

          final bestPromo = eligiblePromos.isNotEmpty ? eligiblePromos.first : null;
          return _checkoutBlock(context, totalAmount, cartItems, cartNotifier, bestPromo);
        },
      ),
    );
  }

  Widget _checkoutBlock(BuildContext context, double totalAmount, List cartItems, cartNotifier, dynamic bestPromo) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final discount = bestPromo?.discountAmount ?? 0.0;
    final payable = (totalAmount - discount).clamp(0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info total + promo
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(formatter.format(totalAmount),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        if (bestPromo != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Anda mendapat promo "${bestPromo.name}" - Potongan ${formatter.format(bestPromo.discountAmount)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Payable
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Dibayar:', style: TextStyle(fontSize: 14)),
            Text(formatter.format(payable), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: cartItems.isNotEmpty && !_isValidating
                ? () => _processCheckout(context, cartItems, totalAmount, cartNotifier, bestPromo)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              bestPromo == null
                  ? 'Bayar Semua (${formatter.format(totalAmount)})'
                  : 'Bayar Semua (${formatter.format(payable)})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }


  // ✅ VALIDASI CART ITEMS DARI POST YANG SUDAH DI-DELETE
  Future<void> _validateCartItems() async {
    if (_isValidating) return;

    setState(() {
      _isValidating = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isValidating = false;
        });
        return;
      }

      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart');

      final cartSnapshot = await cartRef.get();
      List<String> invalidItemIds = [];
      List<String> invalidItemNames = [];

      for (final cartDoc in cartSnapshot.docs) {
        final cartItem = cartDoc.data();
        final postId = cartItem['postId'] as String?;

        if (postId != null) {
          final postDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .get();

          // Cek apakah post sudah tidak ada atau di-soft delete
          if (!postDoc.exists || postDoc.data()?['deleted'] == true) {
            invalidItemIds.add(cartDoc.id);
            invalidItemNames.add(cartItem['title'] ?? 'Item tidak diketahui');
          }
        }
      }

      // Hapus item yang tidak valid
      if (invalidItemIds.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final itemId in invalidItemIds) {
          batch.delete(cartRef.doc(itemId));
        }
        await batch.commit();

        // Refresh cart provider
        ref.refresh(cartProvider);

        // Tampilkan notifikasi
        if (mounted) {
          _showInvalidItemsRemovedDialog(context, invalidItemNames);
        }
      }
    } catch (e) {
      print('Error validating cart items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memvalidasi keranjang: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  // ✅ DIALOG UNTUK MENAMPILKAN ITEM YANG DIHAPUS
  void _showInvalidItemsRemovedDialog(BuildContext context, List<String> removedItems) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Barang Tidak Tersedia'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Barang berikut sudah tidak tersedia dan telah dihapus dari keranjang:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...removedItems.take(3).map((itemName) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.close, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      itemName,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
            if (removedItems.length > 3)
              Text(
                'dan ${removedItems.length - 3} item lainnya...',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ✅ PROCESS CHECKOUT DENGAN VALIDASI TAMBAHAN (DIPERBAIKI)
  // ✅ PROCESS CHECKOUT DENGAN VALIDASI TAMBAHAN (DIPERBAIKI - CLEAR CART ATOMIC)
  Future<void> _processCheckout(BuildContext context, List cartItems, double totalAmount, cartNotifier, dynamic bestPromo) async {
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

      // ✅ VALIDASI ULANG SEBELUM CHECKOUT
      await _validateCartItems();

      // ✅ AMBIL CART ITEMS TERBARU SETELAH VALIDASI
      final cartItemsAsyncValue = ref.read(cartProvider);

      // Cek jika masih loading
      if (cartItemsAsyncValue.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sedang memvalidasi keranjang...'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Cek jika ada error
      if (cartItemsAsyncValue.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${cartItemsAsyncValue.error}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final currentCartItems = cartItemsAsyncValue.value;

      // Null check untuk currentCartItems
      if (currentCartItems == null || currentCartItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keranjang kosong setelah pengecekan barang'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Hitung ulang total setelah validasi dengan null safety
      final validTotalAmount = currentCartItems.fold<double>(
        0,
            (sum, item) {
          if (item != null) {
            return sum + (item.price * item.quantity);
          }
          return sum;
        },
      );
      final discount = (bestPromo?.discountAmount ?? 0.0);
      final payable = (validTotalAmount - discount).clamp(0, double.infinity);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userBalance = (userDoc.data()?['saldo'] as num?)?.toDouble() ?? 0.0;

      if (userBalance < payable) {
        _showInsufficientBalanceDialog(context, validTotalAmount, userBalance);
        return;
      }

      await _createCartTransaction(currentCartItems, validTotalAmount, user.uid, bestPromo: bestPromo);

      // ✅ KURANGI SALDO USER
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'saldo': FieldValue.increment(-payable),
      });

      // ✅ PERBAIKAN: GUNAKAN clearCart() UNTUK HAPUS SEMUA ITEM SEKALIGUS
      // Ini lebih aman dan atomic daripada loop removeFromCart satu per satu
      await cartNotifier.clearCart();

      _showCartCheckoutSuccessDialog(context, validTotalAmount);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses checkout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<void> _createCartTransaction(List cartItems, double totalAmount, String userId, {dynamic bestPromo}) async {
    // Group items by seller untuk membuat transaksi per penjual
    final Map<String, List> itemsBySeller = {};

    for (final item in cartItems) {
      if (item?.sellerId != null) {
        if (!itemsBySeller.containsKey(item.sellerId)) {
          itemsBySeller[item.sellerId] = [];
        }
        itemsBySeller[item.sellerId]!.add(item);
      }
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userAddress = userDoc.data()?['alamat'] as String? ?? 'Alamat tidak tersedia';

    // ✅ HITUNG TOTAL DISCOUNT YANG HARUS DITANGGUNG ADMIN
    final totalDiscount = bestPromo?.discountAmount ?? 0.0;

    // ✅ GUNAKAN BATCH TRANSACTION UNTUK ATOMICITY
    final batch = FirebaseFirestore.instance.batch();

    // Buat transaksi untuk setiap penjual
    for (final sellerId in itemsBySeller.keys) {
      final sellerItems = itemsBySeller[sellerId]!;
      final sellerTotal = sellerItems.fold<double>(
        0,
            (sum, item) => sum + (item?.price ?? 0) * (item?.quantity ?? 1),
      );

      // Proporsi diskon untuk seller ini
      final discountPerSeller = totalDiscount * (sellerTotal / totalAmount);
      final appliedDiscount = double.parse(discountPerSeller.toStringAsFixed(0));

      final transactionRef = FirebaseFirestore.instance.collection('transactions').doc();
      batch.set(transactionRef, {
        'buyerId': userId,
        'sellerId': sellerId,
        'amount': sellerTotal,
        'paidAmount': sellerTotal - appliedDiscount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'buyerAddress': userAddress,
        'items': sellerItems.map((item) => {
          'postId': item?.postId ?? '',
          'title': item?.title ?? '',
          'price': item?.price ?? 0,
          'quantity': item?.quantity ?? 1,
          'imageUrl': item?.imageUrl ?? '',
        }).toList(),
        'isEscrow': true,
        'escrowAmount': sellerTotal,
        'isAcceptedBySeller': false,
        'type': 'cart_checkout',
        if (bestPromo != null) 'promoId': bestPromo.id,
        if (bestPromo != null) 'promoName': bestPromo.name,
        if (bestPromo != null) 'promoDiscount': appliedDiscount,
      });
    }

    // ✅ KURANGI SALDO ADMIN JIKA ADA PROMO
    if (bestPromo != null && totalDiscount > 0) {
      // Cari dokumen admin (asumsi admin@gmail.com)
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: 'admin@gmail.com')
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        final adminDocRef = adminQuery.docs.first.reference;
        batch.update(adminDocRef, {
          'saldo': FieldValue.increment(-totalDiscount),
        });

        // ✅ LOG PENGGUNAAN PROMO UNTUK AUDIT
        final promoLogRef = FirebaseFirestore.instance.collection('promo_usage_logs').doc();
        batch.set(promoLogRef, {
          'promoId': bestPromo.id,
          'promoName': bestPromo.name,
          'discountAmount': totalDiscount,
          'buyerId': userId,
          'totalTransactionAmount': totalAmount,
          'usedAt': FieldValue.serverTimestamp(),
          'transactionType': 'cart_checkout',
        });
      }
    }

    // ✅ COMMIT SEMUA DALAM SATU TRANSAKSI ATOMIK
    await batch.commit();
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
              child: const Column(
                children: [
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
              context.push('/topup');
            },
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
  }

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
