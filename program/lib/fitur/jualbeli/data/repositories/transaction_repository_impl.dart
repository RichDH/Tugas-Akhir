// File: lib/fitur/jualbeli/data/repositories/transaction_repository_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction; // HIDE Transaction saja
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
        'status': status.name,
      });
    } catch (e) {
      throw Exception('Gagal memperbarui status transaksi: $e');
    }
  }

  @override
  Future<void> acceptTransaction(String transactionId) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).update({
        'isAcceptedBySeller': true,
        'status': 'paid',
      });
    } catch (e) {
      throw Exception('Gagal menerima transaksi: $e');
    }
  }

  @override
  Future<void> rejectTransaction(String transactionId, String reason) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).update({
        'isAcceptedBySeller': false,
        'rejectionReason': reason,
        'status': 'refunded',
      });
    } catch (e) {
      throw Exception('Gagal menolak transaksi: $e');
    }
  }

  @override
  Future<void> markAsShipped(String transactionId) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': 'shipped',
        'shippedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal menandai sebagai dikirim: $e');
    }
  }

  @override
  Future<void> markAsDelivered(String transactionId) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal menandai sebagai sampai: $e');
    }
  }

  @override
  Future<void> completeTransaction(String transactionId, int rating) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': 'delivered', // Atau 'completed' — sesuaikan dengan enum Anda
        'completedAt': FieldValue.serverTimestamp(),
        'rating': rating,
      });
    } catch (e) {
      throw Exception('Gagal menyelesaikan transaksi: $e');
    }
  }

  @override
  Future<void> confirmReturnReceived(String transactionId) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).update({
        'status': 'delivered',
        'completedAt': FieldValue.serverTimestamp(),
        'rating': null,
      });
    } catch (e) {
      throw Exception('Gagal konfirmasi penerimaan retur: $e');
    }
  }

  @override
  Future<void> releaseEscrowFunds(String transactionId) async {
    try {
      // Simulasi: cek apakah seller sudah diverifikasi
      final transaction = await getTransactionById(transactionId);
      final userDoc = await _firestore.collection('users').doc(transaction.sellerId).get();
      final isVerified = userDoc.data()?['isVerified'] == true;

      if (isVerified) {
        await _firestore.collection('transactions').doc(transactionId).update({
          'status': 'delivered',
          'releaseToSellerAt': FieldValue.serverTimestamp(),
        });
      } else {
        print('Seller belum diverifikasi. Dana tidak dicairkan.');
      }
    } catch (e) {
      throw Exception('Gagal melepaskan dana escrow: $e');
    }
  }

  @override
  Future<DocumentReference> createTransactionAndGetRef(Transaction transaction) async {
    try {
      return await _firestore.collection('transactions').add(transaction.toFirestore());
    } catch (e) {
      throw Exception('Gagal membuat transaksi: $e');
    }
  }
}