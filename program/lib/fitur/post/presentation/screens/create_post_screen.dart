import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/post/presentation/providers/post_provider.dart';
import '../../../../core/location/locationService.dart';
import '../../../../core/location/locationSuggestion.dart';
import '../widgets/video_player_widgets.dart';

// ===== Tambahan: helper kompresi =====
import 'package:image/image.dart' as img;
import 'package:video_compress/video_compress.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
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

  // Media yang dipilih user (asli)
  List<File> _selectedImages = [];
  XFile? _selectedVideo;

  // Media hasil kompresi (yang akan diupload/dikirim ke provider)
  List<File> _compressedImages = [];
  File? _compressedVideo;

  LocationSuggestion? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  List<LocationSuggestion> _locationSuggestions = [];

  // ===== Helper kompresi & validasi =====
  Future<File?> _compressImage(File imageFile,
      {int maxWidth = 1080, int quality = 85}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return imageFile;

      final resized =
      decoded.width > maxWidth ? img.copyResize(decoded, width: maxWidth) : decoded;

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
        quality: VideoQuality.MediumQuality, // hemat tapi masih bagus
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

  // ================== MEDIA PICKERS ==================
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
      _locationSuggestions = [];
    });

    // Kompres asinkron agar UI tetap responsif
    for (final f in _selectedImages) {
      // Validasi ukuran input (mis: maksimal 10MB untuk gambar)
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
      _locationSuggestions = [];
    });

    final original = File(picked.path);

    // Validasi ukuran input (mis: maksimal 50MB untuk video)
    if (!_validateFileSize(original, maxMB: 50)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video >50MB, mohon pilih file lebih kecil')),
        );
      }
      return;
    }

    // Kompres video
    final compressed = await _compressVideo(original);
    _compressedVideo = compressed;

    if (mounted) setState(() {});
  }

  // ================== LOKASI ==================
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

  // ================== RESET & DISPOSE ==================
  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _descriptionController.clear();
    _categoryController.clear();
    _priceController.clear();
    _locationController.clear();
    _maxOffersController.clear();
    _brandController.clear();
    _sizeController.clear();
    _weightController.clear();
    _additionalNotesController.clear();

    setState(() {
      _selectedPostType = PostType.jastip;
      _selectedCondition = Condition.baru;
      _selectedCategory = null;
      _selectedImages = [];
      _compressedImages = [];
      _selectedVideo = null;
      _compressedVideo = null;
      _selectedLocation = null;
      _locationSuggestions = [];
    });
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

  @override
  Widget build(BuildContext context) {
    final createPostState = ref.watch(createPostProvider);

    // Dengarkan hasil createPost
    ref.listen<AsyncValue<void>>(createPostProvider, (_, state) {
      state.whenOrNull(
        data: (_) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  const Text('Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Postingan berhasil dibuat dan dipublikasikan.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _resetForm();
                        context.go('/feed');
                      },
                      child: const Text('Lihat di Feed'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal membuat postingan: $e'),
            backgroundColor: Colors.red,
          ));
        },
      );
    });

    final categories = [
      'Elektronik','Fashion Pria','Fashion Wanita','Fashion Anak','Kecantikan & Perawatan',
      'Kesehatan','Makanan & Minuman','Rumah Tangga','Olahraga & Outdoor','Hobi & Koleksi',
      'Buku & Alat Tulis','Otomotif','Properti','Jasa','Lainnya'
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Postingan Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Nama barang', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty) ? 'Nama tidak boleh kosong' : null,
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Deskripsi', border: OutlineInputBorder()),
              maxLines: 3,
              validator: (v) => (v == null || v.isEmpty) ? 'Deskripsi tidak boleh kosong' : null,
            ),
            const SizedBox(height: 20),

            if (_selectedPostType == PostType.jastip || _selectedPostType == PostType.short)
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Harga', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCategory = v;
                  _categoryController.text = v ?? '';
                });
              },
              validator: (v) => (v == null || v.isEmpty) ? 'Kategori tidak boleh kosong' : null,
            ),
            const SizedBox(height: 20),

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

            DropdownButtonFormField<Condition>(
              value: _selectedCondition,
              decoration: const InputDecoration(labelText: 'Kondisi Barang'),
              items: Condition.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase())))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCondition = v ?? Condition.baru),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(labelText: 'Merk (Opsional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _sizeController,
              decoration: const InputDecoration(labelText: 'Ukuran (Opsional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Berat (Opsional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _additionalNotesController,
              decoration: const InputDecoration(labelText: 'Catatan Tambahan (Opsional)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Media
            ElevatedButton(onPressed: _pickMedia, child: const Text('Pilih Media')),
            const SizedBox(height: 10),

            if (_compressedVideo != null || _selectedVideo != null)
              SizedBox(
                height: 200,
                child: VideoPlayerWidget(file: _compressedVideo ?? File(_selectedVideo!.path)),
              )
            else if (_compressedImages.isNotEmpty || _selectedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (_compressedImages.isNotEmpty ? _compressedImages : _selectedImages).length,
                  itemBuilder: (context, index) {
                    final f = (_compressedImages.isNotEmpty ? _compressedImages : _selectedImages)[index];
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
                                  if (_compressedImages.isNotEmpty) {
                                    _compressedImages.removeAt(index);
                                    _selectedImages.removeAt(index);
                                  } else {
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
              ),
            const SizedBox(height: 30),

            if (_selectedPostType == PostType.request)
              TextFormField(
                controller: _maxOffersController,
                decoration: const InputDecoration(labelText: 'Batas Jumlah Offer', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Batas offer tidak boleh kosong' : null,
              ),

            const SizedBox(height: 16),

            Center(
              child: createPostState.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  if (_compressedImages.isEmpty && _compressedVideo == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Minimal 1 gambar atau video diperlukan')),
                    );
                    return;
                  }

                  // Kirim path hasil kompresi ke provider
                  await ref.read(createPostProvider.notifier).createPost(
                    type: _selectedPostType,
                    title: _titleController.text.trim(),
                    description: _descriptionController.text.trim(),
                    category: _categoryController.text.trim(),
                    price: double.tryParse(_priceController.text.trim()),
                    location: _locationController.text.trim(),
                    locationCity: _selectedLocation?.name ?? '',
                    locationLat: _selectedLocation?.lat,
                    locationLng: _selectedLocation?.lng,
                    condition: _selectedCondition,
                    brand: _brandController.text.trim(),
                    size: _sizeController.text.trim(),
                    weight: _weightController.text.trim(),
                    additionalNotes: _additionalNotesController.text.trim(),
                    imagePaths: _compressedImages.map((f) => f.path).toList(),
                    videoPath: _compressedVideo?.path,
                    maxOffers: int.tryParse(_maxOffersController.text.trim()),
                  );
                },
                child: const Text('Buat Postingan'),
              ),
            ),
            const SizedBox(height: 20),

            if (createPostState.hasError)
              Text('Error: ${createPostState.error}', style: const TextStyle(color: Colors.red)),
          ]),
        ),
      ),
    );
  }
}
