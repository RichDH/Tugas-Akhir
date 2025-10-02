import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/admin/presentation/providers/admin_provider.dart';
import 'package:program/fitur/admin/presentation/widgets/admin_drawer.dart'; // Import drawer

class AdminVerificationListScreen extends ConsumerWidget {
  const AdminVerificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verificationsAsync = ref.watch(pendingVerificationsStreamProvider);

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(title: const Text('Pengajuan Verifikasi')),

      body: verificationsAsync.when(
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return const Center(child: Text('Tidak ada pengajuan verifikasi baru.'));
          }
          return ListView.builder(
            itemCount: snapshot.docs.length,
            itemBuilder: (context, index) {
              final userDoc = snapshot.docs[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(userData['username'] ?? 'Tanpa Username'),
                subtitle: Text(userData['email'] ?? 'Tanpa Email'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Kirim seluruh data pengguna ke halaman detail
                  context.push('/admin/verification-detail', extra: userDoc);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => const Center(child: Text('Gagal memuat data.')),
      ),
    );
  }
}