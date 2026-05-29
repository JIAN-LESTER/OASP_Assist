import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String conversationId;
  late final String content;
  final String sender; // 'user', 'bot', 'staff', 'system'
  final String? userID;
  final String status; // 'sent', 'read', 'error'
  final String type; // 'text', 'image', etc.
  final String? category;
  final DateTime sentAt;
  final DateTime? respondedAt;
  final bool? isAnswered;
  final String? rating; // 'like', 'dislike', null
  final int? count;
  final int? similarityCount;

  //   Escalation fields
  final bool? escalationResolved;
  final String? escalationResponse;
  final String? escalationRespondedBy;
  final DateTime? escalationRespondedAt;
  final String? escalationId;

  Message({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.sender,
    this.userID,
    required this.status,
    required this.type,
    this.category,
    required this.sentAt,
    this.respondedAt,
    this.isAnswered,
    this.rating,
    this.count,
    this.similarityCount,
    //   Escalation parameters
    this.escalationResolved,
    this.escalationResponse,
    this.escalationRespondedBy,
    this.escalationRespondedAt,
    this.escalationId,
  });

  // Convert Firestore document to Message object
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['messageID'] ?? '',
      conversationId: json['conversationID'] ?? '',
      content: json['content'] ?? '',
      sender: json['sender'] ?? 'user',
      userID: json['userID'],
      status: json['message_status'] ?? 'sent',
      type: json['message_type'] ?? 'text',
      category: json['category'],
      sentAt: (json['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (json['responded_at'] as Timestamp?)?.toDate(),
      isAnswered: json['isAnswered'] as bool?,
      rating: json['rating'] as String?,
      count: json['count'] as int?,
      similarityCount: json['similarityCount'] as int?,
      //   Parse escalation fields
      escalationResolved: json['escalationResolved'] as bool?,
      escalationResponse: json['escalationResponse'] as String?,
      escalationRespondedBy: json['escalationRespondedBy'] as String?,
      escalationRespondedAt:
          (json['escalationRespondedAt'] as Timestamp?)?.toDate(),
      escalationId: json['escalationId'] as String?,
    );
  }

  // Convert Message object to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'messageID': id,
      'conversationID': conversationId,
      'content': content,
      'sender': sender,
      'userID': userID,
      'message_status': status,
      'message_type': type,
      'category': category,
      'sent_at': Timestamp.fromDate(sentAt),
      'responded_at':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'isAnswered': isAnswered ?? false,
      'rating': rating,
      'count': count,
      'similarityCount': similarityCount ?? 0,
      //   Include escalation fields
      'escalationResolved': escalationResolved,
      'escalationResponse': escalationResponse,
      'escalationRespondedBy': escalationRespondedBy,
      'escalationRespondedAt':
          escalationRespondedAt != null
              ? Timestamp.fromDate(escalationRespondedAt!)
              : null,
      'escalationId': escalationId,
    };
  }

  // Create a copy with updated fields
  Message copyWith({
    String? id,
    String? conversationId,
    String? content,
    String? sender,
    String? userID,
    String? status,
    String? type,
    String? category,
    DateTime? sentAt,
    DateTime? respondedAt,
    bool? isAnswered,
    String? rating,
    int? count,
    int? similarityCount,
    bool? escalationResolved,
    String? escalationResponse,
    String? escalationRespondedBy,
    DateTime? escalationRespondedAt,
    String? escalationId,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      userID: userID ?? this.userID,
      status: status ?? this.status,
      type: type ?? this.type,
      category: category ?? this.category,
      sentAt: sentAt ?? this.sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      isAnswered: isAnswered ?? this.isAnswered,
      rating: rating ?? this.rating,
      count: count ?? this.count,
      similarityCount: similarityCount ?? this.similarityCount,
      escalationResolved: escalationResolved ?? this.escalationResolved,
      escalationResponse: escalationResponse ?? this.escalationResponse,
      escalationRespondedBy:
          escalationRespondedBy ?? this.escalationRespondedBy,
      escalationRespondedAt:
          escalationRespondedAt ?? this.escalationRespondedAt,
      escalationId: escalationId ?? this.escalationId,
    );
  }
}
