import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailWidget extends StatelessWidget {
  final String videoUrl;

  const VideoThumbnailWidget({super.key, required this.videoUrl});

  Future<Uint8List?> _generateThumbnail() async {
    final thumbnail = await VideoThumbnail.thumbnailData(
      video: videoUrl,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 150, // Sesuaikan ukuran thumbnail
      quality: 25,
    );
    return thumbnail;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _generateThumbnail(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey.shade300,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        // Jika gagal atau tidak ada data
        return Container(
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.error)),
        );
      },
    );
  }
}