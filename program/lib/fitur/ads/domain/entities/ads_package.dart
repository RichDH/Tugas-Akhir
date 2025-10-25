import 'package:cloud_firestore/cloud_firestore.dart';

enum AdsPackageType { premium, vip }

class AdsPackage {
  final String id;
  final AdsPackageType type;
  final String name;
  final double price; // harga dalam Rupiah
  final int durationDays; // lama berlangsung dalam hari
  final int level; // tingkatan prioritas (semakin tinggi semakin prioritas)
  final bool isActive;
  final DateTime updatedAt;
  final String updatedBy; // admin uid

  const AdsPackage({
    required this.id,
    required this.type,
    required this.name,
    required this.price,
    required this.durationDays,
    required this.level,
    required this.isActive,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory AdsPackage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdsPackage(
      id: doc.id,
      type: AdsPackageType.values.firstWhere(
            (e) => e.name == data['type'],
        orElse: () => AdsPackageType.premium,
      ),
      name: data['name'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      durationDays: data['durationDays'] ?? 1,
      level: data['level'] ?? 1,
      isActive: data['isActive'] ?? true,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      updatedBy: data['updatedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'name': name,
      'price': price,
      'durationDays': durationDays,
      'level': level,
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  AdsPackage copyWith({
    String? id,
    AdsPackageType? type,
    String? name,
    double? price,
    int? durationDays,
    int? level,
    bool? isActive,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return AdsPackage(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      price: price ?? this.price,
      durationDays: durationDays ?? this.durationDays,
      level: level ?? this.level,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  String get typeDisplayName {
    switch (type) {
      case AdsPackageType.premium:
        return 'Premium';
      case AdsPackageType.vip:
        return 'VIP';
    }
  }
}
