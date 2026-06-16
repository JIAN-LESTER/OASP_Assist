import 'package:capstone_project/icon_and_color.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

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

  // Undo functionality
  Map<String, dynamic>? _lastDeletedNotification;
  List<Map<String, dynamic>>? _lastClearedNotifications;
  OverlayEntry? _undoOverlayEntry;

  // Cache the snapshot data to prevent rebuilding
  QuerySnapshot? _cachedSnapshot;

  void _showCustomSnackbar(
    String message, {
    required Color backgroundColor,
    required Color iconBackgroundColor,
    required IconData icon,
    required LinearGradient progressGradient,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            bottom: 24,
            right: 24,
            child: TweenAnimationBuilder<Offset>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: const Offset(1.2, 0), end: Offset.zero),
              builder: (context, offset, child) {
                return Transform.translate(
                  offset: Offset(offset.dx * 100, 0),
                  child: child,
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: isMobile ? screenWidth - 32 : 460,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: iconBackgroundColor,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                icon,
                                color: Colors.white,
                                size: isMobile ? 20 : 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isMobile ? 15 : 16,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => overlayEntry.remove(),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white.withOpacity(0.7),
                                  size: isMobile ? 18 : 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(seconds: 5),
                        curve: Curves.linear,
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            child: SizedBox(
                              height: 4,
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: progressGradient,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  void _showSuccessSnackbar(String message) {
    _showCustomSnackbar(
      message,
      backgroundColor: const Color(0xFF1E3A32),
      iconBackgroundColor: const Color(0xFF10B981),
      icon: Icons.check_circle,
      progressGradient: const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF10B981)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    _showCustomSnackbar(
      message,
      backgroundColor: const Color(0xFF3A2327),
      iconBackgroundColor: const Color(0xFFEF4444),
      icon: Icons.error,
      progressGradient: const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    );
  }

  void _showUndoSnackbar(String message, VoidCallback onUndo) {
    // Remove any existing undo snackbar
    _undoOverlayEntry?.remove();

    final overlay = Overlay.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    _undoOverlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            bottom: 24,
            right: 24,
            child: TweenAnimationBuilder<Offset>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: const Offset(1.2, 0), end: Offset.zero),
              builder: (context, offset, child) {
                return Transform.translate(
                  offset: Offset(offset.dx * 100, 0),
                  child: child,
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: isMobile ? screenWidth - 32 : 460,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B7280),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                Icons.info,
                                color: Colors.white,
                                size: isMobile ? 20 : 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isMobile ? 15 : 16,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () {
                                  _undoOverlayEntry?.remove();
                                  _undoOverlayEntry = null;
                                  onUndo();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4B5563),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'UNDO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 13 : 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                _undoOverlayEntry?.remove();
                                _undoOverlayEntry = null;
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white.withOpacity(0.7),
                                  size: isMobile ? 18 : 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(seconds: 5),
                        curve: Curves.linear,
                        tween: Tween(begin: 0.0, end: 1.0),
                        onEnd: () {
                          _undoOverlayEntry?.remove();
                          _undoOverlayEntry = null;
                        },
                        builder: (context, value, child) {
                          return ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            child: SizedBox(
                              height: 4,
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: value,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF4B5563),
                                              Color(0xFF6B7280),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    overlay.insert(_undoOverlayEntry!);
  }

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
      ' NotificationModal opened for role: ${widget.role}, userId: $currentUserId',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _undoOverlayEntry?.remove();
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
      print(' Marked notification as read: $notificationId');
    } catch (e) {
      print(' Error marking notification as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      // Get the notification data before deleting
      final notificationDoc =
          await _firestore
              .collection('notifications')
              .doc(notificationId)
              .get();

      if (!notificationDoc.exists) {
        _showErrorSnackbar('Notification not found');
        return;
      }

      final notificationData = notificationDoc.data() as Map<String, dynamic>;
      notificationData['notificationId'] = notificationId; // Store the ID

      // Delete the notification
      await _firestore.collection('notifications').doc(notificationId).delete();
      print(' Deleted notification: $notificationId');

      // Store for undo
      _lastDeletedNotification = notificationData;
      _lastClearedNotifications = null; // Clear the other undo option

      if (mounted) {
        _showUndoSnackbar('Notification deleted', _undoDelete);
      }
    } catch (e) {
      print(' Error deleting notification: $e');
      if (mounted) {
        _showErrorSnackbar('Failed to delete notification');
      }
    }
  }

  Future<void> _undoDelete() async {
    if (_lastDeletedNotification == null) return;

    try {
      final notificationId =
          _lastDeletedNotification!['notificationId'] as String;
      final notificationData = Map<String, dynamic>.from(
        _lastDeletedNotification!,
      );
      notificationData.remove('notificationId'); // Remove the ID before saving

      // Restore the notification
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notificationData);

      print(' Restored notification: $notificationId');

      _lastDeletedNotification = null;

      if (mounted) {
        _showSuccessSnackbar('Notification restored');
      }
    } catch (e) {
      print(' Error restoring notification: $e');
      if (mounted) {
        _showErrorSnackbar('Failed to restore notification');
      }
    }
  }

  Future<void> _undoClearAll() async {
    if (_lastClearedNotifications == null ||
        _lastClearedNotifications!.isEmpty) {
      return;
    }

    try {
      final batch = _firestore.batch();

      for (final notificationData in _lastClearedNotifications!) {
        final notificationId = notificationData['notificationId'] as String;
        final data = Map<String, dynamic>.from(notificationData);
        data.remove('notificationId'); // Remove the ID before saving

        batch.set(
          _firestore.collection('notifications').doc(notificationId),
          data,
        );
      }

      await batch.commit();

      print(' Restored ${_lastClearedNotifications!.length} notifications');

      final count = _lastClearedNotifications!.length;
      _lastClearedNotifications = null;

      if (mounted) {
        _showSuccessSnackbar('$count notifications restored');
      }
    } catch (e) {
      print(' Error restoring notifications: $e');
      if (mounted) {
        _showErrorSnackbar('Failed to restore notifications');
      }
    }
  }

  Future<void> _toggleReadStatus(
    String notificationId,
    bool isCurrentlyRead,
  ) async {
    if (currentUserId == null) return;

    try {
      if (isCurrentlyRead) {
        // Mark as unread - remove from readBy array
        await _firestore.collection('notifications').doc(notificationId).update(
          {
            'readBy': FieldValue.arrayRemove([currentUserId]),
          },
        );
        print(' Marked notification as unread: $notificationId');
      } else {
        // Mark as read - add to readBy array
        await _firestore.collection('notifications').doc(notificationId).update(
          {
            'readBy': FieldValue.arrayUnion([currentUserId]),
          },
        );
        print(' Marked notification as read: $notificationId');
      }
    } catch (e) {
      print(' Error toggling read status: $e');
      if (mounted) {
        _showErrorSnackbar('Failed to update notification');
      }
    }
  }

  void _showNotificationMenu(
    BuildContext context,
    String notificationId,
    bool isRead,
    Offset buttonPosition,
    Size buttonSize,
  ) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              // Invisible barrier to close menu when tapping outside
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => overlayEntry.remove(),
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Menu positioned below the button
              Positioned(
                left: buttonPosition.dx - 180, // Position to the left of button
                top:
                    buttonPosition.dy +
                    buttonSize.height +
                    4, // Below the button
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mark as read/unread option
                        InkWell(
                          onTap: () {
                            overlayEntry.remove();
                            _toggleReadStatus(notificationId, isRead);
                          },
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isRead
                                      ? Icons.mark_email_unread_outlined
                                      : Icons.mark_email_read_outlined,
                                  color: const Color(0xFF2E7D32),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isRead ? 'Mark as unread' : 'Mark as read',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Divider(height: 1, color: Colors.grey[200]),

                        // Delete option
                        InkWell(
                          onTap: () {
                            overlayEntry.remove();
                            _showDeleteConfirmation(notificationId);
                          },
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFEF4444),
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Delete notification',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
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

    overlay.insert(overlayEntry);
  }

  void _showDeleteConfirmation(String notificationId) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Delete Notification',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Message
                  const Text(
                    'Are you sure you want to delete this notification? This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
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
                            _deleteNotification(notificationId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Delete',
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
        _showSuccessSnackbar('All notifications marked as read');
      }
    } catch (e) {
      print(' Error marking all as read: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    if (currentUserId == null) return;

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Color(0xFFEF4444),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Clear All Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Message
                  const Text(
                    'Are you sure you want to clear all notifications? This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
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
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Clear All',
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

    if (result == true) {
      try {
        Query notificationsQuery = _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUserId)
            .where('targetRole', isEqualTo: widget.role);

        final snapshot = await notificationsQuery.get();

        // Store all notifications for undo
        _lastClearedNotifications =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['notificationId'] = doc.id; // Store the document ID
              return data;
            }).toList();
        _lastDeletedNotification = null; // Clear the other undo option

        // Delete all notifications
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (mounted) {
          _showUndoSnackbar(
            '${snapshot.docs.length} notifications cleared',
            _undoClearAll,
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar('Error clearing notifications: $e');
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

      //   Handle Facebook token expiration
      case 'fb_token_expiration':
        _handleFacebookTokenExpiration(data);
        break;

      default:
        print(' Unhandled notification type: $type');
    }
  }

  void _handleFacebookTokenExpiration(Map<String, dynamic> data) {
    final status =
        data['status'] as String? ?? data['data']?['status'] as String?;
    final daysLeft =
        int.tryParse(
          (data['daysLeft'] ?? data['data']?['daysLeft'] ?? '0').toString(),
        ) ??
        0;

    print(' Facebook token notification tapped');
    print('   Status: $status');
    print('   Days left: $daysLeft');

    // Close notification modal
    Navigator.of(context).pop();

    // Navigate to announcements page where the banner will be visible
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        '/admin/home',
        arguments: {'initialTab': 4}, // Announcements tab
      );
    });
  }

  void _navigateToAnnouncements(String? announcementId) {
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
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                        // Use MarkdownBody for rendering markdown
                        MarkdownBody(
                          data: staffResponse,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(fontSize: 15, height: 1.4),
                            strong: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
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
                      print(' Continue in Chat pressed');
                      print('   - conversationId: $conversationId');

                      if (conversationId == null ||
                          conversationId.isEmpty ||
                          conversationId == 'null') {
                        _showErrorSnackbar('No conversation available');
                        return;
                      }

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
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                    useMarkdown: false,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'Bot Response',
                    content: botAnswer,
                    icon: Icons.smart_toy_rounded,
                    color: Colors.purple,
                    useMarkdown: true,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'Escalation Reason',
                    content: reason,
                    icon: Icons.report_problem_rounded,
                    color: Colors.orange,
                    useMarkdown: false,
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      title: 'Created',
                      content: formatTime(createdAt),
                      icon: Icons.access_time_rounded,
                      color: Colors.grey,
                      useMarkdown: false,
                    ),
                  ],
                  if (staffResponse != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      title: 'Your Response',
                      content: staffResponse,
                      icon: Icons.support_agent_rounded,
                      color: const Color(0xFF2E7D32),
                      useMarkdown: true,
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

                    print(' Respond to Escalation pressed');
                    print('   - escalationId: $escalationId');
                    print('   - conversationId: $conversationId');

                    if (escalationId == null || escalationId.isEmpty) {
                      _showErrorSnackbar('Error: No escalation ID');
                      return;
                    }

                    await Future.delayed(const Duration(milliseconds: 200));

                    if (!mounted) return;

                    final route =
                        widget.role == 'admin' ? '/admin/home' : '/staff/home';
                    final tabIndex = widget.role == 'admin' ? 5 : 2;

                    print(' Navigating to: $route (tab $tabIndex)');

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
    bool useMarkdown = false,
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
          useMarkdown
              ? MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 14, height: 1.4),
                  strong: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9),
                  ),
                  h1: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  h2: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  code: TextStyle(
                    backgroundColor: Colors.grey[100],
                    fontFamily: 'monospace',
                  ),
                  listBullet: const TextStyle(fontSize: 14),
                ),
              )
              : Text(
                content,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error Message
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // OK Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                // Clear All button
                StreamBuilder<QuerySnapshot>(
                  stream:
                      _firestore
                          .collection('notifications')
                          .where('userId', isEqualTo: currentUserId)
                          .where('targetRole', isEqualTo: widget.role)
                          .snapshots(),
                  builder: (context, snapshot) {
                    final hasNotifications =
                        snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                    return TextButton.icon(
                      onPressed:
                          hasNotifications ? _clearAllNotifications : null,
                      icon: Icon(
                        Icons.delete_sweep_outlined,
                        size: 18,
                        color:
                            hasNotifications
                                ? const Color(0xFFEF4444)
                                : Colors.grey[400],
                      ),
                      label: Text(
                        'Clear all',
                        style: TextStyle(
                          color:
                              hasNotifications
                                  ? const Color(0xFFEF4444)
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
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Tab Bar with Mark all as read button
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

                final hasUnread =
                    snapshot.hasData &&
                    snapshot.data!.docs.any((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return !_isRead(data);
                    });

                return Row(
                  children: [
                    // Tabs on the left
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF2E7D32),
                        unselectedLabelColor: Colors.grey[600],
                        indicatorColor: const Color(0xFF2E7D32),
                        indicatorWeight: 3,
                        dividerColor: Colors.transparent,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          Tab(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                                ? const Color(
                                                  0xFF2E7D32,
                                                ).withOpacity(0.1)
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
                              ],
                            ),
                          ),
                          Tab(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                                ? const Color(
                                                  0xFF2E7D32,
                                                ).withOpacity(0.1)
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mark all as read button on the right
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextButton.icon(
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

        //   Special styling for FB token notifications
        final isFbTokenNotification = notificationType == 'fb_token_expiration';
        final isExpired =
            data['status'] == 'expired' ||
            (data['data']?['status'] == 'expired');

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
                //  Special background for FB token notifications
                color:
                    isFbTokenNotification
                        ? (isExpired
                            ? const Color(0xFFDC2626).withOpacity(0.05)
                            : const Color(0xFFF59E0B).withOpacity(0.05))
                        : (isRead ? Colors.grey[50] : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  //  Special border for FB token notifications
                  color:
                      isFbTokenNotification
                          ? (isExpired
                              ? const Color(0xFFDC2626).withOpacity(0.3)
                              : const Color(0xFFF59E0B).withOpacity(0.3))
                          : (isRead ? Colors.grey[200]! : Colors.grey[300]!),
                  width: isFbTokenNotification ? 2 : 1,
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

                  // Three-dot menu button
                  Builder(
                    builder: (context) {
                      return IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          final RenderBox renderBox =
                              context.findRenderObject() as RenderBox;
                          final buttonPosition = renderBox.localToGlobal(
                            Offset.zero,
                          );
                          final buttonSize = renderBox.size;

                          _showNotificationMenu(
                            context,
                            doc.id,
                            isRead,
                            buttonPosition,
                            buttonSize,
                          );
                        },
                      );
                    },
                  ),

                  // Unread Indicator
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 4, right: 4),
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
