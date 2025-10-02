// 👇 Tambahkan 'hide Transaction' untuk hindari konflik nama
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:program/fitur/jualbeli/domain/entities/transaction_entity.dart';
import 'package:program/fitur/jualbeli/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final FirebaseFirestore _firestore;

  TransactionRepositoryImpl(this._firestore);

  @override
  Future<void> createTransaction(Transaction transaction) async {
    try {
      await _firestore.collection('transactions').add(transaction.toFirestore());
    } catch (e) {
      throw Exception('Gagal membuat transaksi: $e');
    }
  }

  @override
  Future<Transaction> getTransactionById(String transactionId) async {
    try {
      final doc = await _firestore.collection('transactions').doc(transactionId).get();
      if (!doc.exists) {
        throw Exception('Transaksi tidak ditemukan.');
      }
      return Transaction.fromFirestore(doc);
    } catch (e) {
      throw Exception('Gagal mengambil transaksi: $e');
    }
  }

  @override
  Stream<List<Transaction>> getTransactionsByBuyer(String buyerId) {
    return _firestore
        .collection('transactions')
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Transaction.fromFirestore(doc)).toList());
  }

  @override
  Stream<List<Transaction>> getTransactionsBySeller(String sellerId) {
    return _firestore
        .collection('transactions')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Transaction.fromFirestore(doc)).toList());
  }

  @override
  Future<void> updateTransactionStatus(String transactionId, TransactionStatus status) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': status.name, // 👈 Lebih aman pakai .name daripada split
      });
    } catch (e) {
      throw Exception('Gagal memperbarui status transaksi: $e');
    }
  }

  @override
  Future<void> releaseEscrowFunds(String transactionId) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': 'delivered',
        'releaseToSellerAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal melepaskan dana escrow: $e');
    }
  }
}