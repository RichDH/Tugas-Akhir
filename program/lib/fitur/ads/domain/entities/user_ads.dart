import 'package:cloud_firestore/cloud_firestore.dart';

class UserAds {
  final String id;
  final String userId;
  final String postId;
  final String packageType; // 'premium' atau 'vip'
  final String packageName;
  final int adsLevel;
  final double paidAmount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;

  const UserAds({
    required this.id,
    required this.userId,
    required this.postId,
    required this.packageType,
    required this.packageName,
    required this.adsLevel,
    required this.paidAmount,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
  });

  factory UserAds.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAds(
      id: doc.id,
      userId: data['userId'] ?? '',
      postId: data['postId'] ?? '',
      packageType: data['packageType'] ?? '',
      packageName: data['packageName'] ?? '',
      adsLevel: data['adsLevel'] ?? 1,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'postId': postId,
      'packageType': packageType,
      'packageName': packageName,
      'adsLevel': adsLevel,
      'paidAmount': paidAmount,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isActiveAndValid => isActive && !isExpired;
}
