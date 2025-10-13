// File: program/lib/fitur/profile/presentation/screens/edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:program/fitur/profile/presentation/providers/edit_profile_provider.dart';
import 'package:program/fitur/profile/presentation/providers/profile_provider.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:go_router/go_router.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers untuk form
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController; // BARU: Bio
  late TextEditingController _namaAlamatController;
  late TextEditingController _provinsiController;
  late TextEditingController _kotaController;
  late TextEditingController _rtRwController;
  late TextEditingController _kodePosController;

  String? _originalUsername;
  String? _currentProfileImageUrl;
  File? _selectedProfileImage; // BARU: Profile image
  bool _isInitialized = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController(); // BARU
    _namaAlamatController = TextEditingController();
    _provinsiController = TextEditingController();
    _kotaController = TextEditingController();
    _rtRwController = TextEditingController();
    _kodePosController = TextEditingController();
  }

  void _initializeControllers(Map<String, dynamic> userData) {
    if (!_isInitialized) {
      _nameController.text = userData['name'] ?? '';
      _usernameController.text = userData['username'] ?? '';
      _bioController.text = userData['bio'] ?? ''; // BARU
      _originalUsername = userData['username'];
      _currentProfileImageUrl = userData['profileImageUrl']; // BARU

      // Parse alamat yang sudah ada (jika ada)
      final alamat = userData['alamat'] as String? ?? '';
      if (alamat.isNotEmpty) {
        final alamatParts = _parseAlamat(alamat);
        _namaAlamatController.text = alamatParts['namaAlamat'] ?? '';
        _rtRwController.text = alamatParts['rtRw'] ?? '';
        _kotaController.text = alamatParts['kota'] ?? '';
        _provinsiController.text = alamatParts['provinsi'] ?? '';
        _kodePosController.text = alamatParts['kodePos'] ?? '';
      }

      _isInitialized = true;
    }
  }

  Map<String, String> _parseAlamat(String alamat) {
    // Parsing sederhana alamat yang sudah digabung
    // Format: "nama alamat, RT/RW, kota, provinsi, kode pos"
    final parts = alamat.split(', ');

    return {
      'namaAlamat': parts.isNotEmpty ? parts[0] : '',
      'rtRw': parts.length > 1 ? parts[1] : '',
      'kota': parts.length > 2 ? parts[2] : '',
      'provinsi': parts.length > 3 ? parts[3] : '',
      'kodePos': parts.length > 4 ? parts[4] : '',
    };
  }

  String _buildAlamatString() {
    final parts = [
      _namaAlamatController.text.trim(),
      _rtRwController.text.trim(),
      _kotaController.text.trim(),
      _provinsiController.text.trim(),
      _kodePosController.text.trim(),
    ].where((part) => part.isNotEmpty).toList();

    return parts.join(', ');
  }

  // BARU: Method untuk memilih foto profil
  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedProfileImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: $e')),
      );
    }
  }

  // BARU: Widget untuk menampilkan foto profil
  Widget _buildProfileImageSection() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _selectedProfileImage != null
                ? FileImage(_selectedProfileImage!)
                : (_currentProfileImageUrl != null && _currentProfileImageUrl!.isNotEmpty)
                ? NetworkImage(_currentProfileImageUrl!) as ImageProvider
                : null,
            child: (_selectedProfileImage == null &&
                (_currentProfileImageUrl == null || _currentProfileImageUrl!.isEmpty))
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                onPressed: _pickProfileImage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose(); // BARU
    _namaAlamatController.dispose();
    _provinsiController.dispose();
    _kotaController.dispose();
    _rtRwController.dispose();
    _kodePosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    if (authUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profil')),
        body: const Center(child: Text('User tidak ditemukan')),
      );
    }

    final userProfileAsync = ref.watch(userProfileStreamProvider(authUid));
    final editProfileState = ref.watch(editProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
        actions: [
          TextButton(
            onPressed: editProfileState.isLoading ? null : _saveProfile,
            child: editProfileState.isLoading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Simpan', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: userProfileAsync.when(
        data: (doc) {
          if (!doc.exists || doc.data() == null) {
            return const Center(child: Text('Data profil tidak ditemukan'));
          }

          final userData = doc.data() as Map<String, dynamic>;
          _initializeControllers(userData);

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BARU: Foto Profil Section
                  _buildProfileImageSection(),

                  const SizedBox(height: 32),

                  // Nama Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama tidak boleh kosong';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alternate_email),
                      helperText: 'Username harus unik',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username tidak boleh kosong';
                      }
                      if (value.trim().length < 3) {
                        return 'Username minimal 3 karakter';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                        return 'Username hanya boleh berisi huruf, angka, dan underscore';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // BARU: Bio Field
                  TextFormField(
                    controller: _bioController,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info_outline),
                      helperText: 'Deskripsi singkat tentang Anda',
                    ),
                    maxLines: 3,
                    maxLength: 150,
                  ),

                  const SizedBox(height: 24),

                  // Section Header untuk Alamat
                  const Text(
                    'Alamat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nama Alamat Field
                  TextFormField(
                    controller: _namaAlamatController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Alamat (Jalan, No. Rumah, dll)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Row untuk RT/RW dan Kode Pos
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _rtRwController,
                          decoration: const InputDecoration(
                            labelText: 'RT/RW',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _kodePosController,
                          decoration: const InputDecoration(
                            labelText: 'Kode Pos',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Kota/Kabupaten Field
                  TextFormField(
                    controller: _kotaController,
                    decoration: const InputDecoration(
                      labelText: 'Kota/Kabupaten',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Provinsi Field
                  TextFormField(
                    controller: _provinsiController,
                    decoration: const InputDecoration(
                      labelText: 'Provinsi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Error Message
                  if (editProfileState.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              editProfileState.error!,
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (authUid == null) return;

    final profileData = {
      'name': _nameController.text.trim(),
      'username': _usernameController.text.trim(),
      'bio': _bioController.text.trim(), // BARU
      'alamat': _buildAlamatString(),
    };

    // Cek apakah username berubah dan perlu dicek kembar
    final needsUsernameCheck = _originalUsername != _usernameController.text.trim();

    try {
      await ref.read(editProfileProvider.notifier).updateProfile(
        authUid,
        profileData,
        needsUsernameCheck,
        _selectedProfileImage, // BARU: Pass image file
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui')),
        );
        context.pop();
      }
    } catch (e) {
      // Error sudah ditangani di provider
    }
  }
}
