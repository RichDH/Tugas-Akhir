// lib/core/utils/media_compressor.dart
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:video_compress/video_compress.dart';

class MediaCompressor {
  // Compress image sebelum upload
  static Future<File?> compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return imageFile;

      // Resize ke max 1080px width
      final resized = image.width > 1080
          ? img.copyResize(image, width: 1080)
          : image;

      // Compress quality 85%
      final compressed = img.encodeJpg(resized, quality: 85);

      // Save compressed file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressed);

      return tempFile;
    } catch (e) {
      print('❌ Image compression failed: $e');
      return imageFile; // Return original jika gagal
    }
  }

  // Compress video sebelum upload
  static Future<File?> compressVideo(File videoFile) async {
    try {
      final info = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      return info?.file ?? videoFile;
    } catch (e) {
      print('❌ Video compression failed: $e');
      return videoFile;
    }
  }

  // Validasi ukuran file
  static bool validateFileSize(File file, {int maxMB = 50}) {
    final fileSizeInMB = file.lengthSync() / (1024 * 1024);
    if (fileSizeInMB > maxMB) {
      print('❌ File terlalu besar: ${fileSizeInMB.toStringAsFixed(1)}MB (max: ${maxMB}MB)');
      return false;
    }
    return true;
  }
}
