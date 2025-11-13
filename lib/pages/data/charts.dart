
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


import 'package:capstone_project/pages/data/reports.dart';
// import 'package:capstone_project/pages/data/reports.dart';

Widget buildStatCard(String title, String value, Color color, IconData icon) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              // Only use Expanded here, inside the card
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20, // Adjusted font size
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class DashboardWidgets {
  // Simplified color scheme
  static const _categoryColors = {
    'admission': Color(0xFF2196F3),
    'scholarship': Color(0xFF4CAF50),
    'placement': Color(0xFFFF9800),
    'general': Color(0xFF9C27B0),
  };

  static const _programColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFF44336),
    Color(0xFF009688),
    Color(0xFF3F51B5),
    Color(0xFFE91E63),
  ];

  static Color getCategoryColor(String category) {
    return _categoryColors[category.toLowerCase()] ?? Colors.grey;
  }

  static Color getProgramColor(String program) {
    return _programColors[program.hashCode % _programColors.length];
  }

  static String shortenProgram(String program) {
    return program
        .split(' ')
        .where(
          (word) =>
              word.isNotEmpty && !{'of', 'in'}.contains(word.toLowerCase()),
        )
        .map((word) => word[0].toUpperCase())
        .join();
  }

  // Simplified chart interval calculations
  static double getChartInterval(List<int> values) {
    if (values.isEmpty) return 1.0;
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    if (maxValue <= 5) return 1.0;
    if (maxValue <= 10) return 2.0;
    if (maxValue <= 25) return 5.0;
    if (maxValue <= 50) return 10.0;
    return (maxValue / 5).ceil().toDouble();
  }

  static Color getHeatmapColor(int value, int maxValue) {
    if (maxValue == 0) return Colors.grey[300]!;

    final intensity = value / maxValue;
    if (intensity > 0.8) return Colors.red[700]!;
    if (intensity > 0.6) return Colors.red[500]!;
    if (intensity > 0.4) return Colors.orange[500]!;
    if (intensity > 0.2) return Colors.yellow[600]!;
    if (intensity > 0) return Colors.blue[300]!;
    return Colors.grey[300]!;
  }
}

Widget buildSystemLogsCard(List<SystemLog> logs) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent System Logs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              logs.isEmpty
                  ? Center(
                    child: Text(
                      'No recent logs available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              getLogIcon(log.action),
                              size: 16,
                              color: getLogColor(log.action),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.action,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'By: ${log.user}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat(
                                'MMMM d, yyyy, hh:mm a',
                              ).format(log.time),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    ),
  );
}



Widget buildMessageLogsCard(List<MessageLogs> msgLogs) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Message Logs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: msgLogs.isEmpty
              ? Center(
                  child: Text(
                    'No recent logs available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : ListView.builder(
                  itemCount: msgLogs.length,
                  itemBuilder: (context, index) {
                    final log = msgLogs[index];

                    // Parse timestamp safely (assuming ISO8601 or millis)
                    DateTime parsedTime;
                    try {
                      parsedTime = DateTime.parse(log.time.toIso8601String());
                    } catch (_) {
                      parsedTime = DateTime.now();
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "User: ${log.user}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Message: ${log.message}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (log.reply.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "Reply: ${log.reply}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy\nhh:mm a').format(parsedTime),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}










// ==================== UTILITY FUNCTIONS FOR EXISTING CHARTS ====================

Color getColorForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'admission':
      return Colors.blue[600]!;
    case 'scholarship':
      return Colors.green[600]!;
    case 'placement':
      return Colors.orange[600]!;
    case 'general':
      return Colors.purple[600]!;
    case 'academic':
      return Colors.teal[600]!;
    case 'financial':
      return Colors.amber[600]!;
    default:
      return Colors.grey[600]!;
  }
}

IconData getLogIcon(String action) {
  switch (action.toLowerCase()) {
    case 'login':
      return Icons.login;
    case 'logout':
      return Icons.logout;
    case 'create':
      return Icons.add;
    case 'update':
      return Icons.edit;
    case 'delete':
      return Icons.delete;
    case 'view':
      return Icons.visibility;
    default:
      return Icons.info;
  }
}

Color getLogColor(String action) {
  switch (action.toLowerCase()) {
    case 'login':
      return Colors.green;
    case 'logout':
      return Colors.orange;
    case 'create':
      return Colors.blue;
    case 'update':
      return Colors.amber;
    case 'delete':
      return Colors.red;
    case 'view':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

List<Color> getbar(String type) {
  switch (type.toLowerCase()) {
    case 'liked':
      return [Colors.green[400]!, Colors.green[600]!];
    case 'neutral':
      return [Colors.grey[400]!, Colors.grey[600]!];
    case 'disliked':
      return [Colors.red[400]!, Colors.red[600]!];
    default:
      return [Colors.blue[400]!, Colors.blue[600]!];
  }
}