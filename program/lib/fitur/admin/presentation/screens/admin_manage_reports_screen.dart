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
                            '#${data['id'] ?? docs[index].id} • ${data['type'] ?? 'post'}',
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
                      const SizedBox(height: 6),
                      // Detail ringkas
                      Text('Reason: ${data['reason'] ?? '-'}'),
                      if ((data['description'] as String?)?.isNotEmpty == true)
                        Text('Desc: ${data['description']}'),
                      Text('Reporter: ${data['reporterUserId'] ?? '-'}'),
                      if ((data['reportedPostId'] as String?)?.isNotEmpty == true)
                        Text('Post: ${data['reportedPostId']}'),
                      if ((data['reportedUserId'] as String?)?.isNotEmpty == true)
                        Text('Reported User: ${data['reportedUserId']}'),
                      Text('Created: $createdStr'),
                      const SizedBox(height: 12),

                      // Actions
                      Row(
                        children: [
                          // Arahkan ke halaman delete post (navigasi ke post detail/admin tool yang Anda miliki)
                          ElevatedButton.icon(
                            onPressed: (data['reportedPostId'] as String?)?.isNotEmpty == true
                                ? () {
                              // Buka detail post normal; dari sana admin bisa hapus/soft delete
                              context.push('/post-detail/${data['reportedPostId']}');
                            }
                                : null,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete Post'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Tombol tutup akun (placeholder, implement nanti)
                          OutlinedButton.icon(
                            onPressed: (data['reportedUserId'] as String?)?.isNotEmpty == true
                                ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Fitur menutup akun akan dibuat nanti'),
                                ),
                              );
                            }
                                : null,
                            icon: const Icon(Icons.block),
                            label: const Text('Tutup Akun'),
                          ),
                          const Spacer(),
                          // Mark as Reviewed
                          TextButton(
                            onPressed: isOpen
                                ? () async {
                              await docs[index].reference.update({
                                'status': 'reviewed',
                                'reviewedAt': FieldValue.serverTimestamp(),
                              });
                            }
                                : null,
                            child: const Text('Tandai Reviewed'),
                          ),
                        ],
                      ),
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
