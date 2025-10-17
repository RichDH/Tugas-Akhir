// chat_list.dart - PERBAIKAN LENGKAP
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/chat/presentation/providers/chat_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(); // atau sesuaikan dengan navigasi Anda
          },
        ),
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

              // ✅ FIX 2: Deteksi tipe chat (group vs 1-on-1)
              final isGroup = data['type'] == 'group';
              final lastMessage = data['lastMessage'] as String? ?? '';

              if (isGroup) {
                // GROUP CHAT
                final groupName = data['name']?.toString() ?? 'Group';
                final members = List<String>.from(data['users'] ?? []);

                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.group),
                  ),
                  title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text('${members.length} anggota',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: () {
                    // ✅ FIX 2: Route ke group chat dengan chat room ID
                    context.push('/group-chat/${chatRoom.id}', extra: {
                      'groupName': groupName,
                      'isGroup': true,
                    });
                  },
                );
              } else {
                // 1-ON-1 CHAT (existing code)
                final users = List<String>.from(data['users'] as List? ?? []);
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
              }
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: ${err.toString()}")),
      ),
    );
  }

  // ✅ FIX 2: Dialog pembuatan group dengan route yang benar
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

    // Stream followers milik current user
    final followersStream = firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('followers')
        .snapshots();

    // State lokal untuk pilihan anggota
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
                      height: 260, // scrollable box
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

                          // ✅ BATASI whereIn max 10, jika > 10 perlu batching
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
                      // Buat dokumen chat group
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
                        // ✅ FIX 2: Route ke group chat dengan ID yang benar
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
