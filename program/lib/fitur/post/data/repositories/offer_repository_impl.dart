// File: lib/fitur/post/data/repositories/offer_repository_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/fitur/post/domain/entities/offer.dart';
import 'package:program/fitur/post/domain/repositories/offer_repository.dart';

class OfferRepositoryImpl implements OfferRepository {
  final FirebaseFirestore _firestore;

  OfferRepositoryImpl(this._firestore);

  @override
  Future<void> createOffer(Offer offer) async {
    final batch = _firestore.batch();

    // Tambah offer baru
    final offerRef = _firestore.collection('offers').doc();
    batch.set(offerRef, offer.copyWith(id: offerRef.id).toFirestore());

    // Update currentOffers di post
    final postRef = _firestore.collection('posts').doc(offer.postId);
    batch.update(postRef, {
      'currentOffers': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    });

    await batch.commit();
  }

  @override
  Future<void> acceptOffer(String offerId) async {
    await _firestore.collection('offers').doc(offerId).update({
      'status': OfferStatus.accepted.name,
    });
  }

  @override
  Future<void> rejectOffer(String offerId, String reason) async {
    await _firestore.collection('offers').doc(offerId).update({
      'status': OfferStatus.rejected.name,
      'rejectionReason': reason,
    });
  }

  @override
  Stream<List<Offer>> getOffersByPost(String postId) {
    return _firestore
        .collection('offers')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Offer.fromFirestore(doc)).toList());
  }

  @override
  Stream<List<Offer>> getOffersByOfferer(String offererId) {
    return _firestore
        .collection('offers')
        .where('offererId', isEqualTo: offererId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Offer.fromFirestore(doc)).toList());
  }

  @override
  Stream<List<Offer>> getOffersByPostOwner(String postOwnerId) {
    return _firestore
        .collection('offers')
        .where('postOwnerId', isEqualTo: postOwnerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Offer.fromFirestore(doc)).toList());
  }

  @override
  Future<void> updatePostOfferCount(String postId, int newCount) async {
    await _firestore.collection('posts').doc(postId).update({
      'currentOffers': newCount,
      'updatedAt': Timestamp.now(),
    });
  }
}
