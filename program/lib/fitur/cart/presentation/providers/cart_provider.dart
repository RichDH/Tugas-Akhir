import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/cart_item.dart';

final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<List<CartItem>>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<AsyncValue<List<CartItem>>> {
  CartNotifier() : super(const AsyncValue.loading()) {
    _loadCart();
  }

  void _loadCart() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cart')
          .orderBy('addedAt', descending: true)
          .get();

      final cartItems = snapshot.docs.map((doc) => CartItem.fromFirestore(doc)).toList();
      state = AsyncValue.data(cartItems);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addToCart(CartItem item) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Cek apakah item sudah ada di cart
      final existingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cart')
          .where('postId', isEqualTo: item.postId)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        // Update quantity jika sudah ada
        final doc = existingSnapshot.docs.first;
        final existingItem = CartItem.fromFirestore(doc);
        await doc.reference.update({
          'quantity': existingItem.quantity + 1,
        });
      } else {
        // ✅ TAMBAH ITEM BARU TANPA MANUAL ID
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('cart')
            .add(item.toFirestore()); // ✅ FIRESTORE AUTO-GENERATE ID
      }

      _loadCart(); // Reload cart
    } catch (e) {
      print('Error adding to cart: $e');
    }
  }

  // ✅ REMOVE BY CART ITEM ID (BUKAN POST ID)
  Future<void> removeFromCart(String cartItemId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cart')
          .doc(cartItemId) // ✅ GUNAKAN CART ITEM ID
          .delete();

      _loadCart(); // Reload cart
    } catch (e) {
      print('Error removing from cart: $e');
    }
  }

  // ✅ UPDATE BY CART ITEM ID (BUKAN POST ID)
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
          .doc(cartItemId) // ✅ GUNAKAN CART ITEM ID
          .update({'quantity': newQuantity});

      _loadCart(); // Reload cart
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

      _loadCart(); // Reload cart
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }
}
