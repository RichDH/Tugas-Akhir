import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart'; // Import provider Firebase
import 'package:program/fitur/post/data/repositories/post_repository_impl.dart'; // Import implementasi repository
import 'package:program/fitur/post/domain/repositories/post_repository.dart'; // Import interface repository
import 'package:program/fitur/post/domain/entities/post.dart'; // Import entity Post
import 'package:firebase_auth/firebase_auth.dart'; // Untuk mendapatkan UID user saat ini
import 'package:cloud_firestore/cloud_firestore.dart'; // Untuk Timestamp dan username

// Provider untuk PostRepository
// Diperbaiki: PostRepositoryImpl sekarang hanya memerlukan firestore
final postRepositoryProvider = Provider<PostRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return PostRepositoryImpl(firestore);
});

// StateNotifier untuk mengelola state dan logika di halaman Create Post
class CreatePostNotifier extends StateNotifier<AsyncValue<void>> {
  final PostRepository _postRepository;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CreatePostNotifier(this._postRepository, this._auth, this._firestore) : super(const AsyncValue.data(null));

  Future<void> createPost({
    required PostType type,
    required String title,
    required String description,
    required String category,
    double? price,
    required String location,
    required List<String> imagePaths,
    String? videoPath, // Tetap ada jika Anda berencana mengimplementasikannya
    String? syarat,
    int? batasJumlahOffer,
    Timestamp? deadline,
  }) async {
    state = const AsyncValue.loading();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("Pengguna belum login.");
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final username = userDoc.data()?['username'] as String? ?? 'Pengguna Tidak Dikenal';

      List<String> imageUrls = [];
      if (imagePaths.isNotEmpty) {
        // Memanggil method uploadPostImages dari _postRepository yang sudah menggunakan CloudinaryPublic
        // Atau jika Anda ingin menggunakan method dengan progress:
        // imageUrls = await (_postRepository as PostRepositoryImpl).uploadPostImagesWithProgress(
        //   imagePaths,
        //   user.uid,
        //   onProgress: (current, total, currentImageName) {
        //     print('Uploading $currentImageName: $current/$total');
        //     // Di sini Anda bisa memperbarui UI dengan progress jika diperlukan
        //   },
        // );
        imageUrls = await _postRepository.uploadPostImages(imagePaths, user.uid);
      }

      String? videoUrl;
      // TODO: Implementasi upload video jika diperlukan (mungkin juga menggunakan Cloudinary)

      final newPost = Post(
        id: '', // ID akan di-generate oleh Firestore
        userId: user.uid,
        username: username,
        type: type,
        title: title,
        description: description,
        category: category,
        price: price,
        location: location,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        createdAt: Timestamp.now(),
        syarat: syarat,
        batasJumlahOffer: batasJumlahOffer,
        deadline: deadline,
      );

      await _postRepository.createPost(newPost);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      print('Error creating post in Notifier: $e\n$stack');
      state = AsyncValue.error(e, stack);
      // Pertimbangkan untuk melempar ulang error jika Anda ingin menanganinya lebih lanjut di UI
      // rethrow;
    }
  }
}

// Provider untuk CreatePostNotifier
final createPostProvider = StateNotifierProvider<CreatePostNotifier, AsyncValue<void>>((ref) {
  final postRepository = ref.watch(postRepositoryProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return CreatePostNotifier(postRepository, auth, firestore);
});