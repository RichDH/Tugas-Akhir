// File: program/lib/fitur/admin/presentation/screens/admin_chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:go_router/go_router.dart';

Stream<bool> _unreadStream(WidgetRef ref, String roomId, String adminId) {
  final fs = ref.read(firebaseFirestoreProvider);
  return fs.collection('users').doc(adminId)
      .collection('chat_read_status').doc(roomId)
      .snapshots().asyncMap((d) async {
    try {
      final data = d.data();
      if (data == null) return true;

      final last = data['lastRead'] as Timestamp?;
      if (last == null) return true;

      final q = await fs.collection('chats').doc(roomId)
          .collection('messages')
          .where('timestamp', isGreaterThan: last)
          .where('senderId', isNotEqualTo: adminId)
          .limit(1).get();

      return q.docs.isNotEmpty;
    } catch (e) {
      print('Error checking unread: $e');
      return false;
    }
  });
}

class AdminChatListScreen extends ConsumerWidget {
  const AdminChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firebaseFirestoreProvider);
    final adminId = FirebaseAuth.instance.currentUser?.uid;

    if (adminId == null) {
      return const Scaffold(
        body: Center(child: Text('Admin belum login')),
      );
    }

    final roomsStream = fs.collection('chats')
        .where('type', isEqualTo: 'direct')
        .where('isAdminChat', isEqualTo: true)
        .where('users', arrayContains: adminId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Pengguna'),
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/admin/');
            }
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: roomsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada chat dengan pengguna'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final room = snapshot.data!.docs[index];
              final data = room.data();

              if (data is! Map<String, dynamic>) {
                return const SizedBox.shrink();
              }

              final users = List<String>.from(data['users'] ?? []);
              final otherId = users.firstWhere((u) => u != adminId, orElse: () => '');
              final lastMessage = data['lastMessage']?.toString() ?? '';

              if (otherId.isEmpty) return const SizedBox.shrink();

              return FutureBuilder<DocumentSnapshot>(
                future: fs.collection('users').doc(otherId).get(),
                builder: (context, userSnap) {
                  String otherName = 'Pengguna';

                  if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
                    final userData = userSnap.data!.data();
                    if (userData is Map<String, dynamic>) {
                      otherName = userData['username']?.toString() ?? 'Pengguna';
                    }
                  }

                  return StreamBuilder<bool>(
                    stream: _unreadStream(ref, room.id, adminId),
                    builder: (context, unreadSnap) {
                      final hasUnread = unreadSnap.data ?? false;

                      return ListTile(
                        leading: Stack(
                          children: [
                            const CircleAvatar(child: Icon(Icons.person)),
                            if (hasUnread)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          otherName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          // Mark as read
                          FirebaseFirestore.instance
                              .collection('users').doc(adminId)
                              .collection('chat_read_status').doc(room.id)
                              .set({'lastRead': FieldValue.serverTimestamp()},
                              SetOptions(merge: true));

                          context.push('/admin/chats/${room.id}', extra: {'name': otherName});
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
