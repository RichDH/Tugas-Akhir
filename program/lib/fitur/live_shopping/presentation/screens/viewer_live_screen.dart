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
  bool _isNavigating = false;

  // TAMBAHAN: Cache untuk data jastiper
  String? _cachedJastiperUid;
  String? _cachedJastiperName;
  bool _isLoadingJastiperData = false;

  @override
  void initState() {
    super.initState();
    // Load jastiper data saat screen dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadJastiperData();
    });
  }

  // FUNGSI BARU: Load dan cache data jastiper
  Future<void> _loadJastiperData() async {
    if (_isLoadingJastiperData) return;

    setState(() {
      _isLoadingJastiperData = true;
    });

    try {
      final liveState = ref.read(liveShoppingProvider);
      final roomId = liveState.roomId;

      if (roomId == null) {
        debugPrint("Room ID tidak tersedia");
        return;
      }

      debugPrint("Loading jastiper data for roomId: $roomId");

      // Query berdasarkan field roomId
      final liveSessionQuery = await FirebaseFirestore.instance
          .collection('live_sessions')
          .where('roomId', isEqualTo: roomId)
          .limit(1)
          .get();

      if (liveSessionQuery.docs.isNotEmpty) {
        final liveDoc = liveSessionQuery.docs.first;
        final data = liveDoc.data();

        setState(() {
          _cachedJastiperUid = data['hostId'] as String?;
          _cachedJastiperName = data['hostName'] as String?;
        });

        debugPrint("Jastiper data loaded - UID: $_cachedJastiperUid, Name: $_cachedJastiperName");
      } else {
        debugPrint("Live session tidak ditemukan untuk roomId: $roomId");
      }
    } catch (e) {
      debugPrint("Error loading jastiper data: $e");
    } finally {
      setState(() {
        _isLoadingJastiperData = false;
      });
    }
  }

  // FUNGSI DIPERBAIKI: Get jastiper data dengan fallback
  Future<Map<String, String>?> _getJastiperData() async {
    // Cek cache terlebih dahulu
    if (_cachedJastiperUid != null && _cachedJastiperName != null) {
      debugPrint("Using cached jastiper data");
      return {
        'uid': _cachedJastiperUid!,
        'name': _cachedJastiperName!,
      };
    }

    // Jika cache kosong, load ulang
    try {
      final liveState = ref.read(liveShoppingProvider);
      final roomId = liveState.roomId;

      if (roomId == null) {
        throw Exception("Room ID tidak tersedia");
      }

      debugPrint("Fetching jastiper data for roomId: $roomId");

      // Query dengan field roomId
      final liveSessionQuery = await FirebaseFirestore.instance
          .collection('live_sessions')
          .where('roomId', isEqualTo: roomId)
          .where('status', isEqualTo: 'ongoing')
          .limit(1)
          .get();

      if (liveSessionQuery.docs.isEmpty) {
        throw Exception("Sesi live tidak ditemukan");
      }

      final liveDoc = liveSessionQuery.docs.first;
      final data = liveDoc.data();

      final jastiperUid = data['hostId'] as String?;
      final jastiperName = data['hostName'] as String?;

      if (jastiperUid == null) {
        throw Exception("Data jastiper tidak valid");
      }

      // Update cache
      setState(() {
        _cachedJastiperUid = jastiperUid;
        _cachedJastiperName = jastiperName ?? 'Jastiper';
      });

      return {
        'uid': jastiperUid,
        'name': jastiperName ?? 'Jastiper',
      };
    } catch (e) {
      debugPrint("Error getting jastiper data: $e");
      return null;
    }
  }

  // Fungsi untuk menampilkan form pembelian
  void _showPurchaseForm(BuildContext context, WidgetRef ref) async {
    final liveState = ref.read(liveShoppingProvider);
    final price = liveState.currentItemPrice;

    if (price <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Jastiper belum menetapkan harga barang.")),
        );
      }
      return;
    }

    // PERBAIKAN: Ambil data jastiper dengan fungsi baru
    final jastiperData = await _getJastiperData();

    if (jastiperData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tidak dapat menemukan data jastiper. Silakan coba lagi."),
            backgroundColor: Colors.red,
          ),
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
          title: Text("Form Pembelian - ${jastiperData['name']}"),
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

                    // Buat transaksi dengan sellerId yang benar
                    final roomId = ref.read(liveShoppingProvider).roomId ?? '';

                    await FirebaseFirestore.instance.collection('transactions').add({
                      'postId': roomId,
                      'buyerId': user.uid,
                      'sellerId': jastiperData['uid']!, // UID jastiper yang benar
                      'amount': totalAmount,
                      'status': 'pending',
                      'createdAt': FieldValue.serverTimestamp(),
                      'buyerAddress': (userDoc.data()?['alamat'] as String?)?.trim().isNotEmpty == true
                          ? (userDoc.data()?['alamat'] as String).trim()
                          : 'Alamat tidak tersedia',
                      'items': [
                        {
                          'postId': roomId,
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
                        'hostName': jastiperData['name']!,
                        'roomId': roomId,
                        'unitPrice': price,
                        'source': 'live_shopping',
                      },
                    });

                    if (mounted) {
                      Navigator.of(ctx).pop();
                      _showSuccessDialog(context);
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

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  // FUNGSI DIPERBAIKI: Show viewer action panel dengan data yang benar
  void _showViewerActionPanel(BuildContext context, WidgetRef ref) async {
    // Ambil data jastiper
    final jastiperData = await _getJastiperData();

    if (jastiperData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tidak dapat menemukan data jastiper. Silakan coba lagi."),
            backgroundColor: Colors.red,
          ),
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
                  Navigator.of(ctx).pop();
                  _showPurchaseForm(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text("Kirim Pesan ke ${jastiperData['name']}"),
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
                    final jastiperUid = jastiperData['uid']!;
                    final jastiperName = jastiperData['name']!;

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

  void handleLeave() async {
    if (_isLeavingRoom || _isNavigating) return;

    setState(() {
      _isLeavingRoom = true;
      _isNavigating = true;
    });

    try {
      try {
        Navigator.of(context).popUntil((route) => route.settings.name == '/viewer-live' || route.isFirst);
      } catch (e) {
        debugPrint("Error closing overlays: $e");
      }

      await ref.read(liveShoppingProvider.notifier).leaveRoom().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint("LeaveRoom timed out, forcing navigation");
        },
      );

    } catch (e) {
      debugPrint("Error saat keluar dari room: $e");
    }

    if (mounted) {
      try {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/live');
        }
      } catch (e) {
        debugPrint("Navigation error: $e");
        try {
          Navigator.of(context).pushNamedAndRemoveUntil('/live', (route) => false);
        } catch (e2) {
          debugPrint("Fallback navigation error: $e2");
        }
      }
    }
  }

  void _showLiveEndedDialog() {
    if (_hasShownEndDialog || !mounted || _isNavigating) return;

    _hasShownEndDialog = true;

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
    ref.listen<LiveShoppingState>(liveShoppingProvider, (previous, next) {
      if (_isNavigating) return;

      if (next.isLiveEnded && (previous?.isLiveEnded == false || previous == null)) {
        debugPrint("Live ended detected in viewer - immediate action");
        if (!_hasShownEndDialog) {
          _showLiveEndedDialog();
        }
        return;
      }

      if (next.error != null && previous?.error != next.error && !next.isLiveEnded) {
        debugPrint("Error detected: ${next.error}");

        final error = next.error!.toLowerCase();

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

    final hostVideoTrack = ref.watch(liveShoppingProvider.select((state) => state.remoteVideoTrack));
    final hostName = _cachedJastiperName ?? ref.watch(liveShoppingProvider.select((state) => state.hostPeer?.name ?? 'Live'));

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
            onPressed: _isLeavingRoom ? null : handleLeave,
          ),
          title: Text("Menonton Live $hostName"),
          backgroundColor: Colors.black.withOpacity(0.7),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          children: [
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

            if (!_isLeavingRoom)
              LiveChatWidget(
                onActionButtonPressed: () => _showViewerActionPanel(context, ref),
                isJastiper: false,
              ),

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