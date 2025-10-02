// 👇 Hide Transaction dari Firestore
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/data/repositories/transaction_repository_impl.dart';
import 'package:program/fitur/jualbeli/domain/repositories/transaction_repository.dart';
import 'package:program/fitur/jualbeli/domain/entities/transaction_entity.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return TransactionRepositoryImpl(firestore);
});

class TransactionNotifier extends StateNotifier<AsyncValue<void>> {
  final TransactionRepository _repository;
  final Ref _ref;

  TransactionNotifier(this._repository, this._ref) : super(const AsyncData(null));

  Future<void> createTransaction({
    required String postId,
    required String buyerId,
    required String sellerId,
    required double amount,
    required bool isEscrow,
    required double escrowAmount,
  }) async {
    state = const AsyncLoading();
    try {
      final transaction = Transaction(
        id: '',
        postId: postId,
        buyerId: buyerId,
        sellerId: sellerId,
        amount: amount,
        status: TransactionStatus.pending,
        // ❌ HAPUS: paymentMethod dan xenditInvoiceId
        createdAt: Timestamp.now(),
        shippedAt: null,
        deliveredAt: null,
        refundReason: null,
        isEscrow: isEscrow,
        escrowAmount: escrowAmount,
        releaseToSellerAt: null,
      );

      await _repository.createTransaction(transaction);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> updateTransactionStatus(String transactionId, TransactionStatus status) async {
    state = const AsyncLoading();
    try {
      await _repository.updateTransactionStatus(transactionId, status);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> releaseEscrowFunds(String transactionId) async {
    state = const AsyncLoading();
    try {
      await _repository.releaseEscrowFunds(transactionId);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final transactionProvider = StateNotifierProvider<TransactionNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return TransactionNotifier(repository, ref);
});