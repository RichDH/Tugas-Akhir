// File: lib/fitur/post/presentation/widgets/take_order_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/post/presentation/providers/offer_provider.dart';

class TakeOrderDialog extends ConsumerStatefulWidget {
  final Post post;

  const TakeOrderDialog({super.key, required this.post});

  @override
  ConsumerState<TakeOrderDialog> createState() => _TakeOrderDialogState();
}

class _TakeOrderDialogState extends ConsumerState<TakeOrderDialog> {
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null) {
      return AlertDialog(
        title: const Text('Error'),
        content: const Text('Anda harus login terlebih dahulu'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Ambil Pesanan'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request: ${widget.post.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (widget.post.price != null)
              Text(
                'Budget: Rp ${NumberFormat.currency(locale: 'id', symbol: '').format(widget.post.price)}',
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Harga Tawaran Anda',
                hintText: 'Masukkan harga yang Anda tawarkan',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Harga tidak boleh kosong';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Harga harus lebih dari 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catatan:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Tawaran Anda akan dikirim ke pemilik request\n'
                        '• Jika diterima, transaksi akan otomatis dibuat\n'
                        '• Pastikan harga yang Anda tawarkan sesuai',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        Consumer(
          builder: (context, ref, _) {
            final offerState = ref.watch(offerProvider);

            return offerState.when(
              data: (_) => ElevatedButton(
                onPressed: _submitOffer,
                child: const Text('Kirim Tawaran'),
              ),
              loading: () => const ElevatedButton(
                onPressed: null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Mengirim...'),
                  ],
                ),
              ),
              error: (error, _) => ElevatedButton(
                onPressed: _submitOffer,
                child: const Text('Kirim Tawaran'),
              ),
            );
          },
        ),
      ],
    );
  }

  void _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(firebaseAuthProvider).currentUser!;
    final offerPrice = double.parse(_priceController.text);

    try {
      // ✅ AMBIL USERNAME DARI FIRESTORE
      final username = await _getUsernameFromFirestore(currentUser.uid);

      await ref.read(offerProvider.notifier).createOffer(
        postId: widget.post.id,
        postTitle: widget.post.title,
        offererId: currentUser.uid,
        offererUsername: username, // ✅ GUNAKAN USERNAME DARI DATABASE
        postOwnerId: widget.post.userId,
        offerPrice: offerPrice,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tawaran berhasil dikirim!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// ✅ METHOD UNTUK MENGAMBIL USERNAME DARI FIRESTORE
  Future<String> _getUsernameFromFirestore(String userId) async {
    try {
      final firestore = ref.read(firebaseFirestoreProvider);
      final userDoc = await firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        return userData?['username'] as String? ?? 'Unknown User';
      }
      return 'Unknown User';
    } catch (e) {
      print('Error getting username: $e');
      return 'Unknown User';
    }
  }
}
