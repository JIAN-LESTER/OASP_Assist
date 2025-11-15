import 'package:cloud_firestore/cloud_firestore.dart';

class Notifications {
  final String notificationId;
  final String? userId;       // null for staff notifications
  final String title;
  final String body;
  final String type;          // e.g., 'escalation', 'message'
  final String relatedId;     // links to escalation or other entity
  final String targetRole;    // 'user' or 'staff'
  final bool read;
  final Timestamp createdAt;
  final Map<String, dynamic>? data; // ✅ New field for additional data

  Notifications({
    required this.notificationId,
    this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.relatedId,
    required this.targetRole,
    this.read = false,
    required this.createdAt,
    this.data,
  });

  // Convert Firestore document to model
  factory Notifications.fromMap(Map<String, dynamic> map) {
    return Notifications(
      notificationId: map['notificationId'] ?? '',
      userId: map['userId'],
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      relatedId: map['relatedId'] ?? '',
      targetRole: map['targetRole'] ?? 'user',
      read: map['read'] ?? false,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      data: Map<String, dynamic>.from(map['data'] ?? {}), // ✅ Safely handle null
    );
  }

  // Convert model to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'targetRole': targetRole,
      'read': read,
      'createdAt': createdAt,
      'data': data, // ✅ Include in Firestore document
    };
  }
}
