import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:program/fitur/live_shopping/presentation/providers/live_shopping_provider.dart';

class LiveChatWidget extends ConsumerStatefulWidget {
  final VoidCallback onActionButtonPressed;
  final bool isJastiper;

  const LiveChatWidget({
    super.key,
    required this.onActionButtonPressed,
    this.isJastiper = false,
  });

  @override
  ConsumerState<LiveChatWidget> createState() => _LiveChatWidgetState();
}

class _LiveChatWidgetState extends ConsumerState<LiveChatWidget> {
  final TextEditingController _chatController = TextEditingController();

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;
    ref.read(liveShoppingProvider.notifier).sendMessage(_chatController.text);
    _chatController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(liveShoppingProvider.select((s) => s.messages));

    // PERBAIKAN: Ambil hanya 3 pesan terakhir dari state
    final displayedMessages = messages.length > 3
        ? messages.sublist(messages.length - 3)
        : messages;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Daftar Pesan
        Expanded(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: ListView.builder(
              reverse: true, // Penting agar list mulai dari bawah
              shrinkWrap: true,
              itemCount: displayedMessages.length,
              itemBuilder: (context, index) {
                // Balik urutan agar pesan terbaru (terakhir) muncul paling bawah
                final message = displayedMessages.reversed.toList()[index];
                return _buildChatMessage(message);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: ElevatedButton.icon(
            onPressed: widget.onActionButtonPressed,
            icon: Icon(widget.isJastiper ? Icons.dashboard_customize : Icons.shopping_bag),
            label: Text(widget.isJastiper ? "Aksi Jastiper" : "Beli Sekarang"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),
        // Input Pesan
        _buildMessageInputField(),
      ],
    );
  }

  Widget _buildChatMessage(HMSMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          children: [
            TextSpan(
              text: "${message.sender?.name ?? 'Anonim'}: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: message.message),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black.withOpacity(0.5),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ketik komentar...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}