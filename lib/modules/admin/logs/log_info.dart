import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';

void showLogsInfoModal(
  BuildContext context,
  DocumentSnapshot doc,
  List<Map<String, dynamic>> messages,
  bool isMessage, {
  bool showDeleteButton = false, // 🔹  Optional parameter for delete access
}) {
  final data = doc.data() as Map<String, dynamic>;

  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final isTablet = screenWidth >= 600 && screenWidth < 1024;
  final isDesktop = screenWidth >= 1024;

  final Timestamp timeStamp = data['time'] ?? Timestamp.now();
  final DateTime date = timeStamp.toDate();
  final String formattedDate = DateFormat(
    'MMM dd, yyyy • hh:mm a',
  ).format(date);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Logs Info',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 20 : 28),
                  decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.history_outlined,
                          color: Colors.white,
                          size: isMobile ? 24 : 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logs Details',
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Activity log information',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.close,
                              color: Colors.white.withOpacity(0.9),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content - Scrollable body
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 20 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Information
                        buildSectionHeader('User', Icons.person_outline),
                        const SizedBox(height: 12),
                        _buildContentCard(data['user'] ?? 'Unknown User'),
                        const SizedBox(height: 20),

                        // Action or Message Section
                        if (isMessage) ...[
                          // User Message
                          buildSectionHeader(
                            'User Message',
                            Icons.chat_bubble_outline,
                          ),
                          const SizedBox(height: 12),
                          _buildScrollableContentCard(
                            data['message'] ?? 'No message available.',
                          ),
                          const SizedBox(height: 20),

                          // Bot Response
                          buildSectionHeader(
                            'Bot Response',
                            Icons.smart_toy_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildScrollableContentCard(
                            data['reply'] ?? 'No message available.',
                          ),
                          const SizedBox(height: 20),
                        ] else ...[
                          buildSectionHeader('Action', Icons.flash_on_outlined),
                          const SizedBox(height: 12),
                          _buildScrollableContentCard(
                            data['action'] ??
                                'No action information available.',
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Timestamp
                        buildSectionHeader(
                          'Timestamp',
                          Icons.schedule_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildContentCard(formattedDate),

                        // 🔹 CONDITIONAL DELETE BUTTON - Only shown for admins
                        if (showDeleteButton) ...[
                          const SizedBox(height: 24),
                          _buildDeleteButton(
                            context,
                            doc,
                            isMobile,
                            isTablet,
                            isDesktop,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}

// Helper method to build content cards
Widget _buildContentCard(String content) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
    ),
    child: Text(
      content,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF475569),
        height: 1.6,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}

// Helper method to build scrollable content cards for longer content
Widget _buildScrollableContentCard(String content) {
  return Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxHeight: 200),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        content,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF475569),
          height: 1.6,
          fontWeight: FontWeight.w400,
        ),
      ),
    ),
  );
}

// Delete button widget
Widget _buildDeleteButton(
  BuildContext context,
  DocumentSnapshot doc,
  bool isMobile,
  bool isTablet,
  bool isDesktop,
) {
  double buttonHeight =
      isMobile
          ? 48
          : isTablet
          ? 52
          : 56;
  double fontSize = isMobile ? 15 : 16;
  double borderRadius = 12;

  return Container(
    width: double.infinity,
    height: buttonHeight,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        colors: [
          const Color(0xFFEF4444).withOpacity(0.05),
          const Color(0xFFDC2626).withOpacity(0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: const Color(0xFFEF4444).withOpacity(0.3),
        width: 1.5,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: () => _showDeleteConfirmation(context, doc),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Delete Log',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFDC2626),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Delete confirmation dialog
void _showDeleteConfirmation(BuildContext context, DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Delete Confirmation',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Delete Log',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to delete this log? This action cannot be undone.',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        color: const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Message:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['message'] ??
                                data['action'] ??
                                'No message available',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: const Color(0xFF1F2937),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    _buildDeleteActionButtons(context, doc, isMobile),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}

// Delete action buttons
Widget _buildDeleteActionButtons(
  BuildContext context,
  DocumentSnapshot doc,
  bool isMobile,
) {
  double buttonHeight = isMobile ? 40 : 46;
  double fontSize = isMobile ? 14 : 15;
  double borderRadius = 10;

  return Row(
    children: [
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: () => _handleDeleteLog(context, doc),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
            child: Text(
              'Delete',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ],
  );
}

// Handle delete log

Future<void> _handleDeleteLog(
  BuildContext context,
  DocumentSnapshot doc,
) async {
  try {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          ),
    );

    final currentUser = FirebaseAuth.instance.currentUser;
    String actorName = 'Unknown';

    if (currentUser != null) {
      final currentUserDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
      if (currentUserDoc.exists) {
        final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
        actorName = currentUserData['name'] ?? currentUser.email ?? 'Unknown';
      }
    }

    final docData = doc.data() as Map<String, dynamic>;

    // 🔹 FIXED: Check which collection this document belongs to
    String deletedContent;
    String collectionName;

    if (docData.containsKey('message')) {
      // This is from message_logs collection
      deletedContent = docData['message'] ?? 'Unknown';
      collectionName = 'message_logs';
    } else {
      // This is from logs collection (User Activity Logs)
      deletedContent = docData['action'] ?? 'Unknown';
      collectionName = 'logs';
    }

    // 🔹 FIXED: Delete from the correct collection
    await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(doc.id)
        .delete();

    // 🔹 Only log to 'logs' collection if we deleted a message log
    // (Don't create a log when deleting a log - prevents recursion)
    if (collectionName == 'message_logs') {
      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'action': 'Deleted Message Log: $deletedContent',
        'time': Timestamp.now(),
      });
    }

    if (context.mounted) {
      // Close loading dialog
      Navigator.of(context).pop();
      // Close confirmation dialog
      Navigator.of(context).pop();
      // Close info modal
      Navigator.of(context).pop();

      SnackbarUtil.showSuccess(
        context,
        collectionName == 'message_logs'
            ? 'Message log deleted successfully'
            : 'Activity log deleted successfully',
      );
    }
  } catch (error) {
    if (context.mounted) {
      // Close loading dialog
      Navigator.of(context).pop();

      SnackbarUtil.showError(context, 'Delete failed: $error');
    }
  }
}
