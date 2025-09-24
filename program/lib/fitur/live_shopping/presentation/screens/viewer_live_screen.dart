import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:program/fitur/live_shopping/presentation/providers/live_shopping_provider.dart';
import 'package:program/fitur/live_shopping/presentation/widgets/live_chat_widgets.dart';

class ViewerLiveScreen extends ConsumerWidget {

  const ViewerLiveScreen({
    super.key,
  });

  // Fungsi placeholder untuk menampilkan form pembelian di langkah selanjutnya
  void _showPurchaseForm(BuildContext context, WidgetRef ref) {
    final liveState = ref.read(liveShoppingProvider);
    final price = liveState.currentItemPrice;
    final hostPeer = liveState.hostPeer;

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Jastiper belum menetapkan harga barang.")),
      );
      return;
    }

    if (hostPeer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data Jastiper tidak ditemukan.")),
      );
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
                    decoration: const InputDecoration(labelText: 'Nama Barang'),
                    validator: (value) => (value == null || value.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Deskripsi (Warna, Ukuran, dll)'),
                    validator: (value) => (value == null || value.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  TextFormField(
                    controller: qtyController,
                    decoration: const InputDecoration(labelText: 'Jumlah (Qty)'),
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
            TextButton(child: const Text("Batal"), onPressed: () => Navigator.of(ctx).pop()),
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

                    Navigator.of(ctx).pop(); // Tutup form
                    _showSuccessDialog(context); // Tampilkan dialog sukses

                  } catch (e) {
                    if (context.mounted) {
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
              Text("Transaksi Berhasil!", style: TextStyle(color: Colors.white, fontSize: 20)),
            ],
          ),
        ),
      ),
    );
    // Tutup dialog setelah 3 detik
    Future.delayed(const Duration(seconds: 3), () {
      if(context.mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }


  // Fungsi untuk menampilkan panel aksi penonton (popup)
  void _showViewerActionPanel(BuildContext context, WidgetRef ref) {
    final hostPeer = ref.read(liveShoppingProvider).hostPeer;
    if (hostPeer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mendapatkan data Jastiper. Coba lagi sebentar."))
      );
      return;
    }
    final hostId = hostPeer.peerId;
    final hostName = hostPeer.name;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                title: Text("Kirim Pesan ke ${hostName}"),
                onTap: () {
                  // Navigasi ke halaman chat pribadi dengan Jastiper
                  Navigator.of(ctx).pop();
                  // Pastikan GoRouter Anda memiliki rute untuk '/chat/:userId'
                  context.push('/chat/$hostId', extra: hostName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dengarkan status `isLiveEnded` dari provider
    ref.listen<LiveShoppingState>(liveShoppingProvider, (previous, next) {
      if (next.isLiveEnded && (previous?.isLiveEnded == false || previous == null)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Siaran langsung telah berakhir.")),
          );
          if (context.canPop()) {
            context.pop();
          }
        }
      }
    });

    final hostVideoTrack =
    ref.watch(liveShoppingProvider.select((state) => state.remoteVideoTrack));
    final hostName = ref.watch(liveShoppingProvider.select((state) => state.hostPeer?.name ?? 'Live'));

    void handleLeave() async {
      try {
        // PERBAIKAN: Tambahkan try-catch dan await untuk leaveRoom
        await ref.read(liveShoppingProvider.notifier).leaveRoom();

        // PERBAIKAN: Pastikan context masih mounted sebelum navigasi
        if (context.mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/live');
          }
        }
      } catch (e) {
        // PERBAIKAN: Handle error saat leave room
        debugPrint("Error saat keluar dari room: $e");
        if (context.mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/live');
          }
        }
      }
    }

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
            onPressed: handleLeave,
          ),
          title: Text("Menonton Live $hostName"),
        ),
        body: Stack(
          children: [
            // Latar belakang video
            if (hostVideoTrack != null)
              HMSVideoView(track: hostVideoTrack)
            else
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Menunggu siaran dari Jastiper..."),
                  ],
                ),
              ),

            // Overlay Chat
            LiveChatWidget(
              onActionButtonPressed: () => _showViewerActionPanel(context, ref),
              isJastiper: false,
            ),

          ],
        ),
      ),
    );
  }
}
