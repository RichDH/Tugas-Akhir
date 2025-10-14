// File: transaction_entity.dart - PERBAIKAN NULL SAFETY
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
  final String? buyerAddress;

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
    this.buyerAddress,
  });

  // ✅ PERBAIKAN: Null safety yang lebih baik
  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // Validasi data tidak null
    if (data == null) {
      throw Exception('Data transaksi kosong untuk ID: ${doc.id}');
    }

    return Transaction(
      id: doc.id,
      postId: data['postId']?.toString() ?? '', // ✅ Safe cast dengan fallback
      buyerId: data['buyerId']?.toString() ?? '',
      sellerId: data['sellerId']?.toString() ?? '',
      amount: _parseDouble(data['amount']),
      status: _parseStatus(data['status']?.toString()),
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      shippedAt: data['shippedAt'] as Timestamp?,
      deliveredAt: data['deliveredAt'] as Timestamp?,
      completedAt: data['completedAt'] as Timestamp?,
      refundReason: data['refundReason']?.toString(),
      isEscrow: data['isEscrow'] as bool? ?? false,
      escrowAmount: _parseDouble(data['escrowAmount']),
      releaseToSellerAt: data['releaseToSellerAt'] as Timestamp?,
      isAcceptedBySeller: data['isAcceptedBySeller'] as bool? ?? false,
      rejectionReason: data['rejectionReason']?.toString(),
      rating: data['rating'] as int?,
      buyerAddress: data['buyerAddress']?.toString(),
    );
  }

  // ✅ Helper method untuk parsing double yang aman
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // ✅ Helper method untuk parsing status yang aman
  static TransactionStatus _parseStatus(String? status) {
    if (status == null) return TransactionStatus.pending;

    switch (status.toLowerCase()) {
      case 'paid': return TransactionStatus.paid;
      case 'shipped': return TransactionStatus.shipped;
      case 'delivered': return TransactionStatus.delivered;
      case 'completed': return TransactionStatus.completed;
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
      'status': status.name,
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
      'buyerAddress': buyerAddress,
    };
  }

  @override
  List<Object?> get props => [
    id, postId, buyerId, sellerId, amount, status, createdAt, shippedAt, deliveredAt, completedAt,
    refundReason, isEscrow, escrowAmount, releaseToSellerAt, isAcceptedBySeller, rejectionReason, rating, buyerAddress
  ];
}
