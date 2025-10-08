// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:http/http.dart' as http;
// import 'package:program/app/providers/firebase_providers.dart';
//
// class BackgroundService {
//   static Future<void> initialize() async {
//     final service = FlutterBackgroundService();
//
//     // Konfigurasi Android
//     await service.configure(
//       androidConfiguration: AndroidConfiguration(
//         onStart: _onStart,
//         autoStart: true,
//         isForegroundMode: false,
//         onForeground: (ServiceInstance service) {
//           // Tidak perlu aksi khusus saat foreground
//         },
//       ),
//       iosConfiguration: IosConfiguration(
//         onBackground: _onStart,
//         onForeground: (ServiceInstance service) {
//           // Tidak perlu aksi khusus saat foreground
//         },
//       ),
//     );
//
//     // Mulai service
//     await service.startService();
//   }
//
//   static Future<void> _onStart() async {
//     // Jalankan pembersihan setiap 1 jam
//     while (true) {
//       await Future.delayed(const Duration(hours: 1));
//       await _cleanupExpiredCartItems();
//     }
//   }
//
//   static Future<void> _cleanupExpiredCartItems() async {
//     try {
//       final response = await http.get(
//         Uri.parse('http://localhost:3000/cleanup-expired-cart-items'),
//       );
//       print('Cleanup response: ${response.body}');
//     } catch (e) {
//       print('Cleanup error: $e');
//     }
//   }
// }