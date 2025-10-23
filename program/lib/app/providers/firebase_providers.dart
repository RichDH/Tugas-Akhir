import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Provider untuk mendapatkan instance FirebaseAuth
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// Provider untuk mendapatkan instance FirebaseFirestore
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

// Provider untuk mendengarkan perubahan status autentikasi
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// ✅ TAMBAHKAN PROVIDER UNTUK CURRENT USER
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

// ✅ PROVIDER UNTUK CEK APAKAH USER SUDAH LOGIN
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

final currentUserDocStreamProvider = StreamProvider<DocumentSnapshot?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null); // Return null stream jika tidak login

  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore.collection('users').doc(user.uid).snapshots();
});
