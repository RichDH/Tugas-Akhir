import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:program/fitur/verification/presentation/providers/verification_provider.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  XFile? _ktpImage;
  XFile? _selfieImage;
  String? _validationError; // Untuk validasi lokal
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source, Function(XFile) onPicked,
      {CameraDevice cameraDevice = CameraDevice.rear}) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      preferredCameraDevice: cameraDevice,
    );
    if (pickedFile != null) {
      setState(() {
        onPicked(pickedFile);
        if (_validationError != null) {
          _validationError = null; // Reset error jika user pilih gambar baru
        }
      });
    }
  }

  void _submit() {
    if (_ktpImage == null || _selfieImage == null) {
      setState(() {
        _validationError = 'Harap unggah kedua foto.';
      });
      return;
    }

    // Reset error jika valid
    setState(() { _validationError = null; });

    ref.read(verificationProvider.notifier)
        .submitVerification(_ktpImage!, _selfieImage!)
        .then((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Berhasil!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 16),
              const Text("Pengajuan verifikasi berhasil dikirim."),
              const SizedBox(height: 8),
              const Text("Admin akan meninjau dalam 1-3 hari kerja."),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Tutup dialog
                if (context.mounted) {
                  Navigator.of(context).pop(); // Kembali ke halaman sebelumnya
                }
              },
              child: const Text("Oke"),
            ),
          ],
        ),
      );
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verificationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Identitas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Unggah dokumen Anda untuk memverifikasi akun dan mengaktifkan fitur pencairan dana.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Foto KTP
            _buildImagePicker(
              title: 'Foto KTP',
              imageFile: _ktpImage,
              onPressed: () => _pickImage(ImageSource.camera, (file) => _ktpImage = file),
            ),
            const SizedBox(height: 8),
            if (_validationError != null && _ktpImage == null)
              Text(_validationError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 16),
            // Foto Selfie dengan KTP
            _buildImagePicker(
              title: 'Foto Selfie dengan KTP',
              imageFile: _selfieImage,
              onPressed: () => _pickImage(
                ImageSource.camera,
                    (file) => _selfieImage = file,
                cameraDevice: CameraDevice.front,
              ),
            ),
            const SizedBox(height: 8),
            if (_validationError != null && _selfieImage == null)
              Text(_validationError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 24),
            state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _submit,
              child: const Text('Kirim Pengajuan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker({
    required String title,
    required XFile? imageFile,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: imageFile != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(imageFile.path), fit: BoxFit.cover),
          )
              : Center(
            child: TextButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Ambil Gambar'),
              onPressed: onPressed,
            ),
          ),
        ),
      ],
    );
  }
}