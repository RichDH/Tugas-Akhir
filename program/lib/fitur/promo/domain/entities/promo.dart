import 'package:cloud_firestore/cloud_firestore.dart';

class Promo {
  final String id;
  final String name;
  final double discountAmount; // nominal potongan (Rp)
  final double minimumTransaction; // syarat minimum transaksi
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy; // admin uid

  const Promo({
    required this.id,
    required this.name,
    required this.discountAmount,
    required this.minimumTransaction,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
  });

  // Factory dari Firestore
  factory Promo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Promo(
      id: doc.id,
      name: data['name'] ?? '',
      discountAmount: (data['discountAmount'] ?? 0.0).toDouble(),
      minimumTransaction: (data['minimumTransaction'] ?? 0.0).toDouble(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  // Convert ke Map untuk Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'discountAmount': discountAmount,
      'minimumTransaction': minimumTransaction,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  // Helper methods
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  String get status {
    final now = DateTime.now();
    if (!isActive) return 'Nonaktif';
    if (now.isBefore(startDate)) return 'Akan Datang';
    if (now.isAfter(endDate)) return 'Berakhir';
    return 'Aktif';
  }

  Promo copyWith({
    String? id,
    String? name,
    double? discountAmount,
    double? minimumTransaction,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Promo(
      id: id ?? this.id,
      name: name ?? this.name,
      discountAmount: discountAmount ?? this.discountAmount,
      minimumTransaction: minimumTransaction ?? this.minimumTransaction,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
