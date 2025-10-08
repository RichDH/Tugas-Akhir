import '../entities/cart_item.dart';

abstract class CartRepository {
  Future<void> addToCart(CartItem item);
  Future<void> removeFromCart(String postId);
  Stream<List<CartItem>> getCartItems(String userId);
  Future<void> clearCart(String userId);
}