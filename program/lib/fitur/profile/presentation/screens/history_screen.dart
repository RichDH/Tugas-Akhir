import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../jualbeli/presentation/screens/request_history_screen.dart';
import '../../../jualbeli/presentation/screens/transaction_history_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Transaksi'),
              Tab(text: 'Request'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TransactionHistoryScreen(),
            RequestHistoryScreen(),
          ],
        ),
      ),
    );
  }
}