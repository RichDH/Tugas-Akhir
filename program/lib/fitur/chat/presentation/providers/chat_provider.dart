import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/app/constants/app_constants.dart';
import 'package:http/http.dart' as http;

class ChatState {}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  ChatNotifier(this._ref) : super(ChatState());

  final String _serverUrl = AppConstants.vercelUrl;

  // Membuat atau mendapatkan chat room
  Future<String> createOrGetChatRoom(String otherUserId) async {
    final firestore = _ref.read(firebaseFirestoreProvider);
    final currentUser = _ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null) throw Exception("User tidak login");

    List<String> ids = [currentUser.uid, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    final chatRoomRef = firestore.collection('chats').doc(chatRoomId);

    try {
      final snapshot = await chatRoomRef.get();

      if (!snapshot.exists) {
        // Buat chat room baru dengan struktur yang aman
        await chatRoomRef.set({
          'users': ids,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error creating chat room: $e');
      // Tetap return chatRoomId meski ada error
    }

    return chatRoomId;
  }

  // Mengirim pesan reguler
  Future<void> sendMessage(String chatRoomId, String otherUserId, String text) async {
    final firestore = _ref.read(firebaseFirestoreProvider);
    final currentUser = _ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null || text.trim().isEmpty) return;

    try {
      final chatRoomRef = firestore.collection('chats').doc(chatRoomId);

      // Pastikan chat room ada terlebih dahulu
      await createOrGetChatRoom(otherUserId);

      // Kirim pesan
      await chatRoomRef.collection('messages').add({
        'senderId': currentUser.uid,
        'text': text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': 'text',
      });

      // Update last message
      await chatRoomRef.update({
        'lastMessage': text.trim(),
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      // Kirim notifikasi
      await _sendNotification(otherUserId, text.trim());

    } catch (e) {
      print("Error sending message: $e");
      rethrow;
    }
  }

  // Mengirim pesan penawaran
  Future<void> sendOfferMessage(
      String chatRoomId,
      String otherUserId,
      Map<String, dynamic> offerData
      ) async {
    final firestore = _ref.read(firebaseFirestoreProvider);
    final currentUser = _ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null) return;

    try {
      final chatRoomRef = firestore.collection('chats').doc(chatRoomId);

      // Pastikan chat room ada
      await createOrGetChatRoom(otherUserId);

      final offerText = 'Penawaran untuk ${offerData['postTitle']}';

      // Kirim pesan penawaran
      await chatRoomRef.collection('messages').add({
        'senderId': currentUser.uid,
        'text': offerText,
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': 'offer',
        'offerData': offerData,
      });

      // Update last message
      await chatRoomRef.update({
        'lastMessage': offerText,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      // Kirim notifikasi
      await _sendNotification(otherUserId, offerText);

    } catch (e) {
      print("Error sending offer message: $e");
      rethrow;
    }
  }

  // Private method untuk notifikasi
  Future<void> _sendNotification(String otherUserId, String messageText) async {
    try {
      final firestore = _ref.read(firebaseFirestoreProvider);
      final currentUser = _ref.read(firebaseAuthProvider).currentUser;

      if (currentUser == null) return;

      final userDoc = await firestore.collection('users').doc(currentUser.uid).get();
      final senderName = userDoc.data()?['username'] ?? 'Seseorang';

      await http.post(
        Uri.parse('$_serverUrl/sendNotification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipientId': otherUserId,
          'senderName': senderName,
          'messageText': messageText,
        }),
      );
    } catch (e) {
      print("Gagal mengirim notifikasi: $e");
      // Jangan throw error, karena pesan sudah terkirim
    }
  }
}

// Provider yang sudah ada
final chatNotifierProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

// Provider untuk stream pesan dengan error handling yang lebih baik
final messagesStreamProvider =
StreamProvider.family.autoDispose<QuerySnapshot, String>((ref, chatRoomId) {
  final firestore = ref.watch(firebaseFirestoreProvider);

  return firestore
      .collection('chats')
      .doc(chatRoomId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .handleError((error) {
    print('Messages stream error: $error');
    // Kembalikan stream kosong jika ada error
    return Stream.fromIterable([]);
  });
});

// Provider untuk daftar chat rooms
final chatRoomsStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final currentUser = ref.watch(firebaseAuthProvider).currentUser;

  if (currentUser == null) {
    return Stream.error('User tidak login');
  }

  return firestore
      .collection('chats')
      .where('users', arrayContains: currentUser.uid)
      .orderBy('lastMessageTimestamp', descending: true)
      .snapshots()
      .handleError((error) {
    print('Chat rooms stream error: $error');
    return Stream.fromIterable([]);
  });
});

// Provider untuk mendapatkan active posts user lain
final otherUserActivePostsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final firestore = ref.watch(firebaseFirestoreProvider);

  try {
    final snapshot = await firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  } catch (e) {
    print('Error loading other user posts: $e');
    return [];
  }
});

// Tambahan di chat_provider.dart
// Provider untuk group messages stream
final groupMessagesStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, chatId) {
  final firestore = ref.watch(firebaseFirestoreProvider);

  return firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .handleError((error) {
    print('Group messages stream error: $error');
    return Stream.fromIterable([]);
  });
});

// Provider untuk group info
final groupInfoStreamProvider = StreamProvider.autoDispose.family<DocumentSnapshot, String>((ref, chatId) {
  final firestore = ref.watch(firebaseFirestoreProvider);

  return firestore
      .collection('chats')
      .doc(chatId)
      .snapshots()
      .handleError((error) {
    print('Group info stream error: $error');
    return Stream.fromIterable([]);
  });
});

// Method untuk send group message
Future<void> sendGroupMessage(WidgetRef ref, String chatId, String text) async {
  final firestore = ref.read(firebaseFirestoreProvider);
  final currentUser = ref.read(firebaseAuthProvider).currentUser;

  if (currentUser == null || text.trim().isEmpty) return;

  try {
    // Get current user data
    final userDoc = await firestore.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data() ?? {};
    final username = userData['username']?.toString() ?? 'Unknown';

    final chatRef = firestore.collection('chats').doc(chatId);

    // Send message
    await chatRef.collection('messages').add({
      'senderId': currentUser.uid,
      'senderName': username,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': 'text',
    });

    // Update last message
    await chatRef.update({
      'lastMessage': text.trim(),
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    print("Error sending group message: $e");
    rethrow;
  }
}

