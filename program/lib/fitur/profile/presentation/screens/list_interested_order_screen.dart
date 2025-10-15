// File: list_interested_order_screen.dart - PERBAIKAN LENGKAP
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../jualbeli/presentation/providers/transaction_provider.dart';

class ListInterestedOrderScreen extends ConsumerStatefulWidget {
  const ListInterestedOrderScreen({super.key});

  @override
  ConsumerState<ListInterestedOrderScreen> createState() => _ListInterestedOrderScreenState();
}

class _ListInterestedOrderScreenState extends ConsumerState<ListInterestedOrderScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pesanan Masuk'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Silakan login terlebih dahulu'),
        ),
      );
    }

    return DefaultTabController(
      length: 4, // Semua, Menunggu, Terkirim, Selesai
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pesanan Masuk'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Semua'),
              Tab(text: 'Menunggu'),
              Tab(text: 'Terkirim'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAllOrders(),
            _buildPendingOrders(),
            _buildShippedDeliveredOrders(), // Shipped + Delivered
            _buildCompletedOrders(),
          ],
        ),
      ),
    );
  }

  // ✅ TAB SEMUA PESANAN
  Widget _buildAllOrders() {
    return _buildOrdersList(statusFilter: null);
  }

  // ✅ TAB PESANAN MENUNGGU (PENDING + PAID)
  Widget _buildPendingOrders() {
    return _buildOrdersList(statusFilter: ['pending', 'paid']);
  }

  // ✅ TAB PESANAN TERKIRIM (SHIPPED + DELIVERED)
  Widget _buildShippedDeliveredOrders() {
    return _buildOrdersList(statusFilter: ['shipped', 'delivered']);
  }

  // ✅ TAB PESANAN SELESAI (COMPLETED)
  Widget _buildCompletedOrders() {
    return _buildOrdersList(statusFilter: ['completed']);
  }

  // ✅ STREAM BUILDER UNTUK ORDERS BERDASARKAN FILTER STATUS
  Widget _buildOrdersList({List<String>? statusFilter}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getTransactionsStream(statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  statusFilter == null
                      ? 'Belum ada pesanan masuk'
                      : 'Tidak ada pesanan dengan status ini',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final transactions = snapshot.data!.docs;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              final data = transaction.data() as Map<String, dynamic>;
              return _buildOrderCard(transaction.id, data);
            },
          ),
        );
      },
    );
  }

  // ✅ GET TRANSACTIONS STREAM DENGAN FILTER STATUS
  Stream<QuerySnapshot> _getTransactionsStream(List<String>? statusFilter) {
    Query query = FirebaseFirestore.instance
        .collection('transactions')
        .where('sellerId', isEqualTo: currentUser!.uid)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', whereIn: statusFilter);
    }

    return query.snapshots();
  }

  // ✅ BUILD ORDER CARD YANG BISA DIKLIK KE DETAIL + TOMBOL MARK AS DELIVERED
  Widget _buildOrderCard(String transactionId, Map<String, dynamic> data) {
    final String status = data['status'] ?? 'unknown';
    final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final String buyerId = data['buyerId'] ?? '';
    final Timestamp? createdAt = data['createdAt'];
    final String buyerAddress = data['buyerAddress'] ?? 'Alamat tidak tersedia';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        // ✅ TAMBAHKAN ONTAK UNTUK KLIK KE DETAIL
        onTap: () {
          GoRouter.of(context).push('/transaction-detail/$transactionId');
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ HEADER ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID: ${transactionId.substring(0, 8)}...',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      _buildStatusChip(status),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ✅ BUYER INFO
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(buyerId).get(),
                builder: (context, snapshot) {
                  final buyerName = snapshot.data?.get('username') ?? buyerId;
                  return Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Pembeli: $buyerName'),
                    ],
                  );
                },
              ),

              const SizedBox(height: 8),

              // ✅ AMOUNT
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Total: ${_formatCurrency(amount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ✅ DATE
              if (createdAt != null)
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(createdAt.toDate()),
                    ),
                  ],
                ),

              const SizedBox(height: 8),

              // ✅ BUYER ADDRESS
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alamat Pengiriman:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            buyerAddress,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ ITEMS INFO
              if (data['items'] != null) ...[
                const SizedBox(height: 12),
                _buildItemsList(data['items'] as List),
              ],

              // ✅ ACTION BUTTONS BERDASARKAN STATUS TRANSAKSI
              const SizedBox(height: 16),
              _buildActionButtons(transactionId, status, data),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ BUILD ACTION BUTTONS BERDASARKAN STATUS TRANSAKSI
  Widget _buildActionButtons(String transactionId, String status, Map<String, dynamic> data) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAcceptDialog(transactionId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Terima Pesanan'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showRejectDialog(transactionId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Tolak Pesanan'),
              ),
            ),
          ],
        );

      case 'paid':
      // ✅ TOMBOL MARK AS SHIPPED UNTUK STATUS PAID
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showMarkAsShippedDialog(transactionId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.local_shipping, size: 18),
            label: const Text('Tandai Sudah Dikirim'),
          ),
        );

      case 'shipped':
      // ✅ TOMBOL MARK AS DELIVERED UNTUK STATUS SHIPPED
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showMarkAsDeliveredDialog(transactionId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Tandai Sudah Diterima'),
          ),
        );

      case 'delivered':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.done_all, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text(
                'Menunggu pembeli selesaikan transaksi',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      case 'completed':
      // ✅ SHOW RATING AND COMPLETION INFO
        final int? rating = data['rating'] as int?;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.teal, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Transaksi Selesai - Dana Telah Dicairkan',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (rating != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Rating: ', style: TextStyle(fontSize: 12)),
                    ...List.generate(5, (index) => Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    )),
                    Text(' ($rating/5)', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
        );

      case 'refunded':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text(
                'Pesanan Dibatalkan',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ✅ DIALOG MARK AS SHIPPED UNTUK PENJUAL
  void _showMarkAsShippedDialog(String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.local_shipping, color: Colors.blue),
            SizedBox(width: 8),
            Text('Konfirmasi Pengiriman'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah barang sudah dikirim?'),
            SizedBox(height: 12),
            Text(
              '📦 Pastikan barang sudah benar-benar dikirim sebelum menandai status ini.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
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
              await _markAsShipped(transactionId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text(
              'Ya, Sudah Dikirim',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ DIALOG MARK AS DELIVERED UNTUK PENJUAL
  void _showMarkAsDeliveredDialog(String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.done_all, color: Colors.green),
            SizedBox(width: 8),
            Text('Konfirmasi Penerimaan'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah barang sudah diterima oleh pembeli?'),
            SizedBox(height: 12),
            Text(
              '⚠️ Pastikan pembeli sudah benar-benar menerima barang sebelum menandai status ini.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
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
              await _markAsDelivered(transactionId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'Ya, Sudah Diterima',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MARK AS SHIPPED FUNCTION
  Future<void> _markAsShipped(String transactionId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Mengupdate status...'),
            ],
          ),
        ),
      );

      // Call provider to mark as shipped
      await ref.read(transactionProvider.notifier).markAsShipped(transactionId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success dialog
      if (mounted) _showSuccessDialog('Berhasil menandai pesanan sebagai dikirim!');

    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error
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

  // ✅ MARK AS DELIVERED FUNCTION
  Future<void> _markAsDelivered(String transactionId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Mengupdate status...'),
            ],
          ),
        ),
      );

      // Call provider to mark as delivered
      await ref.read(transactionProvider.notifier).markAsDelivered(transactionId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success dialog
      if (mounted) _showSuccessDialog('Berhasil menandai pesanan sebagai diterima!');

    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error
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

  // ✅ DIALOG ACCEPT ORDER
  void _showAcceptDialog(String transactionId) async {
    // Ambil transaksi untuk dapat sellerId dan jumlah escrow
    final txnDoc = await FirebaseFirestore.instance.collection('transactions').doc(transactionId).get();
    final txn = txnDoc.data() ?? {};
    final sellerId = txn['sellerId'] as String? ?? currentUser!.uid;
    final escrowAmount = (txn['escrowAmount'] as num?)?.toDouble();
    final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
    final toRelease = escrowAmount ?? amount;

    final verified = await _isSellerVerified(sellerId);

    if (!mounted) return;

    if (verified) {
      // Seller belum terverifikasi → langsung ke accepted (paid) seperti biasa
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Terima Pesanan'),
          content: const Text('Akun Anda belum terverifikasi. Pesanan akan ditandai dibayar tanpa pencairan awal.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _acceptOrder(transactionId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Terima', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // Seller terverifikasi → tawarkan pencairan awal
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terima Pesanan & Cairkan Dana?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anda terverifikasi. Anda bisa mencairkan dana sekarang sejumlah ${_formatCurrency(toRelease)}.'),
            const SizedBox(height: 8),
            const Text('Setelah dana dicairkan, status transaksi akan menjadi Dibayar (paid).'),
          ],
        ),
        actions: [
          // Terima tanpa cairkan
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _acceptOrder(transactionId);
            },
            icon: const Icon(Icons.check),
            label: const Text('Terima tanpa cairkan'),
          ),
          // Cairkan lalu terima
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              // proses pencairan + set paid
              await _acceptAndPayout(transactionId: transactionId, sellerId: sellerId, amountToRelease: toRelease);
            },
            icon: const Icon(Icons.account_balance_wallet),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            label: const Text('Cairkan & Terima', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // ✅ DIALOG REJECT ORDER
  void _showRejectDialog(String transactionId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pesanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Alasan penolakan:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Masukkan alasan penolakan...',
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
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alasan penolakan harus diisi')),
                );
                return;
              }
              Navigator.pop(context);
              await _rejectOrder(transactionId, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ ACCEPT ORDER FUNCTION
  Future<void> _acceptOrder(String transactionId) async {
    try {
      await FirebaseFirestore.instance.collection('transactions').doc(transactionId).update({
        'status': 'paid',
        'isAcceptedBySeller': true,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      _showSuccessDialog('Pesanan berhasil diterima!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _acceptAndPayout({
    required String transactionId,
    required String sellerId,
    required double amountToRelease,
  }) async {
    try {
      // Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Memproses pencairan...'),
            ],
          ),
        ),
      );

      // 1) Cairkan dana ke seller
      await _releaseFundsToSeller(
        sellerId: sellerId,
        transactionId: transactionId,
        amount: amountToRelease,
      );

      // 2) Set transaksi menjadi paid + accepted flag
      await FirebaseFirestore.instance.collection('transactions').doc(transactionId).update({
        'status': 'paid',
        'isAcceptedBySeller': true,
        'isEscrow' : false,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context); // tutup loading
      if (mounted) _showSuccessDialog('Dana berhasil dicairkan dan pesanan ditandai dibayar!');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencairkan dana: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  Future<bool> _isSellerVerified(String sellerId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(sellerId).get();
    return (doc.data()?['verificationStatus'] ?? 'verified') == false;
  }

  Future<void> _releaseFundsToSeller({
    required String sellerId,
    required String transactionId,
    required double amount,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final usersRef = FirebaseFirestore.instance.collection('users').doc(sellerId);
    final txnRef = FirebaseFirestore.instance.collection('transactions').doc(transactionId);
    final payoutLogRef = FirebaseFirestore.instance.collection('payout_logs').doc();

    // 1) Tambah saldo seller
    batch.update(usersRef, {
      'saldo': FieldValue.increment(amount),
    });

    // 2) Catat log pencairan
    batch.set(payoutLogRef, {
      'transactionId': transactionId,
      'sellerId': sellerId,
      'amount': amount,
      'approvedBy': 'seller_verified_auto', // atau admin uid bila ada persetujuan admin
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'released',
      'note': 'Verified seller early payout',
    });

    // 3) Tandai di transaksi bahwa telah dicairkan ke seller saat accepted
    batch.update(txnRef, {
      'releasedEarly': true,
      'releasedEarlyAt': FieldValue.serverTimestamp(),
      'releasedEarlyAmount': amount,
    });

    await batch.commit();
  }


  // ✅ REJECT ORDER FUNCTION
  Future<void> _rejectOrder(String transactionId, String reason) async {
    try {
      // Get transaction data for refund
      final transactionDoc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionId)
          .get();

      final transactionData = transactionDoc.data();
      final buyerId = transactionData?['buyerId'] as String?;
      final amount = (transactionData?['amount'] as num?)?.toDouble() ?? 0.0;

      // Update transaction status
      await FirebaseFirestore.instance.collection('transactions').doc(transactionId).update({
        'status': 'refunded',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Refund money to buyer if buyerId exists
      if (buyerId != null && amount > 0) {
        await FirebaseFirestore.instance.collection('users').doc(buyerId).update({
          'saldo': FieldValue.increment(amount),
        });
      }

      _showSuccessDialog('Pesanan berhasil ditolak dan dana dikembalikan!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ SUCCESS DIALOG
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ✅ STATUS CHIP
  Widget _buildStatusChip(String status) {
    final statusColors = {
      'pending': Colors.orange,
      'paid': Colors.blue,
      'shipped': Colors.purple,
      'delivered': Colors.green,
      'completed': Colors.teal,
      'refunded': Colors.red,
    };

    final statusLabels = {
      'pending': 'Menunggu',
      'paid': 'Dibayar',
      'shipped': 'Dikirim',
      'delivered': 'Diterima',
      'completed': 'Selesai',
      'refunded': 'Ditolak',
    };

    final color = statusColors[status.toLowerCase()] ?? Colors.grey;
    final label = statusLabels[status.toLowerCase()] ?? status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ✅ BUILD ITEMS LIST
  Widget _buildItemsList(List items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items (${items.length}):',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ...items.take(3).map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '• ${item['title'] ?? 'Unknown Item'} (${item['quantity'] ?? 1}x)',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )),
          if (items.length > 3)
            Text(
              '... dan ${items.length - 3} item lainnya',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  // ✅ FORMAT CURRENCY
  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }
}
