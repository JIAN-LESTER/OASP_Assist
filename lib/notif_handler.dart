// Add this to your main.dart or root widget where you initialize NotificationService

import 'package:capstone_project/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationNavigationHandler {
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationNavigationHandler(this.navigatorKey);

  // Call this during app initialization
  void setup() {
    NotificationService().setNavigationHandler(_handleNavigation);
  }

  void _handleNavigation(String type, Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('⚠️ No navigator context available');
      return;
    }

    print('📍 Navigating to: $type with data: $data');

    switch (type) {
      case 'escalation_detail':
        _navigateToEscalationDetail(context, data);
        break;
      case 'escalation_response':
        _showEscalationResponse(context, data);
        break;
      case 'announcement':
        _navigateToAnnouncement(context, data);
        break;
      case 'announcements_list':
        _navigateToAnnouncementsList(context);
        break;
    }
  }

  // Staff: Navigate to escalation detail
  void _navigateToEscalationDetail(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final escalationId = data['escalationId'];
    if (escalationId == null || escalationId.isEmpty) {
      print('⚠️ No escalation ID provided');
      return;
    }

    // Navigate to Human Escalation screen with the specific escalation
    Navigator.of(context).pushNamed(
      '/staff/escalations', // Your staff escalation route
      arguments: {
        'escalationId': escalationId,
        'autoOpen': true, // Flag to auto-open the dialog
      },
    );
  }

  // User: Show escalation response dialog
  Future<void> _showEscalationResponse(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final escalationId = data['escalationId'];
    if (escalationId == null || escalationId.isEmpty) {
      print('⚠️ No escalation ID provided');
      return;
    }

    try {
      // Fetch escalation details
      final escalationDoc = await FirebaseFirestore.instance
          .collection('escalations')
          .where('escalationId', isEqualTo: escalationId)
          .limit(1)
          .get();

      if (escalationDoc.docs.isEmpty) {
        _showErrorDialog(context, 'Escalation not found');
        return;
      }

      final escalation = escalationDoc.docs.first.data();
      final staffResponse = escalation['staffResponse'] ?? 'No response yet';
      final respondedBy = escalation['respondedBy'] ?? 'Staff';
      final respondedAt = escalation['respondedAt'] as Timestamp?;

      // Show response dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.support_agent,
                  color: Color(0xFF2E7D32),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Response',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (respondedAt != null)
                      Text(
                        _formatTimestamp(respondedAt.toDate()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Original question
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.question_answer,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Your Question',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        escalation['question'] ?? 'No question available',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Staff response
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2E7D32).withOpacity(0.1),
                        Color(0xFF388E3C).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(0xFF2E7D32).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.support_agent,
                            size: 16,
                            color: Color(0xFF2E7D32),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Response from $respondedBy',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        staffResponse,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to conversation
                final conversationId = escalation['conversationId'];
                if (conversationId != null) {
                  Navigator.of(context).pushNamed(
                    '/chat',
                    arguments: {'conversationId': conversationId},
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'View Chat',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error fetching escalation: $e');
      _showErrorDialog(context, 'Failed to load response');
    }
  }

  // Navigate to announcement detail
  void _navigateToAnnouncement(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final announcementId = data['announcementId'];
    if (announcementId == null || announcementId.isEmpty) {
      print('⚠️ No announcement ID provided');
      return;
    }

    Navigator.of(context).pushNamed(
      '/announcements/detail',
      arguments: {'announcementId': announcementId},
    );
  }

  // Navigate to announcements list
  void _navigateToAnnouncementsList(BuildContext context) {
    Navigator.of(context).pushNamed('/announcements');
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

// Usage in main.dart:
// void main() {
//   final navigatorKey = GlobalKey<NavigatorState>();
//   
//   runApp(MyApp(navigatorKey: navigatorKey));
//   
//   // After NotificationService().initialize()
//   NotificationNavigationHandler(navigatorKey).setup();
// }