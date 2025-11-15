import 'package:capstone_project/icon_and_color.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationModal extends StatefulWidget {
  final String role; // 'user', 'staff', or 'admin'
  const NotificationModal({super.key, required this.role});

  @override
  State<NotificationModal> createState() => _NotificationModalState();
}

class _NotificationModalState extends State<NotificationModal> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String? _viewingConversationId;

  String? _viewingEscalationId;
  Map<String, dynamic>? _viewingEscalationData;
  bool _isLoadingDetail = false;

  @override
  void initState() {
    super.initState();
    print(
      '📱 NotificationModal opened for role: ${widget.role}, userId: $currentUserId',
    );
  }

  void _backToNotificationList() {
    setState(() {
      _viewingEscalationId = null;
      _viewingEscalationData = null;
      _isLoadingDetail = false;
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    if (currentUserId == null) return;

    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'readBy': FieldValue.arrayUnion([currentUserId]),
      });
      print('✅ Marked notification as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking as read: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
  if (currentUserId == null) return;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.delete_sweep, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 12),
          const Text('Clear All Notifications'),
        ],
      ),
      content: const Text(
        'Are you sure you want to clear all notifications? This action cannot be undone.',
        style: TextStyle(fontSize: 15, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Clear All'),
        ),
      ],
    ),
  );

  if (result == true) {
    try {
      // 🔹 Query only notifications for this user
      Query notificationsQuery = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId);

      // (Optional) also filter by role if needed:
      // .where('targetRole', isEqualTo: widget.role);

      final snapshot = await notificationsQuery.get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('All notifications cleared'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


  bool _isRead(Map<String, dynamic> data) {
    if (currentUserId == null) return false;
    final readBy = data['readBy'] as List<dynamic>?;
    return readBy?.contains(currentUserId) ?? false;
  }


  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    
    final escalationId = data['escalationId'] as String? ?? 
                         data['data']?['escalationId'] as String?;
    
    final conversationId = data['conversationId'] as String? ??
                          data['data']?['conversationId'] as String?;
    
    final announcementId = data['announcementId'] as String? ?? 
                           data['data']?['announcementId'] as String?;

    print('🔔 Notification tapped - Type: $type, Role: ${widget.role}');
    print('🔔 Data: escalationId=$escalationId, conversationId=$conversationId, announcementId=$announcementId');

    if (type == null) {
      print('⚠️ No notification type found');
      return;
    }

    // Mark notification as read
    final notificationId = data['notificationId'];
    if (notificationId != null) {
      await _markAsRead(notificationId);
    }

    // ✅ CRITICAL FIX: Handle based on type and role
    switch (type) {
      case 'escalation_reply':
        if (widget.role == 'user') {
          // ✅ User viewing staff response - show inline
          if (escalationId == null || escalationId.isEmpty) {
            _showError('Cannot open escalation: Missing escalation ID');
            return;
          }
          await _showEscalationResponseInline(escalationId, conversationId);
        }
        break;

      case 'new_escalation':
        if (widget.role == 'staff' || widget.role == 'admin') {
          // ✅ Staff/Admin viewing new escalation - show inline
          if (escalationId == null || escalationId.isEmpty) {
            _showError('Cannot open escalation: Missing escalation ID');
            return;
          }
          await _showEscalationDetailInline(escalationId, conversationId);
        }
        break;

      case 'announcement':
      case 'deadline_reminder':
        // ✅ Navigate to announcements tab
        _navigateToAnnouncements(announcementId);
        break;

      default:
        print('⚠️ Unhandled notification type: $type');
    }
  }

  // ✅ FIXED: Navigate to announcements based on role
  void _navigateToAnnouncements(String? announcementId) {
    print('📢 Navigating to announcements for role: ${widget.role}');
    print('📢 Announcement ID: $announcementId');
    
    // Close the modal first
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Small delay to ensure modal is closed
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      if (widget.role == 'user') {
        print('✅ Navigating user to announcements tab (index 2)');
        Navigator.of(context).pushReplacementNamed(
          '/home',
          arguments: {
            'initialTab': 2,
            'announcementId': announcementId,
          },
        );
      } else if (widget.role == 'staff') {
        print('✅ Navigating staff to announcements tab (index 3)');
        Navigator.of(context).pushReplacementNamed(
          '/staff/home',
          arguments: {
            'initialTab': 3,
            'announcementId': announcementId,
          },
        );
      } else if (widget.role == 'admin') {
        print('✅ Navigating admin to announcements tab (index 4)');
        Navigator.of(context).pushReplacementNamed(
          '/admin/home',
          arguments: {
            'initialTab': 4,
            'announcementId': announcementId,
          },
        );
      }
    });
  }

  Future<void> _showEscalationResponseInline(String escalationId, String? conversationId) async {
    setState(() {
      _isLoadingDetail = true;
      _viewingEscalationId = escalationId;
      _viewingConversationId = conversationId;
      _viewingEscalationData = null;
    });

    try {
      print('🔍 Fetching escalation: $escalationId');
      
      final escalationDoc =
          await _firestore.collection('escalations').doc(escalationId).get();

      if (!escalationDoc.exists) {
        print('❌ Escalation not found: $escalationId');
        _showError('Escalation not found');
        setState(() {
          _viewingEscalationId = null;
          _viewingConversationId = null;
          _isLoadingDetail = false;
        });
        return;
      }

      print('✅ Escalation data loaded successfully');
      
      if (mounted) {
        setState(() {
          _viewingEscalationData = escalationDoc.data();
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching escalation: $e');
      _showError('Failed to load response: $e');
      if (mounted) {
        setState(() {
          _viewingEscalationId = null;
          _viewingConversationId = null;
          _viewingEscalationData = null;
          _isLoadingDetail = false;
        });
      }
    }
  }

  Future<void> _showEscalationDetailInline(String escalationId, String? conversationId) async {
    setState(() {
      _isLoadingDetail = true;
      _viewingEscalationId = escalationId;
      _viewingConversationId = conversationId;
      _viewingEscalationData = null;
    });

    try {
      print('🔍 Fetching escalation: $escalationId');
      
      final escalationDoc =
          await _firestore.collection('escalations').doc(escalationId).get();

      if (!escalationDoc.exists) {
        print('❌ Escalation not found: $escalationId');
        _showError('Escalation not found');
        setState(() {
          _viewingEscalationId = null;
          _viewingConversationId = null;
          _isLoadingDetail = false;
        });
        return;
      }

      print('✅ Escalation data loaded successfully');
      
      if (mounted) {
        setState(() {
          _viewingEscalationData = escalationDoc.data();
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching escalation: $e');
      _showError('Failed to load escalation: $e');
      if (mounted) {
        setState(() {
          _viewingEscalationId = null;
          _viewingConversationId = null;
          _viewingEscalationData = null;
          _isLoadingDetail = false;
        });
      }
    }
  }

  Widget _buildEscalationDetailView() {
    if (_isLoadingDetail) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }

    if (_viewingEscalationData == null) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: Text('Error loading escalation')),
      );
    }

    if (widget.role == 'user') {
      return _buildUserEscalationResponse();
    } else if (widget.role == 'staff' || widget.role == 'admin') {
      return _buildStaffEscalationDetail();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Text('Unknown role: ${widget.role}'),
      ),
    );
  }

  Widget _buildUserEscalationResponse() {
    final escalation = _viewingEscalationData!;
    final staffResponse = escalation['staffResponse'] ?? 'No response yet';
    final respondedBy = escalation['respondedBy'] ?? 'Staff';
    final respondedAt = escalation['respondedAt'] as Timestamp?;
    final userQuestion = escalation['question'] ?? 'No question available';
    final conversationId = _viewingConversationId ?? 
                           escalation['conversationId'] as String?;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2E7D32).withOpacity(0.05),
                  Colors.white,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _backToNotificationList,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Staff Response",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      if (respondedAt != null)
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              formatTime(respondedAt),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade200, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.question_answer_rounded,
                                size: 20,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Your Question',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          userQuestion,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2E7D32).withOpacity(0.12),
                          const Color(0xFF388E3C).withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2E7D32).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.support_agent_rounded,
                                size: 20,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Response from $respondedBy',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2E7D32),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          staffResponse,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade800,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ FIXED: Navigate to chat with proper arguments
          if (conversationId != null && conversationId.isNotEmpty && conversationId != 'null')
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: () async {
                    print('🔔 User navigating to chat with conversationId: $conversationId');
                    
                    // Close modal
                    Navigator.of(context).pop();
                    await Future.delayed(const Duration(milliseconds: 200));
                    
                    if (!mounted) return;
                    
                    // ✅ Navigate to chat tab with conversation
                    Navigator.of(context).pushReplacementNamed(
                      '/home',
                      arguments: {
                        'initialTab': 1,
                        'conversationId': conversationId,
                        'loadExisting': true,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_rounded, size: 22),
                      const SizedBox(width: 12),
                      const Text(
                        'Continue in Chat',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStaffEscalationDetail() {
    final escalation = _viewingEscalationData!;
    final question = escalation['question'] ?? 'No question';
    final botAnswer = escalation['botAnswer'] ?? 'No bot answer';
    final reason = escalation['reason'] ?? 'No reason provided';
    final status = escalation['status'] ?? 'pending';
    final createdAt = escalation['createdAt'] as Timestamp?;
    final staffResponse = escalation['staffResponse'];
    final conversationId = _viewingConversationId ?? 
                           escalation['conversationId'] as String?;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2E7D32).withOpacity(0.05),
                  Colors.white,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _backToNotificationList,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    "Escalation Detail",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: getNotificationColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: getNotificationColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: getNotificationColor(status),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    title: 'User Question',
                    content: question,
                    icon: Icons.help_rounded,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 14),
                  _buildInfoCard(
                    title: 'Bot Response',
                    content: botAnswer,
                    icon: Icons.smart_toy_rounded,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 14),
                  _buildInfoCard(
                    title: 'Escalation Reason',
                    content: reason,
                    icon: Icons.report_problem_rounded,
                    color: Colors.orange,
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 14),
                    _buildInfoCard(
                      title: 'Created',
                      content: formatTime(createdAt),
                      icon: Icons.access_time_rounded,
                      color: Colors.grey,
                    ),
                  ],
                  if (staffResponse != null) ...[
                    const SizedBox(height: 14),
                    _buildInfoCard(
                      title: 'Your Response',
                      content: staffResponse,
                      icon: Icons.support_agent_rounded,
                      color: const Color(0xFF2E7D32),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ✅ FIXED: Navigate to escalations tab with proper arguments
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () async {
                  final escalationId = _viewingEscalationId;
                  
                  if (escalationId == null || escalationId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error: No escalation ID'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  print('🔔 Staff/Admin navigating to escalations with ID: $escalationId');
                  
                  // Close modal
                  Navigator.of(context).pop();
                  await Future.delayed(const Duration(milliseconds: 200));
                  
                  if (!mounted) return;
                  
                  // ✅ Navigate to escalations tab based on role
                  final route = widget.role == 'admin' ? '/admin/home' : '/staff/home';
                  final tabIndex = widget.role == 'admin' ? 5 : 2;
                  
                  Navigator.of(context).pushReplacementNamed(
                    route,
                    arguments: {
                      'initialTab': tabIndex,
                      'escalationId': escalationId,
                      'conversationId': conversationId,
                      'autoOpen': true,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      status == 'resolved' ? Icons.visibility_rounded : Icons.edit_rounded,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      status == 'resolved'
                          ? 'View Full Details'
                          : 'Respond to Escalation',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationListView() {
    Query notificationsQuery = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true);

    if (widget.role == 'user') {
      notificationsQuery = notificationsQuery.where(
        'targetRole',
        isEqualTo: 'user',
      );
    } else if (widget.role == 'staff') {
      notificationsQuery = notificationsQuery.where(
        'targetRole',
        isEqualTo: 'staff',
      );
    } else if (widget.role == 'admin') {
      notificationsQuery = notificationsQuery.where(
        'targetRole',
        isEqualTo: 'admin',
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                const Text(
                  "Notifications",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const Spacer(),
                StreamBuilder<QuerySnapshot>(
                  stream: notificationsQuery.snapshots(),
                  builder: (context, snapshot) {
                    final hasNotifications =
                        snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                    return PopupMenuButton<String>(
                      enabled: hasNotifications,
                      icon: Icon(
                        Icons.more_vert,
                        color:
                            hasNotifications
                                ? Colors.grey[600]
                                : Colors.grey[300],
                      ),
                      onSelected: (value) {
                        if (value == 'clear_all') {
                          _clearAllNotifications();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'clear_all',
                          child: Row(
                            children: [
                              Icon(Icons.clear_all, size: 20),
                              SizedBox(width: 8),
                              Text('Clear All'),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: notificationsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text('Error loading notifications'),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No notifications yet",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isRead = _isRead(data);
                    final notificationType = data['type'] as String?;

                    return Container(
                      decoration: BoxDecoration(
                        color: isRead ? Colors.grey[50] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRead ? Colors.grey[200]! : Colors.grey[300]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (!isRead) {
                            _markAsRead(doc.id);
                          }
                          _handleNotificationTap(data);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: getNotificationColor(
                                    notificationType,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  getNotificationIcon(notificationType),
                                  color: getNotificationColor(
                                    notificationType,
                                  ),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['title'] ?? 'No title',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  isRead
                                                      ? FontWeight.w500
                                                      : FontWeight.w600,
                                              color:
                                                  isRead
                                                      ? Colors.grey[700]
                                                      : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF2E7D32),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (data['body'] != null &&
                                        data['body'].isNotEmpty)
                                      Text(
                                        data['body'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              isRead
                                                  ? Colors.grey[600]
                                                  : Colors.grey[700],
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      formatTime(
                                        data['createdAt'] as Timestamp?,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Show escalation detail view if viewing an escalation
    if (_viewingEscalationId != null) {
      return _buildEscalationDetailView();
    }

    // ✅ Otherwise show notification list
    return _buildNotificationListView();
  }
}