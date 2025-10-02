import 'package:program/fitur/jualbeli/domain/entities/transaction_entity.dart';

abstract class TransactionRepository {

  Future<void> createTransaction(Transaction transaction);
  Future<Transaction> getTransactionById(String transactionId);
  Stream<List<Transaction>> getTransactionsByBuyer(String buyerId);
  Stream<List<Transaction>> getTransactionsBySeller(String sellerId);
  Future<void> updateTransactionStatus(String transactionId, TransactionStatus status);
  Future<void> releaseEscrowFunds(String transactionId); // Cairkan dana ke Jastiper
}