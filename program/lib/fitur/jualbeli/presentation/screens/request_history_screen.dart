// File: lib/fitur/profile/presentation/screens/request_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/post/presentation/providers/post_provider.dart';

class RequestHistoryScreen extends ConsumerWidget {
  const RequestHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final postsAsync = ref.watch(postListStreamProvider); // Sudah didefinisikan di post_provider.dart

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Request')),
      body: postsAsync.when(
        data: (posts) {
          final requests = posts.where((post) => post.type == 'request' && post.userId == currentUserId).toList();

          if (requests.isEmpty) {
            return const Center(child: Text('Belum ada request jastip.'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final post = requests[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(post.title ?? 'Request Jastip'),
                  subtitle: Text('Dibuat: ${post.createdAt.toDate().toString()}'),
                  trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[600]),
                  onTap: () {
                    GoRouter.of(context).push('/post-detail/${post.id}');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}