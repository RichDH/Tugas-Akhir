import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/domain/entities/transaction_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';

// Stream semua transaksi untuk admin (urut tanggal desc)
final adminAllTransactionsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('transactions')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
    final d = doc.data();
    return Transaction(
      id: doc.id,
      postId: d['postId'] ?? '',
      buyerId: d['buyerId'] ?? '',
      sellerId: d['sellerId'] ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      status: TransactionStatus.values.firstWhere(
            (e) => e.name == d['status'],
        orElse: () => TransactionStatus.pending,
      ),
      createdAt: d['createdAt'] ?? Timestamp.now(),
      shippedAt: d['shippedAt'],
      deliveredAt: d['deliveredAt'],
      completedAt: d['completedAt'],
      refundReason: d['refundReason'],
      isEscrow: d['isEscrow'] ?? false,
      escrowAmount: (d['escrowAmount'] as num?)?.toDouble() ?? 0.0,
      releaseToSellerAt: d['releaseToSellerAt'],
      isAcceptedBySeller: d['isAcceptedBySeller'] ?? false,
      rejectionReason: d['rejectionReason'],
      rating: d['rating'] as int?,
      buyerAddress: d['buyerAddress'] as String?,
    );
  }).toList());
});

// Helper dapatkan username dari userId
final adminUserNameProvider = FutureProvider.family<String?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  final fs = ref.read(firebaseFirestoreProvider);
  final doc = await fs.collection('users').doc(userId).get();
  final data = doc.data();
  return data?['username'] as String?;
});

class AdminTransactionsScreen extends ConsumerWidget {
  const AdminTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin • Transaksi'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Semua'),
              Tab(text: 'Diproses'),
              Tab(text: 'Dikirim'),
              Tab(text: 'Diterima'),
              Tab(text: 'Selesai'),
              Tab(text: 'Dibatalkan'),
              Tab(text: 'Retur'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(ref, filter: (t) => true, empty: 'Belum ada transaksi.'),
            _buildList(ref, filter: (t) => t.status == TransactionStatus.pending || t.status == TransactionStatus.paid, empty: 'Tidak ada transaksi diproses.'),
            _buildList(ref, filter: (t) => t.status == TransactionStatus.shipped, empty: 'Tidak ada transaksi dikirim.'),
            _buildList(ref, filter: (t) => t.status == TransactionStatus.delivered, empty: 'Tidak ada transaksi diterima.'),
            _buildList(ref, filter: (t) => t.status == TransactionStatus.completed, empty: 'Tidak ada transaksi selesai.'),
            _buildList(ref, filter: (t) => t.status == TransactionStatus.refunded, empty: 'Tidak ada transaksi dibatalkan.'),
            // Khusus Retur (retur aktif pada transaksi apapun)
            _buildList(
              ref,
              filter: (_) => true, // ambil semua lalu tandai yang retur aktif
              empty: 'Tidak ada transaksi dalam proses retur.',
              onlyReturnActive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
      WidgetRef ref, {
        required bool Function(Transaction) filter,
        required String empty,
        bool onlyReturnActive = false,
      }) {
    final txAsync = ref.watch(adminAllTransactionsProvider);
    return txAsync.when(
      data: (all) {
        List<Transaction> base = all.where(filter).toList();
        if (base.isEmpty) {
          return _empty(empty);
        }
        return ListView.builder(
          itemCount: base.length,
          itemBuilder: (context, i) {
            return _AdminTransactionCard(tx: base[i], onlyReturnActive: onlyReturnActive);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _empty(String msg) {
    return Center(
      child: Text(msg, style: const TextStyle(color: Colors.grey)),
    );
  }
}

class _AdminTransactionCard extends ConsumerWidget {
  final Transaction tx;
  final bool onlyReturnActive;

  const _AdminTransactionCard({required this.tx, required this.onlyReturnActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buyerNameAsync = ref.watch(adminUserNameProvider(tx.buyerId));
    final sellerNameAsync = ref.watch(adminUserNameProvider(tx.sellerId));
    final returnsAsync = ref.watch(returnRequestsByTransactionIdStreamProvider(tx.id));
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return returnsAsync.when(
      data: (returnRequests) {
        final hasActiveReturn = returnRequests.any((r) =>
        r.status.name == 'pending' ||
            r.status.name == 'approved' ||
            r.status.name == 'awaitingSellerResponse' ||
            r.status.name == 'sellerResponded');

        if (onlyReturnActive && !hasActiveReturn) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ID: ${tx.id.substring(0, 8)}...',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(tx.status, hasActiveReturn).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(tx.status, hasActiveReturn),
                            size: 14,
                            color: _getStatusColor(tx.status, hasActiveReturn),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusText(tx.status, hasActiveReturn),
                            style: TextStyle(
                              color: _getStatusColor(tx.status, hasActiveReturn),
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

                // Pembeli info
                buyerNameAsync.when(
                  data: (buyerName) => Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Pembeli: @${buyerName ?? "unknown"}'),
                    ],
                  ),
                  loading: () => const Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Pembeli: memuat...'),
                    ],
                  ),
                  error: (e, s) => Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Pembeli: ${tx.buyerId.substring(0, 8)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Penjual info
                sellerNameAsync.when(
                  data: (sellerName) => Row(
                    children: [
                      const Icon(Icons.store, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Jastiper: @${sellerName ?? "unknown"}'),
                    ],
                  ),
                  loading: () => const Row(
                    children: [
                      Icon(Icons.store, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Jastiper: memuat...'),
                    ],
                  ),
                  error: (e, s) => Row(
                    children: [
                      const Icon(Icons.store, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Jastiper: ${tx.sellerId.substring(0, 8)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Amount
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Total: ${formatter.format(tx.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Date
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(tx.createdAt.toDate()),
                    ),
                  ],
                ),

                // Address jika ada
                if (tx.buyerAddress != null && tx.buyerAddress!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Alamat: ${tx.buyerAddress}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],

                // Return info jika aktif
                if (hasActiveReturn) ...[
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
                        Text(
                          'Transaksi ini sedang dalam proses retur',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => _buildCardSkeleton(),
      error: (e, s) => _buildCardSkeleton(),
    );
  }

  Color _getStatusColor(TransactionStatus status, bool hasActiveReturn) {
    if (hasActiveReturn) return Colors.orange;
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

  String _getStatusText(TransactionStatus status, bool hasActiveReturn) {
    if (hasActiveReturn) return 'Dalam proses retur';
    switch (status) {
      case TransactionStatus.pending:
        return 'Diproses';
      case TransactionStatus.paid:
        return 'Dibayar';
      case TransactionStatus.shipped:
        return 'Dikirim';
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

  IconData _getStatusIcon(TransactionStatus status, bool hasActiveReturn) {
    if (hasActiveReturn) return Icons.assignment_return;
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

  Widget _buildCardSkeleton() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(height: 16, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Container(height: 14, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}

