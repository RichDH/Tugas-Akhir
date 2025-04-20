import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Import GoRouter jika digunakan
import 'routes/app_router.dart'; // Import konfigurasi router Anda (akan dibuat)
import 'theme/theme_data.dart'; // Import tema Anda (akan dibuat)
import 'constants/app_constants.dart'; // Import konstanta (opsional)

// Gunakan ConsumerWidget jika perlu akses Riverpod di level ini
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dapatkan konfigurasi GoRouter dari provider atau langsung
    final GoRouter router = AppRouter.router; // Contoh ambil dari class AppRouter

    return MaterialApp.router(
      title: AppConstants.appName, // Ganti dengan nama aplikasi Anda
      debugShowCheckedModeBanner: false, // Matikan banner debug
      theme: AppTheme.lightTheme, // Terapkan tema terang (akan dibuat)
      // darkTheme: AppTheme.darkTheme, // Opsional: tema gelap
      // themeMode: ThemeMode.system, // Opsional: sesuaikan dengan sistem
      routerConfig: router, // Gunakan konfigurasi GoRouter
    );

    /* // Alternatif jika tidak pakai GoRouter di awal:
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: DecideInitialScreen(), // Widget yang menentukan layar awal (misal: Cek Auth)
    );
    */
  }
}