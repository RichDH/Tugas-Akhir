import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';
import 'package:program/fitur/jualbeli/domain/entities/return_request_entity.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../../../jualbeli/domain/entities/transaction_entity.dart';

// ✅ PERUBAHAN: Menambahkan .autoDispose agar state di-reset otomatis saat logout
final safeTransactionsByBuyerProvider = StreamProvider.autoDispose.family<List<Transaction>, String>((ref, buyerId) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    loading: () => Stream.value([]),
    error: (error, _) => Stream.error(error),
    data: (user) {
      if (user == null) {
        return Stream.error('User not authenticated');
      }

      // Pengecekan 'user.uid != buyerId' dihilangkan agar lebih aman saat transisi login/logout
      // Karena provider akan otomatis di-reset, pengecekan ini tidak lagi diperlukan.

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
            completedAt: data['completedAt'],
            refundReason: data['refundReason'],
            isEscrow: data['isEscrow'] ?? false,
            escrowAmount: (data['escrowAmount'] as num?)?.toDouble() ?? 0.0,
            releaseToSellerAt: data['releaseToSellerAt'],
            isAcceptedBySeller: data['isAcceptedBySeller'] ?? false,
            rejectionReason: data['rejectionReason'],
            rating: data['rating'] as int?,
            buyerAddress: data['buyerAddress'] as String?,
          );
        }).toList();
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
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat Transaksi'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Semua'),
              Tab(text: 'Diproses'),
              Tab(text: 'Dikirim'),
              Tab(text: 'Diterima'),
              Tab(text: 'Selesai'),
              Tab(text: 'Dibatalkan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAllTransactions(context, ref, userId),
            _buildProcessingTransactions(context, ref, userId),
            _buildShippedTransactions(context, ref, userId),
            _buildDeliveredTransactions(context, ref, userId),
            _buildCompletedTransactions(context, ref, userId),
            _buildCancelledTransactions(context, ref, userId),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTransactions(BuildContext context, WidgetRef ref, String userId) {
    final transactionsAsync = ref.watch(safeTransactionsByBuyerProvider(userId));

    return _buildTransactionList(
      transactionsAsync: transactionsAsync,
      filter: (transactions) => transactions,
      emptyMessage: 'Belum ada riwayat transaksi.',
      ref: ref,
    );
  }

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

  Widget _buildDeliveredTransactions(BuildContext context, WidgetRef ref, String userId) {
    final transactionsAsync = ref.watch(safeTransactionsByBuyerProvider(userId));

    return _buildTransactionList(
      transactionsAsync: transactionsAsync,
      filter: (transactions) => transactions.where((t) =>
      t.status == TransactionStatus.delivered
      ).toList(),
      emptyMessage: 'Tidak ada transaksi yang diterima.',
      ref: ref,
    );
  }

  Widget _buildCompletedTransactions(BuildContext context, WidgetRef ref, String userId) {
    final transactionsAsync = ref.watch(safeTransactionsByBuyerProvider(userId));

    return _buildTransactionList(
      transactionsAsync: transactionsAsync,
      filter: (transactions) => transactions.where((t) =>
      t.status == TransactionStatus.completed
      ).toList(),
      emptyMessage: 'Tidak ada transaksi yang selesai.',
      ref: ref,
    );
  }

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
            // Invalidate-nya sekarang tidak perlu manual karena sudah autoDispose,
            // tapi bisa tetap di sini untuk fitur pull-to-refresh
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
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
                  // Tidak perlu invalidate safeTransactionsByBuyerProvider secara eksplisit
                  // karena authStateChangesProvider akan memicu rebuild.
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
    final returnRequestsAsync = ref.watch(returnRequestsByTransactionIdStreamProvider(transaction.id));

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
        case TransactionStatus.completed:
          return Colors.teal;
        case TransactionStatus.refunded:
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    String getStatusText(TransactionStatus status, bool hasActiveReturn) {
      if (hasActiveReturn && status == TransactionStatus.delivered) {
        return 'Diproses Retur';
      }
      switch (status) {
        case TransactionStatus.pending:
          return 'Menunggu Konfirmasi';
        case TransactionStatus.paid:
          return 'Sudah Dibayar';
        case TransactionStatus.shipped:
          return 'Sedang Dikirim';
        case TransactionStatus.delivered:
          return 'Diterima';
        case TransactionStatus.completed:
          return 'Selesai';
        case TransactionStatus.refunded:
          return 'Dibatalkan';
        default:
          return status.name;
      }
    }

    IconData getStatusIcon(TransactionStatus status, bool hasActiveReturn) {
      if (hasActiveReturn && status == TransactionStatus.delivered) {
        return Icons.assignment_return;
      }
      switch (status) {
        case TransactionStatus.pending:
          return Icons.hourglass_empty;
        case TransactionStatus.paid:
          return Icons.payment;
        case TransactionStatus.shipped:
          return Icons.local_shipping;
        case TransactionStatus.delivered:
          return Icons.check_circle;
        case TransactionStatus.completed:
          return Icons.star;
        case TransactionStatus.refunded:
          return Icons.cancel;
        default:
          return Icons.help;
      }
    }

    return returnRequestsAsync.when(
      data: (returnRequests) {
        final hasActiveReturn = returnRequests.any((r) =>
        r.status == ReturnStatus.pending ||
            r.status == ReturnStatus.approved ||
            r.status == ReturnStatus.awaitingSellerResponse ||
            r.status == ReturnStatus.sellerResponded
        );

        final displayStatusColor = hasActiveReturn && transaction.status == TransactionStatus.delivered
            ? Colors.orange
            : getStatusColor(transaction.status);

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
                          color: displayStatusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              getStatusIcon(transaction.status, hasActiveReturn),
                              size: 14,
                              color: displayStatusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              getStatusText(transaction.status, hasActiveReturn),
                              style: TextStyle(
                                color: displayStatusColor,
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
                  sellerNameAsync.when(
                    data: (name) => Row(
                      children: [
                        const Icon(Icons.store, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Jastiper: ${name ?? 'Unknown'}'),
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
                        const SizedBox(width: 4),
                        Text('Jastiper: ${transaction.sellerId.substring(0, 8)}...'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  if (transaction.buyerAddress != null && transaction.buyerAddress!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Alamat: ${transaction.buyerAddress}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hasActiveReturn && transaction.status != TransactionStatus.refunded) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Retur sedang diproses. Tombol aksi tidak tersedia.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (hasActiveReturn && transaction.status == TransactionStatus.refunded) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Retur Berhasil disetujui.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (transaction.status == TransactionStatus.completed && transaction.rating != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.teal),
                          const SizedBox(width: 4),
                          Text(
                            'Rating: ${transaction.rating}/5',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  if (transaction.status == TransactionStatus.delivered && !hasActiveReturn) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: () => _showCompleteTransactionDialog(ref, transaction.id, context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.star_outline, size: 18),
                            label: const Text('Selesaikan'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            onPressed: () => _navigateToCreateReturnRequest(context, transaction.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            icon: const Icon(Icons.assignment_return, size: 18),
                            label: const Text('Retur'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      loading: () => _buildCardSkeleton(),
      error: (error, stack) => _buildCardSkeleton(),
    );
  }

  Widget _buildCardSkeleton() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(height: 16, width: 120, color: Colors.grey[300]),
                Container(height: 24, width: 80, color: Colors.grey[300]),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 14, width: 200, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Container(height: 18, width: 150, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Container(height: 14, width: 220, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  void _navigateToCreateReturnRequest(BuildContext context, String transactionId) {
    if (transactionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID transaksi tidak valid'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    GoRouter.of(context).push('/create-return-request/$transactionId');
  }

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
              await ref.read(transactionProvider.notifier).markAsDelivered(transactionId);
              _showSuccessDialog(context, 'Transaksi berhasil dikonfirmasi diterima!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Sudah Diterima', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCompleteTransactionDialog(WidgetRef ref, String transactionId, BuildContext context) {
    int selectedRating = 5;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Selesaikan Transaksi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Berikan rating untuk jastiper:'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedRating = index + 1);
                    },
                    child: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      size: 36,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text('Rating: $selectedRating/5'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💰 Dana akan dicairkan ke jastiper setelah transaksi selesai',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
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
                await ref.read(transactionProvider.notifier).completeTransactionAndReleaseFunds(transactionId, selectedRating);
                _showSuccessDialog(context, 'Transaksi berhasil diselesaikan! Dana telah dicairkan ke jastiper.');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Selesaikan', style: TextStyle(color: Colors.white)),
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