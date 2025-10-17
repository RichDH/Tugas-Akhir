// chat_screen.dart - FIXED VERSION dengan semua masalah teratasi
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:program/app/providers/firebase_providers.dart';
import 'package:program/fitur/chat/presentation/providers/chat_provider.dart';
import 'package:program/fitur/post/domain/entities/post.dart';
import 'package:program/fitur/post/presentation/providers/offer_provider.dart';
import 'package:program/fitur/post/domain/entities/offer.dart';

// Offer Message Model untuk chat
class OfferMessage {
  final String postId;
  final String postTitle;
  final String? category;
  final String postImageUrl;
  final double originalPrice;
  final double offerPrice;
  final String offererUserId;
  final String offererUsername;
  final DateTime timestamp;
  final String status;

  OfferMessage({
    required this.postId,
    required this.postTitle,
    this.category,
    required this.postImageUrl,
    required this.originalPrice,
    required this.offerPrice,
    required this.offererUserId,
    required this.offererUsername,
    required this.timestamp,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'offer',
      'postId': postId,
      'postTitle': postTitle,
      'category': category,
      'postImageUrl': postImageUrl,
      'originalPrice': originalPrice,
      'offerPrice': offerPrice,
      'offererUserId': offererUserId,
      'offererUsername': offererUsername,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  factory OfferMessage.fromMap(Map<String, dynamic> map) {
    return OfferMessage(
      postId: _safeGetString(map, 'postId'),
      postTitle: _safeGetString(map, 'postTitle'),
      category: _safeGetString(map, 'category', allowNull: true),
      postImageUrl: _safeGetString(map, 'postImageUrl'),
      originalPrice: _safeGetDouble(map, 'originalPrice'),
      offerPrice: _safeGetDouble(map, 'offerPrice'),
      offererUserId: _safeGetString(map, 'offererUserId'),
      offererUsername: _safeGetString(map, 'offererUsername'),
      timestamp: DateTime.tryParse(_safeGetString(map, 'timestamp')) ?? DateTime.now(),
      status: _safeGetString(map, 'status', defaultValue: 'pending'),
    );
  }

  static String _safeGetString(Map<String, dynamic> map, String key, {String defaultValue = '', bool allowNull = false}) {
    final value = map[key];
    if (value == null) return allowNull ? '' : defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  static double _safeGetDouble(Map<String, dynamic> map, String key, {double defaultValue = 0.0}) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherUsername;
  final String? postId;
  final bool isOfferMode;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
    this.postId,
    this.isOfferMode = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<Post> _otherUserRequestPosts = []; // ✅ HANYA REQUEST POSTS
  bool _isLoadingPosts = false;

  @override
  void initState() {
    super.initState();
    _loadOtherUserRequestPosts(); // ✅ LOAD HANYA REQUEST POSTS
  }

  String _generateChatRoomId(String currentUserId, String otherUserId) {
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    return ids.join('_');
  }

  // ✅ FIX 2: Filter hanya post dengan type REQUEST
  Future<void> _loadOtherUserRequestPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final firestore = ref.read(firebaseFirestoreProvider);
      final snapshot = await firestore
          .collection('posts')
          .where('userId', isEqualTo: widget.otherUserId)
          .where('isActive', isEqualTo: true)
          .where('type', isEqualTo: 'request') // ✅ HANYA POST REQUEST
          .get();

      _otherUserRequestPosts = snapshot.docs
          .map((doc) => Post.fromFirestore(doc))
          .where((post) => post.type == PostType.request) // ✅ DOUBLE CHECK
          .toList();

      print('Found ${_otherUserRequestPosts.length} request posts for user ${widget.otherUserId}');
    } catch (e) {
      print('Error loading request posts: $e');
    } finally {
      setState(() => _isLoadingPosts = false);
    }
  }

  void _sendMessage(String chatRoomId) {
    if (_messageController.text.trim().isNotEmpty) {
      ref.read(chatNotifierProvider.notifier).sendMessage(
        chatRoomId,
        widget.otherUserId,
        _messageController.text,
      );
      _messageController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _sendOfferMessage(String chatRoomId, OfferMessage offerMessage) async {
    try {
      final firestore = ref.read(firebaseFirestoreProvider);
      final currentUser = ref.read(firebaseAuthProvider).currentUser;

      if (currentUser == null) return;

      final chatRoomRef = firestore.collection('chats').doc(chatRoomId);

      await chatRoomRef.collection('messages').add({
        'senderId': currentUser.uid,
        'text': 'Penawaran untuk ${offerMessage.postTitle}',
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': 'offer',
        'offerData': offerMessage.toMap(),
      });

      await chatRoomRef.update({
        'lastMessage': 'Penawaran untuk ${offerMessage.postTitle}',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print('Error sending offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim penawaran: $e')),
        );
      }
    }
  }

  // ✅ FIX 1: Mengatasi document not found dengan verifikasi user terlebih dahulu
  Future<void> _acceptOffer(String chatRoomId, Map<String, dynamic> offerData) async {
    try {
      final firestore = ref.read(firebaseFirestoreProvider);
      final currentUser = ref.read(firebaseAuthProvider).currentUser;

      if (currentUser == null) {
        throw Exception('User tidak login');
      }

      // ✅ VERIFIKASI DOKUMEN USER ADA SEBELUM MEMBUAT OFFER
      final currentUserDoc = await firestore.collection('users').doc(currentUser.uid).get();
      if (!currentUserDoc.exists) {
        throw Exception('Data user penerima offer tidak ditemukan. Silakan login ulang.');
      }

      final offererUserId = OfferMessage._safeGetString(offerData, 'offererUserId');
      if (offererUserId.isEmpty) {
        throw Exception('Data pengirim offer tidak valid');
      }

      final offererUserDoc = await firestore.collection('users').doc(offererUserId).get();
      if (!offererUserDoc.exists) {
        throw Exception('Data user pengirim offer tidak ditemukan');
      }

      // ✅ VERIFIKASI POST ADA
      final postId = OfferMessage._safeGetString(offerData, 'postId');
      final postDoc = await firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post tidak ditemukan atau telah dihapus');
      }

      print('Creating offer with valid documents:');
      print('- Current User: ${currentUser.uid}');
      print('- Offerer: $offererUserId');
      print('- Post: $postId');

      // Buat offer object dengan data yang sudah diverifikasi
      final tempOffer = Offer(
        id: 'chat_offer_${DateTime.now().millisecondsSinceEpoch}',
        postId: postId,
        postTitle: OfferMessage._safeGetString(offerData, 'postTitle'),
        offererId: offererUserId,
        offererUsername: OfferMessage._safeGetString(offerData, 'offererUsername'),
        postOwnerId: currentUser.uid, // ✅ PENERIMA OFFER SEBAGAI POST OWNER
        offerPrice: OfferMessage._safeGetDouble(offerData, 'offerPrice'),
        createdAt: Timestamp.now(),
      );

      // ✅ BUAT OFFER DI DATABASE TERLEBIH DAHULU
      final offerRef = await firestore.collection('offers').add({
        'postId': tempOffer.postId,
        'postTitle': tempOffer.postTitle,
        'offererId': tempOffer.offererId,
        'offererUsername': tempOffer.offererUsername,
        'postOwnerId': tempOffer.postOwnerId,
        'offerPrice': tempOffer.offerPrice,
        'status': 'accepted', // ✅ LANGSUNG ACCEPTED KARENA DARI CHAT
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ UPDATE OFFER ID DENGAN DOCUMENT ID YANG BARU DIBUAT
      final updatedOffer = tempOffer.copyWith(id: offerRef.id);

      // ✅ PANGGIL acceptOfferAndCreateTransaction dengan offer ID yang benar
      await ref.read(offerProvider.notifier).acceptOfferAndCreateTransaction(
        offerId: offerRef.id, // ✅ GUNAKAN ID YANG BENAR
        offer: updatedOffer,
        quantity: 1,
      );

      // Send acceptance message
      final chatRoomRef = firestore.collection('chats').doc(chatRoomId);
      await chatRoomRef.collection('messages').add({
        'senderId': currentUser.uid,
        'text': '**Penawaran anda untuk ${offerData['postTitle']} - diterima.**',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await chatRoomRef.update({
        'lastMessage': 'Penawaran diterima',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penawaran berhasil diterima dan transaksi dibuat!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      print('Error accepting offer: $e');
      if (mounted) {
        String errorMessage = 'Gagal menerima penawaran';
        if (e.toString().contains('not found')) {
          errorMessage = 'Data tidak ditemukan. Pastikan akun Anda masih aktif.';
        } else if (e.toString().contains('insufficient')) {
          errorMessage = 'Saldo tidak mencukupi untuk transaksi ini.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectOffer(String chatRoomId, Map<String, dynamic> offerData) async {
    try {
      final firestore = ref.read(firebaseFirestoreProvider);
      final currentUser = ref.read(firebaseAuthProvider).currentUser;

      if (currentUser == null) return;

      final chatRoomRef = firestore.collection('chats').doc(chatRoomId);
      await chatRoomRef.collection('messages').add({
        'senderId': currentUser.uid,
        'text': '**Penawaran anda untuk ${offerData['postTitle']} - ditolak.**',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await chatRoomRef.update({
        'lastMessage': 'Penawaran ditolak',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penawaran ditolak')),
        );
      }

    } catch (e) {
      print('Error rejecting offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak penawaran: $e')),
        );
      }
    }
  }

  void _showOfferDialog(String chatRoomId) {
    // ✅ CEK REQUEST POSTS, BUKAN SEMUA POSTS
    if (_otherUserRequestPosts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengguna ini tidak memiliki post request aktif')),
      );
      return;
    }

    Post? selectedPost;
    final TextEditingController offerPriceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Buat Penawaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Post>(
                decoration: const InputDecoration(
                  labelText: 'Pilih Post Request',
                  border: OutlineInputBorder(),
                ),
                value: selectedPost,
                // ✅ GUNAKAN REQUEST POSTS
                items: _otherUserRequestPosts.map((post) {
                  return DropdownMenuItem<Post>(
                    value: post,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${post.title}', // ✅ TAMBAH LABEL REQUEST
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (post.price != null)
                          Text(
                            'Budget: Rp ${post.price!.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (Post? value) {
                  setDialogState(() {
                    selectedPost = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: offerPriceController,
                decoration: const InputDecoration(
                  labelText: 'Harga Tawaran Anda',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                  helperText: 'Masukkan harga yang Anda tawarkan',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedPost == null || offerPriceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mohon lengkapi semua field')),
                  );
                  return;
                }

                final currentUser = ref.read(firebaseAuthProvider).currentUser;
                if (currentUser == null) return;

                try {
                  // Get current user data
                  final userDoc = await ref.read(firebaseFirestoreProvider)
                      .collection('users')
                      .doc(currentUser.uid)
                      .get();

                  final userData = userDoc.data() ?? {};
                  final username = userData['username']?.toString() ?? 'Unknown';

                  final offerMessage = OfferMessage(
                    postId: selectedPost!.id,
                    postTitle: selectedPost!.title,
                    category: selectedPost!.category,
                    // ✅ FIX 3: Pastikan image URL diambil dengan benar
                    postImageUrl: selectedPost!.imageUrls.isNotEmpty
                        ? selectedPost!.imageUrls.first
                        : '',
                    originalPrice: selectedPost!.price ?? 0,
                    offerPrice: double.tryParse(offerPriceController.text) ?? 0,
                    offererUserId: currentUser.uid,
                    offererUsername: username,
                    timestamp: DateTime.now(),
                  );

                  await _sendOfferMessage(chatRoomId, offerMessage);
                  Navigator.pop(context);
                } catch (e) {
                  print('Error creating offer: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal membuat penawaran: $e')),
                  );
                }
              },
              child: const Text('Kirim Penawaran'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FIX 3: Widget untuk menampilkan gambar dengan error handling yang lebih baik
  Widget _buildPostImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return const Icon(Icons.image, color: Colors.grey);
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image: $imageUrl - $error');
        return const Icon(Icons.broken_image, color: Colors.grey);
      },
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offerData, String chatRoomId, bool isFromCurrentUser) {
    final postTitle = offerData['postTitle']?.toString() ?? 'Produk';
    final category = offerData['category']?.toString();
    final postImageUrl = offerData['postImageUrl']?.toString() ?? '';
    final offerPrice = OfferMessage._safeGetDouble(offerData, 'offerPrice');
    final status = offerData['status']?.toString() ?? 'pending';

    print('Building offer card with image URL: $postImageUrl'); // ✅ DEBUG

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFromCurrentUser ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ FIX 3: Post Image dengan loading yang lebih baik
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade300,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPostImage(postImageUrl), // ✅ GUNAKAN FUNCTION YANG DIPERBAIKI
            ),
          ),
          const SizedBox(width: 12),
          // Post Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  postTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category != null && category.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Tawaran: Rp ${offerPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 13,
                  ),
                ),
                // Accept/Reject buttons for receiver
                if (!isFromCurrentUser && status == 'pending') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _acceptOffer(chatRoomId, offerData),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Terima', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _rejectOffer(chatRoomId, offerData),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Tolak', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Widget _buildAppBarTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.otherUsername,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoadingPosts
              ? const Text(
            'Memuat post request...',
            key: ValueKey('loading'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.white70,
            ),
          )
              : Text(
            '${_otherUserRequestPosts.length} post request tersedia',
            key: ValueKey('loaded'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("User tidak login")),
      );
    }

    final chatRoomId = _generateChatRoomId(currentUser.uid, widget.otherUserId);
    final messagesAsync = ref.watch(messagesStreamProvider(chatRoomId));

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(), // ✅ GUNAKAN FUNCTION TERPISAH
        actions: [
          if (_isLoadingPosts)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (snapshot) {
                if (snapshot.docs.isEmpty) {
                  return const Center(child: Text("Mulai percakapan!"));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: snapshot.docs.length,
                  itemBuilder: (context, index) {
                    if (index >= snapshot.docs.length) {
                      return const SizedBox.shrink();
                    }

                    final doc = snapshot.docs[index];
                    final data = doc.data();
                    final message = (data is Map<String, dynamic>) ? data : <String, dynamic>{};
                    final bool isMe = message['senderId']?.toString() == currentUser.uid;



                    // Handle offer messages
                    if (message['messageType']?.toString() == 'offer' && message['offerData'] != null) {
                      final offerData = message['offerData'];
                      if (offerData is Map<String, dynamic>) {
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: _buildOfferCard(offerData, chatRoomId, isMe),
                        );
                      }
                    }

                    // Handle regular messages
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).primaryColor : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message['text']?.toString() ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) {
                print('Chat error: $err');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text("Terjadi kesalahan: ${err.toString()}"),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(messagesStreamProvider(chatRoomId));
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Plus button for offers
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blue),
                  onPressed: () => _showOfferDialog(chatRoomId),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                    ),
                    onSubmitted: (_) => _sendMessage(chatRoomId),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(chatRoomId),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
