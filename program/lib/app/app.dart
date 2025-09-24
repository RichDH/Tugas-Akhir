import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import providers
import 'package:program/app/providers/firebase_providers.dart';

// Import screens
import 'package:program/common/widgets/scaffold_with_nav_bar.dart';
import 'package:program/fitur/auth/presentation/screens/login_screen.dart';
import 'package:program/fitur/auth/presentation/screens/register_screen.dart';
import 'package:program/fitur/feed/presentation/screens/feed_screen.dart';
import 'package:program/fitur/post/presentation/screens/create_post_screen.dart';
import 'package:program/fitur/search_explore/presentation/screens/search_explore_screen.dart';
import 'package:program/fitur/profile/presentation/screens/profile_screen.dart';
import 'package:program/fitur/live_shopping/presentation/screens/setup_live_screen.dart';
import 'package:program/fitur/live_shopping/presentation/screens/jastiper_live_screen.dart';
import 'package:program/fitur/live_shopping/presentation/screens/viewer_live_screen.dart';
import 'package:program/fitur/chat/presentation/screens/chat_screens.dart';
import 'package:program/fitur/chat/presentation/screens/chat_individu.dart';
import 'package:program/fitur/post/presentation/screens/post_detail_screen.dart';


final goRouter = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    routes: [
      // --- Rute Top-Level (di luar Shell) ---
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/create-post', builder: (context, state) => const CreatePostScreen()),
      GoRoute(path: '/jastiper-live', builder: (context, state) => const JastiperLiveScreen()),
      GoRoute(path: '/viewer-live', builder: (context, state) => const ViewerLiveScreen(),
      ),
      GoRoute(
        path: '/post/:postId', // :postId adalah parameter ID post
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          return PostDetailScreen(postId: postId);
        },
      ),

      GoRoute(
        path: '/chat-list',
        builder: (context, state) => const ChatListScreen(),
      ),
      // Di file router Anda
      GoRoute(
        path: '/chat/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final username = state.extra as String;

          // Panggil constructor yang sudah diperbaiki
          return ChatScreen(
            otherUserId: userId,
            otherUsername: username,
          );
        },
      ),
      GoRoute(
        path: '/user/:userId', // Rute baru dengan parameter
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return ProfileScreen(userId: userId);
        },
      ),

      // --- ShellRoute untuk Bottom Navigation Bar ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        // PERBAIKAN: Hanya ada 4 branch, sesuai jumlah tab yang punya halaman sendiri.
        // Tombol 'Post' (index 2) tidak punya branch di sini.
        branches: [
          // Branch 0: Untuk Tab 'Feed' (index 0)
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
            ],
          ),
          // Branch 1: Untuk Tab 'Explore' (index 1)
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/explore', builder: (context, state) => const SearchExploreScreen()),
            ],
          ),
          // Branch 2: Untuk Tab 'Live' (index 3)
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/live', builder: (context, state) => const SetupLiveScreen()),
            ],
          ),
          // Branch 3: Untuk Tab 'Profile' (index 4)
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
            ],
          ),
        ],
      ),
    ],

    // --- Redirect Logic ---
    redirect: (context, state) {
      final isAuthenticated = authState.when(data: (user) => user != null, loading: () => null, error: (err, stack) => false);
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final isRoot = state.matchedLocation == '/';
      if (isAuthenticated == null) return null;
      if (isAuthenticated) {
        if (isAuthRoute || isRoot) return '/feed';
      } else {
        if (!isAuthRoute) return '/login';
      }
      return null;
    },
  );
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouter);
    return MaterialApp.router(
      title: 'Aplikasi Jasa Titip',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}