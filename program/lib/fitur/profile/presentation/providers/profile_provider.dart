import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../app/providers/firebase_providers.dart'; // Import provider firebase Anda

// Provider ini akan menyediakan stream ke dokumen pengguna yang sedang login
final userProfileStreamProvider = StreamProvider.autoDispose<DocumentSnapshot>((ref) {
  // Dapatkan instance Firestore dan Auth dari provider global
  final firestore = ref.watch(firebaseFirestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);

  // Dapatkan pengguna yang sedang login
  final user = auth.currentUser;

  // Jika tidak ada pengguna yang login, kembalikan stream kosong
  if (user == null) {
    return Stream.error('Pengguna tidak ditemukan atau belum login.');
  }

  // Jika ada, kembalikan stream ke dokumen pengguna di koleksi 'users'
  return firestore.collection('users').doc(user.uid).snapshots();
});