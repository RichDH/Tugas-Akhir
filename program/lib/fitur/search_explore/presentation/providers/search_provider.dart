import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';

import '../../../post/domain/entities/post.dart';

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

final suggestedAdsProvider = StreamProvider.autoDispose<List<Post>>((ref) {
  final fs = ref.watch(firebaseFirestoreProvider);

  DateTime adsAppliedAt(Map<String, dynamic> m) {
    final ts = m['adsStartDate'] as Timestamp?;
    if (ts != null) return ts.toDate();
    final up = m['updatedAt'] as Timestamp?;
    if (up != null) return up.toDate();
    final cr = m['createdAt'] as Timestamp?;
    return cr?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  return fs.collection('posts').snapshots().map((snap) {
    final now = DateTime.now();

    final adsPosts = snap.docs.where((doc) {
      final m = doc.data();
      // Filter deleted (support post lama)
      final isDeleted = (m['deleted'] == true);
      if (isDeleted) return false;

      // Ads aktif: ada adsLevel & adsExpiredAt dan belum lewat
      final level = m['adsLevel'] as int?;
      final expiredAt = m['adsExpiredAt'] as Timestamp?;
      if (level == null || expiredAt == null) return false;
      return now.isBefore(expiredAt.toDate());
    }).map((doc) {
      final m = doc.data();
      // Bangun Post minimal memakai Post.fromFirestore jika sudah mendukung ads fields
      return Post.fromFirestore(doc);
    }).toList();

    // Urutkan sesuai aturan
    adsPosts.sort((a, b) {
      final la = a.adsLevel ?? 0;
      final lb = b.adsLevel ?? 0;
      if (la != lb) return lb.compareTo(la); // level desc

      final ta = a.adsStartDate != null
          ? a.adsStartDate!.toDate()
          : (a.updatedAt.toDate());
      final tb = b.adsStartDate != null
          ? b.adsStartDate!.toDate()
          : (b.updatedAt.toDate());
      return tb.compareTo(ta); // terbaru dulu
    });

    // Batasi misal 10 untuk suggested
    if (adsPosts.length > 10) {
      return adsPosts.sublist(0, 10);
    }
    return adsPosts;
  });
});