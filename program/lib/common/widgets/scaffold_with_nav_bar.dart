import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    Key? key,
  }) : super(key: key);

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    // PERBAIKAN: Logika baru untuk menentukan item mana yang harus di-highlight
    final int bottomNavIndex;
    // `navigationShell.currentIndex` adalah index dari branch (0, 1, 2, 3)
    // Jika branch index adalah 2 (Live) atau 3 (Profile), kita tambahkan 1
    // untuk mendapatkan index BottomNavBar yang benar (3 atau 4), karena kita "melewati" item 'Post'.
    if (navigationShell.currentIndex >= 2) {
      bottomNavIndex = navigationShell.currentIndex + 1;
    } else {
      bottomNavIndex = navigationShell.currentIndex;
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        // Menggunakan index yang sudah diperbaiki
        currentIndex: bottomNavIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        // Logika onTap Anda sudah benar dan tidak perlu diubah
        onTap: (index) {
          if (index == 2) {
            context.push('/create-post');
          } else {
            int branchIndex = index > 2 ? index - 1 : index;
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