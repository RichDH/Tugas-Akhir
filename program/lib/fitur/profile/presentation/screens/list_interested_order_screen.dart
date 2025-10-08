// File: lib/fitur/profile/presentation/screens/list_interested_order_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/jualbeli/presentation/providers/transaction_provider.dart';
import 'package:intl/intl.dart';

// ✅ HIDE TRANSACTION DARI CLOUD_FIRESTORE UNTUK MENGHINDARI KONFLIK
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../../../jualbeli/domain/entities/transaction_entity.dart';

class ListInterestedOrderScreen extends ConsumerWidget {
  const ListInterestedOrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final transactionsAsync = ref.watch(transactionsBySellerStreamProvider(currentUserId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('List Pesanan'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'List Interested'),
              Tab(text: 'List Order'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildListInterested(transactionsAsync, context, ref),
            _buildListOrder(transactionsAsync, context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildListInterested(AsyncValue<List<Transaction>> transactionsAsync, BuildContext context, WidgetRef ref) {
    return transactionsAsync.when(
         data: (transactions) {
        final interestedTransactions = transactions.where((t) => t.status == TransactionStatus.pending).toList();
        if (interestedTransactions.isEmpty) return const Center(child: Text('Belum ada pesanan yang masuk.'));
        return ListView.builder(
          itemCount: interestedTransactions.length,
          itemBuilder: (context, index) {
            final transaction = interestedTransactions[index];
            return _TransactionCard(transaction: transaction, isInterested: true);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildListOrder(AsyncValue<List<Transaction>> transactionsAsync, BuildContext context, WidgetRef ref) {
    return transactionsAsync.when(
      data: (transactions) {
        final orderTransactions = transactions.where((t) => t.status == TransactionStatus.paid || t.status == TransactionStatus.shipped).toList();
        if (orderTransactions.isEmpty) return const Center(child: Text('Belum ada pesanan yang diterima.'));
        return ListView.builder(
          itemCount: orderTransactions.length,
          itemBuilder: (context, index) {
            final transaction = orderTransactions[index];
            return _TransactionCard(transaction: transaction, isInterested: false);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _TransactionCard extends ConsumerWidget {
  final Transaction transaction;
  final bool isInterested;

  const _TransactionCard({required this.transaction, required this.isInterested});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formattedPrice = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(transaction.amount);
    final buyerNameAsync = ref.watch(userNameProvider(transaction.buyerId));

    return GestureDetector( // ✅ TAMBAHKAN GESTURE DETECTOR DI SINI
      onTap: () {
        GoRouter.of(context).push('/transaction-detail/${transaction.id}');
      },
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ID: ${transaction.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(transaction.status.name, style: const TextStyle(color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 8),
              buyerNameAsync.when(
                data: (name) => Text('Pembeli: $name'),
                loading: () => const Text('Memuat...'),
                error: (err, stack) => Text('Pembeli: ${transaction.buyerId}'),
              ),
              Text('Total: $formattedPrice'),
              Text('Dibuat: ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt.toDate())}'),
              const SizedBox(height: 12),

              if (isInterested)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _acceptTransaction(ref, transaction.id, context),
                      child: const Text('Terima'),
                    ),
                    ElevatedButton(
                      onPressed: () => _rejectTransaction(ref, transaction.id, context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Tolak'),
                    ),
                  ],
                )
              else if (transaction.status == TransactionStatus.paid)
                ElevatedButton(
                  onPressed: () => _markAsShipped(ref, transaction.id, context),
                  child: const Text('Ubah Status ke Dikirim'),
                )
              else if (transaction.status == TransactionStatus.shipped)
                  const Text('Sudah dikirim', style: TextStyle(color: Colors.green)),
            ],
          ),
        ),
      ),
    );
  }

  void _acceptTransaction(WidgetRef ref, String transactionId, BuildContext context) async {
    await ref.read(transactionProvider.notifier).acceptTransaction(transactionId);

    final firestore = FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(ref.read(firebaseAuthProvider).currentUser!.uid).get();
    final isVerified = userDoc.data()?['isVerified'] == true;

    if (isVerified) {
      _showAcceptAndReleaseDialog(context, transactionId, ref);
    } else {
      _showSuccessDialog(context, 'Pesanan berhasil diterima!\nDana akan ditahan hingga barang sampai.');
    }
  }

  void _rejectTransaction(WidgetRef ref, String transactionId, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Alasan Penolakan'),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Alasan...')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(
              onPressed: () {
                ref.read(transactionProvider.notifier).rejectTransaction(transactionId, controller.text);
                Navigator.pop(context);
                _showSuccessDialog(context, 'Pesanan berhasil ditolak.');
              },
              child: const Text('Tolak'),
            ),
          ],
        );
      },
    );
  }

  void _markAsShipped(WidgetRef ref, String transactionId, BuildContext context) {
    ref.read(transactionProvider.notifier).markAsShipped(transactionId);
    _showSuccessDialog(context, 'Status pesanan diubah menjadi:\nDikirim');
  }

  void _showAcceptAndReleaseDialog(BuildContext context, String transactionId, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pesanan Diterima!'),
        content: const Text('Akun Anda sudah terverifikasi.\nIngin mencairkan dana sekarang?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nanti Saja')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(transactionProvider.notifier).releaseEscrowFunds(transactionId);
              _showSuccessDialog(context, 'Dana berhasil dicairkan ke akun Anda!');
            },
            child: const Text('Cairkan Dana'),
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