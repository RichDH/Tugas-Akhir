import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/core/services/fcm_service.dart';

// Definisikan state untuk provider autentikasi
class AuthState {
  final bool isLoading;
  final String? error;

  AuthState({this.isLoading = false, this.error});

  // Helper methods untuk copyWith
  AuthState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Tidak menggunakan ?? karena null error berarti tidak ada error
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthNotifier(this._auth, this._firestore) : super(AuthState()); // State awal: tidak loading, tidak error

  // Metode untuk Login
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null); // Set state loading

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);

      final uid = cred.user?.uid;
      if (uid != null) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final data = userDoc.data() ?? {};
        final isDeleted = data['deleted'] == true;

        if (isDeleted) {
          await _auth.signOut();

          final reason = data['closedReason'] as String? ?? 'pelanggaran kebijakan';
          state = state.copyWith(
            isLoading: false,
            error: 'Akun ditutup karena: $reason. Hubungi admin untuk informasi lebih lanjut.',
          );
          return;
        }
      }
      await FCMService().init();
      state = state.copyWith(isLoading: false);
      // Login berhasil, matikan loading
    } on FirebaseAuthException catch (e) {
      // Tangani error spesifik dari Firebase Auth
      String errorMessage = 'Terjadi kesalahan saat login.';
      if (e.code == 'user-not-found') {
        errorMessage = 'Email tidak terdaftar.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Password salah.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      }
      // Tambahkan penanganan error lain jika perlu

      state = state.copyWith(isLoading: false, error: errorMessage); // Set state error
    } catch (e) {
      // Tangani error umum lainnya
      state = state.copyWith(isLoading: false, error: e.toString()); // Set state error
    }
  }

  // Metode untuk Register
  // Tambahkan method untuk cek username di AuthNotifier class:

  // ✅ METHOD isUsernameAvailable YANG DIPERBAIKI - DENGAN PROPER ERROR HANDLING
  Future<bool> isUsernameAvailable(String username) async {
    try {
      // Validasi input
      if (username.trim().isEmpty) {
        throw Exception('Username tidak boleh kosong');
      }

      if (username.trim().length < 3) {
        throw Exception('Username minimal 3 karakter');
      }

      // Normalisasi username (lowercase untuk konsistensi)
      final normalizedUsername = username.trim().toLowerCase();

      print('🔍 [IsUsernameAvailable] Checking username: $normalizedUsername');

      // Query dengan timeout untuk menghindari hang
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: normalizedUsername)
          .limit(1) // ✅ OPTIMISASI: Hanya butuh 1 dokumen untuk validasi
          .get()
          .timeout(
        const Duration(seconds: 10), // ✅ TIMEOUT 10 DETIK
        onTimeout: () {
          print('❌ [IsUsernameAvailable] Timeout checking username');
          throw Exception('Koneksi timeout, coba lagi');
        },
      );

      final isAvailable = querySnapshot.docs.isEmpty;
      print('🔍 [IsUsernameAvailable] Username $normalizedUsername available: $isAvailable');

      return isAvailable;
    } on FirebaseException catch (e) {
      print('❌ [IsUsernameAvailable] Firebase error: ${e.code} - ${e.message}');

      // Handle specific Firebase errors
      if (e.code == 'permission-denied') {
        throw Exception('Tidak ada akses untuk memeriksa username. Periksa koneksi internet.');
      } else if (e.code == 'unavailable') {
        throw Exception('Server tidak tersedia, coba lagi nanti');
      } else {
        throw Exception('Error database: ${e.message}');
      }
    } catch (e) {
      print('❌ [IsUsernameAvailable] General error: $e');

      if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
        throw Exception('Koneksi timeout, periksa internet dan coba lagi');
      }

      throw Exception('Gagal memeriksa username: ${e.toString()}');
    }
  }


// Update method register:
  Future<void> register(String email, String password, String username) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Cek apakah username sudah digunakan
      final isUsernameAvailable = await this.isUsernameAvailable(username);
      if (!isUsernameAvailable) {
        state = state.copyWith(
            isLoading: false,
            error: 'Username sudah digunakan, pilih username lain'
        );
        return;
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'username': username,
          'name': '', // Tambahkan field name kosong
          'alamat': '', // Tambahkan field alamat kosong
          'createdAt': Timestamp.now(),
          'isVerified': false,
          'saldo': 0,
        });
        await FCMService().init();
      }

      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Terjadi kesalahan saat pendaftaran.';
      if (e.code == 'weak-password') {
        errorMessage = 'Password terlalu lemah.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Email sudah terdaftar.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
    } catch (e) {
      print(e.toString());
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }




  // Metode untuk Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null); // Optional: set loading saat logout
    try {
      await _auth.signOut();
      
      state = state.copyWith(isLoading: false); // Logout berhasil
      // authStateChangesProvider akan otomatis mengupdate & GoRouter redirect ke login
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString()); // Set state error
    }
  }
}

final isAdminProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.value;
  return user?.email == 'admin@gmail.com';
});

// Provider untuk AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final auth = ref.watch(firebaseAuthProvider); // Dapatkan instance FirebaseAuth
  final firestore = ref.watch(firebaseFirestoreProvider); // Dapatkan instance FirebaseFirestore
  return AuthNotifier(auth, firestore);
});