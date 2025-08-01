import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ApiService {
  // PASTIKAN URL INI ADALAH URL NGROK ANDA YANG SEDANG AKTIF
  // ngrok http 3000
  static const String _baseUrl = 'https://3551d10c91e6.ngrok-free.app';

  // Fungsi untuk membuat room
  Future<String> createRoom({required String title}) async {
    final Uri url = Uri.parse('$_baseUrl/create-room');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': title}),
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

  // Fungsi untuk mendapatkan token
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

        // PERBAIKAN: Mengakses token yang bersarang (nested)
        if (decodedBody is Map<String, dynamic> &&
            decodedBody['token'] is Map<String, dynamic> &&
            decodedBody['token']['token'] is String) {

          final String token = decodedBody['token']['token'];
          return token;
        } else if (decodedBody is Map<String, dynamic> && decodedBody['token'] is String) {
          // Fallback jika backend mengirim format yang benar
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