import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../post/domain/entities/post.dart';
import '../../../post/presentation/providers/post_provider.dart';

/// Mengurutkan feed:
/// 1) Kelompok A: post dengan ads aktif (hasActiveAds == true)
///    - diurutkan level tertinggi -> terendah
///    - jika level sama, adsStartDate terbaru -> lama (fallback ke updatedAt/createdAt bila null)
/// 2) Kelompok B: post lain (tanpa ads aktif)
///    - diurutkan createdAt terbaru -> lama
/// 3) Gabungkan A + B (tanpa duplikasi)
final feedProvider = Provider<AsyncValue<List<Post>>>((ref) {
  final raw = ref.watch(postsProvider);

  return raw.whenData((posts) {
    final now = DateTime.now();

    // Helper dapatkan waktu ads applied (pakai adsStartDate bila ada, fallback ke updatedAt/createdAt)
    DateTime _adsAppliedAt(Post p) {
      if (p.adsStartDate != null) return p.adsStartDate!.toDate();
      // fallback agar stabil walaupun adsStartDate belum ada di data lama
      if (p.updatedAt != null) return p.updatedAt.toDate();
      return p.createdAt.toDate();
    }

    // Helper dapatkan createdAt date
    DateTime _createdAt(Post p) => p.createdAt.toDate();

    // Kelompokkan
    final withAds = <Post>[];
    final withoutAds = <Post>[];

    for (final p in posts) {
      final hasActiveAds = (p.adsLevel != null && p.adsExpiredAt != null && now.isBefore(p.adsExpiredAt!.toDate()));
      if (hasActiveAds) {
        withAds.add(p);
      } else {
        withoutAds.add(p);
      }
    }

    // Sort kelompok A (ads aktif)
    withAds.sort((a, b) {
      final la = a.adsLevel ?? 0;
      final lb = b.adsLevel ?? 0;
      if (la != lb) return lb.compareTo(la); // level desc

      final ta = _adsAppliedAt(a);
      final tb = _adsAppliedAt(b);
      return tb.compareTo(ta); // terbaru dulu
    });

    // Sort kelompok B (tanpa ads)
    withoutAds.sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));

    // Gabungkan
    final combined = <Post>[];
    final seen = <String>{};

    for (final p in withAds) {
      if (!seen.contains(p.id)) {
        combined.add(p);
        seen.add(p.id);
      }
    }
    for (final p in withoutAds) {
      if (!seen.contains(p.id)) {
        combined.add(p);
        seen.add(p.id);
      }
    }

    return combined;
  });
});
