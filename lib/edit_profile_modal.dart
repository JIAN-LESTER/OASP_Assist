import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capstone_project/pages/admin_pages/buttons/affiliation.dart';
import 'package:capstone_project/pages/admin_pages/buttons/program.dart';
import 'package:capstone_project/profile.dart';

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
  List<String> _affiliations = [];
  List<String> _scholarships = [];

  final List<String> _years = [
    'Incoming',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'Graduate',
  ];

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
          setState(() {
            _nameController.text = data['name'] ?? '';
            _emailController.text = data['email'] ?? '';
            _selectedYear = data['year'];
            _selectedProgram = data['program'];
            _selectedAffiliation = data['affiliation'];
            _selectedScholarship = data['scholarship'];

            _hasAffiliation =
                data['affiliation'] != null &&
                data['affiliation'].toString().isNotEmpty;
            _hasScholarship =
                data['scholarship'] != null &&
                data['scholarship'].toString().isNotEmpty;

            bool isEnrolled = data['isEnrolled'] ?? true;
            _enrollmentStatus = isEnrolled ? 'enrolled' : 'not_enrolled';
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
      final futures = await Future.wait([
        _getDropdownItems('programs'),
        _getDropdownItems('affiliations'),
        _getDropdownItems('scholarships'),
      ]);

      setState(() {
        _programs = [...futures[0], 'Others'];
        _affiliations = [...futures[1]];
        _scholarships = [...futures[2], 'Others'];
      });
    } catch (e) {
      print('Error loading dropdown data: $e');
    }
  }

  Future<List<String>> _getDropdownItems(String collection) async {
    final snapshot =
        await FirebaseFirestore.instance.collection(collection).get();
    return snapshot.docs.map((doc) => doc['name'] as String).toList();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == 'user') {
      if (_enrollmentStatus == null) {
        _showSnackBar('Please select your enrollment status', isError: true);
        return;
      }

      if (_enrollmentStatus == 'enrolled' &&
          (_selectedYear == null || _selectedProgram == null)) {
        _showSnackBar('Please select both year and program', isError: true);
        return;
      }
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (_passwordController.text.trim().isNotEmpty) {
          try {
            await user.updatePassword(_passwordController.text.trim());
            _showSnackBar('Password updated successfully!');
          } catch (passwordError) {
            if (passwordError.toString().contains('requires-recent-login')) {
              _showSnackBar(
                'Please log out and log in again to change your password',
                isError: true,
              );
              setState(() => _isSaving = false);
              return;
            } else {
              throw passwordError;
            }
          }
        }

        Map<String, dynamic> updateData = {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'profileCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (_role == 'user') {
          updateData.addAll({
            'isEnrolled': _enrollmentStatus == 'enrolled',
            'affiliation': _hasAffiliation ? _selectedAffiliation : null,
            'scholarship': _hasScholarship ? _selectedScholarship : null,
          });

          if (_enrollmentStatus == 'enrolled') {
            updateData.addAll({
              'year': _selectedYear,
              'program': _selectedProgram,
            });
          } else {
            updateData.addAll({'year': 'Incoming', 'program': null});
          }
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updateData);

        _showSnackBar('Profile updated successfully!');
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
      _showSnackBar(
        'Failed to update profile. Please try again.',
        isError: true,
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade600 : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
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

  Widget _buildManagementButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, size: 20, color: const Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Text(
                'Management Tools',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [ManageProgramsButton(), ManageAffiliationsButton()],
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
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
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
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
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
          items.map((item) {
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
                                          label: 'Full Name',
                                          isMobile: isMobile,
                                          child: _buildTextFormField(
                                            controller: _nameController,
                                            hintText: 'Enter your full name',
                                            icon: Icons.person_outline_rounded,
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Please enter your full name';
                                              }
                                              if (value.trim().length < 2) {
                                                return 'Name must be at least 2 characters';
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

                                        if (_role != 'user') ...[
                                          _buildInfoField(
                                            label: 'Management',
                                            isMobile: isMobile,
                                            child: _buildManagementButtons(),
                                          ),
                                        ],

                                        if (_role == 'user') ...[
                                          _buildInfoField(
                                            label: 'Enrollment Status',
                                            isMobile: isMobile,
                                            child: Column(
                                              children: [
                                                _buildRadioOption(
                                                  title: 'Currently Enrolled',
                                                  subtitle:
                                                      'I am currently enrolled in a program',
                                                  value: 'enrolled',
                                                  groupValue: _enrollmentStatus,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _enrollmentStatus = value;
                                                      if (value ==
                                                          'not_enrolled') {
                                                        _selectedYear = null;
                                                        _selectedProgram = null;
                                                      }
                                                    });
                                                  },
                                                ),
                                                _buildRadioOption(
                                                  title: 'Not Yet Enrolled',
                                                  subtitle:
                                                      'I am not currently enrolled in any program',
                                                  value: 'not_enrolled',
                                                  groupValue: _enrollmentStatus,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _enrollmentStatus = value;
                                                      if (value ==
                                                          'not_enrolled') {
                                                        _selectedYear = null;
                                                        _selectedProgram = null;
                                                      }
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),

                                          if (_enrollmentStatus ==
                                              'enrolled') ...[
                                            _buildInfoField(
                                              label: 'Year Level',
                                              isMobile: isMobile,
                                              child: _buildDropdownField(
                                                value: _selectedYear,
                                                items: _years,
                                                onChanged:
                                                    (value) => setState(
                                                      () =>
                                                          _selectedYear = value,
                                                    ),
                                                hint: 'Select your year level',
                                                icon: Icons.school_outlined,
                                              ),
                                            ),
                                            _buildInfoField(
                                              label: 'Program',
                                              isMobile: isMobile,
                                              child: _buildDropdownField(
                                                value: _selectedProgram,
                                                items: _programs,
                                                onChanged:
                                                    (value) => setState(
                                                      () =>
                                                          _selectedProgram =
                                                              value,
                                                    ),
                                                hint: 'Select your program',
                                                icon: Icons.book_outlined,
                                              ),
                                            ),
                                          ],

                                          _buildInfoField(
                                            label: 'Affiliation',
                                            isMobile: isMobile,
                                            child: Column(
                                              children: [
                                                _buildYesNoRadio(
                                                  label:
                                                      'Do you have an affiliation?',
                                                  value: _hasAffiliation,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _hasAffiliation = value;
                                                      if (!value)
                                                        _selectedAffiliation =
                                                            null;
                                                    });
                                                  },
                                                ),
                                                if (_hasAffiliation) ...[
                                                  const SizedBox(height: 12),
                                                  _buildDropdownField(
                                                    value: _selectedAffiliation,
                                                    items: _affiliations,
                                                    onChanged:
                                                        (value) => setState(
                                                          () =>
                                                              _selectedAffiliation =
                                                                  value,
                                                        ),
                                                    hint:
                                                        'Select your affiliation',
                                                    icon: Icons.people_outline,
                                                  ),
                                                ],
                                              ],
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
                                                      _hasScholarship = value;
                                                      if (!value)
                                                        _selectedScholarship =
                                                            null;
                                                    });
                                                  },
                                                ),
                                                if (_hasScholarship) ...[
                                                  const SizedBox(height: 12),
                                                  _buildDropdownField(
                                                    value: _selectedScholarship,
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
      _showSnackBar('Failed to load ${widget.type}: $e', isError: true);
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade600 : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
      _showSnackBar('$displayName deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete $displayName: $e', isError: true);
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$displayName ${isEditing ? 'updated' : 'created'} successfully!',
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to ${isEditing ? 'update' : 'create'} $displayName: $e',
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
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
