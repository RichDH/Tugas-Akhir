// File: lib/fitur/jualbeli/presentation/providers/return_request_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/data/repositories/return_request_repository_impl.dart';
import 'package:program/fitur/jualbeli/domain/repositories/return_request_repository.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:http/http.dart' as http;
import 'package:program/app/constants/app_constants.dart';
import 'dart:convert';

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

  Future<void> approveReturnRequest(String requestId) async {
    state = const AsyncLoading();
    try {
      // ✅ Ubah status langsung ke awaitingSellerResponse
      await _repository.updateReturnRequestStatus(requestId, ReturnStatus.awaitingSellerResponse);

      // Kirim notifikasi ke jastiper
      final request = await _repository.getReturnRequestById(requestId);
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
        throw Exception('Gagal mengirim notifikasi.');
      }

      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> rejectReturnRequest(String requestId) async {
    state = const AsyncLoading();
    try {
      await _repository.updateReturnRequestStatus(requestId, ReturnStatus.rejected);
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
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> finalizeReturn(String requestId, bool isApproved) async {
    state = const AsyncLoading();
    try {
      final status = isApproved ? ReturnStatus.finalApproved : ReturnStatus.finalRejected;
      await _repository.updateReturnRequestStatus(requestId, status);
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

final pendingReturnRequestsStreamProvider = StreamProvider<List<ReturnRequest>>((ref) {
  final notifier = ref.watch(returnRequestProvider.notifier);
  return notifier.getPendingReturnRequests();
});

final returnRequestByIdStreamProvider = StreamProvider.family<ReturnRequest, String>((ref, requestId) {
  final notifier = ref.watch(returnRequestProvider.notifier);
  return notifier.getReturnRequestById(requestId);
});

final returnRequestsBySellerStreamProvider = StreamProvider.family<List<ReturnRequest>, String>((ref, sellerId) {
  final notifier = ref.watch(returnRequestProvider.notifier);
  return notifier.getReturnRequestsBySeller(sellerId);
});

final respondedReturnRequestsStreamProvider = StreamProvider<List<ReturnRequest>>((ref) {
  final notifier = ref.watch(returnRequestProvider.notifier);
  return notifier.getRespondedReturnRequests();
});

final returnRequestsByTransactionIdStreamProvider = StreamProvider.family<List<ReturnRequest>, String>((ref, transactionId) {
  final notifier = ref.watch(returnRequestProvider.notifier);
  return notifier.getReturnRequestsByTransactionId(transactionId);
});