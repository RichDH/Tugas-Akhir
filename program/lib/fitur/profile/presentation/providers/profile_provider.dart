import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';

// Provider ini tetap sama, untuk data dasar profil
final userProfileStreamProvider = StreamProvider.autoDispose.family<DocumentSnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore.collection('users').doc(userId).snapshots();
});

// Provider BARU: Untuk mengambil semua postingan dari seorang pengguna
final userPostsStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots();
});

// Provider BARU: Untuk menghitung jumlah pengikut (followers)
final followersCountProvider = FutureProvider.autoDispose.family<int, String>((ref, userId) async {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final snapshot = await firestore
      .collection('users')
      .doc(userId)
      .collection('followers')
      .get();
  return snapshot.docs.length;
});

// Provider BARU: Untuk menghitung jumlah yang diikuti (following)
final followingCountProvider = FutureProvider.autoDispose.family<int, String>((ref, userId) async {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final snapshot = await firestore
      .collection('users')
      .doc(userId)
      .collection('following')
      .get();
  return snapshot.docs.length;
});