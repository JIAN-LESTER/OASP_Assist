import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capstone_project/profile.dart';
import 'package:capstone_project/utils/snackbar_util.dart';

void showEditProfileModal(
  BuildContext context, {
  bool isRequired = false,
  VoidCallback? onComplete,
  bool showBackButton = false,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: !isRequired,
    barrierLabel: 'Edit Profile',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return EditProfileModal(
        isRequired: isRequired,
        onComplete: onComplete,
        showBackButton: showBackButton,
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

class EditProfileModal extends StatefulWidget {
  final bool isRequired;
  final VoidCallback? onComplete;
  final bool showBackButton;

  const EditProfileModal({
    super.key,
    this.isRequired = false,
    this.onComplete,
    this.showBackButton = false,
  });

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _isCMUStudent; // 'yes' or 'no'
  String? _associationType;
  String? _role;
  String? _enrollmentStatus;
  String? _selectedYear;
  String? _selectedProgram;
  bool _hasAffiliation = false;
  bool _hasScholarship = false;
  String? _selectedAffiliation;
  String? _selectedScholarship;

  bool _isLoading = false;
  bool _isSaving = false;

  List<String> _programs = [];

  final List<String> _affiliations = [
    'CMU Student',
    'Incoming Freshman Applicant',
    'Masteral',
    'Parent',
    'Faculty',
    'CMU Staff',
    'Alumni',
    'Others',
  ];
  List<String> _scholarships = [];

  final List<String> _years = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
  ];

  String? _studentId;
  String? _lrn;
  String? _studentType; // 'undergraduate' or 'graduate'
  String? _graduateType; // 'masteral' or 'not_masteral'
  String? _graduatedCollege;
  String? _graduatedProgram;
  String? _isIncomingFreshman; // for LRN validation
  List<String> _colleges = [];
  Map<String, String> _collegesMap = {}; // college name → college ID
  Map<String, List<String>> _programsByCollege = {};

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  String? _selectedCollege;
  String? _selectedCollegeId;
  String? _graduatedCollegeId;
  String? _customAffiliation;
  bool _customAffiliationConfirmed = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
    _loadUserRole();
    _loadDropdownData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final fullName = data['name'] ?? '';
          final nameParts = fullName.trim().split(' ');

          setState(() {
            _firstNameController.text =
                data['firstName'] ?? (nameParts.isNotEmpty ? nameParts[0] : '');
            _lastNameController.text =
                data['lastName'] ??
                (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
            _nameController.text = fullName;
            _emailController.text = data['email'] ?? '';
            _selectedYear = data['year'];
            _selectedProgram = data['program'];
            _selectedAffiliation = data['affiliation'];
            _selectedScholarship = data['scholarship'];
            _selectedCollege = data['college'];
            _selectedCollegeId = data['collegeId'];
            _graduatedCollegeId = data['graduatedCollegeId'];

            _studentId = data['studentId'];
            _lrn = data['lrn'];
            _studentType = data['studentType'];
            _graduateType = data['graduateType'];
            _graduatedCollege = data['graduatedCollege'];
            _graduatedCollegeId = data['graduatedCollegeId'];
            _graduatedProgram = data['graduatedProgram'];

            // Determine CMU student status and association type
            if (_selectedAffiliation?.toLowerCase() == 'cmu student') {
              _isCMUStudent = 'yes';
              _enrollmentStatus = 'enrolled';
            } else if (_selectedAffiliation?.toLowerCase() ==
                'incoming freshman applicant') {
              _isCMUStudent = 'no';
              _associationType = 'incoming_freshman';
            } else if (_selectedAffiliation?.toLowerCase() ==
                'masteral (not cmu graduate)') {
              _isCMUStudent = 'no';
              _associationType = 'masteral';
            } else if (_selectedAffiliation != null &&
                _selectedAffiliation!.isNotEmpty) {
              _isCMUStudent = 'no';
              _associationType = 'others';
              _customAffiliation = _selectedAffiliation;
            }

            _hasScholarship =
                data['scholarship'] != null &&
                data['scholarship'].toString().isNotEmpty;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDropdownData() async {
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

      // Load programs by college with category
      final programsSnapshot =
          await FirebaseFirestore.instance.collection('programs').get();
      Map<String, List<String>> programsByCollegeMap = {};
      List<String> masteralProgramsList =
          []; // For masteral programs without college

      for (var doc in programsSnapshot.docs) {
        final programName = doc.data()['name']?.toString().trim();
        final collegeId = doc.data()['collegeId']?.toString();
        final category = doc.data()['category']?.toString();

        if (programName == null || programName.isEmpty || category == null)
          continue;

        // Masteral programs (no college association)
        if (category == "Masteral") {
          masteralProgramsList.add(programName);
        }

        // Bachelor programs by college
        if (category == "Bachelor" &&
            collegeId != null &&
            collegeId.isNotEmpty) {
          final key = '${collegeId}_Bachelor';
          if (!programsByCollegeMap.containsKey(key)) {
            programsByCollegeMap[key] = [];
          }
          programsByCollegeMap[key]!.add(programName);
        }
      }

      //  ADD MASTERAL PROGRAMS TO THE MAP
      if (masteralProgramsList.isNotEmpty) {
        programsByCollegeMap['Masteral'] = masteralProgramsList;
      }

      // Load affiliations and scholarships
      final futures = await Future.wait([
        _getDropdownItems('affiliations'),
        _getDropdownItems('scholarships'),
      ]);

      setState(() {
        _collegesMap = collegesMap;
        _colleges = collegesMap.keys.toList();
        _programsByCollege = programsByCollegeMap;
        _scholarships = [...futures[1].toSet(), 'Others'];
      });
    } catch (e) {
      print('Error loading dropdown data: $e');
    }
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

  Future<List<String>> _getDropdownItems(String collection) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection(collection).get();

      //  Filter out empty/null values and remove duplicates
      return snapshot.docs
          .map((doc) {
            final name = doc.data()['name'];
            return name?.toString().trim() ?? '';
          })
          .where((name) => name.isNotEmpty)
          .toSet() //  Convert to Set to remove duplicates
          .toList();
    } catch (e) {
      print('Error getting dropdown items from $collection: $e');
      return [];
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == 'user') {
      // Validate CMU student selection
      if (_isCMUStudent == null) {
        SnackbarUtil.showError(
          context,
          'Please indicate if you are/were a CMU student',
        );
        return;
      }

      // CMU Student validations
      if (_isCMUStudent == 'yes') {
        if (_studentType == null) {
          SnackbarUtil.showError(context, 'Please select your student type');
          return;
        }

        if (_studentType == 'undergraduate') {
          if (_studentId == null || _studentId!.trim().isEmpty) {
            SnackbarUtil.showError(context, 'Please enter your Student ID');
            return;
          }

          //  CHECK STUDENT ID UNIQUENESS (excluding current user)
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final isStudentIdUnique = await _isStudentIdUnique(
              _studentId!.trim(),
              excludeUserId: user.uid,
            );
            if (!isStudentIdUnique) {
              SnackbarUtil.showError(
                context,
                'This Student ID is already registered',
              );
              return;
            }
          }

          if (_selectedYear == null) {
            SnackbarUtil.showError(context, 'Please select your year level');
            return;
          }
          if (_selectedCollege == null) {
            SnackbarUtil.showError(context, 'Please select your college');
            return;
          }
          if (_selectedProgram == null) {
            SnackbarUtil.showError(context, 'Please select your program');
            return;
          }
        } else if (_studentType == 'graduate') {
          if (_graduateType == null) {
            SnackbarUtil.showError(context, 'Please select your graduate type');
            return;
          }
          if (_graduateType == 'masteral' && _selectedProgram == null) {
            SnackbarUtil.showError(
              context,
              'Please select your masteral program',
            );
            return;
          }
          if (_graduateType == 'not_masteral') {
            if (_graduatedCollege == null) {
              SnackbarUtil.showError(
                context,
                'Please select your graduated college',
              );
              return;
            }
            if (_graduatedProgram == null) {
              SnackbarUtil.showError(
                context,
                'Please select your graduated program',
              );
              return;
            }
          }
        }
      }

      // Non-CMU Student validations
      if (_isCMUStudent == 'no') {
        if (_associationType == null) {
          SnackbarUtil.showError(
            context,
            'Please select how you are associated with CMU',
          );
          return;
        }

        if (_associationType == 'incoming_freshman') {
          if (_lrn == null || _lrn!.trim().isEmpty) {
            SnackbarUtil.showError(context, 'Please enter your LRN');
            return;
          }

          //  CHECK LRN UNIQUENESS (excluding current user)
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final isLrnUnique = await _isLRNUnique(
              _lrn!.trim(),
              excludeUserId: user.uid,
            );
            if (!isLrnUnique) {
              SnackbarUtil.showError(context, 'This LRN is already registered');
              return;
            }
          }
        } else if (_associationType == 'masteral') {
          if (_selectedProgram == null) {
            SnackbarUtil.showError(
              context,
              'Please select your masteral program',
            );
            return;
          }
        } else if (_associationType == 'others') {
          if (_customAffiliation == null ||
              _customAffiliation!.trim().isEmpty) {
            SnackbarUtil.showError(context, 'Please specify your affiliation');
            return;
          }
        }
      }
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        bool passwordUpdated = false;

        if (_passwordController.text.trim().isNotEmpty) {
          try {
            await user.updatePassword(_passwordController.text.trim());
            passwordUpdated = true;
          } catch (passwordError) {
            if (passwordError.toString().contains('requires-recent-login')) {
              SnackbarUtil.showError(
                context,
                'Please log out and log in again to change your password',
              );
              setState(() => _isSaving = false);
              return;
            } else {
              throw passwordError;
            }
          }
        }

        final fullName =
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

        Map<String, dynamic> updateData = {
          'name': fullName.trim(),
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'profileCompleted': true,
          'onboardingCompleted': true,
          'hasSeenOnboardingGuide': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (_role == 'user') {
          // CMU STUDENT
          if (_isCMUStudent == 'yes') {
            updateData.addAll({
              'affiliation': 'CMU Student',
              'isEnrolled': true,
              'studentType': _studentType,
              'lrn': null,
            });

            if (_studentType == 'undergraduate') {
              updateData.addAll({
                'studentId': _studentId,
                'year': _selectedYear,
                'college': _selectedCollege,
                'collegeId': _selectedCollegeId,
                'program': _selectedProgram,
                'scholarship': _hasScholarship ? _selectedScholarship : null,
                'graduateType': null,
                'graduatedCollege': null,
                'graduatedCollegeId': null,
                'graduatedProgram': null,
              });
            } else if (_studentType == 'graduate') {
              updateData.addAll({
                'studentId': null,
                'graduateType': _graduateType,
                'scholarship': null,
              });

              if (_graduateType == 'masteral') {
                updateData.addAll({
                  'year': 'Graduate',
                  'program': _selectedProgram,
                  'college': null,
                  'collegeId': null,
                  'graduatedCollege': null,
                  'graduatedCollegeId': null,
                  'graduatedProgram': null,
                });
              } else {
                updateData.addAll({
                  'year': null,
                  'program': null,
                  'college': null,
                  'collegeId': null,
                  'graduatedCollege': _graduatedCollege,
                  'graduatedCollegeId': _graduatedCollegeId,
                  'graduatedProgram': _graduatedProgram,
                });
              }
            }
          }
          // NON-CMU STUDENT
          else {
            updateData.addAll({
              'isEnrolled': false,
              'studentType': null,
              'graduateType': null,
              'year': null,
              'college': null,
              'collegeId': null,
              'studentId': null,
              'graduatedCollege': null,
              'graduatedCollegeId': null,
              'graduatedProgram': null,
            });

            if (_associationType == 'incoming_freshman') {
              updateData.addAll({
                'affiliation': 'Incoming Freshman Applicant',
                'lrn': _lrn,
                'program': null,
                'scholarship': _hasScholarship ? _selectedScholarship : null,
              });
            } else if (_associationType == 'masteral') {
              updateData.addAll({
                'affiliation': 'Masteral (Not CMU Graduate)',
                'program': _selectedProgram,
                'lrn': null,
                'scholarship': null,
              });
            } else {
              updateData.addAll({
                'affiliation': _customAffiliation,
                'program': null,
                'lrn': null,
                'scholarship': null,
              });
            }
          }
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updateData);

        if (passwordUpdated) {
          SnackbarUtil.showSuccess(
            context,
            'Profile and password updated successfully!',
          );
        } else {
          SnackbarUtil.showSuccess(context, 'Profile updated successfully!');
        }

        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          if (widget.showBackButton) {
            _navigateBackToProfile();
          } else {
            Navigator.of(context).pop();
            widget.onComplete?.call();
          }
        }
      }
    } catch (e) {
      print('Error saving profile: $e');
      SnackbarUtil.showError(
        context,
        'Failed to update profile. Please try again.',
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _navigateBackToProfile() {
    final navigatorContext = Navigator.of(context);
    navigatorContext.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showProfileModal(context);
      }
    });
  }

  void _handleBackButton() {
    if (_isSaving) return;
    if (widget.showBackButton) {
      _navigateBackToProfile();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (snapshot.exists) {
        setState(() {
          _role = snapshot.data()?['role'] ?? 'user';
        });
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}').hasMatch(email);
  }

  Widget _buildProfileHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
      child: Row(
        children: [
          if (widget.showBackButton) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                onPressed: _isSaving ? null : _handleBackButton,
                icon: const Icon(
                  Icons.arrow_back_rounded,
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
            const SizedBox(width: 12),
          ],
          Container(
            width: isMobile ? 60 : 80,
            height: isMobile ? 60 : 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFECFDF5), Color(0xFFBBF7D0)],
              ),
              borderRadius: BorderRadius.circular(isMobile ? 30 : 40),
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
              Icons.edit_outlined,
              color: const Color(0xFF2E7D32),
              size: isMobile ? 28 : 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Update your information',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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

  Widget _buildInfoField({
    required String label,
    required Widget child,
    required bool isMobile,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
                letterSpacing: 0.2,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool enabled = true,
    ValueChanged<String>? onChanged, // added ni
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(right: 12),
          child: Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(right: 12),
          child: Icon(
            Icons.lock_outline,
            size: 18,
            color: const Color(0xFF2E7D32),
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: const Color(0xFF6B7280),
            size: 20,
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
    required IconData icon,
  }) {
    //   Remove duplicates and empty values
    final uniqueItems =
        items.where((item) => item.trim().isNotEmpty).toSet().toList();

    //   Validate the current value
    final validValue =
        (value != null &&
                value.trim().isNotEmpty &&
                uniqueItems.contains(value))
            ? value
            : null;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: validValue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(right: 12),
          child: Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items:
          uniqueItems.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
            );
          }).toList(),
      onChanged: onChanged,
      dropdownColor: Colors.white,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF6B7280),
      ),
      //  ADD THESE PROPERTIES FOR SCROLLABLE DROPDOWN
      menuMaxHeight: 250, // Shows approximately 5 items (50px each)
      isDense: false,
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String value,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:
            groupValue == value
                ? const Color(0xFF2E7D32).withOpacity(0.05)
                : Colors.grey.shade50,
        border: Border.all(
          color:
              groupValue == value
                  ? const Color(0xFF2E7D32)
                  : Colors.grey.shade300,
          width: groupValue == value ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile<String>(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color:
                groupValue == value
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF374151),
          ),
        ),
        subtitle:
            subtitle != null
                ? Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                )
                : null,
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: const Color(0xFF2E7D32),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildYesNoRadio({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      value
                          ? const Color(0xFF2E7D32).withOpacity(0.05)
                          : Colors.grey.shade50,
                  border: Border.all(
                    color:
                        value ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                    width: value ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RadioListTile<bool>(
                  title: const Text('Yes', style: TextStyle(fontSize: 13)),
                  value: true,
                  groupValue: value,
                  onChanged: (val) => onChanged(val ?? false),
                  activeColor: const Color(0xFF2E7D32),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  dense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      !value
                          ? const Color(0xFF2E7D32).withOpacity(0.05)
                          : Colors.grey.shade50,
                  border: Border.all(
                    color:
                        !value ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                    width: !value ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RadioListTile<bool>(
                  title: const Text('No', style: TextStyle(fontSize: 13)),
                  value: false,
                  groupValue: value,
                  onChanged: (val) => onChanged(val ?? false),
                  activeColor: const Color(0xFF2E7D32),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  dense: true,
                ),
              ),
            ),
          ],
        ),
      ],
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: isMobile ? 42 : 48,
            child: OutlinedButton(
              onPressed: _isSaving ? null : _handleBackButton,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: Text(widget.showBackButton ? 'Back' : 'Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: isMobile ? 42 : 48,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon:
                  _isSaving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.save_outlined, size: 16),
              label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
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

    return WillPopScope(
      onWillPop: () async {
        if (_isSaving) return false;
        _handleBackButton();
        return false;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 700,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
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
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProfileHeader(isMobile),
                Flexible(
                  child:
                      _isLoading
                          ? Container(
                            height: 300,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF2E7D32),
                                strokeWidth: 3,
                              ),
                            ),
                          )
                          : Column(
                            children: [
                              Flexible(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        _buildInfoField(
                                          label: 'First Name',
                                          isMobile: isMobile,
                                          child: _buildTextFormField(
                                            controller: _firstNameController,
                                            hintText: 'Enter your first name',
                                            icon: Icons.person_outline_rounded,
                                            onChanged: (value) {
                                              _nameController.text =
                                                  '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
                                            },
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Please enter your first name';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),

                                        _buildInfoField(
                                          label: 'Last Name',
                                          isMobile: isMobile,
                                          child: _buildTextFormField(
                                            controller: _lastNameController,
                                            hintText: 'Enter your last name',
                                            icon: Icons.person_outline_rounded,
                                            onChanged: (value) {
                                              _nameController.text =
                                                  '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
                                            },
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Please enter your last name';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),

                                        _buildInfoField(
                                          label: 'Email Address',
                                          isMobile: isMobile,
                                          child: _buildTextFormField(
                                            controller: _emailController,
                                            hintText:
                                                'Enter your email address',
                                            icon: Icons.email_outlined,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            enabled: false, // Disables editing
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Please enter your email address';
                                              }
                                              if (!_isValidEmail(
                                                value.trim(),
                                              )) {
                                                return 'Please enter a valid email address';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),

                                        _buildInfoField(
                                          label: 'New Password',
                                          isMobile: isMobile,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildPasswordField(
                                                controller: _passwordController,
                                                hintText:
                                                    'Leave blank to keep current password',
                                                obscureText: _obscurePassword,
                                                onToggleVisibility: () {
                                                  setState(
                                                    () =>
                                                        _obscurePassword =
                                                            !_obscurePassword,
                                                  );
                                                },
                                                validator: (value) {
                                                  if (value != null &&
                                                      value.isNotEmpty &&
                                                      value.length < 6) {
                                                    return 'Password must be at least 6 characters';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Leave blank if you don\'t want to change your password',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        _buildInfoField(
                                          label: 'Confirm Password',
                                          isMobile: isMobile,
                                          child: _buildPasswordField(
                                            controller:
                                                _confirmPasswordController,
                                            hintText:
                                                'Confirm your new password',
                                            obscureText:
                                                _obscureConfirmPassword,
                                            onToggleVisibility: () {
                                              setState(
                                                () =>
                                                    _obscureConfirmPassword =
                                                        !_obscureConfirmPassword,
                                              );
                                            },
                                            validator: (value) {
                                              if (_passwordController.text
                                                  .trim()
                                                  .isNotEmpty) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Please confirm your password';
                                                }
                                                if (value !=
                                                    _passwordController.text) {
                                                  return 'Passwords do not match';
                                                }
                                              }
                                              return null;
                                            },
                                          ),
                                        ),

                                        if (_role == 'user') ...[
                                          // STEP 1: Are you a CMU student?
                                          _buildInfoField(
                                            label: 'CMU Student Status',
                                            isMobile: isMobile,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Are you currently a student or were you a student of CMU?',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(
                                                      0xFF374151,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color:
                                                              _isCMUStudent ==
                                                                      'yes'
                                                                  ? const Color(
                                                                    0xFF2E7D32,
                                                                  ).withOpacity(
                                                                    0.05,
                                                                  )
                                                                  : Colors
                                                                      .grey
                                                                      .shade50,
                                                          border: Border.all(
                                                            color:
                                                                _isCMUStudent ==
                                                                        'yes'
                                                                    ? const Color(
                                                                      0xFF2E7D32,
                                                                    )
                                                                    : Colors
                                                                        .grey
                                                                        .shade300,
                                                            width:
                                                                _isCMUStudent ==
                                                                        'yes'
                                                                    ? 2
                                                                    : 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: RadioListTile<
                                                          String
                                                        >(
                                                          title: const Text(
                                                            'Yes',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          value: 'yes',
                                                          groupValue:
                                                              _isCMUStudent,
                                                          onChanged: (val) {
                                                            setState(() {
                                                              _isCMUStudent =
                                                                  val;
                                                              _associationType =
                                                                  null;
                                                              _customAffiliation =
                                                                  null;
                                                              _lrn = null;
                                                              // Reset fields
                                                              _studentType =
                                                                  null;
                                                              _graduateType =
                                                                  null;
                                                              _selectedYear =
                                                                  null;
                                                              _selectedProgram =
                                                                  null;
                                                              _selectedCollege =
                                                                  null;
                                                              _selectedCollegeId =
                                                                  null;
                                                              _studentId = null;
                                                              _graduatedCollege =
                                                                  null;
                                                              _graduatedCollegeId =
                                                                  null;
                                                              _graduatedProgram =
                                                                  null;
                                                            });
                                                          },
                                                          activeColor:
                                                              const Color(
                                                                0xFF2E7D32,
                                                              ),
                                                          contentPadding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 0,
                                                              ),
                                                          dense: true,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color:
                                                              _isCMUStudent ==
                                                                      'no'
                                                                  ? const Color(
                                                                    0xFF2E7D32,
                                                                  ).withOpacity(
                                                                    0.05,
                                                                  )
                                                                  : Colors
                                                                      .grey
                                                                      .shade50,
                                                          border: Border.all(
                                                            color:
                                                                _isCMUStudent ==
                                                                        'no'
                                                                    ? const Color(
                                                                      0xFF2E7D32,
                                                                    )
                                                                    : Colors
                                                                        .grey
                                                                        .shade300,
                                                            width:
                                                                _isCMUStudent ==
                                                                        'no'
                                                                    ? 2
                                                                    : 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: RadioListTile<
                                                          String
                                                        >(
                                                          title: const Text(
                                                            'No',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          value: 'no',
                                                          groupValue:
                                                              _isCMUStudent,
                                                          onChanged: (val) {
                                                            setState(() {
                                                              _isCMUStudent =
                                                                  val;
                                                              // Reset CMU student fields
                                                              _studentType =
                                                                  null;
                                                              _graduateType =
                                                                  null;
                                                              _selectedYear =
                                                                  null;
                                                              _selectedProgram =
                                                                  null;
                                                              _selectedCollege =
                                                                  null;
                                                              _selectedCollegeId =
                                                                  null;
                                                              _studentId = null;
                                                              _graduatedCollege =
                                                                  null;
                                                              _graduatedCollegeId =
                                                                  null;
                                                              _graduatedProgram =
                                                                  null;
                                                              _hasScholarship =
                                                                  false;
                                                              _selectedScholarship =
                                                                  null;
                                                            });
                                                          },
                                                          activeColor:
                                                              const Color(
                                                                0xFF2E7D32,
                                                              ),
                                                          contentPadding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 0,
                                                              ),
                                                          dense: true,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // STEP 2A: CMU STUDENT FLOW
                                          if (_isCMUStudent == 'yes') ...[
                                            _buildInfoField(
                                              label: 'Student Type',
                                              isMobile: isMobile,
                                              child: Column(
                                                children: [
                                                  _buildRadioOption(
                                                    title: 'Undergraduate',
                                                    subtitle:
                                                        'Bachelor\'s degree program',
                                                    value: 'undergraduate',
                                                    groupValue: _studentType,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _studentType = value;
                                                        _graduateType = null;
                                                        _selectedYear = null;
                                                        _selectedProgram = null;
                                                        _selectedCollege = null;
                                                        _selectedCollegeId =
                                                            null;
                                                        _graduatedCollege =
                                                            null;
                                                        _graduatedCollegeId =
                                                            null;
                                                        _graduatedProgram =
                                                            null;
                                                      });
                                                    },
                                                  ),
                                                  _buildRadioOption(
                                                    title: 'Graduate',
                                                    subtitle:
                                                        'Master\'s or Doctoral program',
                                                    value: 'graduate',
                                                    groupValue: _studentType,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _studentType = value;
                                                        _studentId = null;
                                                        _selectedYear = null;
                                                        _selectedProgram = null;
                                                        _selectedCollege = null;
                                                        _selectedCollegeId =
                                                            null;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // UNDERGRADUATE FIELDS
                                            if (_studentType ==
                                                'undergraduate') ...[
                                              _buildInfoField(
                                                label: 'Student ID',
                                                isMobile: isMobile,
                                                child: Builder(
                                                  builder: (context) {
                                                    final controller =
                                                        TextEditingController(
                                                          text:
                                                              _studentId ?? '',
                                                        );
                                                    return _buildTextFormField(
                                                      controller: controller,
                                                      hintText:
                                                          'Enter your Student ID',
                                                      icon:
                                                          Icons.badge_outlined,
                                                      onChanged:
                                                          (value) =>
                                                              _studentId =
                                                                  value,
                                                      validator: (value) {
                                                        if (value == null ||
                                                            value
                                                                .trim()
                                                                .isEmpty) {
                                                          return 'Student ID is required';
                                                        }
                                                        return null;
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),

                                              _buildInfoField(
                                                label: 'Year Level',
                                                isMobile: isMobile,
                                                child: _buildDropdownField(
                                                  value: _selectedYear,
                                                  items: _years,
                                                  onChanged:
                                                      (value) => setState(
                                                        () =>
                                                            _selectedYear =
                                                                value,
                                                      ),
                                                  hint:
                                                      'Select your year level',
                                                  icon: Icons.school_outlined,
                                                ),
                                              ),

                                              _buildInfoField(
                                                label: 'College',
                                                isMobile: isMobile,
                                                child: _buildDropdownField(
                                                  value: _selectedCollege,
                                                  items: _colleges,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _selectedCollege = value;
                                                      _selectedCollegeId =
                                                          _collegesMap[value];
                                                      _selectedProgram = null;
                                                    });
                                                  },
                                                  hint: 'Select your college',
                                                  icon:
                                                      Icons
                                                          .account_balance_outlined,
                                                ),
                                              ),

                                              if (_selectedCollegeId !=
                                                  null) ...[
                                                _buildInfoField(
                                                  label: 'Program',
                                                  isMobile: isMobile,
                                                  child: Builder(
                                                    builder: (context) {
                                                      final key =
                                                          '${_selectedCollegeId}_Bachelor';
                                                      final availablePrograms =
                                                          _programsByCollege[key] ??
                                                          [];
                                                      return _buildDropdownField(
                                                        value:
                                                            (_selectedProgram !=
                                                                        null &&
                                                                    availablePrograms
                                                                        .contains(
                                                                          _selectedProgram,
                                                                        ))
                                                                ? _selectedProgram
                                                                : null,
                                                        items:
                                                            availablePrograms,
                                                        onChanged:
                                                            (value) => setState(
                                                              () =>
                                                                  _selectedProgram =
                                                                      value,
                                                            ),
                                                        hint:
                                                            availablePrograms
                                                                    .isEmpty
                                                                ? 'No programs available'
                                                                : 'Select your program',
                                                        icon:
                                                            Icons.book_outlined,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],

                                              // Scholarship for undergraduate
                                              _buildInfoField(
                                                label: 'Scholarship',
                                                isMobile: isMobile,
                                                child: Column(
                                                  children: [
                                                    _buildYesNoRadio(
                                                      label:
                                                          'Do you have a scholarship?',
                                                      value: _hasScholarship,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _hasScholarship =
                                                              value;
                                                          if (!value)
                                                            _selectedScholarship =
                                                                null;
                                                        });
                                                      },
                                                    ),
                                                    if (_hasScholarship) ...[
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      _buildDropdownField(
                                                        value:
                                                            _selectedScholarship,
                                                        items: _scholarships,
                                                        onChanged:
                                                            (value) => setState(
                                                              () =>
                                                                  _selectedScholarship =
                                                                      value,
                                                            ),
                                                        hint:
                                                            'Select your scholarship',
                                                        icon:
                                                            Icons
                                                                .card_membership_outlined,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // GRADUATE FIELDS
                                            if (_studentType == 'graduate') ...[
                                              _buildInfoField(
                                                label: 'Graduate Status',
                                                isMobile: isMobile,
                                                child: Column(
                                                  children: [
                                                    _buildRadioOption(
                                                      title: 'Taking Masteral',
                                                      subtitle:
                                                          'Currently enrolled in a Master\'s program',
                                                      value: 'masteral',
                                                      groupValue: _graduateType,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _graduateType = value;
                                                          _selectedProgram =
                                                              null;
                                                          _graduatedCollege =
                                                              null;
                                                          _graduatedCollegeId =
                                                              null;
                                                          _graduatedProgram =
                                                              null;
                                                        });
                                                      },
                                                    ),
                                                    _buildRadioOption(
                                                      title:
                                                          'Already Graduated',
                                                      subtitle:
                                                          'Not currently taking a Master\'s program',
                                                      value: 'not_masteral',
                                                      groupValue: _graduateType,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _graduateType = value;
                                                          _selectedProgram =
                                                              null;
                                                          _graduatedCollege =
                                                              null;
                                                          _graduatedCollegeId =
                                                              null;
                                                          _graduatedProgram =
                                                              null;
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Masteral program (no college)
                                              if (_graduateType ==
                                                  'masteral') ...[
                                                _buildInfoField(
                                                  label: 'Masteral Program',
                                                  isMobile: isMobile,
                                                  child: Builder(
                                                    builder: (context) {
                                                      //  GET MASTERAL PROGRAMS FROM THE MAP
                                                      final masteralPrograms =
                                                          _programsByCollege['Masteral'] ??
                                                          [];
                                                      return _buildDropdownField(
                                                        value:
                                                            (_selectedProgram !=
                                                                        null &&
                                                                    masteralPrograms
                                                                        .contains(
                                                                          _selectedProgram,
                                                                        ))
                                                                ? _selectedProgram
                                                                : null,
                                                        items: masteralPrograms,
                                                        onChanged:
                                                            (value) => setState(
                                                              () =>
                                                                  _selectedProgram =
                                                                      value,
                                                            ),
                                                        hint:
                                                            masteralPrograms
                                                                    .isEmpty
                                                                ? 'No masteral programs available'
                                                                : 'Select your masteral program',
                                                        icon:
                                                            Icons.book_outlined,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                              // Not masteral - show graduated college and program
                                              if (_graduateType ==
                                                  'not_masteral') ...[
                                                _buildInfoField(
                                                  label: 'Graduated College',
                                                  isMobile: isMobile,
                                                  child: _buildDropdownField(
                                                    value: _graduatedCollege,
                                                    items: _colleges,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _graduatedCollege =
                                                            value;
                                                        _graduatedCollegeId =
                                                            _collegesMap[value];
                                                        _graduatedProgram =
                                                            null;
                                                      });
                                                    },
                                                    hint:
                                                        'Select graduated college',
                                                    icon:
                                                        Icons
                                                            .account_balance_outlined,
                                                  ),
                                                ),

                                                if (_graduatedCollegeId !=
                                                    null) ...[
                                                  _buildInfoField(
                                                    label: 'Graduated Program',
                                                    isMobile: isMobile,
                                                    child: Builder(
                                                      builder: (context) {
                                                        final key =
                                                            '${_graduatedCollegeId}_Bachelor';
                                                        final availablePrograms =
                                                            _programsByCollege[key] ??
                                                            [];
                                                        return _buildDropdownField(
                                                          value:
                                                              (_graduatedProgram !=
                                                                          null &&
                                                                      availablePrograms
                                                                          .contains(
                                                                            _graduatedProgram,
                                                                          ))
                                                                  ? _graduatedProgram
                                                                  : null,
                                                          items:
                                                              availablePrograms,
                                                          onChanged:
                                                              (
                                                                value,
                                                              ) => setState(
                                                                () =>
                                                                    _graduatedProgram =
                                                                        value,
                                                              ),
                                                          hint:
                                                              'Select graduated program',
                                                          icon:
                                                              Icons
                                                                  .book_outlined,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ],
                                          ],

                                          // STEP 2B: NON-CMU STUDENT FLOW
                                          if (_isCMUStudent == 'no') ...[
                                            _buildInfoField(
                                              label:
                                                  'How are you associated with CMU?',
                                              isMobile: isMobile,
                                              child: Column(
                                                children: [
                                                  _buildRadioOption(
                                                    title:
                                                        'Incoming Freshman Applicant',
                                                    subtitle:
                                                        'Planning to enroll as a freshman',
                                                    value: 'incoming_freshman',
                                                    groupValue:
                                                        _associationType,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _associationType =
                                                            value;
                                                        _selectedProgram = null;
                                                        _customAffiliation =
                                                            null;
                                                      });
                                                    },
                                                  ),
                                                  _buildRadioOption(
                                                    title:
                                                        'Taking Masteral Program',
                                                    subtitle:
                                                        'Not a CMU graduate but taking masteral',
                                                    value: 'masteral',
                                                    groupValue:
                                                        _associationType,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _associationType =
                                                            value;
                                                        _lrn = null;
                                                        _customAffiliation =
                                                            null;
                                                        _hasScholarship = false;
                                                        _selectedScholarship =
                                                            null;
                                                      });
                                                    },
                                                  ),
                                                  _buildRadioOption(
                                                    title: 'Others',
                                                    subtitle:
                                                        'Parent, Faculty, Staff, Alumni, etc.',
                                                    value: 'others',
                                                    groupValue:
                                                        _associationType,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _associationType =
                                                            value;
                                                        _lrn = null;
                                                        _selectedProgram = null;
                                                        _hasScholarship = false;
                                                        _selectedScholarship =
                                                            null;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // INCOMING FRESHMAN
                                            if (_associationType ==
                                                'incoming_freshman') ...[
                                              _buildInfoField(
                                                label:
                                                    'Learner Reference Number (LRN)',
                                                isMobile: isMobile,
                                                child: Builder(
                                                  builder: (context) {
                                                    final controller =
                                                        TextEditingController(
                                                          text: _lrn ?? '',
                                                        );
                                                    return _buildTextFormField(
                                                      controller: controller,
                                                      hintText:
                                                          'Enter your 12-digit LRN',
                                                      icon:
                                                          Icons
                                                              .numbers_outlined,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      onChanged:
                                                          (value) =>
                                                              _lrn = value,
                                                      validator: (value) {
                                                        if (value == null ||
                                                            value
                                                                .trim()
                                                                .isEmpty) {
                                                          return 'LRN is required';
                                                        }
                                                        if (value
                                                                .trim()
                                                                .length !=
                                                            12) {
                                                          return 'LRN must be exactly 12 digits';
                                                        }
                                                        return null;
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),

                                              _buildInfoField(
                                                label: 'Scholarship',
                                                isMobile: isMobile,
                                                child: Column(
                                                  children: [
                                                    _buildYesNoRadio(
                                                      label:
                                                          'Do you have a scholarship?',
                                                      value: _hasScholarship,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _hasScholarship =
                                                              value;
                                                          if (!value)
                                                            _selectedScholarship =
                                                                null;
                                                        });
                                                      },
                                                    ),
                                                    if (_hasScholarship) ...[
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      _buildDropdownField(
                                                        value:
                                                            _selectedScholarship,
                                                        items: _scholarships,
                                                        onChanged:
                                                            (value) => setState(
                                                              () =>
                                                                  _selectedScholarship =
                                                                      value,
                                                            ),
                                                        hint:
                                                            'Select your scholarship',
                                                        icon:
                                                            Icons
                                                                .card_membership_outlined,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // MASTERAL (NOT CMU GRADUATE)
                                            if (_associationType ==
                                                'masteral') ...[
                                              _buildInfoField(
                                                label: 'Masteral Program',
                                                isMobile: isMobile,
                                                child: Builder(
                                                  builder: (context) {
                                                    //  GET MASTERAL PROGRAMS FROM THE MAP
                                                    final masteralPrograms =
                                                        _programsByCollege['Masteral'] ??
                                                        [];
                                                    return _buildDropdownField(
                                                      value:
                                                          (_selectedProgram !=
                                                                      null &&
                                                                  masteralPrograms
                                                                      .contains(
                                                                        _selectedProgram,
                                                                      ))
                                                              ? _selectedProgram
                                                              : null,
                                                      items: masteralPrograms,
                                                      onChanged:
                                                          (value) => setState(
                                                            () =>
                                                                _selectedProgram =
                                                                    value,
                                                          ),
                                                      hint:
                                                          masteralPrograms
                                                                  .isEmpty
                                                              ? 'No masteral programs available'
                                                              : 'Select your masteral program',
                                                      icon: Icons.book_outlined,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],

                                            // OTHERS
                                            if (_associationType ==
                                                'others') ...[
                                              _buildInfoField(
                                                label:
                                                    'Specify Your Affiliation',
                                                isMobile: isMobile,
                                                child: Builder(
                                                  builder: (context) {
                                                    final controller =
                                                        TextEditingController(
                                                          text:
                                                              _customAffiliation ??
                                                              '',
                                                        );
                                                    return _buildTextFormField(
                                                      controller: controller,
                                                      hintText:
                                                          'e.g., Parent, Faculty, Staff, Alumni',
                                                      icon:
                                                          Icons.people_outline,
                                                      onChanged:
                                                          (value) =>
                                                              _customAffiliation =
                                                                  value,
                                                      validator: (value) {
                                                        if (value == null ||
                                                            value
                                                                .trim()
                                                                .isEmpty) {
                                                          return 'Please specify your affiliation';
                                                        }
                                                        return null;
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              _buildActionButtons(isMobile),
                            ],
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Management Modal for Programs, Affiliations, and Scholarships
class ManagementModal extends StatefulWidget {
  final String type;
  final VoidCallback onUpdated;

  const ManagementModal({
    super.key,
    required this.type,
    required this.onUpdated,
  });

  @override
  State<ManagementModal> createState() => _ManagementModalState();
}

class _ManagementModalState extends State<ManagementModal> {
  List<DocumentSnapshot> items = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get collectionName => widget.type;
  String get displayName => widget.type;

  Future<void> _fetchItems() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection(collectionName)
              .orderBy('name')
              .get();

      setState(() {
        items = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      SnackbarUtil.showError(context, 'Failed to load ${widget.type}: $e');
    }
  }

  List<DocumentSnapshot> get filteredItems {
    if (searchQuery.isEmpty) return items;
    return items.where((item) {
      final data = item.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      return name.contains(searchQuery.toLowerCase());
    }).toList();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AddEditDialog(
            type: widget.type,
            onSaved: () {
              _fetchItems();
              widget.onUpdated();
            },
          ),
    );
  }

  void _showEditDialog(DocumentSnapshot item) {
    showDialog(
      context: context,
      builder:
          (context) => AddEditDialog(
            type: widget.type,
            item: item,
            onSaved: () {
              _fetchItems();
              widget.onUpdated();
            },
          ),
    );
  }

  void _showDeleteDialog(DocumentSnapshot item) {
    final data = item.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade600, size: 24),
                const SizedBox(width: 12),
                Text('Delete $displayName'),
              ],
            ),
            content: Text(
              'Are you sure you want to delete "${data['name']}"?\n\nThis action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _deleteItem(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteItem(DocumentSnapshot item) async {
    try {
      Navigator.of(context).pop();
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(item.id)
          .delete();
      _fetchItems();
      widget.onUpdated();
      SnackbarUtil.showSuccess(context, '$displayName deleted successfully');
    } catch (e) {
      SnackbarUtil.showError(context, 'Failed to delete $displayName: $e');
    }
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
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIconForType(widget.type),
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
                            'Manage $displayName' + 's',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add, edit, or delete ${widget.type}',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged:
                            (value) => setState(() => searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Search ${widget.type}...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF9CA3AF),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF2E7D32),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(isMobile ? 'Add' : 'Add $displayName'),
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
                  ],
                ),
              ),
              Expanded(
                child:
                    isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredItems.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getIconForType(widget.type),
                                size: 64,
                                color: const Color(0xFF9CA3AF),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchQuery.isEmpty
                                    ? 'No ${widget.type} found'
                                    : 'No ${widget.type} match your search',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          padding: EdgeInsets.all(isMobile ? 20 : 28),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final data = item.data() as Map<String, dynamic>;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2E7D32,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getIconForType(widget.type),
                                    color: const Color(0xFF2E7D32),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  data['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle:
                                    data['description'] != null &&
                                            data['description']
                                                .toString()
                                                .isNotEmpty
                                        ? Text(
                                          data['description'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                        : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _showEditDialog(item),
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Color(0xFF3B82F6),
                                        size: 18,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _showDeleteDialog(item),
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Color(0xFFDC2626),
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

  IconData _getIconForType(String type) {
    switch (type) {
      case 'programs':
        return Icons.school_outlined;
      case 'affiliations':
        return Icons.people_outlined;
      case 'scholarships':
        return Icons.card_membership_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}

// Add/Edit Dialog
class AddEditDialog extends StatefulWidget {
  final String type;
  final DocumentSnapshot? item;
  final VoidCallback onSaved;

  const AddEditDialog({
    super.key,
    required this.type,
    this.item,
    required this.onSaved,
  });

  @override
  State<AddEditDialog> createState() => _AddEditDialogState();
}

class _AddEditDialogState extends State<AddEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final data = widget.item!.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _descriptionController.text = data['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get isEditing => widget.item != null;
  String get displayName => widget.type
      .replaceAll('s', '')
      .replaceFirst(widget.type[0], widget.type[0].toUpperCase());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'updatedAt': Timestamp.now(),
      };

      if (isEditing) {
        await FirebaseFirestore.instance
            .collection(widget.type)
            .doc(widget.item!.id)
            .update(data);
      } else {
        data['createdAt'] = Timestamp.now();
        await FirebaseFirestore.instance.collection(widget.type).add(data);
      }

      widget.onSaved();
      Navigator.of(context).pop();

      //  Use SnackbarUtil
      SnackbarUtil.showSuccess(
        context,
        '$displayName ${isEditing ? 'updated' : 'created'} successfully!',
      );
    } catch (e) {
      //  Use SnackbarUtil
      SnackbarUtil.showError(
        context,
        'Failed to ${isEditing ? 'update' : 'create'} $displayName: $e',
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEditing ? 'Edit $displayName' : 'Add $displayName'),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '$displayName Name',
                  hintText: 'Enter ${displayName.toLowerCase()} name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a ${displayName.toLowerCase()} name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Enter a brief description...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
