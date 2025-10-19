import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:program/core/services/api_service.dart';
import 'package:program/fitur/live_shopping/presentation/providers/live_shopping_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SetupLiveScreen extends ConsumerStatefulWidget {
  const SetupLiveScreen({super.key});

  @override
  ConsumerState<SetupLiveScreen> createState() => _SetupLiveScreenState();
}

class _SetupLiveScreenState extends ConsumerState<SetupLiveScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isCreatingRoom = false;
  bool _hasNavigated = false; // Untuk mencegah multiple navigation

  Future<bool> _handlePermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    if (cameraGranted && micGranted) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin kamera dan mikrofon dibutuhkan.')),
      );
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    debugPrint("=== SETUP LIVE SCREEN INIT ===");

    // Reset state saat screen dimuat
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint("Resetting live shopping state...");
      try {
        await ref.read(liveShoppingProvider.notifier).resetState();
        debugPrint("State reset completed");
      } catch (e) {
        debugPrint("Error resetting state: $e");
      }
    });
  }

  // FUNGSI BARU: Manual navigation dengan timeout
  void _navigateAfterConnection() async {
    if (_hasNavigated) return;

    debugPrint("Starting manual navigation check...");

    // Tunggu maksimal 10 detik untuk connection
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));

      final currentState = ref.read(liveShoppingProvider);
      debugPrint("Check $i - isConnected: ${currentState.isConnected}, role: ${currentState.currentRole}");

      if (currentState.isConnected && !currentState.isJoining) {
        debugPrint("Connection established, navigating...");
        _performNavigation(currentState.currentRole);
        break;
      }

      if (currentState.error != null) {
        debugPrint("Error detected, stopping navigation check");
        break;
      }
    }

    // Timeout reached
    if (!_hasNavigated) {
      debugPrint("Navigation timeout reached");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koneksi timeout. Silakan coba lagi.')),
        );
        setState(() {
          _isCreatingRoom = false;
        });
      }
    }
  }

  void _performNavigation(String? role) {
    if (_hasNavigated || !mounted) return;

    _hasNavigated = true;
    debugPrint("Performing navigation for role: $role");

    switch (role) {
      case 'broadcaster':
        context.push('/jastiper-live');
        break;
      case 'viewer-realtime':
        context.push('/viewer-live');
        break;
      default:
        debugPrint("Unknown role for navigation: $role");
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen untuk error handling dan navigation
    ref.listen<LiveShoppingState>(liveShoppingProvider, (previous, next) {
      debugPrint("State change - isConnected: ${next.isConnected}, isJoining: ${next.isJoining}, role: ${next.currentRole}, error: ${next.error}");

      // Handle error
      if (next.error != null && previous?.error != next.error) {
        debugPrint("Error detected: ${next.error}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${next.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        // Reset flags on error
        setState(() {
          _isCreatingRoom = false;
          _hasNavigated = false;
        });
      }

      // Traditional navigation sebagai backup
      if (next.isConnected && !next.isJoining && !_hasNavigated) {
        debugPrint("Traditional navigation triggered");
        _performNavigation(next.currentRole);
      }
    });

    final user = FirebaseAuth.instance.currentUser;
    final liveState = ref.watch(liveShoppingProvider);
    final liveSessionsAsync = ref.watch(liveSessionsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Mulai & Tonton Siaran Langsung")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Debug Info - DICOMMENT UNTUK PRODUCTION
            // if (kDebugMode) ...[
            //   Container(
            //     padding: const EdgeInsets.all(8),
            //     margin: const EdgeInsets.only(bottom: 16),
            //     decoration: BoxDecoration(
            //       border: Border.all(color: Colors.grey),
            //       borderRadius: BorderRadius.circular(4),
            //     ),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         const Text("DEBUG INFO:", style: TextStyle(fontWeight: FontWeight.bold)),
            //         Text("isLoading: ${liveState.isLoading}"),
            //         Text("isConnected: ${liveState.isConnected}"),
            //         Text("isJoining: ${liveState.isJoining}"),
            //         Text("currentRole: ${liveState.currentRole}"),
            //         Text("roomId: ${liveState.roomId}"),
            //         Text("error: ${liveState.error ?? 'none'}"),
            //         Text("_hasNavigated: $_hasNavigated"),
            //         Text("_isCreatingRoom: $_isCreatingRoom"),
            //       ],
            //     ),
            //   ),
            // ],

            // Section: Mulai Siaran
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mulai Siaran Anda",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: "Judul Live",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: "Harga Barang Awal",
                        hintText: "Contoh: 150000",
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),

                    // Tombol Start Live
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: (liveState.isLoading || liveState.isJoining || _isCreatingRoom)
                          ? ElevatedButton(
                        onPressed: null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isCreatingRoom ? "Membuat room..." :
                              liveState.isJoining ? "Bergabung ke room..." : "Loading...",
                            ),
                          ],
                        ),
                      )
                          : ElevatedButton.icon(
                        onPressed: () async {
                          if (_isCreatingRoom || liveState.isJoining || liveState.isLoading) {
                            debugPrint("Button press ignored - already in progress");
                            return;
                          }

                          bool permissionsGranted = await _handlePermissions();
                          if (!permissionsGranted || user == null) return;

                          debugPrint("=== STARTING LIVE CREATION ===");
                          setState(() {
                            _isCreatingRoom = true;
                            _hasNavigated = false;
                          });

                          try {
                            final title = _titleController.text.isNotEmpty ? _titleController.text : "Live Jastip!";
                            final price = double.tryParse(_priceController.text) ?? 0.0;

                            debugPrint("Creating room with title: $title");
                            final newRoomId = await _apiService.createRoom(title: title);
                            debugPrint("Room created with ID: $newRoomId");

                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .get();
                            final username = userDoc.data()?['username'] as String? ?? 'Jastiper Tanpa Nama';

                            // PERBAIKAN: Simpan ke Firestore SEBELUM join
                            // Gunakan kombinasi document ID yang unik tapi bisa dicari
                            debugPrint("Saving live session to Firestore...");
                            await FirebaseFirestore.instance
                                .collection('live_sessions')
                                .doc(user.uid) // Document ID tetap userId untuk mudah cleanup
                                .set({
                              'hostId': user.uid,          // UID Firebase user (untuk transaksi & chat)
                              'hostName': username,         // Nama jastiper
                              'roomId': newRoomId,         // Room ID dari 100ms (untuk query)
                              'title': title,              // Judul live
                              'status': 'ongoing',         // Status live
                              'itemPrice': price,          // Harga awal
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            debugPrint("Firestore setup completed");

                            debugPrint("Attempting to join room as broadcaster...");

                            // Start manual navigation check
                            _navigateAfterConnection();

                            // Join room
                            await ref.read(liveShoppingProvider.notifier).joinRoom(
                              roomId: newRoomId,
                              userId: user.uid,
                              username: username,
                              role: "broadcaster",
                              liveTitle: title,
                              initialPrice: price,
                            );

                            debugPrint("Join room request completed");

                          } catch (e) {
                            debugPrint("Error in live creation: $e");
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error creating live: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isCreatingRoom = false;
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.live_tv),
                        label: const Text("Mulai Siaran"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section: Siaran Berlangsung
            Text(
              "Siaran Berlangsung",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // List Live Sessions - DIPERBAIKI AGAR BISA SCROLL
            Expanded(
              child: Card(
                elevation: 2,
                child: liveSessionsAsync.when(
                  data: (snapshot) {
                    debugPrint("Live sessions snapshot: ${snapshot.docs.length} documents");
                    for (var doc in snapshot.docs) {
                      debugPrint("Session: ${doc.id} - ${doc.data()}");
                    }

                    if (snapshot.docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.live_tv,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Belum ada siaran langsung",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Mulai siaran pertama Anda atau tunggu jastiper lain untuk memulai live.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Filter sessions yang bukan milik user sendiri
                    final otherSessions = snapshot.docs.where((doc) {
                      final session = doc.data() as Map<String, dynamic>;
                      return session['hostId'] != user?.uid;
                    }).toList();

                    if (otherSessions.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.live_tv,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Belum ada siaran dari jastiper lain",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: otherSessions.length,
                      itemBuilder: (context, index) {
                        final sessionDoc = otherSessions[index];
                        final session = sessionDoc.data() as Map<String, dynamic>;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          elevation: 1,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12.0),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.live_tv,
                                color: Colors.red,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              session['title'] ?? 'Live Shopping',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('oleh ${session['hostName'] ?? 'Jastiper'}'),
                                const SizedBox(height: 4),
                                if (session['itemPrice'] != null && session['itemPrice'] > 0)
                                  Text(
                                    'Harga: Rp ${(session['itemPrice'] as num).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () async {
                              // Prevent join if already in progress
                              if (liveState.isJoining || liveState.isLoading) {
                                debugPrint("Join ignored - already in progress");
                                return;
                              }

                              if (user != null) {
                                debugPrint("=== JOINING AS VIEWER ===");
                                setState(() {
                                  _hasNavigated = false;
                                });

                                try {
                                  final userDoc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .get();
                                  final username = userDoc.data()?['username'] as String? ?? 'Penonton';
                                  final initialPrice = (session['itemPrice'] as num?)?.toDouble() ?? 0.0;

                                  debugPrint("Attempting to join as viewer...");

                                  // Start manual navigation check
                                  _navigateAfterConnection();

                                  await ref.read(liveShoppingProvider.notifier).joinRoom(
                                    roomId: session['roomId'],
                                    userId: user.uid,
                                    username: username,
                                    role: "viewer-realtime",
                                    initialPrice: initialPrice,
                                  );

                                } catch (e) {
                                  debugPrint("Error joining as viewer: $e");
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error joining live: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Gagal memuat daftar live",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Error: $err",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Manual Reset Button - DICOMMENT UNTUK PRODUCTION
            // if (kDebugMode) ...[
            //   const SizedBox(height: 16),
            //   ElevatedButton(
            //     onPressed: () async {
            //       debugPrint("=== MANUAL RESET TRIGGERED ===");
            //       setState(() {
            //         _hasNavigated = false;
            //         _isCreatingRoom = false;
            //       });
            //       try {
            //         await ref.read(liveShoppingProvider.notifier).resetState();
            //         if (mounted) {
            //           ScaffoldMessenger.of(context).showSnackBar(
            //             const SnackBar(content: Text("State reset completed")),
            //           );
            //         }
            //       } catch (e) {
            //         debugPrint("Error in manual reset: $e");
            //       }
            //     },
            //     style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            //     child: const Text("RESET STATE (DEBUG)"),
            //   ),
            // ],
          ],
        ),
      ),
    );
  }
}