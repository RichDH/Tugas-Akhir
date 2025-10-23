import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/constants/app_constants.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/announcement/data/announcement_upload_service.dart';

class AdminAnnouncementState {
  final bool isLoading;
  final String? error;
  final bool success;

  const AdminAnnouncementState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  AdminAnnouncementState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
  }) {
    return AdminAnnouncementState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

class AdminAnnouncementNotifier extends StateNotifier<AdminAnnouncementState> {
  final Ref _ref;

  AdminAnnouncementNotifier(this._ref) : super(const AdminAnnouncementState());

  // String get _backendBaseUrl => const String.fromEnvironment(AppConstants.vercelUrl, defaultValue: '');

  Future<void> createAnnouncement({
    required String title,
    required String body,
    File? imageFile,
  }) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      // 1) Upload image jika ada
      String? imageUrl;
      if (imageFile != null) {
        final uploader = AnnouncementUploadService();
        imageUrl = await uploader.uploadImage(imageFile);
      }

      // 2) Simpan master announcement (opsional, untuk histori/admin view)
      final db = _ref.read(firebaseFirestoreProvider);
      final masterRef = db.collection('announcements').doc(); // auto ID
      await masterRef.set({
        'id': masterRef.id,
        'title': title,
        'body': body,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _ref.read(firebaseAuthProvider).currentUser?.uid,
      });

      final url = Uri.parse('${AppConstants.vercelUrl}/send-announcement');
      final resp = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'body': body,
          'imageUrl': imageUrl,
          'senderId': _ref.read(firebaseAuthProvider).currentUser?.uid ?? 'admin',
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('Gagal mengirim pengumuman: ${resp.statusCode} ${resp.body}');
      }

      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString(), success: false);
    }
  }
}

final adminAnnouncementProvider = StateNotifierProvider.autoDispose<AdminAnnouncementNotifier, AdminAnnouncementState>((ref) {
  return AdminAnnouncementNotifier(ref);
});
