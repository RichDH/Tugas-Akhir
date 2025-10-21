import '../app/constants/app_constants.dart';

class CloudinaryUrl {
  // 🎯 EXTRACT CLOUD NAME DARI URL ASLI (BUKAN DARI CONSTANTS)
  static String? extractCloudName(String cloudinaryUrl) {
    try {
      final uri = Uri.parse(cloudinaryUrl);
      final pathSegments = uri.pathSegments;

      // Format: https://res.cloudinary.com/[CLOUD_NAME]/image/upload/...
      if (pathSegments.isNotEmpty) {
        return pathSegments[0]; // Cloud name selalu segment pertama
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static String? extractPublicId(String cloudinaryUrl) {
    try {
      print('🔍 Trying to extract public ID from: $cloudinaryUrl');

      final uri = Uri.parse(cloudinaryUrl);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length < 4) {
        print('❌ URL too short: ${pathSegments.length} segments');
        return null;
      }

      // Cari index "upload"
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex >= pathSegments.length - 1) {
        print('❌ Upload segment not found');
        return null;
      }

      // Ambil semua segment setelah upload (skip version jika ada)
      final afterUpload = pathSegments.sublist(uploadIndex + 1);

      // Skip version (format v1234567890)
      final filteredSegments = afterUpload.where((segment) => !RegExp(r'^v\d+$').hasMatch(segment)).toList();

      if (filteredSegments.isEmpty) {
        print('❌ No segments after filtering version');
        return null;
      }

      // Join semua segment dan hilangkan extension dari segment terakhir
      String fullPath = filteredSegments.join('/');
      fullPath = fullPath.split('.').first; // Hilangkan extension

      print('✅ Extracted public ID: $fullPath');
      return fullPath;

    } catch (e) {
      print('❌ Error extracting public ID: $e');
      return null;
    }
  }

  // 🎯 SAFE METHODS YANG MEMAKAI CLOUD NAME DARI URL ASLI
  static String safeImageTransform(String originalUrl, {int width = 360, String quality = 'eco'}) {
    final cloudName = extractCloudName(originalUrl);
    final publicId = extractPublicId(originalUrl);

    if (cloudName != null && publicId != null) {
      final transformedUrl = 'https://res.cloudinary.com/$cloudName/image/upload/f_auto,q_auto:$quality,w_$width/$publicId.jpg';
      print('🎯 Transformed image URL: $transformedUrl');
      return transformedUrl;
    }

    // Fallback: gunakan URL asli
    print('⚠️ Using fallback URL for image: $originalUrl');
    return originalUrl;
  }

  static String safeVideoTransform(String originalUrl, {int width = 720, int bitrate = 1200}) {
    final cloudName = extractCloudName(originalUrl);
    final publicId = extractPublicId(originalUrl);

    if (cloudName != null && publicId != null) {
      final transformedUrl = 'https://res.cloudinary.com/$cloudName/video/upload/f_auto,q_auto,w_$width,br_${bitrate}k/$publicId.mp4';
      print('🎯 Transformed video URL: $transformedUrl');
      return transformedUrl;
    }

    print('⚠️ Using fallback URL for video: $originalUrl');
    return originalUrl;
  }

  static String safeVideoPoster(String originalUrl, {int width = 360}) {
    final cloudName = extractCloudName(originalUrl);
    final publicId = extractPublicId(originalUrl);

    if (cloudName != null && publicId != null) {
      final posterUrl = 'https://res.cloudinary.com/$cloudName/video/upload/so_1,f_jpg,q_auto:eco,w_$width/$publicId.jpg';
      print('🎯 Generated poster URL: $posterUrl');
      return posterUrl;
    }

    print('⚠️ Cannot create poster for: $originalUrl');
    // Return placeholder image
    return 'https://via.placeholder.com/${width}x${(width * 9 / 16).round()}.png?text=Video';
  }

  // 🎯 HELPER UNTUK UPLOAD (TETAP PAKAI CONSTANTS)
  static String get uploadCloudName => AppConstants.cloudinaryCloudName;
  static String get uploadPreset => AppConstants.cloudinaryUploadPreset;
}
