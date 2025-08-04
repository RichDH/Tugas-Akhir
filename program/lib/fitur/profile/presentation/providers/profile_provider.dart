import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';

// Provider untuk data dasar profil
final userProfileStreamProvider = StreamProvider.autoDispose.family<DocumentSnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore.collection('users').doc(userId).snapshots();
});

// PERBAIKAN: Provider untuk mengambil postingan JASTIP
final userPostsStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .where('type', isEqualTo: 'jastip') // Menggunakan field 'type' dan nilai 'jastip'
      .orderBy('createdAt', descending: true)
      .snapshots();
});

// PERBAIKAN: Provider untuk mengambil postingan REQUEST
final userRequestsStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .where('type', isEqualTo: 'request') // Menggunakan field 'type' dan nilai 'request'
      .orderBy('createdAt', descending: true)
      .snapshots();
});

// PERBAIKAN: Provider untuk mengambil SHORTS
final userShortsStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, userId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('posts') // Asumsi shorts juga ada di koleksi 'posts'
      .where('userId', isEqualTo: userId)
      .where('type', isEqualTo: 'short') // Menggunakan field 'type' dan nilai 'short'
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

// Provider untuk statistik (followers/following)
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