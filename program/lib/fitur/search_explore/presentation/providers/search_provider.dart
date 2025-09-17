import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';

// Provider untuk menyimpan query pencarian saat ini
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// Provider untuk melakukan pencarian pengguna di Firestore
final userSearchProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, query) {
  final firestore = ref.watch(firebaseFirestoreProvider);

  // Jika query kosong, kembalikan stream kosong agar tidak menampilkan apa-apa
  if (query.isEmpty) {
    // PERBAIKAN: Gunakan Stream.empty()
    return Stream.empty();
  }

  // Melakukan query 'starts with' pada field username
  return firestore
      .collection('users')
      .where('username', isGreaterThanOrEqualTo: query)
      .where('username', isLessThanOrEqualTo: '$query\uf8ff')
      .limit(10)
      .snapshots();
});