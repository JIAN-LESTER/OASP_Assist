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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error marking as read: $e')));
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    if (currentUserId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Notifications'),
            content: const Text(
              'Are you sure you want to clear all notifications? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );

    if (result == true) {
      try {
        Query notificationsQuery = _firestore
            .collection('notifications')
            .where('targetRole', isEqualTo: widget.role);

        final snapshot = await notificationsQuery.get();

        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications cleared'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing notifications: $e')),
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

  String _formatTime(Timestamp? timestamp) {
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

  IconData _getNotificationIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'announcement':
        return Icons.campaign_outlined;
      case 'deadline_reminder':
        return Icons.alarm_outlined;
      case 'escalation_reply':
        return Icons.reply_outlined;
      case 'new_escalation':
        return Icons.help_outline;
      case 'info':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'success':
        return Icons.check_circle_outline;
      case 'error':
        return Icons.error_outline;
      case 'message':
        return Icons.message_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'announcement':
        return const Color(0xFF2E7D32);
      case 'deadline_reminder':
        return Colors.orange;
      case 'escalation_reply':
        return Colors.blue;
      case 'new_escalation':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'error':
        return Colors.red;
      case 'message':
        return Colors.purple;
      default:
        return const Color(0xFF2E7D32);
    }
  }

  
// Update the _handleNotificationTap method in notification_modal.dart

Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
  final type = data['type'] as String?;
  
  // ✅ FIX: Try both root level and nested data
  final escalationId = data['escalationId'] as String? ?? 
                       data['data']?['escalationId'] as String?;
  
  final conversationId = data['conversationId'] as String? ??
                        data['data']?['conversationId'] as String?;
  
  final relatedId = data['relatedId'] as String? ?? 
                    data['announcementId'] as String? ??
                    data['data']?['announcementId'] as String?;

  print('🔔 Notification tapped - Type: $type, EscalationId: $escalationId, ConversationId: $conversationId, Role: ${widget.role}');

  if (type == null) {
    print('⚠️ No notification type found');
    return;
  }

  // Mark notification as read before navigation
  final notificationId = data['notificationId'];
  if (notificationId != null) {
    await _markAsRead(notificationId);
  }

  // Handle based on type and role
  switch (type) {
    case 'escalation_reply':
      if (widget.role == 'user') {
        if (escalationId == null || escalationId.isEmpty) {
          _showError('Cannot open escalation: Missing escalation ID');
          return;
        }
        _showEscalationResponseInline(escalationId, conversationId);
      }
      break;

    case 'new_escalation':
      if (widget.role == 'staff') {
        if (escalationId == null || escalationId.isEmpty) {
          _showError('Cannot open escalation: Missing escalation ID');
          return;
        }
        _showEscalationDetailInline(escalationId, conversationId);
      }
      break;

    case 'announcement':
      Navigator.of(context).pop();
      await _navigateToAnnouncement(relatedId);
      break;

    case 'deadline_reminder':
      Navigator.of(context).pop();
      await _navigateToAnnouncementsList();
      break;

    default:
      print('⚠️ Unhandled notification type: $type');
  }
}
 Future<void> _showEscalationResponseInline(String escalationId, String? conversationId) async {
  setState(() {
    _isLoadingDetail = true;
    _viewingEscalationId = escalationId;
    _viewingConversationId = conversationId; // Store conversationId
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
    _viewingConversationId = conversationId; // Store conversationId
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

    // ✅ Show different views for user vs staff
    if (widget.role == 'user') {
      return _buildUserEscalationResponse();
    } else if (widget.role == 'staff') {
      return _buildStaffEscalationDetail();
    }

    return Container();
  }

Widget _buildUserEscalationResponse() {
  final escalation = _viewingEscalationData!;
  final staffResponse = escalation['staffResponse'] ?? 'No response yet';
  final respondedBy = escalation['respondedBy'] ?? 'Staff';
  final respondedAt = escalation['respondedAt'] as Timestamp?;
  final userQuestion = escalation['question'] ?? 'No question available';
  // Use stored conversationId or fallback to escalation data
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
          // Drag handle
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

          // Header with back button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _backToNotificationList,
                  color: const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Staff Response",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      if (respondedAt != null)
                        Text(
                          _formatTime(respondedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Original question
                  Container(
                    padding: const EdgeInsets.all(12),
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
                            const SizedBox(width: 6),
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
                        const SizedBox(height: 8),
                        Text(
                          userQuestion,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Staff response
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2E7D32).withOpacity(0.1),
                          const Color(0xFF388E3C).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2E7D32).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.support_agent,
                              size: 16,
                              color: Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Response from $respondedBy',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
          ),

              if (conversationId != null && conversationId.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      print('🔔 User navigating to chat with conversationId: $conversationId');
                      
                      // Close the modal
                      Navigator.of(context).pop();
                      
                      // Navigate to home with chat tab and conversationId
                      Navigator.of(context).pushReplacementNamed(
                        '/home',
                        arguments: {
                          'initialTab': 1, // Chat tab
                          'conversationId': conversationId,
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.chat_bubble, size: 20),
                    label: const Text(
                      'Continue in Chat',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,),
                      ),
          ),
        ),
      ],
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

          // Header with back button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _backToNotificationList,
                  color: const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Escalation Detail",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _getNotificationColor(status),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  _buildInfoCard(
                    title: 'User Question',
                    content: question,
                    icon: Icons.help_outline,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),

                  // Bot Answer
                  _buildInfoCard(
                    title: 'Bot Response',
                    content: botAnswer,
                    icon: Icons.smart_toy,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 12),

                  // Reason
                  _buildInfoCard(
                    title: 'Escalation Reason',
                    content: reason,
                    icon: Icons.report_problem,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),

                  // Created at
                  if (createdAt != null)
                    _buildInfoCard(
                      title: 'Created',
                      content: _formatTime(createdAt),
                      icon: Icons.access_time,
                      color: Colors.grey,
                    ),

                  // Staff response if exists
                  if (staffResponse != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      title: 'Your Response',
                      content: staffResponse,
                      icon: Icons.support_agent,
                      color: const Color(0xFF2E7D32),
                    ),
                  ],
                ],
              ),
            ),
          ),

         // Action button - UPDATED
   Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    print('🔔 Staff navigating to escalations with: $_viewingEscalationId');
                    print('🔔 ConversationId: $conversationId');
                    
                    // Close the modal
                    Navigator.of(context).pop();
                    
                    // Navigate to staff home with escalations tab
                    Navigator.of(context).pushReplacementNamed(
                      '/staff/home',
                      arguments: {
                        'initialTab': 2, // Human Escalation tab
                        'escalationId': _viewingEscalationId,
                        'conversationId': conversationId,
                        'autoOpen': true,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: Icon(
                    status == 'resolved' ? Icons.visibility : Icons.edit,
                    size: 20,
                  ),
                  label: Text(
                    status == 'resolved'
                        ? 'View Full Details'
                        : 'Respond to Escalation',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // ✅ Helper widget for info cards
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

  Future<void> _showEscalationResponse(String? escalationId) async {
    if (escalationId == null || escalationId.isEmpty) {
      _showError('No escalation ID provided');
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            ),
      );

      // ✅ CRITICAL FIX: Fetch by document ID, not by field
      final escalationDoc =
          await _firestore
              .collection('escalations')
              .doc(escalationId) // ✅ Use doc() directly with the ID
              .get();

      // Close loading
      if (mounted) Navigator.of(context).pop();

      if (!escalationDoc.exists) {
        _showError('Escalation not found');
        return;
      }

      final escalation = escalationDoc.data()!;
      final staffResponse = escalation['staffResponse'] ?? 'No response yet';
      final respondedBy = escalation['respondedBy'] ?? 'Staff';
      final respondedAt = escalation['respondedAt'] as Timestamp?;
      final userQuestion = escalation['question'] ?? 'No question available';
      final conversationId = escalation['conversationId'] as String?;

      if (!mounted) return;

      // Show response dialog
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      color: Color(0xFF2E7D32),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Staff Response',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (respondedAt != null)
                          Text(
                            _formatTime(respondedAt),
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
                      padding: const EdgeInsets.all(12),
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
                              const SizedBox(width: 6),
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
                          const SizedBox(height: 8),
                          Text(
                            userQuestion,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Staff response
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF2E7D32).withOpacity(0.1),
                            const Color(0xFF388E3C).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF2E7D32).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.support_agent,
                                size: 16,
                                color: Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Response from $respondedBy',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                if (conversationId != null && conversationId.isNotEmpty)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigate to chat with conversation
                      Navigator.of(context).pushNamed(
                        '/chat',
                        arguments: {'conversationId': conversationId},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'View Chat',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
      );
    } catch (e) {
      print('❌ Error fetching escalation: $e');
      _showError('Failed to load response: $e');
    }
  }

  // ✅ STAFF: Navigate to escalation detail
  Future<void> _navigateToEscalationDetail(String? escalationId) async {
    if (escalationId == null || escalationId.isEmpty) {
      _showError('No escalation ID provided');
      return;
    }

    // Navigate to Human Escalation screen with the specific escalation
    Navigator.of(context).pushNamed(
      '/staff/escalations',
      arguments: {
        'escalationId': escalationId,
        'autoOpen': true, // Flag to auto-open the dialog
      },
    );
  }

  // ✅ Navigate to announcement detail
  Future<void> _navigateToAnnouncement(String? announcementId) async {
    if (announcementId == null || announcementId.isEmpty) {
      _showError('No announcement ID provided');
      return;
    }

    Navigator.of(context).pushNamed(
      '/announcements/detail',
      arguments: {'announcementId': announcementId},
    );
  }

  // ✅ Navigate to announcements list
  Future<void> _navigateToAnnouncementsList() async {
    Navigator.of(context).pushNamed('/announcements');
  }

  void _showError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
        .orderBy('createdAt', descending: true);

    // Filter based on role
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
          // Header with drag handle
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

          // Title and actions bar
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

                    if (snapshot.hasData) {
                      print(
                        '📊 Total notifications for ${widget.role}: ${snapshot.data!.docs.length}',
                      );
                    }

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
                      itemBuilder:
                          (context) => [
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

          // Notifications list
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
                  print('❌ Error in notifications stream: ${snapshot.error}');
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
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  print('ℹ️ No notifications found for role: ${widget.role}');
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
                        const SizedBox(height: 8),
                        Text(
                          "You're all caught up!",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data!.docs;
                print('✅ Displaying ${notifications.length} notifications');

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: notifications.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 8),
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
                              // Notification icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getNotificationColor(
                                    notificationType,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getNotificationIcon(notificationType),
                                  color: _getNotificationColor(
                                    notificationType,
                                  ),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Content
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
                                      _formatTime(
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
  print('🏗️ Building NotificationModal - ViewingEscalationId: $_viewingEscalationId, HasData: ${_viewingEscalationData != null}, IsLoading: $_isLoadingDetail');
  
  if (_viewingEscalationId != null) {
    return _buildEscalationDetailView();
  }

  return _buildNotificationListView();
}
}
