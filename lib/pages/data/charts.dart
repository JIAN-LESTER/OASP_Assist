import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:capstone_project/pages/data/reports.dart';

// Enhanced Stat Card with minimal, professional design
Widget buildStatCard(String title, String value, Color color, IconData icon) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1100;

      final padding = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
      final iconSize = isMobile ? 20.0 : (isTablet ? 22.0 : 24.0);
      final valueFontSize = isMobile ? 20.0 : (isTablet ? 24.0 : 28.0);
      final titleFontSize = isMobile ? 12.0 : (isTablet ? 13.0 : 14.0);

      return Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: iconSize),
            ),
            const SizedBox(height: 16),
            // Value
            Text(
              value,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: titleFontSize,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    },
  );
}

class DashboardWidgets {
  static const _categoryColors = {
    'admission': Color(0xFF3B82F6),
    'scholarship': Color(0xFF10B981),
    'placement': Color(0xFFF59E0B),
    'general': Color(0xFF8B5CF6),
  };

  static const _programColors = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFF6366F1),
    Color(0xFFEC4899),
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
    if (maxValue == 0) return Colors.grey[200]!;

    final intensity = value / maxValue;
    if (intensity > 0.8) return const Color(0xFFDC2626);
    if (intensity > 0.6) return const Color(0xFFEF4444);
    if (intensity > 0.4) return const Color(0xFFF59E0B);
    if (intensity > 0.2) return const Color(0xFFFBBF24);
    if (intensity > 0) return const Color(0xFF60A5FA);
    return Colors.grey[200]!;
  }
}

// System Logs Card
Widget buildSystemLogsCard(List<SystemLog> logs) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      return Container(
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: Colors.grey[700],
                  size: isMobile ? 22 : 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Activity',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${logs.length} recent events',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 20 : 24),

            // Logs List
            Expanded(
              child:
                  logs.isEmpty
                      ? _buildEmptyState(
                        icon: Icons.inbox_outlined,
                        message: 'No activity yet',
                        isMobile: isMobile,
                      )
                      : ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder:
                            (context, index) =>
                                Divider(height: 1, color: Colors.grey[100]),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return _buildSystemLogItem(log, isMobile);
                        },
                      ),
            ),
          ],
        ),
      );
    },
  );
}

//  Message Logs Card
Widget buildMessageLogsCard(List<MessageLogs> msgLogs) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      return Container(
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //  Header
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.grey[700],
                  size: isMobile ? 22 : 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conversations',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${msgLogs.length} messages',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 20 : 24),

            // Message Logs List
            Expanded(
              child:
                  msgLogs.isEmpty
                      ? _buildEmptyState(
                        icon: Icons.forum_outlined,
                        message: 'No conversations yet',
                        isMobile: isMobile,
                      )
                      : ListView.separated(
                        itemCount: msgLogs.length,
                        separatorBuilder:
                            (context, index) =>
                                SizedBox(height: isMobile ? 12 : 16),
                        itemBuilder: (context, index) {
                          final log = msgLogs[index];
                          return _buildMessageLogItem(log, isMobile);
                        },
                      ),
            ),
          ],
        ),
      );
    },
  );
}

//  System Log Item
Widget _buildSystemLogItem(SystemLog log, bool isMobile) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16, horizontal: 4),
    child: Row(
      children: [
        //  icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: getLogColor(log.action).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            getLogIcon(log.action),
            size: 20,
            color: getLogColor(log.action),
          ),
        ),
        const SizedBox(width: 14),

        // Log details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.action,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                log.user,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        //  timestamp
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('MMM d').format(log.time),
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('h:mm a').format(log.time),
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

//  Message Log Item
Widget _buildMessageLogItem(MessageLogs log, bool isMobile) {
  return Container(
    padding: EdgeInsets.all(isMobile ? 16 : 18),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            // User avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  log.user[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                log.user,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _getRelativeTime(log.time),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // User Message
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            log.message,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Bot Reply
        if (log.reply.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.reply,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

//  Empty State
Widget _buildEmptyState({
  required IconData icon,
  required String message,
  required bool isMobile,
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: isMobile ? 80 : 96,
          height: isMobile ? 80 : 96,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: isMobile ? 36 : 42, color: Colors.grey[300]),
        ),
        SizedBox(height: isMobile ? 16 : 20),
        Text(
          message,
          style: TextStyle(
            fontSize: isMobile ? 14 : 15,
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ],
    ),
  );
}

// Helper function to get relative time
String _getRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) return 'Now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  return DateFormat('MMM d').format(dateTime);
}

// Utility functions
IconData getLogIcon(String action) {
  switch (action.toLowerCase()) {
    case 'login':
      return Icons.login_rounded;
    case 'logout':
      return Icons.logout_rounded;
    case 'create':
      return Icons.add_circle_outline_rounded;
    case 'update':
      return Icons.edit_outlined;
    case 'delete':
      return Icons.delete_outline_rounded;
    case 'view':
      return Icons.visibility_outlined;
    default:
      return Icons.info_outline_rounded;
  }
}

Color getLogColor(String action) {
  switch (action.toLowerCase()) {
    case 'login':
      return const Color(0xFF10B981);
    case 'logout':
      return const Color(0xFFF59E0B);
    case 'create':
      return const Color(0xFF3B82F6);
    case 'update':
      return const Color(0xFF8B5CF6);
    case 'delete':
      return const Color(0xFFEF4444);
    case 'view':
      return const Color(0xFF6B7280);
    default:
      return const Color(0xFF6B7280);
  }
}

Color getColorForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'admission':
      return const Color(0xFF3B82F6);
    case 'scholarship':
      return const Color(0xFF10B981);
    case 'placement':
      return const Color(0xFFF59E0B);
    case 'general':
      return const Color(0xFF8B5CF6);
    case 'academic':
      return const Color(0xFF06B6D4);
    case 'financial':
      return const Color(0xFFFBBF24);
    default:
      return const Color(0xFF6B7280);
  }
}

List<Color> getbar(String type) {
  switch (type.toLowerCase()) {
    case 'liked':
      return [const Color(0xFF34D399), const Color(0xFF10B981)];
    case 'neutral':
      return [const Color(0xFF9CA3AF), const Color(0xFF6B7280)];
    case 'disliked':
      return [const Color(0xFFF87171), const Color(0xFFEF4444)];
    default:
      return [const Color(0xFF60A5FA), const Color(0xFF3B82F6)];
  }
}
