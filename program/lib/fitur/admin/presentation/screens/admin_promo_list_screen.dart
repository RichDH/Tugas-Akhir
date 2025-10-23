import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:program/fitur/admin/presentation/widgets/admin_drawer.dart';
import 'package:program/fitur/promo/presentation/providers/admin_promo_provider.dart';
import 'package:program/fitur/promo/domain/entities/promo.dart';
import 'package:program/app/providers/firebase_providers.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class AdminPromoListScreen extends ConsumerWidget {
  const AdminPromoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Hanya admin yang dapat mengakses halaman ini')),
      );
    }

    final promosAsync = ref.watch(allPromosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Kelola Promo'),
        actions: [
          IconButton(
            onPressed: () => context.push('/admin/create-promo'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: promosAsync.when(
        data: (promos) {
          if (promos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada promo'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: promos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final promo = promos[index];
              return _PromoCard(promo: promo);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/create-promo'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PromoCard extends ConsumerWidget {
  final Promo promo;

  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd MMM yyyy');

    // Status colors
    Color statusColor;
    Color bgColor;
    switch (promo.status) {
      case 'Aktif':
        statusColor = Colors.green;
        bgColor = Colors.green.shade50;
        break;
      case 'Akan Datang':
        statusColor = Colors.blue;
        bgColor = Colors.blue.shade50;
        break;
      case 'Berakhir':
        statusColor = Colors.orange;
        bgColor = Colors.orange.shade50;
        break;
      default:
        statusColor = Colors.grey;
        bgColor = Colors.grey.shade50;
    }

    return Card(
      elevation: 2,
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    promo.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    promo.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Potongan: ${formatter.format(promo.discountAmount)}'),
                      Text('Min. Transaksi: ${formatter.format(promo.minimumTransaction)}'),
                      Text('Periode: ${dateFormatter.format(promo.startDate)} - ${dateFormatter.format(promo.endDate)}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                // Toggle Active
                Switch(
                  value: promo.isActive,
                  onChanged: (value) {
                    ref.read(adminPromoProvider.notifier).togglePromoStatus(promo.id, value);
                  },
                ),
                const Text('Aktif'),
                const Spacer(),

                // Edit
                TextButton.icon(
                  onPressed: () => context.push('/admin/edit-promo/${promo.id}'),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),

                // Delete
                TextButton.icon(
                  onPressed: () => _showDeleteDialog(context, ref, promo),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Promo promo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Promo?'),
        content: Text('Promo "${promo.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(adminPromoProvider.notifier).deletePromo(promo.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Promo berhasil dihapus')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
