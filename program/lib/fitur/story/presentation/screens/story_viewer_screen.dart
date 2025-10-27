// lib/fitur/story/presentation/screens/story_viewer_screen.dart

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
  final int? startIndex;

  const StoryViewerScreen({
    Key? key,
    required this.userId,
    this.startIndex,
  }) : super(key: key);

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  List<Story> _allStories = [];
  int _currentIndex = 0;
  Timer? _progressTimer;
  double _progress = 0.0;
  VideoPlayerController? _videoController;
  bool _isPaused = false;
  bool _isLoading = true;
  bool _shouldPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllStories();
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _loadAllStories() {
    final storiesAsync = ref.read(activeStoriesProvider);
    storiesAsync.when(
      data: (allStories) {
        if (allStories.isEmpty) {
          print('❌ No stories available');
          setState(() {
            _shouldPop = true;
            _isLoading = false;
          });
          _closeViewer();
          return;
        }

        // Group stories by user untuk urutan yang benar
        final Map<String, List<Story>> groupedStories = {};
        for (final story in allStories) {
          if (groupedStories[story.userId] == null) {
            groupedStories[story.userId] = [];
          }
          groupedStories[story.userId]!.add(story);
        }

        // Flatten stories dengan urutan: user yang dipilih dulu, lalu user lain
        final List<Story> orderedStories = [];

        // Tambahkan stories dari user yang dipilih dulu
        if (groupedStories.containsKey(widget.userId)) {
          orderedStories.addAll(groupedStories[widget.userId]!);
          groupedStories.remove(widget.userId);
        }

        // Tambahkan stories dari user lain
        for (final userStories in groupedStories.values) {
          orderedStories.addAll(userStories);
        }

        if (orderedStories.isEmpty) {
          print('❌ No stories found after ordering');
          setState(() {
            _shouldPop = true;
            _isLoading = false;
          });
          _closeViewer();
          return;
        }

        print('📖 Loaded ${orderedStories.length} total stories');
        print('📖 Starting with user: ${widget.userId}');

        // Set initial index dari startIndex parameter atau 0
        final initialIndex = widget.startIndex ?? 0;
        final safeIndex = initialIndex.clamp(0, orderedStories.length - 1);

        setState(() {
          _allStories = orderedStories;
          _currentIndex = safeIndex;
          _isLoading = false;
        });

        _startStory();
      },
      loading: () {
        print('⏳ Stories still loading...');
      },
      error: (error, stack) {
        print('❌ Error loading stories: $error');
        setState(() {
          _shouldPop = true;
          _isLoading = false;
        });
        _closeViewer();
      },
    );
  }

  void _startStory() {
    if (_allStories.isEmpty || _currentIndex >= _allStories.length) return;

    _progressTimer?.cancel();
    _progress = 0.0;

    final currentStory = _allStories[_currentIndex];
    print('🎬 Starting story ${_currentIndex + 1}/${_allStories.length}: ${currentStory.username}');

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

    try {
      await _videoController!.initialize();
      _videoController!.play();

      _videoController!.addListener(() {
        if (_videoController!.value.isInitialized && !_isPaused && mounted) {
          final duration = _videoController!.value.duration.inMilliseconds;
          final position = _videoController!.value.position.inMilliseconds;

          if (duration > 0) {
            setState(() {
              _progress = position / duration;
            });

            if (_videoController!.value.position >= _videoController!.value.duration) {
              _nextStory();
            }
          }
        }
      });

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error initializing video: $e');
      _nextStory();
    }
  }

  void _startImageTimer() {
    const duration = Duration(seconds: 7); // 7 detik untuk foto
    const interval = Duration(milliseconds: 50);

    _progressTimer = Timer.periodic(interval, (timer) {
      if (!_isPaused && mounted) {
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
    print('➡️ Next story requested - current: $_currentIndex, total: ${_allStories.length}');

    if (_currentIndex < _allStories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startStory();
    } else {
      print('✅ Reached end of stories, closing viewer');
      _closeViewer();
    }
  }

  void _previousStory() {
    print('⬅️ Previous story requested - current: $_currentIndex');

    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _startStory();
    } else {
      print('🔚 At beginning of stories, closing viewer');
      _closeViewer();
    }
  }

  void _closeViewer() {
    _progressTimer?.cancel();
    _videoController?.pause();

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  void _pauseStory() {
    print('⏸️ Story paused');
    setState(() {
      _isPaused = true;
    });
    _progressTimer?.cancel();
    _videoController?.pause();
  }

  void _resumeStory() {
    print('▶️ Story resumed');
    setState(() {
      _isPaused = false;
    });

    if (_allStories[_currentIndex].type == StoryType.video) {
      _videoController?.play();
    } else {
      // Resume dari posisi sebelumnya
      final remainingProgress = 1.0 - _progress;
      const totalDuration = Duration(seconds: 7);
      final remainingTime = Duration(
        milliseconds: (remainingProgress * totalDuration.inMilliseconds).round(),
      );

      const interval = Duration(milliseconds: 50);
      _progressTimer = Timer.periodic(interval, (timer) {
        if (!_isPaused && mounted) {
          setState(() {
            _progress += interval.inMilliseconds / totalDuration.inMilliseconds;
          });

          if (_progress >= 1.0) {
            timer.cancel();
            _nextStory();
          }
        }
      });
    }
  }

  void _handleTap(TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.localPosition.dx;

    print('👆 Screen tapped at x: $tapX (screen width: $screenWidth)');

    if (tapX < screenWidth * 0.3) {
      // Tap di bagian kiri - previous story
      print('⬅️ Left tap detected - going to previous story');
      _previousStory();
    } else if (tapX > screenWidth * 0.7) {
      // Tap di bagian kanan - next story
      print('➡️ Right tap detected - going to next story');
      _nextStory();
    }
    // Tap di tengah tidak melakukan apa-apa (bisa digunakan untuk pause/resume jika diperlukan)
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_shouldPop || _allStories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No stories available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final currentStory = _allStories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: _handleTap,
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
                    children: List.generate(_allStories.length, (index) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
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
                        backgroundImage: currentStory.profileImageUrl != null && currentStory.profileImageUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(currentStory.profileImageUrl!)
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: currentStory.profileImageUrl == null || currentStory.profileImageUrl!.isEmpty
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
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatTime(currentStory.createdAt),
                              style: const TextStyle(
                                color: Colors.purple,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Story counter
                      Text(
                        '${_currentIndex + 1}/${_allStories.length}',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _closeViewer,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.purple,
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
                  color: Colors.purple,
                  size: 80,
                ),
              ),

            // Debug tap zones (remove in production)
            if (false) // Set to true untuk debugging
              Positioned.fill(
                child: Row(
                  children: [
                    // Left tap zone
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: Colors.red.withOpacity(0.2),
                        child: const Center(
                          child: Icon(Icons.arrow_back, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                    // Middle tap zone (no action)
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                    // Right tap zone
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: Colors.green.withOpacity(0.2),
                        child: const Center(
                          child: Icon(Icons.arrow_forward, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                  ],
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
