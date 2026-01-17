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
  String? _selectedScholarship = '';
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

  bool? _hasScholarship; // for undergraduate
bool? _hasScholarshipFreshman; // for freshman applicant
bool _hasConfirmedCustomAffiliation = false; // for others confirmation

  final List<String> _otherAffiliations = ['Parent', 'Faculty', 'CMU Staff', 'Alumni', 'Visitor', 'Others'];
  final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year', 'Incoming'];
  final List<String> _roles = [
    'CMU Undergraduate Student',
    'CMU Student – Graduate Level',
    'Freshman Applicant',
    'Master\'s Applicant',
    'Other (Non-student)',
  ];

  final Map<String, GlobalKey> _roleCardKeys = {};

@override
void initState() {
  super.initState();
  _pageController = PageController();
  // Initialize keys for each role
  for (var role in _roles) {
    _roleCardKeys[role] = GlobalKey();
  }
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
          'Welcome to OASP Assist!',
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
          'Let\'s start by getting to know you',
          style: TextStyle(
            fontSize: descriptionFontSize,
            color: textSecondaryColor,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        
        // Privacy Disclaimer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why we need this information',
                      style: TextStyle(
                        fontSize: descriptionFontSize * 0.95,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your profile information helps us provide personalized assistance and is used for analytics and user demographics purposes only. This ensures we can better serve the CMU community.',
                      style: TextStyle(
                        fontSize: descriptionFontSize * 0.85,
                        color: textSecondaryColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
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
        
        // Updated bottom message
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.08),
                primaryColor.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.arrow_forward_rounded, color: primaryColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Continue to the next step to identify your role and complete your profile',
                  style: TextStyle(
                    fontSize: descriptionFontSize * 0.9,
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
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

// Update _buildStep2 - keep as is but the _buildCollapsibleRoleCard will center content
Widget _buildStep2(double iconSize, double titleFontSize, double descriptionFontSize, double cardPadding) {
  bool allFieldsComplete = _canProceed() && _selectedRole != null;

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
          'Tell Us About Your Role',
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
          'This helps us tailor your experience',
          style: TextStyle(
            fontSize: descriptionFontSize,
            color: textSecondaryColor,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.amber[800], size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your role information helps us provide relevant services and support tailored to your needs within the CMU community.',
                  style: TextStyle(
                    fontSize: descriptionFontSize * 0.85,
                    color: Colors.amber[900],
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
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

// Updated _buildCollapsibleRoleCard to center and emphasize content
Widget _buildCollapsibleRoleCard(String role, double fontSize) {
  final isSelected = _selectedRole == role;
  final cardKey = _roleCardKeys[role]!;

  return AnimatedContainer(
    key: cardKey,
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
            if (_selectedRole == role) {
              _selectedRole = null;
              _resetFields();
              return;
            }
            _selectedRole = role;
            _resetFields();
            _isEditingFromSummary = false;
          });
          
          // Scroll to the selected card after expansion
          if (_selectedRole == role) {
            Future.delayed(const Duration(milliseconds: 350), () {
              _scrollToSelectedCard(cardKey);
            });
          }
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
            
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: isSelected
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          height: 1,
                          color: primaryColor.withOpacity(0.15),
                          margin: const EdgeInsets.only(bottom: 24),
                        ),
                        // Centered content container
                        Container(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: _buildRoleFields(fontSize),
                        ),
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

// Add this method to handle scrolling to the selected card
void _scrollToSelectedCard(GlobalKey cardKey) {
  final context = cardKey.currentContext;
  if (context != null) {
    // Use Scrollable.ensureVisible for smooth scrolling
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      alignment: 0.15, // Position card near top of viewport (15% from top)
    );
  }
}

// Updated _buildFeaturesPage with stacked layout and new features
Widget _buildFeaturesPage(double iconSize, double titleFontSize, double descriptionFontSize, double cardPadding) {
  final features = [
    {
      'icon': Icons.psychology_outlined,
      'title': 'AI-Powered Assistant',
      'description': 'Advanced chatbot delivers intelligent, context-aware responses to your academic questions.'
    },
    {
      'icon': Icons.flash_on_outlined,
      'title': 'Lightning-Fast Replies',
      'description': 'Get immediate answers to your inquiries without any waiting time.'
    },
    {
      'icon': Icons.school_outlined,
      'title': 'OASP Services Hub',
      'description': 'Comprehensive access to admission, scholarship, and placement information in one place.'
    },
    {
      'icon': Icons.support_agent_outlined,
      'title': 'Human Escalation Support',
      'description': 'Connect directly with staff members when you need personalized assistance.'
    },
    {
      'icon': Icons.notifications_active_outlined,
      'title': 'Real-Time Notifications',
      'description': 'Stay updated with instant alerts about important announcements and updates.'
    },
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
              child: Icon(Icons.star_rounded, size: iconSize * 0.4, color: primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Discover Key Features',
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
          'Before we begin, explore what OASP Assist offers',
          style: TextStyle(
            fontSize: descriptionFontSize,
            color: textSecondaryColor,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        
        // Features Disclaimer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.08),
                primaryColor.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'OASP Assist combines cutting-edge AI technology with dedicated human support to provide you with the best assistance possible.',
                  style: TextStyle(
                    fontSize: descriptionFontSize * 0.9,
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Stacked feature cards
        ...features.map((feature) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildFeatureCard(
            icon: feature['icon'] as IconData,
            title: feature['title'] as String,
            description: feature['description'] as String,
            fontSize: descriptionFontSize,
          ),
        )).toList(),
        
        const SizedBox(height: 16),
      ],
    ),
  );
}

// Feature card builder for stacked layout
Widget _buildFeatureCard({
  required IconData icon,
  required String title,
  required String description,
  required double fontSize,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: fontSize * 0.95,
                  fontWeight: FontWeight.w700,
                  color: textPrimaryColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: fontSize * 0.85,
                  color: textSecondaryColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
              // gradient: LinearGradient(
              //   colors: [
              //     Colors.white,
              //     primaryColor.withOpacity(0.01),
              //   ],
              //   begin: Alignment.topLeft,
              //   end: Alignment.bottomRight,
              // ),
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
    return _firstNameController.text.trim().isNotEmpty && 
           _lastNameController.text.trim().isNotEmpty;
  }

  if (_currentPage == 1 && _selectedRole != null) {
    switch (_selectedRole) {
      case 'CMU Undergraduate Student':
        bool scholarshipValid = _hasScholarship == false || 
            (_hasScholarship == true && 
             _selectedScholarship != null && 
             _selectedScholarship!.isNotEmpty &&
             (_selectedScholarship != 'Others' || 
              _customScholarshipController.text.trim().isNotEmpty));
        
        return _studentIdController.text.trim().length >= 5 && 
               _selectedYear.isNotEmpty && 
               _selectedCourse.isNotEmpty && 
               _selectedProgram.isNotEmpty && 
               _hasScholarship != null &&
               scholarshipValid;

      case 'CMU Student – Graduate Level':
        return _selectedCourse.isNotEmpty && 
               _selectedProgram.isNotEmpty && 
               _isEnrolledInMasters != null && 
               (_isEnrolledInMasters == false || 
                (_isEnrolledInMasters == true && _selectedMastersProgram.isNotEmpty));

      case 'Freshman Applicant':
        bool scholarshipValid = _hasScholarshipFreshman == false || 
            (_hasScholarshipFreshman == true && 
             _selectedScholarship != null && 
             _selectedScholarship!.isNotEmpty &&
             (_selectedScholarship != 'Others' || 
              _customScholarshipController.text.trim().isNotEmpty));
        
        return _lrnController.text.trim().length == 12 && 
               _firstChoiceProgram.isNotEmpty && 
               _secondChoiceProgram.isNotEmpty && 
               _firstChoiceProgram != _secondChoiceProgram && 
               _hasScholarshipFreshman != null &&
               scholarshipValid;

      case 'Master\'s Applicant':
        return _intendedMastersProgram.isNotEmpty;

      case 'Other (Non-student)':
        return _selectedAffiliation != null && 
               (_selectedAffiliation != 'Others' || 
                (_customAffiliationController.text.trim().length >= 3 && 
                 _hasConfirmedCustomAffiliation));
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
  _hasScholarship = null;
  _hasScholarshipFreshman = null;
  _isEnrolledInMasters = null;
  _selectedMastersProgram = '';
  _firstChoiceProgram = '';
  _secondChoiceProgram = '';
  _intendedMastersProgram = '';
  _selectedAffiliation = null;
  _hasConfirmedCustomAffiliation = false;
}




Widget _buildRoleFields(double fontSize) {
  switch (_selectedRole) {
    case 'CMU Undergraduate Student':
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModernTextField(
            controller: _studentIdController,
            label: 'Student ID',
            hint: 'Enter your student ID',
            icon: Icons.badge_outlined,
            isRequired: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _buildModernDropdown(
            label: 'Year Level',
            value: _selectedYear,
            items: years,
            onChanged: (v) => setState(() => _selectedYear = v ?? ''),
            fontSize: fontSize,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildModernDropdown(
            label: 'Course',
            value: _selectedCourse,
            items: _courses.keys.toList(),
            onChanged: (v) => setState(() {
              _selectedCourse = v ?? '';
              _selectedCourseId = _courses[v];
              _selectedProgram = '';
            }),
            fontSize: fontSize,
            isRequired: true,
          ),
          if (_selectedCourse.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildModernDropdown(
              label: 'Program',
              value: _selectedProgram,
              items: _programsByCourse['${_selectedCourseId}_Bachelor'] ?? [],
              onChanged: (v) => setState(() => _selectedProgram = v ?? ''),
              fontSize: fontSize,
              isRequired: true,
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Do you have a scholarship?',
            style: TextStyle(
              fontSize: fontSize * 0.95,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildChoiceButton(
                  'Yes',
                  _hasScholarship == true,
                  () => setState(() {
                    _hasScholarship = true;
                    _selectedScholarship = null;
                  }),
                  fontSize,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChoiceButton(
                  'No',
                  _hasScholarship == false,
                  () => setState(() {
                    _hasScholarship = false;
                    _selectedScholarship = null;
                    _customScholarshipController.clear();
                  }),
                  fontSize,
                ),
              ),
            ],
          ),
          if (_hasScholarship == true) ...[
            const SizedBox(height: 16),
            _buildModernDropdown(
              label: 'Scholarship',
              value: _selectedScholarship,
              items: _scholarships,
              onChanged: (v) => setState(() {
                _selectedScholarship = v;
                if (v != 'Others') {
                  _customScholarshipController.clear();
                }
              }),
              fontSize: fontSize,
              isRequired: true,
              hint: 'Select a scholarship',
            ),
            if (_selectedScholarship == 'Others') ...[
              const SizedBox(height: 16),
              _buildModernTextField(
                controller: _customScholarshipController,
                label: 'Custom Scholarship Name',
                hint: 'Enter scholarship name',
                icon: Icons.edit_outlined,
                isRequired: true,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ],
      );

    case 'CMU Student – Graduate Level':
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModernTextField(
            controller: _studentIdController,
            label: 'Student ID',
            hint: 'Enter your student ID (optional)',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 16),
          _buildModernDropdown(
            label: 'Course',
            value: _selectedCourse,
            items: _courses.keys.toList(),
            onChanged: (v) => setState(() {
              _selectedCourse = v ?? '';
              _selectedCourseId = _courses[v];
              _selectedProgram = '';
            }),
            fontSize: fontSize,
            isRequired: true,
          ),
          if (_selectedCourse.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildModernDropdown(
              label: 'Program',
              value: _selectedProgram,
              items: _programsByCourse['${_selectedCourseId}_Bachelor'] ?? [],
              onChanged: (v) => setState(() => _selectedProgram = v ?? ''),
              fontSize: fontSize,
              isRequired: true,
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Enrolled in master\'s program? *',
            style: TextStyle(
              fontSize: fontSize * 0.95,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildChoiceButton(
                  'Yes',
                  _isEnrolledInMasters == true,
                  () => setState(() {
                    _isEnrolledInMasters = true;
                    _selectedMastersProgram = '';
                  }),
                  fontSize,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChoiceButton(
                  'No',
                  _isEnrolledInMasters == false,
                  () => setState(() {
                    _isEnrolledInMasters = false;
                    _selectedMastersProgram = '';
                  }),
                  fontSize,
                ),
              ),
            ],
          ),
          if (_isEnrolledInMasters == true) ...[
            const SizedBox(height: 16),
            _buildModernDropdown(
              label: 'Master\'s Program',
              value: _selectedMastersProgram,
              items: _mastersPrograms,
              onChanged: (v) => setState(() => _selectedMastersProgram = v ?? ''),
              fontSize: fontSize,
              isRequired: true,
            ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LRN required for deduplication',
                    style: TextStyle(
                      fontSize: fontSize * 0.85,
                      color: Colors.blue[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _lrnController,
            label: 'LRN (Learner Reference Number)',
            hint: 'Enter 12-digit LRN',
            icon: Icons.badge_outlined,
            isRequired: true,
            keyboardType: TextInputType.number,
            maxLength: 12,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _buildModernDropdown(
            label: '1st Choice Program',
            value: _firstChoiceProgram,
            items: allPrograms,
            onChanged: (v) => setState(() => _firstChoiceProgram = v ?? ''),
            fontSize: fontSize,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildModernDropdown(
            label: '2nd Choice Program',
            value: _secondChoiceProgram,
            items: allPrograms.where((p) => p != _firstChoiceProgram).toList(),
            onChanged: (v) => setState(() => _secondChoiceProgram = v ?? ''),
            fontSize: fontSize,
            isRequired: true,
          ),
          const SizedBox(height: 20),
          Text(
            'Do you have a scholarship?',
            style: TextStyle(
              fontSize: fontSize * 0.95,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildChoiceButton(
                  'Yes',
                  _hasScholarshipFreshman == true,
                  () => setState(() {
                    _hasScholarshipFreshman = true;
                    _selectedScholarship = null;
                  }),
                  fontSize,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChoiceButton(
                  'No',
                  _hasScholarshipFreshman == false,
                  () => setState(() {
                    _hasScholarshipFreshman = false;
                    _selectedScholarship = null;
                    _customScholarshipController.clear();
                  }),
                  fontSize,
                ),
              ),
            ],
          ),
          if (_hasScholarshipFreshman == true) ...[
            const SizedBox(height: 16),
            _buildModernDropdown(
              label: 'Scholarship',
              value: _selectedScholarship,
              items: _scholarships,
              onChanged: (v) => setState(() {
                _selectedScholarship = v;
                if (v != 'Others') {
                  _customScholarshipController.clear();
                }
              }),
              fontSize: fontSize,
              isRequired: true,
              hint: 'Select a scholarship',
            ),
            if (_selectedScholarship == 'Others') ...[
              const SizedBox(height: 16),
              _buildModernTextField(
                controller: _customScholarshipController,
                label: 'Custom Scholarship Name',
                hint: 'Enter scholarship name',
                icon: Icons.edit_outlined,
                isRequired: true,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ],
      );

    case 'Master\'s Applicant':
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModernDropdown(
            label: 'Intended Master\'s Program',
            value: _intendedMastersProgram,
            items: _mastersPrograms,
            onChanged: (v) => setState(() => _intendedMastersProgram = v ?? ''),
            fontSize: fontSize,
            isRequired: true,
          ),
        ],
      );

    case 'Other (Non-student)':
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModernDropdown(
            label: 'Relationship with CMU',
            value: _selectedAffiliation,
            items: _otherAffiliations,
            onChanged: (v) => setState(() {
              _selectedAffiliation = v;
              _hasConfirmedCustomAffiliation = false;
              _customAffiliationController.clear();
            }),
            fontSize: fontSize,
            isRequired: true,
          ),
          if (_selectedAffiliation == 'Others') ...[
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _customAffiliationController,
              label: 'Specify Affiliation',
              hint: 'Enter your affiliation',
              icon: Icons.edit_outlined,
              isRequired: true,
              onChanged: (_) => setState(() {
                _hasConfirmedCustomAffiliation = false;
              }),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _customAffiliationController.text.trim().length >= 3
                  ? () => setState(() => _hasConfirmedCustomAffiliation = true)
                  : null,
              icon: Icon(
                _hasConfirmedCustomAffiliation ? Icons.check_circle : Icons.check,
                size: 20,
              ),
              label: Text(
                _hasConfirmedCustomAffiliation 
                    ? 'Confirmed ✓' 
                    : 'Confirm Affiliation',
                style: TextStyle(
                  fontSize: fontSize * 0.9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasConfirmedCustomAffiliation 
                    ? primaryColor 
                    : primaryColor.withOpacity(0.8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      );

    default:
      return const SizedBox();
  }
}

Widget _buildModernTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  bool isRequired = false,
  TextInputType? keyboardType,
  int? maxLength,
  Function(String)? onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          if (isRequired)
            Text(
              ' *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: textSecondaryColor.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, color: primaryColor, size: 22),
            suffixIcon: controller.text.isNotEmpty
                ? Icon(Icons.check_circle, color: primaryColor, size: 20)
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildModernDropdown({
  required String label,
  required String? value,
  required List<String> items,
  required ValueChanged<String?> onChanged,
  required double fontSize,
  bool isRequired = false,
  String? hint,
}) {
  final safeValue = value != null && value.isNotEmpty && items.contains(value) ? value : null;
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          if (isRequired)
            Text(
              ' *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DropdownButtonFormField<String>(
          value: safeValue,
          hint: Text(
            hint ?? 'Select an option',
            style: TextStyle(
              color: textSecondaryColor.withOpacity(0.5),
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.arrow_drop_down_circle_outlined,
              color: primaryColor,
              size: 22,
            ),
            suffixIcon: safeValue != null
                ? Icon(Icons.check_circle, color: primaryColor, size: 20)
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              alignment: AlignmentDirectional.center,
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
          menuMaxHeight: 300,
          selectedItemBuilder: (context) {
            return items.map((item) {
              return Center(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }).toList();
          },
        ),
      ),
    ],
  );
}

InputDecoration _inputDecoration(String label, String hint, IconData icon) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      color: textPrimaryColor,
      fontWeight: FontWeight.w600,
    ),
    hintText: hint,
    hintStyle: TextStyle(
      color: textSecondaryColor.withOpacity(0.5),
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: Icon(icon, color: primaryColor, size: 22),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
  );
}

Widget _buildChoiceButton(String text, bool isSelected, VoidCallback onTap, double fontSize) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withOpacity(0.1) : Colors.white,
        border: Border.all(
          color: isSelected ? primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isSelected)
            Icon(Icons.check_circle, color: primaryColor, size: 20),
          if (isSelected) const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize * 0.95,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? primaryColor : textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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