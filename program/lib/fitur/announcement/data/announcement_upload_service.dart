import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:program/app/constants/app_constants.dart';

class AnnouncementUploadService {
  late final CloudinaryPublic _cloudinary;

  AnnouncementUploadService() {
    _cloudinary = CloudinaryPublic(
      AppConstants.cloudinaryCloudName,
      AppConstants.cloudinaryUploadPreset,
      cache: false,
    );
  }

  // Upload 1 gambar pengumuman, mengembalikan secureUrl
  Future<String?> uploadImage(File image, {String folder = 'announcements'}) async {
    try {
      final res = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return res.secureUrl.isNotEmpty ? res.secureUrl : null;
    } catch (e) {
      return null;
    }
  }
}
