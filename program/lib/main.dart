import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:http/http.dart' as http;
import 'app/constants/app_constants.dart';
import 'firebase_options.dart';
import 'app/app.dart'; // Kita akan buat file ini nanti
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:cloudinary_flutter/image/cld_image.dart';
import 'package:cloudinary_flutter/cloudinary_context.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized(); // PASTIKAN BARIS INI ADA

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("Firebase initialized successfully"); // Optional, untuk debugging

  try {
    final response = await http.get(
      Uri.parse('${AppConstants.ngrokUrl}/cleanup-expired-cart-items'),
    );
    if (response.statusCode == 200) {
      print('Auto-remove cart items: ${response.body}');
    }
  } catch (e) {
    print('Gagal auto-remove cart items: $e');
  }
  // Bungkus aplikasi root dengan ProviderScope
  runApp(
    const ProviderScope(
      child: App(), // App() adalah widget root aplikasi Anda
    ),
  );
}

// Hapus class MyApp, MyHomePage, _MyHomePageState dari sini
// Kita akan membuat widget root App terpisah di file app/app.dart