import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod jika perlu logout
import 'package:program/fitur/auth/presentation/providers/auth_provider.dart'; // Sesuaikan

class ProfileScreen extends ConsumerWidget { // Gunakan ConsumerWidget jika ada logout
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Tambahkan WidgetRef ref
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Halaman Profile (UI akan dibuat nanti)'),
            const SizedBox(height: 20),
            // Contoh tombol Logout
            ElevatedButton(
              onPressed: () {
                ref.read(authProvider.notifier).logout(); // Panggil logout dari provider
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}