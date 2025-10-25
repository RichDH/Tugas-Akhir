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

final searchFilterProvider = StateProvider.autoDispose<SearchFilter>((ref) => const SearchFilter());

// Provider untuk post search dengan filter
final postSearchProvider = StreamProvider.autoDispose.family<List<Post>, String>((ref, query) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final filter = ref.watch(searchFilterProvider);

  if (query.isEmpty) {
    return Stream.empty();
  }

  // Base query untuk posts
  Query postQuery = firestore
      .collection('posts')
      .where('deleted', isEqualTo: false);

  // Filter berdasarkan title atau description yang mengandung query
  // Karena Firestore tidak support full-text search, kita gunakan array-contains-any
  // atau filter di client side

  return postQuery.snapshots().map((snapshot) {
    List<Post> posts = snapshot.docs
        .map((doc) => Post.fromFirestore(doc))
        .where((post) {
      // Filter berdasarkan query text
      final titleMatch = post.title.toLowerCase().contains(query.toLowerCase());
      final descMatch = post.description?.toLowerCase().contains(query.toLowerCase()) ?? false;
      final brandMatch = post.brand?.toLowerCase().contains(query.toLowerCase()) ?? false;

      if (!titleMatch && !descMatch && !brandMatch) return false;

      // Apply filters
      if (filter.brand?.isNotEmpty == true) {
        if (post.brand?.toLowerCase() != filter.brand!.toLowerCase()) return false;
      }

      if (filter.minPrice != null) {
        if (post.price == null || post.price! < filter.minPrice!) return false;
      }

      if (filter.maxPrice != null) {
        if (post.price == null || post.price! > filter.maxPrice!) return false;
      }

      if (filter.category?.isNotEmpty == true) {
        if (post.category != filter.category) return false;
      }

      return true;
    })
        .toList();

    // Limit hasil ke 3 item
    if (posts.length > 3) {
      posts = posts.sublist(0, 3);
    }

    return posts;
  });
});

// Provider untuk filtered user search
final filteredUserSearchProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, query) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final filter = ref.watch(searchFilterProvider);

  if (query.isEmpty) {
    return Stream.empty();
  }

  Query userQuery = firestore
      .collection('users')
      .where('username', isGreaterThanOrEqualTo: query)
      .where('username', isLessThanOrEqualTo: '$query\uf8ff');

  return userQuery.snapshots().map((snapshot) {
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

    // Limit hasil ke 3 item
    if (users.length > 3) {
      users = users.sublist(0, 3);
    }

    return users;
  });
});

// Provider untuk location-based search
final locationBasedPostSearchProvider = FutureProvider.autoDispose.family<List<Post>, String>((ref, locationName) async {
  if (locationName.isEmpty) return [];

  final firestore = ref.watch(firebaseFirestoreProvider);

  try {
    // Cari koordinat lokasi menggunakan LocationService
    final locations = await LocationService.searchLocations(locationName);
    if (locations.isEmpty) return [];

    final targetLocation = locations.first;
    const radiusKm = 50.0;

    // Query semua posts yang memiliki koordinat
    final snapshot = await firestore
        .collection('posts')
        .where('deleted', isEqualTo: false)
        .where('locationLat', isNotEqualTo: null)
        .where('locationLng', isNotEqualTo: null)
        .get();

    List<Post> nearbyPosts = [];

    for (final doc in snapshot.docs) {
      final post = Post.fromFirestore(doc);

      if (post.locationLat != null && post.locationLng != null) {
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
    }

    // Sort by distance and limit to 3
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

    return nearbyPosts.take(3).toList();
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