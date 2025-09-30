import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:http/http.dart' as http;

// State untuk transaksi (tidak ada perubahan)
class TransactionState {
  final bool isLoading;
  final String? error;

  TransactionState({this.isLoading = false, this.error});

  TransactionState copyWith({bool? isLoading, String? error}) {
    return TransactionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Notifier untuk logika transaksi
class TransactionNotifier extends StateNotifier<TransactionState> {
  final Ref _ref;
  TransactionNotifier(this._ref) : super(TransactionState());

  // PASTIKAN URL INI ADALAH URL NGROK ANDA YANG SEDANG AKTIF
  final String _serverUrl = "https://4d845549a394.ngrok-free.app"; // Ganti dengan URL ngrok Anda

  // PERBAIKAN: Fungsi ini sekarang mengembalikan Map<String, String>
  Future<Map<String, String>?> createInvoice(double amount) async {
    state = state.copyWith(isLoading: true, error: null);
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      state = state.copyWith(isLoading: false, error: "Pengguna tidak login.");
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/create-invoice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'userId': user.uid,
          'email': user.email,
        }),
      );

      if (response.statusCode == 200) {
        state = state.copyWith(isLoading: false);
        final body = jsonDecode(response.body);
        // Kembalikan URL dan ID eksternal
        return {
          'invoiceUrl': body['invoiceUrl'],
          'externalId': body['externalId'],
        };
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Gagal membuat invoice.');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  // FUNGSI BARU: Untuk memeriksa status invoice dari server
  Future<String?> checkInvoiceStatus(String externalId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/check-invoice/$externalId'),
      );

      if (response.statusCode == 200) {
        state = state.copyWith(isLoading: false);
        return jsonDecode(response.body)['status'];
      } else {
        throw Exception('Gagal memeriksa status invoice.');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

final transactionProvider = StateNotifierProvider.autoDispose<TransactionNotifier, TransactionState>((ref) {
  return TransactionNotifier(ref);
});

