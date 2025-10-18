// File: program/lib/fitur/chat/presentation/screens/chat_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/chat/presentation/providers/chat_provider.dart';

// ✅ FIX 2: Function getAdminId yang lebih simple dan reliable
Future<String?> _getAdminId(FirebaseFirestore firestore) async {
  try {
    final adminQuery = await firestore
        .collection('users')
        .where('email', isEqualTo: 'admin@gmail.com')
        .limit(1)
        .get();
    if (adminQuery.docs.isNotEmpty) {
      return adminQuery.docs.first.id;
    }
    return null;
  } catch (e) {
    print('Error get admin UID: $e');
    return null;
  }
}

class ChatAdminScreen extends ConsumerStatefulWidget {
  const ChatAdminScreen({super.key});

  @override
  ConsumerState<ChatAdminScreen> createState() => _ChatAdminScreenState();
}

class _ChatAdminScreenState extends ConsumerState<ChatAdminScreen> {
  final _controller = TextEditingController();
  String? _chatRoomId;
  String? _adminId;
  bool _isInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initRoom();
  }

  Future<void> _initRoom() async {
    try {
      final firestore = ref.read(firebaseFirestoreProvider);
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'User tidak login';
            _isInitialized = true;
          });
        }
        return;
      }

      final adminId = await _getAdminId(firestore);
      if (adminId == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Admin tidak ditemukan. Pastikan sudah setup admin ID.';
            _isInitialized = true;
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _adminId = adminId);
      }

      final ids = [currentUser.uid, adminId]..sort();
      final roomId = ids.join('_');

      if (mounted) {
        setState(() => _chatRoomId = roomId);
      }

      // Buat room jika belum ada
      final roomRef = firestore.collection('chats').doc(roomId);
      final roomDoc = await roomRef.get();
      if (!roomDoc.exists) {
        await roomRef.set({
          'type': 'direct',
          'users': [currentUser.uid, adminId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'isAdminChat': true,
        });
      }

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      print('Error init room: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && _chatRoomId != null && mounted) {
      FirebaseFirestore.instance
          .collection('users').doc(currentUser.uid)
          .collection('chat_read_status').doc(_chatRoomId!)
          .set({'lastRead': FieldValue.serverTimestamp()}, SetOptions(merge: true))
          .catchError((e) => print('Error marking as read: $e'));
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty || _chatRoomId == null) return;

    final text = _controller.text.trim();
    final firestore = ref.read(firebaseFirestoreProvider);
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    try {
      final roomRef = firestore.collection('chats').doc(_chatRoomId!);
      await roomRef.collection('messages').add({
        'senderId': me.uid,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim pesan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat Admin')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    if (_chatRoomId == null) {
      return const Scaffold(
        body: Center(child: Text('Memuat chat...')),
      );
    }

    final messagesStream = ref.watch(messagesStreamProvider(_chatRoomId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Admin')),
      body: Column(
        children: [
          Expanded(
            child: messagesStream.when(
              data: (snapshot) {
                if (snapshot.docs.isEmpty) {
                  return const Center(
                    child: Text('Mulai percakapan dengan admin.'),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: snapshot.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.docs[index];
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
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
                      hintText: 'Ketik pesan ke admin...',
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
