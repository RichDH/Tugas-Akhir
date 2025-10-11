import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:program/fitur/cart/presentation/providers/cart_provider.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import '../../domain/entities/cart_item.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang')),
      body: cartAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Keranjang kosong'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _CartItemTile(
                item: item,
                onRemove: () => ref.read(cartProvider.notifier).removeFromCart(item.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: cartAsync.when(
        data: (items) {
          if (items.isEmpty) return const SizedBox();
          final total = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
          return Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => _checkout(context, ref, items),
              child: Text('Bayar Semua (Rp ${total.toStringAsFixed(0)})'),
            ),
          );
        },
        loading: () => const SizedBox(),
        error: (e, s) => const SizedBox(),
      ),
    );
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref, List<CartItem> items) async {
    final sellers = <String, List<CartItem>>{};
    for (var item in items) {
      sellers.putIfAbsent(item.sellerId, () => []).add(item);
    }

    List<String> createdTransactionIds = [];

    for (var entry in sellers.entries) {
      final sellerId = entry.key;
      final sellerItems = entry.value;
      final totalAmount = sellerItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

      // Buat transaksi dan simpan ID-nya
      final transactionId = await ref.read(transactionProvider.notifier).createTransactionAndGetId(
        postId: sellerItems[0].postId, // Ambil postId pertama sebagai representasi
        buyerId: FirebaseAuth.instance.currentUser!.uid,
        sellerId: sellerId,
        amount: totalAmount,
        isEscrow: true,
        escrowAmount: totalAmount,
      );

      if (transactionId != null) {
        createdTransactionIds.add(transactionId);
      }
    }

    ref.read(cartProvider.notifier).clearCart();
    _showSuccessDialog(context, 'Transaksi berhasil dibuat!\nSilakan tunggu konfirmasi dari jastiper.');

    // ✅ Arahkan ke riwayat transaksi (lebih aman)
    await Future.delayed(const Duration(milliseconds: 1500));
    if (context.mounted) {
      GoRouter.of(context).push('/transaction-history');
    }
    // Jika ingin ke detail transaksi pertama:
    // if (createdTransactionIds.isNotEmpty) {
    //   GoRouter.of(context).push('/transaction-detail/${createdTransactionIds[0]}');
    // } else {
    //   Navigator.pop(context);
    // }

    // Untuk skripsi, lebih baik ke halaman riwayat
    Navigator.pop(context);
  }

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
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;

  const _CartItemTile({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.network(item.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Rp ${item.price.toStringAsFixed(0)}'),
                  Text('Qty: ${item.quantity}'),
                  if (item.deadline != null)
                    Text(
                      'Deadline: ${DateFormat('dd/MM/yyyy HH:mm').format(item.deadline!.toDate())}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.delete), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}