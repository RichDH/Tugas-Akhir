import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/fitur/ads/domain/entities/ads_package.dart';

class AdsPackageRepository {
  final FirebaseFirestore _firestore;

  AdsPackageRepository(this._firestore);

  // Get semua ads packages (untuk admin)
  Stream<List<AdsPackage>> getAllAdsPackages() {
    return _firestore
        .collection('ads_packages')
        .orderBy('level', descending: true) // VIP (level tinggi) di atas
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => AdsPackage.fromFirestore(doc)).toList());
  }

  // Get active packages (untuk user)
  Stream<List<AdsPackage>> getActivePackages() {
    return _firestore
        .collection('ads_packages')
        .where('isActive', isEqualTo: true)
        .orderBy('level', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => AdsPackage.fromFirestore(doc)).toList());
  }

  // Update package
  Future<void> updatePackage(AdsPackage package) async {
    await _firestore
        .collection('ads_packages')
        .doc(package.id)
        .update(package.toMap());
  }

  // Get package by type
  Future<AdsPackage?> getPackageByType(AdsPackageType type) async {
    final query = await _firestore
        .collection('ads_packages')
        .where('type', isEqualTo: type.name)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return AdsPackage.fromFirestore(query.docs.first);
    }
    return null;
  }

  // Create default packages jika belum ada
  Future<void> createDefaultPackages(String adminUid) async {
    final batch = _firestore.batch();

    // Premium Package
    final premiumRef = _firestore.collection('ads_packages').doc('premium');
    batch.set(premiumRef, AdsPackage(
      id: 'premium',
      type: AdsPackageType.premium,
      name: 'Premium Ads',
      price: 50000, // Rp 50.000
      durationDays: 3, // 3 hari
      level: 1, // level 1
      isActive: true,
      updatedAt: DateTime.now(),
      updatedBy: adminUid,
    ).toMap());

    // VIP Package
    final vipRef = _firestore.collection('ads_packages').doc('vip');
    batch.set(vipRef, AdsPackage(
      id: 'vip',
      type: AdsPackageType.vip,
      name: 'VIP Ads',
      price: 100000, // Rp 100.000
      durationDays: 7, // 7 hari
      level: 2, // level 2 (lebih tinggi dari premium)
      isActive: true,
      updatedAt: DateTime.now(),
      updatedBy: adminUid,
    ).toMap());

    await batch.commit();
  }
}
