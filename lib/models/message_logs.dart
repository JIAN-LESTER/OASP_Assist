

class MessageLogs {
  final String id;
  final String user;
  final String message;
  final String reply;
  final String time;


  MessageLogs({
    required this.id,
    required this.user,
    required this.message,
    required this.reply,
    required this.time,
  });

  factory MessageLogs.fromJson(Map<String, dynamic> json) {
    return MessageLogs(
      id: json['id'],
      user: json['user'],
      message: json['message'],
      reply: json['reply'],
      time: json['time'],
    );
  }

   @override
  String toString() {
    return id;
  }

}
