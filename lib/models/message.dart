import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String conversationId;
  final String content;
  final String sender;
  final String status;
  final String type;
  final bool isAnswered;
  final String? userID;
  final String? category;
  final DateTime sentAt;
  final DateTime? respondedAt;
  final int? count;

  final String? rating; // 'like' or 'dislike'

  Message({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.sender,
    this.userID,
    this.isAnswered = false,
    required this.status,
    this.category,
    required this.type,
    required this.sentAt,
    this.respondedAt,
    this.count,
    this.rating,

  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['messageID'],
      conversationId: json['conversationID'],
      content: json['content'],
      sender: json['sender'],
      status: json['message_status'],
      type: json['message_type'],
      userID: json['userID'],
      isAnswered: json['isAnswered'] ?? false,
      category: json['category'],
      sentAt: (json['sent_at'] as Timestamp).toDate(),
      respondedAt:
          json['responded_at'] != null
              ? (json['responded_at'] as Timestamp).toDate()
              : null,

      rating: json['rating'],
      count: json['count'],

    );
  }
}
