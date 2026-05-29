import 'package:capstone_project/crud/delete/delete.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/modules/admin/user_management/edit_user_modal.dart';

void showUserInfoModal(
  BuildContext context,
  DocumentSnapshot doc, {
  bool fromEdit = false,
}) {
  final data = doc.data() as Map<String, dynamic>;

  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final isTablet = screenWidth >= 600 && screenWidth < 1024;
  final isDesktop = screenWidth >= 1024;

  // Get created date if available
  final Timestamp? timeStamp = data['createdAt'];
  String formattedDate = 'Not available';
  if (timeStamp != null) {
    final DateTime date = timeStamp.toDate();
    formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'User Info',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Container(
          //  UPDATED WIDTH FROM 560 TO 600 TO MATCH EDIT MODAL
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
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
                          Icons.person_outline,
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
                              'User Details',
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Account information',
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

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 20 : 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Personal Information Section
                        _buildSectionHeader(
                          'Personal Information',
                          Icons.badge_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildContentCard(
                          child: Column(
                            children: [
                              _buildMetadataRow(
                                'Full Name',
                                data['name'] ?? 'Not available',
                                Icons.person_outline,
                              ),
                              const SizedBox(height: 16),
                              _buildMetadataRow(
                                'Email',
                                data['email'] ?? 'Not available',
                                Icons.email_outlined,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Account Information Section
                        _buildSectionHeader(
                          'Account Information',
                          Icons.settings_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildContentCard(
                          child: Column(
                            children: [
                              _buildMetadataRow(
                                'Role',
                                _formatRole(data['role']),
                                Icons.admin_panel_settings_outlined,
                              ),

                              // Show affiliation for users
                              if (data['role']?.toString().toLowerCase() ==
                                  'user') ...[
                                // Show affiliation
                                if (data['affiliation'] != null) ...[
                                  const SizedBox(height: 16),
                                  _buildMetadataRow(
                                    'Affiliation',
                                    data['affiliation'],
                                    Icons.business_outlined,
                                  ),
                                ],

                                // CMU STUDENT - Show student fields
                                if (data['affiliation']
                                        ?.toString()
                                        .toLowerCase() ==
                                    'cmu student') ...[
                                  if (data['studentType'] != null) ...[
                                    const SizedBox(height: 16),
                                    _buildMetadataRow(
                                      'Student Type',
                                      data['studentType'] == 'undergraduate'
                                          ? 'Undergraduate'
                                          : data['studentType'] == 'graduate'
                                          ? 'Graduate'
                                          : data['studentType'],
                                      Icons.school_outlined,
                                    ),
                                  ],

                                  // UNDERGRADUATE
                                  if (data['studentType'] ==
                                      'undergraduate') ...[
                                    if (data['studentId'] != null) ...[
                                      const SizedBox(height: 16),
                                      _buildMetadataRow(
                                        'Student ID',
                                        data['studentId'],
                                        Icons.badge_outlined,
                                      ),
                                    ],
                                    if (data['year'] != null) ...[
                                      const SizedBox(height: 16),
                                      _buildMetadataRow(
                                        'Year Level',
                                        data['year'],
                                        Icons.calendar_today_outlined,
                                      ),
                                    ],
                                    if (data['college'] != null) ...[
                                      const SizedBox(height: 16),
                                      _buildMetadataRow(
                                        'College',
                                        data['college'],
                                        Icons.account_balance_outlined,
                                      ),
                                    ],
                                    if (data['program'] != null) ...[
                                      const SizedBox(height: 16),
                                      _buildMetadataRow(
                                        'Program',
                                        data['program'],
                                        Icons.book_outlined,
                                      ),
                                    ],
                                    if (data['scholarship'] != null) ...[
                                      const SizedBox(height: 16),
                                      _buildMetadataRow(
                                        'Scholarship',
                                        data['scholarship'],
                                        Icons.card_membership_outlined,
                                      ),
                                    ],
                                  ],

                                  // GRADUATE
                                  if (data['studentType'] == 'graduate') ...[
                                    if (data['graduateType'] != null) ...[
                                      const SizedBox(height: 16),
                                      _buildMetadataRow(
                                        'Graduate Status',
                                        data['graduateType'] == 'masteral'
                                            ? 'Taking Masteral'
                                            : data['graduateType'] ==
                                                'not_masteral'
                                            ? 'Already Graduated'
                                            : data['graduateType'],
                                        Icons.school,
                                      ),
                                    ],

                                    // MASTERAL GRADUATE
                                    if (data['graduateType'] == 'masteral') ...[
                                      if (data['college'] != null) ...[
                                        const SizedBox(height: 16),
                                        _buildMetadataRow(
                                          'College',
                                          data['college'],
                                          Icons.account_balance_outlined,
                                        ),
                                      ],
                                      if (data['program'] != null) ...[
                                        const SizedBox(height: 16),
                                        _buildMetadataRow(
                                          'Masteral Program',
                                          data['program'],
                                          Icons.book_outlined,
                                        ),
                                      ],
                                    ],

                                    // NOT MASTERAL GRADUATE
                                    if (data['graduateType'] ==
                                        'not_masteral') ...[
                                      if (data['graduatedCollege'] != null) ...[
                                        const SizedBox(height: 16),
                                        _buildMetadataRow(
                                          'Graduated College',
                                          data['graduatedCollege'],
                                          Icons.account_balance_outlined,
                                        ),
                                      ],
                                      if (data['graduatedProgram'] != null) ...[
                                        const SizedBox(height: 16),
                                        _buildMetadataRow(
                                          'Graduated Program',
                                          data['graduatedProgram'],
                                          Icons.book_outlined,
                                        ),
                                      ],
                                    ],
                                  ],
                                ],

                                // INCOMING FRESHMAN APPLICANT
                                if (data['affiliation']
                                        ?.toString()
                                        .toLowerCase() ==
                                    'incoming freshman applicant') ...[
                                  if (data['lrn'] != null) ...[
                                    const SizedBox(height: 16),
                                    _buildMetadataRow(
                                      'LRN',
                                      data['lrn'],
                                      Icons.numbers_outlined,
                                    ),
                                  ],
                                  if (data['scholarship'] != null) ...[
                                    const SizedBox(height: 16),
                                    _buildMetadataRow(
                                      'Scholarship',
                                      data['scholarship'],
                                      Icons.card_membership_outlined,
                                    ),
                                  ],
                                ],

                                // MASTERAL (NOT CMU GRADUATE)
                                if (data['affiliation']
                                        ?.toString()
                                        .toLowerCase() ==
                                    'masteral (not cmu graduate)') ...[
                                  if (data['program'] != null) ...[
                                    const SizedBox(height: 16),
                                    _buildMetadataRow(
                                      'Masteral Program',
                                      data['program'],
                                      Icons.book_outlined,
                                    ),
                                  ],
                                ],
                              ],

                              // Show service unit for staff
                              if (data['role']?.toString().toLowerCase() ==
                                  'staff') ...[
                                const SizedBox(height: 16),
                                _buildMetadataRow(
                                  'Service Unit',
                                  data['serviceUnit'] ?? 'Not specified',
                                  Icons.work_outline,
                                ),
                              ],

                              const SizedBox(height: 16),
                              _buildMetadataRow(
                                'Status',
                                data['isActive'] == true
                                    ? 'Active'
                                    : 'Inactive',
                                Icons.circle_outlined,
                                statusColor:
                                    data['isActive'] == true
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFEF4444),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Metadata Section
                        _buildSectionHeader('Metadata', Icons.info_outline),
                        const SizedBox(height: 12),
                        _buildContentCard(
                          child: _buildMetadataRow(
                            'Created',
                            formattedDate,
                            Icons.schedule_outlined,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Action Buttons
                        _buildActionButtons(
                          context,
                          doc,
                          isMobile,
                          isTablet,
                          isDesktop,
                        ),
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

Widget _buildActionButtons(
  BuildContext context,
  DocumentSnapshot doc,
  bool isMobile,
  bool isTablet,
  bool isDesktop,
) {
  double buttonHeight =
      isMobile
          ? 40
          : isTablet
          ? 44
          : 46;
  double fontSize = isMobile ? 14 : 15;
  double borderRadius = 10;

  return Row(
    children: [
      // Delete Button
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () {
              //  Show delete confirmation (removed async/await)
              showDeleteConfirmation(
                context,
                doc,
                DeleteConfigs.users,
                'users',
                customDeleteHandler: (ctx, document) async {
                  // Perform the delete operation
                  await handleUserDelete(ctx, document);

                  // Close user info modal after successful deletion
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(
              'Delete',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
          ),
        ),
      ),

      const SizedBox(width: 12),
      // Edit Button
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Future.delayed(
                const Duration(milliseconds: 200),
                () => showEditUserModal(context, doc, previousModal: 'info'),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              'Edit',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildSectionHeader(String title, IconData icon) {
  return Row(
    children: [
      Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
          letterSpacing: -0.2,
        ),
      ),
    ],
  );
}

Widget _buildContentCard({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
    ),
    child: child,
  );
}

Widget _buildMetadataRow(
  String label,
  String value,
  IconData icon, {
  Color? statusColor,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF64748B)),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Row(
          children: [
            if (statusColor != null && label == 'Status') ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: statusColor ?? const Color(0xFF334155),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

String _formatRole(dynamic role) {
  if (role == null) return 'Not specified';
  final roleStr = role.toString().toLowerCase();
  switch (roleStr) {
    case 'admin':
      return 'Administrator';
    case 'staff':
      return 'Staff Member';
    case 'user':
      return 'User';
    default:
      return roleStr[0].toUpperCase() + roleStr.substring(1);
  }
}
