import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/post/domain/repositories/post_repository.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PostRepositoryImpl implements PostRepository {
  final FirebaseFirestore _firestore;
  late CloudinaryPublic cloudinary;

  // Kredensial Cloudinary
  final String _cloudinaryCloudName = "ds656gqe2";
  final String _cloudinaryUploadPreset = "ngoper_unsigned_upload";

  PostRepositoryImpl(this._firestore) {
    cloudinary = CloudinaryPublic(_cloudinaryCloudName, _cloudinaryUploadPreset, cache: false);
    print("Cloudinary initialized successfully with CloudinaryPublic.");
  }

  @override
  Future<void> createPost(Post post) async {
    try {
      await _firestore.collection('posts').add(post.toFirestore());
      print('Post created successfully in Firestore');
    } catch (e) {
      print('Error creating post: $e');
      throw Exception('Gagal membuat post: $e');
    }
  }

  @override
  Future<List<String>> uploadPostImages(List<String> imagePaths, String userId) async {
    List<String> downloadUrls = [];
    final folderPath = "jastip_posts/$userId";

    for (int i = 0; i < imagePaths.length; i++) {
      String path = imagePaths[i];
      File file = File(path);

      try {
        if (!await file.exists()) {
          throw Exception('File tidak ditemukan: $path');
        }

        print('Uploading image ${i + 1}/${imagePaths.length}: ${file.path}');

        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            file.path,
            folder: folderPath,
            resourceType: CloudinaryResourceType.Image,
          ),
        );

        if (response.secureUrl.isNotEmpty) {
          downloadUrls.add(response.secureUrl);
          print('Image uploaded successfully: ${response.secureUrl}');
        } else {
          throw Exception('Upload gagal: URL kosong');
        }

      } catch (e) {
        print('Error uploading image $path: $e');

        // Backup upload via HTTP
        try {
          String? backupUrl = await _uploadImageManually(file, folderPath);
          if (backupUrl != null) {
            downloadUrls.add(backupUrl);
            print('Image uploaded successfully using manual method: $backupUrl');
          } else {
            throw Exception('Backup upload method juga gagal');
          }
        } catch (backupError) {
          print('Backup upload method failed: $backupError');
          throw Exception('Gagal mengupload gambar: $e');
        }
      }
    }

    if (downloadUrls.isEmpty) {
      throw Exception('Tidak ada gambar yang berhasil diupload');
    }

    return downloadUrls;
  }

  // ✅ Tambahkan method untuk upload video
  Future<String> uploadPostVideo(String videoPath, String userId) async {
    final folderPath = "jastip_posts/$userId";
    final file = File(videoPath);

    try {
      if (!await file.exists()) {
        throw Exception('File video tidak ditemukan: $videoPath');
      }

      print('Uploading video: ${file.path}');

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: folderPath,
          resourceType: CloudinaryResourceType.Video, // ✅ Resource type video
        ),
      );

      if (response.secureUrl.isNotEmpty) {
        print('Video uploaded successfully: ${response.secureUrl}');
        return response.secureUrl;
      } else {
        throw Exception('Upload video gagal: URL kosong');
      }
    } catch (e) {
      print('Error uploading video: $e');
      throw Exception('Gagal mengupload video: $e');
    }
  }

  // Method backup untuk upload manual menggunakan HTTP
  Future<String?> _uploadImageManually(File file, String folderPath) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');

      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _cloudinaryUploadPreset;
      request.fields['folder'] = folderPath;
      request.fields['resource_type'] = 'image';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        return jsonResponse['secure_url'];
      } else {
        print('Manual upload failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Manual upload error: $e');
      return null;
    }
  }

// Di dalam PostRepositoryImpl
  @override
  Stream<List<Post>> getPosts() {
    try {
      final postsCollection = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true);

      return postsCollection.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            return Post.fromFirestore(doc);
          } catch (e) {
            print('Error parsing post document ${doc.id}: $e');
            rethrow;
          }
        }).toList();
      });
    } catch (e) {
      print('Error getting posts stream: $e');
      return Stream.value(<Post>[]);
    }
  }

  // Method untuk validasi gambar sebelum upload
  Future<bool> validateImage(String imagePath) async {
    try {
      File file = File(imagePath);
      if (!await file.exists()) return false;

      int fileSizeInBytes = await file.length();
      double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
      if (fileSizeInMB > 10) return false;

      String extension = imagePath.toLowerCase().split('.').last;
      List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
      return allowedExtensions.contains(extension);
    } catch (e) {
      print('Error validating image: $e');
      return false;
    }
  }

  // Method untuk validasi video sebelum upload
  Future<bool> validateVideo(String videoPath) async {
    try {
      File file = File(videoPath);
      if (!await file.exists()) return false;

      int fileSizeInBytes = await file.length();
      double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
      if (fileSizeInMB > 100) return false; // Max 100MB untuk video

      String extension = videoPath.toLowerCase().split('.').last;
      List<String> allowedExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
      return allowedExtensions.contains(extension);
    } catch (e) {
      print('Error validating video: $e');
      return false;
    }
  }
}