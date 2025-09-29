import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:program/fitur/live_shopping/presentation/providers/live_shopping_provider.dart';
import 'package:program/fitur/live_shopping/presentation/widgets/live_chat_widgets.dart';

class ViewerLiveScreen extends ConsumerStatefulWidget {
  const ViewerLiveScreen({super.key});

  @override
  ConsumerState<ViewerLiveScreen> createState() => _ViewerLiveScreenState();
}

class _ViewerLiveScreenState extends ConsumerState<ViewerLiveScreen> {
  bool _isLeavingRoom = false;
  bool _hasShownEndDialog = false;
  bool _isNavigating = false; // TAMBAHAN: Flag untuk mencegah multiple navigation

  // Fungsi untuk menampilkan form pembelian
  void _showPurchaseForm(BuildContext context, WidgetRef ref) {
    final liveState = ref.read(liveShoppingProvider);
    final price = liveState.currentItemPrice;
    final hostPeer = liveState.hostPeer;

    if (price <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Jastiper belum menetapkan harga barang.")),
        );
      }
      return;
    }

    if (hostPeer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data Jastiper tidak ditemukan.")),
        );
      }
      return;
    }

    final itemNameController = TextEditingController();
    final descriptionController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Form Pembelian"),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: itemNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Barang',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi (Warna, Ukuran, dll)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah (Qty)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Wajib diisi';
                      if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Jumlah tidak valid';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Batal"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              child: Text("Bayar Rp ${price.toStringAsFixed(0)}"),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await ref.read(liveShoppingProvider.notifier).placeOrder(
                      sessionId: hostPeer.peerId,
                      itemName: itemNameController.text,
                      description: descriptionController.text,
                      quantity: int.parse(qtyController.text),
                      price: price,
                    );

                    if (mounted) {
                      Navigator.of(ctx).pop(); // Tutup form
                      _showSuccessDialog(context); // Tampilkan dialog sukses
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              SizedBox(height: 16),
              Text(
                "Transaksi Berhasil!",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );

    // Tutup dialog setelah 3 detik
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  // Fungsi untuk menampilkan panel aksi penonton (dikembalikan ke bentuk asli)
  void _showViewerActionPanel(BuildContext context, WidgetRef ref) {
    final hostPeer = ref.read(liveShoppingProvider).hostPeer;
    if (hostPeer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mendapatkan data Jastiper. Coba lagi sebentar.")),
        );
      }
      return;
    }

    final hostId = hostPeer.peerId;
    final hostName = hostPeer.name;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text("Isi Form Pembelian"),
                onTap: () {
                  Navigator.of(ctx).pop(); // Tutup bottom sheet
                  _showPurchaseForm(context, ref); // Buka dialog form
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text("Kirim Pesan ke $hostName"),
                onTap: () {
                  // Navigasi langsung ke halaman chat pribadi dengan Jastiper
                  Navigator.of(ctx).pop();
                  context.push('/chat/$hostId', extra: hostName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // PERBAIKAN: Enhanced leave dengan timeout dan cleanup
  void handleLeave() async {
    if (_isLeavingRoom || _isNavigating) return;

    setState(() {
      _isLeavingRoom = true;
      _isNavigating = true;
    });

    try {
      // PERBAIKAN: Tutup dialog/bottomsheet yang mungkin terbuka
      try {
        Navigator.of(context).popUntil((route) => route.settings.name == '/viewer-live' || route.isFirst);
      } catch (e) {
        debugPrint("Error closing overlays: $e");
      }

      // PERBAIKAN: Tambahkan timeout untuk leaveRoom
      await ref.read(liveShoppingProvider.notifier).leaveRoom().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint("LeaveRoom timed out, forcing navigation");
        },
      );

    } catch (e) {
      debugPrint("Error saat keluar dari room: $e");
    }

    // PERBAIKAN: Navigation dengan multiple fallback
    if (mounted) {
      try {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/live');
        }
      } catch (e) {
        debugPrint("Navigation error: $e");
        // Fallback navigation
        try {
          Navigator.of(context).pushNamedAndRemoveUntil('/live', (route) => false);
        } catch (e2) {
          debugPrint("Fallback navigation error: $e2");
        }
      }
    }
  }

  // PERBAIKAN: Simplified live ended dialog dengan shorter timeout
  void _showLiveEndedDialog() {
    if (_hasShownEndDialog || !mounted || _isNavigating) return;

    _hasShownEndDialog = true;

    // PERBAIKAN: Tutup overlay yang ada terlebih dahulu
    try {
      Navigator.of(context).popUntil((route) => route.settings.name == '/viewer-live' || route.isFirst);
    } catch (e) {
      debugPrint("Error closing overlays before dialog: $e");
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || _isNavigating) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.live_tv, color: Colors.red),
              SizedBox(width: 8),
              Text("Live Berakhir"),
            ],
          ),
          content: const Text(
            "Siaran langsung telah berakhir oleh Jastiper. Anda akan diarahkan kembali ke halaman utama.",
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                handleLeave();
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    });

    // PERBAIKAN: Auto close lebih cepat (3 detik)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isNavigating) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (e) {
          debugPrint("Error closing auto dialog: $e");
        }
        handleLeave();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // PERBAIKAN: Simplified listener dengan skip untuk navigating state
    ref.listen<LiveShoppingState>(liveShoppingProvider, (previous, next) {
      // Skip jika sedang navigating
      if (_isNavigating) return;

      // PRIORITAS TERTINGGI: Handle live ended terlebih dahulu
      if (next.isLiveEnded && (previous?.isLiveEnded == false || previous == null)) {
        debugPrint("Live ended detected in viewer - immediate action");
        if (!_hasShownEndDialog) {
          _showLiveEndedDialog();
        }
        return; // Return early untuk mencegah error handling
      }

      // Handle errors hanya jika live belum ended
      if (next.error != null && previous?.error != next.error && !next.isLiveEnded) {
        debugPrint("Error detected: ${next.error}");

        // PERBAIKAN: Filter dan handle berbagai tipe error
        final error = next.error!.toLowerCase();

        // Jika mengandung disconnect keywords, treat sebagai live ended
        if (error.contains("force_disconnect") ||
            error.contains("forced_disconnect") ||
            error.contains("disconnect") ||
            error.contains("peer left") ||
            error.contains("connection") ||
            error.contains("ended")) {
          debugPrint("Connection-related error detected, treating as live ended");
          if (!_hasShownEndDialog) {
            _showLiveEndedDialog();
          }
          return;
        }

        // Show error untuk error lainnya yang bukan connection related
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Terjadi kesalahan: ${next.error}'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Keluar',
                onPressed: handleLeave,
              ),
            ),
          );
        }
      }
    });

    final hostVideoTrack =
    ref.watch(liveShoppingProvider.select((state) => state.remoteVideoTrack));
    final hostName = ref.watch(liveShoppingProvider.select((state) => state.hostPeer?.name ?? 'Live'));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        handleLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isLeavingRoom ? null : handleLeave, // Disable jika sedang leaving
          ),
          title: Text("Menonton Live $hostName"),
          backgroundColor: Colors.black.withOpacity(0.7),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          children: [
            // Latar belakang video
            if (hostVideoTrack != null && !_isLeavingRoom)
              HMSVideoView(track: hostVideoTrack)
            else
              Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        "Menunggu siaran dari Jastiper...",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

            // Overlay Chat
            if (!_isLeavingRoom)
              LiveChatWidget(
                onActionButtonPressed: () => _showViewerActionPanel(context, ref),
                isJastiper: false,
              ),

            // Loading overlay saat leaving
            if (_isLeavingRoom)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        "Keluar dari live...",
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