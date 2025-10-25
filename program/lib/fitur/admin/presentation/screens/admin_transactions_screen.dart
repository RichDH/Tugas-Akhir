import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/domain/entities/transaction_entity.dart';
import 'package:program/fitur/jualbeli/presentation/providers/return_request_provider.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../providers/transactionpdfgenerator.dart';

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

class AdminTransactionsScreen extends ConsumerStatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  ConsumerState<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends ConsumerState<AdminTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Transaksi'),
        actions: [
          IconButton(
            icon: _isGeneratingPdf
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.picture_as_pdf),
            onPressed: _isGeneratingPdf ? null : _generatePdfReport,
            tooltip: 'Generate Laporan PDF',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
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
        controller: _tabController,
        children: [
          _buildList(filter: (t) => true, empty: 'Belum ada transaksi.'),
          _buildList(filter: (t) => t.status == TransactionStatus.pending || t.status == TransactionStatus.paid, empty: 'Tidak ada transaksi diproses.'),
          _buildList(filter: (t) => t.status == TransactionStatus.shipped, empty: 'Tidak ada transaksi dikirim.'),
          _buildList(filter: (t) => t.status == TransactionStatus.delivered, empty: 'Tidak ada transaksi diterima.'),
          _buildList(filter: (t) => t.status == TransactionStatus.completed, empty: 'Tidak ada transaksi selesai.'),
          _buildList(filter: (t) => t.status == TransactionStatus.refunded, empty: 'Tidak ada transaksi dibatalkan.'),
          _buildList(
            filter: (_) => true,
            empty: 'Tidak ada transaksi dalam proses retur.',
            onlyReturnActive: true,
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdfReport() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final txAsync = ref.read(adminAllTransactionsProvider);

      await txAsync.when(
        data: (allTransactions) async {
          if (allTransactions.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tidak ada transaksi untuk digenerate')),
              );
            }
            return;
          }

          // Filter berdasarkan tab aktif
          final currentTab = _tabController.index;
          List<Transaction> filteredTransactions;
          String? filterTitle;

          switch (currentTab) {
            case 0: // Semua
              filteredTransactions = allTransactions;
              filterTitle = 'Filter: Semua Transaksi';
              break;
            case 1: // Diproses
              filteredTransactions = allTransactions.where((t) =>
              t.status == TransactionStatus.pending ||
                  t.status == TransactionStatus.paid).toList();
              filterTitle = 'Filter: Transaksi Diproses';
              break;
            case 2: // Dikirim
              filteredTransactions = allTransactions.where((t) =>
              t.status == TransactionStatus.shipped).toList();
              filterTitle = 'Filter: Transaksi Dikirim';
              break;
            case 3: // Diterima
              filteredTransactions = allTransactions.where((t) =>
              t.status == TransactionStatus.delivered).toList();
              filterTitle = 'Filter: Transaksi Diterima';
              break;
            case 4: // Selesai
              filteredTransactions = allTransactions.where((t) =>
              t.status == TransactionStatus.completed).toList();
              filterTitle = 'Filter: Transaksi Selesai';
              break;
            case 5: // Dibatalkan
              filteredTransactions = allTransactions.where((t) =>
              t.status == TransactionStatus.refunded).toList();
              filterTitle = 'Filter: Transaksi Dibatalkan';
              break;
            case 6: // Retur
              filteredTransactions = allTransactions;
              filterTitle = 'Filter: Transaksi Dalam Proses Retur';
              break;
            default:
              filteredTransactions = allTransactions;
              filterTitle = null;
          }

          if (filteredTransactions.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tidak ada transaksi di tab ini')),
              );
            }
            return;
          }

          // Fetch semua username
          final buyerNames = <String, String?>{};
          final sellerNames = <String, String?>{};
          final hasActiveReturns = <String, bool>{};

          for (final tx in filteredTransactions) {
            // Get buyer name
            if (!buyerNames.containsKey(tx.buyerId)) {
              final buyerNameAsync = await ref.read(adminUserNameProvider(tx.buyerId).future);
              buyerNames[tx.buyerId] = buyerNameAsync;
            }

            // Get seller name
            if (!sellerNames.containsKey(tx.sellerId)) {
              final sellerNameAsync = await ref.read(adminUserNameProvider(tx.sellerId).future);
              sellerNames[tx.sellerId] = sellerNameAsync;
            }

            // Check active return
            final returnsAsync = await ref.read(
              returnRequestsByTransactionIdStreamProvider(tx.id).future,
            );
            hasActiveReturns[tx.id] = returnsAsync.any((r) =>
            r.status.name == 'pending' ||
                r.status.name == 'approved' ||
                r.status.name == 'awaitingSellerResponse' ||
                r.status.name == 'sellerResponded');
          }

          // Filter untuk tab retur (hanya yang ada retur aktif)
          if (currentTab == 6) {
            filteredTransactions = filteredTransactions.where((tx) =>
            hasActiveReturns[tx.id] == true).toList();
          }

          if (filteredTransactions.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tidak ada transaksi dengan retur aktif')),
              );
            }
            return;
          }

          // Generate PDF
          final pdfFile = await TransactionPdfGenerator.generateTransactionReport(
            transactions: filteredTransactions,
            buyerNames: buyerNames,
            sellerNames: sellerNames,
            hasActiveReturns: hasActiveReturns,
            filterTitle: filterTitle,
          );

          if (mounted) {
            // Show PDF Preview with download button
            final pdfBytes = await pdfFile.readAsBytes();
            final fileName = pdfFile.path.split('/').last;

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Preview Laporan PDF'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.download),
                        tooltip: 'Download PDF',
                        onPressed: () async {
                          try {
                            Directory? directory;

                            // Get directory based on platform
                            if (Platform.isAndroid) {
                              // For Android, try to get Downloads directory
                              directory = Directory('/storage/emulated/0/Download');
                              if (!await directory.exists()) {
                                directory = Directory('/storage/emulated/0/Downloads');
                              }
                              if (!await directory.exists()) {
                                directory = await getExternalStorageDirectory();
                              }
                            } else if (Platform.isIOS) {
                              directory = await getApplicationDocumentsDirectory();
                            } else {
                              directory = await getDownloadsDirectory();
                            }

                            if (directory == null) {
                              throw Exception('Tidak dapat mengakses folder download');
                            }

                            // Create file path
                            final filePath = '${directory.path}/$fileName';
                            final file = File(filePath);

                            // Write PDF to file
                            await file.writeAsBytes(pdfBytes);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('PDF berhasil didownload!\nLokasi: ${directory.path}'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 4),
                                  action: SnackBarAction(
                                    label: 'OK',
                                    textColor: Colors.white,
                                    onPressed: () {},
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal download: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  body: PdfPreview(
                    build: (format) => pdfBytes,
                    allowSharing: false,
                    allowPrinting: true,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                  ),
                ),
              ),
            );
          }
        },
        loading: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Memuat data transaksi...')),
            );
          }
        },
        error: (error, stack) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $error')),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Widget _buildList({
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