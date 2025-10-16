
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:program/fitur/auth/presentation/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final usernameController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  Timer? _debounceTimer;

  // TAMBAHAN BARU: State untuk username checking
  bool _isCheckingUsername = false;
  String? _usernameError;

  // TAMBAHAN BARU: Method untuk cek username secara real-time
  Future<void> _checkUsername(String username) async {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Validasi input awal
    if (username.trim().isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _usernameError = null;
      });
      return;
    }

    if (username.trim().length < 3) {
      setState(() {
        _isCheckingUsername = false;
        _usernameError = 'Username minimal 3 karakter';
      });
      return;
    }

    // Validasi karakter
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username.trim())) {
      setState(() {
        _isCheckingUsername = false;
        _usernameError = 'Hanya huruf, angka, dan underscore yang diizinkan';
      });
      return;
    }

    // Set checking state
    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    // Debounce untuk menghindari terlalu banyak request
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      try {
        print('🔍 [CheckUsername] Checking username: $username');

        final isAvailable = await ref.read(authProvider.notifier).isUsernameAvailable(username.trim());

        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            if (isAvailable) {
              _usernameError = null;
              print('✅ [CheckUsername] Username $username available');
            } else {
              _usernameError = 'Username sudah digunakan';
              print('❌ [CheckUsername] Username $username taken');
            }
          });
        }
      } catch (e) {
        print('❌ [CheckUsername] Error checking username: $e');

        if (mounted) {
          setState(() {
            _isCheckingUsername = false;

            // ✅ ERROR HANDLING YANG LEBIH BAIK
            String errorMessage = 'Gagal memeriksa username';

            if (e.toString().contains('timeout')) {
              errorMessage = 'Koneksi timeout, coba lagi';
            } else if (e.toString().contains('permission-denied')) {
              errorMessage = 'Tidak ada akses internet';
            } else if (e.toString().contains('unavailable')) {
              errorMessage = 'Server tidak tersedia';
            }

            _usernameError = errorMessage;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Logo atau judul app
              const Text(
                'Buat Akun Baru',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Email Field
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email tidak boleh kosong';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Format email tidak valid';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Username Field - DIPERBARUI dengan checking
              TextFormField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.alternate_email),
                  suffixIcon: _isCheckingUsername
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                      : (_usernameError == null && usernameController.text.length >= 3)
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  errorText: _usernameError,
                  helperText: 'Minimal 3 karakter, hanya huruf, angka, dan underscore',
                ),
                onChanged: (value) {
                  _debounceTimer?.cancel();
                  if (value.trim().isEmpty) {
                    setState(() {
                      _isCheckingUsername = false;
                      _usernameError = null;
                    });
                    return;
                  }

                  if (value.trim().length < 3) {
                    setState(() {
                      _isCheckingUsername = false;
                      _usernameError = 'Username minimal 3 karakter';
                    });
                    return;
                  }

                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                    setState(() {
                      _isCheckingUsername = false;
                      _usernameError = 'Hanya huruf, angka, dan underscore';
                    });
                    return;
                  }

                  _checkUsername(value.trim());
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Username tidak boleh kosong';
                  }
                  if (value.length < 3) {
                    return 'Username minimal 3 karakter';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return 'Username hanya boleh berisi huruf, angka, dan underscore';
                  }
                  if (_usernameError != null) {
                    return _usernameError;
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password tidak boleh kosong';
                  }
                  if (value.length < 6) {
                    return 'Password minimal 6 karakter';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Confirm Password Field
              TextFormField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Konfirmasi password tidak boleh kosong';
                  }
                  if (value != passwordController.text) {
                    return 'Password tidak cocok';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Error Message
              if (authState.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authState.error!,
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Register Button
              ElevatedButton(
                onPressed: authState.isLoading || _isCheckingUsername ? null : () {
                  if (formKey.currentState!.validate()) {
                    if (_usernameError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Perbaiki error terlebih dahulu')),
                      );
                      return;
                    }

                    ref.read(authProvider.notifier).register(
                      emailController.text.trim(),
                      passwordController.text,
                      usernameController.text.trim(),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: authState.isLoading
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Mendaftar...'),
                  ],
                )
                    : const Text('Daftar'),
              ),

              const SizedBox(height: 16),

              // Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sudah punya akun? '),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Masuk di sini'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
