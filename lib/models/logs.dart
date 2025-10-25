

class Logs {
  final String id;
  final String user;
  final String action;
  final String time;

  Logs({
    required this.id,
    required this.user,
    required this.action,
    required this.time,
  });

  factory Logs.fromJson(Map<String, dynamic> json) {
    return Logs(
      id: json['id'],
      user: json['user'],
      action: json['action'],
      time: json['time'],
    );
  }

  @override
  String toString() {
    return id;
  }
}
