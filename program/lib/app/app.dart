import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import providers global dari app/providers
import 'package:program/app/providers/firebase_providers.dart'; // PASTIKAN PATH BENAR

// Import widget Shell dari common/widgets
import 'package:program/common/widgets/scaffold_with_nav_bar.dart'; // PASTIKAN PATH BENAR

// Import screen dari folder features/auth/presentation/screens
import 'package:program/fitur/auth/presentation/screens/login_screen.dart'; // PASTIKAN PATH BENAR
import 'package:program/fitur/auth/presentation/screens/register_screen.dart'; // PASTIKAN PATH BENAR

// Import screen dari folder features/feed/presentation/screens
import 'package:program/fitur/feed/presentation/screens/feed_screen.dart'; // PASTIKAN PATH BENAR

// Import screen dari folder features/post/presentation/screens
import 'package:program/fitur/post/presentation/screens/create_post_screen.dart'; // PASTIKAN PATH BENAR

// Import screen placeholder dari folder features/.../presentation/screens
import 'package:program/fitur/search_explore/presentation/screens/search_explore_screen.dart'; // PASTIKAN PATH BENAR
import 'package:program/fitur/live_shopping/presentation/screens/live_shopping_screen.dart'; // PASTIKAN PATH BENAR
import 'package:program/fitur/profile/presentation/screens/profile_screen.dart'; // PASTIKAN PATH BENAR


// Definisikan GoRouter sebagai Riverpod Provider
// Gunakan provider authStateChangesProvider untuk mendengarkan perubahan status otentikasi
final goRouter = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider); // Mendengarkan stream status auth

  return GoRouter(
    // initialLocation: '/login', // Tidak perlu initialLocation di sini lagi, redirect logic yang menentukannya
    routes: [
      // --- Rute Top-Level (di luar Shell) ---

      // Rute untuk halaman autentikasi
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Rute untuk halaman membuat post (biasanya full screen atau modal)
      GoRoute(
        path: '/create-post',
        builder: (context, state) => const CreatePostScreen(),
      ),

      // --- ShellRoute untuk Bottom Navigation Bar ---
      // Menggunakan indexedStack untuk menjaga state (posisi scroll, dll) antar tab
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // Menggunakan widget ScaffoldWithNavBar sebagai cangkang (shell)
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        // Definisikan cabang (branch) navigasi untuk setiap tab di Bottom Nav Bar
        branches: [
          // Branch 0: Feed (Tab pertama)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed', // Path untuk tab Feed
                builder: (context, state) => const FeedScreen(),
              ),
            ],
          ),
          // Branch 1: Explore (Tab kedua)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore', // Path untuk tab Explore
                builder: (context, state) => const SearchExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/create-post', // Path untuk tab Explore
                builder: (context, state) => const CreatePostScreen(),
              ),
            ],
          ),
          // Branch 2: Live Shopping (Tab ketiga)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/live', // Path untuk tab Live Shopping
                builder: (context, state) => const LiveShoppingScreen(),
              ),
            ],
          ),
          // Branch 3: Profile (Tab keempat)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile', // Path untuk tab Profile
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          // Catatan: Item "Post" di Bottom Nav Bar (index 2) tidak punya branch di sini.
          // Logika navigasinya ditangani langsung di widget ScaffoldWithNavBar.
        ],
      ),

      // Tambahkan errorPageBuilder jika perlu (misal: halaman 404)
      // errorPageBuilder: (context, state) => const ErrorScreen(), // Anda perlu membuat ErrorScreen
    ],

    // --- Redirect Logic ---
    // Menentukan ke mana pengguna harus diarahkan berdasarkan status autentikasi dan lokasi saat ini
    redirect: (context, state) {
      // Cek status otentikasi dari stream provider
      final isAuthenticated = authState.when(
        data: (user) => user != null, // True jika user tidak null (sudah login)
        loading: () => null, // Biarkan null/loading saat stream masih loading
        error: (err, stack) => false, // False jika terjadi error pada stream
      );

      // Cek apakah pengguna sedang di halaman autentikasi (login atau register)
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      // Cek apakah pengguna sedang di path root '/'
      final isRoot = state.matchedLocation == '/';


      String? targetPath; // Path tujuan redirect

      // Jika status masih loading, jangan lakukan redirect (tunggu stream memberikan data)
      if (isAuthenticated == null) {
        targetPath = null; // Tidak ada redirect
      }
      // Jika sudah login:
      else if (isAuthenticated) {
        // Jika pengguna mencoba mengakses halaman auth (login/register) ATAU path root '/' setelah login,
        // arahkan mereka ke halaman default shell (misal: /feed)
        if (isAuthRoute || isRoot) { // <-- Perubahan di sini: Tambahkan || isRoot
          targetPath = '/feed';
        }
        // Jika sudah login dan tidak di halaman auth atau root, biarkan saja (mereka mungkin di halaman shell atau /create-post)
        else {
          targetPath = null; // Tidak ada redirect
        }
      }
      // Jika belum login:
      else {
        // Jika pengguna mencoba mengakses halaman yang BUKAN halaman auth (misal: /feed, /explore, /create-post, atau /),
        // arahkan mereka ke halaman login
        if (!isAuthRoute) { // <-- Logika ini sudah menangani '/' karena '/' bukan isAuthRoute
          targetPath = '/login';
        }
        // Jika belum login dan sudah di halaman auth, biarkan saja di halaman auth
        else {
          targetPath = null; // Tidak ada redirect
        }
      }

      // Tambahkan print statement untuk debugging
      if (targetPath != null) {
        print('GoRouter Redirect: ${state.matchedLocation} -> $targetPath');
      } else {
        print('GoRouter Redirect: ${state.matchedLocation} -> No redirect');
      }

      return targetPath; // Kembalikan path tujuan redirect
    },
  );
});


// Widget root aplikasi yang menggunakan Riverpod dan GoRouter
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dapatkan instance GoRouter dari provider
    final router = ref.watch(goRouter);

    return MaterialApp.router(
      title: 'Aplikasi Jasa Titip', // Ganti dengan nama aplikasi Anda
      theme: ThemeData(
        primarySwatch: Colors.blue, // Ganti tema dasar sesuai keinginan
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Tambahkan konfigurasi tema lain di sini jika perlu
      ),
      routerConfig: router, // Gunakan router dari GoRouter
      debugShowCheckedModeBanner: false, // Optional: Sembunyikan banner debug
    );
  }
}
