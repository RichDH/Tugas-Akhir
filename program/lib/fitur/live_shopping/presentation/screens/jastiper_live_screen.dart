import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:program/fitur/live_shopping/presentation/providers/live_shopping_provider.dart';
import 'package:program/fitur/live_shopping/presentation/widgets/live_chat_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class JastiperLiveScreen extends ConsumerStatefulWidget {
  const JastiperLiveScreen({super.key});

  @override
  ConsumerState<JastiperLiveScreen> createState() => _JastiperLiveScreenState();
}

class _JastiperLiveScreenState extends ConsumerState<JastiperLiveScreen>
    with WidgetsBindingObserver {
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    // Monitor app lifecycle untuk handle app termination
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("App lifecycle state changed: $state");

    // Handle app termination/backgrounding
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      debugPrint("App going to background/terminating - performing cleanup");
      _performCleanupOnly();
    }
  }

  // FUNGSI BARU: Cleanup tanpa navigation (untuk app termination)
  void _performCleanupOnly() async {
    if (_isLeaving) return;
    _isLeaving = true;

    try {
      await ref.read(liveShoppingProvider.notifier).leaveRoom();
      debugPrint("Cleanup completed due to app lifecycle change");
    } catch (e) {
      debugPrint("Error during cleanup: $e");
    }
  }

  // FUNGSI YANG DIPERBAIKI: Handle leave dengan better error handling
  void handleLeave() async {
    debugPrint("=== JASTIPER HANDLE LEAVE TRIGGERED ===");

    if (_isLeaving) {
      debugPrint("Already leaving, ignoring duplicate call");
      return;
    }
    _isLeaving = true;
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      debugPrint("Starting leave room process...");
      await ref.read(liveShoppingProvider.notifier).leaveRoom().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint("Leave room timed out - forcing navigation");
        },
      );

      debugPrint("Leave room completed, navigating...");

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Navigate with error handling
      if (mounted) {
        try {
          context.go('/feed');
        } catch (e) {
          debugPrint("Navigation error: $e");
          // Fallback navigation
          Navigator.of(context).pushNamedAndRemoveUntil('/feed', (route) => false);
        }
      }

    } catch (e) {
      debugPrint("Error during leave process: $e");

      // Close loading dialog if still open
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending live: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        // Force navigation after showing error
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            try {
              context.go('/feed');
            } catch (navError) {
              debugPrint("Force navigation error: $navError");
            }
          }
        });
      }
    } finally {
      _isLeaving = false;
    }
  }

  // FUNGSI BARU: Untuk menampilkan dialog detail pesanan
  void _showOrderDetailDialog(BuildContext context, WidgetRef ref, String jastiperId, String orderId, Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Detail Pesanan"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pemesan: ${orderData['buyerName'] ?? 'Anonim'}"),
                const SizedBox(height: 8),
                Text("Barang: ${orderData['itemName'] ?? 'Tidak ada nama'}"),
                const SizedBox(height: 8),
                Text("Deskripsi: ${orderData['description'] ?? '-'}"),
                const SizedBox(height: 8),
                Text("Jumlah: ${orderData['quantity'] ?? 1}"),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Tolak", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                try {
                  await ref.read(liveShoppingProvider.notifier).processOrder(
                    sessionId: jastiperId,
                    orderId: orderId,
                    newStatus: 'rejected',
                  );
                  Navigator.of(ctx).pop();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
            ),
            ElevatedButton(
              child: const Text("Terima"),
              onPressed: () async {
                try {
                  await ref.read(liveShoppingProvider.notifier).processOrder(
                    sessionId: jastiperId,
                    orderId: orderId,
                    newStatus: 'accepted',
                  );
                  Navigator.of(ctx).pop();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // FUNGSI YANG SUDAH ADA: Untuk menampilkan panel aksi dengan tab
  void _showJastiperActionPanel(BuildContext context, WidgetRef ref) {
    final currentLiveState = ref.read(liveShoppingProvider);
    final priceController = TextEditingController(
        text: currentLiveState.currentItemPrice > 0 ? currentLiveState.currentItemPrice.toStringAsFixed(0) : ''
    );
    final jastiperId = FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DefaultTabController(
          length: 3,
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16, right: 16, top: 16,
              ),
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.shopping_bag), text: "Pesanan"),
                      Tab(icon: Icon(Icons.chat_bubble), text: "Pesan"),
                      Tab(icon: Icon(Icons.settings), text: "Pengaturan"),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Pesanan Masuk
                        if (jastiperId != null)
                          Consumer(
                            builder: (context, ref, child) {
                              final ordersAsync = ref.watch(liveOrdersStreamProvider(jastiperId));
                              return ordersAsync.when(
                                data: (snapshot) {
                                  if (snapshot.docs.isEmpty) {
                                    return const Center(child: Text("Belum ada pesanan masuk."));
                                  }
                                  return ListView.builder(
                                    itemCount: snapshot.docs.length,
                                    itemBuilder: (context, index) {
                                      final orderDoc = snapshot.docs[index];
                                      final order = orderDoc.data() as Map<String, dynamic>;
                                      return Card(
                                        child: ListTile(
                                          title: Text(order['itemName'] ?? 'Barang'),
                                          subtitle: Text('oleh ${order['buyerName'] ?? 'Anonim'} (Qty: ${order['quantity']})'),
                                          trailing: const Icon(Icons.chevron_right),
                                          onTap: () {
                                            _showOrderDetailDialog(context, ref, jastiperId, orderDoc.id, order);
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, s) => const Center(child: Text("Gagal memuat pesanan.")),
                              );
                            },
                          )
                        else
                          const Center(child: Text("Tidak dapat memuat pesanan.")),

                        // Tab 2: Pesan Pribadi (Placeholder)
                        const Center(
                          child: Text("Fitur Pesan Pribadi akan segera hadir.", style: TextStyle(color: Colors.grey)),
                        ),

                        // Tab 3: Pengaturan Live
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text("Ubah Harga Barang Saat Ini"),
                            const SizedBox(height: 8),
                            TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Harga Baru', prefixText: 'Rp '),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                final price = double.tryParse(priceController.text);
                                if (price != null && price >= 0) {
                                  ref.read(liveShoppingProvider.notifier).updateAndBroadcastPrice(price);
                                  Navigator.of(ctx).pop();
                                }
                              },
                              child: const Text("Perbarui Harga"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen untuk HMS errors yang bisa cause crash
    ref.listen<LiveShoppingState>(liveShoppingProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        debugPrint("HMS Error detected in JastiperLiveScreen: ${next.error}");

        // Show error dan handle gracefully
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Live error: ${next.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );

          // Auto-leave jika error critical
          if (next.error!.contains('1003') ||
              next.error!.contains('2003') ||
              next.error!.contains('4005')) {
            debugPrint("Critical error detected, auto-leaving...");
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && !_isLeaving) {
                handleLeave();
              }
            });
          }
        }
      }
    });

    final HMSVideoTrack? localVideoTrack =
    ref.watch(liveShoppingProvider.select((state) => state.localVideoTrack));

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        handleLeave();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, color: Colors.white),
            ),
            onPressed: _isLeaving ? null : handleLeave, // Disable jika sedang leaving
          ),
        ),
        body: Stack(
          children: [
            // Latar belakang video
            if (localVideoTrack != null)
              HMSVideoView(track: localVideoTrack, matchParent: true)
            else
              const Center(child: CircularProgressIndicator()),

            // Overlay Chat
            LiveChatWidget(
              onActionButtonPressed: () => _showJastiperActionPanel(context, ref),
              isJastiper: true,
            ),

            // Loading overlay saat leaving
            if (_isLeaving)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        "Mengakhiri siaran...",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}