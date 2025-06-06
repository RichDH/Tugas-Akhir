import 'package:flutter/material.dart';
import 'package:program/fitur/post/domain/entities/post.dart'; // Import Post entity
import 'package:cached_network_image/cached_network_image.dart'; // Untuk menampilkan gambar dari URL

class PostWidget extends StatelessWidget {
  final Post post;

  const PostWidget({
    required this.post,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Post (User Info)
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blueGrey[100],
                  child: Text(
                    post.username.isNotEmpty ? post.username[0].toUpperCase() : '?', // Inisial username, handle empty
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // TODO: Ganti dengan gambar profil user jika ada
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // TODO: Tambahkan menu opsi post (misal: Report)
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // Aksi untuk menu opsi
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Gambar Postingan (Jika ada)
            if (post.imageUrls.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9, // Sesuaikan rasio aspek gambar
                child: CachedNetworkImage(
                  imageUrl: post.imageUrls.first, // Tampilkan gambar pertama
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),

            // Deskripsi Postingan
            Text(
              post.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Info Tambahan (Judul, Kategori, Lokasi, Harga, dll.)
            Text(
              'Judul: ${post.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Jenis: ${post.type.toString().split('.').last.toUpperCase()}'),
            Text('Kategori: ${post.category}'),
            Text('Lokasi: ${post.location}'),
            if (post.price != null) Text('Harga: Rp ${post.price!.toStringAsFixed(0)}'),

            const SizedBox(height: 12),

            // Aksi Post (Likes, Comments, Offers, dll.)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Likes
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () {
                        // TODO: Aksi Like
                      },
                    ),
                    Text('${post.likesCount} Likes'),
                  ],
                ),
                // Comments
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.comment_outlined),
                      onPressed: () {
                        // TODO: Navigasi ke halaman detail post/komentar
                      },
                    ),
                    Text('${post.commentsCount} Comments'),
                  ],
                ),
                // Offers (Khusus Request Jastip)
                if (post.type == PostType.request)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.local_offer_outlined),
                        onPressed: () {
                          // TODO: Navigasi ke halaman daftar tawaran
                        },
                      ),
                      Text('${post.offersCount} Offers'),
                    ],
                  ),
              ],
            ),
            // TODO: Tambahkan tombol aksi lain seperti "Ajukan Tawaran" (untuk Request), "Beli" (untuk Jastip/Live)
          ],
        ),
      ),
    );
  }
}