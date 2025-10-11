import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { jastip, request, short }
enum Condition { baru, bekas }

class Post extends Equatable {
  final String id;
  final String userId;
  final String username;
  final PostType type;
  final String title;
  final String? description;
  final String? category;
  final double? price;
  final String? location;
  final String? locationCity;
  final double? locationLat;
  final double? locationLng;
  final Condition? condition;
  final String? brand;
  final String? size;
  final String? weight; // ✅ UBAH KE STRING (BUKAN DOUBLE)
  final String? additionalNotes;
  final List<String> imageUrls;
  final String? videoUrl;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  // Properties untuk interactions
  final bool isLiked;
  final int likesCount;
  final int commentsCount;
  final int currentOffers;
  final List<String> likedBy;

  // Properties khusus untuk request
  final String? syarat;
  final int? maxOffers;
  final Timestamp? deadline;
  final bool isPriceNegotiable;
  final bool isActive;

  const Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.type,
    required this.title,
    this.description,
    this.category,
    this.price,
    this.location,
    this.locationCity,
    this.locationLat,
    this.locationLng,
    this.condition,
    this.brand,
    this.size,
    this.weight, // String bukan double
    this.additionalNotes,
    required this.imageUrls,
    this.videoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isLiked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.currentOffers = 0,
    this.likedBy = const [],
    this.syarat,
    this.maxOffers,
    this.deadline,
    this.isPriceNegotiable = false,
    this.isActive = true,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Post(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? '',
      type: _parsePostType(data['type'] as String?),
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      category: data['category'] as String?,
      price: _parseDouble(data['price']), // ✅ SAFE PARSING
      location: data['location'] as String?,
      locationCity: data['locationCity'] as String?,
      locationLat: _parseDouble(data['locationLat']),
      locationLng: _parseDouble(data['locationLng']),
      condition: _parseCondition(data['condition'] as String?),
      brand: data['brand'] as String?,
      size: data['size'] as String?,
      weight: data['weight'] as String?, // ✅ PARSE SEBAGAI STRING
      additionalNotes: data['additionalNotes'] as String?,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrl: data['videoUrl'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
      isLiked: data['isLiked'] as bool? ?? false,
      likesCount: data['likesCount'] as int? ?? 0,
      commentsCount: data['commentsCount'] as int? ?? 0,
      currentOffers: data['currentOffers'] as int? ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      syarat: data['syarat'] as String?,
      maxOffers: data['maxOffers'] as int?,
      deadline: data['deadline'] as Timestamp?,
      isPriceNegotiable: data['isPriceNegotiable'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  // ✅ SAFE DOUBLE PARSING
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value); // ✅ GUNAKAN tryParse BUKAN toDouble()
    }
    return null;
  }

  static PostType _parsePostType(String? type) {
    if (type == null) return PostType.jastip;
    try {
      return PostType.values.firstWhere((e) => e.name == type);
    } catch (e) {
      return PostType.jastip;
    }
  }

  static Condition _parseCondition(String? condition) {
    if (condition == null) return Condition.baru;
    try {
      return Condition.values.firstWhere((e) => e.name == condition);
    } catch (e) {
      return Condition.baru;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'type': type.name,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'location': location,
      'locationCity': locationCity,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'condition': condition?.name,
      'brand': brand,
      'size': size,
      'weight': weight, // String langsung
      'additionalNotes': additionalNotes,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'currentOffers': currentOffers,
      'likedBy': likedBy,
      'syarat': syarat,
      'maxOffers': maxOffers,
      'deadline': deadline,
      'isPriceNegotiable': isPriceNegotiable,
      'isActive': isActive,
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? username,
    PostType? type,
    String? title,
    String? description,
    String? category,
    double? price,
    String? location,
    String? locationCity,
    double? locationLat,
    double? locationLng,
    Condition? condition,
    String? brand,
    String? size,
    String? weight,
    String? additionalNotes,
    List<String>? imageUrls,
    String? videoUrl,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool? isLiked,
    int? likesCount,
    int? commentsCount,
    int? currentOffers,
    List<String>? likedBy,
    String? syarat,
    int? maxOffers,
    Timestamp? deadline,
    bool? isPriceNegotiable,
    bool? isActive,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      location: location ?? this.location,
      locationCity: locationCity ?? this.locationCity,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      condition: condition ?? this.condition,
      brand: brand ?? this.brand,
      size: size ?? this.size,
      weight: weight ?? this.weight,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      currentOffers: currentOffers ?? this.currentOffers,
      likedBy: likedBy ?? this.likedBy,
      syarat: syarat ?? this.syarat,
      maxOffers: maxOffers ?? this.maxOffers,
      deadline: deadline ?? this.deadline,
      isPriceNegotiable: isPriceNegotiable ?? this.isPriceNegotiable,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
    id, userId, username, type, title, description, category,
    price, location, locationCity, locationLat, locationLng,
    condition, brand, size, weight, additionalNotes, imageUrls,
    videoUrl, createdAt, updatedAt, isLiked, likesCount,
    commentsCount, currentOffers, likedBy, syarat, maxOffers,
    deadline, isPriceNegotiable, isActive,
  ];
}
