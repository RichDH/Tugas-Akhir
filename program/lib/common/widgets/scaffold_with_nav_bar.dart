import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Widget ini akan menjadi "cangkang" (shell) untuk halaman-halaman utama
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    Key? key,
  }) : super(key: key);

  final StatefulNavigationShell navigationShell; // Shell yang disediakan oleh GoRouter

  // Metode untuk berpindah antar branch (tab) navigasi
  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Add the login screen to the Navigator if it's not deep linked.
      // If you are using deep linking with your app, then you should set
      // this to true
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body akan menampilkan halaman dari branch navigasi yang sedang aktif
      body: navigationShell,
      // BottomNavigationBar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex, // Index tab yang aktif
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Post'), // Item untuk Create Post
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: _goBranch, // Panggil _goBranch saat tab ditekan
        type: BottomNavigationBarType.fixed, // Agar semua label terlihat
      ),
    );
  }
}