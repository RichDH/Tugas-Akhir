import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/cart_item.dart';

// Tetap sama: provider publik
final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<List<CartItem>>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<AsyncValue<List<CartItem>>> {
  CartNotifier() : super(const AsyncValue.loading()) {
    _subscribeCart(); // ganti dari sekali get() menjadi stream subscription
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cartSub;

  // Mengganti _loadCart() dengan stream subscription realtime
  void _subscribeCart() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      state = const AsyncValue.data([]);
      return;
    }

    // Dengarkan perubahan koleksi cart user
    _cartSub?.cancel();
    _cartSub = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('cart')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      try {
        // Untuk setiap item di cart, cek post terkait → filter deleted
        final filtered = <CartItem>[];
        for (final doc in snapshot.docs) {
          final item = CartItem.fromFirestore(doc);
          if (item.postId == null || item.postId.isEmpty) {
            // Jika tidak ada postId, abaikan item
            continue;
          }

          final postDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(item.postId)
              .get();

          final isValid = postDoc.exists && (postDoc.data()?['deleted'] != true);
          if (isValid) {
            filtered.add(item);
          } else {
            // Opsional: sinkron bersihkan item invalid yang masih tertinggal
            // await doc.reference.delete();
          }
        }

        state = AsyncValue.data(filtered);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    }, onError: (e, st) {
      state = AsyncValue.error(e, st);
    });
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    super.dispose();
  }

  // —————— ACTIONS tetap sama ——————

  Future<void> addToCart(CartItem item) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Cek apakah item sudah ada di cart (berdasar postId)
      final existingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cart')
          .where('postId', isEqualTo: item.postId)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        final doc = existingSnapshot.docs.first;
        final existingItem = CartItem.fromFirestore(doc);
        await doc.reference.update({
          'quantity': existingItem.quantity + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('cart')
            .add({
          ...item.toFirestore(),
          'addedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // Tidak perlu _loadCart(); stream akan mengalir otomatis
    } catch (e) {
      print('Error adding to cart: $e');
    }
  }

  Future<void> removeFromCart(String cartItemId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cart')
          .doc(cartItemId)
          .delete();
      // Stream akan update otomatis
    } catch (e) {
      print('Error removing from cart: $e');
    }
  }

  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      if (newQuantity <= 0) {
        await removeFromCart(cartItemId);
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cart')
          .doc(cartItemId)
          .update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Stream akan update otomatis
    } catch (e) {
      print('Error updating quantity: $e');
    }
  }

  Future<void> clearCart() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cart')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      // Stream akan update otomatis
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }
}
