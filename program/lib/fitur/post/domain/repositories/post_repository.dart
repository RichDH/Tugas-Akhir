import 'package:program/fitur/post/domain/entities/post.dart'; // Sesuaikan nama_project_anda

abstract class PostRepository {
  Future<void> createPost(Post post);
  Future<List<String>> uploadPostImages(List<String> imagePaths, String userId);
  Stream<List<Post>> getPosts(); // Metode untuk mendapatkan stream postingan
// Tambahkan metode lain seperti update, delete, get single post, dll.
}