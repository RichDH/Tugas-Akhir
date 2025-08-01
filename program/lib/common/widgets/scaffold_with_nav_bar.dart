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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        // PERBAIKAN: Logika onTap disesuaikan dengan jumlah branch
        onTap: (index) {
          // Jika item yang ditekan adalah 'Post' (index 2)
          if (index == 2) {
            // Navigasi ke halaman create post secara manual
            context.push('/create-post');
          } else {
            // Untuk tab lain, gunakan goBranch.
            // Logikanya: jika index yang ditekan lebih besar dari 2 (yaitu Live atau Profile),
            // kita kurangi 1 untuk mendapatkan branchIndex yang benar.
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