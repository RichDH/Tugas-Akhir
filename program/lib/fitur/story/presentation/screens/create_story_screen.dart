import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../providers/story_provider.dart';
import '../../domain/entities/story.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  File? _selectedFile;
  StoryType? _fileType;
  VideoPlayerController? _videoController;
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _videoController?.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final result = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () async {
                final file = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Rekam Video'),
              onTap: () async {
                final file = await _picker.pickVideo(
                  source: ImageSource.camera,
                  maxDuration: const Duration(seconds: 60), // Max 60 detik
                );
                Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                final file = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Pilih Video dari Galeri'),
              onTap: () async {
                final file = await _picker.pickVideo(
                  source: ImageSource.gallery,
                );
                Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      _setSelectedFile(File(result.path));
    }
  }

  void _setSelectedFile(File file) {
    final isVideo = file.path.toLowerCase().endsWith('.mp4') ||
        file.path.toLowerCase().endsWith('.mov') ||
        file.path.toLowerCase().endsWith('.avi');

    setState(() {
      _selectedFile = file;
      _fileType = isVideo ? StoryType.video : StoryType.image;
    });

    if (isVideo) {
      _initializeVideoPlayer(file);
    }
  }

  Future<void> _initializeVideoPlayer(File videoFile) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(videoFile);
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.play();
    setState(() {});
  }

  Future<void> _publishStory() async {
    if (_selectedFile == null || _fileType == null) return;

    await ref.read(storyNotifierProvider.notifier).createStory(
      filePath: _selectedFile!.path,
      type: _fileType!,
      text: _textController.text.trim().isEmpty
          ? null
          : _textController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storyState = ref.watch(storyNotifierProvider);

    ref.listen(storyNotifierProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Story berhasil dibuat!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        },
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Buat Story'),
        actions: [
          if (_selectedFile != null)
            TextButton(
              onPressed: storyState.isLoading ? null : _publishStory,
              child: storyState.isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                'Bagikan',
                style: TextStyle(color: Colors.blue, fontSize: 16),
              ),
            ),
        ],
      ),
      body: _selectedFile == null
          ? _buildMediaPicker()
          : _buildStoryEditor(),
    );
  }

  Widget _buildMediaPicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_circle_outline,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            'Pilih foto atau video untuk story',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickMedia,
            icon: const Icon(Icons.add),
            label: const Text('Pilih Media'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryEditor() {
    return Stack(
      children: [
        // Media Preview
        Positioned.fill(
          child: _fileType == StoryType.image
              ? Image.file(
            _selectedFile!,
            fit: BoxFit.cover,
          )
              : _videoController != null && _videoController!.value.isInitialized
              ? VideoPlayer(_videoController!)
              : const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),

        // Text Overlay Input
        Positioned(
          bottom: 100,
          left: 16,
          right: 16,
          child: TextField(
            controller: _textController,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              hintText: 'Tambahkan teks...',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
            ),
            maxLines: null,
            textAlign: TextAlign.center,
          ),
        ),

        // Bottom Actions
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedFile = null;
                    _fileType = null;
                    _videoController?.dispose();
                    _videoController = null;
                    _textController.clear();
                  });
                },
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              IconButton(
                onPressed: _pickMedia,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
