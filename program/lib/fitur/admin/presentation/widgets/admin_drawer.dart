import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/auth/presentation/providers/auth_provider.dart';

class AdminDrawer extends ConsumerWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.deepPurple,
            ),
            child: Text(
              'Panel Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () {
              // Navigasi ke halaman dashboard
              context.go('/admin');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Chat Pengguna'),
            onTap: () {
              context.go('/admin/chats');
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Verifikasi Pengguna'),
            onTap: () {
              // Navigasi ke halaman daftar verifikasi
              context.go('/admin/verifications');
            },
          ),
          ListTile(
            leading: const Icon(Icons.undo),
            title: const Text('Review Retur'),
            onTap: () {
              context.go('/admin/return-review');
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Manage Report'),
            onTap: () {
              context.go('/admin/reports');
            },
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