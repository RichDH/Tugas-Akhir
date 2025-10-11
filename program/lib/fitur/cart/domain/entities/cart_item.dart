import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem extends Equatable {
  final String id;
  final String postId;
  final String title;
  final double price;
  final String imageUrl;
  final String sellerId;
  final String sellerUsername;
  final Timestamp addedAt;
  final Timestamp? deadline;
  final int quantity;

  const CartItem({
    required this.id,
    required this.postId,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.sellerId,
    required this.sellerUsername,
    required this.addedAt,
    this.deadline,
    this.quantity = 1,
  });

  factory CartItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CartItem(
      id: doc.id,
      postId: data['postId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      price: _parseDouble(data['price']) ?? 0.0, // ✅ SAFE PARSING
      imageUrl: data['imageUrl'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      sellerUsername: data['sellerUsername'] as String? ?? '',
      addedAt: data['addedAt'] as Timestamp? ?? Timestamp.now(),
      deadline: data['deadline'] as Timestamp?,
      quantity: data['quantity'] as int? ?? 1,
    );
  }

  // ✅ SAFE DOUBLE PARSING
  static double? _parseDouble(dynamic value) {
    if (value == null) return 0.0; // ✅ DEFAULT 0 INSTEAD OF NULL
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.trim().isEmpty) return 0.0;
      return double.tryParse(value.replaceAll(',', '').replaceAll('Rp', '').trim()) ?? 0.0;
    }
    return 0.0; // ✅ FALLBACK KE 0
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'title': title,
      'price': price,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
      'sellerUsername': sellerUsername,
      'addedAt': addedAt,
      'deadline': deadline,
      'quantity': quantity,
    };
  }

  CartItem copyWith({
    String? id,
    String? postId,
    String? title,
    double? price,
    String? imageUrl,
    String? sellerId,
    String? sellerUsername,
    Timestamp? addedAt,
    Timestamp? deadline,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      title: title ?? this.title,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerId: sellerId ?? this.sellerId,
      sellerUsername: sellerUsername ?? this.sellerUsername,
      addedAt: addedAt ?? this.addedAt,
      deadline: deadline ?? this.deadline,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [
    id, postId, title, price, imageUrl, sellerId,
    sellerUsername, addedAt, deadline, quantity,
  ];
}
