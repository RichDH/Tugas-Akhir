import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserService {
  final FirebaseFirestore _db;
  AdminUserService(this._db);

  // Soft delete user + soft delete semua post milik user
  Future<void> closeUserAccount({
    required String targetUserId,
    String? reason,
    String? closedBy,
  }) async {
    final userRef = _db.collection('users').doc(targetUserId);

    // 1) Soft delete user (transaksi kecil)
    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) throw Exception('User tidak ditemukan');
      tx.update(userRef, {
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'closedReason': reason ?? 'pelanggaran kebijakan',
        'closedBy': closedBy ?? 'admin',
      });
    });

    // 2) Soft delete post user (chunked, karena limit batch 500)
    // posts koleksi utama
    const pageSize = 300;
    Query nextQuery = _db.collection('posts').where('userId', isEqualTo: targetUserId).limit(pageSize);

    while (true) {
      final page = await nextQuery.get();
      if (page.docs.isEmpty) break;

      final batch = _db.batch();
      for (final d in page.docs) {
        batch.update(d.reference, {
          'deleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (page.docs.length < pageSize) break;
      final last = page.docs.last;
      nextQuery = _db.collection('posts')
          .where('userId', isEqualTo: targetUserId)
          .startAfterDocument(last)
          .limit(pageSize);
    }
  }
}
