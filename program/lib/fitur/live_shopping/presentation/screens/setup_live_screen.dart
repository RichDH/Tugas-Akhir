import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:program/core/services/api_service.dart'; // Import ApiService
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
  final ApiService _apiService = ApiService();
  bool _isCreatingRoom = false;

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
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LiveShoppingState>(liveShoppingProvider, (previous, next) {
      if (next.isConnected && (previous?.isConnected == false || previous == null)) {
        if (mounted) {
          if (next.currentRole == 'broadcaster') {
            context.push('/jastiper-live');
          } else {
            context.push('/viewer-live');
          }
        }
      }
      if (next.error != null && previous?.error != next.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Terjadi kesalahan: ${next.error}')),
          );
        }
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
            Text("Mulai Siaran Anda", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Judul Live"),
            ),
            const SizedBox(height: 20),
            (liveState.isLoading && liveState.currentRole == 'broadcaster') || _isCreatingRoom
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: () async {
                bool permissionsGranted = await _handlePermissions();
                if (permissionsGranted && user != null) {
                  setState(() {
                    _isCreatingRoom = true;
                  });

                  try {
                    final title = _titleController.text.isNotEmpty ? _titleController.text : "Live Jastip!";
                    // 1. Buat room baru melalui API
                    final newRoomId = await _apiService.createRoom(title: title);

                    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                    final username = userDoc.data()?['username'] as String? ?? 'Jastiper Tanpa Nama';

                    // 2. Gunakan roomId yang baru untuk join
                    ref.read(liveShoppingProvider.notifier).joinRoom(
                      roomId: newRoomId, // <-- MENGGUNAKAN ROOM ID BARU
                      userId: user.uid,
                      username: username,
                      role: "broadcaster",
                      liveTitle: title,
                    );

                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  } finally {
                    if(mounted) {
                      setState(() {
                        _isCreatingRoom = false;
                      });
                    }
                  }
                }
              },
              child: const Text("Mulai Siaran"),
            ),
            const Divider(height: 40, thickness: 2),
            Text("Siaran Berlangsung", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(
              child: liveSessionsAsync.when(
                data: (snapshot) {
                  if (snapshot.docs.isEmpty) {
                    return const Center(child: Text("Belum ada siaran langsung."));
                  }
                  return ListView.builder(
                    itemCount: snapshot.docs.length,
                    itemBuilder: (context, index) {
                      final session = snapshot.docs[index].data() as Map<String, dynamic>;
                      if (session['hostId'] == user?.uid) {
                        return const SizedBox.shrink();
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          title: Text(session['title'] ?? 'Live Shopping'),
                          subtitle: Text('oleh ${session['hostName'] ?? ''}'),
                          leading: const Icon(Icons.live_tv, color: Colors.red),
                          onTap: () async {
                            if (user != null) {
                              final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                              final username = userDoc.data()?['username'] as String? ?? 'Penonton';
                              ref.read(liveShoppingProvider.notifier).joinRoom(
                                roomId: session['roomId'],
                                userId: user.uid,
                                username: username,
                                role: "viewer-realtime",
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text("Gagal memuat daftar live. Error: $err")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}