  import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


class CategoryStyle {
  final String displayName;
  final Color backgroundColor;
  final Color textColor;

  CategoryStyle(this.displayName, this.backgroundColor, this.textColor);
}

/// Returns the full style (with display name, bg, text color)
CategoryStyle getCategoryStyle(String category) {
  switch (category.toLowerCase()) {
    case 'admission':
      return CategoryStyle('Admission', Colors.blue, Colors.white);
    case 'scholarship':
      return CategoryStyle('Scholarship', Colors.red, Colors.white);
    case 'placement':
      return CategoryStyle('Placement', Colors.yellow, Colors.black);
    case 'general':
      return CategoryStyle('General', Colors.green, Colors.white);
    default:
      return CategoryStyle('Unknown', Colors.grey, Colors.white);
  }
}

/// Returns only the background color (for charts, etc.)
Color getColorForCategory(String category) {
  return getCategoryStyle(category).backgroundColor;
}

/// Returns a background tint color depending on action keywords
Color getActionColor(String action) {
  final lowerAction = action.toLowerCase();

  if (lowerAction.contains('delete')) {
    return Colors.red[50]!;
  } else if (lowerAction.contains('create') || lowerAction.contains('add')) {
    return Colors.green[50]!;
  } else if (lowerAction.contains('update') || lowerAction.contains('edit')) {
    return Colors.orange[50]!;
  } else if (lowerAction.contains('login') || lowerAction.contains('logout')) {
    return Colors.purple[50]!;
  } else {
    return Colors.blue[50]!;
  }
}

IconData getLogIcon(String type) {
  switch (type.toLowerCase()) {
    case 'error':
      return Icons.error;
    case 'warning':
      return Icons.warning;
    case 'success':
      return Icons.check_circle;
    default:
      return Icons.info;
  }
}

Color getLogColor(String type) {
  switch (type.toLowerCase()) {
    case 'error':
      return Colors.red;
    case 'warning':
      return Colors.orange;
    case 'success':
      return Colors.green;
    default:
      return Colors.blue;
  }
}

List<Color> getbar(String label) {
  switch (label.toLowerCase()) {
    case 'like':
      return [Colors.green, Colors.lightGreen];
    case 'dislike':
      return [Colors.red, Colors.redAccent];
    case 'neutral':
      return [Colors.grey, Colors.blueGrey];
    default:
      return [Colors.blueGrey, Colors.grey];
  }
}

IconData getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'admission':
        return Icons.school;
      case 'scholarship':
        return Icons.event;
      case 'placement':
        return Icons.priority_high;
      case 'general':
        return Icons.info;
      default:
        return Icons.campaign;
    }
  }

  Color getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'admission':
        return Colors.blue;
      case 'scholarship':
        return Colors.purple;
      case 'placement':
        return Colors.red;
      case 'general':
        return Colors.green;
      default:
        return Colors.green;
    }
  }


  String formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData getNotificationIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'announcement':
        return Icons.campaign_rounded;
      case 'deadline_reminder':
        return Icons.alarm_on_rounded;
      case 'escalation_reply':
        return Icons.reply_rounded;
      case 'new_escalation':
        return Icons.help_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color getNotificationColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'announcement':
        return const Color(0xFF2E7D32);
      case 'deadline_reminder':
        return const Color(0xFFFF6F00);
      case 'escalation_reply':
        return const Color(0xFF1976D2);
      case 'new_escalation':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFF2E7D32);
    }
  }

