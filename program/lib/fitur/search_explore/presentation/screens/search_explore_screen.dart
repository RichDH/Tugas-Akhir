import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/fitur/search_explore/presentation/providers/search_provider.dart';
import 'package:go_router/go_router.dart';

class SearchExploreScreen extends ConsumerWidget {
  const SearchExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResults = ref.watch(userSearchProvider(searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Pengguna'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              autofocus: true, // Langsung fokus ke search bar
              decoration: const InputDecoration(
                hintText: 'Cari username...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (query) {
                ref.read(searchQueryProvider.notifier).state = query;
              },
            ),
          ),

          Expanded(
            child: searchResults.when(
              // Kondisi saat stream memberikan data (termasuk data kosong)
              data: (snapshot) {
                final filteredDocs = snapshot.docs.where((d) {
                  final m = d.data() as Map<String, dynamic>;
                  // tampilkan jika deleted tidak ada atau false
                  return !m.containsKey('deleted') || m['deleted'] == false;
                }).toList();

                // Jika belum ada input, tampilkan pesan awal
                if (searchQuery.isEmpty) {
                  return const Center(child: Text('Masukkan nama pengguna untuk memulai pencarian.'));
                }
                // Jika sudah ada input tapi tidak ada hasil
                if (snapshot.docs.isEmpty || filteredDocs.isEmpty) {
                  return const Center(child: Text('Pengguna tidak ditemukan.'));
                }

                // Jika ada hasil, tampilkan list
                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final userDoc = filteredDocs[index];
                    final userData = userDoc.data() as Map<String, dynamic>;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(userData['username']?[0].toUpperCase() ?? '?'),
                      ),
                      title: Text(userData['username'] ?? ''),
                      onTap: () {
                        context.push('/user/${userDoc.id}');
                      },
                    );
                  },
                );
              },
              // Kondisi saat stream sedang menunggu data pertama kali
              loading: () {
                // Jika belum ada input, jangan tampilkan apa-apa (atau pesan awal)
                if (searchQuery.isEmpty) {
                  return const Center(child: Text('Masukkan nama pengguna untuk memulai pencarian.'));
                }
                // Jika sudah ada input, tampilkan loading indicator
                return const Center(child: CircularProgressIndicator());
              },
              // Kondisi jika terjadi error (seperti permission-denied sebelumnya)
              error: (err, stack) => Center(child: Text('Terjadi kesalahan: $err')),
            ),
          )
        ],
      ),
    );
  }
}