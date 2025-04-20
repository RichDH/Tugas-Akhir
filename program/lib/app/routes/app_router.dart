import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/presentation/screens/login_screen.dart'; // Import layar login (akan dibuat)
import '../../features/auth/presentation/screens/register_screen.dart';// Import layar register (akan dibuat)
// Import layar lain nanti (misal: HomeScreen, SplashScreen)

// Contoh sederhana GoRouter
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login', // Rute awal (atau splash screen)
    debugLogDiagnostics: true, // Aktifkan log untuk debugging routing
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen(); // Arahkan ke LoginScreen (akan dibuat)
        },
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) {
          return const RegisterScreen(); // Arahkan ke RegisterScreen (akan dibuat)
        },
      ),
      // Tambahkan route lain nanti, misal: '/home' atau '/' untuk splash
      // GoRoute(
      //   path: '/home',
      //   builder: (BuildContext context, GoRouterState state) {
      //     return const HomeScreen(); // Layar utama setelah login
      //   },
      // ),
    ],
    // Opsional: Error handling jika route tidak ditemukan
    // errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
}