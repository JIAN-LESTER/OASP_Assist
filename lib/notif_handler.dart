// Add this to your main.dart or root widget where you initialize NotificationService

import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/main.dart';
import 'package:capstone_project/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationNavigationHandler {
  final GlobalKey<NavigatorState> navigatorKey;
  String? _cachedUserRole; // ✅ Cache the role

  NotificationNavigationHandler(this.navigatorKey);

  void setup() {
    NotificationService().setNavigationHandler(_handleNavigation);
    _initializeUserRole(); // ✅ Initialize role on setup
    _listenToRoleChanges(); // ✅ Start listening to role changes
    print('✅ Navigation handler registered');
  }

  Future<void> initializeServices() async {
  try {
    print('🚀 Initializing services...');
    
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('✅ Background handler registered');
    
    await NotificationService().initialize(); // ✅ Make this await
    print('✅ Notifications ready');
    
    NotificationNavigationHandler(navigatorKey).setup();
    
    print('✅ Core services initialized');
  } catch (e, stackTrace) {
    print('⚠️ Service init warning: $e');
    print('Stack: $stackTrace');
  }
}
// Add to your initialization
  Future<void> _initializeUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          _cachedUserRole = userDoc.data()?['role'] ?? 'user';
          print('✅ Cached user role: $_cachedUserRole');
        }
      }
    } catch (e) {
      print('⚠️ Error caching user role: $e');
      _cachedUserRole = 'user'; // Safe fallback
    }
  }

   Future<String> _getUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return _cachedUserRole ?? 'user';
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final role = userDoc.data()?['role'] ?? 'user';
        _cachedUserRole = role; // Update cache
        return role;
      }
      
      return _cachedUserRole ?? 'user';
    } catch (e) {
      print('⚠️ Error fetching role, using cache: $e');
      return _cachedUserRole ?? 'user'; // Fallback to cache
    }
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
 void _listenToRoleChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) async {
        if (doc.exists) {
          final newRole = doc.data()?['role'] ?? 'user';
          _cachedUserRole = newRole;
          
          // ✅ Also update SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', newRole);
          
          print('🔄 Role updated in real-time: $_cachedUserRole');
        }
      });
    }
  }


  // Staff: Navigate to escalation detail
  void _navigateToEscalationDetail(BuildContext context, Map<String, dynamic> data) async {
    final escalationId = data['escalationId'];
    if (escalationId == null || escalationId.isEmpty) {
      print('⚠️ No escalation ID provided');
      return;
    }

    LoadingOverlay.show(context, message: 'Loading escalation...');

    try {
      // ✅ Use improved role getter with cache fallback
      final role = await _getUserRole();
      
      print('📍 User role determined: $role');
      
      // ✅ Navigate based on actual role
      String route;
      int tabIndex;
      
      if (role == 'admin') {
        route = '/admin/home';
        tabIndex = 5;
      } else if (role == 'staff') {
        route = '/staff/home';
        tabIndex = 2;
      } else {
        // ✅ Users shouldn't access escalations
        LoadingOverlay.hide(context);
        _showErrorDialog(context, 'You do not have permission to view escalations');
        return;
      }
      
      print('📍 Navigating $role to escalations (route: $route, tab: $tabIndex)');
      
      LoadingOverlay.hide(context);
      
      // ✅ Use small delay to ensure overlay is hidden
      await Future.delayed(Duration(milliseconds: 100));
      
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed(
          route,
          arguments: {
            'initialTab': tabIndex,
            'escalationId': escalationId,
            'autoOpen': true,
          },
        );
      }
    } catch (e) {
      print('❌ Error in escalation navigation: $e');
      LoadingOverlay.hide(context);
      
      // ✅ Better error handling - don't navigate on error
      if (context.mounted) {
        _showErrorDialog(
          context, 
          'Failed to load escalation. Please check your connection and try again.'
        );
      }
    }
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
      final escalationDoc =
          await FirebaseFirestore.instance
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
        builder:
            (context) => AlertDialog(
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
                            formatTime(respondedAt),
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
      builder:
          (context) => AlertDialog(
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
}
