import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:program/fitur/post/presentation/providers/post_provider.dart'; // Sesuaikan nama_project_anda
import 'package:program/fitur/post/domain/entities/post.dart'; // Import PostType
import 'package:cloud_firestore/cloud_firestore.dart'; // Untuk Timestamp (jika perlu input deadline)
import 'package:go_router/go_router.dart';

import '../../../../core/location/locationService.dart';
import '../../../../core/location/locationSuggestion.dart';
import '../widgets/video_player_widgets.dart'; // Untuk navigasi kembali (opsional)

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
  final _maxOffersController = TextEditingController(); // Untuk request
  final _brandController = TextEditingController(); // Field opsional
  final _sizeController = TextEditingController(); // Field opsional
  final _weightController = TextEditingController(); // Field opsional
  final _additionalNotesController = TextEditingController();

  PostType _selectedPostType = PostType.jastip;
  Condition _selectedCondition = Condition.baru;
  String? _selectedCategory;

  List<File> _selectedImages = [];
  XFile? _selectedVideo; // Tambahkan ini untuk video
  LocationSuggestion? _selectedLocation; // Tambahkan ini untuk GeoNames API

  final ImagePicker _picker = ImagePicker();

  // Tambahkan list suggestion lokasi
  List<LocationSuggestion> _locationSuggestions = [];

  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
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
            leading: const Icon(Icons.video_file),
            title: const Text('Rekam/Upload Video'),
            onTap: () {
              Navigator.pop(context);
              _pickVideo();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages = pickedFiles.map((xfile) => File(xfile.path)).toList();
        _selectedVideo = null; // Hapus video jika pilih gambar
        _locationSuggestions = []; // Reset suggestion saat ganti media
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? pickedVideo = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedVideo != null) {
      setState(() {
        _selectedVideo = pickedVideo;
        _selectedImages.clear(); // Hapus gambar jika pilih video
        _locationSuggestions = []; // Reset suggestion saat ganti media
      });
    }
  }

  Future<void> _searchLocations(String query) async {
    if (query.length > 2) {
      try {
        final suggestions = await LocationService.searchLocations(query);
        setState(() {
          _locationSuggestions = suggestions;
        });
      } catch (e) {
        print('Error searching locations: $e');
        setState(() {
          _locationSuggestions = [];
        });

        // Tampilkan error ke user jika perlu
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error mencari lokasi: ${e.toString()}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
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
      _selectedImages = [];
      _selectedVideo = null;
      _selectedPostType = PostType.jastip;
      _selectedCondition = Condition.baru;
      _selectedLocation = null;
      _locationSuggestions = [];
      _selectedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final createPostState = ref.watch(createPostProvider);
    final List<String> _categories = [
      'Elektronik',
      'Fashion Pria',
      'Fashion Wanita',
      'Fashion Anak',
      'Kecantikan & Perawatan',
      'Kesehatan',
      'Makanan & Minuman',
      'Rumah Tangga',
      'Olahraga & Outdoor',
      'Hobi & Koleksi',
      'Buku & Alat Tulis',
      'Otomotif',
      'Properti',
      'Jasa',
      'Lainnya'
    ];



    // Ganti ref.listen yang ada dengan ini:
    ref.listen<AsyncValue<void>>(createPostProvider, (_, state) {
      state.whenOrNull(
        data: (_) {
          // ✅ POPUP SUKSES DENGAN IKON HIJAU
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Berhasil!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Postingan berhasil dibuat dan dipublikasikan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _resetForm();
                          context.go('/feed');
                        },
                        child: const Text('Lihat di Feed'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        error: (e, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal membuat postingan: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    });


    return Scaffold(
      appBar: AppBar(title: const Text('Buat Postingan Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<PostType>(
                value: _selectedPostType,
                decoration: const InputDecoration(labelText: 'Jenis Postingan'),
                items: PostType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedPostType = newValue;
                      // Reset field khusus request jika bukan request
                      if (newValue != PostType.request) {
                        _maxOffersController.clear();
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Nama barang',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Deskripsi tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Harga hanya untuk jastip & short
              if (_selectedPostType == PostType.jastip || _selectedPostType == PostType.short)
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Harga (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                )
              else
                const SizedBox.shrink(),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                    _categoryController.text = newValue ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Kategori tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Lokasi (Kota/Kabupaten)',
                      border: OutlineInputBorder(),
                      helperText: 'Ketik minimal 3 karakter untuk mencari lokasi',
                    ),
                    onChanged: (value) async {
                      if (value.length > 2) {
                        await _searchLocations(value);
                      } else {
                        setState(() {
                          _locationSuggestions = [];
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lokasi tidak boleh kosong';
                      }
                      return null;
                    },
                  ),

                  // Tampilkan dropdown suggestion dengan design yang lebih baik
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
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final loc = _locationSuggestions[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              loc.displayName,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              '${loc.country}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
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
                ],
              ),

              const SizedBox(height: 20),

              // Kondisi barang (untuk semua jenis post)
              DropdownButtonFormField<Condition>(
                value: _selectedCondition,
                decoration: const InputDecoration(labelText: 'Kondisi Barang'),
                items: Condition.values.map((condition) {
                  return DropdownMenuItem(
                    value: condition,
                    child: Text(condition.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCondition = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Field opsional (untuk semua jenis post)
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Merk (Opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _sizeController,
                decoration: const InputDecoration(
                  labelText: 'Ukuran (Opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Berat (Opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _additionalNotesController,
                decoration: const InputDecoration(
                  labelText: 'Catatan Tambahan (Opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Media upload
              ElevatedButton(
                onPressed: _pickMedia,
                child: const Text('Pilih Media'),
              ),
              const SizedBox(height: 10),
              if (_selectedVideo != null)
                SizedBox(
                  height: 200,
                  child: VideoPlayerWidget(file: File(_selectedVideo!.path)),
                )
              else if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            Image.file(
                              _selectedImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
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

              // Field khusus untuk PostType.request
              if (_selectedPostType == PostType.request) ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _maxOffersController,
                  decoration: const InputDecoration(
                    labelText: 'Batas Jumlah Offer',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Batas offer tidak boleh kosong';
                    }
                    return null;
                  },
                ),
              ],

              Center(
                child: createPostState.isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Validasi tambahan gambar/video
                      if (_selectedImages.isEmpty && _selectedVideo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Minimal 1 gambar atau video diperlukan')),
                        );
                        return;
                      }

                      ref.read(createPostProvider.notifier).createPost(
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
                        imagePaths: _selectedImages.map((f) => f.path).toList(),
                        videoPath: _selectedVideo?.path,
                        maxOffers: int.tryParse(_maxOffersController.text.trim()),
                      );
                    }
                  },
                  child: const Text('Buat Postingan'),
                ),
              ),
              const SizedBox(height: 20),

              if (createPostState.hasError)
                Text(
                  'Error: ${createPostState.error.toString()}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}