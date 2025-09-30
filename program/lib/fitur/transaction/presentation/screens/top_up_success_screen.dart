import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TopUpSuccessScreen extends StatefulWidget {
  const TopUpSuccessScreen({super.key});

  @override
  State<TopUpSuccessScreen> createState() => _TopUpSuccessScreenState();
}

class _TopUpSuccessScreenState extends State<TopUpSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Setelah 3 detik, kembali ke halaman profil
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // Menggunakan go() untuk kembali ke root tab profil
        context.go('/profile');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false, // Mencegah pengguna menekan tombol back manual
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 100),
              SizedBox(height: 24),
              Text(
                "Top Up Berhasil!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Saldo Anda akan segera diperbarui.",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}