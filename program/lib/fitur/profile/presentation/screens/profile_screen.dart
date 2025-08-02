import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/fitur/profile/presentation/providers/profile_provider.dart';
import 'package:program/fitur/auth/presentation/providers/auth_provider.dart'; // Import auth provider Anda

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pantau data pengguna dari stream provider
    final userProfileAsync = ref.watch(userProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Panggil fungsi signOut dari auth provider Anda
              ref.read(authProvider.notifier).logout();
            },
          )
        ],
      ),
      body: userProfileAsync.when(
        data: (userDoc) {
          // Jika dokumen ada dan berisi data
          if (userDoc.exists && userDoc.data() != null) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final username = userData['username'] ?? 'Tanpa Nama';
            final email = userData['email'] ?? 'Tidak ada email';
            // Anda bisa tambahkan field lain seperti profile picture di sini

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Bagian Header Profil
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade300,
                      // TODO: Ganti dengan URL gambar profil jika ada
                      child: const Icon(Icons.person, size: 40, color: Colors.grey),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          email,
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    )
                  ],
                ),
                const Divider(height: 40),

                // TODO: Tambahkan bagian lain seperti "Postingan Saya", "Pengaturan", dll.
                const ListTile(
                  leading: Icon(Icons.shopping_bag_outlined),
                  title: Text('Transaksi Saya'),
                  trailing: Icon(Icons.chevron_right),
                ),
                const ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Pengaturan Akun'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            );
          }
          // Jika dokumen tidak ada
          return const Center(child: Text('Gagal memuat data profil.'));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Terjadi kesalahan: $err')),
      ),
    );
  }
}