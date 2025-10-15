// File: lib/fitur/post/domain/entities/offer.dart

import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum OfferStatus { pending, accepted, rejected }

class Offer extends Equatable {
  final String id;
  final String postId;
  final String postTitle;
  final String offererId; // ID pengguna yang mengambil pesanan
  final String offererUsername;
  final String postOwnerId; // ID pemilik post request
  final double offerPrice; // Harga yang ditawarkan
  final Timestamp createdAt;
  final OfferStatus status;
  final String? rejectionReason;

  const Offer({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.offererId,
    required this.offererUsername,
    required this.postOwnerId,
    required this.offerPrice,
    required this.createdAt,
    this.status = OfferStatus.pending,
    this.rejectionReason,
  });

  factory Offer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Offer(
      id: doc.id,
      postId: data['postId'] as String? ?? '',
      postTitle: data['postTitle'] as String? ?? '',
      offererId: data['offererId'] as String? ?? '',
      offererUsername: data['offererUsername'] as String? ?? '',
      postOwnerId: data['postOwnerId'] as String? ?? '',
      offerPrice: _parseDouble(data['offerPrice']) ?? 0.0,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      status: _parseOfferStatus(data['status'] as String?),
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static OfferStatus _parseOfferStatus(String? status) {
    if (status == null) return OfferStatus.pending;
    try {
      return OfferStatus.values.firstWhere((e) => e.name == status);
    } catch (e) {
      return OfferStatus.pending;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'postTitle': postTitle,
      'offererId': offererId,
      'offererUsername': offererUsername,
      'postOwnerId': postOwnerId,
      'offerPrice': offerPrice,
      'createdAt': createdAt,
      'status': status.name,
      'rejectionReason': rejectionReason,
    };
  }

  Offer copyWith({
    String? id,
    String? postId,
    String? postTitle,
    String? offererId,
    String? offererUsername,
    String? postOwnerId,
    double? offerPrice,
    Timestamp? createdAt,
    OfferStatus? status,
    String? rejectionReason,
  }) {
    return Offer(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      postTitle: postTitle ?? this.postTitle,
      offererId: offererId ?? this.offererId,
      offererUsername: offererUsername ?? this.offererUsername,
      postOwnerId: postOwnerId ?? this.postOwnerId,
      offerPrice: offerPrice ?? this.offerPrice,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  @override
  List<Object?> get props => [
    id, postId, postTitle, offererId, offererUsername,
    postOwnerId, offerPrice, createdAt, status, rejectionReason,
  ];
}
