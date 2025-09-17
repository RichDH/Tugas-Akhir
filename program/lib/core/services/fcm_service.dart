import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> init() async {
    // 1. Meminta izin notifikasi dari pengguna
    await _firebaseMessaging.requestPermission();

    // 2. Mengambil FCM Token
    final fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      debugPrint("FCM Token: $fcmToken");
      _saveTokenToDatabase(fcmToken);
    }

    // 3. Listener untuk perubahan token
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);

    // 4. Menangani notifikasi saat aplikasi di foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Menerima notifikasi foreground!');
      if (message.notification != null) {
        debugPrint('Pesan berisi notifikasi: ${message.notification}');
      }
    });
  }

  // Fungsi untuk menyimpan token ke profil pengguna di Firestore
  Future<void> _saveTokenToDatabase(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true)); // Merge true agar tidak menimpa data lain
    }
  }
}