import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../providers/post_provider.dart';
import '../widgets/video_player_widgets.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postByIdProvider(widget.postId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Postingan'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: postAsync.when(
        data: (post) {
          if (post == null) {
            return const Center(child: Text('Post tidak ditemukan'));
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header dengan info penjual
                      _buildSellerHeader(post),

                      // Media
                      _buildMediaContent(post),

                      // ✅ TOMBOL LIKE DI BAWAH MEDIA (INSTAGRAM STYLE) - PERBAIKAN
                      _buildPostActions(post),

                      // Detail produk
                      _buildProductDetails(post),

                      const Divider(),

                      // Komentar section
                      _buildCommentsSection(post),

                      const SizedBox(height: 100), // Space untuk bottom buttons
                    ],
                  ),
                ),
              ),

              // ✅ BOTTOM ACTION BUTTONS - DIPERBAIKI UNTUK REQUEST
              _buildBottomActions(post),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(postByIdProvider(widget.postId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSellerHeader(post) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            child: Icon(Icons.person),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  post.location ?? '',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(post) {
    if (post.videoUrl != null) {
      return Container(
        width: double.infinity,
        height: 300,
        color: Colors.black,
        child: VideoPlayerWidget(url: post.videoUrl!),
      );
    } else if (post.imageUrls.isNotEmpty) {
      return Container(
        width: double.infinity,
        height: 300,
        color: Colors.black,
        child: Image.network(
          post.imageUrls[0],
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            return progress == null
                ? child
                : const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) =>
          const Center(child: Icon(Icons.error, color: Colors.white)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ✅ POST ACTIONS (LIKE BUTTON INSTAGRAM STYLE) - DIPERBAIKI
  Widget _buildPostActions(post) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ✅ LIKE BUTTON - PERBAIKAN VISUAL DAN LOGIC
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(post.id)
                    .collection('likes')
                    .snapshots(),
                builder: (context, snapshot) {
                  final likesCount = snapshot.data?.docs.length ?? 0;
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final isLiked = currentUser != null &&
                      snapshot.data?.docs.any((doc) => doc.id == currentUser.uid) == true;

                  return GestureDetector(
                    onTap: () => _toggleLike(post),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey[700], // ✅ MERAH JIKA LIKED
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$likesCount suka',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // ✅ HAPUS TOMBOL SHARE
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails(post) {
    // ✅ TAMPILKAN DEADLINE UNTUK REQUEST, HARGA UNTUK LAINNYA
    String displayPrice;
    if (_getPostTypeText(post.type) == 'REQUEST') {
      if (post.deadline != null) {
        displayPrice = 'Deadline: ${DateFormat('dd/MM/yyyy HH:mm').format(post.deadline!.toDate())}';
      } else {
        displayPrice = 'Tidak ada deadline';
      }
    } else {
      displayPrice = post.price != null
          ? NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(post.price!)
          : 'Free';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayPrice,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _getPostTypeText(post.type) == 'REQUEST' ? Colors.orange : Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Deskripsi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(post.description ?? ''),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jenis: ${_getPostTypeText(post.type)}'),
                    Text('Kategori: ${post.category ?? '–'}'),
                    if (post.condition != null)
                      Text('Kondisi: ${_getConditionText(post.condition!)}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Komentar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(post.id)
              .collection('comments')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final comments = snapshot.data!.docs;

            if (comments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Belum ada komentar. Jadilah yang pertama!',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index].data() as Map<String, dynamic>;
                return ListTile(
                  leading: const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person, size: 16),
                  ),
                  title: Text(
                    comment['username'] ?? 'Anonymous',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(comment['text'] ?? ''),
                  trailing: Text(
                    _formatTimestamp(comment['createdAt']),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ✅ BOTTOM ACTION BUTTONS - DIPERBAIKI UNTUK REQUEST
  Widget _buildBottomActions(post) {
    final postType = _getPostTypeText(post.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Comment input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Tulis komentar...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _postComment,
                icon: const Icon(Icons.send),
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ ACTION BUTTONS BERBEDA UNTUK REQUEST DAN NON-REQUEST
          if (postType == 'REQUEST')
          // Tombol untuk REQUEST
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement buat penawaran
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur buat penawaran akan segera hadir'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_offer),
                    label: const Text('Buat Penawaran'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement ambil pesanan
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur ambil pesanan akan segera hadir'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Ambil Pesanan'),
                  ),
                ),
              ],
            )
          else
          // Tombol untuk JASTIP/SHORT/SALE
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showQuantityDialog(context, post),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Keranjang'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showBuyDirectDialog(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Beli'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ✅ DIALOG QUANTITY UNTUK KERANJANG
  void _showQuantityDialog(BuildContext context, post) {
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Pilih Kuantitas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(post.title),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: quantity > 1 ? () {
                      setState(() => quantity--);
                    } : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$quantity', style: const TextStyle(fontSize: 18)),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => quantity++);
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format((post.price ?? 0) * quantity)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                _addToCartWithQuantity(post, quantity);
                Navigator.pop(context);
              },
              child: const Text('Tambah ke Keranjang'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ DIALOG BELI LANGSUNG DENGAN CEK SALDO
  void _showBuyDirectDialog(post) {
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Beli Langsung'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(post.title),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: quantity > 1 ? () {
                      setState(() => quantity--);
                    } : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$quantity', style: const TextStyle(fontSize: 18)),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => quantity++);
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format((post.price ?? 0) * quantity)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _buyDirect(post, quantity);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Beli Sekarang'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ TOGGLE LIKE DENGAN PERBAIKAN (TIDAK DOUBLE INCREMENT)
  Future<void> _toggleLike(post) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
      final likesRef = postRef.collection('likes').doc(user.uid);

      // ✅ CEK STATUS LIKE SAAT INI
      final likeDoc = await likesRef.get();

      if (likeDoc.exists) {
        // Unlike - hapus like
        await likesRef.delete();
      } else {
        // Like - tambah like
        await likesRef.set({
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // ✅ TIDAK PERLU UPDATE POST PROVIDER KARENA SUDAH MENGGUNAKAN STREAM
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal update like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addToCartWithQuantity(post, int quantity) {
    final cartItem = CartItem(
      id: '',
      postId: post.id,
      title: post.title,
      price: post.price ?? 0,
      imageUrl: post.imageUrls.isNotEmpty ? post.imageUrls[0] : '',
      sellerId: post.userId,
      sellerUsername: post.username,
      addedAt: Timestamp.now(),
      deadline: post.deadline,
      quantity: quantity,
    );

    ref.read(cartProvider.notifier).addToCart(cartItem);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$quantity item ditambahkan ke keranjang'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ✅ BELI LANGSUNG DENGAN CEK SALDO
  Future<void> _buyDirect(post, int quantity) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final totalAmount = (post.price ?? 0) * quantity;

      // ✅ CEK SALDO USER
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userBalance = (userDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;

      if (userBalance < totalAmount) {
        // ✅ SALDO TIDAK MENCUKUPI
        _showInsufficientBalanceDialog(totalAmount, userBalance);
        return;
      }

      // ✅ SALDO MENCUKUPI, BUAT TRANSAKSI
      await _createTransaction(post, quantity, totalAmount, user.uid);

      // ✅ KURANGI SALDO USER
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'balance': FieldValue.increment(-totalAmount),
      });

      // ✅ TAMPILKAN POPUP SUKSES
      _showTransactionSuccessDialog(totalAmount);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat transaksi: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
              // TODO: Navigate to top-up page
              context.push('/topup');
            },
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
  }

  void _showTransactionSuccessDialog(double totalAmount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaksi Berhasil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pembayaran berhasil!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount)}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/transaction-history');
            },
            child: const Text('Lihat Riwayat'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTransaction(post, int quantity, double totalAmount, String userId) async {
    await FirebaseFirestore.instance.collection('transactions').add({
      'postId': post.id,
      'buyerId': userId,
      'sellerId': post.userId,
      'amount': totalAmount,
      'status': 'paid',
      'createdAt': FieldValue.serverTimestamp(),
      'items': [
        {
          'postId': post.id,
          'title': post.title,
          'price': post.price ?? 0,
          'quantity': quantity,
          'imageUrl': post.imageUrls.isNotEmpty ? post.imageUrls[0] : '',
        }
      ],
      'isEscrow': true,
      'escrowAmount': totalAmount,
    });
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda harus login terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final username = userDoc.data()?['username'] ?? user.displayName ?? 'User';

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'text': _commentController.text.trim(),
        'username': username,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Komentar berhasil ditambahkan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim komentar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getPostTypeText(dynamic postType) {
    if (postType == null) return 'UNKNOWN';

    final typeString = postType.toString();

    if (typeString.contains('.')) {
      return typeString.split('.').last.toUpperCase();
    }

    return typeString.toUpperCase();
  }

  String _getConditionText(dynamic condition) {
    if (condition == null) return 'UNKNOWN';

    final conditionString = condition.toString();

    if (conditionString.contains('.')) {
      return conditionString.split('.').last.toUpperCase();
    }

    return conditionString.toUpperCase();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return '';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}h';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}j';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'Baru saja';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
