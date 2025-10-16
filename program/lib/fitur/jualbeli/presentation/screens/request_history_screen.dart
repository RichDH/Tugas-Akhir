// File: lib/fitur/jualbeli/presentation/screens/request_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/post/domain/entities/offer.dart';
import 'package:program/fitur/post/presentation/providers/offer_provider.dart';

import '../../../../core/exception/balance_exception.dart';

class RequestHistoryScreen extends ConsumerStatefulWidget {
  const RequestHistoryScreen({super.key});

  @override
  ConsumerState<RequestHistoryScreen> createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends ConsumerState<RequestHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _quantityController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Tawaran'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pesanan Saya', icon: Icon(Icons.send)),
            Tab(text: 'Pesanan Masuk', icon: Icon(Icons.inbox)),
          ],
        ),
      ),
      body: authState.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Silakan login terlebih dahulu'),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildMyOffers(user.uid),
              _buildIncomingOffers(user.uid),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(authStateChangesProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyOffers(String userId) {
    final offersAsync = ref.watch(offersByOffererProvider(userId));

    return offersAsync.when(
      data: (offers) => _buildOffersList(offers, isMyOffers: true),
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat pesanan saya...'),
          ],
        ),
      ),
      error: (error, stack) => _buildErrorWidget(error, () {
        ref.invalidate(offersByOffererProvider);
      }),
    );
  }

  Widget _buildIncomingOffers(String userId) {
    final offersAsync = ref.watch(offersByPostOwnerProvider(userId));

    return offersAsync.when(
      data: (offers) => _buildOffersList(offers, isMyOffers: false),
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat pesanan masuk...'),
          ],
        ),
      ),
      error: (error, stack) => _buildErrorWidget(error, () {
        ref.invalidate(offersByPostOwnerProvider);
      }),
    );
  }

  Widget _buildOffersList(List<Offer> offers, {required bool isMyOffers}) {
    if (offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMyOffers ? Icons.send_outlined : Icons.inbox_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isMyOffers
                  ? 'Belum ada tawaran yang Anda buat'
                  : 'Belum ada tawaran masuk',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              isMyOffers
                  ? 'Tawaran untuk mengambil pesanan akan muncul di sini'
                  : 'Tawaran dari jastiper akan muncul di sini',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (isMyOffers) {
          ref.invalidate(offersByOffererProvider);
        } else {
          ref.invalidate(offersByPostOwnerProvider);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          return _OfferCard(
            offer: offer,
            isMyOffer: isMyOffers,
            onAccept: () => _showAcceptOfferDialog(offer),
            onReject: () => _showRejectOfferDialog(offer),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(Object error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Terjadi kesalahan:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAcceptOfferDialog(Offer offer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terima Tawaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tawaran dari: ${offer.offererUsername}'),
            Text('Harga: Rp ${NumberFormat.currency(locale: 'id', symbol: '').format(offer.offerPrice)}'),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Jumlah Quantity',
                hintText: 'Masukkan jumlah barang',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final quantity = int.tryParse(_quantityController.text) ?? 1;
                final total = offer.offerPrice * quantity;
                return Text(
                  'Total: Rp ${NumberFormat.currency(locale: 'id', symbol: '').format(total)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          Consumer(
            builder: (context, ref, _) {
              final offerState = ref.watch(offerProvider);
              return offerState.when(
                data: (_) => ElevatedButton(
                  onPressed: () => _acceptOffer(offer),
                  child: const Text('Bayar Sekarang'),
                ),
                loading: () => const ElevatedButton(
                  onPressed: null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Processing...'),
                    ],
                  ),
                ),
                error: (error, _) => ElevatedButton(
                  onPressed: () => _acceptOffer(offer),
                  child: const Text('Bayar Sekarang'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRejectOfferDialog(Offer offer) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Tawaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tolak tawaran dari: ${offer.offererUsername}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan penolakan',
                hintText: 'Jelaskan alasan penolakan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _rejectOffer(offer.id, reasonController.text),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  void _acceptOffer(Offer offer) async {
    Navigator.pop(context); // Close dialog

    final quantity = int.tryParse(_quantityController.text) ?? 1;

    try {
      await ref.read(offerProvider.notifier).acceptOfferAndCreateTransaction(
        offerId: offer.id,
        offer: offer,
        quantity: quantity,
      );

      if (mounted) {
        _showSuccessDialog(offer.offerPrice * quantity);
      }
    } catch (e) {
      if (mounted) {
        // ✅ CEK JENIS ERROR DAN TAMPILKAN DIALOG YANG SESUAI
        if (e is InsufficientBalanceException) {
          _showInsufficientBalanceDialog(e.required, e.available);
        } else {
          _showGenericErrorDialog(e.toString());
        }
      }
    }
  }

// ✅ DIALOG SUCCESS
  void _showSuccessDialog(double totalAmount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tawaran Diterima'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text(
              'Transaksi berhasil dibuat!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Text(
                    '🔒 Saldo telah dipotong dan disimpan aman',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Penjual akan segera memproses pesanan',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to transaction history
              context.push('/transaction-history');
            },
            child: const Text('Lihat Transaksi'),
          ),
        ],
      ),
    );
  }

// ✅ DIALOG SALDO TIDAK CUKUP (COPY DARI POST_DETAIL_SCREEN)
  void _showInsufficientBalanceDialog(double totalAmount, double userBalance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saldo Tidak Mencukupi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Saldo Anda: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(userBalance)}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Total yang dibutuhkan: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Kurang: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount - userBalance)}',
              style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Column(
                children: [
                  Text(
                    '💡 Silakan top up saldo Anda terlebih dahulu',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tawaran masih bisa diterima setelah saldo mencukupi',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to top-up page
              context.push('/top-up');
            },
            child: const Text('Top Up Saldo'),
          ),
        ],
      ),
    );
  }

// ✅ DIALOG ERROR UMUM
  void _showGenericErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terjadi Kesalahan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal memproses tawaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                errorMessage,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Silakan coba lagi atau hubungi customer service',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Refresh untuk coba lagi
              ref.invalidate(offersByPostOwnerProvider);
            },
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }



  void _rejectOffer(String offerId, String reason) async {
    Navigator.pop(context); // Close dialog

    if (reason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alasan penolakan tidak boleh kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await ref.read(offerProvider.notifier).rejectOffer(offerId, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tawaran ditolak'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ✅ OFFER CARD WIDGET
class _OfferCard extends StatelessWidget {
  final Offer offer;
  final bool isMyOffer;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _OfferCard({
    required this.offer,
    required this.isMyOffer,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    offer.postTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isMyOffer
                  ? 'Request dari anda'
                  : 'Ditawarkan oleh: ${offer.offererUsername}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Harga: Rp ${NumberFormat.currency(locale: 'id', symbol: '').format(offer.offerPrice)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(offer.createdAt.toDate()),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            if (!isMyOffer && offer.status == OfferStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Terima', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onReject,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text('Tolak', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
            if (offer.status == OfferStatus.rejected && offer.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alasan Ditolak:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      offer.rejectionReason!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;
    IconData icon;

    switch (offer.status) {
      case OfferStatus.pending:
        color = Colors.orange;
        text = 'Menunggu';
        icon = Icons.access_time;
        break;
      case OfferStatus.accepted:
        color = Colors.green;
        text = 'Diterima';
        icon = Icons.check_circle;
        break;
      case OfferStatus.rejected:
        color = Colors.red;
        text = 'Ditolak';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
