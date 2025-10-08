import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';

class ReturnFinalizeScreen extends ConsumerWidget {
  const ReturnFinalizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnRequestsAsync = ref.watch(respondedReturnRequestsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Finalisasi Retur')),
      body: returnRequestsAsync.when(
           data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('Tidak ada retur yang perlu difinalisasi.'));
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _ReturnFinalizeCard(request: request);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ReturnFinalizeCard extends ConsumerWidget {
  final ReturnRequest request;

  const _ReturnFinalizeCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = ref.watch(transactionByIdStreamProvider(request.transactionId));
    final buyerNameAsync = ref.watch(userNameProvider(request.buyerId));
    final sellerNameAsync = ref.watch(userNameProvider(request.sellerId));

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID Retur: ${request.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Dibuat: ${DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt.toDate())}'),
            const Divider(),

            // Detail Pembeli & Jastiper
            Row(
              children: [
                Expanded(child: Text('Pembeli: ${request.buyerId}')),
                Expanded(child: Text('Jastiper: ${request.sellerId}')),
              ],
            ),
            const SizedBox(height: 8),

            // Alasan Retur
            Text('Alasan Retur: ${request.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),

            // Respon Jastiper
            if (request.responseReason != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Respon Jastiper:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(request.responseReason!, style: const TextStyle(color: Colors.blue)),
                ],
              ),

            const SizedBox(height: 16),

            // Tombol Finalisasi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    ref.read(returnRequestProvider.notifier).finalizeReturn(request.id, true);
                    _showSuccessDialog(context, 'Retur disetujui. Jastiper akan mengirim ulang barang.');
                  },
                  child: const Text('Setujui Retur'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref.read(returnRequestProvider.notifier).finalizeReturn(request.id, false);
                    _showSuccessDialog(context, 'Retur ditolak. Transaksi tetap berjalan.');
                  },
                  child: const Text('Tolak Retur'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}