import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Tambahkan ini
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/chat/presentation/providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherUsername;
  final String? postId;
  final bool isOfferMode;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
    this.postId,
    this.isOfferMode = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  String _generateChatRoomId(String currentUserId, String otherUserId) {
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    return ids.join('_');
  }

  void _sendMessage(String chatRoomId) {
    if (_messageController.text.trim().isNotEmpty) {
      ref.read(chatNotifierProvider.notifier).sendMessage(
        chatRoomId,
        widget.otherUserId,
        _messageController.text,
      );
      _messageController.clear();
      FocusScope.of(context).unfocus();
    }
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
      return Scaffold(
        body: Center(child: Text("User tidak login")),
      );
    }

    final chatRoomId = _generateChatRoomId(currentUser.uid, widget.otherUserId);
    final messagesAsync = ref.watch(messagesStreamProvider(chatRoomId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUsername),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (snapshot) {
                if (snapshot.docs.isEmpty) {
                  return const Center(child: Text("Mulai percakapan!"));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: snapshot.docs.length,
                  itemBuilder: (context, index) {
                    final message = snapshot.docs[index].data() as Map<String, dynamic>;
                    final bool isMe = message['senderId'] == currentUser.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).primaryColor : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message['text'] ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text("Error: ${err.toString()}")),
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
                      hintText: 'Ketik pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                    ),
                    onSubmitted: (_) => _sendMessage(chatRoomId),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(chatRoomId),
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