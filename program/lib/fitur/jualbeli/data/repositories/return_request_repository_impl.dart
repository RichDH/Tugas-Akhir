
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:program/fitur/jualbeli/domain/repositories/return_request_repository.dart';

class ReturnRequestRepositoryImpl implements ReturnRequestRepository {
  final FirebaseFirestore _firestore;

  ReturnRequestRepositoryImpl(this._firestore);

  @override
  Future<void> createReturnRequest(ReturnRequest request) async {
    try {
      await _firestore.collection('return_requests').add(request.toFirestore());
    } catch (e) {
      throw Exception('Gagal membuat permintaan retur: $e');
    }
  }

  @override
  Future<void> completeTransaction(String transactionId, int rating, String review) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': 'delivered', // Atau 'completed' — sesuaikan dengan enum Anda
        'completedAt': FieldValue.serverTimestamp(),
        'rating': rating,
        'review': review,
      });
    } catch (e) {
      throw Exception('Gagal menyelesaikan transaksi: $e');
    }
  }

  @override
  Future<ReturnRequest> getReturnRequestById(String requestId) async {
    final doc = await _firestore.collection('return_requests').doc(requestId).get();
    if (!doc.exists) {
      throw Exception('Retur tidak ditemukan.');
    }
    return ReturnRequest.fromFirestore(doc);
  }

  @override
  Stream<List<ReturnRequest>> getReturnRequestsByBuyer(String buyerId) {
    return _firestore
        .collection('return_requests')
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ReturnRequest.fromFirestore(doc)).toList());
  }

  @override
  Stream<List<ReturnRequest>> getReturnRequestsBySeller(String sellerId) {
    return _firestore
        .collection('return_requests')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ReturnRequest.fromFirestore(doc)).toList());
  }

  @override
  Stream<List<ReturnRequest>> getPendingReturnRequests() {
    return _firestore
        .collection('return_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ReturnRequest.fromFirestore(doc)).toList());
  }

  @override
  Stream<List<ReturnRequest>> getRespondedReturnRequests() {
    return _firestore
        .collection('return_requests')
        .where('status', isEqualTo: 'sellerResponded')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ReturnRequest.fromFirestore(doc)).toList());
  }

  @override
  Future<void> updateReturnRequestStatus(String requestId, ReturnStatus status) async {
    try {
      await _firestore.collection('return_requests').doc(requestId).update({
        'status': status.name,
      });
    } catch (e) {
      throw Exception('Gagal memperbarui status retur: $e');
    }
  }

  @override
  Future<void> respondToReturnRequest(String requestId, String responseReason) async {
    try {
      await _firestore.collection('return_requests').doc(requestId).update({
        'responseReason': responseReason,
        'respondedAt': FieldValue.serverTimestamp(),
        'status': 'sellerResponded',
      });
    } catch (e) {
      throw Exception('Gagal merespon retur: $e');
    }
  }

  @override
  Stream<List<ReturnRequest>> getReturnRequestsByTransactionId(String transactionId) {
    return _firestore
        .collection('return_requests')
        .where('transactionId', isEqualTo: transactionId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ReturnRequest.fromFirestore(doc)).toList());
  }
}