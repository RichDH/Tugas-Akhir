// File: program/lib/fitur/chat/presentation/screens/group_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';

class Poll {
  final String id;
  final String question;
  final List<String> options;
  final Map<String, List<String>> votes; // optionIndex -> [userIds]
  final String creatorId;
  final DateTime createdAt;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    required this.creatorId,
    required this.createdAt,
  });

  factory Poll.fromMap(Map<String, dynamic> map) {
    return Poll(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      votes: Map<String, List<String>>.from(
        (map['votes'] as Map<String, dynamic>? ?? {}).map(
              (key, value) => MapEntry(key, List<String>.from(value ?? [])),
        ),
      ),
      creatorId: map['creatorId'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'votes': votes,
      'creatorId': creatorId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  int getTotalVotes() {
    return votes.values.fold(0, (sum, userIds) => sum + userIds.length);
  }

  int getVotesForOption(int optionIndex) {
    return votes[optionIndex.toString()]?.length ?? 0;
  }

  bool hasUserVoted(String userId) {
    return votes.values.any((userIds) => userIds.contains(userId));
  }

  String? getUserVotedOption(String userId) {
    for (var entry in votes.entries) {
      if (entry.value.contains(userId)) {
        return entry.key;
      }
    }
    return null;
  }
}

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

  // Method untuk vote pada poll
  Future<void> _voteOnPoll(String? messageId, int optionIndex) async {
    if (messageId == null) return;

    final firestore = ref.read(firebaseFirestoreProvider);
    final currentUser = ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null) return;

    try {
      final messageRef = firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId);

      await firestore.runTransaction((transaction) async {
        final messageDoc = await transaction.get(messageRef);
        if (!messageDoc.exists) return;

        final messageData = messageDoc.data() as Map<String, dynamic>;
        final pollData = messageData['pollData'] as Map<String, dynamic>;
        final votes = Map<String, List<String>>.from(
          (pollData['votes'] as Map<String, dynamic>? ?? {}).map(
                (key, value) => MapEntry(key, List<String>.from(value ?? [])),
          ),
        );

        // Remove user from any previous votes
        votes.forEach((key, userIds) {
          userIds.remove(currentUser.uid);
        });

        // Add user to selected option
        final optionKey = optionIndex.toString();
        if (!votes.containsKey(optionKey)) {
          votes[optionKey] = [];
        }
        votes[optionKey]!.add(currentUser.uid);

        // Update the message with new votes
        pollData['votes'] = votes;
        transaction.update(messageRef, {
          'pollData': pollData,
        });
      });
    } catch (e) {
      print('Error voting on poll: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memberikan vote: $e')),
      );
    }
  }

// Method untuk show poll details
  void _showPollDetails(Poll poll) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vote Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              poll.question,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...poll.options.asMap().entries.map((entry) {
              final optionIndex = entry.key;
              final optionText = entry.value;
              final optionVotes = poll.getVotesForOption(optionIndex);
              final totalVotes = poll.getTotalVotes();
              final percentage = totalVotes > 0 ? (optionVotes / totalVotes * 100) : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(optionText)),
                        Text('${percentage.toStringAsFixed(1)}%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                    ),
                    Text(
                      '$optionVotes votes',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

// Method untuk create poll (tambahkan setelah _sendMessage method)
  Future<void> _createPoll(String question, List<String> options) async {
    final firestore = ref.read(firebaseFirestoreProvider);
    final currentUser = ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null) return;

    try {
      // Get current user data untuk username
      final userDoc = await firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final username = userData['username']?.toString() ?? 'Unknown';

      final chatRef = firestore.collection('chats').doc(widget.chatId);
      final messageId = firestore.collection('temp').doc().id; // Generate unique ID

      // Create poll data
      final poll = Poll(
        id: messageId,
        question: question,
        options: options,
        votes: {}, // Empty votes initially
        creatorId: currentUser.uid,
        createdAt: DateTime.now(),
      );

      // Send poll message to group
      await chatRef.collection('messages').doc(messageId).set({
        'messageId': messageId,
        'senderId': currentUser.uid,
        'senderName': username,
        'text': 'Poll: $question',
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': 'poll',
        'pollData': poll.toMap(),
      });

      // Update last message di group document
      await chatRef.update({
        'lastMessage': 'Poll: $question',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating poll: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat poll: $e')),
      );
    }
  }

// Method untuk show create poll dialog
  void _showCreatePollDialog() {
    final TextEditingController questionController = TextEditingController();
    final List<TextEditingController> optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Create Poll'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionController,
                      decoration: const InputDecoration(
                        labelText: 'Poll Question',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Poll Options',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: optionControllers.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: optionControllers[index],
                                    decoration: InputDecoration(
                                      labelText: 'Option ${index + 1}',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                if (optionControllers.length > 2) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        optionControllers.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (optionControllers.length < 5)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            optionControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Option'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final question = questionController.text.trim();
                    final options = optionControllers
                        .map((controller) => controller.text.trim())
                        .where((text) => text.isNotEmpty)
                        .toList();

                    if (question.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Question is required')),
                      );
                      return;
                    }

                    if (options.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('At least 2 options required')),
                      );
                      return;
                    }

                    await _createPoll(question, options);
                    Navigator.pop(ctx);
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


  Widget _buildMessage(Map<String, dynamic> message, bool isMe) {
    final messageType = message['messageType']?.toString() ?? 'text';

    if (messageType == 'poll') {
      return _buildPollMessage(message, isMe);
    }

    // Existing text message code (tidak diubah)
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

  Widget _buildPollMessage(Map<String, dynamic> message, bool isMe) {
    final pollData = message['pollData'] as Map<String, dynamic>? ?? {};
    final senderName = message['senderName']?.toString() ?? 'Unknown';
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return const SizedBox.shrink();

    final poll = Poll.fromMap(pollData);
    final hasVoted = poll.hasUserVoted(currentUser.uid);
    final userVotedOption = poll.getUserVotedOption(currentUser.uid);
    final totalVotes = poll.getTotalVotes();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender name for group
            if (!isMe) ...[
              Text(
                '~ $senderName',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Poll question
            Text(
              poll.question,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),

            // Poll options
            ...poll.options.asMap().entries.map((entry) {
              final optionIndex = entry.key;
              final optionText = entry.value;
              final optionVotes = poll.getVotesForOption(optionIndex);
              final percentage = totalVotes > 0 ? (optionVotes / totalVotes) : 0.0;
              final isSelected = userVotedOption == optionIndex.toString();

              return GestureDetector(
                onTap: hasVoted ? null : () => _voteOnPoll(message['messageId'], optionIndex),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade100 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Checkbox/Circle indicator
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.green : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? Colors.green : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 8),

                      // Option text and percentage
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              optionText,
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (hasVoted) ...[
                              const SizedBox(height: 2),
                              // Progress bar
                              LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isSelected ? Colors.green : Colors.blue.shade300,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Vote count and avatars
                      if (hasVoted) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // User avatars (max 3)
                            if (optionVotes > 0) ...[
                              SizedBox(
                                width: optionVotes > 3 ? 60 : optionVotes * 20.0,
                                height: 20,
                                child: Stack(
                                  children: poll.votes[optionIndex.toString()]
                                      ?.take(3)
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((userEntry) {
                                    final stackIndex = userEntry.key;
                                    return Positioned(
                                      left: stackIndex * 12.0,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.blue.shade300,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.person,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                      .toList() ?? [],
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              '$optionVotes',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),

            // Total votes
            if (hasVoted) ...[
              const SizedBox(height: 8),
              Text(
                totalVotes == 1 ? '$totalVotes vote' : '$totalVotes votes',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            // View votes button
            if (hasVoted && totalVotes > 0) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showPollDetails(poll),
                child: const Text(
                  'View votes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
          // Update bagian Padding untuk input chat di build method
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Plus button untuk poll (hanya untuk admin/creator)
                StreamBuilder<DocumentSnapshot>(
                  stream: _groupInfoStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final admins = List<String>.from(data['admins'] ?? []);
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final isAdmin = currentUser != null && admins.contains(currentUser.uid);

                    return isAdmin
                        ? IconButton(
                      icon: const Icon(Icons.add, color: Colors.blue),
                      onPressed: _showCreatePollDialog,
                      tooltip: 'Create Poll',
                    )
                        : const SizedBox.shrink();
                  },
                ),
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
