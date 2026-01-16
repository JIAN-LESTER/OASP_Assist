import 'dart:async';

import 'package:capstone_project/modules/user_module/user_main_page.dart';
import 'package:capstone_project/responsive/user_constant.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserOnboardingScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserOnboardingScreen({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<UserOnboardingScreen> createState() => _UserOnboardingScreenState();
}

class _UserOnboardingScreenState extends State<UserOnboardingScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isEditingFromSummary = false;

  static const Color primaryColor = Color.fromARGB(255, 8, 121, 11);
  static const Color backgroundColor = Colors.white;
  static final Color textPrimaryColor = Colors.grey[800]!;
  static final Color textSecondaryColor = Colors.grey[600]!;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _lrnController = TextEditingController();
  final _customScholarshipController = TextEditingController();
  final _customAffiliationController = TextEditingController();

  String? _selectedRole;
  String _selectedYear = '';
  String _selectedCourse = '';
  String? _selectedCourseId;
  String _selectedProgram = '';
  String? _selectedScholarship;
  bool? _isEnrolledInMasters;
  String _selectedMastersProgram = '';
  String _firstChoiceProgram = '';
  String _secondChoiceProgram = '';
  String _intendedMastersProgram = '';
  String? _selectedAffiliation;

  Map<String, String> _courses = {};
  Map<String, List<String>> _programsByCourse = {};
  List<String> _mastersPrograms = [];
  List<String> _scholarships = [];

  final List<String> _otherAffiliations = ['Parent', 'Faculty', 'CMU Staff', 'Alumni', 'Visitor', 'Others'];
  final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year', 'Incoming'];
  final List<String> _roles = [
    'CMU Undergraduate Student',
    'CMU Student – Graduate Level',
    'Freshman Applicant',
    'Master\'s Applicant',
    'Other (Non-student)',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    try {
      final coursesSnapshot = await FirebaseFirestore.instance.collection('colleges').get();
      Map<String, String> coursesMap = {};
      for (var doc in coursesSnapshot.docs) {
        final name = doc.data()['name']?.toString().trim();
        if (name != null && name.isNotEmpty) coursesMap[name] = doc.id;
      }

      final programsSnapshot = await FirebaseFirestore.instance.collection('programs').get();
      Map<String, List<String>> programsByCourseMap = {};
      List<String> mastersPrograms = [];

      for (var doc in programsSnapshot.docs) {
        final programName = doc.data()['name']?.toString().trim();
        final courseId = doc.data()['collegeId']?.toString() ?? '';
        final category = doc.data()['category']?.toString();
        if (programName == null || programName.isEmpty || category == null) continue;

        if (category == "Masteral") {
          mastersPrograms.add(programName);
        } else {
          if (courseId.isEmpty) continue;
          final key = '${courseId}_$category';
          programsByCourseMap.putIfAbsent(key, () => []).add(programName);
        }
      }

      final scholarshipsSnapshot = await FirebaseFirestore.instance.collection('scholarships').get();
      List<String> scholarshipsList = scholarshipsSnapshot.docs
          .map((doc) => doc.data()['name']?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();

      setState(() {
        _courses = coursesMap;
        _programsByCourse = programsByCourseMap;
        _mastersPrograms = mastersPrograms;
        _scholarships = [...scholarshipsList, "Others"];
      });
    } catch (e) {
      print('Error loading dropdown data: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _studentIdController.dispose();
    _lrnController.dispose();
    _customScholarshipController.dispose();
    _customAffiliationController.dispose();
    super.dispose();
  }

  Widget _buildContent({
    required double maxWidth,
    required double horizontalPadding,
    required double iconSize,
    required double titleFontSize,
    required double descriptionFontSize,
    required double buttonHeight,
    required double cardPadding,
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'OASP Assist',
                      style: TextStyle(
                        fontSize: titleFontSize * 0.65,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      'Step ${_currentPage + 1} of 4',
                      style: TextStyle(
                        fontSize: descriptionFontSize * 0.95,
                        fontWeight: FontWeight.w600,
                        color: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentPage + 1) / 4,
                    backgroundColor: primaryColor.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(iconSize, titleFontSize, descriptionFontSize, cardPadding),
                _buildStep2(iconSize, titleFontSize, descriptionFontSize, cardPadding),
                _buildFeaturesPage(iconSize, titleFontSize, descriptionFontSize, cardPadding),
                _buildCompletePage(iconSize, titleFontSize, descriptionFontSize),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Row(
              children: [
                if (_currentPage > 0) ...[
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: const BorderSide(color: primaryColor, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: buttonHeight),
                      ),
                      child: Text(
                        'Back',
                        style: TextStyle(
                          fontSize: descriptionFontSize * 0.95,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: _canProceed() ? _nextPage : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(vertical: buttonHeight),
                    ),
                    child: Text(
                      _currentPage == 3 ? 'Start Chatting!' : 'Continue',
                      style: TextStyle(
                        fontSize: descriptionFontSize * 0.95,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  Widget _buildStep1(double iconSize, double titleFontSize, double descriptionFontSize, double cardPadding) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: iconSize * 0.75,
                height: iconSize * 0.75,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: iconSize * 0.4,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Personal Information',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w800,
              color: textPrimaryColor,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Let\'s start with your basic information',
            style: TextStyle(
              fontSize: descriptionFontSize,
              color: textSecondaryColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _firstNameController,
            decoration: _inputDecoration('First Name', 'Enter your first name', Icons.person_outline),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            decoration: _inputDecoration('Last Name', 'Enter your last name', Icons.person_outline),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Avatar selection available in profile settings',
                    style: TextStyle(
                      fontSize: descriptionFontSize * 0.85,
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(double iconSize, double titleFontSize, double descriptionFontSize, double cardPadding) {
    bool allFieldsComplete = _canProceed() && _selectedRole != null;

    // Show summary if all fields complete AND not editing
    if (allFieldsComplete && !_isEditingFromSummary) {
      return _buildProfileSummary(iconSize, titleFontSize, descriptionFontSize, cardPadding);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.badge_outlined, size: iconSize * 0.4, color: primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Which best describes you?',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w800,
              color: textPrimaryColor,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Select your role and complete the required information',
            style: TextStyle(
              fontSize: descriptionFontSize,
              color: textSecondaryColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          ..._roles.map((role) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCollapsibleRoleCard(role, descriptionFontSize),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildCollapsibleRoleCard(String role, double fontSize) {
    final isSelected = _selectedRole == role;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
        border: Border.all(
          color: isSelected ? primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected ? [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (_selectedRole == role) return;
              _selectedRole = role;
              _resetFields();
              _isEditingFromSummary = false;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? primaryColor : Colors.grey[400]!,
                          width: 2.5,
                        ),
                        color: isSelected ? primaryColor : Colors.transparent,
                      ),
                      child: isSelected 
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        role,
                        style: TextStyle(
                          fontSize: fontSize * 0.95,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? primaryColor : textPrimaryColor,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Selected',
                          style: TextStyle(
                            fontSize: fontSize * 0.7,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Expandable content
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                child: isSelected
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 1,
                            color: primaryColor.withOpacity(0.15),
                            margin: const EdgeInsets.only(bottom: 20),
                          ),
                          _buildRoleFields(fontSize),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSummary(double iconSize, double titleFontSize, double descriptionFontSize, double cardPadding) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.15),
                        primaryColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: iconSize * 0.75,
                      height: iconSize * 0.75,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: iconSize * 0.45,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Review Your Information',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    color: textPrimaryColor,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Please review your details before proceeding',
                  style: TextStyle(
                    fontSize: descriptionFontSize,
                    color: textSecondaryColor,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  primaryColor.withOpacity(0.01),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(-5, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryItem(
                  icon: Icons.person,
                  label: 'Full Name',
                  value: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
                  fontSize: descriptionFontSize,
                ),
                const SizedBox(height: 18),
                Divider(height: 1, color: primaryColor.withOpacity(0.1)),
                const SizedBox(height: 18),
                _buildSummaryItem(
                  icon: Icons.badge,
                  label: 'Role',
                  value: _selectedRole ?? '',
                  fontSize: descriptionFontSize,
                ),
                ..._buildRoleSummaryItems(descriptionFontSize),
              ],
            ),
          ),
          
          const SizedBox(height: 28),
          Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditingFromSummary = true;
                  });
                },
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: Text(
                  'Edit Information',
                  style: TextStyle(
                    fontSize: descriptionFontSize * 0.95,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildRoleSummaryItems(double fontSize) {
    List<Widget> items = [];
    
    switch (_selectedRole) {
      case 'CMU Undergraduate Student':
        items.addAll([
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.badge, label: 'Student ID', 
            value: _studentIdController.text.trim(), fontSize: fontSize),
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.school, label: 'Year Level', 
            value: _selectedYear, fontSize: fontSize),
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.account_balance, label: 'Course', 
            value: _selectedCourse, fontSize: fontSize),
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.book, label: 'Program', 
            value: _selectedProgram, fontSize: fontSize),
          if (_selectedScholarship != null && _selectedScholarship!.isNotEmpty) ...[
            const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
            _buildSummaryItem(icon: Icons.card_membership, label: 'Scholarship',
              value: _selectedScholarship == 'Others' 
                ? _customScholarshipController.text.trim() 
                : _selectedScholarship!, 
              fontSize: fontSize),
          ],
        ]);
        break;
      
      case 'CMU Student – Graduate Level':
        if (_studentIdController.text.trim().isNotEmpty) {
          items.addAll([
            const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
            _buildSummaryItem(icon: Icons.badge, label: 'Student ID',
              value: _studentIdController.text.trim(), fontSize: fontSize),
          ]);
        }
        items.addAll([
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.account_balance, label: 'Course',
            value: _selectedCourse, fontSize: fontSize),
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.book, label: 'Program',
            value: _selectedProgram, fontSize: fontSize),
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.school, label: 'Master\'s Enrollment',
            value: _isEnrolledInMasters == true ? 'Yes' : 'No', fontSize: fontSize),
          if (_isEnrolledInMasters == true) ...[
            const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
            _buildSummaryItem(icon: Icons.school, label: 'Master\'s Program',
              value: _selectedMastersProgram, fontSize: fontSize),
          ],
        ]);
        break;
      
      case 'Freshman Applicant':
        items.addAll([
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.badge, label: 'LRN',
            value: _lrnController.text.trim(), fontSize: fontSize),
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.looks_one, label: '1st Choice Program',
            value: _firstChoiceProgram, fontSize: fontSize),
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.looks_two, label: '2nd Choice Program',
            value: _secondChoiceProgram, fontSize: fontSize),
          if (_selectedScholarship != null && _selectedScholarship!.isNotEmpty) ...[
            const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
            _buildSummaryItem(icon: Icons.card_membership, label: 'Scholarship',
              value: _selectedScholarship == 'Others'
                ? _customScholarshipController.text.trim()
                : _selectedScholarship!,
              fontSize: fontSize),
          ],
        ]);
        break;
      
      case 'Master\'s Applicant':
        items.addAll([
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.school, label: 'Intended Master\'s Program',
            value: _intendedMastersProgram, fontSize: fontSize),
        ]);
        break;
      
      case 'Other (Non-student)':
        items.addAll([
          const SizedBox(height: 18), Divider(height: 1, color: primaryColor.withOpacity(0.1)), const SizedBox(height: 18),
          _buildSummaryItem(icon: Icons.people, label: 'Affiliation',
            value: _selectedAffiliation == 'Others'
              ? _customAffiliationController.text.trim()
              : _selectedAffiliation ?? '',
            fontSize: fontSize),
        ]);
        break;
    }
    
    return items;
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required double fontSize,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.15),
                primaryColor.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: primaryColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize * 0.8,
                  color: textSecondaryColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  fontSize: fontSize * 0.95,
                  color: textPrimaryColor,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesPage(double iconSize, double titleFontSize, double descriptionFontSize, double cardPadding) {
    final features = [
      {'icon': Icons.smart_toy, 'title': 'AI Chat Assistant', 'description': 'Get answers to your academic questions'},
      {'icon': Icons.school, 'title': 'OASP Services', 'description': 'Access admission, scholarship, and placement info'},
      {'icon': Icons.notifications_active, 'title': 'Real-time Updates', 'description': 'Stay informed with latest announcements'},
      {'icon': Icons.support_agent, 'title': '24/7 Support', 'description': 'Help available whenever you need it'},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: iconSize * 0.75,
                height: iconSize * 0.75,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star, size: iconSize * 0.4, color: primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Discover Features',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w800,
              color: textPrimaryColor,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Explore what OASP Assist can do for you',
            style: TextStyle(
              fontSize: descriptionFontSize,
              color: textSecondaryColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(feature['icon'] as IconData, color: primaryColor, size: 26),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      feature['title'] as String,
                      style: TextStyle(
                        fontSize: descriptionFontSize * 0.95,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      feature['description'] as String,
                      style: TextStyle(
                        fontSize: descriptionFontSize * 0.75,
                        color: textSecondaryColor,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCompletePage(double iconSize, double titleFontSize, double descriptionFontSize) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: iconSize * 1.2,
            height: iconSize * 1.2,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: iconSize * 0.5,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'You\'re All Set!',
            style: TextStyle(
              fontSize: titleFontSize * 1.1,
              fontWeight: FontWeight.w800,
              color: textPrimaryColor,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Perfect! You\'re ready to explore OASP Assist. Let\'s start with a conversation with our AI assistant.',
              style: TextStyle(
                fontSize: descriptionFontSize,
                color: textSecondaryColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    if (_currentPage == 0) {
      return _firstNameController.text.trim().isNotEmpty && _lastNameController.text.trim().isNotEmpty;
    }

    if (_currentPage == 1 && _selectedRole != null) {
      switch (_selectedRole) {
        case 'CMU Undergraduate Student':
          return _studentIdController.text.trim().length >= 5 && _selectedYear.isNotEmpty && 
                 _selectedCourse.isNotEmpty && _selectedProgram.isNotEmpty;
        case 'CMU Student – Graduate Level':
          return _selectedCourse.isNotEmpty && _selectedProgram.isNotEmpty && _isEnrolledInMasters != null && 
                 (_isEnrolledInMasters == false || _selectedMastersProgram.isNotEmpty);
        case 'Freshman Applicant':
          return _lrnController.text.trim().length == 12 && _firstChoiceProgram.isNotEmpty && 
                 _secondChoiceProgram.isNotEmpty && _firstChoiceProgram != _secondChoiceProgram;
        case 'Master\'s Applicant':
          return _intendedMastersProgram.isNotEmpty;
        case 'Other (Non-student)':
          return _selectedAffiliation != null && 
                 (_selectedAffiliation != 'Others' || _customAffiliationController.text.trim().isNotEmpty);
      }
    }

    if (_currentPage == 2 || _currentPage == 3) {
      return true;
    }
    return false;
  }

  Future<void> _finishOnboarding() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User session expired');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))),
        ),
      );

      await _saveUserProfile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_onboarding_completed_${user.uid}', true);
      await prefs.setBool('should_show_guide', true);

      String? newConversationId;
      try {
        newConversationId = await UserConstant.createNewConversation(user.uid);
      } catch (e) {
        print('Could not create conversation: $e');
      }

      if (mounted) Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => UserMainPage(
              initialTabIndex: 1,
              conversationId: newConversationId,
              shouldShowGuide: true,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            action: SnackBarAction(label: 'RETRY', textColor: Colors.white, onPressed: _finishOnboarding),
          ),
        );
      }
    }
  }

  Future<void> _saveUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    Map<String, dynamic> updateData = {
      'name': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim(),
      'profileCompleted': true,
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'affiliation': _selectedRole,
    };

    switch (_selectedRole) {
      case 'CMU Undergraduate Student':
        updateData.addAll({
          'studentId': _studentIdController.text.trim(),
          'year': _selectedYear,
          'course': _selectedCourse,
          'program': _selectedProgram,
          'scholarship': _selectedScholarship == 'Others' ? _customScholarshipController.text.trim() : _selectedScholarship,
        });
        break;
      case 'CMU Student – Graduate Level':
        updateData.addAll({
          'studentId': _studentIdController.text.trim().isEmpty ? null : _studentIdController.text.trim(),
          'course': _selectedCourse,
          'program': _selectedProgram,
          'isEnrolledInMasters': _isEnrolledInMasters,
          'mastersProgram': _isEnrolledInMasters == true ? _selectedMastersProgram : null,
        });
        break;
      case 'Freshman Applicant':
        updateData.addAll({
          'lrn': _lrnController.text.trim(),
          'firstChoiceProgram': _firstChoiceProgram,
          'secondChoiceProgram': _secondChoiceProgram,
          'scholarship': _selectedScholarship == 'Others' ? _customScholarshipController.text.trim() : _selectedScholarship,
        });
        break;
      case 'Master\'s Applicant':
        updateData['intendedMastersProgram'] = _intendedMastersProgram;
        break;
      case 'Other (Non-student)':
        updateData['otherAffiliation'] = _selectedAffiliation == 'Others' 
            ? _customAffiliationController.text.trim() 
            : _selectedAffiliation;
        break;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));
  }

  void _resetFields() {
    _studentIdController.clear();
    _lrnController.clear();
    _customScholarshipController.clear();
    _customAffiliationController.clear();
    _selectedYear = '';
    _selectedCourse = '';
    _selectedProgram = '';
    _selectedScholarship = null;
    _isEnrolledInMasters = null;
    _selectedMastersProgram = '';
    _firstChoiceProgram = '';
    _secondChoiceProgram = '';
    _intendedMastersProgram = '';
    _selectedAffiliation = null;
  }

  Widget _buildRoleFields(double fontSize) {
    switch (_selectedRole) {
      case 'CMU Undergraduate Student':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(controller: _studentIdController, decoration: _inputDecoration('Student ID *', 'Enter student ID', Icons.badge_outlined), onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            _buildDropdown('Year Level *', _selectedYear, years, (v) => setState(() => _selectedYear = v ?? ''), fontSize),
            const SizedBox(height: 16),
            _buildDropdown('Course *', _selectedCourse, _courses.keys.toList(), (v) => setState(() {
              _selectedCourse = v ?? '';
              _selectedCourseId = _courses[v];
              _selectedProgram = '';
            }), fontSize),
            if (_selectedCourse.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDropdown('Program *', _selectedProgram, _programsByCourse['${_selectedCourseId}_Bachelor'] ?? [], 
                (v) => setState(() => _selectedProgram = v ?? ''), fontSize),
            ],
            const SizedBox(height: 16),
            _buildDropdown('Scholarship (Optional)', _selectedScholarship, _scholarships, (v) => setState(() => _selectedScholarship = v), fontSize),
            if (_selectedScholarship == 'Others') ...[
              const SizedBox(height: 16),
              TextFormField(controller: _customScholarshipController, decoration: _inputDecoration('Specify Scholarship', 'Enter name', Icons.edit_outlined)),
            ],
          ],
        );
      case 'CMU Student – Graduate Level':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(controller: _studentIdController, decoration: _inputDecoration('Student ID (if applicable)', 'Enter ID', Icons.badge_outlined)),
            const SizedBox(height: 16),
            _buildDropdown('Course *', _selectedCourse, _courses.keys.toList(), (v) => setState(() {
              _selectedCourse = v ?? '';
              _selectedCourseId = _courses[v];
              _selectedProgram = '';
            }), fontSize),
            if (_selectedCourse.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDropdown('Program *', _selectedProgram, _programsByCourse['${_selectedCourseId}_Bachelor'] ?? [], 
                (v) => setState(() => _selectedProgram = v ?? ''), fontSize),
            ],
            const SizedBox(height: 20),
            Text('Enrolled in master\'s program?', style: TextStyle(fontSize: fontSize * 0.95, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildChoiceButton('Yes', _isEnrolledInMasters == true, () => setState(() => _isEnrolledInMasters = true), fontSize)),
                const SizedBox(width: 12),
                Expanded(child: _buildChoiceButton('No', _isEnrolledInMasters == false, () => setState(() {
                  _isEnrolledInMasters = false;
                  _selectedMastersProgram = '';
                }), fontSize)),
              ],
            ),
            if (_isEnrolledInMasters == true) ...[
              const SizedBox(height: 16),
              _buildDropdown('Master\'s Program *', _selectedMastersProgram, _mastersPrograms, (v) => setState(() => _selectedMastersProgram = v ?? ''), fontSize),
            ],
          ],
        );
      case 'Freshman Applicant':
        List<String> allPrograms = [];
        _programsByCourse.forEach((key, programs) {
          if (key.contains('Bachelor')) allPrograms.addAll(programs);
        });
        allPrograms = allPrograms.toSet().toList()..sort();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('LRN required for deduplication', style: TextStyle(fontSize: fontSize * 0.85, color: Colors.blue[900]))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _lrnController, decoration: _inputDecoration('LRN *', '12-digit LRN', Icons.badge_outlined), 
              keyboardType: TextInputType.number, maxLength: 12, onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            _buildDropdown('1st Choice Program *', _firstChoiceProgram, allPrograms, (v) => setState(() => _firstChoiceProgram = v ?? ''), fontSize),
            const SizedBox(height: 16),
            _buildDropdown('2nd Choice Program *', _secondChoiceProgram, allPrograms.where((p) => p != _firstChoiceProgram).toList(), 
              (v) => setState(() => _secondChoiceProgram = v ?? ''), fontSize),
            const SizedBox(height: 16),
            _buildDropdown('Scholarship (Optional)', _selectedScholarship, _scholarships, (v) => setState(() => _selectedScholarship = v), fontSize),
            if (_selectedScholarship == 'Others') ...[
              const SizedBox(height: 16),
              TextFormField(controller: _customScholarshipController, decoration: _inputDecoration('Specify Scholarship', 'Enter name', Icons.edit_outlined)),
            ],
          ],
        );
      case 'Master\'s Applicant':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown('Intended Master\'s Program *', _intendedMastersProgram, _mastersPrograms, (v) => setState(() => _intendedMastersProgram = v ?? ''), fontSize),
          ],
        );
      case 'Other (Non-student)':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown('Relationship with CMU *', _selectedAffiliation, _otherAffiliations, (v) => setState(() => _selectedAffiliation = v), fontSize),
            if (_selectedAffiliation == 'Others') ...[
              const SizedBox(height: 16),
              TextFormField(controller: _customAffiliationController, decoration: _inputDecoration('Specify Affiliation', 'Enter affiliation', Icons.edit_outlined), 
                onChanged: (_) => setState(() {})),
            ],
          ],
        );
      default:
        return const SizedBox();
    }
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 2)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged, double fontSize) {
    return DropdownButtonFormField<String>(
      value: value != null && value.isNotEmpty && items.contains(value) ? value : null,
      decoration: _inputDecoration(label, 'Select', Icons.arrow_drop_down),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: TextStyle(fontSize: fontSize * 0.9)))).toList(),
      onChanged: onChanged,
      isExpanded: true,
      menuMaxHeight: 300,
    );
  }

  Widget _buildChoiceButton(String text, bool isSelected, VoidCallback onTap, double fontSize) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.grey[50],
          border: Border.all(color: isSelected ? primaryColor : Colors.grey[300]!, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(text, style: TextStyle(
          fontSize: fontSize * 0.9,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? primaryColor : textPrimaryColor,
        ))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: ResponsiveLayout(
          mobileBody: _buildContent(
            maxWidth: double.infinity,
            horizontalPadding: 16,
            iconSize: 80,
            titleFontSize: 24,
            descriptionFontSize: 14,
            buttonHeight: 16,
            cardPadding: 20,
          ),
          tabletBody: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700),
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildContent(
                maxWidth: 700,
                horizontalPadding: 20,
                iconSize: 100,
                titleFontSize: 28,
                descriptionFontSize: 15,
                buttonHeight: 18,
                cardPadding: 24,
              ),
            ),
          ),
          desktopBody: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildContent(
                maxWidth: 800,
                horizontalPadding: 24,
                iconSize: 120,
                titleFontSize: 32,
                descriptionFontSize: 16,
                buttonHeight: 20,
                cardPadding: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}