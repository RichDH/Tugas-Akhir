import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';

// Provider untuk menyimpan query pencarian saat ini
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final userSearchProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, query) {
  final firestore = ref.watch(firebaseFirestoreProvider);

  if (query.isEmpty) {
    return Stream.empty();
  }

  return firestore
      .collection('users')
      .where('username', isGreaterThanOrEqualTo: query)
      .where('username', isLessThanOrEqualTo: '$query\uf8ff')
      .limit(10)
      .snapshots();
});