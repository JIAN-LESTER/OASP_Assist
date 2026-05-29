import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/modal_pages/modal_widget/textfield.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:capstone_project/services/admin_functions.dart';
import 'package:capstone_project/utils/snackbar_util.dart';

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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Material(
        color: Colors.transparent,
        child: Container(
          //  UPDATED DIMENSIONS TO MATCH EDIT MODAL
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

  String _selectedStudentType = 'N/A'; // 'undergraduate' or 'graduate'
  String _selectedGraduateType = 'N/A'; // 'masteral' or 'not_masteral'
  String _graduatedCollege = 'N/A';
  String _graduatedCollegeId = '';
  String _graduatedProgram = 'N/A';
  String _selectedCollege = 'N/A';
  String _selectedCollegeId = '';
  Map<String, String> _collegesMap = {};
  Map<String, List<String>> _programsByCollege = {};
  List<String> _masteralPrograms = [];

  String _customScholarship = '';

  final _customScholarshipController = TextEditingController();
  final _customAffiliationController = TextEditingController();

  // ADD this state variable:
  String _customAffiliation = '';

  final List<String> _programs = ['N/A'];
  final List<String> _affiliations = [
    'N/A',
    'CMU Student',
    'Incoming Freshman Applicant',
    'Parent',
    'Faculty',
    'CMU Staff',
    'Alumni',
    'Visitor',
    'Masteral (Not CMU Graduate)',
    'Others', // Add this for custom affiliation input
  ];

  final List<String> _scholarships = ['N/A'];
  bool isLoadingPrograms = true;
  bool isLoadingAffiliations = true;
  bool isLoadingScholarships = true;

  final _studentIdController = TextEditingController();
  final _lrnController = TextEditingController();

  // Add these new state variables
  String _selectedServiceUnit = 'N/A';
  final List<String> _serviceUnits = [
    'N/A',
    'Admission',
    'Scholarship',
    'Placement',
  ];

  final roles = ['admin', 'user', 'staff'];
  List<String> get displayRoles =>
      roles.map((role) => role[0].toUpperCase() + role.substring(1)).toList();

  final years = ['N/A', '1st Year', '2nd Year', '3rd Year', '4th Year'];

  @override
  void initState() {
    super.initState();
    _fetchPrograms();

    _fetchScholarships();
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _affiliationController.dispose();
    _scholarshipController.dispose();
    _studentIdController.dispose();
    _lrnController.dispose();
    _customAffiliationController.dispose();
    super.dispose();
  }

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

  // UPDATE the shouldShowMasteralNotCMUFields getter:
  bool get shouldShowMasteralNotCMUFields {
    return _selectedRole.toLowerCase() == 'user' &&
        _selectedAffiliation.toLowerCase() == 'masteral (not cmu graduate)';
  }

  // ADD a new getter for showing "Others" fields:
  bool get shouldShowOthersFields {
    return _selectedRole.toLowerCase() == 'user' &&
        _selectedAffiliation == 'Others';
  }

  bool get shouldShowServiceUnit {
    return _selectedRole.toLowerCase() == 'staff';
  }

  Map<String, String> get _colleges {
    Map<String, String> collegesWithNA = {'N/A': ''};
    collegesWithNA.addAll(_collegesMap);
    return collegesWithNA;
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
          masteralPrograms.add(programName);
        }

        // Group bachelor programs by college
        if (category == "Bachelor" &&
            collegeId != null &&
            collegeId.isNotEmpty) {
          final key = '${collegeId}_Bachelor';
          if (!programsByCollege.containsKey(key)) {
            programsByCollege[key] = [];
          }
          programsByCollege[key]!.add(programName);
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

  // REPLACE the entire _saveUser() method with this fixed version:

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Basic field validations
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      SnackbarUtil.showWarning(
        context,
        'Please enter both first and last name',
      );
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

    // CHECK EMAIL UNIQUENESS
    final isEmailUnique = await _isEmailUnique(_emailController.text.trim());
    if (!isEmailUnique) {
      SnackbarUtil.showWarning(context, 'This email is already registered');
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      SnackbarUtil.showWarning(context, 'Please enter password');
      return;
    }

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

    // Role-specific validations
    if (_selectedRole.toLowerCase() == 'user') {
      if (_selectedAffiliation == 'N/A') {
        SnackbarUtil.showWarning(context, 'Please select an affiliation');
        return;
      }

      if (_selectedAffiliation.toLowerCase() == 'cmu student') {
        if (_selectedStudentType == 'N/A') {
          SnackbarUtil.showWarning(context, 'Please select student type');
          return;
        }

        if (_selectedStudentType == 'undergraduate') {
          if (_studentIdController.text.trim().isEmpty) {
            SnackbarUtil.showWarning(context, 'Please enter student ID');
            return;
          }

          final isStudentIdUnique = await _isStudentIdUnique(
            _studentIdController.text.trim(),
          );
          if (!isStudentIdUnique) {
            SnackbarUtil.showWarning(
              context,
              'This Student ID is already registered',
            );
            return;
          }

          if (_selectedYear == 'N/A') {
            SnackbarUtil.showWarning(context, 'Please select year level');
            return;
          }

          if (_selectedCollege == 'N/A') {
            SnackbarUtil.showWarning(context, 'Please select a college');
            return;
          }

          if (_selectedProgram == 'N/A') {
            SnackbarUtil.showWarning(context, 'Please select a program');
            return;
          }
        }

        if (_selectedStudentType == 'graduate') {
          if (_selectedGraduateType == 'N/A') {
            SnackbarUtil.showWarning(context, 'Please select graduate type');
            return;
          }

          if (_selectedGraduateType == 'masteral') {
            if (_selectedProgram == 'N/A') {
              SnackbarUtil.showWarning(
                context,
                'Please select a masteral program',
              );
              return;
            }
          } else if (_selectedGraduateType == 'not_masteral') {
            if (_graduatedCollege == 'N/A') {
              SnackbarUtil.showWarning(
                context,
                'Please select graduated college',
              );
              return;
            }
            if (_graduatedProgram == 'N/A') {
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

        if (_selectedAffiliation == 'Others') {
          if (_customAffiliation.trim().isEmpty) {
            SnackbarUtil.showWarning(
              context,
              'Please specify your affiliation',
            );
            return;
          }
        }

        final isLrnUnique = await _isLRNUnique(_lrnController.text.trim());
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
        if (_selectedProgram == 'N/A') {
          SnackbarUtil.showWarning(context, 'Please select a masteral program');
          return;
        }
      }
    }

    if (_selectedRole.toLowerCase() == 'staff') {
      if (_selectedServiceUnit == 'N/A') {
        SnackbarUtil.showWarning(context, 'Please select a service unit');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final functionsService = FirebaseFunctionsService();
      String uid;

      //  FIX: Don't include timestamps in userData - Cloud Function handles them
      Map<String, dynamic> userData = {
        'name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'role': _selectedRole.toLowerCase().trim(),
        'isActive': true,
        'profileCompleted': true,
        'onboardingCompleted': true,
        'isVerified': true,
        'emailVerified': true,
      };

      // Add role-specific fields to userData BEFORE calling Cloud Function
      if (_selectedRole.toLowerCase() == 'user') {
        userData['affiliation'] = _selectedAffiliation;
        userData['isEnrolled'] =
            _selectedAffiliation.toLowerCase() == 'cmu student';

        if (_selectedAffiliation.toLowerCase() == 'cmu student') {
          userData['studentType'] = _selectedStudentType;

          if (_selectedStudentType == 'undergraduate') {
            userData['studentId'] = _studentIdController.text.trim();
            userData['year'] = _selectedYear;
            userData['college'] = _selectedCollege;
            userData['collegeId'] = _selectedCollegeId;
            userData['program'] = _selectedProgram;
            userData['scholarship'] =
                _selectedScholarship == 'Others'
                    ? _customScholarship
                    : (_selectedScholarship != 'N/A'
                        ? _selectedScholarship
                        : null);
            userData['graduateType'] = null;
            userData['graduatedCollege'] = null;
            userData['graduatedCollegeId'] = null;
            userData['graduatedProgram'] = null;
            userData['lrn'] = null;
          } else if (_selectedStudentType == 'graduate') {
            userData['graduateType'] = _selectedGraduateType;
            userData['studentId'] = null;

            if (_selectedGraduateType == 'masteral') {
              userData['program'] = _selectedProgram;
              userData['year'] = 'Graduate';
              userData['scholarship'] = null;
              userData['college'] = null;
              userData['collegeId'] = null;
              userData['graduatedCollege'] = null;
              userData['graduatedCollegeId'] = null;
              userData['graduatedProgram'] = null;
            } else {
              userData['graduatedCollege'] = _graduatedCollege;
              userData['graduatedCollegeId'] = _graduatedCollegeId;
              userData['graduatedProgram'] = _graduatedProgram;
              userData['college'] = null;
              userData['collegeId'] = null;
              userData['program'] = null;
              userData['year'] = null;
              userData['scholarship'] = null;
            }
            userData['lrn'] = null;
          }
        } else if (_selectedAffiliation.toLowerCase() ==
            'incoming freshman applicant') {
          userData['lrn'] = _lrnController.text.trim();
          userData['scholarship'] =
              _selectedScholarship == 'Others'
                  ? _customScholarship
                  : (_selectedScholarship != 'N/A'
                      ? _selectedScholarship
                      : null);
          userData['studentId'] = null;
          userData['year'] = null;
          userData['college'] = null;
          userData['collegeId'] = null;
          userData['program'] = null;
          userData['studentType'] = null;
          userData['graduateType'] = null;
          userData['graduatedCollege'] = null;
          userData['graduatedCollegeId'] = null;
          userData['graduatedProgram'] = null;
        } else if (_selectedAffiliation.toLowerCase() ==
            'masteral (not cmu graduate)') {
          userData['program'] = _selectedProgram;
          userData['lrn'] = null;
          userData['scholarship'] = null;
          userData['year'] = null;
          userData['college'] = null;
          userData['collegeId'] = null;
          userData['studentId'] = null;
          userData['studentType'] = null;
          userData['graduateType'] = null;
          userData['graduatedCollege'] = null;
          userData['graduatedCollegeId'] = null;
          userData['graduatedProgram'] = null;
        } else if (_selectedAffiliation == 'Others') {
          userData['customAffiliation'] = _customAffiliation;
          userData['lrn'] = null;
          userData['scholarship'] = null;
          userData['year'] = null;
          userData['college'] = null;
          userData['collegeId'] = null;
          userData['program'] = null;
          userData['studentId'] = null;
          userData['studentType'] = null;
          userData['graduateType'] = null;
          userData['graduatedCollege'] = null;
          userData['graduatedCollegeId'] = null;
          userData['graduatedProgram'] = null;
        } else {
          // For Parent, Faculty, CMU Staff, Alumni, Visitor
          userData['lrn'] = null;
          userData['scholarship'] = null;
          userData['year'] = null;
          userData['college'] = null;
          userData['collegeId'] = null;
          userData['program'] = null;
          userData['studentId'] = null;
          userData['studentType'] = null;
          userData['graduateType'] = null;
          userData['graduatedCollege'] = null;
          userData['graduatedCollegeId'] = null;
          userData['graduatedProgram'] = null;
          userData['customAffiliation'] = null;
        }
      } else if (_selectedRole.toLowerCase() == 'staff') {
        userData['serviceUnit'] = _selectedServiceUnit;
      }

      //  Call Cloud Function with complete userData
      try {
        uid = await functionsService.createUserAuth(
          email: email,
          password: password,
          displayName: fullName,
          userData: userData,
        );
      } catch (e) {
        SnackbarUtil.showError(
          context,
          'Failed to create user account: ${e.toString()}',
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      //  The Cloud Function already created the Firestore document
      // No need to create it again here

      await _logCreateAction(fullName);

      SnackbarUtil.showSuccess(context, 'User created successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      SnackbarUtil.showError(context, 'Failed to create user: $e');
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
    } catch (e) {
      // Silent log failure
    }
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

          // Scrollable Content
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

                            // Reset custom affiliation if not "Others"
                            if (value != 'Others') {
                              _customAffiliation = '';
                              _customAffiliationController.clear();
                            }
                          });
                        },
                      ),

                      // ADD this right after the Affiliation dropdown (before the SizedBox(height: 16)):
                      if (_selectedAffiliation == 'Others') ...[
                        const SizedBox(height: 16),
                        buildTextField(
                          controller: _customAffiliationController,
                          label: 'Custom Affiliation',
                          hint: 'Enter your affiliation...',
                          icon: Icons.edit_outlined,
                          isMobile: false,
                          onChanged: (value) {
                            setState(() {
                              _customAffiliation = value.trim();
                            });
                          },
                        ),
                      ],

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
                                  (value) =>
                                      setState(() => _selectedProgram = value!),
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

                    // ========== NOT MASTERAL GRADUATE FIELDS (WITH COLLEGE) ==========
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

                    // ========== STAFF ROLE FIELDS ==========
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

                    // ========== PASSWORD SECTION ==========
                    buildSectionHeader('Password', Icons.lock_outlined),
                    const SizedBox(height: 16),

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
                  ],
                ),
              ),
            ),
          ),

          // Fixed Action Buttons at Bottom
          Container(
            padding: EdgeInsets.all(widget.isMobile ? 20 : 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: _buildActionButtons(),
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
                        item == 'n/a'
                            ? 'N/A'
                            : item
                                .replaceAll('_', ' ')
                                .split(' ')
                                .map((w) => w[0].toUpperCase() + w.substring(1))
                                .join(' '), // Capitalize each word
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
