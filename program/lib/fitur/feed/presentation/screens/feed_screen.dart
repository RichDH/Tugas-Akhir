import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Untuk navigasi ke halaman lain
import 'package:program/fitur/feed/presentation/providers/feed_provider.dart'; // Akan kita buat nanti
import 'package:program/fitur/feed/presentation/widgets/post_widget.dart'; // Akan kita buat nanti

class FeedScreen extends ConsumerWidget { // Gunakan ConsumerWidget untuk membaca provider
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Tambahkan WidgetRef ref
    // Watch provider untuk mendapatkan daftar postingan
    final postsAsyncValue = ref.watch(postsStreamProvider); // Akan kita buat nanti

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngoper'), // Ganti dengan nama aplikasi Anda
        actions: [
          // Icon Notifikasi
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              // TODO: Navigasi ke halaman Notifikasi
            },
          ),
          // Icon Chat
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              // Navigasi ke halaman daftar chat
              context.push('/chat-list');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Section Stories (Placeholder)
          Container(
            height: 100, // Tinggi untuk horizontal list of stories
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 10, // Jumlah placeholder story
              itemBuilder: (context, index) {
                // Placeholder untuk setiap story
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[300],
                        child: Icon(Icons.person, size: 30, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User $index',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Divider di bawah Stories
          const Divider(height: 1, thickness: 1),

          // Section List Postingan
          Expanded( // Penting agar ListView mengambil sisa ruang
            child: postsAsyncValue.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const Center(child: Text('Belum ada postingan.'));
                }
                // Tampilkan daftar postingan
                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    // Gunakan widget PostWidget untuk menampilkan setiap post
                    return PostWidget(post: post); // Akan kita buat nanti
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()), // Tampilkan loading
              error: (err, stack) => Center(child: Text('Error memuat postingan: $err')), // Tampilkan error
            ),
          ),
        ],
      ),
    );
  }
}