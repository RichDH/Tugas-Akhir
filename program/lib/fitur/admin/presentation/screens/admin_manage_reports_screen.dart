import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:program/fitur/admin/presentation/widgets/admin_drawer.dart';

class AdminManageReportsScreen extends StatelessWidget {
  const AdminManageReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Report'),
      ),
      drawer: const AdminDrawer(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada laporan.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final created = (data['createdAt'] as Timestamp?);
              final createdStr = created != null
                  ? DateFormat('dd MMM yyyy HH:mm').format(created.toDate())
                  : '-';

              final status = (data['status'] as String?) ?? 'open';
              final isOpen = status == 'open';
              final reporterUserId = data['reporterUserId'] as String?;
              final reportedUserId = data['reportedUserId'] as String?;
              final reportedPostId = data['reportedPostId'] as String?;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '#${docs[index].id} • ${data['type'] ?? 'post'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOpen ? Colors.orange.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: isOpen ? Colors.orange.shade800 : Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Content dengan thumbnail
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Detail report di kiri
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reason: ${data['reason'] ?? '-'}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                if ((data['description'] as String?)?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Description: ${data['description']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 8),

                                // Reporter username
                                if (reporterUserId != null)
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(reporterUserId)
                                        .get(),
                                    builder: (context, userSnap) {
                                      final username = userSnap.data?.data() != null
                                          ? (userSnap.data!.data() as Map<String, dynamic>)['username'] ?? 'Unknown'
                                          : 'Loading...';
                                      return Text('Reporter: @$username');
                                    },
                                  ),

                                // Reported username (jika ada)
                                if (reportedUserId != null) ...[
                                  const SizedBox(height: 4),
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(reportedUserId)
                                        .get(),
                                    builder: (context, userSnap) {
                                      final username = userSnap.data?.data() != null
                                          ? (userSnap.data!.data() as Map<String, dynamic>)['username'] ?? 'Unknown'
                                          : 'Loading...';
                                      return Text('Reported User: @$username');
                                    },
                                  ),
                                ],

                                // Post title (jika ada)
                                if (reportedPostId != null) ...[
                                  const SizedBox(height: 4),
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('posts')
                                        .doc(reportedPostId)
                                        .get(),
                                    builder: (context, postSnap) {
                                      final postData = postSnap.data?.data() as Map<String, dynamic>?;
                                      final title = postData?['title'] ?? 'Post not found';
                                      return Text(
                                        'Post: $title',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      );
                                    },
                                  ),
                                ],

                                const SizedBox(height: 4),
                                Text(
                                  'Created: $createdStr',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Thumbnail post di kanan
                          if (reportedPostId != null)
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(reportedPostId)
                                  .get(),
                              builder: (context, postSnap) {
                                final postData = postSnap.data?.data() as Map<String, dynamic>?;
                                if (postData == null) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.error, color: Colors.grey),
                                  );
                                }

                                final imageUrls = postData['imageUrls'] as List<dynamic>? ?? [];
                                final videoUrl = postData['videoUrl'] as String?;

                                return GestureDetector(
                                  onTap: () => context.push('/post-detail/$reportedPostId'),
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: imageUrls.isNotEmpty
                                          ? Image.network(
                                        imageUrls.first,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.error, color: Colors.grey),
                                            ),
                                      )
                                          : videoUrl != null
                                          ? Stack(
                                        children: [
                                          Container(
                                            color: Colors.black,
                                            child: const Center(
                                              child: Icon(
                                                Icons.play_circle_outline,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                          : Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),

                      if (status == 'open') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Soft Delete Post (ADMIN)
                            ElevatedButton.icon(
                              onPressed: reportedPostId?.isNotEmpty == true
                                  ? () async {
                                final postId = reportedPostId!;
                                final reportRef = docs[index].reference;
                                final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

                                // Konfirmasi admin
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Hapus Post (Soft Delete)?'),
                                    content: const Text(
                                      'Post akan disembunyikan dari feed/profil (deleted: true). '
                                          'Data tetap tersimpan untuk referensi transaksi/chat.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm != true) return;

                                try {
                                  // Soft delete + tandai report sebagai resolved
                                  await FirebaseFirestore.instance.runTransaction((tx) async {
                                    final postSnap = await tx.get(postRef);
                                    if (!postSnap.exists) {
                                      throw Exception('Post tidak ditemukan');
                                    }

                                    tx.update(postRef, {
                                      'deleted': true,
                                      'deletedAt': FieldValue.serverTimestamp(),
                                      'deletedBy': 'admin',
                                    });

                                    tx.update(reportRef, {
                                      'status': 'resolved',
                                      'resolvedAt': FieldValue.serverTimestamp(),
                                      'action': 'soft_deleted_post',
                                    });
                                  });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Post berhasil dihapus (soft delete).')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Gagal menghapus post: $e')),
                                    );
                                  }
                                }
                              }
                                  : null,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Delete Post'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Tutup Akun (placeholder)
                            OutlinedButton.icon(
                              onPressed: reportedUserId?.isNotEmpty == true
                                  ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Fitur menutup akun akan dibuat nanti')),
                                );
                              }
                                  : null,
                              icon: const Icon(Icons.block, size: 18),
                              label: const Text('Tutup Akun'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),

                            const Spacer(),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
