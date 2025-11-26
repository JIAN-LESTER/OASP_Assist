// Enhanced escalation_info.dart with improved UI design
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/utils/snackbar_util.dart';

class EscalationDetailModal extends StatefulWidget {
  final String escalationId;
  final Map<String, dynamic> escalationData;

  const EscalationDetailModal({
    super.key,
    required this.escalationId,
    required this.escalationData,
  });

  @override
  State<EscalationDetailModal> createState() => _EscalationDetailModalState();
}

class _EscalationDetailModalState extends State<EscalationDetailModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _replyController = TextEditingController();
  bool _isSending = false;
  Map<String, dynamic>? _userData;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _showFullBotResponse = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = widget.escalationData['userId'];
      if (userId != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

        if (userDoc.exists && mounted) {
          setState(() {
            _userData = userDoc.data();
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'resolved':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'resolved':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) {
      SnackbarUtil.showError(context, 'Please enter a response');
      return;
    }

    final data = widget.escalationData;
    final question = data['question']?.toString() ?? 'unknown';
    final userId = data['userId'] as String?;
    final conversationId = data['conversationId'] as String?;

    if (conversationId == null || conversationId.isEmpty) {
      SnackbarUtil.showError(context, 'Invalid conversation ID');
      return;
    }

    setState(() => _isSending = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final staffDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser?.uid)
              .get();

      final staffName = staffDoc.data()?['name'] ?? 'Staff';
      final staffResponse = _replyController.text.trim();

      final batch = FirebaseFirestore.instance.batch();

      final escalationRef = FirebaseFirestore.instance
          .collection('escalations')
          .doc(widget.escalationId);

      batch.update(escalationRef, {
        'staffResponse': staffResponse,
        'status': 'resolved',
        'respondedBy': staffName,
        'respondedAt': Timestamp.now(),
      });

      final staffMessageRef =
          FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .doc();

      final staffMessageContent =
          '**Staff Response from $staffName:**\n\n$staffResponse';

      batch.set(staffMessageRef, {
        'messageID': staffMessageRef.id,
        'conversationID': conversationId,
        'content': staffMessageContent,
        'sender': 'staff',
        'userID': userId ?? '',
        'message_status': 'sent',
        'message_type': 'text',
        'sent_at': Timestamp.now(),
        'responded_at': Timestamp.now(),
        'isAnswered': true,
        'category': 'Escalation Response',
      });

      if (userId != null && userId.isNotEmpty) {
        final notificationRef =
            FirebaseFirestore.instance.collection('notifications').doc();

        batch.set(notificationRef, {
          'notificationId': notificationRef.id,
          'userId': userId,
          'title': 'Staff Response Received',
          'body':
              'A staff member has responded to your escalated question: "$question"',
          'type': 'escalation_response',
          'relatedId': widget.escalationId,
          'targetRole': 'user',
          'read': false,
          'createdAt': Timestamp.now(),
          'data': {
            'escalationId': widget.escalationId,
            'conversationId': conversationId,
            'staffResponse': staffResponse,
            'respondedBy': staffName,
          },
        });
      }

      await batch.commit();

      if (mounted) {
        SnackbarUtil.showSuccess(context, 'Response sent successfully!');
        HapticFeedback.lightImpact();
      }

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        await _animationController.reverse();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      print('❌ Error sending response: $e');
      if (mounted) {
        SnackbarUtil.showError(
          context,
          'Failed to send response: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _closeModal() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.escalationData;
    final status = data['status']?.toString() ?? 'unknown';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return WillPopScope(
      onWillPop: () async {
        await _closeModal();
        return false;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 700,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with Gradient
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 28),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.support_agent,
                              color: Colors.white,
                              size: isMobile ? 26 : 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Escalation Details',
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      status,
                                    ).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getStatusIcon(status),
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _isSending ? null : _closeModal,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content Area
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 20 : 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User Information Card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: Color(0xFF2E7D32),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'User Information',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildUserInfoRow(
                                    icon: Icons.person_outline,
                                    label: 'Name',
                                    value: _userData?['name'] ?? 'Loading...',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildUserInfoRow(
                                    icon: Icons.email_outlined,
                                    label: 'Email',
                                    value: _userData?['email'] ?? 'Loading...',
                                  ),
                                  if (_userData?['affiliation'] != null) ...[
                                    const SizedBox(height: 16),
                                    _buildUserInfoRow(
                                      icon: Icons.business,
                                      label: 'Affiliation',
                                      value: _userData!['affiliation'],
                                    ),
                                  ],
                                  if (_userData?['program'] != null) ...[
                                    const SizedBox(height: 16),
                                    _buildUserInfoRow(
                                      icon: Icons.school_outlined,
                                      label: 'Program',
                                      value: _userData!['program'],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Question Section
                            _buildSection(
                              title: 'Question',
                              icon: Icons.help_outline,
                              iconColor: const Color(0xFF2E7D32),
                              child: Text(
                                data['question'] ?? 'No question provided',
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Bot Response Section with See More/Less
                            _buildSection(
                              title: 'Bot Response',
                              icon: Icons.smart_toy,
                              iconColor: const Color(0xFF2E7D32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['botAnswer'] ??
                                        'No bot response available',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.6,
                                      color: Color(0xFF1F2937),
                                    ),
                                    maxLines: _showFullBotResponse ? null : 3,
                                    overflow:
                                        _showFullBotResponse
                                            ? null
                                            : TextOverflow.ellipsis,
                                  ),
                                  if ((data['botAnswer'] ?? '').length > 200)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _showFullBotResponse =
                                                  !_showFullBotResponse;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _showFullBotResponse
                                                      ? 'See less'
                                                      : 'See more',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1976D2),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  _showFullBotResponse
                                                      ? Icons.keyboard_arrow_up
                                                      : Icons
                                                          .keyboard_arrow_down,
                                                  size: 18,
                                                  color: const Color(
                                                    0xFF2E7D32,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Reason and Date Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoChip(
                                    title: 'Reason',
                                    content: data['reason'] ?? 'N/A',
                                    icon: Icons.report_problem,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoChip(
                                    title: 'Submitted',
                                    content: _formatDate(
                                      data['createdAt'] as Timestamp?,
                                    ),
                                    icon: Icons.schedule,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),

                            if (data['staffResponse'] != null) ...[
                              const SizedBox(height: 24),
                              _buildSection(
                                title: 'Staff Response',
                                icon: Icons.admin_panel_settings,
                                iconColor: const Color(0xFF2E7D32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['staffResponse'],
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.6,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    if (data['respondedBy'] != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF2E7D32,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Responded by: ${data['respondedBy']}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],

                            if (status != 'resolved') ...[
                              const SizedBox(height: 24),
                              const Divider(height: 32),

                              // Response Field
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2E7D32,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.reply,
                                      color: Color(0xFF2E7D32),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Your Response',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              TextField(
                                controller: _replyController,
                                maxLines: 5,
                                enabled: !_isSending,
                                decoration: InputDecoration(
                                  hintText:
                                      'Type your response to help resolve this escalation...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF2E7D32),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: _isSending ? null : _closeModal,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6B7280),
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                          ),
                          if (status != 'resolved') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton.icon(
                                  onPressed: _isSending ? null : _sendReply,
                                  icon:
                                      _isSending
                                          ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Icon(
                                            Icons.send_rounded,
                                            size: 18,
                                          ),
                                  label: Text(
                                    _isSending ? 'Sending...' : 'Send Response',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
