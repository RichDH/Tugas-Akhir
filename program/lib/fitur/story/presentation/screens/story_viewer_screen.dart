
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../providers/story_provider.dart';
import '../../domain/entities/story.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  final String userId;

  const StoryViewerScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  List<Story> _stories = [];
  int _currentIndex = 0;
  Timer? _progressTimer;
  double _progress = 0.0;
  VideoPlayerController? _videoController;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _loadUserStories();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _loadUserStories() async {
    final storiesAsync = ref.read(activeStoriesProvider);
    storiesAsync.when(
      data: (allStories) {
        final userStories = allStories
            .where((story) => story.userId == widget.userId)
            .toList();

        if (userStories.isNotEmpty) {
          setState(() {
            _stories = userStories;
            _currentIndex = 0;
          });
          _startStory();
        } else {
          context.pop();
        }
      },
      loading: () {},
      error: (_, __) => context.pop(),
    );
  }

  void _startStory() {
    _progressTimer?.cancel();
    _progress = 0.0;

    final currentStory = _stories[_currentIndex];

    // Mark sebagai sudah dilihat
    ref.read(storyNotifierProvider.notifier).markAsViewed(currentStory.id);

    if (currentStory.type == StoryType.video) {
      _initializeVideo(currentStory.mediaUrl);
    } else {
      _startImageTimer();
    }
  }

  void _initializeVideo(String videoUrl) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.network(videoUrl);

    await _videoController!.initialize();
    _videoController!.play();

    _videoController!.addListener(() {
      if (_videoController!.value.isInitialized && !_isPaused) {
        final duration = _videoController!.value.duration.inMilliseconds;
        final position = _videoController!.value.position.inMilliseconds;

        setState(() {
          _progress = position / duration;
        });

        if (_videoController!.value.position >= _videoController!.value.duration) {
          _nextStory();
        }
      }
    });

    setState(() {});
  }

  void _startImageTimer() {
    const duration = Duration(seconds: 7); // 7 detik untuk foto
    const interval = Duration(milliseconds: 50);

    _progressTimer = Timer.periodic(interval, (timer) {
      if (!_isPaused) {
        setState(() {
          _progress += interval.inMilliseconds / duration.inMilliseconds;
        });

        if (_progress >= 1.0) {
          timer.cancel();
          _nextStory();
        }
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startStory();
    } else {
      context.pop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _startStory();
    }
  }

  void _pauseStory() {
    setState(() {
      _isPaused = true;
    });
    _progressTimer?.cancel();
    _videoController?.pause();
  }

  void _resumeStory() {
    setState(() {
      _isPaused = false;
    });

    if (_stories[_currentIndex].type == StoryType.video) {
      _videoController?.play();
    } else {
      _startImageTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final currentStory = _stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          final tapX = details.localPosition.dx;

          if (tapX < screenWidth * 0.3) {
            _previousStory();
          } else if (tapX > screenWidth * 0.7) {
            _nextStory();
          }
        },
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        child: Stack(
          children: [
            // Media Content
            Positioned.fill(
              child: currentStory.type == StoryType.image
                  ? CachedNetworkImage(
                imageUrl: currentStory.mediaUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error, color: Colors.white),
                ),
              )
                  : _videoController != null && _videoController!.value.isInitialized
                  ? VideoPlayer(_videoController!)
                  : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

            // Text Overlay
            if (currentStory.text?.isNotEmpty == true)
              Positioned(
                bottom: 150,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    currentStory.text!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Top UI
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // Progress Indicators
                  Row(
                    children: List.generate(_stories.length, (index) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: index == _currentIndex
                                ? _progress
                                : index < _currentIndex
                                ? 1.0
                                : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  // User Info Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: currentStory.userAvatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(currentStory.userAvatarUrl)
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: currentStory.userAvatarUrl.isEmpty
                            ? Text(
                          currentStory.username.isNotEmpty
                              ? currentStory.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStory.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatTime(currentStory.createdAt),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Pause Indicator
            if (_isPaused)
              const Center(
                child: Icon(
                  Icons.pause_circle_filled,
                  color: Colors.white70,
                  size: 80,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }
}
