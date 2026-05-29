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
  String? _cachedUserRole;
  String? _cachedServiceUnit; //  Add service unit cache

  NotificationNavigationHandler(this.navigatorKey);

  void setup() {
    NotificationService().setNavigationHandler(_handleNavigation);
    _initializeUserRole();
    _listenToRoleChanges();
    print(' Navigation handler registered');
  }

  Future<void> initializeServices() async {
    try {
      print(' Initializing services...');

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      print(' Background handler registered');

      await NotificationService().initialize();
      print(' Notifications ready');

      NotificationNavigationHandler(navigatorKey).setup();

      print(' Core services initialized');
    } catch (e, stackTrace) {
      print(' Service init warning: $e');
      print('Stack: $stackTrace');
    }
  }

  //  Initialize both role and service unit
  Future<void> _initializeUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          _cachedUserRole = data?['role'] ?? 'user';
          _cachedServiceUnit = data?['serviceUnit']; //  Cache service unit
          print(' Cached user role: $_cachedUserRole');
          print(' Cached service unit: $_cachedServiceUnit');
        }
      }
    } catch (e) {
      print(' Error caching user role: $e');
      _cachedUserRole = 'user';
    }
  }

  Future<String> _getUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return _cachedUserRole ?? 'user';
      }

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        final role = userDoc.data()?['role'] ?? 'user';
        _cachedUserRole = role;
        return role;
      }

      return _cachedUserRole ?? 'user';
    } catch (e) {
      print(' Error fetching role, using cache: $e');
      return _cachedUserRole ?? 'user';
    }
  }

  //  Add method to get service unit
  Future<String?> _getServiceUnit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return _cachedServiceUnit;
      }

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        final serviceUnit = userDoc.data()?['serviceUnit'] as String?;
        _cachedServiceUnit = serviceUnit;
        return serviceUnit;
      }

      return _cachedServiceUnit;
    } catch (e) {
      print(' Error fetching service unit, using cache: $e');
      return _cachedServiceUnit;
    }
  }

  void _handleNavigation(String type, Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print(' No navigator context available');
      return;
    }

    print(' Navigating to: $type with data: $data');

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
      //   Handle Facebook token expiration notifications
      case 'fb_token_expiration':
        _handleFacebookTokenExpiration(context, data);
        break;
    }
  }

  void _handleFacebookTokenExpiration(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final status = data['status'] as String?;
    final daysLeft = int.tryParse(data['daysLeft'] ?? '0') ?? 0;

    print(' Facebook token notification:');
    print('   Status: $status');
    print('   Days left: $daysLeft');

    // Show dialog with token renewal instructions
    _showTokenExpirationDialog(context, status, daysLeft);
  }

  void _showTokenExpirationDialog(
    BuildContext context,
    String? status,
    int daysLeft,
  ) {
    final isExpired = status == 'expired' || daysLeft <= 0;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isExpired
                                  ? const Color(0xFFDC2626).withOpacity(0.1)
                                  : const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isExpired
                              ? Icons.error_rounded
                              : Icons.warning_rounded,
                          color:
                              isExpired
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFF59E0B),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isExpired
                                  ? 'Facebook Token Expired'
                                  : 'Facebook Token Expiring Soon',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isExpired
                                  ? 'Action required immediately'
                                  : '$daysLeft day${daysLeft != 1 ? "s" : ""} remaining',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      isExpired
                          ? 'Your Facebook API token has expired. You cannot sync new posts until you renew the token.'
                          : 'Your Facebook API token will expire in $daysLeft day${daysLeft != 1 ? "s" : ""}. Please renew it soon to continue syncing posts without interruption.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick instructions
                  const Text(
                    'To renew your token:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickStep('1', 'Go to Announcements page'),
                  const SizedBox(height: 8),
                  _buildQuickStep('2', 'Click the key () button'),
                  const SizedBox(height: 8),
                  _buildQuickStep('3', 'Follow the token renewal process'),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Navigate to announcements page
                            Navigator.of(context).pushReplacementNamed(
                              '/admin/home',
                              arguments: {'initialTab': 4}, // Announcements tab
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Go to Announcements',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildQuickStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  //  Listen to both role and service unit changes
  void _listenToRoleChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) async {
            if (doc.exists) {
              final data = doc.data();
              final newRole = data?['role'] ?? 'user';
              final newServiceUnit = data?['serviceUnit'] as String?;

              _cachedUserRole = newRole;
              _cachedServiceUnit = newServiceUnit;

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_role', newRole);
              if (newServiceUnit != null) {
                await prefs.setString('service_unit', newServiceUnit);
              }

              print(' Role updated in real-time: $_cachedUserRole');
              print(' Service unit updated: $_cachedServiceUnit');
            }
          });
    }
  }

  //  Fixed navigation - wait for service unit to load
  void _navigateToEscalationDetail(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final escalationId = data['escalationId'];
    if (escalationId == null || escalationId.isEmpty) {
      print(' No escalation ID provided');
      return;
    }

    LoadingOverlay.show(context, message: 'Loading escalation...');

    try {
      final role = await _getUserRole();
      final serviceUnit = await _getServiceUnit(); //  Get service unit

      print(' User role determined: $role');
      print(' Service unit: $serviceUnit');

      String route;
      int tabIndex;

      if (role == 'admin') {
        route = '/admin/home';
        tabIndex = 5;
      } else if (role == 'staff') {
        route = '/staff/home';
        tabIndex = 2;
      } else {
        LoadingOverlay.hide(context);
        _showErrorDialog(
          context,
          'You do not have permission to view escalations',
        );
        return;
      }

      //  Verify service unit is loaded before navigation
      if (serviceUnit == null && role == 'staff') {
        print(' Service unit not loaded yet, retrying...');
        await Future.delayed(Duration(milliseconds: 500));
        final retryServiceUnit = await _getServiceUnit();

        if (retryServiceUnit == null) {
          LoadingOverlay.hide(context);
          _showErrorDialog(
            context,
            'Unable to load service unit. Please try again.',
          );
          return;
        }
      }

      print(' Navigating $role to escalations (route: $route, tab: $tabIndex)');

      LoadingOverlay.hide(context);

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
    } catch (e, stackTrace) {
      print(' Error in escalation navigation: $e');
      print('Stack trace: $stackTrace');
      LoadingOverlay.hide(context);

      if (context.mounted) {
        _showErrorDialog(
          context,
          'Failed to load escalation. Please check your connection and try again.',
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
      print(' No escalation ID provided');
      return;
    }

    try {
      final escalationDoc =
          await FirebaseFirestore.instance
              .collection('escalations')
              .doc(escalationId)
              .get();

      if (!escalationDoc.exists) {
        _showErrorDialog(context, 'Escalation not found');
        return;
      }

      final escalation = escalationDoc.data() as Map<String, dynamic>;
      final staffResponse = escalation['staffResponse'] ?? 'No response yet';
      final respondedBy = escalation['respondedBy'] ?? 'Staff';
      final respondedAt = escalation['respondedAt'] as Timestamp?;

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
      print(' Error fetching escalation: $e');
      _showErrorDialog(context, 'Failed to load response');
    }
  }

  void _navigateToAnnouncement(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final announcementId = data['announcementId'];
    if (announcementId == null || announcementId.isEmpty) {
      print(' No announcement ID provided');
      return;
    }

    Navigator.of(context).pushNamed(
      '/announcements/detail',
      arguments: {'announcementId': announcementId},
    );
  }

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
