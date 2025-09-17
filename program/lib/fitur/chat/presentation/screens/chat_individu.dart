import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/chat/presentation/providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherUsername;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late final String _chatRoomId;

  @override
  void initState() {
    super.initState();
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    if (currentUser != null) {
      List<String> ids = [currentUser.uid, widget.otherUserId];
      ids.sort();
      _chatRoomId = ids.join('_');
    } else {
      // Handle jika user tidak login, meskipun seharusnya tidak terjadi
      Navigator.of(context).pop();
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      ref.read(chatNotifierProvider.notifier)
          .sendMessage(widget.otherUserId, _messageController.text);
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
    final messagesAsync = ref.watch(messagesStreamProvider(_chatRoomId));
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

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
                  reverse: true, // Membuat list mulai dari bawah
                  padding: const EdgeInsets.all(8.0),
                  itemCount: snapshot.docs.length,
                  itemBuilder: (context, index) {
                    final message = snapshot.docs[index].data() as Map<String, dynamic>;
                    final bool isMe = message['senderId'] == currentUserId;

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
          // Input area
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