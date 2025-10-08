import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:program/fitur/jualbeli/domain/entities/transaction_entity.dart';

class ReturnConfirmationScreen extends ConsumerWidget {
  final String transactionId;
  const ReturnConfirmationScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = ref.watch(transactionByIdStreamProvider(transactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Penerimaan Retur')),
      body: transactionAsync.when(
           data: (transaction) {
          if (transaction.status != TransactionStatus.delivered) {
            return const Center(child: Text('Transaksi tidak valid untuk konfirmasi.'));
          }

          return _ReturnConfirmationForm(transactionId: transactionId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ReturnConfirmationForm extends ConsumerWidget {
  final String transactionId;

  const _ReturnConfirmationForm({required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jastiper telah mengirim ulang barang retur.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Jika Anda telah menerima barang tersebut, silakan konfirmasi penerimaan.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: () {
                ref.read(transactionProvider.notifier).confirmReturnReceived(transactionId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Penerimaan retur berhasil dikonfirmasi.')),
                );
                Navigator.pop(context);
              },
              child: const Text('Konfirmasi Diterima'),
            ),
          ),
        ],
      ),
    );
  }
}