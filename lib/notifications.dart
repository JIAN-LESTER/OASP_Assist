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

class _NotificationModalState extends State<NotificationModal>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String? _viewingConversationId;
  String? _viewingEscalationId;
  Map<String, dynamic>? _viewingEscalationData;
  bool _isLoadingDetail = false;

  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Cache the snapshot data to prevent rebuilding
  QuerySnapshot? _cachedSnapshot;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return; // Ignore intermediate states
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    print(
      '📱 NotificationModal opened for role: ${widget.role}, userId: $currentUserId',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    }
  }

  Future<void> _markAllAsRead() async {
    if (currentUserId == null) return;

    try {
      Query notificationsQuery = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('targetRole', isEqualTo: widget.role);

      final snapshot = await notificationsQuery.get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final readBy = data['readBy'] as List<dynamic>? ?? [];

        if (!readBy.contains(currentUserId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([currentUserId]),
          });
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All notifications marked as read'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    if (currentUserId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Clear All Notifications'),
            content: const Text(
              'Are you sure you want to clear all notifications? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );

    if (result == true) {
      try {
        Query notificationsQuery = _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUserId);

        final snapshot = await notificationsQuery.get();

        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('All notifications cleared'),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
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
    final escalationId =
        data['escalationId'] as String? ??
        data['data']?['escalationId'] as String?;
    final conversationId =
        data['conversationId'] as String? ??
        data['data']?['conversationId'] as String?;
    final announcementId =
        data['announcementId'] as String? ??
        data['data']?['announcementId'] as String?;

    if (type == null) return;

    // Mark notification as read
    final notificationId = data['notificationId'];
    if (notificationId != null) {
      await _markAsRead(notificationId);
    }

    switch (type) {
      case 'escalation_reply':
        if (widget.role == 'user') {
          if (escalationId == null || escalationId.isEmpty) {
            _showError('Cannot open escalation: Missing escalation ID');
            return;
          }
          await _showEscalationResponseInline(escalationId, conversationId);
        }
        break;

      case 'new_escalation':
        if (widget.role == 'staff' || widget.role == 'admin') {
          if (escalationId == null || escalationId.isEmpty) {
            _showError('Cannot open escalation: Missing escalation ID');
            return;
          }
          await _showEscalationDetailInline(escalationId, conversationId);
        }
        break;

      case 'announcement':
      case 'deadline_reminder':
        _navigateToAnnouncements(announcementId);
        break;

      default:
        print('⚠️ Unhandled notification type: $type');
    }
  }

  void _navigateToAnnouncements(String? announcementId) {
    if (mounted) {
      Navigator.of(context).pop();
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      if (widget.role == 'user') {
        Navigator.of(context).pushReplacementNamed(
          '/home',
          arguments: {'initialTab': 2, 'announcementId': announcementId},
        );
      } else if (widget.role == 'staff') {
        Navigator.of(context).pushReplacementNamed(
          '/staff/home',
          arguments: {'initialTab': 3, 'announcementId': announcementId},
        );
      } else if (widget.role == 'admin') {
        Navigator.of(context).pushReplacementNamed(
          '/admin/home',
          arguments: {'initialTab': 4, 'announcementId': announcementId},
        );
      }
    });
  }

  Future<void> _showEscalationResponseInline(
    String escalationId,
    String? conversationId,
  ) async {
    setState(() {
      _isLoadingDetail = true;
      _viewingEscalationId = escalationId;
      _viewingConversationId = conversationId;
      _viewingEscalationData = null;
    });

    try {
      final escalationDoc =
          await _firestore.collection('escalations').doc(escalationId).get();

      if (!escalationDoc.exists) {
        _showError('Escalation not found');
        setState(() {
          _viewingEscalationId = null;
          _viewingConversationId = null;
          _isLoadingDetail = false;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _viewingEscalationData = escalationDoc.data();
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
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

  Future<void> _showEscalationDetailInline(
    String escalationId,
    String? conversationId,
  ) async {
    setState(() {
      _isLoadingDetail = true;
      _viewingEscalationId = escalationId;
      _viewingConversationId = conversationId;
      _viewingEscalationData = null;
    });

    try {
      final escalationDoc =
          await _firestore.collection('escalations').doc(escalationId).get();

      if (!escalationDoc.exists) {
        _showError('Escalation not found');
        setState(() {
          _viewingEscalationId = null;
          _viewingConversationId = null;
          _isLoadingDetail = false;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _viewingEscalationData = escalationDoc.data();
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
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
      child: Center(child: Text('Unknown role: ${widget.role}')),
    );
  }

  Widget _buildUserEscalationResponse() {
    final escalation = _viewingEscalationData!;
    final staffResponse = escalation['staffResponse'] ?? 'No response yet';
    final respondedBy = escalation['respondedBy'] ?? 'Staff';
    final respondedAt = escalation['respondedAt'] as Timestamp?;
    final userQuestion = escalation['question'] ?? 'No question available';
    final conversationId =
        _viewingConversationId ?? escalation['conversationId'] as String?;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _backToNotificationList,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Staff Response",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Question',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userQuestion,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2E7D32).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Response from $respondedBy',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            const Spacer(),
                            if (respondedAt != null)
                              Text(
                                formatTime(respondedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          staffResponse,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (conversationId != null &&
              conversationId.isNotEmpty &&
              conversationId != 'null')
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await Future.delayed(const Duration(milliseconds: 200));

                      if (!mounted) return;

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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue in Chat',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
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
    final conversationId =
        _viewingConversationId ?? escalation['conversationId'] as String?;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _backToNotificationList,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Escalation Detail",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: getNotificationColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: getNotificationColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: getNotificationColor(status),
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
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'Bot Response',
                    content: botAnswer,
                    icon: Icons.smart_toy_rounded,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'Escalation Reason',
                    content: reason,
                    icon: Icons.report_problem_rounded,
                    color: Colors.orange,
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      title: 'Created',
                      content: formatTime(createdAt),
                      icon: Icons.access_time_rounded,
                      color: Colors.grey,
                    ),
                  ],
                  if (staffResponse != null) ...[
                    const SizedBox(height: 12),
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

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
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

                    Navigator.of(context).pop();
                    await Future.delayed(const Duration(milliseconds: 200));

                    if (!mounted) return;

                    final route =
                        widget.role == 'admin' ? '/admin/home' : '/staff/home';
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
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
          Text(content, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
    Query baseQuery = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUserId)
        .where('targetRole', isEqualTo: widget.role)
        .orderBy('createdAt', descending: true);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const Text(
                  "Your notifications",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                StreamBuilder<QuerySnapshot>(
                  stream: baseQuery.snapshots(),
                  builder: (context, snapshot) {
                    final hasUnread =
                        snapshot.hasData &&
                        snapshot.data!.docs.any((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return !_isRead(data);
                        });

                    return TextButton.icon(
                      onPressed: hasUnread ? _markAllAsRead : null,
                      icon: Icon(
                        Icons.done_all,
                        size: 18,
                        color:
                            hasUnread
                                ? const Color(0xFF1976D2)
                                : Colors.grey[400],
                      ),
                      label: Text(
                        'Mark all as read',
                        style: TextStyle(
                          color:
                              hasUnread
                                  ? const Color(0xFF1976D2)
                                  : Colors.grey[400],
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: baseQuery.snapshots(),
              builder: (context, snapshot) {
                int allCount = 0;
                int todayCount = 0;

                if (snapshot.hasData) {
                  allCount = snapshot.data!.docs.length;

                  final now = DateTime.now();
                  final startOfDay = DateTime(now.year, now.month, now.day);

                  todayCount =
                      snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final createdAt = data['createdAt'] as Timestamp?;
                        if (createdAt == null) return false;
                        return createdAt.toDate().isAfter(startOfDay);
                      }).length;
                }

                return TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF2E7D32),
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: const Color(0xFF2E7D32),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('All'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _selectedTabIndex == 0
                                      ? const Color(0xFF2E7D32).withOpacity(0.1)
                                      : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              allCount.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    _selectedTabIndex == 0
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Today'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _selectedTabIndex == 1
                                      ? const Color(0xFF2E7D32).withOpacity(0.1)
                                      : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              todayCount.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    _selectedTabIndex == 1
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Notification List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: baseQuery.snapshots(),
              builder: (context, snapshot) {
                // Cache the snapshot to prevent rebuilding
                if (snapshot.hasData) {
                  _cachedSnapshot = snapshot.data;
                }

                // Use cached data if available during tab switching
                final dataToUse =
                    snapshot.hasData ? snapshot.data : _cachedSnapshot;

                if (snapshot.connectionState == ConnectionState.waiting &&
                    _cachedSnapshot == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        const Text('Error loading notifications'),
                      ],
                    ),
                  );
                }

                return TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildNotificationList(dataToUse, filterToday: false),
                    _buildNotificationList(dataToUse, filterToday: true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(
    QuerySnapshot? snapshot, {
    bool filterToday = false,
  }) {
    if (snapshot == null || snapshot.docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No notifications yet",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Filter notifications based on tab
    List<QueryDocumentSnapshot> notifications = snapshot.docs;

    if (filterToday) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      notifications =
          notifications.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;
            if (createdAt == null) return false;
            return createdAt.toDate().isAfter(startOfDay);
          }).toList();
    }

    // Show empty state if no notifications after filtering
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              filterToday ? "No notifications today" : "No notifications yet",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doc = notifications[index];
        final data = doc.data() as Map<String, dynamic>;
        final isRead = _isRead(data);
        final notificationType = data['type'] as String?;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!isRead) {
                _markAsRead(doc.id);
              }
              _handleNotificationTap(data);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRead ? Colors.grey[50] : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isRead ? Colors.grey[200]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture Placeholder
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: getNotificationColor(
                        notificationType,
                      ).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      getNotificationIcon(notificationType),
                      color: getNotificationColor(notificationType),
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
                                  fontSize: 15,
                                  fontWeight:
                                      isRead
                                          ? FontWeight.w500
                                          : FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (data['body'] != null &&
                            data['body'].isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            data['body'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          formatTime(data['createdAt'] as Timestamp?),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Unread Indicator
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 8, top: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show escalation detail view if viewing an escalation
    if (_viewingEscalationId != null) {
      return _buildEscalationDetailView();
    }

    // Otherwise show notification list
    return _buildNotificationListView();
  }
}

// Helper function to format time
String formatTime(Timestamp? timestamp) {
  if (timestamp == null) return 'Unknown time';

  final date = timestamp.toDate();
  final now = DateTime.now();
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
    return '${date.month}/${date.day}/${date.year}';
  }
}
