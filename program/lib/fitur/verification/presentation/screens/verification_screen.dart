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
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source, Function(XFile) onPicked,
      {CameraDevice cameraDevice = CameraDevice.rear}) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      preferredCameraDevice: cameraDevice, // Gunakan parameter ini
    );
    if (pickedFile != null) {
      setState(() {
        onPicked(pickedFile);
      });
    }
  }

  void _submit() {
    if (_ktpImage != null && _selfieImage != null) {
      ref.read(verificationProvider.notifier)
          .submitVerification(_ktpImage!, _selfieImage!)
          .then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan verifikasi berhasil dikirim!')),
        );
        Navigator.of(context).pop();
      }).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap unggah kedua foto.')),
      );
    }
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
            // Preview & Tombol Foto KTP
            _buildImagePicker(
              title: 'Foto KTP',
              imageFile: _ktpImage,
              onPressed: () => _pickImage(ImageSource.camera, (file) => _ktpImage = file),
            ),
            const SizedBox(height: 24),
            // Preview & Tombol Foto Selfie dengan KTP
            _buildImagePicker(
              title: 'Foto Selfie dengan KTP',
              imageFile: _selfieImage,
              onPressed: () => _pickImage(
                ImageSource.camera,
                    (file) => _selfieImage = file,
                cameraDevice: CameraDevice.front, // <-- INI PERBAIKANNYA
              ),
            ),
            const SizedBox(height: 32),
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