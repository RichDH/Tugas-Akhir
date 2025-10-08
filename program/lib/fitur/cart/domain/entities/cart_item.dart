import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class CartItem extends Equatable {
  final String postId;
  final String title;
  final double price;
  final String imageUrl;
  final String sellerId;
  final Timestamp addedAt;
  final int quantity;
  final String? notes;
  final Timestamp? deadline;

  const CartItem({
    required this.postId,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.sellerId,
    required this.addedAt,
    this.quantity = 1,
    this.notes,
    this.deadline,
  });

  factory CartItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CartItem(
      postId: data['postId'] as String,
      title: data['title'] as String,
      price: (data['price'] as num).toDouble(),
      imageUrl: data['imageUrl'] as String,
      sellerId: data['sellerId'] as String,
      addedAt: data['addedAt'] as Timestamp,
      quantity: data['quantity'] as int? ?? 1,
      notes: data['notes'] as String?,
      deadline: data['deadline'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'title': title,
      'price': price,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
      'addedAt': addedAt,
      'quantity': quantity,
      'notes': notes,
      'deadline': deadline,
    };
  }

  @override
  List<Object?> get props => [postId, title, price, imageUrl, sellerId, addedAt, quantity, notes, deadline];
}