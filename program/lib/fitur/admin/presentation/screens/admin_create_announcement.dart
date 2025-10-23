import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/admin/presentation/widgets/admin_drawer.dart';
import 'package:program/fitur/announcement/presentation/providers/admin_announcement_provider.dart';
import 'package:program/app/providers/firebase_providers.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class AdminCreateAnnouncementScreen extends ConsumerStatefulWidget {
  const AdminCreateAnnouncementScreen({super.key});

  @override
  ConsumerState<AdminCreateAnnouncementScreen> createState() => _AdminCreateAnnouncementScreenState();
}

class _AdminCreateAnnouncementScreenState extends ConsumerState<AdminCreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  File? _pickedImage;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) {
      setState(() {
        _pickedImage = File(x.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Hanya admin yang dapat mengakses halaman ini')),
      );
    }

    final state = ref.watch(adminAnnouncementProvider);
    ref.listen<AdminAnnouncementState>(adminAnnouncementProvider, (prev, next) {
      if (next.success && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengumuman terkirim ke semua pengguna')),
        );
        context.go('/admin'); // kembali ke dashboard admin
      } else if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Admin • Buat Pengumuman')),
      drawer: const AdminDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul Pengumuman',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(
                labelText: 'Isi Pengumuman',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Isi pengumuman wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Picker image opsional
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Pilih Gambar (Opsional)'),
                ),
                const SizedBox(width: 12),
                if (_pickedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(_pickedImage!, width: 60, height: 60, fit: BoxFit.cover),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () async {
                  if (!_formKey.currentState!.validate()) return;
                  await ref.read(adminAnnouncementProvider.notifier).createAnnouncement(
                    title: _titleCtrl.text.trim(),
                    body: _bodyCtrl.text.trim(),
                    imageFile: _pickedImage,
                  );
                },
                icon: state.isLoading
                    ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(state.isLoading ? 'Mengirim...' : 'Kirim Ke Semua Pengguna'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
