import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // PERBAIKAN: Import Riverpod
import 'package:go_router/go_router.dart';
import 'package:program/fitur/auth/presentation/providers/auth_provider.dart'; // PERBAIKAN: Import isAdminProvider

class ScaffoldWithNavBar extends ConsumerWidget { // PERBAIKAN: Ubah menjadi ConsumerWidget
  const ScaffoldWithNavBar({
    required this.navigationShell,
    Key? key,
  }) : super(key: key);

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) { // PERBAIKAN: Tambahkan WidgetRef ref
    // PERBAIKAN: Cek apakah pengguna adalah admin
    final bool isAdmin = ref.watch(isAdminProvider);

    // Logika currentIndex Anda sudah benar dan tidak perlu diubah
    final int bottomNavIndex;
    if (navigationShell.currentIndex >= 2) {
      bottomNavIndex = navigationShell.currentIndex + 1;
    } else {
      bottomNavIndex = navigationShell.currentIndex;
    }

    // PERBAIKAN: Buat daftar item navigasi secara dinamis
    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
      const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
      const BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Post'),
      const BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live'),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ];

    // Jika pengguna adalah admin, tambahkan item Admin di akhir
    if (isAdmin) {
      items.add(
        const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: bottomNavIndex,
        items: items, // Gunakan daftar item yang dinamis
        onTap: (index) {
          // Logika onTap Anda sudah benar untuk menangani tombol Post dan navigasi branch
          // bahkan setelah menambahkan item Admin. Tidak perlu diubah.
          if (index == 2) { // Tombol Post
            context.push('/create-post');
          } else {
            int branchIndex = index > 2 ? index - 1 : index;
            // Jika admin dan menekan tab admin (index 5), branchIndex akan menjadi 4,
            // yang sudah sesuai dengan branch admin yang kita buat di GoRouter.
            navigationShell.goBranch(
              branchIndex,
              initialLocation: branchIndex == navigationShell.currentIndex,
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}