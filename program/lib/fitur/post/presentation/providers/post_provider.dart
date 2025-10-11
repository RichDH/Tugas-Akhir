import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/post.dart';

// ✅ PROVIDER UNTUK GET POST BY ID
final postByIdProvider = StreamProvider.family<Post?, String>((ref, postId) {
  return FirebaseFirestore.instance
      .collection('posts')
      .doc(postId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return Post.fromFirestore(doc);
  });
});

// ✅ TAMBAHKAN DI post_provider.dart
final userRequestsProvider = StreamProvider.family<List<Post>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .where('type', isEqualTo: 'request')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final isLiked = likedBy.contains(userId);

      data['isLiked'] = isLiked;
      return Post.fromFirestore(doc);
    }).toList();
  });
});


// ✅ PROVIDER UNTUK GET SEMUA POSTS
final postsProvider = StreamProvider<List<Post>>((ref) {
  return FirebaseFirestore.instance
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final isLiked = likedBy.contains(currentUserId);

      // Create post dengan isLiked yang benar
      final post = Post.fromFirestore(doc);
      return post.copyWith(isLiked: isLiked);
    }).toList();
  });
})

;

// ✅ POST NOTIFIER UNTUK ACTIONS
final postNotifierProvider = StateNotifierProvider<PostNotifier, AsyncValue<void>>((ref) {
  return PostNotifier();
});

class PostNotifier extends StateNotifier<AsyncValue<void>> {
  PostNotifier() : super(const AsyncValue.data(null));

  Future<void> toggleLike(String postId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) return;

      final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;

        final data = postDoc.data()!;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        final likesCount = data['likesCount'] ?? 0;

        if (likedBy.contains(currentUserId)) {
          likedBy.remove(currentUserId);
          transaction.update(postRef, {
            'likedBy': likedBy,
            'likesCount': likesCount - 1,
          });
        } else {
          likedBy.add(currentUserId);
          transaction.update(postRef, {
            'likedBy': likedBy,
            'likesCount': likesCount + 1,
          });
        }
      });
    } catch (e) {
      // Handle error silently or show snackbar
      print('Error toggling like: $e');
    }
  }

  Future<void> takeOrder(String postId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) return;

      final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;

        final data = postDoc.data()!;
        final currentOffers = data['currentOffers'] ?? 0;
        final maxOffers = data['maxOffers'] ?? 1;

        if (currentOffers >= maxOffers) {
          throw Exception('Post sudah penuh');
        }

        transaction.update(postRef, {
          'currentOffers': currentOffers + 1,
        });
      });
    } catch (e) {
      print('Error taking order: $e');
      rethrow;
    }
  }
}

// ✅ CREATE POST PROVIDER
final createPostProvider = StateNotifierProvider<CreatePostNotifier, AsyncValue<void>>((ref) {
  return CreatePostNotifier();
});

class CreatePostNotifier extends StateNotifier<AsyncValue<void>> {
  CreatePostNotifier() : super(const AsyncValue.data(null));

  Future<void> createPost({
    required PostType type,
    required String title,
    required String description,
    required String category,
    double? price,
    required String location,
    String? locationCity,
    double? locationLat,
    double? locationLng,
    required Condition condition,
    String? brand,
    String? size,
    String? weight,
    String? additionalNotes,
    required List<String> imagePaths,
    String? videoPath,
    String? syarat,
    int? maxOffers,
    Timestamp? deadline,
    bool isPriceNegotiable = false,
  }) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // TODO: Upload files dan dapatkan URLs
      final imageUrls = <String>[]; // Placeholder - implement file upload
      String? videoUrl; // Placeholder - implement file upload

      final postData = {
        'title': title,
        'description': description,
        'type': type.name,
        'category': category,
        'price': price,
        'isPriceNegotiable': isPriceNegotiable,
        'location': location,
        'locationCity': locationCity ?? '',
        'locationLat': locationLat,
        'locationLng': locationLng,
        'imageUrls': imageUrls,
        'videoUrl': videoUrl,
        'condition': condition.name,
        'brand': brand ?? '',
        'size': size ?? '',
        'weight': weight != null ? double.tryParse(weight) : null,
        'additionalNotes': additionalNotes ?? '',
        'syarat': syarat ?? '',
        'maxOffers': maxOffers,
        'deadline': deadline,
        'userId': currentUser.uid,
        'username': currentUser.displayName ?? 'User',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'currentOffers': 0,
        'likedBy': [],
      };

      await FirebaseFirestore.instance
          .collection('posts')
          .add(postData);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
