import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

// Provider untuk bulan yang dipilih (state)
final selectedMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1); // default bulan ini
});

// Provider laporan berdasarkan bulan yang dipilih
final adminMonthlyReportProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final fs = ref.read(firebaseFirestoreProvider);

  try {
    // Bulan yang dipilih (1-31)
    final currentMonthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final currentMonthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

    // Bulan sebelumnya (1-31)
    final lastMonthStart = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    final lastMonthEnd = DateTime(selectedMonth.year, selectedMonth.month, 1);

    print('📊 Analyzing ${DateFormat('MMMM yyyy').format(selectedMonth)}...');

    // Fetch semua data sekali
    final allTransactions = await fs.collection('transactions').get();
    final allUsers = await fs.collection('users').get();

    // TRANSAKSI - Filter berdasarkan bulan
    final currentMonthTx = allTransactions.docs.where((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final date = createdAt.toDate();
      return date.isAfter(currentMonthStart) && date.isBefore(currentMonthEnd);
    }).toList();

    final lastMonthTx = allTransactions.docs.where((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final date = createdAt.toDate();
      return date.isAfter(lastMonthStart) && date.isBefore(lastMonthEnd);
    }).toList();

    // Completed transactions
    final currentCompletedTx = currentMonthTx.where((doc) => doc.data()['status'] == 'completed').toList();
    final lastMonthCompletedTx = lastMonthTx.where((doc) => doc.data()['status'] == 'completed').toList();

    // Revenue
    final currentRevenue = currentCompletedTx.fold<double>(0.0, (sum, doc) {
      final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });

    final lastMonthRevenue = lastMonthCompletedTx.fold<double>(0.0, (sum, doc) {
      final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });

    // ✅ USERS - Filter berdasarkan createdAt jika ada
    final currentMonthUsers = allUsers.docs.where((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) return false; // Skip user tanpa createdAt
      final date = createdAt.toDate();
      return date.isAfter(currentMonthStart) && date.isBefore(currentMonthEnd);
    }).toList();

    final lastMonthUsers = allUsers.docs.where((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final date = createdAt.toDate();
      return date.isAfter(lastMonthStart) && date.isBefore(lastMonthEnd);
    }).toList();

    // ✅ VERIFIED USERS - Filter berdasarkan verifiedAt jika ada
    final currentMonthVerified = allUsers.docs.where((doc) {
      final data = doc.data();
      if (data['isVerified'] != true) return false;

      final verifiedAt = data['verifiedAt'] as Timestamp?;
      if (verifiedAt == null) return false;

      final date = verifiedAt.toDate();
      return date.isAfter(currentMonthStart) && date.isBefore(currentMonthEnd);
    }).toList();

    final lastMonthVerified = allUsers.docs.where((doc) {
      final data = doc.data();
      if (data['isVerified'] != true) return false;

      final verifiedAt = data['verifiedAt'] as Timestamp?;
      if (verifiedAt == null) return false;

      final date = verifiedAt.toDate();
      return date.isAfter(lastMonthStart) && date.isBefore(lastMonthEnd);
    }).toList();

    // Total users (akumulatif sampai bulan dipilih)
    final totalUsersUntilMonth = allUsers.docs.where((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) return true; // Include user tanpa createdAt sebagai user lama
      final date = createdAt.toDate();
      return date.isBefore(currentMonthEnd);
    }).length;

    final totalUsersUntilLastMonth = allUsers.docs.where((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) return true;
      final date = createdAt.toDate();
      return date.isBefore(lastMonthEnd);
    }).length;

    // Total verified users (akumulatif sampai bulan dipilih)
    final totalVerifiedUntilMonth = allUsers.docs.where((doc) {
      final data = doc.data();
      if (data['isVerified'] != true) return false;

      final verifiedAt = data['verifiedAt'] as Timestamp?;
      if (verifiedAt == null) return true; // Include verified user tanpa verifiedAt

      final date = verifiedAt.toDate();
      return date.isBefore(currentMonthEnd);
    }).length;

    final totalVerifiedUntilLastMonth = allUsers.docs.where((doc) {
      final data = doc.data();
      if (data['isVerified'] != true) return false;

      final verifiedAt = data['verifiedAt'] as Timestamp?;
      if (verifiedAt == null) return true;

      final date = verifiedAt.toDate();
      return date.isBefore(lastMonthEnd);
    }).length;

    // Helper function untuk menghitung growth percentage
    double calculateGrowth(double current, double previous) {
      if (previous == 0) return current > 0 ? 100.0 : 0.0;
      return ((current - previous) / previous) * 100.0;
    }

    print('📊 Monthly analysis complete');

    return {
      // Data bulan dipilih
      'totalTransactions': currentMonthTx.length,
      'completedTransactions': currentCompletedTx.length,
      'totalRevenue': currentRevenue,
      'newUsers': currentMonthUsers.length, // user baru bulan ini
      'newVerifiedUsers': currentMonthVerified.length, // user yang verified bulan ini
      'totalUsersAccumulated': totalUsersUntilMonth, // total akumulatif
      'totalVerifiedAccumulated': totalVerifiedUntilMonth, // total verified akumulatif

      // Data bulan lalu untuk perbandingan
      'lastMonthTransactions': lastMonthTx.length,
      'lastMonthCompleted': lastMonthCompletedTx.length,
      'lastMonthRevenue': lastMonthRevenue,
      'lastMonthNewUsers': lastMonthUsers.length,
      'lastMonthNewVerified': lastMonthVerified.length,
      'lastMonthTotalUsers': totalUsersUntilLastMonth,
      'lastMonthTotalVerified': totalVerifiedUntilLastMonth,

      // Growth percentages
      'transactionGrowth': calculateGrowth(currentMonthTx.length.toDouble(), lastMonthTx.length.toDouble()),
      'completedGrowth': calculateGrowth(currentCompletedTx.length.toDouble(), lastMonthCompletedTx.length.toDouble()),
      'revenueGrowth': calculateGrowth(currentRevenue, lastMonthRevenue),
      'userGrowth': calculateGrowth(currentMonthUsers.length.toDouble(), lastMonthUsers.length.toDouble()),
      'verifiedGrowth': calculateGrowth(currentMonthVerified.length.toDouble(), lastMonthVerified.length.toDouble()),
      'userAccumulatedGrowth': calculateGrowth(totalUsersUntilMonth.toDouble(), totalUsersUntilLastMonth.toDouble()),
      'verifiedAccumulatedGrowth': calculateGrowth(totalVerifiedUntilMonth.toDouble(), totalVerifiedUntilLastMonth.toDouble()),

      // Metadata
      'selectedMonth': selectedMonth,
    };
  }catch (e) {
    print('❌ Monthly report error: $e');
    rethrow;
  }
});


