import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/ads/data/repositories/ads_package_repository.dart';
import 'package:program/fitur/ads/domain/entities/ads_package.dart';

import '../../domain/entities/user_ads.dart';

// Repository provider
final adsPackageRepositoryProvider = Provider<AdsPackageRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return AdsPackageRepository(firestore);
});

// Stream semua ads packages untuk admin
final allAdsPackagesProvider = StreamProvider.autoDispose<List<AdsPackage>>((ref) {
  final repository = ref.watch(adsPackageRepositoryProvider);
  return repository.getAllAdsPackages();
});

// Stream active packages untuk user
final activeAdsPackagesProvider = StreamProvider.autoDispose<List<AdsPackage>>((ref) {
  final repository = ref.watch(adsPackageRepositoryProvider);
  return repository.getActivePackages();
});

// State untuk manage package updates
class AdsPackageFormState {
  final bool isLoading;
  final String? error;
  final bool success;

  const AdsPackageFormState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  AdsPackageFormState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
  }) {
    return AdsPackageFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

// Notifier untuk manage package actions
class AdsPackageNotifier extends StateNotifier<AdsPackageFormState> {
  final AdsPackageRepository _repository;

  AdsPackageNotifier(this._repository) : super(const AdsPackageFormState());

  Future<void> updatePackage(AdsPackage package) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      await _repository.updatePackage(package);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createDefaultPackages(String adminUid) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      await _repository.createDefaultPackages(adminUid);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearState() {
    state = const AdsPackageFormState();
  }
}

final adsPackageNotifierProvider = StateNotifierProvider.autoDispose<AdsPackageNotifier, AdsPackageFormState>((ref) {
  final repository = ref.watch(adsPackageRepositoryProvider);
  return AdsPackageNotifier(repository);
});

// ✅ PERBAIKAN: Get user's eligible posts untuk ads
final userEligiblePostsForAdsProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snap) {
    return snap.docs.where((doc) {
      final data = doc.data();

      // ✅ FILTER 1: Cek deleted field (support post lama tanpa field deleted)
      final hasDeletedField = data.containsKey('deleted');
      final isDeleted = hasDeletedField ? (data['deleted'] == true) : false;
      if (isDeleted) return false;

      // ✅ FILTER 2: Bukan request
      final type = data['type'] as String?;
      if (type == 'request') return false;

      // ✅ FILTER 3: Cek ads aktif (support post lama tanpa field ads)
      final hasAdsLevel = data.containsKey('adsLevel');
      final hasAdsExpiry = data.containsKey('adsExpiredAt');

      if (!hasAdsLevel || !hasAdsExpiry) {
        // Post lama tanpa field ads = eligible
        return true;
      }

      final adsLevel = data['adsLevel'] as int?;
      final adsExpiredAt = data['adsExpiredAt'] as Timestamp?;

      // Jika tidak ada ads level atau sudah expired = eligible
      if (adsLevel == null || adsExpiredAt == null) {
        return true;
      }

      // Cek apakah ads sudah expired
      final expiry = adsExpiredAt.toDate();
      final isExpired = DateTime.now().isAfter(expiry);

      return isExpired; // eligible jika ads sudah expired

    }).map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'] ?? 'Tanpa Judul',
        'imageUrls': (data['imageUrls'] as List?)?.cast<String>() ?? <String>[],
        'videoUrl': data['videoUrl'] as String?,
        'price': data['price'],
        'type': data['type'] ?? 'jastip',
        'createdAt': data['createdAt'] as Timestamp?,
        // ✅ DEBUG INFO: tampilkan status ads untuk debugging
        'hasAds': data.containsKey('adsLevel'),
        'adsLevel': data['adsLevel'],
        'adsExpiredAt': data['adsExpiredAt'],
      };
    }).toList();
  });
});


// User ads history
final userAdsHistoryProvider = StreamProvider.autoDispose.family<List<UserAds>, String>((ref, userId) {
  final fs = ref.watch(firebaseFirestoreProvider);
  return fs
      .collection('user_ads')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => UserAds.fromFirestore(doc)).toList());
});
