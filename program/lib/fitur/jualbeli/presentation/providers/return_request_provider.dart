// File: return_request_provider.dart - PERBAIKAN LENGKAP DENGAN REFUND
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/data/repositories/return_request_repository_impl.dart';
import 'package:program/fitur/jualbeli/domain/repositories/return_request_repository.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:http/http.dart' as http;
import 'package:program/app/constants/app_constants.dart';
import 'dart:convert';

import '../../domain/entities/transaction_entity.dart';

final returnRequestRepositoryProvider = Provider<ReturnRequestRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return ReturnRequestRepositoryImpl(firestore);
});

class ReturnRequestNotifier extends StateNotifier<AsyncValue<void>> {
  final ReturnRequestRepository _repository;
  final Ref _ref;

  ReturnRequestNotifier(this._repository, this._ref) : super(const AsyncData(null));

  Future<void> createReturnRequest({
    required String transactionId,
    required String buyerId,
    required String sellerId,
    required String reason,
    required List<String> evidenceUrls,
  }) async {
    state = const AsyncLoading();
    try {
      final request = ReturnRequest(
        id: '',
        transactionId: transactionId,
        buyerId: buyerId,
        sellerId: sellerId,
        reason: reason,
        evidenceUrls: evidenceUrls,
        createdAt: Timestamp.now(),
        status: ReturnStatus.pending,
      );

      await _repository.createReturnRequest(request);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  // ✅ ADMIN APPROVE - KIRIM KE JASTIPER
  Future<void> approveReturnRequest(String requestId) async {
    state = const AsyncLoading();
    try {
      // Update status ke awaitingSellerResponse
      await _repository.updateReturnRequestStatus(requestId, ReturnStatus.awaitingSellerResponse);

      // Kirim notifikasi ke jastiper
      final request = await _repository.getReturnRequestById(requestId);
      try {
        final response = await http.post(
          Uri.parse('${AppConstants.ngrokUrl}/sendNotification'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'recipientId': request.sellerId,
            'senderName': 'Admin',
            'messageText': 'Anda memiliki retur baru yang perlu direspon dalam 15 menit.',
          }),
        );

        if (response.statusCode != 200) {
          print('Warning: Gagal mengirim notifikasi: ${response.body}');
        }
      } catch (e) {
        print('Warning: Error mengirim notifikasi: $e');
      }

      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  // ✅ ADMIN REJECT - KEMBALIKAN TRANSAKSI KE DELIVERED
  Future<void> rejectReturnRequest(String requestId) async {
    state = const AsyncLoading();
    try {
      // 1. Update status return request ke rejected
      await _repository.updateReturnRequestStatus(requestId, ReturnStatus.rejected);

      // 2. Kembalikan transaksi ke status delivered
      final request = await _repository.getReturnRequestById(requestId);
      await _ref.read(transactionProvider.notifier).updateTransactionStatus(
          request.transactionId,
          TransactionStatus.delivered
      );

      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> sendToSeller(String requestId) async {
    state = const AsyncLoading();
    try {
      await _repository.updateReturnRequestStatus(requestId, ReturnStatus.awaitingSellerResponse);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> respondToReturnRequest(String requestId, String responseReason) async {
    state = const AsyncLoading();
    try {
      await _repository.respondToReturnRequest(requestId, responseReason);

      // Update status ke seller_responded setelah jastiper respon
      await _repository.updateReturnRequestStatus(requestId, ReturnStatus.sellerResponded);

      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  // ✅ ADMIN FINALISASI - KEPUTUSAN AKHIR DENGAN REFUND KE BUYER
  Future<void> finalizeReturn(String requestId, bool isApproved) async {
    state = const AsyncLoading();
    try {
      // 1. Get return request data
      final request = await _repository.getReturnRequestById(requestId);

      // 2. Get transaction data untuk ambil informasi amount dan buyerId
      final firestore = _ref.read(firebaseFirestoreProvider);
      final transactionDoc = await firestore.collection('transactions').doc(request.transactionId).get();

      if (!transactionDoc.exists) {
        throw Exception('Transaksi tidak ditemukan');
      }

      final transactionData = transactionDoc.data() as Map<String, dynamic>;
      final buyerId = transactionData['buyerId'] as String;
      final amount = (transactionData['amount'] as num).toDouble();
      final escrowAmount = (transactionData['escrowAmount'] as num?)?.toDouble() ?? amount;

      print('🔍 [FinalizeReturn] Processing return for transaction ${request.transactionId}');
      print('🔍 [FinalizeReturn] Buyer: $buyerId, Amount: $amount, Escrow: $escrowAmount');

      if (isApproved) {
        print('✅ [FinalizeReturn] Admin approved - Refunding to buyer');

        // ✅ ADMIN SETUJU: REFUND KE PEMBELI
        // 1. Update return request status
        await _repository.updateReturnRequestStatus(requestId, ReturnStatus.finalApproved);

        // 2. Update transaction status to refunded
        await _ref.read(transactionProvider.notifier).updateTransactionStatus(
            request.transactionId,
            TransactionStatus.refunded
        );

        // 3. ✅ KEMBALIKAN DANA KE PEMBELI
        await firestore.collection('users').doc(buyerId).update({
          'saldo': FieldValue.increment(amount), // Kembalikan full amount ke buyer
        });

        // 4. ✅ UPDATE TRANSACTION DENGAN REFUND INFO
        await firestore.collection('transactions').doc(request.transactionId).update({
          'refundedAt': FieldValue.serverTimestamp(),
          'refundAmount': amount,
          'refundReason': 'Return approved by admin after seller response',
        });

        // 5. ✅ TAMBAHKAN LOG REFUND UNTUK AUDIT TRAIL
        await firestore.collection('refund_logs').add({
          'transactionId': request.transactionId,
          'returnRequestId': requestId,
          'buyerId': buyerId,
          'sellerId': request.sellerId,
          'refundAmount': amount,
          'originalAmount': amount,
          'escrowAmount': escrowAmount,
          'reason': 'Final approved return by admin',
          'buyerReason': request.reason,
          'sellerResponse': request.responseReason,
          'processedAt': FieldValue.serverTimestamp(),
          'processedBy': 'admin',
          'type': 'return_refund',
        });

        print('✅ [FinalizeReturn] Refund completed - $amount returned to buyer $buyerId');

      } else {
        print('❌ [FinalizeReturn] Admin rejected - Restoring transaction to delivered');

        // ✅ ADMIN TOLAK: KEMBALIKAN KE DELIVERED
        // 1. Update return request status
        await _repository.updateReturnRequestStatus(requestId, ReturnStatus.finalRejected);

        // 2. Update transaction kembali ke delivered
        await _ref.read(transactionProvider.notifier).updateTransactionStatus(
            request.transactionId,
            TransactionStatus.delivered
        );

        // 3. ✅ UPDATE TRANSACTION DENGAN REJECTION INFO
        await firestore.collection('transactions').doc(request.transactionId).update({
          'returnRejectedAt': FieldValue.serverTimestamp(),
          'returnRejectionReason': 'Final rejected by admin after seller response',
        });

        // 4. ✅ TAMBAHKAN LOG REJECTION UNTUK AUDIT TRAIL
        await firestore.collection('return_rejection_logs').add({
          'transactionId': request.transactionId,
          'returnRequestId': requestId,
          'buyerId': buyerId,
          'sellerId': request.sellerId,
          'reason': 'Final rejected return by admin',
          'buyerReason': request.reason,
          'sellerResponse': request.responseReason,
          'processedAt': FieldValue.serverTimestamp(),
          'processedBy': 'admin',
          'type': 'return_rejection',
        });

        print('❌ [FinalizeReturn] Rejection completed - Transaction restored to delivered');
      }

      state = const AsyncData(null);
      print('🔍 [FinalizeReturn] Process completed successfully');

    } catch (e) {
      print('❌ [FinalizeReturn] Error: $e');
      state = AsyncError(e, StackTrace.current);
      rethrow; // Re-throw untuk error handling di UI
    }
  }

  // ✅ TAMBAHAN: HELPER METHOD UNTUK GET TRANSACTION AMOUNT
  Future<double> _getTransactionAmount(String transactionId) async {
    try {
      final firestore = _ref.read(firebaseFirestoreProvider);
      final transactionDoc = await firestore.collection('transactions').doc(transactionId).get();

      if (!transactionDoc.exists) {
        throw Exception('Transaksi tidak ditemukan');
      }

      final data = transactionDoc.data() as Map<String, dynamic>;
      return (data['amount'] as num).toDouble();
    } catch (e) {
      print('❌ [GetTransactionAmount] Error: $e');
      throw Exception('Gagal mengambil jumlah transaksi: $e');
    }
  }

  // ✅ TAMBAHAN: HELPER METHOD UNTUK REFUND PROCESS
  Future<void> _processRefundToBuyer(String buyerId, double amount, String transactionId, String reason) async {
    try {
      final firestore = _ref.read(firebaseFirestoreProvider);

      // 1. Kembalikan dana ke buyer
      await firestore.collection('users').doc(buyerId).update({
        'saldo': FieldValue.increment(amount),
      });

      // 2. Log refund transaction
      await firestore.collection('transaction_logs').add({
        'userId': buyerId,
        'transactionId': transactionId,
        'type': 'refund',
        'amount': amount,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ [ProcessRefund] Successfully refunded $amount to buyer $buyerId');

    } catch (e) {
      print('❌ [ProcessRefund] Error: $e');
      throw Exception('Gagal memproses refund: $e');
    }
  }

  Stream<List<ReturnRequest>> getPendingReturnRequests() {
    return _repository.getPendingReturnRequests();
  }

  Stream<List<ReturnRequest>> getReturnRequestsByBuyer(String buyerId) {
    return _repository.getReturnRequestsByBuyer(buyerId);
  }

  Stream<List<ReturnRequest>> getReturnRequestsBySeller(String sellerId) {
    return _repository.getReturnRequestsBySeller(sellerId);
  }

  Stream<ReturnRequest> getReturnRequestById(String requestId) {
    return _repository.getReturnRequestById(requestId).asStream();
  }

  // ✅ STREAM UNTUK RETURN YANG SUDAH DIRESPON JASTIPER (UNTUK ADMIN FINALISASI)
  Stream<List<ReturnRequest>> getRespondedReturnRequests() {
    return _repository.getRespondedReturnRequests();
  }

  Stream<List<ReturnRequest>> getReturnRequestsByTransactionId(String transactionId) {
    return _repository.getReturnRequestsByTransactionId(transactionId);
  }
}

final returnRequestProvider = StateNotifierProvider<ReturnRequestNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(returnRequestRepositoryProvider);
  return ReturnRequestNotifier(repository, ref);
});

// ✅ PROVIDER UNTUK PENDING RETURN REQUESTS (UNTUK ADMIN REVIEW)
final pendingReturnRequestsStreamProvider = StreamProvider<List<ReturnRequest>>((ref) {
  final notifier = ref.watch(returnRequestProvider.notifier);
  return notifier.getPendingReturnRequests();
});

final returnRequestByIdStreamProvider = StreamProvider.family<ReturnRequest, String>((ref, requestId) {
  final notifier = ref.watch(returnRequestProvider.notifier);
  return notifier.getReturnRequestById(requestId);
});

// ✅ PROVIDER UNTUK RETURN YANG PERLU DIRESPON JASTIPER (STATUS: awaitingSellerResponse)
final returnRequestsBySellerStreamProvider = StreamProvider.family<List<ReturnRequest>, String>((ref, sellerId) {
  final notifier = ref.watch(returnRequestProvider.notifier);
  return notifier.getReturnRequestsBySeller(sellerId);
});

// ✅ PROVIDER UNTUK RETURN YANG SUDAH DIRESPON JASTIPER (UNTUK ADMIN FINALISASI)
final respondedReturnRequestsStreamProvider = StreamProvider<List<ReturnRequest>>((ref) {
  final notifier = ref.watch(returnRequestProvider.notifier);
  return notifier.getRespondedReturnRequests();
});

final returnRequestsByTransactionIdStreamProvider = StreamProvider.family<List<ReturnRequest>, String>((ref, transactionId) {
  final notifier = ref.watch(returnRequestProvider.notifier);
  return notifier.getReturnRequestsByTransactionId(transactionId);
});

// ✅ PROVIDER UNTUK CEK APAKAH TRANSAKSI PUNYA RETURN REQUEST AKTIF
final hasActiveReturnRequestProvider = FutureProvider.family<bool, String>((ref, transactionId) async {
  final returnRequests = await ref.watch(returnRequestsByTransactionIdStreamProvider(transactionId).future);
  return returnRequests.any((r) =>
  r.status == ReturnStatus.pending ||
      r.status == ReturnStatus.approved ||
      r.status == ReturnStatus.awaitingSellerResponse ||
      r.status == ReturnStatus.sellerResponded
  );
});
