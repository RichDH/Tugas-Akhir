// File: lib/fitur/jualbeli/presentation/providers/transaction_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
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

  // --- Transaksi Dasar ---
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
        createdAt: firestore.Timestamp.now(),
        shippedAt: null,
        deliveredAt: null,
        refundReason: null,
        isEscrow: isEscrow,
        escrowAmount: escrowAmount,
        releaseToSellerAt: null,
        isAcceptedBySeller: false,
        rejectionReason: null,
      );

      await _repository.createTransaction(transaction);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  // --- Method untuk mendapatkan ID transaksi ---
  Future<String?> createTransactionAndGetId({
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
        createdAt: firestore.Timestamp.now(),
        shippedAt: null,
        deliveredAt: null,
        refundReason: null,
        isEscrow: isEscrow,
        escrowAmount: escrowAmount,
        releaseToSellerAt: null,
        isAcceptedBySeller: false,
        rejectionReason: null,
      );

      final docRef = await _repository.createTransactionAndGetRef(transaction);
      state = const AsyncData(null);
      return docRef.id;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return null;
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

  // --- Alur Pesanan oleh Jastiper ---
  Future<void> acceptTransaction(String transactionId) async {
    state = const AsyncLoading();
    try {
      await _repository.acceptTransaction(transactionId);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> rejectTransaction(String transactionId, String reason) async {
    state = const AsyncLoading();
    try {
      await _repository.rejectTransaction(transactionId, reason);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  // --- Update Status Pengiriman ---
  Future<void> markAsShipped(String transactionId) async {
    state = const AsyncLoading();
    try {
      await _repository.markAsShipped(transactionId);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> markAsDelivered(String transactionId) async {
    state = const AsyncLoading();
    try {
      await _repository.markAsDelivered(transactionId);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  // --- Escrow: Pencairan Dana ---
  Future<void> releaseEscrowFunds(String transactionId) async {
    state = const AsyncLoading();
    try {
      await _repository.releaseEscrowFunds(transactionId);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> completeTransaction(String transactionId, int rating) async {
    state = const AsyncLoading();
    try {
      await _repository.completeTransaction(transactionId, rating);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> confirmReturnReceived(String transactionId) async {
    state = const AsyncLoading();
    try {
      await _repository.confirmReturnReceived(transactionId);
      await _repository.releaseEscrowFunds(transactionId);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  // --- Stream untuk transaksi berdasarkan buyerId ---
  Stream<List<Transaction>> getTransactionsByBuyer(String buyerId) {
    return _repository.getTransactionsByBuyer(buyerId);
  }

  // --- Stream untuk transaksi berdasarkan sellerId ---
  Stream<List<Transaction>> getTransactionsBySeller(String sellerId) {
    return _repository.getTransactionsBySeller(sellerId);
  }

  // --- Stream untuk transaksi berdasarkan ID ---
  Stream<Transaction> getTransactionById(String transactionId) {
    return _repository.getTransactionById(transactionId).asStream();
  }
}

final transactionProvider = StateNotifierProvider<TransactionNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return TransactionNotifier(repository, ref);
});

// ✅ PROVIDER UNTUK STREAM TRANSAKSI BERDASARKAN BUYER
final transactionsByBuyerStreamProvider = StreamProvider.family<List<Transaction>, String>((ref, buyerId) {
  final notifier = ref.watch(transactionProvider.notifier);
  return notifier.getTransactionsByBuyer(buyerId);
});

// ✅ PROVIDER UNTUK STREAM TRANSAKSI BERDASARKAN SELLER
final transactionsBySellerStreamProvider = StreamProvider.family<List<Transaction>, String>((ref, sellerId) {
  final notifier = ref.watch(transactionProvider.notifier);
  return notifier.getTransactionsBySeller(sellerId);
});

// ✅ PROVIDER UNTUK STREAM TRANSAKSI BERDASARKAN ID
final transactionByIdStreamProvider = StreamProvider.family<Transaction, String>((ref, transactionId) {
  final notifier = ref.watch(transactionProvider.notifier);
  return notifier.getTransactionById(transactionId);
});


// ✅ PROVIDER UNTUK USERNAME BERDASARKAN USER ID
final userNameProvider = FutureProvider.family<String, String>((ref, userId) async {
  final firestore = ref.watch(firebaseFirestoreProvider);
  try {
    final doc = await firestore.collection('users').doc(userId).get();
    if (!doc.exists) return 'Pengguna Tidak Dikenal';
    final data = doc.data() as Map<String, dynamic>?;
    return data?['username'] as String? ?? 'Pengguna Tidak Dikenal';
  } catch (e) {
    print('Error getting username for $userId: $e');
    return 'Pengguna Tidak Dikenal';
  }
});