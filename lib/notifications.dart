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

  @override
  void initState() {
    super.initState();
    print('📱 NotificationModal opened for role: ${widget.role}, userId: $currentUserId');
  }

  Future<void> _markAsRead(String notificationId) async {
    if (currentUserId == null) return;
    
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'readBy': FieldValue.arrayUnion([currentUserId])
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
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications? This action cannot be undone.'),
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

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    print('🔔 Notification tapped - Type: $type');
    
    if (type == 'escalation_reply') {
      final escalationId = data['escalationId'] as String?;
      final dataMap = data['data'] as Map<String, dynamic>?;
      
      if (escalationId != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.reply, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Staff Response',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Question:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dataMap?['question'] ?? 'No question',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Staff Reply:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      dataMap?['staffReply'] ?? 'No reply',
                      style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } else if (type == 'new_escalation') {
      final escalationId = data['escalationId'] as String?;
      
      if (escalationId != null) {
        // Navigate to escalation detail page
        // You can implement navigation to HumanEscalation page here
        Navigator.pop(context); // Close notification modal
        // Then navigate to escalation details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('View Escalation'),
            content: Text('Navigate to escalation details for: $escalationId'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    final hasNotifications = snapshot.hasData && 
                        snapshot.data!.docs.isNotEmpty;
                    
                    if (snapshot.hasData) {
                      print('📊 Total notifications for ${widget.role}: ${snapshot.data!.docs.length}');
                    }
                    
                    return PopupMenuButton<String>(
                      enabled: hasNotifications,
                      icon: Icon(
                        Icons.more_vert,
                        color: hasNotifications ? Colors.grey[600] : Colors.grey[300],
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

          // Notifications list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: notificationsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2E7D32),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print('❌ Error in notifications stream: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text('Error loading notifications'),
                        SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                              // Notification icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getNotificationColor(notificationType)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getNotificationIcon(notificationType),
                                  color: _getNotificationColor(notificationType),
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
                                              fontWeight: isRead 
                                                  ? FontWeight.w500 
                                                  : FontWeight.w600,
                                              color: isRead 
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
                                    if (data['body'] != null && data['body'].isNotEmpty)
                                      Text(
                                        data['body'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isRead 
                                              ? Colors.grey[600] 
                                              : Colors.grey[700],
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatTime(data['createdAt'] as Timestamp?),
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
}