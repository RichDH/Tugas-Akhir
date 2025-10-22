import 'package:program/fitur/post/domain/entities/post.dart';

abstract class PostRepository {
  /// Membuat post baru di Firestore
  Future<void> createPost(Post post);
  /// Mengupload gambar post ke Cloudinary
  Future<List<String>> uploadPostImages(List<String> imagePaths, String userId);
  /// Mengupload video post ke Cloudinary (untuk PostType.short)
  Future<String> uploadPostVideo(String videoPath, String userId);
  /// Mendapatkan stream semua post (diurutkan terbaru)
  Stream<List<Post>> getPosts();
  Future<void> updatePost(Post post);
  Future<void> deletePost(String postId);
  Future<Post?> getPostById(String postId);

}