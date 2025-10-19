import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:intl/intl.dart';
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

  // ✅ PERBAIKAN SEDERHANA: Fungsi untuk mendapatkan data jastiper dengan benar
  Future<Map<String, String?>> _getJastiperData() async {
    try {
      final liveState = ref.read(liveShoppingProvider);
      final roomId = liveState.roomId; // Ambil roomId dari state provider

      debugPrint("=== GETTING JASTIPER DATA ===");
      debugPrint("Room ID dari state: $roomId");

      if (roomId == null) {
        debugPrint("❌ Room ID tidak ditemukan di state");
        return {'uid': null, 'name': null};
      }

      // ✅ STRATEGI 1: Query berdasarkan roomId field di Firestore
      final liveSessionQuery = await FirebaseFirestore.instance
          .collection('live_sessions')
          .where('roomId', isEqualTo: roomId)
          .where('status', isEqualTo: 'ongoing')
          .limit(1)
          .get();

      if (liveSessionQuery.docs.isNotEmpty) {
        final liveDoc = liveSessionQuery.docs.first;
        final jastiperUid = liveDoc.data()['hostId'] as String?;
        final jastiperName = liveDoc.data()['hostName'] as String?;

        debugPrint("✅ BERHASIL - Query berdasarkan roomId field");
        debugPrint("Jastiper UID: $jastiperUid");
        debugPrint("Jastiper Name: $jastiperName");

        return {
          'uid': jastiperUid,
          'name': jastiperName,
        };
      }

      // ✅ STRATEGI 2: Jika tidak ditemukan, coba query semua live sessions ongoing
      debugPrint("❌ Tidak ditemukan via roomId query, mencoba strategi alternatif...");

      final allLiveQuery = await FirebaseFirestore.instance
          .collection('live_sessions')
          .where('status', isEqualTo: 'ongoing')
          .get();

      debugPrint("Ditemukan ${allLiveQuery.docs.length} live sessions ongoing");

      for (var doc in allLiveQuery.docs) {
        final data = doc.data();
        final docRoomId = data['roomId'] as String?;

        debugPrint("Checking doc ${doc.id}: roomId = $docRoomId");

        if (docRoomId == roomId) {
          final jastiperUid = data['hostId'] as String?;
          final jastiperName = data['hostName'] as String?;

          debugPrint("✅ BERHASIL - Ditemukan via scan dokumen");
          debugPrint("Jastiper UID: $jastiperUid");

          return {
            'uid': jastiperUid,
            'name': jastiperName,
          };
        }
      }

      debugPrint("❌ Jastiper data tidak ditemukan di semua strategi");
      return {'uid': null, 'name': null};

    } catch (e) {
      debugPrint("❌ ERROR saat mengambil data jastiper: $e");
      return {'uid': null, 'name': null};
    }
  }

  // Fungsi untuk menampilkan form pembelian
  void _showPurchaseForm(BuildContext context, WidgetRef ref) async {
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

    // ✅ PERBAIKAN: Gunakan fungsi yang sudah diperbaiki
    final jastiperData = await _getJastiperData();
    final jastiperUid = jastiperData['uid'];
    final jastiperName = jastiperData['name'];

    if (jastiperUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data jastiper tidak ditemukan. Silakan coba lagi.")),
        );
      }
      return;
    }

    final itemNameController = TextEditingController();
    final descriptionController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Beli dari ${jastiperName ?? 'Jastiper'}"),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info jastiper
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Jastiper: ${jastiperName ?? 'Unknown'}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    final qty = int.parse(qtyController.text);
                    final totalAmount = price * qty;

                    // Cek login user
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Anda harus login terlebih dahulu.")),
                        );
                      }
                      return;
                    }

                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();

                    final userBalance = (userDoc.data()?['saldo'] as num?)?.toDouble() ?? 0.0;

                    if (userBalance < totalAmount) {
                      Navigator.of(ctx).pop(); // Tutup form dulu
                      _showInsufficientBalanceDialog(totalAmount, userBalance);
                      return;
                    }

                    // Potong saldo user (escrow)
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'saldo': FieldValue.increment(-totalAmount),
                    });

                    // ✅ Buat transaksi dengan data jastiper yang sudah dipastikan benar
                    await FirebaseFirestore.instance.collection('transactions').add({
                      'postId': liveState.roomId, // roomId sebagai identifier sumber transaksi
                      'buyerId': user.uid,
                      'sellerId': jastiperUid, // ✅ UID jastiper yang sudah dipastikan benar
                      'amount': totalAmount,
                      'status': 'pending',
                      'createdAt': FieldValue.serverTimestamp(),
                      'buyerAddress': (userDoc.data()?['alamat'] as String?)?.trim().isNotEmpty == true
                          ? (userDoc.data()?['alamat'] as String).trim()
                          : 'Alamat tidak tersedia',
                      'items': [
                        {
                          'postId': liveState.roomId,
                          'title': itemNameController.text.trim(),
                          'price': price,
                          'quantity': qty,
                          'imageUrl': '',
                        }
                      ],
                      'isEscrow': true,
                      'escrowAmount': totalAmount,
                      'isAcceptedBySeller': false,
                      'type': 'live_buy',
                      'liveDescription': descriptionController.text.trim(),
                      'liveMeta': {
                        'hostName': jastiperName,
                        'roomId': liveState.roomId,
                        'unitPrice': price,
                        'source': 'live_shopping',
                      },
                    });

                    if (mounted) {
                      Navigator.of(ctx).pop(); // tutup form
                      _showSuccessDialog(context); // tampilkan success overlay 3 detik
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal membuat transaksi: $e')),
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

  void _showInsufficientBalanceDialog(double totalAmount, double userBalance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saldo Tidak Mencukupi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Saldo Anda: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(userBalance)}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Total yang dibutuhkan: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Kurang: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount - userBalance)}',
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/top-up');
            },
            child: const Text('Top Up'),
          ),
        ],
      ),
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

  // ✅ PERBAIKAN: Fungsi untuk menampilkan panel aksi penonton
  void _showViewerActionPanel(BuildContext context, WidgetRef ref) async {
    final hostPeer = ref.read(liveShoppingProvider).hostPeer;
    if (hostPeer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mendapatkan data Jastiper. Coba lagi sebentar.")),
        );
      }
      return;
    }

    // ✅ Ambil data jastiper dengan fungsi yang sudah diperbaiki
    final jastiperData = await _getJastiperData();
    final jastiperUid = jastiperData['uid'];
    final jastiperName = jastiperData['name'] ?? hostPeer.name ?? 'Jastiper';

    if (jastiperUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data jastiper tidak ditemukan. Silakan coba lagi.")),
        );
      }
      return;
    }

    if (!mounted) return;

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
                title: Text("Kirim Pesan ke $jastiperName"),
                onTap: () async {
                  Navigator.of(ctx).pop();

                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Anda harus login untuk chat')),
                    );
                    return;
                  }

                  try {
                    // Buat room ID deterministik
                    final users = [currentUser.uid, jastiperUid]..sort();
                    final roomId = users.join('_');

                    // Cek/buat chat room
                    final roomDoc = await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(roomId)
                        .get();

                    if (!roomDoc.exists) {
                      await FirebaseFirestore.instance.collection('chats').doc(roomId).set({
                        'type': 'direct',
                        'users': [currentUser.uid, jastiperUid],
                        'createdAt': FieldValue.serverTimestamp(),
                        'lastMessage': '',
                        'lastMessageTimestamp': FieldValue.serverTimestamp(),
                      });
                    }

                    context.push('/chat/$jastiperUid', extra: jastiperName);

                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
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

    // ✅ TAMBAHAN: Debug info untuk melihat state
    final liveState = ref.watch(liveShoppingProvider);

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
          // ✅ TAMBAHAN: Debug info button (optional)
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Debug Info"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Room ID: ${liveState.roomId ?? 'null'}"),
                        Text("Host Peer ID: ${liveState.hostPeer?.peerId ?? 'null'}"),
                        Text("Current Role: ${liveState.currentRole ?? 'null'}"),
                        Text("Is Connected: ${liveState.isConnected}"),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
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
