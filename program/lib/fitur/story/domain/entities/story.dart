import 'package:cloud_firestore/cloud_firestore.dart';

enum StoryType { image, video }

class Story {
  final String id;
  final String userId;
  final String username;
  final String? profileImageUrl;
  final String mediaUrl;
  final String? text;
  final StoryType type;
  final bool isActive;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy; // user IDs yang sudah melihat

  Story({
    required this.id,
    required this.userId,
    required this.username,
    this.profileImageUrl,
    required this.mediaUrl,
    this.text,
    required this.type,
    this.isActive = true,
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
  });

  factory Story.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      mediaUrl: data['mediaUrl'] ?? '',
      text: data['text'],
      type: StoryType.values.firstWhere(
            (e) => e.name == data['type'],
        orElse: () => StoryType.image,
      ),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(Duration(minutes: 2)),
      viewedBy: List<String>.from(data['viewedBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'mediaUrl': mediaUrl,
      'text': text,
      'type': type.name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewedBy': viewedBy,
    };
  }

  Story copyWith({
    String? id,
    String? userId,
    String? username,
    String? profileImageUrl,
    String? mediaUrl,
    String? text,
    StoryType? type,
    bool? isActive,
    DateTime? createdAt,
    DateTime? expiresAt,
    List<String>? viewedBy,
  }) {
    return Story(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      text: text ?? this.text,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewedBy: viewedBy ?? this.viewedBy,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool hasBeenViewedBy(String userId) => viewedBy.contains(userId);
}
