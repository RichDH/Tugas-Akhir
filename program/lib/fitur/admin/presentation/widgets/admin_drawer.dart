import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/auth/presentation/providers/auth_provider.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:intl/intl.dart';

class AdminDrawer extends ConsumerWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(adminBalanceStreamProvider);
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.deepPurple),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Panel Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                balanceAsync.when(
                  data: (saldo) => Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saldo: ${formatter.format(saldo)}',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Text('Memuat saldo...', style: TextStyle(color: Colors.white70)),
                  error: (e, s) => const Text('Saldo tidak tersedia', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () => context.go('/admin'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Chat Pengguna'),
            onTap: () => context.go('/admin/chats'),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Verifikasi Pengguna'),
            onTap: () => context.go('/admin/verifications'),
          ),
          ListTile(
            leading: const Icon(Icons.undo),
            title: const Text('Review Retur'),
            onTap: () => context.go('/admin/return-review'),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Manage Report'),
            onTap: () => context.go('/admin/reports'),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search User'),
            onTap: () => context.go('/admin/search-users'),
          ),
          ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text('Buat Pengumuman'),
            onTap: () => context.push('/admin/create-announcement'),
          ),
          ListTile(
            leading: const Icon(Icons.local_offer),
            title: const Text('Kelola Promo'),
            onTap: () => context.push('/admin/promos'),
          ),
          ListTile(
            leading: const Icon(Icons.ad_units),
            title: const Text('Kelola Paket Ads'),
            onTap: () => context.push('/admin/ads-packages'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Lihat Transaksi'),
            onTap: () => context.push('/admin/transactions'),
          ),
          ListTile(
            leading: const Icon(Icons.assessment),
            title: const Text('Laporan'),
            onTap: () => context.push('/admin/laporan'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}