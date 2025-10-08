import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnRequest extends Equatable {
  final String id;
  final String transactionId;
  final String buyerId;
  final String sellerId;
  final String reason;
  final List<String> evidenceUrls; // Foto/video pendukung
  final Timestamp createdAt;
  final Timestamp? respondedAt;
  final String? responseReason;
  final ReturnStatus status;

  const ReturnRequest({
    required this.id,
    required this.transactionId,
    required this.buyerId,
    required this.sellerId,
    required this.reason,
    required this.evidenceUrls,
    required this.createdAt,
    this.respondedAt,
    this.responseReason,
    required this.status,
  });

  factory ReturnRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReturnRequest(
      id: doc.id,
      transactionId: data['transactionId'] as String,
      buyerId: data['buyerId'] as String,
      sellerId: data['sellerId'] as String,
      reason: data['reason'] as String,
      evidenceUrls: List<String>.from(data['evidenceUrls'] ?? []),
      createdAt: data['createdAt'] as Timestamp,
      respondedAt: data['respondedAt'] as Timestamp?,
      responseReason: data['responseReason'] as String?,
      status: _parseStatus(data['status'] as String),
    );
  }

  static ReturnStatus _parseStatus(String status) {
    switch (status) {
      case 'pending': return ReturnStatus.pending;
      case 'approved': return ReturnStatus.approved;
      case 'rejected': return ReturnStatus.rejected;
      case 'awaiting_seller_response': return ReturnStatus.awaitingSellerResponse;
      case 'seller_responded': return ReturnStatus.sellerResponded;
      case 'final_rejected': return ReturnStatus.finalRejected;
      case 'final_approved': return ReturnStatus.finalApproved;
      default: return ReturnStatus.pending;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'transactionId': transactionId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'reason': reason,
      'evidenceUrls': evidenceUrls,
      'createdAt': createdAt,
      'respondedAt': respondedAt,
      'responseReason': responseReason,
      'status': status.name,
    };
  }

  @override
  List<Object?> get props => [
    id,
    transactionId,
    buyerId,
    sellerId,
    reason,
    evidenceUrls,
    createdAt,
    respondedAt,
    responseReason,
    status,
  ];
}

enum ReturnStatus {
  pending,
  approved,
  rejected,
  awaitingSellerResponse,
  sellerResponded,
  finalRejected,
  finalApproved,
}