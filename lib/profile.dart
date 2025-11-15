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

  // FIXED: Simplified edit profile modal navigation
  void _showEditProfileModal() {
    Navigator.of(context).pop(); // Close current ProfileModal

    // Show EditProfileModal immediately without delay
    showEditProfileModal(
      context,
      showBackButton: true, // Enable back button when coming from ProfileModal
    );
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
    final name = data['name'] ?? 'User';
    final email = data['email'] ?? '';
    final lastLoginAt = data['lastLoginAt'] as Timestamp?;
    final lastLoginFormatted = _formatLastLogin(lastLoginAt);

    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 28),
      decoration: BoxDecoration(color: Color(0xFF2E7D32)),
      child: Row(
        children: [
          // Profile Image
          Container(
            width: isMobile ? 88 : 96,
            height: isMobile ? 88 : 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFECFDF5), // Green-50
                  Color(0xFFBBF7D0), // Green-200 - slightly brighter
                ],
              ),
              borderRadius: BorderRadius.circular(isMobile ? 44 : 48),
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
              color: const Color(0xFF2E7D32), // Your specified green
              size: isMobile ? 42 : 48,
            ),
          ),
          const SizedBox(width: 24),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Profile',
                  style: TextStyle(
                    fontSize: isMobile ? 26 : 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
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
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Last login: $lastLoginFormatted',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 24,
              ),
              style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormRow({
    required String label,
    required Widget child,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border:
            isLast
                ? null
                : Border(
                  bottom: BorderSide(
                    color: const Color(0xFFE5E7EB).withOpacity(0.6),
                    width: 1,
                  ),
                ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildTextValue(String value, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(
                0xFF2E7D32,
              ).withOpacity(0.12), // Your specified green with transparency
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF2E7D32),
            ), // Your specified green
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'Not specified',
            style: TextStyle(
              fontSize: 15,
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
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 28),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Edit Profile Button
          SizedBox(
            height: isMobile ? 44 : 48,
            child: ElevatedButton.icon(
              onPressed: _showEditProfileModal,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFF2E7D32,
                ), // Your specified green
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: const Color(0xFF2E7D32).withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ).copyWith(
                textStyle: MaterialStateProperty.all(
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                overlayColor: MaterialStateProperty.all(
                  Colors.white.withOpacity(0.1),
                ),
              ),
            ),
          ),
        ],
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
          maxWidth: isMobile ? double.infinity : 650,
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
                  final data =
                      snapshot.data ??
                      {
                        'name':
                            snapshot.connectionState == ConnectionState.waiting
                                ? ''
                                : 'Error',
                        'email': '',
                        'lastLoginAt': null,
                      };
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
                            color: Color(0xFF059669), // Emerald-600
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

                    return Column(
                      children: [
                        // Form Content
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isMobile ? 24 : 28),
                            child: Column(
                              children: [
                                // Name field
                                _buildFormRow(
                                  label: 'Full Name',
                                  child: _buildTextValue(
                                    name,
                                    icon: Icons.person_outline_rounded,
                                  ),
                                ),
                                // Email field
                                _buildFormRow(
                                  label: 'Email Address',
                                  child: _buildTextValue(
                                    email,
                                    icon: Icons.email_outlined,
                                  ),
                                ),
                                if (role.toLowerCase() == 'user') ...[
                                  if (year.isNotEmpty)
                                    _buildFormRow(
                                      label: 'Year Level',
                                      child: _buildTextValue(
                                        year,
                                        icon: Icons.school_outlined,
                                      ),
                                    ),
                                  if (program.isNotEmpty)
                                    _buildFormRow(
                                      label: 'Program',
                                      child: _buildTextValue(
                                        program,
                                        icon: Icons.book_outlined,
                                      ),
                                    ),
                                  if (affiliation.isNotEmpty)
                                    _buildFormRow(
                                      label: 'Affiliations',
                                      child: _buildTextValue(
                                        affiliation,
                                        icon: Icons.people_outline,
                                      ),
                                    ),

                                  if (scholarship.isNotEmpty)
                                    _buildFormRow(
                                      label: 'Scholarship',
                                      child: _buildTextValue(
                                        scholarship,
                                        icon: Icons.card_membership_outlined,
                                      ),
                                      isLast: true,
                                    ),
                                ] else
                                  const SizedBox(),
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
