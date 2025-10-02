import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/fitur/admin/presentation/providers/admin_provider.dart';
import 'package:program/fitur/admin/presentation/widgets/admin_drawer.dart';

class AdminDashboardScreen extends ConsumerWidget { // Ubah menjadi ConsumerWidget
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Tambahkan WidgetRef ref
    // Ambil data stream verifikasi
    final verificationsAsync = ref.watch(pendingVerificationsStreamProvider);

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            // PERBAIKAN: Buat kartu "Verifikasi Pending" menjadi dinamis
            verificationsAsync.when(
              data: (snapshot) => _DashboardCard(
                title: 'Verifikasi Pending',
                value: snapshot.docs.length.toString(), // Ambil jumlahnya
                icon: Icons.pending_actions,
              ),
              loading: () => const _DashboardCard(title: 'Verifikasi Pending', value: '...', icon: Icons.pending_actions),
              error: (e,s) => const _DashboardCard(title: 'Verifikasi Pending', value: 'Error', icon: Icons.error_outline),
            ),

            // Placeholder lain
            const _DashboardCard(title: 'Total Pengguna', value: '0', icon: Icons.person_outline),
            const _DashboardCard(title: 'Live Aktif', value: '0', icon: Icons.live_tv),
            const _DashboardCard(title: 'Total Transaksi', value: 'Rp 0', icon: Icons.monetization_on_outlined),
          ],
        ),
      ),
    );
  }
}

// Widget helper untuk kartu dashboard
class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}