import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/core/location/locationService.dart' as loc;
import '../../../post/domain/entities/post.dart';
import 'dart:math' as math;
import 'package:program/core/location/locationService.dart';
import '../../../search_explore/domain/entities/search_filter.dart';

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

final searchFilterProvider = StateProvider.autoDispose<SearchFilter>((ref) => const SearchFilter());

// ✅ PERBAIKAN: postSearchProvider yang kompatibel dengan post lama
final postSearchProvider = StreamProvider.autoDispose<List<Post>>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final query = ref.watch(searchQueryProvider);
  final filter = ref.watch(searchFilterProvider);

  print('🔍 Searching posts with query: "$query"');
  print('🔧 Active filter: $filter');

  // ✅ PERUBAHAN: Query yang lebih sederhana tanpa where clause untuk deleted
  // dan gunakan createdAt untuk orderBy
  return firestore
      .collection('posts')
      .orderBy('createdAt', descending: true) // ✅ Ganti dari updatedAt ke createdAt
      .limit(200) // ✅ Ambil lebih banyak karena akan ada filtering manual
      .snapshots()
      .map((snapshot) {

    print('📦 Total posts from Firestore: ${snapshot.docs.length}');

    List<Post> posts = [];

    for (final doc in snapshot.docs) {
      try {
        final post = Post.fromFirestore(doc);

        // ✅ PERUBAHAN: Manual filtering untuk deleted - include post tanpa field deleted
        final isDeleted = post.deleted; // Post.fromFirestore sudah handle default false
        if (isDeleted) {
          print('🗑️ Skipping deleted post: ${post.title}');
          continue; // Skip post yang deleted = true
        }

        bool passFilter = true;

        // ✅ Search keyword - lebih fleksibel
        if (query.isNotEmpty) {
          final queryLower = query.toLowerCase().trim();
          final titleLower = post.title.toLowerCase();
          final descLower = post.description?.toLowerCase() ?? '';
          final brandLower = post.brand?.toLowerCase() ?? '';
          final categoryLower = post.category?.toLowerCase() ?? '';

          // Cek apakah keyword ada di title, description, brand, atau category
          final matchesKeyword = titleLower.contains(queryLower) ||
              descLower.contains(queryLower) ||
              brandLower.contains(queryLower) ||
              categoryLower.contains(queryLower);

          if (!matchesKeyword) {
            passFilter = false;
            print('❌ Post "${post.title}" tidak cocok dengan keyword "$query"');
          } else {
            print('✅ Post "${post.title}" cocok dengan keyword "$query"');
          }
        }

        // ✅ Apply filters hanya jika masih pass
        if (passFilter) {
          // Filter brand - gunakan contains, bukan exact match
          if (filter.brand?.isNotEmpty == true && passFilter) {
            final postBrand = post.brand?.toLowerCase() ?? '';
            final filterBrand = filter.brand!.toLowerCase();
            if (!postBrand.contains(filterBrand)) {
              passFilter = false;
              print('❌ Brand filter: "${post.brand}" tidak mengandung "${filter.brand}"');
            }
          }

          // Filter price range
          if (filter.minPrice != null && passFilter) {
            if (post.price == null || post.price! < filter.minPrice!) {
              passFilter = false;
              print('❌ Price filter: ${post.price} kurang dari ${filter.minPrice}');
            }
          }

          if (filter.maxPrice != null && passFilter) {
            if (post.price == null || post.price! > filter.maxPrice!) {
              passFilter = false;
              print('❌ Price filter: ${post.price} lebih dari ${filter.maxPrice}');
            }
          }

          // Filter category - exact match untuk kategori
          if (filter.category?.isNotEmpty == true && passFilter) {
            if (post.category != filter.category) {
              passFilter = false;
              print('❌ Category filter: "${post.category}" != "${filter.category}"');
            }
          }

          // ✅ Filter location - gunakan contains untuk lebih fleksibel
          if (filter.location?.isNotEmpty == true && passFilter) {
            final postLocation = post.location?.toLowerCase() ?? '';
            final filterLocation = filter.location!.toLowerCase();
            if (!postLocation.contains(filterLocation)) {
              passFilter = false;
              print('❌ Location filter: "${post.location}" tidak mengandung "${filter.location}"');
            }
          }
        }

        if (passFilter) {
          posts.add(post);
          print('✅ Post "${post.title}" lolos semua filter');
        }

      } catch (e) {
        print('❌ Error parsing post ${doc.id}: $e');
        continue;
      }
    }

    print('✅ Filtered posts result: ${posts.length}');

    // Sort berdasarkan relevansi - posts yang cocok dengan keyword di title diprioritaskan
    if (query.isNotEmpty) {
      final queryLower = query.toLowerCase().trim();
      posts.sort((a, b) {
        final aTitleMatch = a.title.toLowerCase().contains(queryLower);
        final bTitleMatch = b.title.toLowerCase().contains(queryLower);

        if (aTitleMatch && !bTitleMatch) return -1;
        if (!aTitleMatch && bTitleMatch) return 1;

        // Jika sama-sama cocok atau tidak cocok, sort by created date
        return b.createdAt.compareTo(a.createdAt);
      });
    } else {
      // Jika tidak ada query, sort by created date
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return posts;
  });
});


// ✅ Provider untuk filtered user search yang diperbaiki
final filteredUserSearchProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, query) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final filter = ref.watch(searchFilterProvider);

  if (query.isEmpty) {
    return Stream.empty();
  }

  return firestore
      .collection('users')
      .where('username', isGreaterThanOrEqualTo: query)
      .where('username', isLessThanOrEqualTo: '$query\uf8ff')
      .limit(20) // Ambil lebih banyak untuk di-filter
      .snapshots()
      .map((snapshot) {

    List<Map<String, dynamic>> users = snapshot.docs
        .where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Filter deleted users
      if (data['deleted'] == true) return false;

      // Apply isVerified filter
      if (filter.isVerified != null) {
        final userVerified = data['isVerified'] as bool? ?? false;
        if (userVerified != filter.isVerified) return false;
      }

      return true;
    })
        .map((doc) => {
      'id': doc.id,
      ...doc.data() as Map<String, dynamic>
    })
        .toList();

    return users;
  });
});

final locationBasedPostSearchProvider = FutureProvider.autoDispose.family<List<Post>, String>((ref, locationName) async {
  if (locationName.isEmpty) return [];

  final firestore = ref.watch(firebaseFirestoreProvider);

  try {
    // Cari koordinat lokasi menggunakan LocationService
    final locations = await LocationService.searchLocations(locationName);
    if (locations.isEmpty) return [];

    final targetLocation = locations.first;
    const radiusKm = 50.0;

    // ✅ PERUBAHAN: Query tanpa where clause untuk deleted
    final snapshot = await firestore
        .collection('posts')
        .orderBy('createdAt', descending: true) // ✅ Ganti ke createdAt
        .limit(200) // Ambil lebih banyak untuk filtering manual
        .get();

    List<Post> nearbyPosts = [];

    for (final doc in snapshot.docs) {
      try {
        final post = Post.fromFirestore(doc);

        // ✅ Manual filter deleted
        if (post.deleted) continue;

        // Check jika ada koordinat dan valid
        if (post.locationLat != null &&
            post.locationLng != null &&
            post.locationLat != 0 &&
            post.locationLng != 0) {

          final distance = _calculateDistance(
            targetLocation.lat,
            targetLocation.lng,
            post.locationLat!,
            post.locationLng!,
          );

          if (distance <= radiusKm) {
            nearbyPosts.add(post);
          }
        }
      } catch (e) {
        print('Error parsing post ${doc.id} for location search: $e');
        continue;
      }
    }

    // Sort by distance
    nearbyPosts.sort((a, b) {
      final distanceA = _calculateDistance(
        targetLocation.lat, targetLocation.lng,
        a.locationLat!, a.locationLng!,
      );
      final distanceB = _calculateDistance(
        targetLocation.lat, targetLocation.lng,
        b.locationLat!, b.locationLng!,
      );
      return distanceA.compareTo(distanceB);
    });

    return nearbyPosts;
  } catch (e) {
    print('Error in location-based search: $e');
    return [];
  }
});


// Fungsi untuk menghitung jarak antara dua koordinat (Haversine formula)
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371; // Earth radius in kilometers

  final double dLat = _degreesToRadians(lat2 - lat1);
  final double dLon = _degreesToRadians(lon2 - lon1);

  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
          math.sin(dLon / 2) * math.sin(dLon / 2);

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadius * c;
}

double _degreesToRadians(double degrees) {
  return degrees * (math.pi / 180);
}
