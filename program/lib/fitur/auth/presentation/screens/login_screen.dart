import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/auth/presentation/providers/auth_provider.dart'; // Sesuaikan nama_project_anda

class LoginScreen extends ConsumerWidget { // Gunakan ConsumerWidget
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Tambahkan WidgetRef ref
    final authState = ref.watch(authProvider); // Watch state dari provider

    // Controllers untuk TextField
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    // Key untuk Form (untuk validasi)
    final formKey = GlobalKey<FormState>();

    // Bersihkan controller saat widget dihapus
    // Ini adalah praktik yang baik, tapi memerlukan StatefuLWidget atau Hook
    // Untuk sederhana, kita abaikan dulu di sini atau gunakan hooks_riverpod

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center( // Gunakan Center atau ListView untuk menghindari overflow
        child: SingleChildScrollView( // Penting agar tidak overflow saat keyboard muncul
          padding: const EdgeInsets.all(20.0),
          child: Form( // Gunakan Form untuk validasi
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Selamat Datang Kembali!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    // Tambahkan validasi format email jika perlu
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true, // Untuk menyembunyikan password
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                // Tombol Login
                authState.isLoading
                    ? const CircularProgressIndicator() // Tampilkan loading jika sedang proses
                    : ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      // Panggil metode login dari provider
                      ref.read(authProvider.notifier).login(
                        emailController.text.trim(), // Gunakan trim() untuk hapus spasi
                        passwordController.text.trim(),
                      );
                    }
                  },
                  child: const Text('Login'),
                ),
                const SizedBox(height: 20),
                // Tampilkan pesan error jika ada
                if (authState.error != null)
                  Text(
                    authState.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 20),
                // Tombol navigasi ke Register
                TextButton(
                  onPressed: () {
                    context.go('/register'); // Navigasi menggunakan GoRouter
                  },
                  child: const Text('Belum punya akun? Daftar di sini.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}