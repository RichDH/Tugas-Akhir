// lib/fitur/story/data/repositories/story_repository_impl.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image/image.dart' as img;
import 'package:video_compress/video_compress.dart';
import '../../domain/entities/story.dart';
import 'package:program/fitur/story/domain/entities/story.dart';
import '../../../../app/constants/app_constants.dart';
import '../../domain/repositories/story_repository.dart';

class StoryRepositoryImpl implements StoryRepository {
  final FirebaseFirestore _firestore;
  late CloudinaryPublic cloudinary;

  StoryRepositoryImpl(this._firestore) {
    cloudinary = CloudinaryPublic(
      AppConstants.cloudinaryCloudName,
      AppConstants.cloudinaryUploadPreset,
      cache: false,
    );
  }

  @override
  Future<void> createStory(Story story) async {
    try {
      await _firestore.collection('stories').add(story.toFirestore());
    } catch (e) {
      throw Exception('Gagal membuat story: $e');
    }
  }

  @override
  Future<String> uploadStoryMedia(String filePath, String userId, StoryType type) async {
    final folderPath = "stories/$userId";
    File file = File(filePath);

    try {
      if (!await file.exists()) {
        throw Exception('File tidak ditemukan');
      }

      // Compress dan optimize berdasarkan type
      File optimizedFile;
      if (type == StoryType.image) {
        optimizedFile = await _compressImage(file);
      } else {
        optimizedFile = await _compressVideo(file);
      }

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          optimizedFile.path,
          folder: folderPath,
          resourceType: type == StoryType.image
              ? CloudinaryResourceType.Image
              : CloudinaryResourceType.Video,
        ),
      );

      // Clean up temporary compressed file
      if (optimizedFile.path != file.path) {
        await optimizedFile.delete();
      }

      if (response.secureUrl.isNotEmpty) {
        return response.secureUrl;
      } else {
        throw Exception('Upload gagal: URL kosong');
      }
    } catch (e) {
      throw Exception('Gagal mengupload media: $e');
    }
  }

  Future<File> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return imageFile;

      // Resize untuk story (9:16 ratio, max width 720)
      final resized = img.copyResize(
        image,
        width: 720,
        height: 1280,
        maintainAspect: false,
      );

      // Compress dengan quality 85%
      final compressedBytes = img.encodeJpg(resized, quality: 85);

      final tempDir = Directory.systemTemp;
      final compressedFile = File('${tempDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      print('Error compressing image: $e');
      return imageFile;
    }
  }

  Future<File> _compressVideo(File videoFile) async {
    try {
      // Compress video untuk story - quality medium, size maksimal 10MB
      final MediaInfo? info = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (info?.file != null) {
        return info!.file!;
      } else {
        return videoFile;
      }
    } catch (e) {
      print('Error compressing video: $e');
      return videoFile;
    }
  }

  @override
  Stream<List<Story>> getActiveStoriesFromFollowing(String currentUserId) {
    return _firestore
        .collection('stories')
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      // Ambil list user yang di follow
      final followingDoc = await _firestore
          .collection('follows')
          .doc(currentUserId)
          .get();

      final following = followingDoc.exists
          ? List<String>.from(followingDoc.data()?['following'] ?? [])
          : <String>[];

      // Filter story dari user yang difollow + user sendiri
      final stories = snapshot.docs
          .map((doc) => Story.fromFirestore(doc))
          .where((story) =>
      following.contains(story.userId) ||
          story.userId == currentUserId)
          .toList();

      return stories;
    });
  }

  @override
  Future<Story?> getUserActiveStory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Story.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting user story: $e');
      return null;
    }
  }

  @override
  Future<void> markStoryAsViewed(String storyId, String userId) async {
    try {
      await _firestore.collection('stories').doc(storyId).update({
        'viewedBy': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      print('Error marking story as viewed: $e');
    }
  }

  @override
  Future<void> deleteExpiredStories() async {
    try {
      final snapshot = await _firestore
          .collection('stories')
          .where('expiresAt', isLessThan: Timestamp.now())
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting expired stories: $e');
    }
  }
}
