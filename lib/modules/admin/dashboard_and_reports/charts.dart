import 'package:capstone_project/modules/admin/dashboard_and_reports/inquiry_trends_dialog.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/reports.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

Widget buildStatCard(
  String title,
  String value,
  Color color,
  IconData icon, {
  VoidCallback? onTap,
  String? rateLabel,
  double? rateValue,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1100;

      final padding = isMobile ? 12.0 : (isTablet ? 14.0 : 16.0);
      final iconPadding = isMobile ? 6.0 : (isTablet ? 7.0 : 8.0);
      final iconSize = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
      final valueFontSize = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
      final titleFontSize = isMobile ? 10.0 : (isTablet ? 11.0 : 12.0);
      final rateFontSize = isMobile ? 9.0 : (isTablet ? 10.0 : 11.0);
      final spacing = isMobile ? 8.0 : (isTablet ? 10.0 : 12.0);
      final borderRadius = isMobile ? 10.0 : 12.0;
      final borderWidth = isMobile ? 3.0 : 4.0;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: Icon and Value
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(iconPadding),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: iconSize),
                          ),
                          SizedBox(width: isMobile ? 6 : 8),
                          Expanded(
                            child: _buildAdaptiveValueText(
                              value,
                              valueFontSize + 2,
                              const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right side: Rate badge (if provided)
                    if (rateLabel != null && rateValue != null)
                      Container(
                        margin: EdgeInsets.only(left: isMobile ? 4 : 6),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 6 : 8,
                          vertical: isMobile ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${rateValue.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: rateFontSize,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: spacing),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.arrow_forward_ios,
                        size: isMobile ? 10 : 12,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildAdaptiveValueText(String value, double baseFontSize, Color color) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: baseFontSize,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: constraints.maxWidth);

      final needsTwoLines = textPainter.didExceedMaxLines;
      final adjustedFontSize =
          needsTwoLines ? baseFontSize * 0.85 : baseFontSize;
      final lineHeight = 1.2;
      final singleLineHeight = baseFontSize * lineHeight;
      final containerHeight = singleLineHeight * 2;

      return SizedBox(
        height: containerHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: adjustedFontSize,
              fontWeight: FontWeight.bold,
              color: color,
              height: lineHeight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    },
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

// Enhanced System Logs Card with modern design
Widget buildSystemLogsCard(
  List<SystemLog> logs,
  String timeFrame,
  BuildContext context,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      return Container(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDBEAFE), Color(0xFFEFF6FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF93C5FD),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: Color(0xFF1D4ED8),
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent System Logs',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      Text(
                        '${logs.length} recent activities',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // See More Button
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) =>
                              SystemLogsDetailDialog(timeFrame: timeFrame),
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward,
                    size: isMobile ? 14 : 16,
                    color: Colors.blue[700],
                  ),
                  label: Text(
                    'See more',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 14 : 20),
            Expanded(
              child:
                  logs.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: isMobile ? 40 : 48,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            Text(
                              'No system logs available',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.separated(
                        itemCount: logs.length > 5 ? 5 : logs.length,
                        separatorBuilder:
                            (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return _buildSystemLogItem(log, isMobile, false);
                        },
                      ),
            ),
          ],
        ),
      );
    },
  );
}

// Enhanced Message Logs Card with modern design
Widget buildMessageLogsCard(
  List<MessageLogs> msgLogs,
  String timeFrame,
  BuildContext context,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      return Container(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF86EFAC),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF15803D),
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Conversations',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      Text(
                        '${msgLogs.length} recent messages',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // See More Button
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) =>
                              MessageLogsDetailDialog(timeFrame: timeFrame),
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward,
                    size: isMobile ? 14 : 16,
                    color: Colors.green[700],
                  ),
                  label: Text(
                    'See more',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 14 : 20),
            Expanded(
              child:
                  msgLogs.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mark_chat_unread_outlined,
                              size: isMobile ? 40 : 48,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            Text(
                              'No recent conversations',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.separated(
                        itemCount: msgLogs.length > 5 ? 5 : msgLogs.length,
                        separatorBuilder:
                            (context, index) =>
                                SizedBox(height: isMobile ? 10 : 12),
                        itemBuilder: (context, index) {
                          final log = msgLogs[index];
                          return _buildMessageLogItem(log, isMobile, false);
                        },
                      ),
            ),
          ],
        ),
      );
    },
  );
}

// System Log Item with enhanced design
Widget _buildSystemLogItem(SystemLog log, bool isMobile, bool isTablet) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: isMobile ? 10 : 12,
      vertical: isMobile ? 10 : 12,
    ),
    child: Row(
      children: [
        // Action icon with colored background
        Container(
          padding: EdgeInsets.all(isMobile ? 8 : 10),
          decoration: BoxDecoration(
            color: getLogColor(log.action).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            getLogIcon(log.action),
            size: isMobile ? 18 : 20,
            color: getLogColor(log.action),
          ),
        ),
        SizedBox(width: isMobile ? 10 : 12),

        // Log details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.action,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: isMobile ? 12 : 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      log.user,
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Timestamp
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('MMM d').format(log.time),
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Text(
              DateFormat('h:mm a').format(log.time),
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// Message Log Item with enhanced design
Widget _buildMessageLogItem(MessageLogs log, bool isMobile, bool isTablet) {
  return Container(
    padding: EdgeInsets.all(isMobile ? 12 : 14),

    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with user and timestamp
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: isMobile ? 14 : 16,
                color: Colors.white,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 10),
            Expanded(
              child: Text(
                log.user,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFC7D2FE), width: 1),
              ),
              child: Text(
                _getRelativeTime(log.time),
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF4338CA),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 8 : 10),

        // User Message
        Container(
          padding: EdgeInsets.all(isMobile ? 8 : 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: isMobile ? 14 : 16,
                color: Colors.blue[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.message,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Bot Reply (if exists)
        if (log.reply.isNotEmpty) ...[
          SizedBox(height: isMobile ? 6 : 8),
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  size: isMobile ? 14 : 16,
                  color: Colors.green[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.reply,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                    maxLines: 2,
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

// Empty state widget
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
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: isMobile ? 40 : 48, color: Colors.grey[400]),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Text(
          message,
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
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

  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return DateFormat('MMM d').format(dateTime);
  }
}

// Utility functions (keep existing ones)
IconData getLogIcon(String action) {
  switch (action.toLowerCase()) {
    case 'login':
      return Icons.login;
    case 'logout':
      return Icons.logout;
    case 'create':
      return Icons.add_circle_outline;
    case 'update':
      return Icons.edit_outlined;
    case 'delete':
      return Icons.delete_outline;
    case 'view':
      return Icons.visibility_outlined;
    default:
      return Icons.info_outline;
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
