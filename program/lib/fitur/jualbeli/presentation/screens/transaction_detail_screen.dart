// File: transaction_detail_screen.dart - PERBAIKAN STATUS COMPLETED
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  ConsumerState<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .doc(widget.transactionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Transaksi tidak ditemukan'),
            );
          }

          final transactionData = snapshot.data!.data() as Map<String, dynamic>;
          return _buildTransactionDetails(transactionData);
        },
      ),
    );
  }

  Widget _buildTransactionDetails(Map<String, dynamic> transaction) {
    return FutureBuilder<Map<String, String>>(
      future: _fetchUsernames(
        transaction['buyerId'] as String? ?? '',
        transaction['sellerId'] as String? ?? '',
      ),
      builder: (context, snapshot) {
        final usernames = snapshot.data ?? {};
        final buyerUsername = usernames['buyer'] ?? (transaction['buyerId'] as String? ?? 'Unknown');
        final sellerUsername = usernames['seller'] ?? (transaction['sellerId'] as String? ?? 'Unknown');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Transaction Info Card
            _buildInfoCard('Informasi Transaksi', [
              _buildInfoRow('ID Transaksi', widget.transactionId),
              _buildInfoRow('Status', _buildStatusChip(transaction['status'] as String? ?? 'unknown')),
              _buildInfoRow('Tanggal', _formatTimestamp(transaction['createdAt'])),
            ]),

            const SizedBox(height: 16),

            // Participants Info Card
            _buildInfoCard('Informasi Peserta', [
              _buildInfoRow('Pembeli', buyerUsername),
              _buildInfoRow('Penjual/Jastiper', sellerUsername),
              // ✅ TAMBAHAN: ALAMAT PEMBELI
              if (transaction['buyerAddress'] != null && (transaction['buyerAddress'] as String).isNotEmpty)
                _buildInfoRow('Alamat Pengiriman', transaction['buyerAddress'] as String),
            ]),

            const SizedBox(height: 16),

            // Financial Info Card
            _buildInfoCard('Informasi Keuangan', [
              _buildInfoRow('Total Pembayaran', _formatCurrency(transaction['amount'])),
              _buildInfoRow('Status Escrow', transaction['isEscrow'] == true ? 'Aktif' : 'Tidak Aktif'),
              if (transaction['escrowAmount'] != null)
                _buildInfoRow('Dana Escrow', _formatCurrency(transaction['escrowAmount'])),
              // ✅ TAMBAHAN: RATING JIKA ADA
              if (transaction['rating'] != null)
                _buildInfoRow('Rating', '${transaction['rating']}/5 ⭐'),
            ]),

            const SizedBox(height: 16),

            // Items Info Card
            _buildItemsCard(transaction),

            const SizedBox(height: 16),

            // Timeline Card
            _buildTimelineCard(transaction),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: value is Widget
                ? value
                : Text(
              value?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ PERBAIKAN STATUS CHIP DENGAN COMPLETED
  Widget _buildStatusChip(String status) {
    final statusColors = {
      'pending': Colors.orange,
      'paid': Colors.blue,
      'shipped': Colors.purple,
      'delivered': Colors.green,
      'completed': Colors.teal, // ✅ TAMBAHAN
      'refunded': Colors.red,
    };

    final statusLabels = {
      'pending': 'Menunggu',
      'paid': 'Dibayar',
      'shipped': 'Dikirim',
      'delivered': 'Diterima',
      'completed': 'Selesai', // ✅ TAMBAHAN
      'refunded': 'Dibatalkan',
    };

    final color = statusColors[status.toLowerCase()] ?? Colors.grey;
    final label = statusLabels[status.toLowerCase()] ?? status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildItemsCard(Map<String, dynamic> transaction) {
    final items = transaction['items'] as List<dynamic>? ?? [];

    if (items.isEmpty) {
      // Fallback for single item transaction
      return _buildInfoCard('Item Transaksi', [
        _buildSingleItemWidget(transaction),
      ]);
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Item yang Dibeli',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => _buildItemWidget(item as Map<String, dynamic>)),
            const Divider(),
            _buildInfoRow('Total Item', '${items.length} item'),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleItemWidget(Map<String, dynamic> transaction) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Image placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['title'] as String? ?? 'Item',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${transaction['quantity'] ?? 1}',
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  _formatCurrency(transaction['price'] ?? transaction['amount']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemWidget(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Item image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item['imageUrl'] != null && (item['imageUrl'] as String).isNotEmpty
                ? Image.network(
              item['imageUrl'] as String,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported),
                  ),
            )
                : Container(
              width: 60,
              height: 60,
              color: Colors.grey[200],
              child: const Icon(Icons.shopping_bag),
            ),
          ),
          const SizedBox(width: 12),
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String? ?? 'Unknown Item',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item['quantity'] ?? 1}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(item['price'] ?? 0),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text(
                'Total: ${_formatCurrency((item['price'] ?? 0) * (item['quantity'] ?? 1))}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ PERBAIKAN TIMELINE DENGAN COMPLETED
  Widget _buildTimelineCard(Map<String, dynamic> transaction) {
    return _buildInfoCard('Timeline', [
      _buildTimelineItem('Dibuat', transaction['createdAt'], Icons.add_shopping_cart),
      if (transaction['paidAt'] != null || transaction['status'] != 'pending')
        _buildTimelineItem('Dibayar', transaction['paidAt'] ?? transaction['createdAt'], Icons.payment),
      if (transaction['shippedAt'] != null)
        _buildTimelineItem('Dikirim', transaction['shippedAt'], Icons.local_shipping),
      if (transaction['deliveredAt'] != null)
        _buildTimelineItem('Diterima', transaction['deliveredAt'], Icons.done_all),
      if (transaction['completedAt'] != null) // ✅ TAMBAHAN
        _buildTimelineItem('Selesai', transaction['completedAt'], Icons.star),
      if (transaction['releaseToSellerAt'] != null)
        _buildTimelineItem('Dana Dicairkan', transaction['releaseToSellerAt'], Icons.attach_money),
    ]);
  }

  Widget _buildTimelineItem(String label, dynamic timestamp, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            _formatTimestamp(timestamp),
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ✅ FETCH USERNAMES FROM USER IDS
  Future<Map<String, String>> _fetchUsernames(String buyerId, String sellerId) async {
    try {
      if (buyerId.isEmpty && sellerId.isEmpty) {
        return {};
      }

      final futures = <Future<DocumentSnapshot>>[];

      if (buyerId.isNotEmpty) {
        futures.add(FirebaseFirestore.instance.collection('users').doc(buyerId).get());
      }

      if (sellerId.isNotEmpty) {
        futures.add(FirebaseFirestore.instance.collection('users').doc(sellerId).get());
      }

      final results = await Future.wait(futures);
      final usernames = <String, String>{};

      if (buyerId.isNotEmpty && results.isNotEmpty) {
        final buyerData = results[0].data() as Map<String, dynamic>?;
        usernames['buyer'] = buyerData?['username'] as String? ?? buyerId;
      }

      if (sellerId.isNotEmpty) {
        final sellerIndex = buyerId.isNotEmpty ? 1 : 0;
        if (results.length > sellerIndex) {
          final sellerData = results[sellerIndex].data() as Map<String, dynamic>?;
          usernames['seller'] = sellerData?['username'] as String? ?? sellerId;
        }
      }

      return usernames;
    } catch (e) {
      print('Error fetching usernames: $e');
      return {};
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';

    double value = 0.0;
    if (amount is double) {
      value = amount;
    } else if (amount is int) {
      value = amount.toDouble();
    } else if (amount is String) {
      value = double.tryParse(amount) ?? 0.0;
    }

    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '-';

    try {
      DateTime dateTime;

      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return '-';
      }

      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return '-';
    }
  }
}
