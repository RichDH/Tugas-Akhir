// profile_provider.dart - PERBAIKAN SINTAKS YANG BENAR
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';

// Provider untuk data dasar profil
final userProfileStreamProvider = StreamProvider.autoDispose.family<DocumentSnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore.collection('users').doc(userId).snapshots();
});

// Provider untuk mengambil postingan JASTIP
final userPostsStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .where('type', isEqualTo: 'jastip')
      .orderBy('createdAt', descending: true)
      .snapshots();
});

// Provider untuk mengambil postingan REQUEST
final userRequestsStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .where('type', isEqualTo: 'request')
      .orderBy('createdAt', descending: true)
      .snapshots();
});

// Provider untuk mengambil SHORTS
final userShortsStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .where('type', isEqualTo: 'short')
      .orderBy('createdAt', descending: true)
      .snapshots();
});

// Provider untuk riwayat LIVE
final userLiveHistoryStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('live_sessions')
      .where('hostId', isEqualTo: userId)
      .where('status', isEqualTo: 'ended')
      .orderBy('createdAt', descending: true)
      .snapshots();
});

// ✅ FIX: Provider untuk followers count (realtime)
final followersCountStreamProvider = StreamProvider.autoDispose.family<int, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('users')
      .doc(userId)
      .collection('followers')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

// ✅ FIX: Provider untuk following count (realtime)
final followingCountStreamProvider = StreamProvider.autoDispose.family<int, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('users')
      .doc(userId)
      .collection('following')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

// ✅ FIX: Provider untuk cek apakah user sedang mengikuti target user
final isFollowingProvider = StreamProvider.autoDispose.family<bool, String>((ref, targetUserId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final currentUser = ref.watch(firebaseAuthProvider).currentUser;

  if (currentUser == null) {
    return Stream.value(false);
  }

  return firestore
      .collection('users')
      .doc(currentUser.uid)
      .collection('following')
      .doc(targetUserId)
      .snapshots()
      .map((snapshot) => snapshot.exists);
});

// ✅ FIX: StateNotifier untuk handle follow/unfollow actions
class FollowNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  FollowNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> toggleFollow(String targetUserId) async {
    final firestore = _ref.read(firebaseFirestoreProvider);
    final currentUser = _ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null || currentUser.uid == targetUserId) {
      return; // Tidak bisa follow diri sendiri
    }

    state = const AsyncValue.loading();

    try {
      final followerDocRef = firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUser.uid);

      final followingDocRef = firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(targetUserId);

      // ✅ FIX: Gunakan transaction untuk menjaga konsistensi
      await firestore.runTransaction((transaction) async {
        final followerSnapshot = await transaction.get(followerDocRef);

        if (followerSnapshot.exists) {
          // Unfollow: hapus dari kedua collection
          transaction.delete(followerDocRef);
          transaction.delete(followingDocRef);
        } else {
          // Follow: tambah ke kedua collection
          transaction.set(followerDocRef, {
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.set(followingDocRef, {
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

// ✅ FIX: Provider untuk follow actions
final followProvider = StateNotifierProvider.autoDispose<FollowNotifier, AsyncValue<void>>((ref) {
  return FollowNotifier(ref);
});

// Provider lama untuk backward compatibility (akan dihapus nanti)
final followersCountProvider = FutureProvider.autoDispose.family<int, String>((ref, userId) async {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final snapshot = await firestore.collection('users').doc(userId).collection('followers').get();
  return snapshot.docs.length;
});

final followingCountProvider = FutureProvider.autoDispose.family<int, String>((ref, userId) async {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final snapshot = await firestore.collection('users').doc(userId).collection('following').get();
  return snapshot.docs.length;
});
