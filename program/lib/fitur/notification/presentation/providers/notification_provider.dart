// File: program/lib/fitur/notification/presentation/providers/notification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/notification/domain/entities/notification_entity.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:program/app/constants/app_constants.dart';

// Provider untuk notifications stream
final notificationsStreamProvider = StreamProvider.autoDispose<List<NotificationEntity>>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final currentUser = ref.watch(firebaseAuthProvider).currentUser;

  if (currentUser == null) {
    return Stream.value([]);
  }

  return firestore
      .collection('users')
      .doc(currentUser.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
      .map((doc) => NotificationEntity.fromMap(doc.id, doc.data()))
      .toList());
});

// Provider untuk unread count
final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final currentUser = ref.watch(firebaseAuthProvider).currentUser;

  if (currentUser == null) {
    return Stream.value(0);
  }

  return firestore
      .collection('users')
      .doc(currentUser.uid)
      .collection('notifications')
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

// StateNotifier untuk notification actions
class NotificationNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  NotificationNotifier(this._ref) : super(const AsyncValue.data(null));

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final firestore = _ref.read(firebaseFirestoreProvider);
    final currentUser = _ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null) return;

    try {
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    state = const AsyncValue.loading();

    try {
      final firestore = _ref.read(firebaseFirestoreProvider);
      final currentUser = _ref.read(firebaseAuthProvider).currentUser;

      if (currentUser == null) return;

      final batch = firestore.batch();
      final unreadNotifications = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // Create announcement (admin only)
  Future<void> createAnnouncement({
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = _ref.read(firebaseAuthProvider).currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      // Send announcement via backend
      final response = await http.post(
        Uri.parse('${AppConstants.vercelUrl}/send-announcement'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'body': body,
          'imageUrl': imageUrl,
          'senderId': currentUser.uid,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send announcement: ${response.body}');
      }

      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // Save chat notification locally
  Future<void> saveChatNotification({
    required String title,
    required String body,
    required String senderId,
    required String senderName,
    Map<String, dynamic>? data,
  }) async {
    final firestore = _ref.read(firebaseFirestoreProvider);
    final currentUser = _ref.read(firebaseAuthProvider).currentUser;

    if (currentUser == null || senderId == currentUser.uid) return;

    try {
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': 'chat',
        'senderId': senderId,
        'senderName': senderName,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error saving chat notification: $e');
    }
  }
}

final notificationNotifierProvider = StateNotifierProvider<NotificationNotifier, AsyncValue<void>>((ref) {
  return NotificationNotifier(ref);
});
