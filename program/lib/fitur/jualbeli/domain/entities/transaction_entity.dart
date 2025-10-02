import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionStatus { pending, paid, shipped, delivered, refunded }

class Transaction extends Equatable {
  final String id;
  final String postId;
  final String buyerId;
  final String sellerId;
  final double amount; // Jumlah dana yang ditransfer
  final TransactionStatus status;
  final Timestamp createdAt;
  final Timestamp? shippedAt;
  final Timestamp? deliveredAt;
  final String? refundReason;
  final bool isEscrow; // Dana ditahan di sistem
  final double escrowAmount; // Jumlah yang ditahan
  final Timestamp? releaseToSellerAt; // Waktu dana dicairkan ke seller

  const Transaction({
    required this.id,
    required this.postId,
    required this.buyerId,
    required this.sellerId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.shippedAt,
    this.deliveredAt,
    this.refundReason,
    required this.isEscrow,
    required this.escrowAmount,
    this.releaseToSellerAt,
  });

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      postId: data['postId'] as String,
      buyerId: data['buyerId'] as String,
      sellerId: data['sellerId'] as String,
      amount: (data['amount'] as num).toDouble(),
      status: _parseStatus(data['status'] as String),
      createdAt: data['createdAt'] as Timestamp,
      shippedAt: data['shippedAt'] as Timestamp?,
      deliveredAt: data['deliveredAt'] as Timestamp?,
      refundReason: data['refundReason'] as String?,
      isEscrow: data['isEscrow'] as bool,
      escrowAmount: (data['escrowAmount'] as num).toDouble(),
      releaseToSellerAt: data['releaseToSellerAt'] as Timestamp?,
    );
  }

  static TransactionStatus _parseStatus(String status) {
    switch (status) {
      case 'paid': return TransactionStatus.paid;
      case 'shipped': return TransactionStatus.shipped;
      case 'delivered': return TransactionStatus.delivered;
      case 'refunded': return TransactionStatus.refunded;
      default: return TransactionStatus.pending;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'amount': amount,
      'status': status.toString().split('.').last,
      'createdAt': createdAt,
      'shippedAt': shippedAt,
      'deliveredAt': deliveredAt,
      'refundReason': refundReason,
      'isEscrow': isEscrow,
      'escrowAmount': escrowAmount,
      'releaseToSellerAt': releaseToSellerAt,
    };
  }

  @override
  List<Object?> get props => [
    id, postId, buyerId, sellerId, amount, status, createdAt, shippedAt, deliveredAt,
    refundReason, isEscrow, escrowAmount, releaseToSellerAt
  ];
}