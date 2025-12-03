import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';
import 'package:capstone_project/utils/snackbar_util.dart';
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _studentIdController;
  late final TextEditingController _lrnController;
  late final TextEditingController _customScholarshipController;

  String _selectedRole = 'User';
  String _selectedYear = 'N/A';
  String _selectedProgram = 'N/A';
  String _selectedAffiliation = 'N/A';
  String _selectedScholarship = 'N/A';
  String _selectedServiceUnit = 'N/A';
  String _selectedCollege = 'N/A';
  String _selectedCollegeId = '';
  String _customScholarship = '';

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;
  bool isActive = true; // Only for edit_user

  Map<String, String> _collegesMap = {};
  List<String> _masteralPrograms = [];

  final List<String> _programs = ['N/A'];
  final List<String> _affiliations = [
    'N/A',
    'CMU Student',
    'Incoming Freshman Applicant',
    'Parent',
    'Faculty',
    'CMU Staff',
    'Masteral (Not CMU Graduate)',
  ];
  final List<String> _scholarships = ['N/A'];
  final List<String> _serviceUnits = [
    'N/A',
    'Admission',
    'Scholarship',
    'Placement',
  ];
  final List<String> roles = ['admin', 'user', 'staff'];
  final List<String> years = [
    'N/A',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];

  bool isLoadingPrograms = true;
  bool isLoadingScholarships = true;

  // ====================================================================
  // 2. GETTERS (Same for both modals)
  // ====================================================================
  Map<String, String> get _colleges {
    Map<String, String> collegesWithNA = {'N/A': ''};
    collegesWithNA.addAll(_collegesMap);
    return collegesWithNA;
  }

  final List<String> programs = ['N/A'];

  String _selectedStudentType = 'N/A'; // 'undergraduate' or 'graduate'
  String _selectedGraduateType = 'N/A'; // 'masteral' or 'not_masteral'
  String _graduatedCollege = 'N/A';
  String _graduatedCollegeId = '';
  String _graduatedProgram = 'N/A';

  Map<String, List<String>> _programsByCollege = {};

  String _notEnrolledType = 'N/A'; // 'incoming_freshman', 'masteral', 'others'

  bool _customScholarshipConfirmed = false;

  List<String> get displayRoles =>
      roles.map((role) => role[0].toUpperCase() + role.substring(1)).toList();

  bool get shouldShowAffiliation {
    return _selectedRole.toLowerCase() == 'user';
  }

  bool get shouldShowStudentFields {
    return _selectedRole.toLowerCase() == 'user' &&
        _selectedAffiliation.toLowerCase() == 'cmu student';
  }

  bool get shouldShowStudentTypeSelection {
    return shouldShowStudentFields;
  }

  bool get shouldShowUndergraduateFields {
    return shouldShowStudentFields && _selectedStudentType == 'undergraduate';
  }

  bool get shouldShowGraduateFields {
    return shouldShowStudentFields && _selectedStudentType == 'graduate';
  }

  bool get shouldShowGraduateTypeSelection {
    return shouldShowGraduateFields;
  }

  bool get shouldShowMasteralGraduateFields {
    return shouldShowGraduateFields && _selectedGraduateType == 'masteral';
  }

  bool get shouldShowNotMasteralGraduateFields {
    return shouldShowGraduateFields && _selectedGraduateType == 'not_masteral';
  }

  bool get shouldShowLRNField {
    return _selectedRole.toLowerCase() == 'user' &&
        _selectedAffiliation.toLowerCase() == 'incoming freshman applicant';
  }

  bool get shouldShowMasteralNotCMUFields {
    return _selectedRole.toLowerCase() == 'user' &&
        _selectedAffiliation.toLowerCase() == 'masteral (not cmu graduate)';
  }

  bool get shouldShowServiceUnit {
    return _selectedRole.toLowerCase() == 'staff';
  }

  List<String> get _undergraduatePrograms {
    if (_selectedCollege == 'N/A' || _selectedCollegeId.isEmpty) {
      return ['N/A'];
    }
    final key = '${_selectedCollegeId}_Bachelor';
    return ['N/A', ...(_programsByCollege[key] ?? [])];
  }

  List<String> get _masteralProgramsList {
    return ['N/A', ..._masteralPrograms];
  }

  Future<bool> _isStudentIdUnique(
    String studentId, {
    String? excludeUserId,
  }) async {
    try {
      final query =
          await FirebaseFirestore.instance
              .collection('users')
              .where('studentId', isEqualTo: studentId.trim())
              .get();

      if (query.docs.isEmpty) return true;

      // If excluding a user (for edit), check if the only match is that user
      if (excludeUserId != null) {
        return query.docs.every((doc) => doc.id == excludeUserId);
      }

      return false;
    } catch (e) {
      print('Error checking student ID uniqueness: $e');
      return false;
    }
  }

  Future<bool> _isLRNUnique(String lrn, {String? excludeUserId}) async {
    try {
      final query =
          await FirebaseFirestore.instance
              .collection('users')
              .where('lrn', isEqualTo: lrn.trim())
              .get();

      if (query.docs.isEmpty) return true;

      // If excluding a user (for edit), check if the only match is that user
      if (excludeUserId != null) {
        return query.docs.every((doc) => doc.id == excludeUserId);
      }

      return false;
    } catch (e) {
      print('Error checking LRN uniqueness: $e');
      return false;
    }
  }

  // late String selectedRole;
  // late String selectedYear;
  // late String selectedProgram;

  @override
  void initState() {
    super.initState();

    // Initialize controllers first
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _studentIdController = TextEditingController();
    _lrnController = TextEditingController();
    _customScholarshipController = TextEditingController();

    final userData = widget.userDoc.data() as Map<String, dynamic>;

    final fullName = userData['name']?.toString().split(' ') ?? [''];

    // Now set the text values
    _firstNameController.text = fullName.isNotEmpty ? fullName.first : '';
    _lastNameController.text =
        fullName.length > 1 ? fullName.sublist(1).join(' ') : '';
    _emailController.text = userData['email'] ?? '';

    // Use the correct state variables (with underscore)
    _selectedRole = getDisplayRole(userData['role'] ?? 'user');
    _selectedYear = userData['year'] ?? 'N/A';
    _selectedProgram = userData['program'] ?? 'N/A';
    _selectedAffiliation = userData['affiliation'] ?? 'N/A';
    _selectedScholarship = userData['scholarship'] ?? 'N/A';
    _selectedServiceUnit = userData['serviceUnit'] ?? 'N/A';
    isActive = userData['isActive'] ?? true;

    // Initialize student-specific fields
    _studentIdController.text = userData['studentId'] ?? '';
    _lrnController.text = userData['lrn'] ?? '';

    _selectedStudentType = userData['studentType'] ?? 'N/A';
    _selectedGraduateType = userData['graduateType'] ?? 'N/A';
    _graduatedCollege = userData['graduatedCollege'] ?? 'N/A';
    _graduatedCollegeId = userData['graduatedCollegeId'] ?? '';
    _graduatedProgram = userData['graduatedProgram'] ?? 'N/A';
    _selectedCollege = userData['college'] ?? 'N/A';
    _selectedCollegeId = userData['collegeId'] ?? '';

    _fetchPrograms();
    _fetchScholarships();
  }

  Future<void> _fetchPrograms() async {
    try {
      // Load colleges
      final collegesSnapshot =
          await FirebaseFirestore.instance.collection('colleges').get();
      Map<String, String> collegesMap = {};
      for (var doc in collegesSnapshot.docs) {
        final name = doc.data()['name']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          collegesMap[name] = doc.id;
        }
      }

      final programsSnapshot =
          await FirebaseFirestore.instance.collection('programs').get();
      List<String> masteralPrograms = [];
      Map<String, List<String>> programsByCollege = {};

      for (var doc in programsSnapshot.docs) {
        final programName = doc.data()['name']?.toString().trim();
        final category = doc.data()['category']?.toString();
        final collegeId = doc.data()['collegeId']?.toString();

        if (programName == null || programName.isEmpty || category == null)
          continue;

        // Group masteral programs (no college needed)
        if (category == "Masteral") {
          // ✅ FIX: Prevent duplicate masteral programs
          if (!masteralPrograms.contains(programName)) {
            masteralPrograms.add(programName);
          }
        }

        // Group bachelor programs by college
        if (category == "Bachelor" &&
            collegeId != null &&
            collegeId.isNotEmpty) {
          final key = '${collegeId}_Bachelor';
          if (!programsByCollege.containsKey(key)) {
            programsByCollege[key] = [];
          }
          // ✅ FIX: Prevent duplicate bachelor programs
          if (!programsByCollege[key]!.contains(programName)) {
            programsByCollege[key]!.add(programName);
          }
        }
      }

      setState(() {
        _collegesMap = collegesMap;
        _masteralPrograms = masteralPrograms;
        _programsByCollege = programsByCollege;
        _programs.clear();
        _programs.add('N/A');
        isLoadingPrograms = false;
      });
    } catch (e) {
      setState(() => isLoadingPrograms = false);
      print('Error fetching programs: $e');
    }
  }

  Future<void> _fetchScholarships() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('scholarships')
              .orderBy('name')
              .get();

      // ✅ FIX: Remove duplicates from scholarships
      final scholarshipNames =
          snapshot.docs
              .map((doc) => doc['name'] as String)
              .where((name) => name.trim().isNotEmpty)
              .toSet() // Remove duplicates
              .toList();

      setState(() {
        _scholarships.clear();
        _scholarships.add('N/A');
        _scholarships.addAll(scholarshipNames);
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _studentIdController.dispose();
    _lrnController.dispose();
    _customScholarshipController.dispose();
    super.dispose();
  }

  String getDisplayRole(String role) =>
      role[0].toUpperCase() + role.substring(1);

  String getOriginalRole(String displayRole) => displayRole.toLowerCase();

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
              // Header
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

                      // Name Fields
                      if (isMobile) ...[
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

                      // ========== ACCOUNT INFORMATION SECTION ==========
                      buildSectionHeader(
                        'Account Information',
                        Icons.settings_outlined,
                      ),
                      const SizedBox(height: 16),

                      // Role Dropdown
                      _buildDropdownField(
                        label: 'Role',
                        value: _selectedRole,
                        items: displayRoles,
                        icon: Icons.badge_outlined,
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                            // Reset all conditional fields
                            _selectedAffiliation = 'N/A';
                            _selectedYear = 'N/A';
                            _selectedProgram = 'N/A';
                            _selectedScholarship = 'N/A';
                            _selectedServiceUnit = 'N/A';
                            _selectedCollege = 'N/A';
                            _selectedCollegeId = '';
                            _studentIdController.clear();
                            _lrnController.clear();
                            _customScholarship = '';
                            _customScholarshipController.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // ========== USER ROLE FIELDS ==========
                      if (shouldShowAffiliation) ...[
                        _buildDropdownField(
                          label: 'Affiliation',
                          value: _selectedAffiliation,
                          items: _affiliations,
                          icon: Icons.business_outlined,
                          isEnabled: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedAffiliation = value!;
                              // Reset all fields
                              _selectedStudentType = 'N/A';
                              _selectedGraduateType = 'N/A';
                              _selectedYear = 'N/A';
                              _selectedProgram = 'N/A';
                              _selectedScholarship = 'N/A';
                              _selectedCollege = 'N/A';
                              _selectedCollegeId = '';
                              _graduatedCollege = 'N/A';
                              _graduatedCollegeId = '';
                              _graduatedProgram = 'N/A';
                              _studentIdController.clear();
                              _lrnController.clear();
                              _customScholarship = '';
                              _customScholarshipController.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ========== CMU STUDENT FIELDS ==========
                      if (shouldShowStudentTypeSelection) ...[
                        _buildDropdownField(
                          label: 'Student Type',
                          value: _selectedStudentType,
                          items: ['N/A', 'undergraduate', 'graduate'],

                          icon: Icons.school_outlined,
                          isEnabled: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedStudentType = value!.toLowerCase();
                              // Reset dependent fields
                              _selectedGraduateType = 'N/A';
                              _selectedYear = 'N/A';
                              _selectedProgram = 'N/A';
                              _selectedScholarship = 'N/A';
                              _selectedCollege = 'N/A';
                              _selectedCollegeId = '';
                              _graduatedCollege = 'N/A';
                              _graduatedCollegeId = '';
                              _graduatedProgram = 'N/A';
                              _studentIdController.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ========== UNDERGRADUATE STUDENT FIELDS ==========
                      if (shouldShowUndergraduateFields) ...[
                        buildTextField(
                          controller: _studentIdController,
                          label: 'Student ID',
                          hint: 'Enter student ID...',
                          icon: Icons.badge_outlined,
                          isMobile: false,
                        ),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          label: 'Year Level',
                          value: _selectedYear,
                          items: years,
                          icon: Icons.school_outlined,
                          isEnabled: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value!;
                              _selectedProgram = 'N/A';
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          label: 'College',
                          value: _selectedCollege,
                          items: _colleges.keys.toList(),
                          icon: Icons.account_balance_outlined,
                          isEnabled: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedCollege = value!;
                              _selectedCollegeId = _colleges[value] ?? '';
                              _selectedProgram = 'N/A';
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _buildDropdownField(
                                label: 'Program',
                                value: _selectedProgram,
                                items: _undergraduatePrograms,
                                icon: Icons.class_outlined,
                                isEnabled:
                                    _selectedCollege != 'N/A' &&
                                    _selectedCollegeId.isNotEmpty,
                                onChanged:
                                    (value) => setState(
                                      () => _selectedProgram = value!,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          label: 'Scholarship',
                          value: _selectedScholarship,
                          items: _scholarships,
                          icon: Icons.school_outlined,
                          isEnabled: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedScholarship = value!;
                              if (value != 'Others') {
                                _customScholarship = '';
                                _customScholarshipController.clear();
                              }
                            });
                          },
                        ),

                        if (_selectedScholarship == 'Others') ...[
                          const SizedBox(height: 16),
                          buildTextField(
                            controller: _customScholarshipController,
                            label: 'Custom Scholarship Name',
                            hint: 'Enter scholarship name...',
                            icon: Icons.edit_outlined,
                            isMobile: false,
                            onChanged: (value) {
                              setState(() {
                                _customScholarship = value.trim();
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],

                      // ========== GRADUATE STUDENT TYPE SELECTION ==========
                      if (shouldShowGraduateTypeSelection) ...[
                        _buildDropdownField(
                          label: 'Graduate Type',
                          value: _selectedGraduateType,
                          items: ['N/A', 'masteral', 'not_masteral'],

                          icon: Icons.school_outlined,
                          isEnabled: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedGraduateType = value!
                                  .toLowerCase()
                                  .replaceAll(' ', '_');
                              // Reset dependent fields
                              _selectedProgram = 'N/A';
                              _selectedCollege = 'N/A';
                              _selectedCollegeId = '';
                              _graduatedCollege = 'N/A';
                              _graduatedCollegeId = '';
                              _graduatedProgram = 'N/A';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ========== MASTERAL GRADUATE FIELDS ==========
                      if (shouldShowMasteralGraduateFields) ...[
                        _buildDropdownField(
                          label: 'Masteral Program',
                          value: _selectedProgram,
                          items: _masteralProgramsList,
                          icon: Icons.class_outlined,
                          isEnabled: true,
                          onChanged:
                              (value) =>
                                  setState(() => _selectedProgram = value!),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ========== NOT MASTERAL GRADUATE FIELDS ==========
                      if (shouldShowNotMasteralGraduateFields) ...[
                        _buildDropdownField(
                          label: 'Graduated College',
                          value: _graduatedCollege,
                          items: _colleges.keys.toList(),
                          icon: Icons.account_balance_outlined,
                          isEnabled: true,
                          onChanged: (value) {
                            setState(() {
                              _graduatedCollege = value!;
                              _graduatedCollegeId = _colleges[value] ?? '';
                              _graduatedProgram = 'N/A';
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          label: 'Graduated Program (Bachelor)',
                          value: _graduatedProgram,
                          items:
                              _graduatedCollege != 'N/A' &&
                                      _graduatedCollegeId.isNotEmpty
                                  ? [
                                    'N/A',
                                    ...(_programsByCollege['${_graduatedCollegeId}_Bachelor'] ??
                                        []),
                                  ]
                                  : ['N/A'],
                          icon: Icons.class_outlined,
                          isEnabled:
                              _graduatedCollege != 'N/A' &&
                              _graduatedCollegeId.isNotEmpty,
                          onChanged:
                              (value) =>
                                  setState(() => _graduatedProgram = value!),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // ========== INCOMING FRESHMAN APPLICANT FIELDS ==========
                      if (shouldShowLRNField) ...[
                        buildTextField(
                          controller: _lrnController,
                          label: 'LRN (Learner Reference Number)',
                          hint: 'Enter LRN...',
                          icon: Icons.numbers_outlined,
                          isMobile: false,
                        ),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          label: 'Scholarship',
                          value: _selectedScholarship,
                          items: _scholarships,
                          icon: Icons.school_outlined,
                          isEnabled: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedScholarship = value!;
                              if (value != 'Others') {
                                _customScholarship = '';
                                _customScholarshipController.clear();
                              }
                            });
                          },
                        ),

                        if (_selectedScholarship == 'Others') ...[
                          const SizedBox(height: 16),
                          buildTextField(
                            controller: _customScholarshipController,
                            label: 'Custom Scholarship Name',
                            hint: 'Enter scholarship name...',
                            icon: Icons.edit_outlined,
                            isMobile: false,
                            onChanged: (value) {
                              setState(() {
                                _customScholarship = value.trim();
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],

                      // ========== MASTERAL (NOT CMU GRADUATE) FIELDS ==========
                      if (shouldShowMasteralNotCMUFields) ...[
                        _buildDropdownField(
                          label: 'Masteral Program',
                          value: _selectedProgram,
                          items: _masteralProgramsList,
                          icon: Icons.class_outlined,
                          isEnabled: true,
                          onChanged:
                              (value) =>
                                  setState(() => _selectedProgram = value!),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // STAFF ROLE FIELDS
                      if (shouldShowServiceUnit) ...[
                        _buildDropdownField(
                          label: 'Service Unit',
                          value: _selectedServiceUnit,
                          items: _serviceUnits,
                          icon: Icons.work_outline,
                          isEnabled: true,
                          onChanged:
                              (value) =>
                                  setState(() => _selectedServiceUnit = value!),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 8),

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

                      buildTextField(
                        controller: _passwordController,
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
                        controller: _confirmPasswordController,
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

              // Fixed Action Buttons
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

  Future<bool> _isEmailUnique(String email, {String? excludeUserId}) async {
    try {
      final query =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email.trim().toLowerCase())
              .get();

      if (query.docs.isEmpty) return true;

      if (excludeUserId != null) {
        return query.docs.every((doc) => doc.id == excludeUserId);
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Updated _saveChanges method with comprehensive validation
  Future<void> _saveChanges() async {
    if (_firstNameController.text.trim().isEmpty) {
      SnackbarUtil.showWarning(context, 'Please enter first name');
      return;
    }

    if (_lastNameController.text.trim().isEmpty) {
      SnackbarUtil.showWarning(context, 'Please enter last name');
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      SnackbarUtil.showWarning(context, 'Please enter email address');
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      SnackbarUtil.showWarning(context, 'Please enter a valid email address');
      return;
    }

    // CHECK EMAIL UNIQUENESS (excluding current user)

    final userData = widget.userDoc.data() as Map<String, dynamic>;
    final originalEmail = userData['email'] ?? '';
    final newEmail = _emailController.text.trim();

    if (newEmail != originalEmail) {
      final isEmailUnique = await _isEmailUnique(
        newEmail,
        excludeUserId: widget.userDoc.id,
      );
      if (!isEmailUnique) {
        SnackbarUtil.showWarning(context, 'This email is already registered');
        return;
      }
    }

    // Validate password if entered
    if (_passwordController.text.isNotEmpty) {
      if (_passwordController.text.length < 6) {
        SnackbarUtil.showWarning(
          context,
          'Password must be at least 6 characters',
        );
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        SnackbarUtil.showWarning(context, 'Passwords do not match');
        return;
      }
    }

    // Role-specific validations
    if (_selectedRole.toLowerCase() == 'user') {
      if (_selectedAffiliation == null || _selectedAffiliation == 'N/A') {
        SnackbarUtil.showWarning(context, 'Please select an affiliation');
        return;
      }

      if (_selectedAffiliation.toLowerCase() == 'cmu student') {
        if (_selectedStudentType == 'N/A') {
          SnackbarUtil.showWarning(context, 'Please select student type');
          return;
        }

        if (_selectedStudentType == 'undergraduate') {
          if (_studentIdController.text.trim().isEmpty ||
              _studentIdController.text.trim() == 'N/A') {
            SnackbarUtil.showWarning(context, 'Please enter student ID');
            return;
          }

          final isStudentIdUnique = await _isStudentIdUnique(
            _studentIdController.text.trim(),
            excludeUserId: widget.userDoc.id,
          );
          if (!isStudentIdUnique) {
            SnackbarUtil.showWarning(
              context,
              'This Student ID is already registered',
            );
            return;
          }

          if (_selectedYear == null || _selectedYear == 'N/A') {
            SnackbarUtil.showWarning(context, 'Please select year level');
            return;
          }

          if (_selectedCollege == null || _selectedCollege == 'N/A') {
            SnackbarUtil.showWarning(context, 'Please select a college');
            return;
          }

          if (_selectedProgram == null || _selectedProgram == 'N/A') {
            SnackbarUtil.showWarning(context, 'Please select a program');
            return;
          }

   
        }

        if (_selectedStudentType == 'graduate') {
          if (_selectedGraduateType == null || _selectedGraduateType == 'N/A') {
            SnackbarUtil.showWarning(context, 'Please select graduate type');
            return;
          }

          if (_selectedGraduateType == 'masteral') {
            if (_selectedProgram == null || _selectedProgram == 'N/A') {
              SnackbarUtil.showWarning(
                context,
                'Please select a masteral program',
              );
              return;
            }
          } else if (_selectedGraduateType == 'not_masteral') {
            if (_graduatedCollege == null || _graduatedCollege == 'N/A') {
              SnackbarUtil.showWarning(
                context,
                'Please select graduated college',
              );
              return;
            }
            if (_graduatedProgram == null || _graduatedProgram == 'N/A') {
              SnackbarUtil.showWarning(
                context,
                'Please select graduated program',
              );
              return;
            }
          }
        }
      }

      if (_selectedAffiliation.toLowerCase() == 'incoming freshman applicant') {
        if (_lrnController.text.trim().isEmpty) {
          SnackbarUtil.showWarning(context, 'Please enter LRN');
          return;
        }

        final isLrnUnique = await _isLRNUnique(
          _lrnController.text.trim(),
          excludeUserId: widget.userDoc.id,
        );
        if (!isLrnUnique) {
          SnackbarUtil.showWarning(context, 'This LRN is already registered');
          return;
        }

   

        if (_selectedScholarship == 'Others' &&
            _customScholarship.trim().isEmpty) {
          SnackbarUtil.showWarning(context, 'Please specify scholarship name');
          return;
        }
      }

      if (_selectedAffiliation.toLowerCase() == 'masteral (not cmu graduate)') {
        if (_selectedProgram == null || _selectedProgram == 'N/A') {
          SnackbarUtil.showWarning(context, 'Please select a masteral program');
          return;
        }
      }
    }

    if (_selectedRole.toLowerCase() == 'staff') {
      if (_selectedServiceUnit == null || _selectedServiceUnit == 'N/A') {
        SnackbarUtil.showWarning(context, 'Please select a service unit');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final newDisplayName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

      // Update email and/or password in Firebase Authentication if changed
      if (newEmail != originalEmail || _passwordController.text.isNotEmpty) {
        try {
          final functionsService = FirebaseFunctionsService();
          await functionsService.updateUserAuth(
            uid: widget.userDoc.id,
            email: newEmail != originalEmail ? newEmail : null,
            displayName: newDisplayName,
            password:
                _passwordController.text.isNotEmpty
                    ? _passwordController.text.trim()
                    : null,
          );
        } catch (e) {
          setState(() {
            _isSubmitting = false;
          });
          SnackbarUtil.showError(
            context,
            'Failed to update authentication: ${e.toString()}',
          );
          return;
        }
      }

      Map<String, dynamic> updateData = {
        'name': newDisplayName,
        'email': newEmail,
        'role': _selectedRole.toLowerCase(),
        'isActive': isActive,
        'updatedAt': Timestamp.now(),
      };

      // Add role-specific fields
      if (_selectedRole.toLowerCase() == 'user') {
        updateData['affiliation'] = _selectedAffiliation;
        updateData['isEnrolled'] =
            _selectedAffiliation.toLowerCase() == 'cmu student';

        if (_selectedAffiliation.toLowerCase() == 'cmu student') {
          updateData['studentType'] = _selectedStudentType;

          if (_selectedStudentType == 'undergraduate') {
            updateData['studentId'] = _studentIdController.text.trim();
            updateData['year'] = _selectedYear;
            updateData['college'] = _selectedCollege;
            updateData['collegeId'] = _selectedCollegeId;
            updateData['program'] = _selectedProgram;
            updateData['scholarship'] =
                _selectedScholarship == 'Others'
                    ? _customScholarship
                    : (_selectedScholarship != 'N/A'
                        ? _selectedScholarship
                        : null);
            updateData['graduateType'] = null;
            updateData['graduatedCollege'] = null;
            updateData['graduatedCollegeId'] = null;
            updateData['graduatedProgram'] = null;
            updateData['lrn'] = null;
          } else if (_selectedStudentType == 'graduate') {
            updateData['graduateType'] = _selectedGraduateType;
            updateData['studentId'] = null;

            if (_selectedGraduateType == 'masteral') {
              updateData['program'] = _selectedProgram;
              updateData['year'] = 'Graduate';
              updateData['scholarship'] = null;
              updateData['college'] = null;
              updateData['collegeId'] = null;
              updateData['graduatedCollege'] = null;
              updateData['graduatedCollegeId'] = null;
              updateData['graduatedProgram'] = null;
            } else {
              updateData['graduatedCollege'] = _graduatedCollege;
              updateData['graduatedCollegeId'] = _graduatedCollegeId;
              updateData['graduatedProgram'] = _graduatedProgram;
              updateData['college'] = null;
              updateData['collegeId'] = null;
              updateData['program'] = null;
              updateData['year'] = null;
              updateData['scholarship'] = null;
            }
            updateData['lrn'] = null;
          }
        } else if (_selectedAffiliation.toLowerCase() ==
            'incoming freshman applicant') {
          updateData['lrn'] = _lrnController.text.trim();
          updateData['scholarship'] =
              _selectedScholarship == 'Others'
                  ? _customScholarship
                  : (_selectedScholarship != 'N/A'
                      ? _selectedScholarship
                      : null);
          updateData['studentId'] = null;
          updateData['year'] = null;
          updateData['college'] = null;
          updateData['collegeId'] = null;
          updateData['program'] = null;
          updateData['studentType'] = null;
          updateData['graduateType'] = null;
          updateData['graduatedCollege'] = null;
          updateData['graduatedCollegeId'] = null;
          updateData['graduatedProgram'] = null;
        } else if (_selectedAffiliation.toLowerCase() ==
            'masteral (not cmu graduate)') {
          updateData['program'] = _selectedProgram;
          updateData['lrn'] = null;
          updateData['scholarship'] = null;
          updateData['year'] = null;
          updateData['college'] = null;
          updateData['collegeId'] = null;
          updateData['studentId'] = null;
          updateData['studentType'] = null;
          updateData['graduateType'] = null;
          updateData['graduatedCollege'] = null;
          updateData['graduatedCollegeId'] = null;
          updateData['graduatedProgram'] = null;
        } else {
          updateData['lrn'] = null;
          updateData['scholarship'] = null;
          updateData['year'] = null;
          updateData['college'] = null;
          updateData['collegeId'] = null;
          updateData['program'] = null;
          updateData['studentId'] = null;
          updateData['studentType'] = null;
          updateData['graduateType'] = null;
          updateData['graduatedCollege'] = null;
          updateData['graduatedCollegeId'] = null;
          updateData['graduatedProgram'] = null;
        }
      } else if (_selectedRole.toLowerCase() == 'staff') {
        updateData['serviceUnit'] = _selectedServiceUnit;
        updateData['affiliation'] = FieldValue.delete();
        updateData['studentId'] = FieldValue.delete();
        updateData['year'] = FieldValue.delete();
        updateData['program'] = FieldValue.delete();
        updateData['scholarship'] = FieldValue.delete();
        updateData['lrn'] = FieldValue.delete();
      } else if (_selectedRole.toLowerCase() == 'admin') {
        updateData['affiliation'] = FieldValue.delete();
        updateData['studentId'] = FieldValue.delete();
        updateData['year'] = FieldValue.delete();
        updateData['program'] = FieldValue.delete();
        updateData['scholarship'] = FieldValue.delete();
        updateData['lrn'] = FieldValue.delete();
        updateData['serviceUnit'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userDoc.id)
          .update(updateData);

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

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        SnackbarUtil.showSuccess(context, 'User updated successfully');

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        SnackbarUtil.showError(context, 'Failed to update: ${e.toString()}');
      }
    }
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    bool isEnabled = true,
    bool showError = false,
    String? errorText,
  }) {
    // ✅ FIX: Remove duplicates and ensure unique items
    final uniqueItems = items.toSet().toList();

    // ✅ FIX: Ensure value exists in items, otherwise set to null
    final safeValue = uniqueItems.contains(value) ? value : null;

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
            border: Border.all(
              color: showError ? Colors.red : const Color(0xFFE5E7EB),
              width: showError ? 2 : 1.5,
            ),
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
              value: safeValue, // ✅ CHANGED: Use safeValue instead of value
              onChanged: isEnabled ? onChanged : null,
              isExpanded: true,
              alignment: Alignment.centerLeft,
              menuMaxHeight: 250,
              items:
                  uniqueItems.map((String item) {
                    // ✅ CHANGED: Use uniqueItems instead of items
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item == 'N/A'
                            ? 'N/A'
                            : item
                                .replaceAll('_', ' ')
                                .split(' ')
                                .map(
                                  (w) =>
                                      w.isNotEmpty
                                          ? w[0].toUpperCase() + w.substring(1)
                                          : '',
                                )
                                .join(' '),
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
        if (showError && errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              errorText,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
      ],
    );
  }
}
