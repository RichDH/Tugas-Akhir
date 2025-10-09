import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

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

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    try {
      if (widget.url != null) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      } else if (widget.file != null) {
        _controller = VideoPlayerController.file(widget.file!);
      }

      if (_controller != null) {
        await _controller!.initialize();
        _controller!.setLooping(true);

        if (widget.autoPlay) {
          _controller!.play();
        }

        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.file != widget.file) {
      _controller?.dispose();
      _isInitialized = false;
      _hasError = false;
      _initializeVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.white, size: 48),
              SizedBox(height: 8),
              Text(
                'Error loading video',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
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
          VideoPlayer(_controller!),
          if (!_controller!.value.isPlaying)
            Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 50,
              ),
            ),
          if (widget.showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.blue,
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.black26,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
