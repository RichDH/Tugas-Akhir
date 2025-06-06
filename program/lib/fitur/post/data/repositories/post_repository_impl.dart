import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/post/domain/repositories/post_repository.dart';
import 'package:cloudinary_public/cloudinary_public.dart'; // Gunakan cloudinary_public untuk unsigned upload
import 'package:http/http.dart' as http;
import 'dart:convert';

class PostRepositoryImpl implements PostRepository {
  final FirebaseFirestore _firestore;
  late CloudinaryPublic cloudinary;

  // Kredensial Cloudinary
  final String _cloudinaryCloudName = "ds656gqe2";
  final String _cloudinaryUploadPreset = "ngoper_unsigned_upload";

  PostRepositoryImpl(this._firestore) {
    // Inisialisasi Cloudinary Public untuk unsigned upload
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
        // Pastikan file ada
        if (!await file.exists()) {
          throw Exception('File tidak ditemukan: $path');
        }

        print('Uploading image ${i + 1}/${imagePaths.length}: ${file.path}');

        // Upload ke Cloudinary menggunakan CloudinaryPublic
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

        // Jika upload dengan cloudinary_public gagal, coba dengan HTTP request manual
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

  // Method backup untuk upload manual menggunakan HTTP
  Future<String?> _uploadImageManually(File file, String folderPath) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');

      var request = http.MultipartRequest('POST', url);

      // Add form fields
      request.fields['upload_preset'] = _cloudinaryUploadPreset;
      request.fields['folder'] = folderPath;
      request.fields['resource_type'] = 'image';

      // Add file
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      // Send request
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
            // Return null dan filter nanti, atau buat Post default
            rethrow;
          }
        }).toList();
      });
    } catch (e) {
      print('Error getting posts stream: $e');
      // Return empty stream jika ada error
      return Stream.value(<Post>[]);
    }
  }

  // Method tambahan untuk menghapus gambar dari Cloudinary jika diperlukan
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract public_id from URL
      String publicId = _extractPublicIdFromUrl(imageUrl);

      if (publicId.isEmpty) {
        print('Cannot extract public_id from URL: $imageUrl');
        return false;
      }

      // Untuk menghapus gambar, biasanya perlu signed request
      // Implementasi ini memerlukan API secret, jadi skip untuk sekarang
      print('Delete image functionality not implemented for unsigned uploads');
      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  String _extractPublicIdFromUrl(String url) {
    try {
      // Extract public_id from Cloudinary URL
      // Format URL: https://res.cloudinary.com/cloud_name/image/upload/v123456/folder/public_id.jpg
      Uri uri = Uri.parse(url);
      List<String> pathSegments = uri.pathSegments;

      // Find the upload segment
      int uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex != -1 && uploadIndex < pathSegments.length - 1) {
        // Get everything after 'upload' and before file extension
        String publicIdWithExtension = pathSegments.sublist(uploadIndex + 2).join('/');
        // Remove file extension
        return publicIdWithExtension.split('.')[0];
      }
      return '';
    } catch (e) {
      print('Error extracting public_id: $e');
      return '';
    }
  }

  // Method untuk validasi gambar sebelum upload
  Future<bool> validateImage(String imagePath) async {
    try {
      File file = File(imagePath);

      // Check if file exists
      if (!await file.exists()) {
        print('File does not exist: $imagePath');
        return false;
      }

      // Check file size (max 10MB)
      int fileSizeInBytes = await file.length();
      double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      if (fileSizeInMB > 10) {
        print('File too large: ${fileSizeInMB.toStringAsFixed(2)} MB');
        return false;
      }

      // Check file extension
      String extension = imagePath.toLowerCase().split('.').last;
      List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        print('Unsupported file extension: $extension');
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating image: $e');
      return false;
    }
  }

  // Method untuk upload dengan progress callback
  Future<List<String>> uploadPostImagesWithProgress(
      List<String> imagePaths,
      String userId,
      {Function(int current, int total, String currentImageName)? onProgress}
      ) async {
    List<String> downloadUrls = [];
    final folderPath = "jastip_posts/$userId";

    for (int i = 0; i < imagePaths.length; i++) {
      String path = imagePaths[i];
      File file = File(path);
      String fileName = file.path.split('/').last;

      // Callback progress
      onProgress?.call(i + 1, imagePaths.length, fileName);

      try {
        // Validate image first
        if (!await validateImage(path)) {
          throw Exception('Validasi gambar gagal untuk: $fileName');
        }

        print('Uploading image ${i + 1}/${imagePaths.length}: $fileName');

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
        print('Error uploading image $fileName: $e');
        throw Exception('Gagal mengupload gambar $fileName: $e');
      }
    }

    return downloadUrls;
  }
}