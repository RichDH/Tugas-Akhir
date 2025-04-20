import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'firebase_options.dart'; // File konfigurasi Firebase (pastikan sudah ada)
import 'app/app.dart'; // Import widget App utama Anda (akan dibuat)

void main() async { // Jadikan main async
  WidgetsFlutterBinding.ensureInitialized(); // Wajib sebelum Firebase.initializeApp
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Gunakan konfigurasi Firebase
  );
  runApp(
    const ProviderScope( // Bungkus dengan ProviderScope untuk Riverpod
      child: App(), // Jalankan widget App utama Anda
    ),
  );
}