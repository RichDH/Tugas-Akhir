// File: lib/fitur/admin/presentation/screens/return_review_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(title: const Text('Review Retur')),
      body: returnRequestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('Tidak ada permintaan retur.'));
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _ReturnRequestCard(request: request);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
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
                Expanded(
                  child: buyerNameAsync.when(
                    data: (name) => Text('Pembeli: $name'),
                    loading: () => const Text('Memuat...'),
                    error: (err, stack) => Text('Pembeli: ${request.buyerId}'),
                  ),
                ),
                Expanded(
                  child: sellerNameAsync.when(
                    data: (name) => Text('Jastiper: $name'),
                    loading: () => const Text('Memuat...'),
                    error: (err, stack) => Text('Jastiper: ${request.sellerId}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Alasan Retur
            Text('Alasan: ${request.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),

            // Evidence (Gambar/Video)
            if (request.evidenceUrls.isNotEmpty)
              Column(
                children: request.evidenceUrls.map((url) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Image.network(url, height: 100, fit: BoxFit.cover),
                  );
                }).toList(),
              ),

            const SizedBox(height: 16),

            // ✅ TOMBOL AKSI (HANYA SATU SET)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    ref.read(returnRequestProvider.notifier).approveReturnRequest(request.id);
                    _showSuccessDialog(context, 'Retur disetujui. Dikirim ke jastiper.');
                  },
                  child: const Text('Setujui'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref.read(returnRequestProvider.notifier).rejectReturnRequest(request.id);
                    _showSuccessDialog(context, 'Retur ditolak.');
                  },
                  child: const Text('Tolak'),
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