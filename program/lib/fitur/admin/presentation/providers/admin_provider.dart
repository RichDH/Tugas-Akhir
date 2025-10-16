import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';

// Provider untuk mendapatkan stream pengajuan verifikasi yang 'pending'
final pendingVerificationsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final firestore = ref.read(firebaseFirestoreProvider);
  return firestore
      .collection('users')
      .where('verificationStatus', isEqualTo: 'pending')
      .snapshots();
});

// State Notifier untuk aksi admin
class AdminNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  AdminNotifier(this._ref) : super(const AsyncData(null));

  Future<void> updateVerificationStatus(String userId, String newStatus) async {
    state = const AsyncLoading();
    final firestore = _ref.read(firebaseFirestoreProvider);
    try {
      await firestore.collection('users').doc(userId).update({
        'verificationStatus': newStatus,
      });
      await firestore.collection('users').doc(userId).update({
        'isVerified': true,
      });
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }
}

final adminProvider = StateNotifierProvider<AdminNotifier, AsyncValue<void>>((ref) {
  return AdminNotifier(ref);
});