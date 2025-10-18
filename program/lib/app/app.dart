import 'package:cloud_firestore/cloud_firestore.dart';
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

import 'package:program/fitur/chat/presentation/screens/chat_list.dart';
import 'package:program/fitur/chat/presentation/screens/chat_screen.dart';
import 'package:program/fitur/chat/presentation/screens/group_chat_screen.dart';

import 'package:program/fitur/post/presentation/screens/post_detail_screen.dart';
import 'package:program/fitur/transaction/presentation/screens/topup_screen.dart';
import 'package:program/fitur/transaction/presentation/screens/webview_screen.dart';
import 'package:program/fitur/transaction/presentation/screens/top_up_success_screen.dart';
import 'package:program/fitur/verification/presentation/screens/verification_screen.dart';

import 'package:program/fitur/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:program/fitur/admin/presentation/screens/verification/admin_verification_list_screen.dart';
import 'package:program/fitur/admin/presentation/screens/verification/admin_verification_detail_screen.dart';
import 'package:program/fitur/auth/presentation/providers/auth_provider.dart';

import '../fitur/admin/presentation/screens/chat/admin_chat_list_screen.dart';
import '../fitur/admin/presentation/screens/chat/admin_chat_screen.dart';
import '../fitur/admin/presentation/screens/return_finalize_screen.dart';
import '../fitur/admin/presentation/screens/return_review_screen.dart';
import '../fitur/cart/presentation/screens/cart_screen.dart';
import '../fitur/chat/presentation/screens/chat_admin_screen.dart';
import '../fitur/jualbeli/presentation/screens/create_return_request_screen.dart';
import '../fitur/jualbeli/presentation/screens/request_history_screen.dart';
import '../fitur/jualbeli/presentation/screens/return_confirmation_screen.dart';
import '../fitur/jualbeli/presentation/screens/transaction_detail_screen.dart';
import '../fitur/jualbeli/presentation/screens/transaction_history_screen.dart';
import '../fitur/notification/presentation/screens/notification_screen.dart';
import '../fitur/profile/presentation/screens/edit_profile_screen.dart';
import '../fitur/profile/presentation/screens/history_screen.dart';
import '../fitur/profile/presentation/screens/list_interested_order_screen.dart';
import '../fitur/profile/presentation/screens/return_response_list_screen.dart';
import '../fitur/profile/presentation/screens/return_response_screen.dart';


final goRouter = Provider<GoRouter>((ref) {
  final isAdmin = ref.watch(isAdminProvider);
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
      // Tambahkan route ini jika belum ada
      GoRoute(
        path: '/post-detail/:postId',
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
          final extra = state.extra;

          String otherUsername = 'Pengguna';
          if (extra is String) {
            otherUsername = extra;
          } else if (extra is Map) {
            final map = Map<String, dynamic>.from(extra as Map);
            otherUsername = (map['username'] ?? map['name'] ?? 'Pengguna').toString();
          }

          return ChatScreen(
            otherUserId: userId,
            otherUsername: otherUsername,
          );
        },
      ),
      // Di router configuration (app_router.dart atau main.dart)
      // Di router configuration
      GoRoute(
        path: '/group-chat/:chatId',
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final groupName = extra['groupName']?.toString() ?? 'Group';

          return GroupChatScreen(
            chatId: chatId,
            groupName: groupName,
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/chat-admin',
        builder: (context, state) => const ChatAdminScreen(), // Buat di langkah 3
      ),


      GoRoute(
        path: '/user/:userId', // Rute baru dengan parameter
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(path: '/top-up', builder: (context, state) => const TopUpScreen()),
      GoRoute(
        path: '/webview',
        builder: (context, state) {
          final url = state.extra as String? ?? 'https://xendit.co';
          return WebViewScreen(url: url);
        },
      ),
      GoRoute(
        path: '/top-up-success',
        builder: (context, state) => const TopUpSuccessScreen(),
      ),
      GoRoute(
        path: '/verification',
        builder: (context, state) => const VerificationScreen(),
      ),
      GoRoute(
        path: '/admin/verification-detail',
        builder: (context, state) {
          // Ambil DocumentSnapshot dari extra yang dikirim
          final userDoc = state.extra as DocumentSnapshot;
          return AdminVerificationDetailScreen(userDoc: userDoc);
        },
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/transaction-detail/:id',
        builder: (context, state) {
          final transactionId = state.pathParameters['id']!;
          return TransactionDetailScreen(transactionId: transactionId);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/transaction-history',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/request-history',
        builder: (context, state) => const RequestHistoryScreen(),
      ),
      GoRoute(
        path: '/admin/return-review',
        builder: (context, state) => const ReturnReviewScreen(),
      ),
      GoRoute(path: '/list-interested-order', builder: (context, state) => const ListInterestedOrderScreen()),


      GoRoute(path: '/admin/return-finalize', builder: (context, state) => const ReturnFinalizeScreen()),
      GoRoute(path: '/admin/return-review', builder: (context, state) => const ReturnReviewScreen()),
      GoRoute(
        path: '/admin/chats',
        builder: (context, state) => const AdminChatListScreen(), // Buat langkah 6
      ),
      GoRoute(
        path: '/admin/chats/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final otherName = extra['name']?.toString() ?? 'Pengguna';
          return AdminChatScreen(roomId: roomId, otherName: otherName);
        },
      ),



      GoRoute(path: '/return-response-list', builder: (context, state) => const ReturnResponseListScreen()),
      GoRoute(path: '/return-response/:requestId', builder: (context, state) => ReturnResponseScreen(requestId: state.pathParameters['requestId']!)),
      GoRoute(path: '/return-confirmation/:transactionId', builder: (context, state) => ReturnConfirmationScreen(transactionId: state.pathParameters['transactionId']!)),
      GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
      GoRoute(path: '/transaction-history', builder: (context, state) => const TransactionHistoryScreen()),
      GoRoute(path: '/request-history', builder: (context, state) => const RequestHistoryScreen()),

      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/create-return-request/:transactionId',
        builder: (context, state) {
          final transactionId = state.pathParameters['transactionId']!;
          return CreateReturnRequestScreen(transactionId: transactionId);
        },
      ),



      // --- ShellRoute untuk Bottom Navigation Bar ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
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

          StatefulShellBranch(
            routes: [
              // Rute utama untuk admin adalah Dashboard
              GoRoute(
                path: '/admin',
                builder: (context, state) => const AdminDashboardScreen(),
                routes: [
                  // Sub-rute untuk halaman lain di dalam panel admin
                  GoRoute(
                    path: 'verifications', // akan menjadi /admin/verifications
                    builder: (context, state) => const AdminVerificationListScreen(),
                  ),
                ],
              ),
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

      if (isAuthenticated && isAdmin) {
        final isAdminRoute = state.matchedLocation.startsWith('/admin');
        if (!isAdminRoute) {
          return '/admin';
        }
        return null;
      }


      if (isAuthenticated && !isAdmin) {
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