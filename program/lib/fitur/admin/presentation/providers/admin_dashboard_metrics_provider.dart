import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';

import 'admin_provider.dart';

// Total pengguna (realtime)
final dashTotalUsersProvider = StreamProvider.autoDispose<int>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs.collection('users').snapshots().map((s) => s.size);
});

// Pengguna terverifikasi (realtime)
final dashVerifiedUsersProvider = StreamProvider.autoDispose<int>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs.collection('users').where('isVerified', isEqualTo: true).snapshots().map((s) => s.size);
});

// Akun ditutup (realtime) - field 'deleted' == true
final dashClosedAccountsProvider = StreamProvider.autoDispose<int>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs.collection('users').where('deleted', isEqualTo: true).snapshots().map((s) => s.size);
});

// Total transaksi (realtime)
final dashTotalTransactionsProvider = StreamProvider.autoDispose<int>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs.collection('transactions').snapshots().map((s) => s.size);
});

// Nominal transaksi selesai (realtime best-effort; gunakan stream status=completed)
final dashCompletedRevenueProvider = StreamProvider.autoDispose<double>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs.collection('transactions')
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((s) {
    double sum = 0.0;
    for (final d in s.docs) {
      final m = d.data();
      sum += (m['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return sum;
  });
});

// Jumlah posts (deleted=false OR tidak punya field 'deleted')
final dashTotalPostsProvider = StreamProvider.autoDispose<int>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs.collection('posts').snapshots().map((s) {
    int count = 0;
    for (final d in s.docs) {
      final m = d.data();
      final hasDeleted = m.containsKey('deleted');
      final isDeleted = hasDeleted ? (m['deleted'] == true) : false; // lama = dianggap tidak deleted
      if (!isDeleted) count++;
    }
    return count;
  });
});

// Live sessions ongoing
final dashLiveOngoingProvider = StreamProvider.autoDispose<int>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs.collection('live_sessions').where('status', isEqualTo: 'ongoing').snapshots().map((s) => s.size);
});

// Pending verifications (sudah ada di pendingVerificationsStreamProvider) -> wrapping ke int
final dashPendingVerificationsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final snapAsync = ref.watch(pendingVerificationsStreamProvider);
  return snapAsync.when(
    data: (snap) => Stream.value(snap.docs.length),
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
