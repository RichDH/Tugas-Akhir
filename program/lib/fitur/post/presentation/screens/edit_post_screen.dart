import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/post/presentation/providers/post_provider.dart';
import 'package:program/fitur/post/data/repositories/post_repository_impl.dart';
import '../../../../core/location/locationService.dart';
import '../../../../core/location/locationSuggestion.dart';
import '../widgets/video_player_widgets.dart';

// Import untuk kompresi
import 'package:image/image.dart' as img;
import 'package:video_compress/video_compress.dart';

class EditPostScreen extends ConsumerStatefulWidget {
  final String postId;

  const EditPostScreen({Key? key, required this.postId}) : super(key: key);

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxOffersController = TextEditingController();
  final _brandController = TextEditingController();
  final _sizeController = TextEditingController();
  final _weightController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  PostType _selectedPostType = PostType.jastip;
  Condition _selectedCondition = Condition.baru;
  String? _selectedCategory;
  bool _isRequestActive = true;

  // Media yang dipilih user (baru)
  List<File> _selectedImages = [];
  XFile? _selectedVideo;

  // Media hasil kompresi
  List<File> _compressedImages = [];
  File? _compressedVideo;

  // Media existing dari post (URL)
  List<String> _existingImageUrls = [];
  String? _existingVideoUrl;

  LocationSuggestion? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  List<LocationSuggestion> _locationSuggestions = [];

  bool _isFormInitialized = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Tidak perlu _loadPost() karena menggunakan postByIdProvider
  }

  // ===== POPULATE FORM =====
  void _populateForm(Post post) {
    if (_isFormInitialized) return; // Cegah populate berulang

    setState(() {
      _selectedPostType = post.type;
      _selectedCondition = post.condition ?? Condition.baru;
      _selectedCategory = post.category;
      _isRequestActive = post.isActive;
      _titleController.text = post.title;
      _descriptionController.text = post.description ?? '';
      _priceController.text = post.price?.toString() ?? '';
      _locationController.text = post.location ?? '';
      _maxOffersController.text = post.maxOffers?.toString() ?? '';
      _brandController.text = post.brand ?? '';
      _sizeController.text = post.size ?? '';
      _weightController.text = post.weight ?? '';
      _additionalNotesController.text = post.additionalNotes ?? '';

      // Set existing media
      _existingImageUrls = List.from(post.imageUrls);
      _existingVideoUrl = post.videoUrl;

      _isFormInitialized = true;
    });
  }

  // ===== KOMPRESI METHODS =====
  Future<File?> _compressImage(File imageFile, {int maxWidth = 1080, int quality = 85}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return imageFile;

      final resized = decoded.width > maxWidth
          ? img.copyResize(decoded, width: maxWidth)
          : decoded;

      final encoded = img.encodeJpg(resized, quality: quality);
      final temp = File(
          '${Directory.systemTemp.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await temp.writeAsBytes(encoded);
      return temp;
    } catch (e) {
      debugPrint('Image compression error: $e');
      return imageFile;
    }
  }

  Future<File?> _compressVideo(File videoFile) async {
    try {
      final info = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        includeAudio: true,
        deleteOrigin: false,
      );
      return info?.file ?? videoFile;
    } catch (e) {
      debugPrint('Video compression error: $e');
      return videoFile;
    }
  }

  bool _validateFileSize(File file, {int maxMB = 50}) {
    final sizeMB = file.lengthSync() / (1024 * 1024);
    return sizeMB <= maxMB;
  }

  // ===== MEDIA PICKERS =====
  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Pilih Gambar'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Pilih Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    setState(() {
      _selectedImages = pickedFiles.map((x) => File(x.path)).toList();
      _selectedVideo = null;
      _compressedVideo = null;
      _compressedImages = [];
      // Clear existing media jika pilih yang baru
      _existingImageUrls.clear();
      _existingVideoUrl = null;
    });

    // Kompres asinkron
    for (final f in _selectedImages) {
      if (!_validateFileSize(f, maxMB: 10)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gambar >10MB, mohon pilih file lebih kecil')),
          );
        }
        continue;
      }
      final compressed = await _compressImage(f);
      if (compressed != null) {
        _compressedImages.add(compressed);
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _selectedVideo = picked;
      _selectedImages.clear();
      _compressedImages = [];
      _compressedVideo = null;
      // Clear existing media
      _existingImageUrls.clear();
      _existingVideoUrl = null;
    });

    final original = File(picked.path);

    if (!_validateFileSize(original, maxMB: 50)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video >50MB, mohon pilih file lebih kecil')),
        );
      }
      return;
    }

    final compressed = await _compressVideo(original);
    _compressedVideo = compressed;

    if (mounted) setState(() {});
  }

  // ===== LOKASI =====
  Future<void> _searchLocations(String query) async {
    if (query.length <= 2) {
      setState(() => _locationSuggestions = []);
      return;
    }
    try {
      final suggestions = await LocationService.searchLocations(query);
      setState(() => _locationSuggestions = suggestions);
    } catch (e) {
      debugPrint('Error searching locations: $e');
      setState(() => _locationSuggestions = []);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error mencari lokasi: $e'), backgroundColor: Colors.orange),
      );
    }
  }

  // ===== SAVE CHANGES =====
  Future<void> _saveChanges(Post currentPost) async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi media
    final hasExistingMedia = _existingImageUrls.isNotEmpty || _existingVideoUrl != null;
    final hasNewMedia = _compressedImages.isNotEmpty || _compressedVideo != null;

    if (!hasExistingMedia && !hasNewMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal 1 gambar atau video diperlukan')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Jika ada media baru, upload dulu
      List<String> finalImageUrls = List.from(_existingImageUrls);
      String? finalVideoUrl = _existingVideoUrl;

      if (_compressedImages.isNotEmpty) {
        // Upload gambar baru dan replace existing
        final repository = PostRepositoryImpl(FirebaseFirestore.instance);
        finalImageUrls = await repository.uploadPostImages(
          _compressedImages.map((f) => f.path).toList(),
          currentPost.userId,
        );
      }

      if (_compressedVideo != null) {
        // Upload video baru dan replace existing
        final repository = PostRepositoryImpl(FirebaseFirestore.instance);
        finalVideoUrl = await repository.uploadPostVideo(
          _compressedVideo!.path,
          currentPost.userId,
        );
      }

      // Update post dengan data baru
      final updatedPost = currentPost.copyWith(
        type: _selectedPostType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null : _descriptionController.text.trim(),
        category: _selectedCategory,
        price: _priceController.text.isEmpty
            ? null : double.tryParse(_priceController.text),
        location: _locationController.text.trim().isEmpty
            ? null : _locationController.text.trim(),
        locationCity: _selectedLocation?.name ?? '',
        locationLat: _selectedLocation?.lat,
        locationLng: _selectedLocation?.lng,
        condition: _selectedCondition,
        brand: _brandController.text.trim().isEmpty
            ? null : _brandController.text.trim(),
        size: _sizeController.text.trim().isEmpty
            ? null : _sizeController.text.trim(),
        weight: _weightController.text.trim().isEmpty
            ? null : _weightController.text.trim(),
        additionalNotes: _additionalNotesController.text.trim().isEmpty
            ? null : _additionalNotesController.text.trim(),
        maxOffers: _maxOffersController.text.isEmpty
            ? null : int.tryParse(_maxOffersController.text),
        imageUrls: finalImageUrls,
        videoUrl: finalVideoUrl,
        updatedAt: Timestamp.now(),
        isActive: _isRequestActive,
      );

      await ref.read(postNotifierProvider.notifier).updatePost(updatedPost);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/feed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postByIdProvider(widget.postId));

    return postAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
      data: (post) {
        if (post == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Post Tidak Ditemukan')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Post tidak ditemukan'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Kembali'),
                  ),
                ],
              ),
            ),
          );
        }

        // Populate form (hanya sekali)
        if (!_isFormInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _populateForm(post);
          });
        }

        // UI Form
        final categories = [
          'Elektronik','Fashion Pria','Fashion Wanita','Fashion Anak','Kecantikan & Perawatan',
          'Kesehatan','Makanan & Minuman','Rumah Tangga','Olahraga & Outdoor','Hobi & Koleksi',
          'Buku & Alat Tulis','Otomotif','Properti','Jasa','Lainnya'
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Postingan'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Jenis Postingan
                  DropdownButtonFormField<PostType>(
                    value: _selectedPostType,
                    decoration: const InputDecoration(labelText: 'Jenis Postingan'),
                    items: PostType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase())))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedPostType = v;
                        if (v != PostType.request) _maxOffersController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Nama barang
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Nama barang', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nama tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 20),

                  // Deskripsi
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Deskripsi', border: OutlineInputBorder()),
                    maxLines: 3,
                    validator: (v) => (v == null || v.isEmpty) ? 'Deskripsi tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 20),

                  // Harga (jika bukan request)
                  if (_selectedPostType == PostType.jastip || _selectedPostType == PostType.short)
                    Column(
                      children: [
                        TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(labelText: 'Harga (Opsional)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),

                  // Kategori
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedCategory = v;
                      });
                    },
                    validator: (v) => (v == null || v.isEmpty) ? 'Kategori tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 20),

                  // Lokasi
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Lokasi (Kota/Kabupaten)',
                      border: OutlineInputBorder(),
                      helperText: 'Ketik minimal 3 karakter untuk mencari lokasi',
                    ),
                    onChanged: (v) => _searchLocations(v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Lokasi tidak boleh kosong' : null,
                  ),

                  // Location suggestions
                  if (_locationSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _locationSuggestions.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (_, i) {
                          final loc = _locationSuggestions[i];
                          return ListTile(
                            dense: true,
                            title: Text(loc.displayName, style: const TextStyle(fontSize: 14)),
                            subtitle: Text(loc.country, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            trailing: Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                            onTap: () {
                              setState(() {
                                _locationController.text = loc.displayName;
                                _selectedLocation = loc;
                                _locationSuggestions = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Kondisi Barang
                  DropdownButtonFormField<Condition>(
                    value: _selectedCondition,
                    decoration: const InputDecoration(labelText: 'Kondisi Barang'),
                    items: Condition.values
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase())))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCondition = v ?? Condition.baru),
                  ),
                  const SizedBox(height: 20),

                  // Merk
                  TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Merk (Opsional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),

                  // Ukuran
                  TextFormField(
                    controller: _sizeController,
                    decoration: const InputDecoration(labelText: 'Ukuran (Opsional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),

                  // Berat
                  TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: 'Berat (Opsional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),

                  // Catatan Tambahan
                  TextFormField(
                    controller: _additionalNotesController,
                    decoration: const InputDecoration(labelText: 'Catatan Tambahan (Opsional)', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  // Media Section
                  Row(
                    children: [
                      ElevatedButton(onPressed: _pickMedia, child: const Text('Ubah Media')),
                      const SizedBox(width: 16),
                      Text(
                        'Media saat ini: ${_existingImageUrls.length} foto${_existingVideoUrl != null ? ', 1 video' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Show Media
                  if (_compressedVideo != null || _selectedVideo != null)
                    SizedBox(
                      height: 200,
                      child: VideoPlayerWidget(file: _compressedVideo ?? File(_selectedVideo!.path)),
                    )
                  else if (_existingVideoUrl != null)
                    SizedBox(
                      height: 200,
                      child: VideoPlayerWidget(url: _existingVideoUrl!),
                    )
                  else if (_compressedImages.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _compressedImages.length,
                          itemBuilder: (context, index) {
                            final f = _compressedImages[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  Image.file(f, width: 100, height: 100, fit: BoxFit.cover),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _compressedImages.removeAt(index);
                                          if (_selectedImages.length > index) {
                                            _selectedImages.removeAt(index);
                                          }
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    else if (_existingImageUrls.isNotEmpty)
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _existingImageUrls.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _existingImageUrls[index],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.error),
                                        ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 30),

                  // Batas Jumlah Offer (jika request)
                  if (_selectedPostType == PostType.request)
                    Column(
                      children: [
                        TextFormField(
                          controller: _maxOffersController,
                          decoration: const InputDecoration(labelText: 'Batas Jumlah Offer', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || v.isEmpty) ? 'Batas offer tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Status Request',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    _isRequestActive ? Icons.check_circle : Icons.cancel,
                                    color: _isRequestActive ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isRequestActive ? 'Aktif - Menerima penawaran' : 'Tidak Aktif - Tidak menerima penawaran',
                                    style: TextStyle(
                                      color: _isRequestActive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _isRequestActive = !_isRequestActive;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isRequestActive ? Colors.red.shade100 : Colors.green.shade100,
                                    foregroundColor: _isRequestActive ? Colors.red.shade700 : Colors.green.shade700,
                                    side: BorderSide(
                                      color: _isRequestActive ? Colors.red.shade300 : Colors.green.shade300,
                                    ),
                                  ),
                                  icon: Icon(_isRequestActive ? Icons.pause : Icons.play_arrow),
                                  label: Text(_isRequestActive ? 'Nonaktifkan Request' : 'Aktifkan Request'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isRequestActive
                                    ? 'Request ini masih menerima penawaran dari jastiper'
                                    : 'Request ini tidak lagi menerima penawaran baru',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Save Button
                  Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: () => _saveChanges(post),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                      ),
                      child: const Text('Simpan Perubahan', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _maxOffersController.dispose();
    _brandController.dispose();
    _sizeController.dispose();
    _weightController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }
}
