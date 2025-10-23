import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:program/fitur/admin/presentation/providers/admin_provider.dart';
import 'package:program/fitur/admin/presentation/providers/admin_dashboard_metrics_provider.dart';
import 'package:program/fitur/admin/presentation/widgets/admin_drawer.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final pendingVerif = ref.watch(dashPendingVerificationsCountProvider);
    final totalUsers = ref.watch(dashTotalUsersProvider);
    final verifiedUsers = ref.watch(dashVerifiedUsersProvider);
    final closedAccounts = ref.watch(dashClosedAccountsProvider);
    final totalTransactions = ref.watch(dashTotalTransactionsProvider);
    final completedRevenue = ref.watch(dashCompletedRevenueProvider);
    final totalPosts = ref.watch(dashTotalPostsProvider);
    final liveOngoing = ref.watch(dashLiveOngoingProvider);

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildCard(context, 'Verifikasi Pending', Icons.pending_actions, pendingVerif, (v) => v.toString(), color: Colors.orange),
            _buildCard(context, 'Total Pengguna', Icons.people_alt, totalUsers, (v) => v.toString(), color: Colors.blue),
            _buildCard(context, 'Pengguna Terverifikasi', Icons.verified_user, verifiedUsers, (v) => v.toString(), color: Colors.green),
            _buildCard(context, 'Akun Ditutup', Icons.person_off, closedAccounts, (v) => v.toString(), color: Colors.red),
            _buildCard(context, 'Total Transaksi', Icons.receipt_long, totalTransactions, (v) => v.toString(), color: Colors.teal),
            _buildCard(context, 'Revenue Selesai', Icons.monetization_on, completedRevenue, (v) => currency.format(v), color: Colors.indigo),
            _buildCard(context, 'Post Aktif', Icons.post_add, totalPosts, (v) => v.toString(), color: Colors.purple),
            _buildCard(context, 'Live Aktif', Icons.live_tv, liveOngoing, (v) => v.toString(), color: Colors.pink),
          ],
        ),
      ),
    );
  }

  Widget _buildCard<T>(
      BuildContext context,
      String title,
      IconData icon,
      AsyncValue<T> asyncValue,
      String Function(T) formatter, {
        Color? color,
      }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: asyncValue.when(
          data: (v) => _DashboardCard(
            title: title,
            value: formatter(v),
            icon: icon,
            color: color,
          ),
          loading: () => _DashboardCard(
            title: title,
            value: '...',
            icon: icon,
            color: color,
          ),
          error: (e, s) => _DashboardCard(
            title: title,
            value: 'Error',
            icon: Icons.error_outline,
            color: Colors.red,
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, size: 28, color: c),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: c,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
