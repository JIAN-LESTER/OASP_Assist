
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


import 'package:capstone_project/pages/data/reports.dart';
// import 'package:capstone_project/pages/data/reports.dart';

Widget buildStatCard(String title, String value, Color color, IconData icon) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1100;
      
      // Responsive sizing
      final padding = isMobile ? 12.0 : (isTablet ? 14.0 : 16.0);
      final iconPadding = isMobile ? 6.0 : (isTablet ? 7.0 : 8.0);
      final iconSize = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
      final valueFontSize = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
      final titleFontSize = isMobile ? 10.0 : (isTablet ? 11.0 : 12.0);
      final spacing = isMobile ? 8.0 : (isTablet ? 10.0 : 12.0);
      final borderRadius = isMobile ? 10.0 : 12.0;
      final borderWidth = isMobile ? 3.0 : 4.0;
      
      return Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border(
            left: BorderSide(
              color: color,
              width: borderWidth,
            ),
          ),
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
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: iconSize),
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            Text(
              title,
              style: TextStyle(
                fontSize: titleFontSize,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
Widget buildSystemLogsCard(List<SystemLog> logs) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1100;

      return Container(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
           border: Border(
        
      ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history,
                    color: Colors.blue[700],
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
              ],
            ),
            SizedBox(height: isMobile ? 14 : 20),
            
            // Logs List
            Expanded(
              child: logs.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.inventory_2_outlined,
                      message: 'No system logs available',
                      isMobile: isMobile,
                    )
                  : ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return _buildSystemLogItem(log, isMobile, isTablet);
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
Widget buildMessageLogsCard(List<MessageLogs> msgLogs) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1100;

      return Container(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
           border: Border(
        
      ),
          
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.green[700],
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
              ],
            ),
            SizedBox(height: isMobile ? 14 : 20),
            
            // Message Logs List
            Expanded(
              child: msgLogs.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.mark_chat_unread_outlined,
                      message: 'No recent conversations',
                      isMobile: isMobile,
                    )
                  : ListView.separated(
                      itemCount: msgLogs.length,
                      separatorBuilder: (context, index) => SizedBox(height: isMobile ? 10 : 12),
                      itemBuilder: (context, index) {
                        final log = msgLogs[index];
                        return _buildMessageLogItem(log, isMobile, isTablet);
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
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with user and timestamp
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: isMobile ? 14 : 16,
                color: Colors.green[700],
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getRelativeTime(log.time),
                style: TextStyle(
                  fontSize: isMobile ? 10 : 11,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
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
          child: Icon(
            icon,
            size: isMobile ? 40 : 48,
            color: Colors.grey[400],
          ),
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