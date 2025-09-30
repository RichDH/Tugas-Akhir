import 'dart:io';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ApiService {
  // ngrok http 3000
  static const String _baseUrl = 'https://4d845549a394.ngrok-free.app';

  // PERBAIKAN 1: Fungsi untuk membuat room dengan unique ID
  Future<String> createRoom({required String title}) async {
    final Uri url = Uri.parse('$_baseUrl/create-room');
    try {
      // TAMBAHKAN TIMESTAMP UNTUK MEMBUAT ROOM ID UNIK
      final uniqueTitle = '${title}_${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': uniqueTitle}), // Gunakan unique title
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['roomId'];
      } else {
        throw Exception('Gagal membuat room baru: ${response.body}');
      }
    } catch (e) {
      throw Exception('Tidak dapat terhubung ke backend untuk membuat room: $e');
    }
  }

  // PERBAIKAN 2: Fungsi alternatif untuk membuat room dengan random ID
  Future<String> createUniqueRoom({required String title}) async {
    final Uri url = Uri.parse('$_baseUrl/create-room');
    try {
      // Generate unique room name dengan kombinasi title + timestamp + random
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = (timestamp % 10000).toString().padLeft(4, '0');
      final uniqueTitle = '${title.replaceAll(' ', '_')}_${timestamp}_$randomSuffix';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': uniqueTitle}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['roomId'];
      } else {
        throw Exception('Gagal membuat room baru: ${response.body}');
      }
    } catch (e) {
      throw Exception('Tidak dapat terhubung ke backend untuk membuat room: $e');
    }
  }

  // PERBAIKAN 3: Fungsi untuk mengecek status room sebelum membuat yang baru
  Future<bool> checkRoomStatus({required String roomId}) async {
    try {
      const String baseUrl = 'https://api.100ms.live/v2';
      const String managementToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3NTg3MTIxMzEsImV4cCI6MTc1OTMxNjkzMSwianRpIjoiYmFmZTczODgtOGIzMi00NDEyLTliYWYtMGQ2YjlhYzRjODAxIiwidHlwZSI6Im1hbmFnZW1lbnQiLCJ2ZXJzaW9uIjoyLCJuYmYiOjE3NTg3MTIxMzEsImFjY2Vzc19rZXkiOiI2NzhlMTA0OTMzY2U3NGFiOWJlOTUwNjEifQ.qKKJWjX1pi1GkdyV1mFqTwI_NtUfcmSAwOL2Z8E63i0';

      final url = Uri.parse('$baseUrl/rooms/$roomId');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $managementToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final isEnabled = responseData['enabled'] ?? false;
        debugPrint('Room $roomId status: enabled=$isEnabled');
        return isEnabled;
      } else {
        debugPrint('Failed to check room status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error checking room status: $e');
      return false;
    }
  }

  // PERBAIKAN 4: Fungsi untuk enable room yang disabled (jika memungkinkan)
  Future<bool> enableRoom({required String roomId}) async {
    try {
      const String baseUrl = 'https://api.100ms.live/v2';
      const String managementToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3NTg3MTIxMzEsImV4cCI6MTc1OTMxNjkzMSwianRpIjoiYmFmZTczODgtOGIzMi00NDEyLTliYWYtMGQ2YjlhYzRjODAxIiwidHlwZSI6Im1hbmFnZW1lbnQiLCJ2ZXJzaW9uIjoyLCJuYmYiOjE3NTg3MTIxMzEsImFjY2Vzc19rZXkiOiI2NzhlMTA0OTMzY2U3NGFiOWJlOTUwNjEifQ.qKKJWjX1pi1GkdyV1mFqTwI_NtUfcmSAwOL2Z8E63i0';

      final url = Uri.parse('$baseUrl/rooms/$roomId');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $managementToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'enabled': true,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Room $roomId enabled successfully');
        return true;
      } else {
        debugPrint('Failed to enable room: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error enabling room: $e');
      return false;
    }
  }

  // PERBAIKAN 5: Improved end room method dengan better cleanup
  Future<void> endRoomOnServer({required String roomId}) async {
    try {
      const String baseUrl_100ms = 'https://api.100ms.live/v2';
      const String managementToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3NTg3MTIxMzEsImV4cCI6MTc1OTMxNjkzMSwianRpIjoiYmFmZTczODgtOGIzMi00NDEyLTliYWYtMGQ2YjlhYzRjODAxIiwidHlwZSI6Im1hbmFnZW1lbnQiLCJ2ZXJzaW9uIjoyLCJuYmYiOjE3NTg3MTIxMzEsImFjY2Vzc19rZXkiOiI2NzhlMTA0OTMzY2U3NGFiOWJlOTUwNjEifQ.qKKJWjX1pi1GkdyV1mFqTwI_NtUfcmSAwOL2Z8E63i0';

      // STEP 1: End active room session only (tidak disable room)
      final endUrl = Uri.parse('$baseUrl_100ms/active-rooms/$roomId/end-room');

      final endResponse = await http.post(
        endUrl,
        headers: {
          'Authorization': 'Bearer $managementToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reason': 'Live session ended by host',
          'lock': false, // PENTING: false agar room tidak di-disable
        }),
      );

      if (endResponse.statusCode == 200) {
        debugPrint('Active room session ended successfully');
      } else if (endResponse.statusCode == 404) {
        debugPrint('Room session was already inactive');
      } else {
        debugPrint('Failed to end room session. Status: ${endResponse.statusCode}');
      }

      // STEP 2: Ensure room remains enabled untuk reuse
      await Future.delayed(const Duration(milliseconds: 2000));
      final isEnabled = await checkRoomStatus(roomId: roomId);

      if (!isEnabled) {
        debugPrint('Room became disabled, attempting to re-enable...');
        await enableRoom(roomId: roomId);
      }

    } catch (e) {
      debugPrint('Error ending room on server: $e');
    }
  }

  Future<void> endActiveRoom({required String roomId}) async {
    try {
      const String baseUrl = 'https://api.100ms.live/v2';
      const String managementToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3NTg3MTIxMzEsImV4cCI6MTc1OTMxNjkzMSwianRpIjoiYmFmZTczODgtOGIzMi00NDEyLTliYWYtMGQ2YjlhYzRjODAxIiwidHlwZSI6Im1hbmFnZW1lbnQiLCJ2ZXJzaW9uIjoyLCJuYmYiOjE3NTg3MTIxMzEsImFjY2Vzc19rZXkiOiI2NzhlMTA0OTMzZ2U3NGFiOWJlOTUwNjEifQ.qKKJWjX1pi1GkdyV1mFqTwI_NtUfcmSAwOL2Z8E63i0';

      final url = Uri.parse('$baseUrl/active-rooms/$roomId/end-room');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $managementToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reason': 'Live shopping session ended by host',
          'lock': false, // PENTING: false = end session tapi keep room enabled
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('Active room ended successfully: ${responseData['message']}');
      } else if (response.statusCode == 404) {
        debugPrint('Room session was already inactive');
      } else {
        debugPrint('Failed to end active room. Status: ${response.statusCode}');
        throw HttpException('Failed to end active room: ${response.statusCode}');
      }

    } catch (e) {
      debugPrint('Error ending active room: $e');
      rethrow;
    }
  }

  // HANYA gunakan method ini jika ingin permanently disable room
  Future<void> endAndLockRoom({required String roomId}) async {
    try {
      const String baseUrl = 'https://api.100ms.live/v2';
      const String managementToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3NTg3MTIxMzEsImV4cCI6MTc1OTMxNjkzMSwianRpIjoiYmFmZTczODgtOGIzMi00NDEyLTliYWYtMGQ2YjlhYzRjODAxIiwidHlwZSI6Im1hbmFnZW1lbnQiLCJ2ZXJzaW9uIjoyLCJuYmYiOjE3NTg3MTIxMzEsImFjY2Vzc19rZXkiOiI2NzhlMTA0OTMzY2U3NGFiOWJlOTUwNjEifQ.qKKJWjX1pi1GkdyV1mFqTwI_NtUfcmSAwOL2Z8E63i0';

      final url = Uri.parse('$baseUrl/active-rooms/$roomId/end-room');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $managementToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reason': 'Live shopping session permanently ended',
          'lock': true, // true = disable room permanently
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('Room ended and locked successfully: ${responseData['message']}');
      } else {
        debugPrint('Failed to end and lock room. Status: ${response.statusCode}');
        throw HttpException('Failed to end and lock room: ${response.statusCode}');
      }

    } catch (e) {
      debugPrint('Error ending and locking room: $e');
      rethrow;
    }
  }

  // Fungsi untuk mendapatkan token (tidak berubah)
  Future<String> get100msToken({
    required String roomId,
    required String userId,
    required String role,
  }) async {
    final Uri url = Uri.parse('$_baseUrl/get100msToken');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomId': roomId,
          'userId': userId,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final dynamic decodedBody = jsonDecode(response.body);

        if (decodedBody is Map<String, dynamic> &&
            decodedBody['token'] is Map<String, dynamic> &&
            decodedBody['token']['token'] is String) {

          final String token = decodedBody['token']['token'];
          return token;
        } else if (decodedBody is Map<String, dynamic> && decodedBody['token'] is String) {
          return decodedBody['token'];
        }
        else {
          throw Exception('Format respons token tidak valid.');
        }
      } else {
        throw Exception('Gagal mendapatkan token dari server: ${response.body}');
      }
    } catch (e) {
      throw Exception('Tidak dapat terhubung ke backend: $e');
    }
  }
}