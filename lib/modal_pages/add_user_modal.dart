import 'package:capstone_project/pages/admin_pages/affiliation.dart';
import 'package:capstone_project/pages/admin_pages/scholarship_management.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';
import 'package:capstone_project/modal_pages/programs.modal.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:capstone_project/services/admin_functions.dart';

import 'modal_widget/top_right_alert.dart';

void showAddUserModal(BuildContext context, {Function(int)? onNavigateToPage}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Add User',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return AddUserModal(onNavigateToPage: onNavigateToPage);
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

class AddUserModal extends StatelessWidget {
  final Function(int)? onNavigateToPage;

  const AddUserModal({Key? key, this.onNavigateToPage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBody: _buildModal(context, true, false, false),
      tabletBody: _buildModal(context, false, true, false),
      desktopBody: _buildModal(context, false, false, true),
    );
  }

  Widget _buildModal(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Responsive dimensions
    double modalWidth;
    double modalHeight;
    EdgeInsets modalPadding;

    if (isMobile) {
      modalWidth = screenWidth * 0.95;
      modalHeight = screenHeight * 0.90;
      modalPadding = const EdgeInsets.all(16);
    } else if (isTablet) {
      modalWidth = screenWidth * 0.80;
      modalHeight = screenHeight * 0.85;
      modalPadding = const EdgeInsets.all(24);
    } else {
      modalWidth = 700;
      modalHeight = screenHeight * 0.80;
      modalPadding = const EdgeInsets.all(32);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: modalPadding,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: modalWidth,
          height: modalHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
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
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            child: AddUserContent(
              isMobile: isMobile,
              isTablet: isTablet,
              isDesktop: isDesktop,
              onNavigateToPage: onNavigateToPage,
            ),
          ),
        ),
      ),
    );
  }
}

class AddUserContent extends StatefulWidget {
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final Function(int)? onNavigateToPage;

  const AddUserContent({
    Key? key,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    this.onNavigateToPage,
  }) : super(key: key);

  @override
  State<AddUserContent> createState() => _AddUserContentState();
}

class _AddUserContentState extends State<AddUserContent> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _affiliationController = TextEditingController();
  final _scholarshipController = TextEditingController();

  String _selectedRole = 'User';
  String _selectedYear = 'N/A';
  String _selectedProgram = 'N/A';
  String _selectedAffiliation = 'N/A';
  String _selectedScholarship = 'N/A';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;

  final List<String> _programs = ['N/A'];
  final List<String> _affiliations = ['N/A'];
  final List<String> _scholarships = ['N/A'];
  bool isLoadingPrograms = true;
  bool isLoadingAffiliations = true;
  bool isLoadingScholarships = true;

  final roles = ['admin', 'user', 'staff'];
  List<String> get displayRoles =>
      roles.map((role) => role[0].toUpperCase() + role.substring(1)).toList();

  final years = [
    'N/A',
    'Incoming',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    'Graduate',
  ];

  @override
  void initState() {
    super.initState();
    _fetchPrograms();
    _fetchAffiliations();
    _fetchScholarships();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _affiliationController.dispose();
    _scholarshipController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrograms() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('programs')
              .orderBy('name')
              .get();

      setState(() {
        _programs.clear();
        _programs.add('N/A');
        _programs.addAll(snapshot.docs.map((doc) => doc['name'] as String));
        isLoadingPrograms = false;
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
      });
    } catch (e) {
      setState(() {
        isLoadingScholarships = false;
      });
      print('Error fetching scholarships: $e');
    }
  }

  bool get isYearEnabled {
    return _selectedRole.toLowerCase() == 'user';
  }

  bool get isProgramEnabled {
    return _selectedRole.toLowerCase() == 'user' &&
        _selectedYear != 'N/A' &&
        _selectedYear != 'Incoming' &&
        _selectedYear != 'Graduate';
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      _showTopRightAlert(
        'Please enter both first and last name',
        AlertType.warning,
      );
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      _showTopRightAlert('Please enter email address', AlertType.warning);
      return;
    }

   final emailRegex = RegExp(
  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'
);

if (!emailRegex.hasMatch(_emailController.text.trim())) {
  _showTopRightAlert(
    'Please enter a valid email address',
    AlertType.warning,
  );
  return;
}
    if (_passwordController.text.trim().isEmpty) {
      _showTopRightAlert('Please enter password', AlertType.warning);
      return;
    }

    if (_passwordController.text.length < 6) {
      _showTopRightAlert('Password must be 6 characters', AlertType.warning);
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showTopRightAlert('Passwords do not match', AlertType.warning);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final affiliation = _affiliationController.text.trim();
      final scholarship = _scholarshipController.text.trim();

      final functionsService = FirebaseFunctionsService();
      String uid;

      try {
        uid = await functionsService.createUserAuth(
          email: email,
          password: password,
          displayName: fullName,
          affiliation: affiliation.isNotEmpty ? affiliation : null,
          scholarship: scholarship.isNotEmpty ? scholarship : null,
        );
        print('✅ User created in Authentication with UID: $uid');
      } catch (e) {
        print('❌ Failed to create user in Authentication: $e');
        _showTopRightAlert(
          'Failed to create user account: ${e.toString()}',
          AlertType.error,
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Step 2: Create user document in Firestore using the same UID
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': fullName,
          'email': email,
          'role': _selectedRole.toLowerCase().trim(),
          'year': _selectedYear.trim(),
          'program': _selectedProgram.trim(),
          'affiliation': affiliation,
          'scholarship': scholarship,
          'isActive': true,
          'createdAt': Timestamp.now(),
        });
        print('✅ User document created in Firestore');
      } catch (e) {
        print('❌ Failed to create Firestore document: $e');
        // Try to clean up the auth user if Firestore creation fails
        try {
          await functionsService.deleteUserAuth(uid);
          print('✅ Cleaned up auth user after Firestore failure');
        } catch (cleanupError) {
          print('⚠️ Could not clean up auth user: $cleanupError');
        }

        _showTopRightAlert(
          'Failed to create user document: ${e.toString()}',
          AlertType.error,
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Step 3: Log the action
      await _logCreateAction(fullName);

      _showTopRightAlert('User created successfully!', AlertType.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      print('❌ Unexpected error: $e');
      _showTopRightAlert('Failed to create user: $e', AlertType.error);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _logCreateAction(String userName) async {
    try {
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

      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': actorName,
        'action': 'Created new user: $userName',
        'time': Timestamp.now(),
      });
      print('✅ User creation logged successfully');
    } catch (e) {
      print('⚠️ Failed to log action: $e');
    }
  }

  void _showTopRightAlert(String message, AlertType type) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder:
          (context) => TopRightAlert(
            message: message,
            type: type,
            onDismiss: () => overlayEntry.remove(),
            isMobile: widget.isMobile,
            isTablet: widget.isTablet,
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(widget.isMobile ? 20 : 28),
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
                    Icons.person_add_outlined,
                    color: Colors.white,
                    size: widget.isMobile ? 24 : 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New User',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create a new user account',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 14 : 16,
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
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMobile ? 20 : 28,
                vertical: widget.isMobile ? 20 : 28,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information Section
                    buildSectionHeader(
                      'Personal Information',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 16),

                    // Name Fields
                    if (widget.isMobile) ...[
                      buildTextField(
                        controller: _firstNameController,
                        label: 'First Name',
                        hint: 'Enter first name...',
                        icon: Icons.person_outline,
                        isMobile: false,
                      ),
                      const SizedBox(height: 16),
                      buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        hint: 'Enter last name...',
                        icon: Icons.person_outline,
                        isMobile: false,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: buildTextField(
                              controller: _firstNameController,
                              label: 'First Name',
                              hint: 'Enter first name...',
                              icon: Icons.person_outline,
                              isMobile: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: buildTextField(
                              controller: _lastNameController,
                              label: 'Last Name',
                              hint: 'Enter last name...',
                              icon: Icons.person_outline,
                              isMobile: false,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Email Field
                    buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'Enter email address...',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      isMobile: false,
                    ),

                    const SizedBox(height: 24),

                    // Account Information Section
                    buildSectionHeader(
                      'Account Information',
                      Icons.settings_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Role and Year
                    if (widget.isMobile) ...[
                      _buildDropdownField(
                        label: 'Role',
                        value: _selectedRole,
                        items: displayRoles,
                        icon: Icons.badge_outlined,
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                            if (!isYearEnabled) {
                              _selectedYear = 'N/A';
                              _selectedProgram = 'N/A';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Year Level',
                        value: _selectedYear,
                        items: years,
                        icon: Icons.school_outlined,
                        isEnabled: isYearEnabled,
                        onChanged: (value) {
                          setState(() {
                            _selectedYear = value!;
                            if (!isProgramEnabled) {
                              _selectedProgram = 'N/A';
                            }
                          });
                        },
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              label: 'Role',
                              value: _selectedRole,
                              items: displayRoles,
                              icon: Icons.badge_outlined,
                              onChanged: (value) {
                                setState(() {
                                  _selectedRole = value!;
                                  if (!isYearEnabled) {
                                    _selectedYear = 'N/A';
                                    _selectedProgram = 'N/A';
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdownField(
                              label: 'Year Level',
                              value: _selectedYear,
                              items: years,
                              icon: Icons.school_outlined,
                              isEnabled: isYearEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value!;
                                  if (!isProgramEnabled) {
                                    _selectedProgram = 'N/A';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Program Field with Manage Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Program',
                            value: _selectedProgram,
                            items: _programs,
                            icon: Icons.class_outlined,
                            isEnabled: isProgramEnabled,
                            onChanged:
                                (value) =>
                                    setState(() => _selectedProgram = value!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close modal
                              widget.onNavigateToPage?.call(
                                12,
                              ); // Navigate to Programs page
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

                    // Affiliation and Scholarship Fields
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Affiliation',
                            value: _selectedAffiliation,
                            items:
                                _affiliations, // list fetched via _fetchAffiliations()
                            icon: Icons.business_outlined,
                            isEnabled: true,
                            onChanged:
                                (value) => setState(
                                  () => _selectedAffiliation = value!,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close modal
                              widget.onNavigateToPage?.call(
                                11,
                              ); // Navigate to Affiliations page
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

                    // Scholarship Dropdown + Manage Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Scholarship',
                            value: _selectedScholarship,

                            items:
                                _scholarships, // list fetched via _fetchScholarships()
                            icon: Icons.school_outlined,
                            isEnabled: true,

                            onChanged:
                                (value) => setState(
                                  () => _selectedScholarship = value!,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close modal
                              widget.onNavigateToPage?.call(
                                9,
                              ); // Navigate to Scholarship page
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
                    buildSectionHeader('Password', Icons.lock_outlined),
                    const SizedBox(height: 16),

                    // Password Fields
                    buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter password...',
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
                      controller: _confirmPasswordController,
                      isMobile: false,
                      label: 'Confirm Password',
                      hint: 'Confirm password...',
                      icon: Icons.lock_outlined,
                      isPassword: true,
                      isPasswordVisible: _isConfirmPasswordVisible,
                      onTogglePassword:
                          () => setState(
                            () =>
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible,
                          ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    _buildActionButtons(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
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
          constraints: const BoxConstraints(
            maxWidth: double.infinity, // ✅ ensures it doesn’t expand outwards
          ),
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
              isExpanded: true, // ✅ prevents horizontal text overflow
              alignment: Alignment.centerLeft, // ✅ keeps dropdown aligned
              menuMaxHeight: 250, // ✅ avoids vertical overflow
              items:
                  items.map((String item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        overflow:
                            TextOverflow.ellipsis, // ✅ truncate long names
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

  Widget _buildActionButtons() {
    double buttonHeight =
        widget.isMobile
            ? 40
            : widget.isTablet
            ? 44
            : 46;
    double fontSize = widget.isMobile ? 14 : 15;
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
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isMobile ? 16 : 20,
                ),
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
              onPressed: _isSubmitting ? null : _saveUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isMobile ? 16 : 20,
                ),
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
                            'Creating...',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                      : Text(
                        'Create User',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ),
      ],
    );
  }
}
