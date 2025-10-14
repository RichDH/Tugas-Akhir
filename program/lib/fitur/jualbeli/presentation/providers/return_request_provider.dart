// File: lib/fitur/jualbeli/presentation/providers/return_request_provider.dart - FLOW DIPERBAIKI

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/data/repositories/return_request_repository_impl.dart';
import 'package:program/fitur/jualbeli/domain/repositories/return_request_repository.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart'; // ✅ TAMBAHAN
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
        status: ReturnStatus.pending, // ✅ AWAL: PENDING (UNTUK ADMIN REVIEW)
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
          // Tidak throw error, karena yang penting status sudah diupdate
        }
      } catch (e) {
        print('Warning: Error mengirim notifikasi: $e');
        // Tidak throw error, karena yang penting status sudah diupdate
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
      
      // 2. ✅ KEMBALIKAN TRANSAKSI KE STATUS DELIVERED
      final request = await _repository.getReturnRequestById(requestId);
      await _ref.read(transactionProvider.notifier).updateTransactionStatus(
        request.transactionId, 
        TransactionStatus.delivered // ✅ KEMBALIKAN KE DELIVERED
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
      
      // ✅ UPDATE STATUS KE SELLER_RESPONDED SETELAH JASTIPER RESPON
      await _repository.updateReturnRequestStatus(requestId, ReturnStatus.sellerResponded);
      
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  // ✅ ADMIN FINALISASI - KEPUTUSAN AKHIR SETELAH JASTIPER RESPON
  Future<void> finalizeReturn(String requestId, bool isApproved) async {
    state = const AsyncLoading();
    try {
      final request = await _repository.getReturnRequestById(requestId);
      
      if (isApproved) {
        // ✅ ADMIN SETUJU: REFUND KE PEMBELI
        await _repository.updateReturnRequestStatus(requestId, ReturnStatus.finalApproved);
        
        // Update transaction ke refunded dan cairkan dana kembali ke pembeli
        await _ref.read(transactionProvider.notifier).updateTransactionStatus(
          request.transactionId, 
          TransactionStatus.refunded
        );
        
        // TODO: Kembalikan dana ke pembeli (implementasi escrow refund)
        // await _refundToBuyer(request.transactionId);
        
      } else {
        // ✅ ADMIN TOLAK: KEMBALIKAN KE DELIVERED
        await _repository.updateReturnRequestStatus(requestId, ReturnStatus.finalRejected);
        
        // Update transaction kembali ke delivered
        await _ref.read(transactionProvider.notifier).updateTransactionStatus(
          request.transactionId, 
          TransactionStatus.delivered
        );
      }
      
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
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