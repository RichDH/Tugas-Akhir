import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/fitur/promo/domain/entities/promo.dart';

class PromoRepository {
  final FirebaseFirestore _firestore;

  PromoRepository(this._firestore);

  // Create promo baru
  Future<String> createPromo(Promo promo) async {
    final docRef = _firestore.collection('promos').doc();
    final promoWithId = promo.copyWith(id: docRef.id);
    await docRef.set(promoWithId.toMap());
    return docRef.id;
  }

  // Get semua promo (untuk admin)
  Stream<List<Promo>> getAllPromos() {
    return _firestore
        .collection('promos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Promo.fromFirestore(doc)).toList());
  }

  // Get promo aktif (untuk user saat transaksi)
  Stream<List<Promo>> getActivePromos() {
    final now = Timestamp.now();
    return _firestore
        .collection('promos')
        .where('isActive', isEqualTo: true)
        .where('startDate', isLessThanOrEqualTo: now)
        .where('endDate', isGreaterThan: now)
        .orderBy('endDate')
        .orderBy('discountAmount', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Promo.fromFirestore(doc)).toList());
  }

  // Update promo
  Future<void> updatePromo(Promo promo) async {
    await _firestore.collection('promos').doc(promo.id).update(promo.toMap());
  }

  // Toggle active status
  Future<void> togglePromoStatus(String promoId, bool isActive) async {
    await _firestore.collection('promos').doc(promoId).update({
      'isActive': isActive,
    });
  }

  // Delete promo (hard delete untuk admin)
  Future<void> deletePromo(String promoId) async {
    await _firestore.collection('promos').doc(promoId).delete();
  }

  // Get promo by ID
  Future<Promo?> getPromoById(String promoId) async {
    final doc = await _firestore.collection('promos').doc(promoId).get();
    if (doc.exists) {
      return Promo.fromFirestore(doc);
    }
    return null;
  }
}
