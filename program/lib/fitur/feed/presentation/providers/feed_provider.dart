import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/fitur/post/domain/entities/post.dart'; // Import Post entity
import 'package:program/fitur/post/domain/repositories/post_repository.dart'; // Import PostRepository
import 'package:program/fitur/post/data/repositories/post_repository_impl.dart'; // Import implementasi repository
import 'package:program/app/providers/firebase_providers.dart'; // Import provider Firestore dan Storage
import 'package:program/fitur/post/presentation/providers/post_provider.dart'; // Import postRepositoryProvider

// Provider yang menyediakan stream daftar postingan dari Firestore
final postsStreamProvider = StreamProvider<List<Post>>((ref) {
  final postRepository = ref.watch(postRepositoryProvider); // Ambil repository dari provider

  // Mengembalikan stream dari repository
  return postRepository.getPosts();
});

// Anda mungkin perlu provider lain di sini nanti, misal untuk data Stories
// final storiesStreamProvider = StreamProvider<List<Story>>((ref) { ... });