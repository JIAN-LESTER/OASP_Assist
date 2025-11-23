import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';
import 'package:capstone_project/modal_pages/modal_widget/top_right_alert.dart';
import 'package:capstone_project/modal_pages/programs.modal.dart';

import 'package:capstone_project/pages/admin_pages/scholarship_management.dart';
import 'package:capstone_project/modal_pages/user_info.dart';
import 'package:capstone_project/services/admin_functions.dart';

void showEditUserModal(
  BuildContext context,
  DocumentSnapshot userDoc, {
  String? previousModal,
  Function(int)? onNavigateToPage,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Edit User',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return StatefulBuilder(
        builder: (context, setState) {
          return EditUserModal(
            userDoc: userDoc,
            previousModal: previousModal,
            onNavigateToPage: onNavigateToPage,
          );
        },
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

class EditUserModal extends StatefulWidget {
  final DocumentSnapshot userDoc;
  final String? previousModal;
  final Function(int)? onNavigateToPage;

  const EditUserModal({
    super.key,
    required this.userDoc,
    this.previousModal,
    this.onNavigateToPage,
  });

  @override
  State<EditUserModal> createState() => _EditUserModalState();
}

class _EditUserModalState extends State<EditUserModal> {
  final List<String> programs = ['N/A'];
  final List<String> _affiliations = ['N/A'];
  final List<String> _scholarships = ['N/A'];
  bool isLoadingPrograms = true;
  bool isLoadingAffiliations = true;
  bool isLoadingScholarships = true;

  final List<String> roles = ['admin', 'user', 'staff'];
  final List<String> years = [
    'N/A',
    'Incoming',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    'Graduate',
  ];

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  late String selectedRole;
  late String selectedYear;
  late String selectedProgram;
  String _selectedAffiliation = 'N/A';
  String _selectedScholarship = 'N/A';
  late bool isActive;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;

  bool get isYearEnabled => selectedRole == 'user';
  bool get isProgramEnabled =>
      selectedRole == 'user' &&
      selectedYear != 'N/A' &&
      selectedYear != 'Incoming' &&
      selectedYear != 'Graduate';

  @override
  void initState() {
    super.initState();
    final userData = widget.userDoc.data() as Map<String, dynamic>;

    final fullName = userData['name']?.toString().split(' ') ?? [''];
    firstNameController = TextEditingController(
      text: fullName.isNotEmpty ? fullName.first : '',
    );
    lastNameController = TextEditingController(
      text: fullName.length > 1 ? fullName.sublist(1).join(' ') : '',
    );
    emailController = TextEditingController(text: userData['email'] ?? '');

    selectedRole = userData['role'] ?? 'user';
    selectedYear = userData['year'] ?? '1st Year';
    selectedProgram = userData['program'] ?? 'N/A';
    _selectedAffiliation = userData['affiliation'] ?? 'N/A';
    _selectedScholarship = userData['scholarship'] ?? 'N/A';
    isActive = userData['isActive'] ?? true;

    _fetchPrograms();
    _fetchAffiliations();
    _fetchScholarships();
  }

  Future<void> _fetchPrograms() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('programs')
              .orderBy('name')
              .get();

      final fetchedPrograms = ['N/A'];
      fetchedPrograms.addAll(snapshot.docs.map((doc) => doc['name'] as String));

      setState(() {
        programs.clear();
        programs.addAll(fetchedPrograms);
        isLoadingPrograms = false;

        if (!programs.contains(selectedProgram)) {
          selectedProgram = 'N/A';
        }
      });
    } catch (e) {
      setState(() {
        isLoadingPrograms = false;
      });
      print('Error fetching programs: $e');
    }
  }

  Future<void> _fetchAffiliations() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('affiliations')
              .orderBy('name')
              .get();

      setState(() {
        _affiliations.clear();
        _affiliations.add('N/A');
        _affiliations.addAll(snapshot.docs.map((doc) => doc['name'] as String));
        isLoadingAffiliations = false;

        if (!_affiliations.contains(_selectedAffiliation)) {
          _selectedAffiliation = 'N/A';
        }
      });
    } catch (e) {
      setState(() {
        isLoadingAffiliations = false;
      });
      print('Error fetching affiliation: $e');
    }
  }

  Future<void> _fetchScholarships() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('scholarships')
              .orderBy('name')
              .get();

      setState(() {
        _scholarships.clear();
        _scholarships.add('N/A');
        _scholarships.addAll(snapshot.docs.map((doc) => doc['name'] as String));
        isLoadingScholarships = false;

        if (!_scholarships.contains(_selectedScholarship)) {
          _selectedScholarship = 'N/A';
        }
      });
    } catch (e) {
      setState(() {
        isLoadingScholarships = false;
      });
      print('Error fetching scholarships: $e');
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String getDisplayRole(String role) =>
      role[0].toUpperCase() + role.substring(1);

  String getOriginalRole(String displayRole) => displayRole.toLowerCase();

  void _showTopRightAlert(String message, AlertType type) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    overlayEntry = OverlayEntry(
      builder:
          (context) => TopRightAlert(
            message: message,
            type: type,
            onDismiss: () => overlayEntry.remove(),
            isMobile: isMobile,
            isTablet: isTablet,
          ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Container(
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
                    if (widget.previousModal == 'info') ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.of(context).pop();
                            Future.delayed(
                              const Duration(milliseconds: 200),
                              () {
                                showUserInfoModal(
                                  context,
                                  widget.userDoc,
                                  fromEdit: true,
                                );
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white.withOpacity(0.9),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_document,
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
                            'Edit User',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update user information',
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

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 20 : 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal Information Section
                      buildSectionHeader(
                        'Personal Information',
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 16),

                      isMobile
                          ? Column(
                            children: [
                              buildTextField(
                                isMobile: false,
                                controller: firstNameController,
                                label: "First Name",
                                hint: "Enter first name",
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 16),
                              buildTextField(
                                isMobile: false,
                                controller: lastNameController,
                                label: "Last Name",
                                hint: "Enter last name",
                                icon: Icons.person_outline,
                              ),
                            ],
                          )
                          : Row(
                            children: [
                              Expanded(
                                child: buildTextField(
                                  isMobile: false,
                                  controller: firstNameController,
                                  label: "First Name",
                                  hint: "Enter first name",
                                  icon: Icons.person_outline,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: buildTextField(
                                  isMobile: false,
                                  controller: lastNameController,
                                  label: "Last Name",
                                  hint: "Enter last name",
                                  icon: Icons.person_outline,
                                ),
                              ),
                            ],
                          ),

                      const SizedBox(height: 16),
                      buildTextField(
                        controller: emailController,
                        isMobile: false,
                        label: "Email Address",
                        hint: "Enter email address",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 32),

                      // Account Information Section
                      buildSectionHeader(
                        'Account Information',
                        Icons.settings_outlined,
                      ),
                      const SizedBox(height: 16),

                      _buildDropdownField(
                        label: "Role",
                        value: getDisplayRole(selectedRole),
                        items: roles.map(getDisplayRole).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedRole = getOriginalRole(val!);
                            if (selectedRole != 'user') {
                              selectedYear = 'N/A';
                              selectedProgram = 'N/A';
                            }
                          });
                        },
                        icon: Icons.badge_outlined,
                        isEnabled: true,
                      ),

                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: "Year Level",
                        value: selectedYear,
                        items: years,
                        onChanged:
                            isYearEnabled
                                ? (val) {
                                  setState(() {
                                    selectedYear = val!;
                                    if (selectedYear == 'N/A' ||
                                        selectedYear == 'Incoming' ||
                                        selectedYear == 'Graduate') {
                                      selectedProgram = 'N/A';
                                    }
                                  });
                                }
                                : null,
                        icon: Icons.school_outlined,
                        isEnabled: isYearEnabled,
                      ),

                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child:
                                isLoadingPrograms
                                    ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                    : _buildDropdownField(
                                      label: 'Program',
                                      value:
                                          programs.contains(selectedProgram)
                                              ? selectedProgram
                                              : 'N/A',
                                      items: programs,
                                      onChanged:
                                          isProgramEnabled
                                              ? (value) => setState(
                                                () => selectedProgram = value!,
                                              )
                                              : null,
                                      icon: Icons.class_outlined,
                                      isEnabled: isProgramEnabled,
                                    ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onNavigateToPage?.call(12);
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Manage'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Additional Information Section
                      buildSectionHeader(
                        'Additional Information',
                        Icons.info_outline,
                      ),
                      const SizedBox(height: 16),

                      // Affiliation Dropdown with Manage
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child:
                                isLoadingAffiliations
                                    ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                    : _buildDropdownField(
                                      label: 'Affiliation',
                                      value:
                                          _affiliations.contains(
                                                _selectedAffiliation,
                                              )
                                              ? _selectedAffiliation
                                              : 'N/A',
                                      items: _affiliations,
                                      icon: Icons.business_outlined,
                                      isEnabled: true,
                                      onChanged:
                                          (value) => setState(
                                            () => _selectedAffiliation = value!,
                                          ),
                                    ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onNavigateToPage?.call(11);
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Manage'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Scholarship Dropdown with Manage
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child:
                                isLoadingScholarships
                                    ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                    : _buildDropdownField(
                                      label: 'Scholarship',
                                      value:
                                          _scholarships.contains(
                                                _selectedScholarship,
                                              )
                                              ? _selectedScholarship
                                              : 'N/A',
                                      items: _scholarships,
                                      icon: Icons.school_outlined,
                                      isEnabled: true,
                                      onChanged:
                                          (value) => setState(
                                            () => _selectedScholarship = value!,
                                          ),
                                    ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onNavigateToPage?.call(9);
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Manage'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Password Section
                      buildSectionHeader(
                        'Change Password',
                        Icons.lock_outlined,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Leave blank to keep current password',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Fields
                      buildTextField(
                        controller: passwordController,
                        label: 'New Password',
                        hint: 'Enter new password...',
                        icon: Icons.lock_outlined,
                        isPassword: true,
                        isPasswordVisible: _isPasswordVisible,
                        isMobile: false,
                        onTogglePassword:
                            () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                      ),

                      const SizedBox(height: 16),

                      buildTextField(
                        controller: confirmPasswordController,
                        isMobile: false,
                        label: 'Confirm New Password',
                        hint: 'Confirm new password...',
                        icon: Icons.lock_outlined,
                        isPassword: true,
                        isPasswordVisible: _isConfirmPasswordVisible,
                        onTogglePassword:
                            () => setState(
                              () =>
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible,
                            ),
                      ),

                      const SizedBox(height: 24),

                      // Status Section
                      buildSectionHeader('Status', Icons.toggle_on_outlined),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle_outlined,
                              size: 18,
                              color:
                                  isActive
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Account Status',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Switch(
                              value: isActive,
                              activeColor: const Color(0xFF2E7D32),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              onChanged:
                                  (val) => setState(() => isActive = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Fixed Action Buttons at Bottom
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                ),
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                child: _buildActionButtons(
                  context,
                  isMobile,
                  isTablet,
                  isDesktop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
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
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton(
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).pop(),
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
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
              ),
              child:
                  _isSubmitting
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Updating...',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    if (firstNameController.text.trim().isEmpty) {
      _showTopRightAlert('Please enter a first name', AlertType.warning);
      return;
    }

    // Validate password if entered
    if (passwordController.text.isNotEmpty) {
      if (passwordController.text.length < 6) {
        _showTopRightAlert(
          'Password must be at least 6 characters',
          AlertType.warning,
        );
        return;
      }

      if (passwordController.text != confirmPasswordController.text) {
        _showTopRightAlert('Passwords do not match', AlertType.warning);
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userData = widget.userDoc.data() as Map<String, dynamic>;
      final originalEmail = userData['email'] ?? '';
      final newEmail = emailController.text.trim();
      final newDisplayName =
          '${firstNameController.text.trim()} ${lastNameController.text.trim()}';

      // Update email and/or password in Firebase Authentication if changed
      if (newEmail != originalEmail || passwordController.text.isNotEmpty) {
        try {
          final functionsService = FirebaseFunctionsService();
          await functionsService.updateUserAuth(
            uid: widget.userDoc.id,
            email: newEmail != originalEmail ? newEmail : null,
            displayName: newDisplayName,
            password:
                passwordController.text.isNotEmpty
                    ? passwordController.text.trim()
                    : null,
          );
          print('✅ User updated in Firebase Authentication');
        } catch (e) {
          print('⚠️ Failed to update in Authentication: $e');
          setState(() {
            _isSubmitting = false;
          });
          _showTopRightAlert(
            'Failed to update authentication: ${e.toString()}',
            AlertType.error,
          );
          return;
        }
      }

      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userDoc.id)
          .update({
            'name': newDisplayName,
            'email': newEmail,
            'role': selectedRole.toLowerCase(),
            'year': selectedYear,
            'program': selectedProgram,
            'affiliation': _selectedAffiliation,
            'scholarship': _selectedScholarship,
            'isActive': isActive,
            'updatedAt': Timestamp.now(),
          });
      print('✅ User document updated in Firestore');

      // Log the action
      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = 'Unknown';

      if (currentUser != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          actorName = data['name'] ?? currentUser.email ?? 'Unknown';
        }
      }

      final originalName = userData['name'] ?? 'Unknown';
      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      final logData = {
        'logId': logRef.id,
        'user': actorName,
        'action': 'Updated User: $originalName to $newDisplayName',
        'time': Timestamp.now(),
      };
      await logRef.set(logData);
      print('✅ Update logged successfully');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        _showTopRightAlert('User updated successfully!', AlertType.success);

        // Close modal after short delay to show success message
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      print('❌ Error updating user: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showTopRightAlert(
          'Failed to update: ${e.toString()}',
          AlertType.error,
        );
      }
    }
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    required IconData icon,
    bool isEnabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                isEnabled ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          decoration: BoxDecoration(
            color: isEnabled ? Colors.white : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            boxShadow:
                isEnabled
                    ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                    : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: value,
              onChanged: isEnabled ? onChanged : null,
              isExpanded: true,
              alignment: Alignment.centerLeft,
              menuMaxHeight: 250,
              items:
                  items.map((String item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isEnabled
                                  ? const Color(0xFF1F2937)
                                  : const Color(0xFF9CA3AF),
                        ),
                      ),
                    );
                  }).toList(),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color:
                      isEnabled
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFFD1D5DB),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              dropdownColor: Colors.white,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
            ),
          ),
        ),
      ],
    );
  }
}
