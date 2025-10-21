import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// VideoPlayerWidget versi aman:
/// - Dispose controller dengan benar
/// - Re-init saat URL/File berubah
/// - Mendukung autoPlay dan progress bar opsional
class VideoPlayerWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final bool autoPlay;
  final bool showControls;

  const VideoPlayerWidget({
    super.key,
    this.url,
    this.file,
    this.autoPlay = false,
    this.showControls = true,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _hasError = false;
      _isInitialized = false;

      // Tutup controller lama sebelum membuat yang baru
      await _controller?.dispose();

      if (widget.url != null && widget.url!.isNotEmpty) {
        // Gunakan networkUrl agar validasi URL lebih aman
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      } else if (widget.file != null) {
        _controller = VideoPlayerController.file(widget.file!);
      } else {
        setState(() {
          _hasError = true;
        });
        return;
      }

      await _controller!.initialize();
      if (_disposed) return;

      _controller!.setLooping(true);
      if (widget.autoPlay) {
        await _controller!.play();
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (!_disposed) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jika sumber berubah, re-initialize
    if (oldWidget.url != widget.url || oldWidget.file != widget.file) {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.error, color: Colors.white, size: 48),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: () {
        if (!mounted || _controller == null) return;
        setState(() {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio == 0
                ? 16 / 9
                : _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          if (!_controller!.value.isPlaying)
            Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(48),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 56),
            ),
          if (widget.showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.blue,
                  bufferedColor: Colors.white54,
                  backgroundColor: Colors.black26,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
