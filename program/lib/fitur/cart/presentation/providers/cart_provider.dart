import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/cart/data/repositories/cart_repository_impl.dart';
import 'package:program/fitur/cart/domain/entities/cart_item.dart';
import 'package:program/fitur/cart/domain/repositories/cart_repository.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return CartRepositoryImpl(firestore);
});

class CartNotifier extends StateNotifier<AsyncValue<List<CartItem>>> {
  final CartRepository _repository;
  final String _userId;

  CartNotifier(this._repository, this._userId) : super(const AsyncLoading()) {
    _loadCart();
  }

  Future<void> _loadCart() async {
    try {
      // Load sekali saja
      final items = await _repository.getCartItems(_userId).first;
      state = AsyncData(items);

    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> addToCart(CartItem item) async {
    try {
      await _repository.addToCart(item);
      // Setelah add, reload cart
      final items = await _repository.getCartItems(_userId).first;
      state = AsyncData(items);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> removeFromCart(String postId) async {
    try {
      await _repository.removeFromCart(postId);
      // Setelah remove, reload cart
      final items = await _repository.getCartItems(_userId).first;
      state = AsyncData(items);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> clearCart() async {
    try {
      await _repository.clearCart(_userId);
      state = AsyncData([]);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<List<CartItem>>>((ref) {
  final repository = ref.watch(cartRepositoryProvider);
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  return CartNotifier(repository, userId);
});