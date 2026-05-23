import 'package:cloud_firestore/cloud_firestore.dart';

class EscalatedMessage {
  final String userMessage;
  final String category;
  final String status;
  final DateTime escalatedAt;
  final String? resolvedBy;
  final String? staffResponse;
  final String? userId;
  final String? conversationId;
  final String? escalationId;

  EscalatedMessage({
    required this.userMessage,
    required this.category,
    required this.status,
    required this.escalatedAt,
    this.resolvedBy,
    this.staffResponse,
    this.userId,
    this.conversationId,
    this.escalationId,
  });

  factory EscalatedMessage.fromMap(Map<String, dynamic> map) {
    return EscalatedMessage(
      userMessage: map['question'] ?? 'N/A',  // Based on your Firestore structure
      category: map['category'] ?? 'General',
      status: map['status'] ?? 'pending',
      escalatedAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedBy: map['respondedBy'],  // Your field is 'respondedBy'
      staffResponse: map['staffResponse'],
      userId: map['userId'],
      conversationId: map['conversationId'],
      escalationId: map['escalationId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': userMessage,
      'category': category,
      'status': status,
      'createdAt': Timestamp.fromDate(escalatedAt),
      'respondedBy': resolvedBy,
      'staffResponse': staffResponse,
      'userId': userId,
      'conversationId': conversationId,
      'escalationId': escalationId,
    };
  }
}