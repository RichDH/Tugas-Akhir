// File: program/lib/fitur/profile/presentation/providers/edit_profile_provider.dart

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class EditProfileState {
  final bool isLoading;
  final String? error;

  EditProfileState({
    this.isLoading = false,
    this.error,
  });

  EditProfileState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return EditProfileState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EditProfileNotifier extends StateNotifier<EditProfileState> {
  final FirebaseFirestore _firestore;
  late CloudinaryPublic _cloudinary;

  EditProfileNotifier(this._firestore) : super(EditProfileState()) {
    // MENGGUNAKAN konfigurasi Cloudinary yang sama seperti di PostRepositoryImpl
    _cloudinary = CloudinaryPublic(
      "ds656gqe2", // Cloud name yang sama
      "ngoper_unsigned_upload", // Upload preset yang sama
      cache: false,
    );
  }

  Future<bool> isUsernameAvailable(String username, String currentUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return true;
      }

      for (var doc in querySnapshot.docs) {
        if (doc.id != currentUserId) {
          return false;
        }
      }

      return true;
    } catch (e) {
      throw Exception('Gagal memeriksa ketersediaan username');
    }
  }

  // BARU: Method untuk upload profile image ke Cloudinary
  Future<String?> _uploadProfileImage(File imageFile, String userId) async {
    try {
      final folderPath = "profile_pictures/$userId";

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folderPath,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      if (response.secureUrl.isNotEmpty) {
        return response.secureUrl;
      }

      throw Exception('URL upload kosong');
    } catch (e) {
      throw Exception('Gagal upload gambar profil: $e');
    }
  }

  Future<void> updateProfile(
      String userId,
      Map<String, dynamic> profileData,
      bool needsUsernameCheck,
      File? profileImageFile, // BARU: Parameter untuk image
      ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Cek username jika perlu
      if (needsUsernameCheck) {
        final isAvailable = await isUsernameAvailable(
          profileData['username'],
          userId,
        );

        if (!isAvailable) {
          state = state.copyWith(
            isLoading: false,
            error: 'Username sudah digunakan, pilih username lain',
          );
          return;
        }
      }

      // BARU: Upload profile image jika ada
      String? profileImageUrl;
      if (profileImageFile != null) {
        profileImageUrl = await _uploadProfileImage(profileImageFile, userId);
        profileData['profileImageUrl'] = profileImageUrl;
      }

      // Update profil di Firestore
      await _firestore.collection('users').doc(userId).update({
        ...profileData,
        'updatedAt': Timestamp.now(),
      });

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }
}

final editProfileProvider = StateNotifierProvider<EditProfileNotifier, EditProfileState>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return EditProfileNotifier(firestore);
});
