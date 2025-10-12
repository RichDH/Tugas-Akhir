// File: lib/fitur/profile/presentation/screens/transaction_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../../../jualbeli/domain/entities/transaction_entity.dart';

// ✅ AUTH-SAFE TRANSACTION PROVIDER UNTUK BUYER (SAMA SEPERTI SEBELUMNYA)
final safeTransactionsByBuyerProvider = StreamProvider.family<List<Transaction>, String>((ref, buyerId) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    loading: () => Stream.value([]),
    error: (error, _) => Stream.error(error),
    data: (user) {
      if (user == null) {
        return Stream.error('User not authenticated');
      }

      if (user.uid != buyerId) {
        return Stream.error('User ID mismatch');
      }

      print('✅ Safe to access Firestore for buyer: ${user.uid}');

      final firestore = ref.watch(firebaseFirestoreProvider);

      return firestore
          .collection('transactions')
          .where('buyerId', isEqualTo: buyerId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return Transaction(
            id: doc.id,
            postId: data['postId'] ?? '',
            buyerId: data['buyerId'] ?? '',
            sellerId: data['sellerId'] ?? '',
            amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
            status: TransactionStatus.values.firstWhere(
                  (e) => e.name == data['status'],
              orElse: () => TransactionStatus.pending,
            ),
            createdAt: data['createdAt'] ?? Timestamp.now(),
            shippedAt: data['shippedAt'],
            deliveredAt: data['deliveredAt'],
            refundReason: data['refundReason'],
            isEscrow: data['isEscrow'] ?? false,
            escrowAmount: (data['escrowAmount'] as num?)?.toDouble() ?? 0.0,
            releaseToSellerAt: data['releaseToSellerAt'],
            isAcceptedBySeller: data['isAcceptedBySeller'] ?? false,
            rejectionReason: data['rejectionReason'],
          );
        }).toList();
      }).handleError((error) {
        print('❌ Buyer transactions stream error: $error');
        throw error;
      });
    },
  );
});

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Riwayat Transaksi')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Riwayat Transaksi')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Auth Error: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(authStateChangesProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Riwayat Transaksi')),
            body: const Center(
              child: Text('Silakan login terlebih dahulu'),
            ),
          );
        }

        return _buildAuthenticatedContent(context, ref, user.uid);
      },
    );
  }

  Widget _buildAuthenticatedContent(BuildContext context, WidgetRef ref, String userId) {
    return DefaultTabController(
      length: 5, // ✅ UBAH DARI 4 JADI 5 TAB
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat Transaksi'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Semua'),
              Tab(text: 'Diproses'),
              Tab(text: 'Dikirim'),
              Tab(text: 'Selesai'), // ✅ KHUSUS DELIVERED
              Tab(text: 'Dibatalkan'), // ✅ KHUSUS CANCELLED
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAllTransactions(context, ref, userId),
            _buildProcessingTransactions(context, ref, userId),
            _buildShippedTransactions(context, ref, userId),
            _buildCompletedTransactions(context, ref, userId), // ✅ KHUSUS DELIVERED
            _buildCancelledTransactions(context, ref, userId), // ✅ KHUSUS CANCELLED
          ],
        ),
      ),
    );
  }

  // ✅ TAB SEMUA TRANSAKSI
  Widget _buildAllTransactions(BuildContext context, WidgetRef ref, String userId) {
    final transactionsAsync = ref.watch(safeTransactionsByBuyerProvider(userId));

    return _buildTransactionList(
      transactionsAsync: transactionsAsync,
      filter: (transactions) => transactions, // Semua transaksi
      emptyMessage: 'Belum ada riwayat transaksi.',
      ref: ref,
    );
  }

  // ✅ TAB DIPROSES (PENDING + PAID)
  Widget _buildProcessingTransactions(BuildContext context, WidgetRef ref, String userId) {
    final transactionsAsync = ref.watch(safeTransactionsByBuyerProvider(userId));

    return _buildTransactionList(
      transactionsAsync: transactionsAsync,
      filter: (transactions) => transactions.where((t) =>
      t.status == TransactionStatus.pending ||
          t.status == TransactionStatus.paid
      ).toList(),
      emptyMessage: 'Tidak ada transaksi yang sedang diproses.',
      ref: ref,
    );
  }

  // ✅ TAB DIKIRIM (SHIPPED)
  Widget _buildShippedTransactions(BuildContext context, WidgetRef ref, String userId) {
    final transactionsAsync = ref.watch(safeTransactionsByBuyerProvider(userId));

    return _buildTransactionList(
      transactionsAsync: transactionsAsync,
      filter: (transactions) => transactions.where((t) =>
      t.status == TransactionStatus.shipped
      ).toList(),
      emptyMessage: 'Tidak ada transaksi yang sedang dikirim.',
      ref: ref,
    );
  }

  // ✅ TAB SELESAI (DELIVERED SAJA)
  Widget _buildCompletedTransactions(BuildContext context, WidgetRef ref, String userId) {
    final transactionsAsync = ref.watch(safeTransactionsByBuyerProvider(userId));

    return _buildTransactionList(
      transactionsAsync: transactionsAsync,
      filter: (transactions) => transactions.where((t) =>
      t.status == TransactionStatus.delivered
      ).toList(),
      emptyMessage: 'Tidak ada transaksi yang selesai.',
      ref: ref,
    );
  }

  // ✅ TAB DIBATALKAN (CANCELLED SAJA)
  Widget _buildCancelledTransactions(BuildContext context, WidgetRef ref, String userId) {
    final transactionsAsync = ref.watch(safeTransactionsByBuyerProvider(userId));

    return _buildTransactionList(
      transactionsAsync: transactionsAsync,
      filter: (transactions) => transactions.where((t) =>
      t.status == TransactionStatus.refunded
      ).toList(),
      emptyMessage: 'Tidak ada transaksi yang dibatalkan.',
      ref: ref,
    );
  }

  // ✅ HELPER METHOD UNTUK BUILD TRANSACTION LIST (SAMA SEPERTI SEBELUMNYA)
  Widget _buildTransactionList({
    required AsyncValue<List<Transaction>> transactionsAsync,
    required List<Transaction> Function(List<Transaction>) filter,
    required String emptyMessage,
    required WidgetRef ref,
  }) {
    return transactionsAsync.when(
      data: (transactions) {
        final filteredTransactions = filter(transactions);

        if (filteredTransactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(safeTransactionsByBuyerProvider);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filteredTransactions.length,
            itemBuilder: (context, index) {
              final transaction = filteredTransactions[index];
              return _TransactionHistoryCard(transaction: transaction);
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
            Text('Memuat riwayat transaksi...'),
          ],
        ),
      ),
      error: (err, stack) {
        print('❌ Transaction history error: $err');

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Terjadi kesalahan:',
                  style: TextStyle(fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              Text(
                  err.toString().contains('permission-denied')
                      ? 'Sesi login bermasalah. Silakan logout dan login ulang.'
                      : err.toString(),
                  textAlign: TextAlign.center
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(authStateChangesProvider);
                  ref.invalidate(safeTransactionsByBuyerProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ✅ CARD UNTUK MENAMPILKAN TRANSACTION HISTORY (SAMA SEPERTI SEBELUMNYA)
class _TransactionHistoryCard extends ConsumerWidget {
  final Transaction transaction;

  const _TransactionHistoryCard({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formattedPrice = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0
    ).format(transaction.amount);

    final sellerNameAsync = ref.watch(userNameProvider(transaction.sellerId));

    // ✅ STATUS COLOR MAPPING
    Color getStatusColor(TransactionStatus status) {
      switch (status) {
        case TransactionStatus.pending:
          return Colors.orange;
        case TransactionStatus.paid:
          return Colors.blue;
        case TransactionStatus.shipped:
          return Colors.purple;
        case TransactionStatus.delivered:
          return Colors.green;
        case TransactionStatus.refunded:
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    // ✅ STATUS TEXT MAPPING
    String getStatusText(TransactionStatus status) {
      switch (status) {
        case TransactionStatus.pending:
          return 'Menunggu Konfirmasi';
        case TransactionStatus.paid:
          return 'Sudah Dibayar';
        case TransactionStatus.shipped:
          return 'Sedang Dikirim';
        case TransactionStatus.delivered:
          return 'Selesai';
        case TransactionStatus.refunded:
          return 'Dibatalkan';
        default:
          return status.name;
      }
    }

    // ✅ STATUS ICON MAPPING
    IconData getStatusIcon(TransactionStatus status) {
      switch (status) {
        case TransactionStatus.pending:
          return Icons.hourglass_empty;
        case TransactionStatus.paid:
          return Icons.payment;
        case TransactionStatus.shipped:
          return Icons.local_shipping;
        case TransactionStatus.delivered:
          return Icons.check_circle;
        case TransactionStatus.refunded:
          return Icons.cancel;
        default:
          return Icons.help;
      }
    }

    return GestureDetector(
      onTap: () {
        GoRouter.of(context).push('/transaction-detail/${transaction.id}');
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ HEADER ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID: ${transaction.id.substring(0, 8)}...',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: getStatusColor(transaction.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          getStatusIcon(transaction.status),
                          size: 14,
                          color: getStatusColor(transaction.status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          getStatusText(transaction.status),
                          style: TextStyle(
                            color: getStatusColor(transaction.status),
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

              // ✅ SELLER INFO
              sellerNameAsync.when(
                data: (name) => Row(
                  children: [
                    const Icon(Icons.store, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Jastiper: $name'),
                  ],
                ),
                loading: () => const Row(
                  children: [
                    Icon(Icons.store, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('Memuat...'),
                  ],
                ),
                error: (err, stack) => Row(
                  children: [
                    const Icon(Icons.store, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('Jastiper: ${transaction.sellerId.substring(0, 8)}...'),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ✅ AMOUNT
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Total: $formattedPrice',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ✅ DATE
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy, HH:mm').format(
                        transaction.createdAt.toDate()
                    ),
                  ),
                ],
              ),

              // ✅ SHOW CANCELLATION REASON IF CANCELLED
              if (transaction.status == TransactionStatus.refunded &&
                  transaction.rejectionReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Alasan dibatalkan: ${transaction.rejectionReason}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ✅ ACTION BUTTONS (JIKA DIPERLUKAN)
              if (transaction.status == TransactionStatus.shipped) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markAsDelivered(ref, transaction.id, context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Konfirmasi Diterima'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ✅ MARK AS DELIVERED
  void _markAsDelivered(WidgetRef ref, String transactionId, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Penerimaan'),
        content: const Text('Apakah barang sudah diterima dengan baik?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Belum'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Mark as delivered
              await ref.read(transactionProvider.notifier).markAsDelivered(transactionId);

              // Show success dialog
              _showSuccessDialog(context, 'Transaksi berhasil diselesaikan!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Sudah Diterima', style: TextStyle(color: Colors.white)),
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
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
