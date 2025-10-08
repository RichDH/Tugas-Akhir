// File: lib/fitur/jualbeli/domain/repositories/return_request_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';

abstract class ReturnRequestRepository {

  Future<void> createReturnRequest(ReturnRequest request);
  Stream<List<ReturnRequest>> getReturnRequestsByBuyer(String buyerId);
  Stream<List<ReturnRequest>> getReturnRequestsBySeller(String sellerId);
  Stream<List<ReturnRequest>> getPendingReturnRequests();
  Future<void> updateReturnRequestStatus(String requestId, ReturnStatus status);
  Future<void> respondToReturnRequest(String requestId, String responseReason);
  Future<ReturnRequest> getReturnRequestById(String requestId);
  Stream<List<ReturnRequest>> getRespondedReturnRequests();
  Stream<List<ReturnRequest>> getReturnRequestsByTransactionId(String transactionId);
}