// File: program/lib/fitur/notification/domain/entities/notification_entity.dart
class NotificationEntity {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String type; // 'chat', 'announcement', 'system'
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final bool isRead;
  final String? senderId; // untuk chat notifications
  final String? senderName;

  NotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.type,
    this.data,
    required this.createdAt,
    this.isRead = false,
    this.senderId,
    this.senderName,
  });

  factory NotificationEntity.fromMap(String id, Map<String, dynamic> map) {
    return NotificationEntity(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      imageUrl: map['imageUrl'],
      type: map['type'] ?? 'system',
      data: map['data'] as Map<String, dynamic>?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      isRead: map['isRead'] ?? false,
      senderId: map['senderId'],
      senderName: map['senderName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'type': type,
      'data': data,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isRead': isRead,
      'senderId': senderId,
      'senderName': senderName,
    };
  }

  NotificationEntity copyWith({bool? isRead}) {
    return NotificationEntity(
      id: id,
      title: title,
      body: body,
      imageUrl: imageUrl,
      type: type,
      data: data,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      senderId: senderId,
      senderName: senderName,
    );
  }
}
