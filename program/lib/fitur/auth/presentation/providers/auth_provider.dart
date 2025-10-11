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
      // Jika berhasil, authStateChangesProvider akan otomatis mengupdate,
      // dan GoRouter akan melakukan redirect.
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
  Future<void> register(String email, String password, String username) async {
    state = state.copyWith(isLoading: true, error: null); // Set state loading

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // --- SIMPAN DATA USER KE FIRESTORE ---
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'username': username, // Simpan username awal
          'createdAt': Timestamp.now(),
          'isVerified': false, // Tambahkan field verifikasi
          'saldo': 0,
          // Tambahkan field profil lain yang relevan
        });
        await FCMService().init();
      }
      // ------------------------------------

      state = state.copyWith(isLoading: false); // Register berhasil, matikan loading
      // authStateChangesProvider akan otomatis mengupdate & GoRouter redirect
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Terjadi kesalahan saat pendaftaran.';
      if (e.code == 'weak-password') {
        errorMessage = 'Password terlalu lemah.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Email sudah terdaftar.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      }
      // Tambahkan penanganan error lain jika perlu

      state = state.copyWith(isLoading: false, error: errorMessage); // Set state error
    } catch (e) {
      print(e.toString());
      state = state.copyWith(isLoading: false, error: e.toString()); // Set state error
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
  return user?.email == 'adminngoper87@gmail.com';
});

// Provider untuk AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final auth = ref.watch(firebaseAuthProvider); // Dapatkan instance FirebaseAuth
  final firestore = ref.watch(firebaseFirestoreProvider); // Dapatkan instance FirebaseFirestore
  return AuthNotifier(auth, firestore);
});