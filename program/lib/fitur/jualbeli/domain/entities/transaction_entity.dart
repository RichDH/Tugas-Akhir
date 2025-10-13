// File: transaction_entity.dart - DIPERBAIKI
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionStatus { pending, paid, shipped, delivered, completed, refunded }

class Transaction extends Equatable {
  final String id;
  final String postId;
  final String buyerId;
  final String sellerId;
  final double amount;
  final TransactionStatus status;
  final Timestamp createdAt;
  final Timestamp? shippedAt;
  final Timestamp? deliveredAt;
  final Timestamp? completedAt;
  final String? refundReason;
  final bool isEscrow;
  final double escrowAmount;
  final Timestamp? releaseToSellerAt;
  final bool isAcceptedBySeller;
  final String? rejectionReason;
  final int? rating;
  final String? buyerAddress; // ✅ TAMBAHAN: Alamat pembeli

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
    this.completedAt,
    this.refundReason,
    required this.isEscrow,
    required this.escrowAmount,
    this.releaseToSellerAt,
    this.isAcceptedBySeller = false,
    this.rejectionReason,
    this.rating,
    this.buyerAddress, // ✅ TAMBAHAN
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
      completedAt: data['completedAt'] as Timestamp?,
      refundReason: data['refundReason'] as String?,
      isEscrow: data['isEscrow'] as bool,
      escrowAmount: (data['escrowAmount'] as num).toDouble(),
      releaseToSellerAt: data['releaseToSellerAt'] as Timestamp?,
      isAcceptedBySeller: data['isAcceptedBySeller'] as bool? ?? false,
      rejectionReason: data['rejectionReason'] as String?,
      rating: data['rating'] as int?,
      buyerAddress: data['buyerAddress'] as String?, // ✅ TAMBAHAN
    );
  }

  static TransactionStatus _parseStatus(String status) {
    switch (status) {
      case 'paid': return TransactionStatus.paid;
      case 'shipped': return TransactionStatus.shipped;
      case 'delivered': return TransactionStatus.delivered;
      case 'completed': return TransactionStatus.completed; // ✅ TAMBAHAN
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
      'completedAt': completedAt,
      'refundReason': refundReason,
      'isEscrow': isEscrow,
      'escrowAmount': escrowAmount,
      'releaseToSellerAt': releaseToSellerAt,
      'isAcceptedBySeller': isAcceptedBySeller,
      'rejectionReason': rejectionReason,
      'rating': rating,
      'buyerAddress': buyerAddress, // ✅ TAMBAHAN
    };
  }

  @override
  List<Object?> get props => [
    id, postId, buyerId, sellerId, amount, status, createdAt, shippedAt, deliveredAt, completedAt,
    refundReason, isEscrow, escrowAmount, releaseToSellerAt, isAcceptedBySeller, rejectionReason, rating, buyerAddress
  ];
}
