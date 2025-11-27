import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:capstone_project/edit_profile_modal.dart';

void showProfileModal(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Profile',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const ProfileModal();
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

class ProfileModal extends StatefulWidget {
  const ProfileModal({super.key});

  @override
  State<ProfileModal> createState() => _ProfileModalState();
}

class _ProfileModalState extends State<ProfileModal> {
  Future<Map<String, dynamic>?> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      return doc.data();
    }
    return null;
  }

  void _showEditProfileModal() {
    Navigator.of(context).pop();
    showEditProfileModal(context, showBackButton: true);
  }

  String _formatLastLogin(Timestamp? lastLoginAt) {
    if (lastLoginAt == null) return 'Never';

    final lastLogin = lastLoginAt.toDate();
    final now = DateTime.now();
    final difference = now.difference(lastLogin);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${lastLogin.day}/${lastLogin.month}/${lastLogin.year} at ${lastLogin.hour.toString().padLeft(2, '0')}:${lastLogin.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildProfileHeader(Map<String, dynamic> data, bool isMobile) {
    final lastLoginAt = data['lastLoginAt'] as Timestamp?;
    final lastLoginFormatted = _formatLastLogin(lastLoginAt);

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(color: Color(0xFF2E7D32)),
      child: Row(
        children: [
          // Profile Image
          Container(
            width: isMobile ? 70 : 96,
            height: isMobile ? 70 : 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFECFDF5), Color(0xFFBBF7D0)],
              ),
              borderRadius: BorderRadius.circular(isMobile ? 35 : 48),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.person_rounded,
              color: const Color(0xFF2E7D32),
              size: isMobile ? 35 : 48,
            ),
          ),
          const SizedBox(width: 16),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Profile',
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Last login: $lastLoginFormatted',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Close Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 22,
              ),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                minimumSize: Size(40, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required bool isMobile,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              value.isNotEmpty ? value : 'Not specified',
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                color:
                    value.isNotEmpty
                        ? const Color(0xFF111827)
                        : const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child:
          isMobile
              ? SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _showEditProfileModal,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: const Color(0xFF2E7D32).withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              : Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _showEditProfileModal,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: const Color(0xFF2E7D32).withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
              // Header
              FutureBuilder<Map<String, dynamic>?>(
                future: _getUserData(),
                builder: (context, snapshot) {
                  final data = snapshot.data ?? {'lastLoginAt': null};
                  return _buildProfileHeader(data, isMobile);
                },
              ),

              // Content
              Flexible(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _getUserData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        height: 300,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2E7D32),
                            strokeWidth: 3,
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data == null) {
                      return Container(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  size: 32,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Failed to load profile',
                                style: TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final data = snapshot.data!;
                    final role = data['role'] ?? 'User';
                    final email = data['email'] ?? '';
                    final year = data['year'] ?? '';
                    final program = data['program'] ?? '';
                    final name = data['name'] ?? '';
                    final scholarship = data['scholarship'] ?? '';
                    final affiliation = data['affiliation'] ?? '';
                    final studentId = data['studentId'] ?? '';
                    final lrn = data['lrn'] ?? '';
                    final serviceUnit = data['serviceUnit'] ?? '';

                    return Column(
                      children: [
                        // Form Content
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isMobile ? 16 : 24),
                            child: Column(
                              children: [
                                // Name field
                                _buildInfoCard(
                                  label: 'Full Name',
                                  value: name,
                                  icon: Icons.person_outline_rounded,
                                  isMobile: isMobile,
                                ),

                                // Email field
                                _buildInfoCard(
                                  label: 'Email Address',
                                  value: email,
                                  icon: Icons.email_outlined,
                                  isMobile: isMobile,
                                ),

                                // USER ROLE FIELDS
                                if (role.toLowerCase() == 'user') ...[
                                  // Show affiliation first
                                  if (affiliation.isNotEmpty)
                                    _buildInfoCard(
                                      label: 'Affiliation',
                                      value: affiliation,
                                      icon: Icons.business_outlined,
                                      isMobile: isMobile,
                                    ),

                                  // INCOMING FRESHMAN APPLICANT
                                  if (affiliation.toLowerCase() == 'incoming freshman applicant' && lrn.isNotEmpty)
                                    _buildInfoCard(
                                      label: 'LRN',
                                      value: lrn,
                                      icon: Icons.numbers_outlined,
                                      isMobile: isMobile,
                                    ),

                                  // CMU STUDENT FIELDS
                                  if (affiliation.toLowerCase() == 'cmu student') ...[
                                    if (studentId.isNotEmpty)
                                      _buildInfoCard(
                                        label: 'Student ID',
                                        value: studentId,
                                        icon: Icons.badge_outlined,
                                        isMobile: isMobile,
                                      ),
                                    if (year.isNotEmpty)
                                      _buildInfoCard(
                                        label: 'Year Level',
                                        value: year,
                                        icon: Icons.school_outlined,
                                        isMobile: isMobile,
                                      ),
                                    if (program.isNotEmpty)
                                      _buildInfoCard(
                                        label: 'Program',
                                        value: program,
                                        icon: Icons.book_outlined,
                                        isMobile: isMobile,
                                      ),
                                    if (scholarship.isNotEmpty)
                                      _buildInfoCard(
                                        label: 'Scholarship',
                                        value: scholarship,
                                        icon: Icons.card_membership_outlined,
                                        isMobile: isMobile,
                                      ),
                                  ],
                                ],

                                // STAFF ROLE FIELDS
                                if (role.toLowerCase() == 'staff' && serviceUnit.isNotEmpty)
                                  _buildInfoCard(
                                    label: 'Service Unit',
                                    value: serviceUnit,
                                    icon: Icons.work_outline,
                                    isMobile: isMobile,
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Action Buttons
                        _buildActionButtons(isMobile),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}