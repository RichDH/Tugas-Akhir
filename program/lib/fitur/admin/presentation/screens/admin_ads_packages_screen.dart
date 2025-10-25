import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:program/fitur/ads/domain/entities/ads_package.dart';
import 'package:program/fitur/ads/presentation/providers/ads_package_provider.dart';
import 'package:program/fitur/admin/presentation/widgets/admin_drawer.dart';
import 'package:program/app/providers/firebase_providers.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class AdminAdsPackagesScreen extends ConsumerStatefulWidget {
  const AdminAdsPackagesScreen({super.key});

  @override
  ConsumerState<AdminAdsPackagesScreen> createState() => _AdminAdsPackagesScreenState();
}

class _AdminAdsPackagesScreenState extends ConsumerState<AdminAdsPackagesScreen> {
  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Hanya admin yang dapat mengakses halaman ini')),
      );
    }

    final packagesAsync = ref.watch(allAdsPackagesProvider);

    ref.listen<AdsPackageFormState>(adsPackageNotifierProvider, (prev, next) {
      if (next.success && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paket ads berhasil diupdate'), backgroundColor: Colors.green),
        );
      } else if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Kelola Paket Ads'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showCreateDefaultPackagesDialog(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset ke Default',
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: packagesAsync.when(
        data: (packages) {
          if (packages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.ad_units, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Belum ada paket ads'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _createDefaultPackages(),
                    icon: const Icon(Icons.add),
                    label: const Text('Buat Paket Default'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: packages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final package = packages[index];
              return _AdsPackageCard(package: package);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(allAdsPackagesProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDefaultPackagesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Paket Ads'),
        content: const Text(
          'Ini akan mengembalikan semua paket ads ke pengaturan default. '
              'Perubahan yang sudah dilakukan akan hilang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createDefaultPackages();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createDefaultPackages() async {
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    if (currentUser != null) {
      await ref.read(adsPackageNotifierProvider.notifier).createDefaultPackages(currentUser.uid);
    }
  }
}

class _AdsPackageCard extends ConsumerWidget {
  final AdsPackage package;

  const _AdsPackageCard({required this.package});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Warna berdasarkan type
    Color cardColor;
    Color accentColor;
    IconData packageIcon;

    switch (package.type) {
      case AdsPackageType.premium:
        cardColor = Colors.amber.shade50;
        accentColor = Colors.amber.shade600;
        packageIcon = Icons.star;
        break;
      case AdsPackageType.vip:
        cardColor = Colors.purple.shade50;
        accentColor = Colors.purple.shade600;
        packageIcon = Icons.diamond;
        break;
    }

    return Card(
      color: cardColor,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(packageIcon, color: accentColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        'Level ${package.level}',
                        style: TextStyle(
                          fontSize: 14,
                          color: accentColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: package.isActive,
                  onChanged: (value) => _updatePackageStatus(ref, package, value),
                  activeColor: accentColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Package details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Harga', formatter.format(package.price), Icons.attach_money),
                  const SizedBox(height: 8),
                  _buildDetailRow('Durasi', '${package.durationDays} hari', Icons.schedule),
                  const SizedBox(height: 8),
                  _buildDetailRow('Prioritas Level', '${package.level}', Icons.trending_up),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditDialog(context, ref, package),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Paket'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _updatePackageStatus(WidgetRef ref, AdsPackage package, bool isActive) {
    final updatedPackage = package.copyWith(
      isActive: isActive,
      updatedAt: DateTime.now(),
      updatedBy: ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
    );
    ref.read(adsPackageNotifierProvider.notifier).updatePackage(updatedPackage);
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, AdsPackage package) {
    final nameController = TextEditingController(text: package.name);
    final priceController = TextEditingController(text: package.price.toStringAsFixed(0));
    final durationController = TextEditingController(text: package.durationDays.toString());
    final levelController = TextEditingController(text: package.level.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${package.typeDisplayName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Paket',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Harga (Rp)',
                  border: OutlineInputBorder(),
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: 'Durasi (Hari)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: levelController,
                decoration: const InputDecoration(
                  labelText: 'Level Prioritas',
                  border: OutlineInputBorder(),
                  helperText: 'Semakin tinggi, semakin prioritas',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => _submitEdit(
              context,
              ref,
              package,
              nameController,
              priceController,
              durationController,
              levelController,
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _submitEdit(
      BuildContext context,
      WidgetRef ref,
      AdsPackage package,
      TextEditingController nameController,
      TextEditingController priceController,
      TextEditingController durationController,
      TextEditingController levelController,
      ) {
    // Validasi input
    if (nameController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty ||
        durationController.text.trim().isEmpty ||
        levelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua field harus diisi'), backgroundColor: Colors.red),
      );
      return;
    }

    final price = double.tryParse(priceController.text);
    final duration = int.tryParse(durationController.text);
    final level = int.tryParse(levelController.text);

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga harus berupa angka positif'), backgroundColor: Colors.red),
      );
      return;
    }

    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Durasi harus berupa angka positif'), backgroundColor: Colors.red),
      );
      return;
    }

    if (level == null || level <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Level harus berupa angka positif'), backgroundColor: Colors.red),
      );
      return;
    }

    final updatedPackage = package.copyWith(
      name: nameController.text.trim(),
      price: price,
      durationDays: duration,
      level: level,
      updatedAt: DateTime.now(),
      updatedBy: ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
    );

    ref.read(adsPackageNotifierProvider.notifier).updatePackage(updatedPackage);
    Navigator.pop(context);
  }
}
