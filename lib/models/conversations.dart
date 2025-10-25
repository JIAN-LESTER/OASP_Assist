class Conversation {
  final String id;
  final String userId;
  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime? endedAt;     
  final int messageCount;      
       

  Conversation({
    required this.id,
    required this.userId,
    required this.title,
    required this.status,
    required this.createdAt,
    this.endedAt,
    this.messageCount = 0,

  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['conversationID'] as String? ?? '',
      userId: json['userID'] as String? ?? '',
      title: json['conversation_title'] as String? ?? 'Untitled',
      status: json['conversation_status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'])
          : null,
      messageCount: json['message_count'] as int? ?? 0,
     
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationID': id,
      'userID': userId,
      'conversation_title': title,
      'conversation_status': status,
      'created_at': createdAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'message_count': messageCount,
    
    };
  }
}
