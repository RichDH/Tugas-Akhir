// File: lib/fitur/jualbeli/presentation/screens/transaction_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';

import '../../domain/entities/transaction_entity.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = ref.watch(transactionByIdStreamProvider(transactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: transactionAsync.when(
           data: (transaction) {
          final formattedPrice = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(transaction.amount);
          final statusText = _getStatusText(transaction.status);
          final statusColor = _getStatusColor(transaction.status);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ID & Status
              _buildInfoRow('ID Transaksi', transaction.id),
              _buildInfoRow('Status', Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),

              const Divider(height: 32),

              // Pihak Terkait
              _buildInfoRow('Pembeli ID', transaction.buyerId),
              _buildInfoRow('Jastiper ID', transaction.sellerId),

              const Divider(height: 32),

              // Keuangan
              _buildInfoRow('Total Pembayaran', formattedPrice),
              if (transaction.isEscrow)
                _buildInfoRow('Dana Ditahan', 'Ya (Escrow)'),
              if (transaction.releaseToSellerAt != null)
                _buildInfoRow('Dana Dicairkan', DateFormat('dd/MM/yyyy HH:mm').format(transaction.releaseToSellerAt!.toDate())),

              const Divider(height: 32),

              // Waktu
              _buildInfoRow('Dibuat', DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt.toDate())),
              if (transaction.shippedAt != null)
                _buildInfoRow('Dikirim', DateFormat('dd/MM/yyyy HH:mm').format(transaction.shippedAt!.toDate())),
              if (transaction.deliveredAt != null)
                _buildInfoRow('Diterima', DateFormat('dd/MM/yyyy HH:mm').format(transaction.deliveredAt!.toDate())),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            flex: 2,
            child: value is Widget ? value : Text(value.toString()),
          ),
        ],
      ),
    );
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending: return 'Menunggu Konfirmasi';
      case TransactionStatus.paid: return 'Diterima';
      case TransactionStatus.shipped: return 'Dikirim';
      case TransactionStatus.delivered: return 'Selesai';
      case TransactionStatus.refunded: return 'Ditolak/Dibatalkan';
    }
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending: return Colors.orange;
      case TransactionStatus.paid: return Colors.blue;
      case TransactionStatus.shipped: return Colors.purple;
      case TransactionStatus.delivered: return Colors.green;
      case TransactionStatus.refunded: return Colors.red;
    }
  }
}