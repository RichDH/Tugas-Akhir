import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';

// ✅ PROVIDER TERPISAH - TIDAK SALING BERGANTUNG

// 1. Total Users Count (StreamProvider sederhana)
final adminTotalUsersProvider = StreamProvider.autoDispose<int>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs.collection('users').snapshots().map((snap) => snap.size);
});

// 2. Verified Users Count
final adminVerifiedUsersProvider = StreamProvider.autoDispose<int>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs
      .collection('users')
      .where('isVerified', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.size);
});

// 3. Total Transactions Count
final adminTotalTransactionsProvider = StreamProvider.autoDispose<int>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs.collection('transactions').snapshots().map((snap) => snap.size);
});

// 4. Completed Transactions Count
final adminCompletedTransactionsProvider = StreamProvider.autoDispose<int>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs
      .collection('transactions')
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((snap) => snap.size);
});

// 5. Total Revenue dari Completed Transactions (FutureProvider one-time)
final adminTotalRevenueProvider = FutureProvider.autoDispose<double>((ref) async {
  final fs = ref.read(firebaseFirestoreProvider);

  try {
    final completedSnap = await fs
        .collection('transactions')
        .where('status', isEqualTo: 'completed')
        .get();

    return completedSnap.docs.fold<double>(0.0, (sum, doc) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });
  } catch (e) {
    print('Error calculating revenue: $e');
    return 0.0;
  }
});

// 6. Simple Date Range State Provider
final reportDateRangeProvider = StateProvider.autoDispose<DateTimeRange?>((ref) => null);
