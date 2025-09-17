import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/fitur/post/presentation/providers/post_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import untuk format angka

class PostDetailScreen extends ConsumerWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailStreamProvider(postId));
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Postingan"),
      ),
      body: postAsync.when(
        data: (postDoc) {
          if (!postDoc.exists || postDoc.data() == null) {
            return const Center(child: Text("Postingan tidak ditemukan."));
          }
          final postData = postDoc.data() as Map<String, dynamic>;
          final userId = postData['userId'] as String? ?? '';
          final imageUrls = postData['imageUrls'] as List<dynamic>? ?? [];
          final likes = List<String>.from(postData['likes'] ?? []);
          final isLiked = likes.contains(currentUserId);

          // PERBAIKAN 1: Format harga agar lebih rapi
          final price = postData['price'] ?? 0;
          final formattedPrice = NumberFormat.currency(
              locale: 'id_ID',
              symbol: 'Rp ',
              decimalDigits: 0
          ).format(price);

          return ListView(
            children: [
              // Header Pengguna (Avatar & Username)
              if (userId.isNotEmpty) _buildPostHeader(ref, userId),

              // Gambar Postingan
              if (imageUrls.isNotEmpty)
                Image.network(
                  imageUrls[0],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    return progress == null ? child : const Center(child: CircularProgressIndicator());
                  },
                ),

              // Tombol Aksi (Like, Comment, dan Order)
              _buildActionButtons(context, ref, postId, isLiked),

              // Detail Postingan
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('${likes.length} Likes', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(height: 16),

                    // PERBAIKAN 1: Perkecil ukuran font judul
                    Text(postData['title'] ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(postData['description'] ?? ''),
                    const SizedBox(height: 12),
                    Text('Jenis: ${postData['type']?.toString().toUpperCase() ?? ''}'),
                    Text('Kategori: ${postData['category'] ?? ''}'),
                    Text('Lokasi: ${postData['location'] ?? ''}'),
                    const SizedBox(height: 8),
                    Text(formattedPrice, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                  ],
                ),
              ),

              const Divider(height: 20),

              InkWell(
                onTap: () => _showCommentsBottomSheet(context, ref, postId),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Text("Lihat semua komentar", style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  // Widget untuk Header (tidak ada perubahan)
  Widget _buildPostHeader(WidgetRef ref, String userId) {
    final userAsync = ref.watch(userProvider(userId));
    return userAsync.when(
      data: (userDoc) {
        if (!userDoc.exists) return const SizedBox.shrink();
        final userData = userDoc.data() as Map<String, dynamic>;
        return ListTile(
          leading: CircleAvatar(
            // TODO: Ganti dengan URL profile picture
            child: const Icon(Icons.person),
          ),

          title: Text(userData['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
        );
      },
      loading: () => const ListTile(title: Text("Memuat...")),
      error: (e, s) => const ListTile(title: Text("Gagal memuat user")),
    );
  }

  // PERBAIKAN 2 & 3: Widget untuk tombol aksi (Like, Comment, Order)
  Widget _buildActionButtons(BuildContext context, WidgetRef ref, String postId, bool isLiked) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // PERBAIKAN 5: Tombol like yang interaktif
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : null,
                ),
                onPressed: () {
                  ref.read(postNotifierProvider.notifier).toggleLike(postId);
                },
              ),
              // PERBAIKAN 4: Tombol comment yang fungsional
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () {
                  _showCommentsBottomSheet(context, ref, postId);
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: () {
                // TODO: Tambahkan logika order
              },
              child: const Text('Order'),
            ),
          ),
        ],
      ),
    );
  }

  // PERBAIKAN 4: Fungsi untuk menampilkan Bottom Sheet Komentar (tidak ada perubahan besar)
  void _showCommentsBottomSheet(BuildContext context, WidgetRef ref, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Agar bisa full screen
      builder: (context) {
        final commentsAsync = ref.watch(commentsStreamProvider(postId));
        final commentController = TextEditingController();

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75, // 75% tinggi layar
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Komentar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: commentsAsync.when(
                    data: (snapshot) {
                      if (snapshot.docs.isEmpty) {
                        return const Center(child: Text("Jadilah yang pertama berkomentar!"));
                      }
                      return ListView.builder(
                        itemCount: snapshot.docs.length,
                        itemBuilder: (context, index) {
                          final comment = snapshot.docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(comment['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(comment['text'] ?? ''),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => const Center(child: Text("Gagal memuat komentar")),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: 'Tambahkan komentar...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          if(commentController.text.trim().isNotEmpty) {
                            ref.read(postNotifierProvider.notifier).addComment(postId, commentController.text);
                            commentController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}