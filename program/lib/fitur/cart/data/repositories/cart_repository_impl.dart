import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:program/fitur/cart/domain/entities/cart_item.dart';
import 'package:program/fitur/cart/domain/repositories/cart_repository.dart';

class CartRepositoryImpl implements CartRepository {
  final FirebaseFirestore _firestore;

  CartRepositoryImpl(this._firestore);

  @override
  Future<void> addToCart(CartItem item) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');
    await _firestore.collection('users').doc(userId).collection('cart').doc(item.postId).set(item.toFirestore());
  }

  @override
  Future<void> removeFromCart(String postId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not logged in');
    await _firestore.collection('users').doc(userId).collection('cart').doc(postId).delete();
  }

  @override
  Stream<List<CartItem>> getCartItems(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('cart')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CartItem.fromFirestore(doc)).toList());
  }

  @override
  Future<void> clearCart(String userId) async {
    final batch = _firestore.batch();
    final cartSnapshot = await _firestore.collection('users').doc(userId).collection('cart').get();
    for (var doc in cartSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}