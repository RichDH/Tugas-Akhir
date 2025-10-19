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
  String? _cachedRoomId;

  @override
  void initState() {
    super.initState();
    
    // PERBAIKAN: Inisialisasi data saat screen dimuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeJastiperData();
    });
  }

  // FUNGSI BARU: Inisialisasi data jastiper dari berbagai sumber
  Future<void> _initializeJastiperData() async {
    try {
      final liveState = ref.read(liveShoppingProvider);
      final hostPeer = liveState.hostPeer;
      
      if (hostPeer?.peerId != null) {
        _cachedRoomId = hostPeer!.peerId;
        
        // PERBAIKAN: Multiple query strategies
        await _fetchJastiperData(hostPeer.peerId, hostPeer.name);
      }
    } catch (e) {
      debugPrint("Error initializing jastiper data: $e");
    }
  }

  // FUNGSI BARU: Multi-strategy untuk mendapatkan data jastiper
  Future<Map<String, String?>> _fetchJastiperData(String roomId, String? hostName) async {
    try {
      debugPrint("=== FETCHING JASTIPER DATA ===");
      debugPrint("Room ID: $roomId");
      debugPrint("Host Name: $hostName");

      // STRATEGI 1: Query berdasarkan roomId field (struktur baru)
      var liveSessionQuery = await FirebaseFirestore.instance
          .collection('live_sessions')
          .where('roomId', isEqualTo: roomId)
          .where('status', isEqualTo: 'ongoing')
          .limit(1)
          .get();

      if (liveSessionQuery.docs.isNotEmpty) {
        final liveDoc = liveSessionQuery.docs.first;
        final jastiperUid = liveDoc.data()['hostId'] as String?;
        final jastiperName = liveDoc.data()['hostName'] as String? ?? hostName ?? 'Jastiper';
        
        debugPrint("✅ STRATEGI 1 BERHASIL - Found via roomId query");
        debugPrint("Jastiper UID: $jastiperUid");
        debugPrint("Jastiper Name: $jastiperName");
        
        // Cache data
        _cachedJastiperUid = jastiperUid;
        _cachedJastiperName = jastiperName;
        
        return {
          'uid': jastiperUid,
          'name': jastiperName,
          'source': 'roomId_query'
        };
      }

      // STRATEGI 2: Query berdasarkan document ID = hostId (struktur lama)
      debugPrint("❌ STRATEGI 1 GAGAL - Trying alternative queries...");
      
      // Cari semua live sessions yang ongoing
      final allLiveSessionsQuery = await FirebaseFirestore.instance
          .collection('live_sessions')
          .where('status', isEqualTo: 'ongoing')
          .get();

      debugPrint("Found ${allLiveSessionsQuery.docs.length} ongoing sessions");

      for (var doc in allLiveSessionsQuery.docs) {
        final data = doc.data();
        debugPrint("Checking session: ${doc.id} - roomId: ${data['roomId']}");
        
        // Cek apakah ada yang match dengan roomId
        if (data['roomId'] == roomId) {
          final jastiperUid = data['hostId'] as String? ?? doc.id;
          final jastiperName = data['hostName'] as String? ?? hostName ?? 'Jastiper';
          
          debugPrint("✅ STRATEGI 2 BERHASIL - Found via document scan");
          debugPrint("Jastiper UID: $jastiperUid");
          
          // Cache data
          _cachedJastiperUid = jastiperUid;
          _cachedJastiperName = jastiperName;
          
          return {
            'uid': jastiperUid,
            'name': jastiperName,
            'source': 'document_scan'
          };
        }
        
        // STRATEGI 3: Cek berdasarkan document ID (untuk backward compatibility)
        if (doc.id == roomId) {
          final jastiperUid = data['hostId'] as String? ?? doc.id;
          final jastiperName = data['hostName'] as String? ?? hostName ?? 'Jastiper';
          
          debugPrint("✅ STRATEGI 3 BERHASIL - Found via document ID");
          debugPrint("Jastiper UID: $jastiperUid");
          
          // Cache data
          _cachedJastiperUid = jastiperUid;
          _cachedJastiperName = jastiperName;
          
          return {
            'uid': jastiperUid,
            'name': jastiperName,
            'source': 'document_id'
          };
        }
      }

      debugPrint("❌ SEMUA STRATEGI GAGAL - No matching live session found");
      
      // FALLBACK: Gunakan roomId sebagai UID jika tidak ada yang ditemukan
      debugPrint("🔄 FALLBACK - Using roomId as UID");
      return {
        'uid': roomId, // Fallback ke roomId
        'name': hostName ?? 'Jastiper',
        'source': 'fallback'
      };

    } catch (e) {
      debugPrint("❌ ERROR in _fetchJastiperData: $e");
      return {
        'uid': roomId, // Emergency fallback
        'name': hostName ?? 'Jastiper',
        'source': 'error_fallback'
      };
    }
  }

  // FUNGSI YANG DIPERBAIKI: Menampilkan form pembelian dengan data yang tepat
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

    // PERBAIKAN: Fetch data jastiper dengan strategy yang benar
    Map<String, String?> jastiperData;
    if (_cachedJastiperUid != null) {
      jastiperData = {
        'uid': _cachedJastiperUid,
        'name': _cachedJastiperName,
        'source': 'cached'
      };
    } else {
      jastiperData = await _fetchJastiperData(hostPeer.peerId, hostPeer.name);
    }

    final jastiperUid = jastiperData['uid'];
    final jastiperName = jastiperData['name'];

    if (jastiperUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mendapatkan data jastiper. Coba lagi.")),
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
          title: Text("Beli dari $jastiperName"),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TAMBAHAN: Tampilkan info jastiper
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
                            "Jastiper: $jastiperName",
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
                  await _processTransaction(
                    context: ctx,
                    jastiperUid: jastiperUid,
                    jastiperName: jastiperName!,
                    itemName: itemNameController.text.trim(),
                    description: descriptionController.text.trim(),
                    qty: int.parse(qtyController.text),
                    price: price,
                    roomId: hostPeer.peerId,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // FUNGSI BARU: Pemrosesan transaksi yang terpisah
  Future<void> _processTransaction({
    required BuildContext context,
    required String jastiperUid,
    required String jastiperName,
    required String itemName,
    required String description,
    required int qty,
    required double price,
    required String roomId,
  }) async {
    try {
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
        Navigator.of(context).pop(); // Tutup form dulu
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

      // Buat transaksi dengan data jastiper yang benar
      await FirebaseFirestore.instance.collection('transactions').add({
        'postId': roomId, // roomId sebagai identifier sumber transaksi
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
            'postId': roomId,
            'title': itemName,
            'price': price,
            'quantity': qty,
            'imageUrl': '',
          }
        ],
        'isEscrow': true,
        'escrowAmount': totalAmount,
        'isAcceptedBySeller': false,
        'type': 'live_buy',
        'liveDescription': description,
        'liveMeta': {
          'hostName': jastiperName,
          'roomId': roomId,
          'unitPrice': price,
          'source': 'live_shopping',
          'jastiperUid': jastiperUid, // TAMBAHAN: Simpan juga untuk referensi
        },
      });

      if (mounted) {
        Navigator.of(context).pop(); // tutup form
        _showSuccessDialog(this.context); // tampilkan success overlay 3 detik
      }
    } catch (e) {
      debugPrint("Error processing transaction: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat transaksi: $e')),
        );
      }
    }
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

  // FUNGSI YANG DIPERBAIKI: Menampilkan panel aksi penonton dengan data yang benar
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

    // PERBAIKAN: Fetch atau gunakan data yang sudah di-cache
    Map<String, String?> jastiperData;
    if (_cachedJastiperUid != null) {
      jastiperData = {
        'uid': _cachedJastiperUid,
        'name': _cachedJastiperName,
        'source': 'cached'
      };
    } else {
      jastiperData = await _fetchJastiperData(hostPeer.peerId, hostPeer.name);
    }

    final jastiperUid = jastiperData['uid'];
    final jastiperName = jastiperData['name'] ?? hostPeer.name;

    if (jastiperUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mendapatkan data jastiper. Coba lagi.")),
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
              // TAMBAHAN: Header dengan info jastiper
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        jastiperName?.substring(0, 1).toUpperCase() ?? 'J',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jastiperName ?? 'Jastiper',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Sedang live",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text("Isi Form Pembelian"),
                subtitle: const Text("Buat pesanan dari live ini"),
                onTap: () {
                  Navigator.of(ctx).pop(); // Tutup bottom sheet
                  _showPurchaseForm(context, ref); // Buka dialog form
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text("Kirim Pesan ke $jastiperName"),
                subtitle: const Text("Chat privat dengan jastiper"),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _navigateToChat(jastiperUid, jastiperName ?? 'Jastiper');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // FUNGSI BARU: Navigasi ke chat yang terpisah
  Future<void> _navigateToChat(String jastiperUid, String jastiperName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anda harus login untuk chat')),
        );
      }
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

      if (mounted) {
        context.push('/chat/$jastiperUid', extra: jastiperName);
      }

    } catch (e) {
      debugPrint("Error navigating to chat: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
          // TAMBAHAN: Action button untuk debug info (jika debug mode)
          actions: [
            if (mounted && _cachedJastiperUid != null)
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
                          Text("Room ID: ${_cachedRoomId ?? 'null'}"),
                          Text("Jastiper UID: ${_cachedJastiperUid ?? 'null'}"),
                          Text("Jastiper Name: ${_cachedJastiperName ?? 'null'}"),
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