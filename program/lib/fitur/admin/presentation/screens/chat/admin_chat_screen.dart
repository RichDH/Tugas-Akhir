// File: program/lib/fitur/admin/presentation/screens/admin_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:program/app/providers/firebase_providers.dart';

class AdminChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String otherName;

  const AdminChatScreen({
    super.key,
    required this.roomId,
    required this.otherName,
  });

  @override
  ConsumerState<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends ConsumerState<AdminChatScreen> {
  final _controller = TextEditingController();
  late final Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    final firestore = ref.read(firebaseFirestoreProvider);
    _messagesStream = firestore
        .collection('chats')
        .doc(widget.roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && mounted) {
      FirebaseFirestore.instance
          .collection('users').doc(currentUser.uid)
          .collection('chat_read_status').doc(widget.roomId)
          .set({'lastRead': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;

    final text = _controller.text.trim();
    final firestore = ref.read(firebaseFirestoreProvider);
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;

    try {
      final roomRef = firestore.collection('chats').doc(widget.roomId);
      await roomRef.collection('messages').add({
        'senderId': admin.uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': 'text',
      });

      await roomRef.update({
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      _controller.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat: ${widget.otherName}')),
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
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Mulai percakapan.'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    // ✅ FIX: Safe data access
                    final messageData = doc.data();

                    if (messageData is! Map<String, dynamic>) {
                      return const SizedBox.shrink();
                    }

                    final isMe = (messageData['senderId']?.toString() ?? '') ==
                        FirebaseAuth.instance.currentUser?.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          messageData['text']?.toString() ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Balas pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: _send,
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
