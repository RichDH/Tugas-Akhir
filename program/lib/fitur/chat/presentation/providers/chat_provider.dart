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

  // GANTI URL INI dengan URL NGROK Anda yang sedang berjalan
  final String _serverUrl = AppConstants.ngrokUrl;

  // FUNGSI BARU: Untuk membuat chat room sebelum masuk ke halaman chat
  Future<String> createOrGetChatRoom(String otherUserId) async {
    final firestore = _ref.read(firebaseFirestoreProvider);
    final currentUser = _ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null) throw Exception("User tidak login");

    List<String> ids = [currentUser.uid, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    final chatRoomRef = firestore.collection('chats').doc(chatRoomId);
    final snapshot = await chatRoomRef.get();

    if (!snapshot.exists) {
      // Jika ruang chat belum ada, buat dulu dengan daftar penggunanya
      await chatRoomRef.set({
        'users': ids,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return chatRoomId;
  }

  // FUNGSI sendMessage yang sudah disederhanakan kembali
  Future<void> sendMessage(String chatRoomId, String otherUserId, String text) async {
    final firestore = _ref.read(firebaseFirestoreProvider);
    final currentUser = _ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null || text.trim().isEmpty) return;

    final chatRoomRef = firestore.collection('chats').doc(chatRoomId);

    // Langsung kirim pesan
    await chatRoomRef.collection('messages').add({
      'senderId': currentUser.uid,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update last message
    await chatRoomRef.update({
      'lastMessage': text.trim(),
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });

    // Panggil fungsi notifikasi
    try {
      final userDoc = await firestore.collection('users').doc(currentUser.uid).get();
      final senderName = userDoc.data()?['username'] ?? 'Seseorang';

      await http.post(
        Uri.parse('$_serverUrl/sendNotification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipientId': otherUserId,
          'senderName': senderName,
          'messageText': text.trim(),
        }),
      );
    } catch (e) {
      print("Gagal memanggil fungsi notifikasi: $e");
    }
  }
}

// Provider untuk Notifier (tidak ada perubahan)
final chatNotifierProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

// Provider untuk mendapatkan stream pesan (tidak ada perubahan)
final messagesStreamProvider =
StreamProvider.family.autoDispose<QuerySnapshot, String>((ref, chatRoomId) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('chats')
      .doc(chatRoomId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots();
});

// Provider untuk mendapatkan daftar chat room (tidak ada perubahan)
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
      .snapshots();
});

