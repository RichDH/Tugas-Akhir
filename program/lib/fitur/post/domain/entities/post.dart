import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { jastip, request, live, short }

class Post extends Equatable {
  final String id;
  final String userId;
  final String username;
  final PostType type;
  final String title;
  final String description;
  final String category;
  final double? price;
  final String location;
  final List<String> imageUrls;
  final String? videoUrl;
  final Timestamp createdAt;
  final int likesCount;
  final int commentsCount;
  final int offersCount;
  final bool isActive;
  final String? syarat;
  final int? batasJumlahOffer;
  final Timestamp? deadline;

  const Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    this.price,
    required this.location,
    required this.imageUrls,
    this.videoUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.offersCount = 0,
    this.isActive = true,
    this.syarat,
    this.batasJumlahOffer,
    this.deadline,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] as String,
      username: data['username'] as String,
      type: PostType.values.firstWhere(
              (e) => e.toString() == 'PostType.${data['type']}',
          orElse: () => PostType.jastip),
      title: data['title'] as String,
      description: data['description'] as String,
      category: data['category'] as String,
      price: (data['price'] as num?)?.toDouble(),
      location: data['location'] as String,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrl: data['videoUrl'] as String?,
      createdAt: data['createdAt'] as Timestamp,
      likesCount: data['likesCount'] as int? ?? 0,
      commentsCount: data['commentsCount'] as int? ?? 0,
      offersCount: data['offersCount'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      syarat: data['syarat'] as String?,
      batasJumlahOffer: data['batasJumlahOffer'] as int?,
      deadline: data['deadline'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'location': location,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'createdAt': createdAt,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'offersCount': offersCount,
      'isActive': isActive,
      'syarat': syarat,
      'batasJumlahOffer': batasJumlahOffer,
      'deadline': deadline,
    };
  }

  @override
  List<Object?> get props => [
    id, userId, username, type, title, description, price, location,
    imageUrls, videoUrl, createdAt, likesCount, commentsCount, offersCount,
    isActive, syarat, batasJumlahOffer, deadline
  ];
}