import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/admin/presentation/providers/admin_provider.dart';

class AdminVerificationDetailScreen extends ConsumerWidget {
  final DocumentSnapshot userDoc;
  const AdminVerificationDetailScreen({super.key, required this.userDoc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = userDoc.data() as Map<String, dynamic>;
    final userId = userDoc.id;

    void _processVerification(BuildContext context, WidgetRef ref, String userId, String status) async {
      try {
        await ref.read(adminProvider.notifier).updateVerificationStatus(userId, status);

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status verifikasi berhasil diubah menjadi "$status"')),
        );
        context.pop();

      } catch (e) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }

    void _showConfirmationAndUpdate(BuildContext context, WidgetRef ref, String userId, String status) {
      String actionText = status == 'verified' ? 'Menyetujui' : 'Menolak';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              bool isLoading = false;
              bool isSuccess = false;

              return AlertDialog(
                title: Text(isSuccess ? "Berhasil" : "Konfirmasi Tindakan"),
                content: isSuccess
                    ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 60),
                    const SizedBox(height: 16),
                    Text("Status pengguna telah diperbarui."),
                  ],
                )
                    : isLoading
                    ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text("$actionText verifikasi..."),
                  ],
                )
                    : Text("Anda yakin ingin $actionText verifikasi untuk pengguna ini?"),
                actions: isLoading || isSuccess
                    ? []
                    : [
                  TextButton(
                    child: const Text("Batal"),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                  ElevatedButton(
                    child: Text("Ya, $actionText"),
                    onPressed: () async {
                      setDialogState(() => isLoading = true);

                      try {
                        // Pastikan context masih mounted sebelum panggil provider
                        if (!context.mounted) return;

                        await ref.read(adminProvider.notifier).updateVerificationStatus(userId, status);

                        setDialogState(() {
                          isLoading = false;
                          isSuccess = true;
                        });

                        // Tunggu 2 detik lalu tutup semuanya
                        await Future.delayed(const Duration(seconds: 2));

                        if (context.mounted) {
                          Navigator.of(ctx).pop(); // Tutup dialog
                          if (context.mounted) {
                            context.pop(); // Tutup halaman detail
                          }
                        }

                      } catch (e) {
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(userData['username'] ?? 'Detail Verifikasi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageView(context, 'Foto KTP', userData['ktpImageUrl']),
            const SizedBox(height: 24),
            _buildImageView(context, 'Foto Selfie dengan KTP', userData['selfieKtpImageUrl']),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showConfirmationAndUpdate(context, ref, userId, 'rejected'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showConfirmationAndUpdate(context, ref, userId, 'verified'),
                    child: const Text('Setujui'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildImageView(BuildContext context, String title, String? imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: (imageUrl != null)
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(imageUrl, fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                return progress == null ? child : const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) => const Center(child: Text('Gagal memuat gambar')),
            ),
          )
              : const Center(child: Text('Gambar tidak tersedia.')),
        )
      ],
    );
  }
}