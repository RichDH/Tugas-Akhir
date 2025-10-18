// chat_list.dart - PERBAIKAN LENGKAP REAL-TIME UNREAD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/chat/presentation/providers/chat_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ HELPER FUNCTION - GANTI KE STREAM REAL-TIME
Stream<bool> _hasUnreadMessagesStream(WidgetRef ref, String chatRoomId, String currentUserId) {
  final firestore = ref.read(firebaseFirestoreProvider);

  // Stream dari chat_read_status untuk real-time updates
  return firestore
      .collection('users')
      .doc(currentUserId)
      .collection('chat_read_status')
      .doc(chatRoomId)
      .snapshots()
      .asyncMap((lastReadDoc) async {
    try {
      final lastReadTs = lastReadDoc.data()?['lastRead'] as Timestamp?;

      if (lastReadTs == null) return true; // Belum pernah baca

      // Cek ada messages baru setelah lastRead
      final q = await firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .where('timestamp', isGreaterThan: lastReadTs)
          .where('senderId', isNotEqualTo: currentUserId)
          .limit(1)
          .get();

      return q.docs.isNotEmpty;
    } catch (e) {
      print('Error checking unread: $e');
      return false;
    }
  }).handleError((e) {
    print('Stream error: $e');
    return false;
  });
}

// HELPER FUNCTION - SAMA SEPERTI SEBELUMNYA
Future<void> _markChatAsRead(WidgetRef ref, String chatRoomId, String currentUserId) async {
  try {
    final firestore = ref.read(firebaseFirestoreProvider);
    await firestore
        .collection('users')
        .doc(currentUserId)
        .collection('chat_read_status')
        .doc(chatRoomId)
        .set({'lastRead': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  } catch (e) {
    print('Error marking as read: $e');
  }
}

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
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Buat Group',
            onPressed: () => _showCreateGroupDialog(context, ref),
          ),
        ],
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
              final data = chatRoom.data() as Map<String, dynamic>;

              final isGroup = data['type'] == 'group';
              final lastMessage = data['lastMessage'] as String? ?? '';

              if (isGroup) {
                // ✅ GROUP CHAT dengan StreamBuilder
                final groupName = data['name']?.toString() ?? 'Group';
                final members = List<String>.from(data['users'] ?? []);

                return StreamBuilder<bool>(
                  stream: _hasUnreadMessagesStream(ref, chatRoom.id, currentUserId!),
                  builder: (context, unreadSnap) {
                    final hasUnread = unreadSnap.data ?? false;

                    return ListTile(
                      leading: Stack(
                        children: [
                          const CircleAvatar(child: Icon(Icons.group)),
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
                      title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('${members.length} anggota',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      onTap: () {
                        _markChatAsRead(ref, chatRoom.id, currentUserId!);
                        context.push('/group-chat/${chatRoom.id}', extra: {
                          'groupName': groupName,
                          'isGroup': true,
                        });
                      },
                    );
                  },
                );
              } else {
                // ✅ 1-ON-1 CHAT dengan StreamBuilder
                final users = List<String>.from(data['users'] as List? ?? []);
                final otherUserId = users.firstWhere((id) => id != currentUserId, orElse: () => '');

                if (otherUserId.isEmpty) return const SizedBox.shrink();

                return FutureBuilder<String>(
                  future: _getOtherUsername(otherUserId, ref),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        leading: const CircleAvatar(child: CircularProgressIndicator()),
                        title: const Text('Memuat...', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }

                    final otherUsername = snapshot.data ?? 'User tidak dikenal';

                    // ✅ NESTED StreamBuilder untuk unread status
                    return StreamBuilder<bool>(
                      stream: _hasUnreadMessagesStream(ref, chatRoom.id, currentUserId!),
                      builder: (context, unreadSnap) {
                        final hasUnread = unreadSnap.data ?? false;

                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                child: Text(otherUsername.isNotEmpty ? otherUsername[0].toUpperCase() : '?'),
                              ),
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
                          title: Text(otherUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            _markChatAsRead(ref, chatRoom.id, currentUserId!);
                            context.push('/chat/$otherUserId', extra: otherUsername);
                          },
                        );
                      },
                    );
                  },
                );
              }
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: ${err.toString()}")),
      ),
    );
  }

  // ✅ DIALOG CREATE GROUP - TIDAK BERUBAH, TETAP SAMA
  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController nameController = TextEditingController();
    final firestore = ref.read(firebaseFirestoreProvider);
    final currentUser = ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harus login untuk membuat grup')),
      );
      return;
    }

    final followersStream = firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('followers')
        .snapshots();

    final Set<String> selectedMemberIds = <String>{};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Buat Group Chat'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Group',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pilih Anggota (followers)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 260,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: followersStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snap.hasData || snap.data!.docs.isEmpty) {
                            return const Center(child: Text('Belum ada followers'));
                          }

                          final followerIds = snap.data!.docs.map((d) => d.id).toList();
                          final idsToQuery = followerIds.take(10).toList();

                          if (idsToQuery.isEmpty) {
                            return const Center(child: Text('Belum ada followers'));
                          }

                          return FutureBuilder<QuerySnapshot>(
                            future: firestore
                                .collection('users')
                                .where(FieldPath.documentId, whereIn: idsToQuery)
                                .get(),
                            builder: (context, usersSnap) {
                              if (usersSnap.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final userDocs = usersSnap.data?.docs ?? [];
                              return ListView.builder(
                                itemCount: userDocs.length,
                                itemBuilder: (context, index) {
                                  final user = userDocs[index];
                                  final uid = user.id;
                                  final data = user.data() as Map<String, dynamic>;
                                  final username = data['username']?.toString() ?? 'User';

                                  final checked = selectedMemberIds.contains(uid);

                                  return CheckboxListTile(
                                    value: checked,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          selectedMemberIds.add(uid);
                                        } else {
                                          selectedMemberIds.remove(uid);
                                        }
                                      });
                                    },
                                    title: Text(username),
                                    controlAffinity: ListTileControlAffinity.trailing,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama group wajib diisi')),
                      );
                      return;
                    }
                    if (selectedMemberIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pilih minimal 1 anggota')),
                      );
                      return;
                    }

                    try {
                      final members = <String>{...selectedMemberIds, currentUser.uid}.toList();
                      final admins = <String>[currentUser.uid];

                      final chatDoc = await firestore.collection('chats').add({
                        'type': 'group',
                        'name': name,
                        'users': members,
                        'admins': admins,
                        'createdAt': FieldValue.serverTimestamp(),
                        'lastMessage': '',
                        'lastMessageTimestamp': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        context.push('/group-chat/${chatDoc.id}', extra: {
                          'groupName': name,
                          'isGroup': true,
                        });
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal membuat grup: $e')),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
