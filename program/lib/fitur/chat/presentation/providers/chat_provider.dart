import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';

// State untuk chat (bisa dikembangkan nanti, untuk sekarang kosong)
class ChatState {}

// Notifier untuk mengirim pesan
class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  ChatNotifier(this._ref) : super(ChatState());

  Future<void> sendMessage(String otherUserId, String text) async {
    final firestore = _ref.read(firebaseFirestoreProvider);
    final currentUser = _ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null || text.trim().isEmpty) {
      return;
    }

    List<String> ids = [currentUser.uid, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    final messageData = {
      'senderId': currentUser.uid,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    await firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    await firestore.collection('chats').doc(chatRoomId).set({
      'users': ids,
      'lastMessage': text.trim(),
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

// Provider untuk Notifier
final chatNotifierProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

// Provider untuk mendapatkan stream pesan dari chat room tertentu
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

// --- TAMBAHKAN PROVIDER BARU DI BAWAH INI ---
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