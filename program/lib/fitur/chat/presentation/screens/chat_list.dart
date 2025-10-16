import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/chat/presentation/providers/chat_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  Future<String> _getOtherUsername(String otherUserId, WidgetRef ref) async {
    final firestore = ref.read(firebaseFirestoreProvider);
    final userDoc = await firestore.collection('users').doc(otherUserId).get();
    return userDoc.data()?['username'] ?? 'User tidak dikenal';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatRoomsAsync = ref.watch(chatRoomsStreamProvider);
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesan'),
      ),
      body: chatRoomsAsync.when(
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return const Center(child: Text('Belum ada percakapan.'));
          }
          return ListView.builder(
            itemCount: snapshot.docs.length,
            itemBuilder: (context, index) {
              final chatRoom = snapshot.docs[index];
              final users = List<String>.from(chatRoom['users'] as List);
              final lastMessage = chatRoom['lastMessage'] as String? ?? '';

              final otherUserId = users.firstWhere((id) => id != currentUserId, orElse: () => '');

              if (otherUserId.isEmpty) return const SizedBox.shrink();

              return FutureBuilder<String>(
                future: _getOtherUsername(otherUserId, ref),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: const CircleAvatar(child: CircularProgressIndicator()),
                      title: Text('Memuat...', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                    );
                  }

                  final otherUsername = snapshot.data ?? 'User tidak dikenal';

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(otherUsername.isNotEmpty ? otherUsername[0].toUpperCase() : '?'),
                    ),
                    title: Text(otherUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      context.push('/chat/$otherUserId', extra: otherUsername);
                    },
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: ${err.toString()}")),
      ),
    );
  }
}