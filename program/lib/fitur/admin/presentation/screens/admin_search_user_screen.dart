import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/search_explore/presentation/providers/search_provider.dart';

import '../widgets/admin_drawer.dart';

class AdminSearchUserScreen extends ConsumerWidget {
  const AdminSearchUserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(userSearchProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('Admin • Cari Akun')),
      drawer: const AdminDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari username atau nama...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val.trim(),
            ),
          ),
          Expanded(
            child: results.when(
              data: (snap) {

                final filteredDocs = snap.docs.where((d) {
                  final m = d.data() as Map<String, dynamic>;
                  return !m.containsKey('deleted') || m['deleted'] == false;
                }).toList();

                if (query.isEmpty) {
                  return const Center(child: Text('Ketik untuk mencari akun.'));
                }
                if (snap.docs.isEmpty || filteredDocs.isEmpty) {
                  return const Center(child: Text('Tidak ada akun ditemukan.'));
                }
                return ListView.separated(
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = filteredDocs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final username = (data['username'] ?? '').toString();
                    final name = (data['name'] ?? '').toString();

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?'),
                      ),
                      title: Text(username.isNotEmpty ? '@$username' : '(tanpa username)'),
                      subtitle: name.isNotEmpty ? Text(name) : null,
                      onTap: () {
                        // Buka profil user target. Agar tombol “Tutup Akun” muncul,
                        // ProfileScreen akan mendeteksi role admin (isAdminProvider)
                        // dan mengganti tombol sesuai role.
                        context.push('/user/${doc.id}');
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
