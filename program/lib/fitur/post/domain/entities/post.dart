import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Jenis postingan yang didukung:
/// - jastip: Jual barang langsung oleh jastiper
/// - request: Permintaan barang oleh pembeli
/// - short: Video pendek promosi (mirip TikTok/Reels)
enum PostType { jastip, request, short }

/// Kondisi barang yang dijual/diminta
enum Condition { baru, bekas }

class Post extends Equatable {
  final String id;
  final String userId;
  final String username;
  final PostType type;
  final String title;
  final String description;
  final String category;
  final double? price; // Hanya untuk jastip & short
  final String location; // Lokasi umum (misal: "Surabaya")
  final String locationCity; // Nama kota/kabupaten (untuk filter & GeoNames)
  final double? locationLat; // Latitude dari GeoNames API
  final double? locationLng; // Longitude dari GeoNames API
  final Condition condition;
  final String? brand;
  final String? size;
  final String? weight;
  final String? additionalNotes;
  final List<String> imageUrls; // Boleh kosong jika ada video
  final String? videoUrl; // Boleh null jika hanya gambar
  final Timestamp createdAt;
  final int likesCount;
  final int commentsCount;
  final int offersCount;
  final bool isActive;

  // === Field khusus untuk PostType.request ===
  final String? syarat; // Toleransi kenaikan harga (misal: "Maks 10%")
  final int? maxOffers; // Batas jumlah penawaran dari jastiper
  final Timestamp? deadline; // Batas waktu request
  final bool isPriceNegotiable; // Apakah harga bisa dinegosiasi

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
    required this.locationCity,
    this.locationLat,
    this.locationLng,
    required this.condition,
    this.brand,
    this.size,
    this.weight,
    this.additionalNotes,
    required this.imageUrls,
    this.videoUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.offersCount = 0,
    this.isActive = true,
    this.syarat,
    this.maxOffers,
    this.deadline,
    this.isPriceNegotiable = false,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] as String,
      username: data['username'] as String,
      type: _parsePostType(data['type'] as String?),
      title: data['title'] as String,
      description: data['description'] as String,
      category: data['category'] as String,
      price: (data['price'] as num?)?.toDouble(),
      location: data['location'] as String,
      locationCity: data['locationCity'] as String,
      locationLat: (data['locationLat'] as num?)?.toDouble(),
      locationLng: (data['locationLng'] as num?)?.toDouble(),
      condition: _parseCondition(data['condition'] as String?),
      brand: data['brand'] as String?,
      size: data['size'] as String?,
      weight: data['weight'] as String?,
      additionalNotes: data['additionalNotes'] as String?,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrl: data['videoUrl'] as String?,
      createdAt: data['createdAt'] as Timestamp,
      likesCount: data['likesCount'] as int? ?? 0,
      commentsCount: data['commentsCount'] as int? ?? 0,
      offersCount: data['offersCount'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      syarat: data['syarat'] as String?,
      maxOffers: data['maxOffers'] as int?,
      deadline: data['deadline'] as Timestamp?,
      isPriceNegotiable: data['isPriceNegotiable'] as bool? ?? false,
    );
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
    if (condition == 'bekas') return Condition.bekas;
    return Condition.baru;
  }

  Map<String, dynamic> toFirestore() {
    // Validasi: minimal ada gambar atau video
    if (imageUrls.isEmpty && videoUrl == null) {
      throw Exception('Post harus memiliki gambar atau video.');
    }

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
      'condition': condition.name,
      'brand': brand,
      'size': size,
      'weight': weight,
      'additionalNotes': additionalNotes,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'createdAt': createdAt,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'offersCount': offersCount,
      'isActive': isActive,
      'syarat': syarat,
      'maxOffers': maxOffers,
      'deadline': deadline,
      'isPriceNegotiable': isPriceNegotiable,
    };
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    username,
    type,
    title,
    description,
    price,
    location,
    locationCity,
    locationLat,
    locationLng,
    condition,
    brand,
    size,
    weight,
    additionalNotes,
    imageUrls,
    videoUrl,
    createdAt,
    likesCount,
    commentsCount,
    offersCount,
    isActive,
    syarat,
    maxOffers,
    deadline,
    isPriceNegotiable,
  ];
}