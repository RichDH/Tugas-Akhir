class MediaOptimizer {
  // ✅ AMAN: Tidak mengubah URL asli, hanya menambahkan parameter
  static String optimizeImageUrl(String originalUrl, {int? width, int? height}) {
    if (!originalUrl.contains('cloudinary.com')) {
      return originalUrl; // ✅ AMAN: URL non-cloudinary tidak diubah
    }

    try {
      // Cari posisi "/upload/" dalam URL
      final uploadIndex = originalUrl.indexOf('/upload/');
      if (uploadIndex == -1) return originalUrl;

      // Split URL menjadi sebelum dan sesudah "/upload/"
      final beforeUpload = originalUrl.substring(0, uploadIndex + 8); // +8 untuk "/upload/"
      final afterUpload = originalUrl.substring(uploadIndex + 8);

      // Buat parameter optimasi
      List<String> params = [];
      if (width != null) params.add('w_$width');
      if (height != null) params.add('h_$height');
      params.addAll(['q_auto', 'f_auto']); // Auto quality & format

      // Gabungkan URL dengan parameter optimasi
      return '$beforeUpload${params.join(',')},/$afterUpload';

    } catch (e) {
      print('❌ Error optimizing URL: $e');
      return originalUrl; // ✅ AMAN: Return URL asli jika error
    }
  }

  static String optimizeVideoUrl(String originalUrl, {int? width}) {
    if (!originalUrl.contains('cloudinary.com')) {
      return originalUrl; // ✅ AMAN: URL non-cloudinary tidak diubah
    }

    try {
      final uploadIndex = originalUrl.indexOf('/upload/');
      if (uploadIndex == -1) return originalUrl;

      final beforeUpload = originalUrl.substring(0, uploadIndex + 8);
      final afterUpload = originalUrl.substring(uploadIndex + 8);

      List<String> params = [];
      if (width != null) params.add('w_$width');
      params.addAll(['q_auto:eco', 'f_auto']); // Eco quality untuk video

      return '$beforeUpload${params.join(',')},/$afterUpload';

    } catch (e) {
      print('❌ Error optimizing video URL: $e');
      return originalUrl; // ✅ AMAN: Return URL asli jika error
    }
  }
}
