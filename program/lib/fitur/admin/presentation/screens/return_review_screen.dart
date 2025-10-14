// File: lib/fitur/admin/presentation/screens/return_review_screen.dart - PERBAIKAN LENGKAP

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // ✅ TAMBAHAN UNTUK NAVIGATION
import 'package:intl/intl.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';

class ReturnReviewScreen extends ConsumerWidget {
  const ReturnReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnRequestsAsync = ref.watch(pendingReturnRequestsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Retur'),
        backgroundColor: Colors.blue.shade50,
        // ✅ TAMBAHAN: Back button otomatis ada, tapi bisa customize
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // Fallback jika tidak bisa pop
              context.go('/admin/'); // Sesuaikan dengan route admin
            }
          },
        ),
      ),
      body: returnRequestsAsync.when(
        data: (requests) {
          // ✅ FILTER HANYA STATUS PENDING (BELUM DIREVIEW ADMIN)
          final pendingRequests = requests.where((r) => r.status == ReturnStatus.pending).toList();
          
          if (pendingRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada permintaan retur yang perlu direview.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Semua retur sudah diproses.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pendingReturnRequestsStreamProvider);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: pendingRequests.length,
              itemBuilder: (context, index) {
                final request = pendingRequests[index];
                return _ReturnRequestCard(request: request);
              },
            ),
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat permintaan retur...'),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Terjadi kesalahan:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(err.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(pendingReturnRequestsStreamProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReturnRequestCard extends ConsumerWidget {
  final ReturnRequest request;

  const _ReturnRequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = ref.watch(transactionByIdStreamProvider(request.transactionId));
    final buyerNameAsync = ref.watch(userNameProvider(request.buyerId));
    final sellerNameAsync = ref.watch(userNameProvider(request.sellerId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID Retur: ${request.id.substring(0, 8)}...',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pending,
                        size: 14,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Perlu Review',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),

            // ✅ TRANSACTION INFO
            transactionAsync.when(
              data: (transaction) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        const Text('Transaksi:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text('ID ${transaction.id.substring(0, 8)}...'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.attach_money, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(transaction.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              loading: () => const Text('Memuat info transaksi...'),
              error: (err, stack) => Text('Error: $err'),
            ),

            const SizedBox(height: 12),

            // ✅ DETAIL PEMBELI & JASTIPER
            Row(
              children: [
                Expanded(
                  child: buyerNameAsync.when(
                    data: (name) => Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text('Pembeli: ${name ?? 'Unknown'}')),
                      ],
                    ),
                    loading: () => const Text('Memuat...'),
                    error: (err, stack) => Text('Pembeli: ${request.buyerId.substring(0, 8)}...'),
                  ),
                ),
                Expanded(
                  child: sellerNameAsync.when(
                    data: (name) => Row(
                      children: [
                        const Icon(Icons.store, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text('Jastiper: ${name ?? 'Unknown'}')),
                      ],
                    ),
                    loading: () => const Text('Memuat...'),
                    error: (err, stack) => Text('Jastiper: ${request.sellerId.substring(0, 8)}...'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),

            // ✅ WAKTU PENGAJUAN
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Diajukan: ${DateFormat('dd MMM yyyy, HH:mm').format(request.createdAt.toDate())}'),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),

            // ✅ ALASAN RETUR
            const Text(
              'Alasan Retur:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                request.reason,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),

            // ✅ EVIDENCE (GAMBAR/VIDEO)
            if (request.evidenceUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Bukti Pendukung:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: request.evidenceUrls.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          request.evidenceUrls[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey[300],
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, color: Colors.grey),
                                  Text('Gagal memuat', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ✅ TOMBOL AKSI - HANYA SATU SET DAN JELAS
            Row(
              children: [
                // TOMBOL TOLAK
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context, ref, request.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(
                      'Tolak Retur',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // TOMBOL SETUJUI
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showApproveDialog(context, ref, request.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Setujui Retur',
                      style: TextStyle(fontWeight: FontWeight.w600),
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

  // ✅ DIALOG SETUJUI DENGAN KONFIRMASI
  void _showApproveDialog(BuildContext context, WidgetRef ref, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Setujui Retur?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Retur akan diteruskan ke jastiper untuk direspons.'),
            SizedBox(height: 8),
            Text(
              '⏰ Jastiper memiliki waktu 15 menit untuk merespons.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(returnRequestProvider.notifier).approveReturnRequest(requestId);
                _showSuccessDialog(context, 'Retur berhasil disetujui!\nDikirim ke jastiper untuk direspons.');
              } catch (e) {
                _showErrorDialog(context, 'Gagal menyetujui retur: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Setujui', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ DIALOG TOLAK DENGAN KONFIRMASI
  void _showRejectDialog(BuildContext context, WidgetRef ref, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Tolak Retur?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Retur akan ditolak dan transaksi kembali ke status diterima.'),
            SizedBox(height: 8),
            Text(
              '⚠️ Pembeli dapat menyelesaikan transaksi setelah penolakan.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(returnRequestProvider.notifier).rejectReturnRequest(requestId);
                _showSuccessDialog(context, 'Retur berhasil ditolak.\nTransaksi kembali ke status diterima.');
              } catch (e) {
                _showErrorDialog(context, 'Gagal menolak retur: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('OK')
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.error, color: Colors.red, size: 64),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('OK')
          ),
        ],
      ),
    );
  }
}