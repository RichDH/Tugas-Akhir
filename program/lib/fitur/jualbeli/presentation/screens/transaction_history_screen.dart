// File: lib/fitur/jualbeli/presentation/screens/transaction_history_screen.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:program/fitur/jualbeli/domain/entities/transaction_history_filter.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_history_filter_provider.dart';

import '../../domain/entities/return_request_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/return_request_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final transactionsAsync = ref.watch(transactionsByBuyerStreamProvider(currentUserId));
    final currentFilter = ref.watch(transactionHistoryFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: Column(
        children: [
          // ✅ FILTER TABS
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: TransactionHistoryFilter.values.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: currentFilter == filter ? Colors.blue.shade100 : null,
                      side: BorderSide(color: currentFilter == filter ? Colors.blue : Colors.grey),
                    ),
                    onPressed: () {
                      ref.read(transactionHistoryFilterProvider.notifier).setFilter(filter);
                    },
                    child: Text(filter.label),
                  ),
                );
              }).toList(),
            ),
          ),

          // ✅ DAFTAR TRANSAKSI (DIFILTER)
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                final filtered = _filterTransactions(transactions, currentFilter);
                if (filtered.isEmpty) {
                  return const Center(child: Text('Tidak ada transaksi.'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final transaction = filtered[index];
                    return _TransactionHistoryCard(transaction: transaction);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  List<Transaction> _filterTransactions(List<Transaction> transactions, TransactionHistoryFilter filter) {
    switch (filter) {
      case TransactionHistoryFilter.all:
        return transactions;
      case TransactionHistoryFilter.processing:
        return transactions.where((t) => t.status == TransactionStatus.pending || t.status == TransactionStatus.paid).toList();
      case TransactionHistoryFilter.shipped:
        return transactions.where((t) => t.status == TransactionStatus.shipped).toList();
      case TransactionHistoryFilter.delivered:
        return transactions.where((t) => t.status == TransactionStatus.delivered).toList();
      case TransactionHistoryFilter.refunded:
        return transactions.where((t) => t.status == TransactionStatus.refunded).toList();
    }
  }
}

class _TransactionHistoryCard extends ConsumerStatefulWidget {
  final Transaction transaction;

  const _TransactionHistoryCard({required this.transaction});

  @override
  ConsumerState<_TransactionHistoryCard> createState() => _TransactionHistoryCardState();
}

class _TransactionHistoryCardState extends ConsumerState<_TransactionHistoryCard> {
  XFile? _evidenceImage;

  @override
  Widget build(BuildContext context) {
    final formattedPrice = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(widget.transaction.amount);
    final statusText = _getStatusText(widget.transaction.status);
    final statusColor = _getStatusColor(widget.transaction.status);
    final returnRequestsAsync = ref.watch(returnRequestsByTransactionIdStreamProvider(widget.transaction.id));

    // ✅ Cek apakah ada retur yang disetujui
    final hasApprovedReturn = returnRequestsAsync.maybeWhen(
      data: (requests) => requests.any((r) => r.status == ReturnStatus.finalApproved),
      orElse: () => false,
    );

    // Ambil nama jastiper
    final sellerNameAsync = ref.watch(userNameProvider(widget.transaction.sellerId));

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text('ID: ${widget.transaction.id}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sellerNameAsync.when(
              data: (name) => Text('Jastiper: $name'),
              loading: () => const Text('Memuat jastiper...'),
              error: (err, stack) => Text('Jastiper: ${widget.transaction.sellerId}'),
            ),
            Text('Total: $formattedPrice'),
            Text('Status: $statusText', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
            Text('Dibuat: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.transaction.createdAt.toDate())}'),
            if (widget.transaction.rating != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Text('Rating: ${widget.transaction.rating} ⭐'),
                  ],
                ),
              ),
          ],
        ),
          // ✅ Tampilkan rating jika ada (tanpa review)

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.transaction.status == TransactionStatus.pending)
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _cancelTransaction(context, widget.transaction.id),
                tooltip: 'Batalkan',
              ),
            // Di dalam trailing Row() di _TransactionHistoryCard.build()
            if (widget.transaction.status == TransactionStatus.delivered)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _completeTransaction(context, widget.transaction.id),
                    child: const Text('Selesai'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.replay, color: Colors.blue),
                    onPressed: () => _initiateReturn(context, widget.transaction.id),
                    tooltip: 'Ajukan Retur',
                  ),
                  if (hasApprovedReturn)
                    ElevatedButton(
                      onPressed: () {
                        GoRouter.of(context).push('/return-confirmation/${widget.transaction.id}');
                      },
                      child: const Text('Konfirmasi Diterima'),
                    ),
                ],
              ),
            Icon(_getStatusIcon(widget.transaction.status), color: statusColor),

          ],
        ),
        onTap: () {
          GoRouter.of(context).push('/transaction-detail/${widget.transaction.id}');
        },
      ),
    );
  }

  void _completeTransaction(BuildContext context, String transactionId) {
    showDialog(
      context: context,
      builder: (context) {
        final ratingController = TextEditingController();
        final reviewController = TextEditingController();

        return AlertDialog(
          title: const Text('Selesaikan Transaksi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ratingController,
                decoration: const InputDecoration(hintText: 'Rating (1-5)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(hintText: 'Ulasan...'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final rating = int.tryParse(ratingController.text.trim());
                final review = reviewController.text.trim();

                if (rating == null || rating < 1 || rating > 5) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rating harus antara 1-5')));
                  return;
                }

                ref.read(transactionProvider.notifier).completeTransaction(transactionId, rating);
                ref.read(transactionProvider.notifier).releaseEscrowFunds(transactionId);
                Navigator.pop(context);
                _showSuccessDialog(context, 'Transaksi berhasil diselesaikan. Terima kasih atas rating Anda!');
              },
              child: const Text('Selesai'),
            ),
          ],
        );
      },
    );
  }

  void _cancelTransaction(BuildContext context, String transactionId) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Alasan Pembatalan'),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Alasan...')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(
              onPressed: () {
                ref.read(transactionProvider.notifier).rejectTransaction(transactionId, controller.text);
                Navigator.pop(context);
                _showSuccessDialog(context, 'Transaksi berhasil dibatalkan.');
              },
              child: const Text('Batalkan'),
            ),
          ],
        );
      },
    );
  }

  void _initiateReturn(BuildContext context, String transactionId) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        XFile? evidenceImage;

        return AlertDialog(
          title: const Text('Ajukan Retur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Alasan Retur...'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              // ✅ Tombol Pilih Gambar
              ElevatedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    setState(() {
                      evidenceImage = pickedFile;
                    });
                  }
                },
                icon: const Icon(Icons.image),
                label: const Text('Pilih Gambar Pendukung'),
              ),
              const SizedBox(height: 8),
              // ✅ Tampilkan Preview Gambar
              if (evidenceImage != null)
                Container(
                  height: 100,
                  width: double.infinity,
                  child: Image.file(File(evidenceImage!.path), fit: BoxFit.cover),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final reason = controller.text.trim();

                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alasan retur wajib diisi')));
                  return;
                }

                // ✅ Upload gambar ke Cloudinary
                String? evidenceUrl;
                if (evidenceImage != null) {
                  try {
                    final cloudinary = CloudinaryPublic('ds656gqe2', 'ngoper_unsigned_upload');
                    final response = await cloudinary.uploadFile(
                      CloudinaryFile.fromFile(
                        evidenceImage!.path,
                        folder: "return_evidences/${widget.transaction.sellerId}",
                        resourceType: CloudinaryResourceType.Image,
                      ),
                    );
                    evidenceUrl = response.secureUrl;
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengunggah gambar pendukung')));
                    return;
                  }
                }

                // ✅ Buat array evidenceUrls
                final evidenceUrls = evidenceUrl != null ? [evidenceUrl] : <String>[];

                // ✅ Kirim ke provider
                ref.read(returnRequestProvider.notifier).createReturnRequest(
                  transactionId: transactionId,
                  buyerId: FirebaseAuth.instance.currentUser!.uid, // ✅ Gunakan FirebaseAuth.instance
                  sellerId: widget.transaction.sellerId,
                  reason: reason,
                  evidenceUrls: evidenceUrls,
                );

                Navigator.pop(context);
                _showSuccessDialog(context, 'Permintaan retur berhasil diajukan. Tunggu review dari admin.');
              },
              child: const Text('Ajukan'),
            ),
          ],
        );
      },
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

  IconData _getStatusIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending: return Icons.hourglass_empty;
      case TransactionStatus.paid: return Icons.check_circle_outline;
      case TransactionStatus.shipped: return Icons.local_shipping;
      case TransactionStatus.delivered: return Icons.done_all;
      case TransactionStatus.refunded: return Icons.cancel;
    }
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