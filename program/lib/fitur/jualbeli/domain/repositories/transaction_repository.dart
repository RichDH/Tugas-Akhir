import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:program/fitur/jualbeli/domain/entities/transaction_entity.dart';

abstract class TransactionRepository {

  // --- Transaksi Dasar ---
  Future<void> createTransaction(Transaction transaction);
  Future<Transaction> getTransactionById(String transactionId);
  Stream<List<Transaction>> getTransactionsByBuyer(String buyerId);
  Stream<List<Transaction>> getTransactionsBySeller(String sellerId);

  // --- Update Status Umum ---
  Future<void> updateTransactionStatus(String transactionId, TransactionStatus status);

  // --- Alur Pesanan oleh Jastiper ---
  Future<void> acceptTransaction(String transactionId);
  Future<void> rejectTransaction(String transactionId, String reason);

  // --- Update Status Pengiriman ---
  Future<void> markAsShipped(String transactionId);
  Future<void> markAsDelivered(String transactionId);

  // --- Escrow: Pencairan Dana ---
  Future<void> releaseEscrowFunds(String transactionId);

  // ✅ TAMBAHKAN METHOD INI UNTUK MENDAPATKAN REFERENCE TRANSAKSI
  Future<firestore.DocumentReference> createTransactionAndGetRef(Transaction transaction);
  Future<void> completeTransaction(String transactionId, int rating);
  Future<void> confirmReturnReceived(String transactionId);
}