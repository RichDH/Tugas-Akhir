import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart'; // Pastikan path ini benar
import 'package:program/fitur/chat/presentation/providers/chat_provider.dart'; // Pastikan path ini benar

class ChatScreen extends ConsumerStatefulWidget {
  // --- PERBAIKAN 1: Hapus `chatRoomId` dari constructor ---
  // Kita hanya butuh ID dan nama user lain, yang kita dapat dari GoRouter.
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

  // --- PERBAIKAN 2: Buat variabel untuk menampung chatRoomId ---
  // Kita gunakan `late final` karena akan diinisialisasi sekali di initState.
  late final String chatRoomId;

  @override
  void initState() {
    super.initState();
    // --- PERBAIKAN 3: Logika untuk membuat chatRoomId ---
    // Ini adalah bagian yang paling penting dan mungkin yang Anda lewatkan.

    // Ambil ID pengguna yang sedang login
    final currentUserId = ref.read(firebaseAuthProvider).currentUser!.uid;
    final otherUserId = widget.otherUserId;

    // Buat daftar ID dan urutkan berdasarkan abjad
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();

    // Gabungkan ID yang sudah diurutkan untuk membuat ID room yang unik dan konsisten
    chatRoomId = ids.join('_');
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      ref.read(chatNotifierProvider.notifier).sendMessage(
        // Gunakan chatRoomId yang sudah kita buat di initState
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
    // Gunakan chatRoomId dari state untuk mendengarkan stream pesan
    final messagesAsync = ref.watch(messagesStreamProvider(chatRoomId));
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        // otherUsername didapat dari widget, sudah benar
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
                    final message =
                    snapshot.docs[index].data() as Map<String, dynamic>;
                    final bool isMe = message['senderId'] == currentUserId;

                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message['text'] ?? '',
                          style: TextStyle(
                              color: isMe ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text("Error: ${err.toString()}")),
            ),
          ),
          // Input area (Tidak ada perubahan di sini, sudah bagus)
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