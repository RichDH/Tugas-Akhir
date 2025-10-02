import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

// Sama seperti PostRepository, kita bisa buat VerificationRepository
abstract class VerificationRepository {
  Future<String> uploadVerificationImage(String imagePath, String userId, String docType);
  Future<void> updateUserVerificationStatus(String userId, String ktpUrl, String selfieUrl);
}

class VerificationRepositoryImpl implements VerificationRepository {
  final FirebaseFirestore _firestore;
  final CloudinaryPublic _cloudinary;

  VerificationRepositoryImpl(this._firestore)
  // Menggunakan kredensial yang sama persis seperti di PostRepositoryImpl Anda
      : _cloudinary = CloudinaryPublic('ds656gqe2', 'ngoper_unsigned_upload', cache: false);

  @override
  Future<String> uploadVerificationImage(String imagePath, String userId, String docType) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniquePublicId = '${docType}_$timestamp';

    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(imagePath,
          resourceType: CloudinaryResourceType.Image,
          folder: 'verification_docs/$userId',
          publicId: uniquePublicId, // ktp atau selfie_ktp
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print('Error uploading verification image: $e');
      throw Exception('Gagal mengunggah gambar verifikasi.');
    }
  }

  @override
  Future<void> updateUserVerificationStatus(String userId, String ktpUrl, String selfieUrl) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'verificationStatus': 'pending',
        'ktpImageUrl': ktpUrl,
        'selfieKtpImageUrl': selfieUrl,
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user verification status: $e');
      throw Exception('Gagal memperbarui status verifikasi.');
    }
  }
}

// Provider untuk VerificationRepository
final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return VerificationRepositoryImpl(firestore);
});


// Notifier sekarang menjadi lebih bersih
class VerificationState {
  final bool isLoading;
  final String? error;
  VerificationState({this.isLoading = false, this.error});
}

class VerificationNotifier extends StateNotifier<VerificationState> {
  final VerificationRepository _repository;
  final Ref _ref;

  VerificationNotifier(this._repository, this._ref) : super(VerificationState());

  Future<void> submitVerification(XFile ktpImage, XFile selfieImage) async {
    state = VerificationState(isLoading: true);
    final user = _ref.read(firebaseAuthProvider).currentUser;

    if (user == null) {
      state = VerificationState(error: "User tidak login.");
      return;
    }

    try {
      // 1. Upload foto KTP
      final ktpUrl = await _repository.uploadVerificationImage(ktpImage.path, user.uid, 'ktp');
      // 2. Upload foto selfie
      final selfieUrl = await _repository.uploadVerificationImage(selfieImage.path, user.uid, 'selfie_ktp');
      // 3. Update Firestore
      await _repository.updateUserVerificationStatus(user.uid, ktpUrl, selfieUrl);

      state = VerificationState(isLoading: false);
    } catch (e) {
      state = VerificationState(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

// Provider untuk Notifier
final verificationProvider = StateNotifierProvider.autoDispose<VerificationNotifier, VerificationState>((ref) {
  final repository = ref.watch(verificationRepositoryProvider);
  return VerificationNotifier(repository, ref);
});