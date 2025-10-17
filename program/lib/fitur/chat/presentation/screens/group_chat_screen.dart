// File: program/lib/fitur/chat/presentation/screens/group_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.chatId,
    required this.groupName,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late Stream<QuerySnapshot> _messagesStream;
  late Stream<DocumentSnapshot> _groupInfoStream;

  @override
  void initState() {
    super.initState();
    final firestore = ref.read(firebaseFirestoreProvider);

    // Stream untuk messages
    _messagesStream = firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();

    // Stream untuk group info (members, admins, etc)
    _groupInfoStream = firestore
        .collection('chats')
        .doc(widget.chatId)
        .snapshots();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final firestore = ref.read(firebaseFirestoreProvider);
    final currentUser = ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null) return;

    try {
      // Get current user data untuk username
      final userDoc = await firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final username = userData['username']?.toString() ?? 'Unknown';

      final chatRef = firestore.collection('chats').doc(widget.chatId);

      // Kirim pesan ke group
      await chatRef.collection('messages').add({
        'senderId': currentUser.uid,
        'senderName': username,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': 'text',
      });

      // Update last message di group document
      await chatRef.update({
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      print('Error sending group message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim pesan: $e')),
      );
    }
  }

  Future<void> _showGroupInfo() async {
    final firestore = ref.read(firebaseFirestoreProvider);
    final currentUser = ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null) return;

    try {
      final groupDoc = await firestore.collection('chats').doc(widget.chatId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final members = List<String>.from(groupData['users'] ?? []);
      final admins = List<String>.from(groupData['admins'] ?? []);
      final isAdmin = admins.contains(currentUser.uid);

      showDialog(
        context: context,
        builder: (context) => _GroupInfoDialog(
          chatId: widget.chatId,
          groupName: widget.groupName,
          members: members,
          admins: admins,
          isCurrentUserAdmin: isAdmin,
        ),
      );
    } catch (e) {
      print('Error showing group info: $e');
    }
  }

  Widget _buildMessage(Map<String, dynamic> message, bool isMe) {
    final text = message['text']?.toString() ?? '';
    final senderName = message['senderName']?.toString() ?? 'Unknown';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe) ...[
              Text(
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.white70 : Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("User tidak login")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.groupName),
            StreamBuilder<DocumentSnapshot>(
              stream: _groupInfoStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final members = List<String>.from(data['users'] ?? []);

                return Text(
                  '${members.length} anggota',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Mulai percakapan grup!'),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final message = doc.data() as Map<String, dynamic>;
                    final bool isMe = message['senderId'] == currentUser.uid;

                    return _buildMessage(message, isMe);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan grup...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Dialog untuk info grup dan management
class _GroupInfoDialog extends ConsumerStatefulWidget {
  final String chatId;
  final String groupName;
  final List<String> members;
  final List<String> admins;
  final bool isCurrentUserAdmin;

  const _GroupInfoDialog({
    required this.chatId,
    required this.groupName,
    required this.members,
    required this.admins,
    required this.isCurrentUserAdmin,
  });

  @override
  ConsumerState<_GroupInfoDialog> createState() => _GroupInfoDialogState();
}

class _GroupInfoDialogState extends ConsumerState<_GroupInfoDialog> {
  Future<Map<String, String>> _getUsernames(List<String> userIds) async {
    final firestore = ref.read(firebaseFirestoreProvider);
    final Map<String, String> usernames = {};

    for (String userId in userIds) {
      try {
        final userDoc = await firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? {};
        usernames[userId] = userData['username']?.toString() ?? 'Unknown';
      } catch (e) {
        usernames[userId] = 'Unknown';
      }
    }

    return usernames;
  }

  Future<void> _removeMember(String memberId) async {
    if (!widget.isCurrentUserAdmin) return;

    try {
      final firestore = ref.read(firebaseFirestoreProvider);
      await firestore.collection('chats').doc(widget.chatId).update({
        'users': FieldValue.arrayRemove([memberId]),
        'admins': FieldValue.arrayRemove([memberId]), // Remove from admins too if admin
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anggota berhasil dikeluarkan')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengeluarkan anggota: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Info Group: ${widget.groupName}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anggota (${widget.members.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<Map<String, String>>(
                future: _getUsernames(widget.members),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final usernames = snapshot.data ?? {};

                  return ListView.builder(
                    itemCount: widget.members.length,
                    itemBuilder: (context, index) {
                      final memberId = widget.members[index];
                      final username = usernames[memberId] ?? 'Loading...';
                      final isAdmin = widget.admins.contains(memberId);
                      final currentUser = ref.read(firebaseAuthProvider).currentUser;
                      final isCurrentUser = memberId == currentUser?.uid;

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?'),
                        ),
                        title: Row(
                          children: [
                            Text(username),
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (isCurrentUser) ...[
                              const SizedBox(width: 8),
                              const Text(
                                '(Anda)',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: widget.isCurrentUserAdmin && !isCurrentUser
                            ? IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeMember(memberId),
                          tooltip: 'Keluarkan dari grup',
                        )
                            : null,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
