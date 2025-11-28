import 'dart:async';

import 'package:capstone_project/responsive/user_constant.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/pages/user_pages/user_main_page.dart';
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

class _UserOnboardingScreenState extends State<UserOnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentPage = 0;

  // Color scheme
  static const Color primaryColor = Color.fromARGB(255, 8, 121, 11);
  static const Color backgroundColor = Colors.white;
  static final Color textPrimaryColor = Colors.grey[800]!;
  static final Color textSecondaryColor = Colors.grey[600]!;

  // Form controllers
  final _nameController = TextEditingController();

  // User profile data
  String? _role;
  String? _enrollmentStatus;

  // For enrolled students
  String _studentId = '';
  bool _studentIdConfirmed = false;
  String _selectedYear = '';
  String _selectedDepartment = '';
  String _selectedCollege = '';
  String? _selectedCollegeId;
  String _selectedProgram = '';
  bool? _hasScholarship;
  String? _selectedScholarship;

  // For not enrolled students
  bool? _isIncomingFreshman;
  String _lrn = '';
  bool _lrnConfirmed = false;
  String? _selectedAffiliation;
  bool _isLoading = false;

  // Add to state variables section
  String? _studentIdError;
  String? _lrnError;
  Timer? _studentIdErrorTimer;
  Timer? _lrnErrorTimer;

  // Data lists from Firestore
  Map<String, String> _colleges = {}; // college name → college ID
Map<String, List<String>> _programsByCollege = {};
  List<String> _scholarships = [];

  final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // For undergraduate/graduate flow
  String? _studentType; // 'undergraduate' or 'graduate'
  String? _graduateType; // 'masteral' or 'not_masteral'
  String _graduatedCollege = '';
  String? _graduatedCollegeId;
  String _graduatedProgram = '';

  // For custom affiliation
  String _customAffiliation = '';
  bool _customAffiliationConfirmed = false;

  // Update affiliations list to include "Others"
  final List<String> _affiliations = [
    'Parent',
    'Faculty',
    'CMU Staff',
    'Others',
  ];

  final List<UserOnboardingPage> _pages = [
    UserOnboardingPage(
      icon: Icons.waving_hand,
      title: "Welcome!",
      description:
          "Great to have you here! Let's get you started with OASP Assist and make your academic journey smoother.",
      color: primaryColor,
      type: UserOnboardingType.welcome,
    ),
    UserOnboardingPage(
      icon: Icons.person_outline,
      title: "Tell us about yourself",
      description:
          "Help us personalize your experience by sharing some information about your academic background.",
      color: primaryColor,
      type: UserOnboardingType.profile,
    ),
    UserOnboardingPage(
      icon: Icons.star,
      title: "Discover Features",
      description:
          "Explore what OASP Assist can do for you - from AI chat assistance to real-time announcements.",
      color: primaryColor,
      type: UserOnboardingType.features,
    ),
    UserOnboardingPage(
      icon: Icons.check_circle_outline,
      title: "You're All Set!",
      description:
          "Perfect! You're ready to explore OASP Assist. Let's start with a conversation with our AI assistant.",
      color: primaryColor,
      type: UserOnboardingType.complete,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
    _loadUserRole();
    _loadDropdownData();
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

    // Load programs with college references AND category (case-sensitive)
    final programsSnapshot =
        await FirebaseFirestore.instance.collection('programs').get();
    Map<String, List<String>> programsByCollegeMap = {};
    for (var doc in programsSnapshot.docs) {
      final programName = doc.data()['name']?.toString().trim();
      final collegeId = doc.data()['collegeId']?.toString();
      final category = doc.data()['category']?.toString(); // Keep original case

      if (programName != null &&
          programName.isNotEmpty &&
          collegeId != null &&
          category != null) {
        // Create key with exact category match: "Bachelor" or "Masters"
        final key = '${collegeId}_$category';
        
        if (!programsByCollegeMap.containsKey(key)) {
          programsByCollegeMap[key] = [];
        }
        programsByCollegeMap[key]!.add(programName);
      }
    }

    // Load scholarships
    final scholarshipsSnapshot =
        await FirebaseFirestore.instance.collection('scholarships').get();
    List<String> scholarshipsList =
        scholarshipsSnapshot.docs
            .map((doc) {
              final name = doc.data()['name'];
              return name?.toString().trim() ?? '';
            })
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();

    setState(() {
      _colleges = collegesMap;
      _programsByCollege = programsByCollegeMap;
      _scholarships = [...scholarshipsList, 'Others'];
    });
  } catch (e) {
    print('Error loading dropdown data: $e');
  }
}

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nameController.dispose();
    _studentIdErrorTimer?.cancel();
    _lrnErrorTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _role = data?['role'] ?? 'user';
          if (data?['name'] != null && data!['name'].toString().isNotEmpty) {
            _nameController.text = data['name'];
          }
        });
      }
    }
  }

  

  Future<List<String>> _getDropdownItems(String collection) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection(collection).get();
      // Filter out empty or null values and ensure uniqueness
      return snapshot.docs
          .map((doc) {
            final name = doc.data()['name'];
            return name?.toString().trim() ?? '';
          })
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
    } catch (e) {
      print('Error getting dropdown items from $collection: $e');
      return [];
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  // Also update _previousPage() to remove _showSummary:

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _finishOnboarding() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User session expired');
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => WillPopScope(
              onWillPop: () async => false,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ),
      );

      await _saveUserProfile();
      await Future.delayed(const Duration(milliseconds: 800));

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists || doc.data()?['onboardingCompleted'] != true) {
        throw Exception('Failed to verify onboarding completion');
      }

      // ✅ NEW: Mark user onboarding as completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_onboarding_completed_${user.uid}', true);

      // ✅ NEW: Mark that OnboardingGuide should be shown on next app open
      await prefs.setBool('should_show_guide', true);

      String? newConversationId;
      try {
        newConversationId = await UserConstant.createNewConversation(user.uid);
        print(
          '✅ Created initial conversation after onboarding: $newConversationId',
        );
      } catch (e) {
        print('⚠️ Could not create conversation: $e');
      }

      if (mounted) Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        // ✅ Navigate with flag to trigger guide
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (context) => UserMainPage(
                  initialTabIndex: 1,
                  conversationId: newConversationId,
                  shouldShowGuide: true, // ✅ NEW PARAMETER
                ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Failed to complete onboarding',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please check your connection and try again',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _finishOnboarding,
            ),
          ),
        );
      }
    }
  }

  void _setStudentIdError(String error) {
    _studentIdErrorTimer?.cancel();
    setState(() => _studentIdError = error);
    _studentIdErrorTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _studentIdError = null);
      }
    });
  }

  void _setLrnError(String error) {
    _lrnErrorTimer?.cancel();
    setState(() => _lrnError = error);
    _lrnErrorTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _lrnError = null);
      }
    });
  }

  // Build error text widget (similar to login page)
  Widget _buildInlineError(String? error, double fontSize) {
    if (error == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(left: 12, top: 8, right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red[400]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[400]!.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: fontSize * 0.8,
                fontWeight: FontWeight.w500,
                color: Colors.red[400],
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (error == _studentIdError) {
                _studentIdErrorTimer?.cancel();
                setState(() => _studentIdError = null);
              } else if (error == _lrnError) {
                _lrnErrorTimer?.cancel();
                setState(() => _lrnError = null);
              }
            },
            child: Icon(
              Icons.close,
              color: Colors.red[400]!.withOpacity(0.7),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

Future<void> _saveUserProfile() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

    Map<String, dynamic> updateData = {
      'name': fullName.trim(),
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'profileCompleted': true,
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (_role == 'user') {
      updateData['isEnrolled'] = _enrollmentStatus == 'enrolled';

      if (_enrollmentStatus == 'not_enrolled') {
        if (_isIncomingFreshman == true) {
          updateData.addAll({
            'affiliation': 'Incoming Freshman Applicant',
            'lrn': _lrn,
            'year': null,
            'college': null,
            'program': null,
            'scholarship': null,
            'studentId': null,
            'studentType': null,
            'graduateType': null,
            'graduatedCollege': null,
            'graduatedProgram': null,
          });
        } else {
          final affiliation = _selectedAffiliation == 'Others' 
              ? _customAffiliation 
              : _selectedAffiliation ?? '';
              
          updateData.addAll({
            'affiliation': affiliation,
            'lrn': null,
            'year': null,
            'college': null,
            'program': null,
            'scholarship': null,
            'studentId': null,
            'studentType': null,
            'graduateType': null,
            'graduatedCollege': null,
            'graduatedProgram': null,
          });
        }
      } else {
        // ENROLLED
        updateData['studentType'] = _studentType;
        updateData['affiliation'] = 'CMU Student';
        updateData['lrn'] = null;

        if (_studentType == 'undergraduate') {
          // Undergraduate HAS Student ID
          updateData.addAll({
            'studentId': _studentId,
            'year': _selectedYear,
            'college': _selectedCollege,
            'program': _selectedYear == 'Incoming' ? null : _selectedProgram,
            'scholarship': _hasScholarship == true ? _selectedScholarship : null,
            'graduateType': null,
            'graduatedCollege': null,
            'graduatedProgram': null,
          });
        } else if (_studentType == 'graduate') {
          // Graduate does NOT have Student ID
          updateData['graduateType'] = _graduateType;
          updateData['studentId'] = null; // No Student ID for graduates
          
          if (_graduateType == 'masteral') {
            updateData.addAll({
              'college': _selectedCollege,
              'program': _selectedProgram,
              'year': 'Graduate',
              'scholarship': null,
              'graduatedCollege': null,
              'graduatedProgram': null,
            });
          } else {
            updateData.addAll({
              'graduatedCollege': _graduatedCollege,
              'graduatedProgram': _graduatedProgram,
              'college': null,
              'program': null,
              'year': null,
              'scholarship': null,
            });
          }
        }
      }
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(updateData, SetOptions(merge: true));

    final verifyDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!verifyDoc.exists ||
        verifyDoc.data()?['onboardingCompleted'] != true) {
      throw Exception('Firestore write verification failed');
    }
  } catch (e) {
    rethrow;
  }
}

  Future<bool> _isStudentIdTaken(String studentId) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('studentId', isEqualTo: studentId.trim())
              .limit(1)
              .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking student ID: $e');
      return false;
    }
  }

  // Validate if LRN already exists
  Future<bool> _isLrnTaken(String lrn) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('lrn', isEqualTo: lrn.trim())
              .limit(1)
              .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking LRN: $e');
      return false;
    }
  }

 bool _canProceed() {
  switch (_pages[_currentPage].type) {
    case UserOnboardingType.welcome:
      return _firstNameController.text.trim().isNotEmpty &&
          _lastNameController.text.trim().isNotEmpty;

    case UserOnboardingType.profile:
      if (_role == 'user') {
        if (_enrollmentStatus == null) return false;

        if (_enrollmentStatus == 'not_enrolled') {
          if (_isIncomingFreshman == null) return false;

          if (_isIncomingFreshman == true) {
            return _lrn.trim().length == 12 && _lrnConfirmed;
          } else {
            if (_selectedAffiliation == 'Others') {
              return _customAffiliation.trim().isNotEmpty && 
                     _customAffiliationConfirmed;
            }
            return _selectedAffiliation != null &&
                _selectedAffiliation!.isNotEmpty;
          }
        } else {
          // ENROLLED checks
          if (_studentType == null) return false;

          if (_studentType == 'undergraduate') {
            // Undergraduate needs Student ID
            if (_studentId.trim().length < 5 || !_studentIdConfirmed) return false;
            if (_selectedYear.isEmpty) return false;
            if (_selectedCollege.isEmpty) return false;
            if (_selectedYear != 'Incoming' && _selectedProgram.isEmpty) return false;
            if (_hasScholarship == null) return false;
            if (_hasScholarship == true &&
                (_selectedScholarship == null ||
                    _selectedScholarship == 'N/A' ||
                    _selectedScholarship!.isEmpty)) {
              return false;
            }
            return true;
          } else if (_studentType == 'graduate') {
            // Graduate does NOT need Student ID
            if (_graduateType == null) return false;
            
            if (_graduateType == 'masteral') {
              if (_selectedCollege.isEmpty) return false;
              if (_selectedProgram.isEmpty) return false;
              return true;
            } else {
              if (_graduatedCollege.isEmpty) return false;
              if (_graduatedProgram.isEmpty) return false;
              return true;
            }
          }
        }
      }
      return true;

    default:
      return true;
  }
}

  Widget _buildContent({
    required double maxWidth,
    required double horizontalPadding,
    required double iconSize,
    required double titleFontSize,
    required double descriptionFontSize,
    required double buttonHeight,
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          children: [
            // Header with Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'OASP Assist',
                        style: TextStyle(
                          fontSize: titleFontSize * 0.6,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Step ${_currentPage + 1} of ${_pages.length}',
                        style: TextStyle(
                          fontSize: descriptionFontSize * 0.85,
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
                      value: (_currentPage + 1) / _pages.length,
                      backgroundColor: primaryColor.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        primaryColor,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // Page Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(
                    _pages[index],
                    iconSize,
                    titleFontSize,
                    descriptionFontSize,
                    maxWidth,
                  );
                },
              ),
            ),

            // Navigation Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              _currentPage == index
                                  ? primaryColor
                                  : primaryColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Navigation Buttons
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: const BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: buttonHeight,
                              ),
                            ),
                            child: Text(
                              'Back',
                              style: TextStyle(
                                fontSize: descriptionFontSize * 0.9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          onPressed: _canProceed() ? _nextPage : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: backgroundColor,
                            disabledBackgroundColor: Colors.grey[300],
                            elevation: 2,
                            shadowColor: primaryColor.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: buttonHeight,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1
                                    ? 'Start Chatting!'
                                    : 'Continue',
                                style: TextStyle(
                                  fontSize: descriptionFontSize * 0.9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _currentPage == _pages.length - 1
                                    ? Icons.chat_bubble_outline
                                    : Icons.arrow_forward_rounded,
                                size: descriptionFontSize,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(
    UserOnboardingPage page,
    double iconSize,
    double titleFontSize,
    double descriptionFontSize,
    double maxWidth,
  ) {
    switch (page.type) {
      case UserOnboardingType.welcome:
        return _buildWelcomePage(
          page,
          iconSize,
          titleFontSize,
          descriptionFontSize,
        );
      case UserOnboardingType.profile:
        return _buildProfilePage(
          page,
          iconSize,
          titleFontSize,
          descriptionFontSize,
          maxWidth,
        );
      case UserOnboardingType.features:
        return _buildFeaturesPage(
          page,
          iconSize,
          titleFontSize,
          descriptionFontSize,
        );
      case UserOnboardingType.complete:
        return _buildCompletePage(
          page,
          iconSize,
          titleFontSize,
          descriptionFontSize,
        );
    }
  }

  Widget _buildWelcomePage(
    UserOnboardingPage page,
    double iconSize,
    double titleFontSize,
    double descriptionFontSize,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: iconSize * 1.2,
            height: iconSize * 1.2,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: iconSize * 0.85,
                height: iconSize * 0.85,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  page.icon,
                  size: iconSize * 0.4,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            page.title,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w800,
              color: textPrimaryColor,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: TextStyle(
              fontSize: descriptionFontSize,
              color: textSecondaryColor,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // First Name Field
          TextFormField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: 'First Name',
              hintText: 'Enter your first name',
              labelStyle: TextStyle(
                color: primaryColor,
                fontSize: descriptionFontSize * 0.9,
              ),
              hintStyle: TextStyle(
                color: textSecondaryColor.withOpacity(0.6),
                fontSize: descriptionFontSize * 0.85,
              ),
              prefixIcon: const Icon(Icons.person_outline, color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: TextStyle(
              fontSize: descriptionFontSize,
              fontWeight: FontWeight.w500,
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Last Name Field
          TextFormField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: 'Last Name',
              hintText: 'Enter your last name',
              labelStyle: TextStyle(
                color: primaryColor,
                fontSize: descriptionFontSize * 0.9,
              ),
              hintStyle: TextStyle(
                color: textSecondaryColor.withOpacity(0.6),
                fontSize: descriptionFontSize * 0.85,
              ),
              prefixIcon: const Icon(Icons.person_outline, color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: TextStyle(
              fontSize: descriptionFontSize,
              fontWeight: FontWeight.w500,
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Replace the _buildProfilePage method with this version that auto-shows summary:
  Widget _buildProfilePage(
    UserOnboardingPage page,
    double iconSize,
    double titleFontSize,
    double descriptionFontSize,
    double maxWidth,
  ) {
    // Check if all required fields are completed for summary
    bool allFieldsCompleted = false;

    if (_role == 'user' && _enrollmentStatus != null) {
      if (_enrollmentStatus == 'not_enrolled') {
        if (_isIncomingFreshman == true) {
          allFieldsCompleted = _lrn.trim().length == 12 && _lrnConfirmed;
        } else if (_isIncomingFreshman == false) {
          if (_selectedAffiliation == 'Others') {
            allFieldsCompleted =
                _customAffiliation.trim().isNotEmpty &&
                _customAffiliationConfirmed;
          } else {
            allFieldsCompleted =
                _selectedAffiliation != null &&
                _selectedAffiliation!.isNotEmpty;
          }
        }
      } else {
        // ENROLLED checks
        bool studentIdComplete =
            _studentId.trim().isNotEmpty && _studentIdConfirmed;
        bool studentTypeComplete = _studentType != null;

        if (_studentType == 'undergraduate') {
          bool yearComplete = _selectedYear.isNotEmpty;
          bool collegeComplete = _selectedCollege.isNotEmpty;
          bool programComplete =
              (_selectedYear == 'Incoming') || _selectedProgram.isNotEmpty;
          bool scholarshipComplete =
              _hasScholarship != null &&
              (_hasScholarship == false ||
                  (_hasScholarship == true &&
                      _selectedScholarship != null &&
                      _selectedScholarship != 'N/A' &&
                      _selectedScholarship!.isNotEmpty));

          allFieldsCompleted =
              studentIdComplete &&
              studentTypeComplete &&
              yearComplete &&
              collegeComplete &&
              programComplete &&
              scholarshipComplete;
        } else if (_studentType == 'graduate') {
          bool graduateTypeComplete = _graduateType != null;

          if (_graduateType == 'masteral') {
            allFieldsCompleted =
                studentIdComplete &&
                studentTypeComplete &&
                graduateTypeComplete &&
                _selectedCollege.isNotEmpty &&
                _selectedProgram.isNotEmpty;
          } else if (_graduateType == 'not_masteral') {
            allFieldsCompleted =
                studentIdComplete &&
                studentTypeComplete &&
                graduateTypeComplete &&
                _graduatedCollege.isNotEmpty &&
                _graduatedProgram.isNotEmpty;
          }
        }
      }
    }

    // Show summary when complete
    if (allFieldsCompleted) {
      return _buildProfileSummary(descriptionFontSize);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: iconSize * 0.9,
            height: iconSize * 0.9,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: iconSize * 0.4, color: primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Hello ${_firstNameController.text.isNotEmpty ? _firstNameController.text : 'there'}!',
            style: TextStyle(
              fontSize: titleFontSize * 0.8,
              fontWeight: FontWeight.w800,
              color: textPrimaryColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            page.title,
            style: TextStyle(
              fontSize: titleFontSize * 0.7,
              fontWeight: FontWeight.w700,
              color: textPrimaryColor,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            page.description,
            style: TextStyle(
              fontSize: descriptionFontSize * 0.9,
              color: textSecondaryColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (_role == 'user') ...[
            // Step 1: Enrollment Status
            if (_enrollmentStatus == null) ...[
              _buildSectionTitle(
                'Are you currently enrolled?',
                descriptionFontSize,
              ),
              const SizedBox(height: 12),
              _buildRadioOption(
                title: 'Yes, I am enrolled',
                value: 'enrolled',
                groupValue: _enrollmentStatus,
                onChanged:
                    (value) => setState(() {
                      _enrollmentStatus = value;
                      _resetAllFields();
                    }),
                fontSize: descriptionFontSize,
              ),
              const SizedBox(height: 12),
              _buildRadioOption(
                title: 'No, not yet enrolled',
                value: 'not_enrolled',
                groupValue: _enrollmentStatus,
                onChanged:
                    (value) => setState(() {
                      _enrollmentStatus = value;
                      _resetEnrolledFields();
                    }),
                fontSize: descriptionFontSize,
              ),
            ]
            // === ENROLLED FLOW ===
            else if (_enrollmentStatus == 'enrolled') ...[
              // Ask undergraduate or graduate FIRST
              if (_studentType == null) ...[
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'Are you an undergraduate or graduate student?',
                  descriptionFontSize,
                ),
                const SizedBox(height: 12),
                _buildRadioOption(
                  title: 'Undergraduate',
                  value: 'undergraduate',
                  groupValue: _studentType,
                  onChanged:
                      (value) => setState(() {
                        _studentType = value;
                        _resetEnrolledFields();
                      }),
                  fontSize: descriptionFontSize,
                ),
                const SizedBox(height: 12),
                _buildRadioOption(
                  title: 'Graduate',
                  value: 'graduate',
                  groupValue: _studentType,
                  onChanged:
                      (value) => setState(() {
                        _studentType = value;
                        _resetEnrolledFields();
                      }),
                  fontSize: descriptionFontSize,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _enrollmentStatus = null;
                          _studentType = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(
                        'Previous',
                        style: TextStyle(fontSize: descriptionFontSize * 0.85),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ]
              // Continue with Student ID and rest of flow...
              else
                ..._buildEnrolledFlow(descriptionFontSize),
            ]
            // === NOT ENROLLED FLOW ===
            else if (_enrollmentStatus == 'not_enrolled') ...[
              ..._buildNotEnrolledFlow(descriptionFontSize),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _resetEnrolledFields() {
    _studentId = '';
    _studentIdConfirmed = false;
    _selectedYear = '';
    _selectedDepartment = '';
    _selectedCollege = '';
    _selectedCollegeId = null;
    _selectedProgram = '';
    _hasScholarship = null;
    _selectedScholarship = null;
    _graduateType = null;
    _graduatedCollege = '';
    _graduatedCollegeId = null;
    _graduatedProgram = '';
  }

  void _resetAllFields() {
    _studentId = '';
    _studentIdConfirmed = false;
    _studentType = null;
    _selectedYear = '';
    _selectedDepartment = '';
    _selectedCollege = '';
    _selectedCollegeId = null;
    _selectedProgram = '';
    _hasScholarship = null;
    _selectedScholarship = null;
    _graduateType = null;
    _graduatedCollege = '';
    _graduatedCollegeId = null;
    _graduatedProgram = '';
    _isIncomingFreshman = null;
    _lrn = '';
    _lrnConfirmed = false;
    _selectedAffiliation = null;
    _customAffiliation = '';
    _customAffiliationConfirmed = false;
  }

  List<Widget> _buildEnrolledFlow(double descriptionFontSize) {
  // UNDERGRADUATE: Needs Student ID first
  if (_studentType == 'undergraduate') {
    if (_studentId.trim().length < 5 || !_studentIdConfirmed) {
      return [
        const SizedBox(height: 24),
        // Add authenticator message
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'To prove you are a student of CMU, please enter your Student ID',
                  style: TextStyle(
                    fontSize: descriptionFontSize * 0.85,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('Enter your Student ID', descriptionFontSize),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _studentId,
          decoration: InputDecoration(
            labelText: 'Student ID',
            hintText: 'Enter your student ID (minimum 5 characters)',
            labelStyle: TextStyle(
              color: primaryColor,
              fontSize: descriptionFontSize * 0.9,
            ),
            hintStyle: TextStyle(
              color: textSecondaryColor.withOpacity(0.6),
              fontSize: descriptionFontSize * 0.85,
            ),
            prefixIcon: const Icon(Icons.badge_outlined, color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: TextStyle(
            fontSize: descriptionFontSize,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (value) {
            setState(() {
              _studentId = value;
              _studentIdConfirmed = false;
              _studentIdError = null;
              _studentIdErrorTimer?.cancel();
            });
          },
        ),
        if (_studentId.isNotEmpty && _studentId.trim().length < 5) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'Student ID must be at least 5 characters',
              style: TextStyle(
                fontSize: descriptionFontSize * 0.8,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
        _buildInlineError(_studentIdError, descriptionFontSize),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _studentId.trim().length >= 5 ? () async {
              _studentIdErrorTimer?.cancel();
              setState(() => _studentIdError = null);
              setState(() => _isLoading = true);

              final isTaken = await _isStudentIdTaken(_studentId);
              setState(() => _isLoading = false);

              if (isTaken) {
                _setStudentIdError(
                  'This Student ID is already registered. Please check your ID or contact support.',
                );
              } else {
                setState(() {
                  _studentIdConfirmed = true;
                });
              }
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: backgroundColor,
              disabledBackgroundColor: Colors.grey[300],
              elevation: 2,
              shadowColor: primaryColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.0,
                    ),
                  )
                : Text(
                    'Confirm Student ID',
                    style: TextStyle(
                      fontSize: descriptionFontSize * 0.9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _studentType = null;
                  _studentId = '';
                  _studentIdConfirmed = false;
                  _studentIdError = null;
                  _studentIdErrorTimer?.cancel();
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                'Previous',
                style: TextStyle(fontSize: descriptionFontSize * 0.85),
              ),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ];
    }
    // Continue with undergraduate flow
    return _buildUndergraduateFlow(descriptionFontSize);
  }
  
  // GRADUATE: Skip Student ID, go directly to graduate flow
  if (_studentType == 'graduate') {
    return _buildGraduateFlow(descriptionFontSize);
  }

  return [];
}

 List<Widget> _buildUndergraduateFlow(double descriptionFontSize) {
  // Year, College, Program (Bachelor category), Scholarship
  if (_selectedYear.isEmpty ||
      _selectedCollege.isEmpty ||
      (_selectedYear != 'Incoming' && _selectedProgram.isEmpty)) {
    return [
      const SizedBox(height: 24),
      _buildSectionTitle('What year are you in?', descriptionFontSize),
      const SizedBox(height: 12),
      _buildDropdownField(
        value: _selectedYear.isEmpty || !years.contains(_selectedYear)
            ? null
            : _selectedYear,
        items: years.toSet().toList(),
        onChanged: (value) => setState(() {
          _selectedYear = value ?? '';
          if (value == 'Incoming') {
            _selectedProgram = 'N/A';
          } else {
            _selectedProgram = '';
          }
        }),
        hint: 'Select your year level',
        icon: Icons.school_outlined,
        fontSize: descriptionFontSize,
      ),
      if (_selectedYear.isNotEmpty) ...[
        const SizedBox(height: 24),
        _buildSectionTitle('Select your College', descriptionFontSize),
        const SizedBox(height: 12),
        _buildDropdownField(
          value: _selectedCollege.isEmpty ||
                  !_colleges.keys.contains(_selectedCollege)
              ? null
              : _selectedCollege,
          items: _colleges.keys.toList(),
          onChanged: (value) {
            setState(() {
              _selectedCollege = value ?? '';
              _selectedCollegeId = _colleges[value];
              _selectedProgram = '';
            });
          },
          hint: 'Select your college',
          icon: Icons.account_balance_outlined,
          fontSize: descriptionFontSize,
        ),
      ],
      if (_selectedCollege.isNotEmpty && _selectedYear != 'Incoming') ...[
        const SizedBox(height: 24),
        _buildSectionTitle('Select your Program', descriptionFontSize),
        const SizedBox(height: 12),
        () {
          // Get Bachelor programs only (exact case match)
          final key = '${_selectedCollegeId}_Bachelor';
          final availablePrograms =
              _programsByCollege.containsKey(key)
                  ? _programsByCollege[key]!
                  : <String>[];

          return _buildDropdownField(
            value: _selectedProgram.isEmpty ||
                    !availablePrograms.contains(_selectedProgram)
                ? null
                : _selectedProgram,
            items: availablePrograms,
            onChanged: (value) =>
                setState(() => _selectedProgram = value ?? ''),
            hint: availablePrograms.isEmpty
                ? 'No bachelor programs available'
                : 'Select your program',
            icon: Icons.book_outlined,
            fontSize: descriptionFontSize,
          );
        }(),
      ],
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedYear = '';
                _selectedCollege = '';
                _selectedCollegeId = null;
                _selectedProgram = '';
                _studentIdConfirmed = false;
                _studentId = '';
              });
            },
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(
              'Previous',
              style: TextStyle(fontSize: descriptionFontSize * 0.85),
            ),
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  // Scholarship question
  if (_hasScholarship == null ||
      (_hasScholarship == true &&
          (_selectedScholarship == null ||
              _selectedScholarship!.isEmpty ||
              _selectedScholarship == 'N/A'))) {
    return [
      const SizedBox(height: 24),
      _buildYesNoSection(
        title: 'Do you have any scholarship?',
        value: _hasScholarship,
        onChanged: (value) {
          setState(() {
            _hasScholarship = value;
            if (!value) {
              _selectedScholarship = 'N/A';
            } else {
              _selectedScholarship = null;
            }
          });
        },
        dropdownValue: _hasScholarship == true ? _selectedScholarship : null,
        dropdownItems: _scholarships,
        dropdownHint: 'Select your scholarship',
        dropdownIcon: Icons.card_membership_outlined,
        onDropdownChanged: (value) => setState(() => _selectedScholarship = value),
        fontSize: descriptionFontSize,
        onPrevious: () {
          setState(() {
            _hasScholarship = null;
            _selectedScholarship = null;
            if (_selectedYear == 'Incoming') {
              _selectedCollege = '';
              _selectedCollegeId = null;
            } else {
              _selectedProgram = '';
            }
          });
        },
        isLast: true,
      ),
    ];
  }

  return [];
}

  List<Widget> _buildGraduateFlow(double descriptionFontSize) {
  // Ask if taking masteral
  if (_graduateType == null) {
    return [
      const SizedBox(height: 24),
      _buildSectionTitle(
        'Are you currently taking a masteral degree?',
        descriptionFontSize,
      ),
      const SizedBox(height: 12),
      _buildRadioOption(
        title: 'Yes, taking Masteral',
        value: 'masteral',
        groupValue: _graduateType,
        onChanged: (value) => setState(() {
          _graduateType = value;
          _selectedCollege = '';
          _selectedCollegeId = null;
          _selectedProgram = '';
          _graduatedCollege = '';
          _graduatedCollegeId = null;
          _graduatedProgram = '';
        }),
        fontSize: descriptionFontSize,
      ),
      const SizedBox(height: 12),
      _buildRadioOption(
        title: 'No, already graduated',
        value: 'not_masteral',
        groupValue: _graduateType,
        onChanged: (value) => setState(() {
          _graduateType = value;
          _selectedCollege = '';
          _selectedCollegeId = null;
          _selectedProgram = '';
          _graduatedCollege = '';
          _graduatedCollegeId = null;
          _graduatedProgram = '';
        }),
        fontSize: descriptionFontSize,
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _studentType = null;
                _graduateType = null;
              });
            },
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(
              'Previous',
              style: TextStyle(fontSize: descriptionFontSize * 0.85),
            ),
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  // If taking masteral - show Masters programs
  if (_graduateType == 'masteral') {
    if (_selectedCollege.isEmpty || _selectedProgram.isEmpty) {
      return [
        const SizedBox(height: 24),
        _buildSectionTitle('Select your College', descriptionFontSize),
        const SizedBox(height: 12),
        _buildDropdownField(
          value: _selectedCollege.isEmpty ||
                  !_colleges.keys.contains(_selectedCollege)
              ? null
              : _selectedCollege,
          items: _colleges.keys.toList(),
          onChanged: (value) {
            setState(() {
              _selectedCollege = value ?? '';
              _selectedCollegeId = _colleges[value];
              _selectedProgram = '';
            });
          },
          hint: 'Select your college',
          icon: Icons.account_balance_outlined,
          fontSize: descriptionFontSize,
        ),
        if (_selectedCollege.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionTitle('Select your Masteral Program', descriptionFontSize),
          const SizedBox(height: 12),
          () {
            // Get Masters programs only (exact case match)
            final key = '${_selectedCollegeId}_Masters';
            final availablePrograms =
                _programsByCollege.containsKey(key)
                    ? _programsByCollege[key]!
                    : <String>[];

            return _buildDropdownField(
              value: _selectedProgram.isEmpty ||
                      !availablePrograms.contains(_selectedProgram)
                  ? null
                  : _selectedProgram,
              items: availablePrograms,
              onChanged: (value) =>
                  setState(() => _selectedProgram = value ?? ''),
              hint: availablePrograms.isEmpty
                  ? 'No masteral programs available'
                  : 'Select your program',
              icon: Icons.book_outlined,
              fontSize: descriptionFontSize,
            );
          }(),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _graduateType = null;
                  _selectedCollege = '';
                  _selectedCollegeId = null;
                  _selectedProgram = '';
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                'Previous',
                style: TextStyle(fontSize: descriptionFontSize * 0.85),
              ),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ];
    }
  }

  // If not taking masteral (already graduated) - show Bachelor programs they graduated from
  if (_graduateType == 'not_masteral') {
    if (_graduatedCollege.isEmpty || _graduatedProgram.isEmpty) {
      return [
        const SizedBox(height: 24),
        _buildSectionTitle(
          'Which college did you graduate from?',
          descriptionFontSize,
        ),
        const SizedBox(height: 12),
        _buildDropdownField(
          value: _graduatedCollege.isEmpty ||
                  !_colleges.keys.contains(_graduatedCollege)
              ? null
              : _graduatedCollege,
          items: _colleges.keys.toList(),
          onChanged: (value) {
            setState(() {
              _graduatedCollege = value ?? '';
              _graduatedCollegeId = _colleges[value];
              _graduatedProgram = '';
            });
          },
          hint: 'Select your college',
          icon: Icons.account_balance_outlined,
          fontSize: descriptionFontSize,
        ),
        if (_graduatedCollege.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionTitle(
            'Which program did you graduate from?',
            descriptionFontSize,
          ),
          const SizedBox(height: 12),
          () {
            // Get Bachelor programs for graduated college
            final key = '${_graduatedCollegeId}_Bachelor';
            final availablePrograms =
                _programsByCollege.containsKey(key)
                    ? _programsByCollege[key]!
                    : <String>[];

            return _buildDropdownField(
              value: _graduatedProgram.isEmpty ||
                      !availablePrograms.contains(_graduatedProgram)
                  ? null
                  : _graduatedProgram,
              items: availablePrograms,
              onChanged: (value) =>
                  setState(() => _graduatedProgram = value ?? ''),
              hint: availablePrograms.isEmpty
                  ? 'No programs available'
                  : 'Select your program',
              icon: Icons.book_outlined,
              fontSize: descriptionFontSize,
            );
          }(),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _graduateType = null;
                  _graduatedCollege = '';
                  _graduatedCollegeId = null;
                  _graduatedProgram = '';
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                'Previous',
                style: TextStyle(fontSize: descriptionFontSize * 0.85),
              ),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
          ),
        
      ];
    }
  }

  return [];
}

  List<Widget> _buildNotEnrolledFlow(double descriptionFontSize) {
    // Ask if incoming freshman for CMUCAT
    if (_isIncomingFreshman == null) {
      return [
        const SizedBox(height: 24),
        _buildSectionTitle(
          'Are you an incoming freshman applicant for CMUCAT?',
          descriptionFontSize,
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          title: 'Yes',
          value: 'yes',
          groupValue:
              _isIncomingFreshman == null
                  ? null
                  : (_isIncomingFreshman! ? 'yes' : 'no'),
          onChanged:
              (value) => setState(() {
                _isIncomingFreshman = value == 'yes';
                if (_isIncomingFreshman!) {
                  _selectedAffiliation = null;
                  _customAffiliation = '';
                  _customAffiliationConfirmed = false;
                } else {
                  _lrn = '';
                  _lrnConfirmed = false;
                }
              }),
          fontSize: descriptionFontSize,
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          title: 'No',
          value: 'no',
          groupValue:
              _isIncomingFreshman == null
                  ? null
                  : (_isIncomingFreshman! ? 'yes' : 'no'),
          onChanged:
              (value) => setState(() {
                _isIncomingFreshman = value == 'yes';
                if (_isIncomingFreshman!) {
                  _selectedAffiliation = null;
                  _customAffiliation = '';
                  _customAffiliationConfirmed = false;
                } else {
                  _lrn = '';
                  _lrnConfirmed = false;
                }
              }),
          fontSize: descriptionFontSize,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _enrollmentStatus = null;
                  _isIncomingFreshman = null;
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                'Previous',
                style: TextStyle(fontSize: descriptionFontSize * 0.85),
              ),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ];
    } // If YES to incoming freshman - ask for LRN
    if (_isIncomingFreshman == true && !_lrnConfirmed) {
      return [
        const SizedBox(height: 24),
        // Add authenticator message
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enter your LRN to prove authenticity as an incoming freshman applicant',
                  style: TextStyle(
                    fontSize: descriptionFontSize * 0.85,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle(
          'Enter your Learner Reference Number (LRN)',
          descriptionFontSize,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _lrn,
          decoration: InputDecoration(
            labelText: 'LRN',
            hintText: 'Enter your 12-digit LRN',
            labelStyle: TextStyle(
              color: primaryColor,
              fontSize: descriptionFontSize * 0.9,
            ),
            hintStyle: TextStyle(
              color: textSecondaryColor.withOpacity(0.6),
              fontSize: descriptionFontSize * 0.85,
            ),
            prefixIcon: const Icon(Icons.badge_outlined, color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: TextStyle(
            fontSize: descriptionFontSize,
            fontWeight: FontWeight.w500,
          ),
          keyboardType: TextInputType.number,
          maxLength: 12,
          onChanged: (value) {
            setState(() {
              _lrn = value;
              _lrnConfirmed = false;
              _lrnError = null;
              _lrnErrorTimer?.cancel();
            });
          },
        ),
        if (_lrn.isNotEmpty && _lrn.trim().length < 12) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'LRN must be exactly 12 digits (${_lrn.trim().length}/12)',
              style: TextStyle(
                fontSize: descriptionFontSize * 0.8,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
        _buildInlineError(_lrnError, descriptionFontSize),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                _lrn.trim().length == 12
                    ? () async {
                      _lrnErrorTimer?.cancel();
                      setState(() => _lrnError = null);
                      setState(() => _isLoading = true);
                      final isTaken = await _isLrnTaken(_lrn);
                      setState(() => _isLoading = false);
                      if (isTaken) {
                        _setLrnError(
                          'This LRN is already registered. Please check your LRN or contact support.',
                        );
                      } else {
                        setState(() {
                          _lrnConfirmed = true;
                        });
                      }
                    }
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: backgroundColor,
              disabledBackgroundColor: Colors.grey[300],
              elevation: 2,
              shadowColor: primaryColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                    : Text(
                      'Confirm LRN',
                      style: TextStyle(
                        fontSize: descriptionFontSize * 0.9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isIncomingFreshman = null;
                  _lrn = '';
                  _lrnConfirmed = false;
                  _lrnError = null;
                  _lrnErrorTimer?.cancel();
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                'Previous',
                style: TextStyle(fontSize: descriptionFontSize * 0.85),
              ),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ];
    } // If NO to incoming freshman - ask for affiliation with "Others" option
    if (_isIncomingFreshman == false) {
      if (_selectedAffiliation == null || _selectedAffiliation!.isEmpty) {
        return [
          const SizedBox(height: 24),
          _buildSectionTitle(
            'How are you associated with the school?',
            descriptionFontSize,
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            value: _selectedAffiliation,
            items: _affiliations,
            onChanged: (value) {
              setState(() {
                _selectedAffiliation = value;
                if (value != 'Others') {
                  _customAffiliation = '';
                  _customAffiliationConfirmed = false;
                }
              });
            },
            hint: 'Select your association',
            icon: Icons.people_outline,
            fontSize: descriptionFontSize,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isIncomingFreshman = null;
                    _selectedAffiliation = null;
                    _customAffiliation = '';
                    _customAffiliationConfirmed = false;
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  'Previous',
                  style: TextStyle(fontSize: descriptionFontSize * 0.85),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ];
      } // If "Others" is selected, show custom input
      if (_selectedAffiliation == 'Others' && !_customAffiliationConfirmed) {
        return [
          const SizedBox(height: 24),
          _buildSectionTitle(
            'Please specify your association',
            descriptionFontSize,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _customAffiliation,
            decoration: InputDecoration(
              labelText: 'Your Association',
              hintText: 'Enter your association with CMU',
              labelStyle: TextStyle(
                color: primaryColor,
                fontSize: descriptionFontSize * 0.9,
              ),
              hintStyle: TextStyle(
                color: textSecondaryColor.withOpacity(0.6),
                fontSize: descriptionFontSize * 0.85,
              ),
              prefixIcon: const Icon(Icons.people_outline, color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: TextStyle(
              fontSize: descriptionFontSize,
              fontWeight: FontWeight.w500,
            ),
            onChanged: (value) {
              setState(() {
                _customAffiliation = value;
                _customAffiliationConfirmed = false;
              });
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _customAffiliation.trim().isNotEmpty
                      ? () {
                        setState(() {
                          _customAffiliationConfirmed = true;
                        });
                      }
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: backgroundColor,
                disabledBackgroundColor: Colors.grey[300],
                elevation: 2,
                shadowColor: primaryColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Confirm Association',
                style: TextStyle(
                  fontSize: descriptionFontSize * 0.9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedAffiliation = null;
                    _customAffiliation = '';
                    _customAffiliationConfirmed = false;
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  'Previous',
                  style: TextStyle(fontSize: descriptionFontSize * 0.85),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ];
      }
    }
    return [];
  }

  Widget _buildProfileSummary(double fontSize) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 40,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirm Your Information',
                  style: TextStyle(
                    fontSize: fontSize * 1.4,
                    fontWeight: FontWeight.w800,
                    color: textPrimaryColor,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please review your details before proceeding',
                  style: TextStyle(
                    fontSize: fontSize * 0.95,
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name - ALWAYS SHOW
                _buildSummaryItem(
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value:
                      '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
                  fontSize: fontSize,
                ),

                // NOT ENROLLED: Show affiliation and LRN (if incoming freshman)
                if (_enrollmentStatus == 'not_enrolled') ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildSummaryItem(
                    icon: Icons.people_outline,
                    label: 'Organizational Affiliation',
                    value:
                        _isIncomingFreshman == true
                            ? 'Incoming Freshman Applicant'
                            : (_selectedAffiliation == 'Others'
                                ? _customAffiliation
                                : _selectedAffiliation ?? 'None'),
                    fontSize: fontSize,
                  ),
                  if (_isIncomingFreshman == true) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _buildSummaryItem(
                      icon: Icons.badge_outlined,
                      label: 'LRN',
                      value: _lrn,
                      fontSize: fontSize,
                    ),
                  ],
                ],

                // ENROLLED: Show all details
                if (_enrollmentStatus == 'enrolled') ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildSummaryItem(
                    icon: Icons.people_outline,
                    label: 'Organizational Affiliation',
                    value: 'CMU Student',
                    fontSize: fontSize,
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildSummaryItem(
                    icon: Icons.badge_outlined,
                    label: 'Student ID',
                    value: _studentId,
                    fontSize: fontSize,
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildSummaryItem(
                    icon: Icons.school_outlined,
                    label: 'Student Type',
                    value:
                        _studentType == 'undergraduate'
                            ? 'Undergraduate'
                            : 'Graduate',
                    fontSize: fontSize,
                  ),

                  // UNDERGRADUATE DETAILS
                  if (_studentType == 'undergraduate') ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _buildSummaryItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Year Level',
                      value: _selectedYear,
                      fontSize: fontSize,
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _buildSummaryItem(
                      icon: Icons.account_balance_outlined,
                      label: 'College',
                      value: _selectedCollege,
                      fontSize: fontSize,
                    ),
                    if (_selectedYear != 'Incoming') ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _buildSummaryItem(
                        icon: Icons.book_outlined,
                        label: 'Program',
                        value: _selectedProgram,
                        fontSize: fontSize,
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _buildSummaryItem(
                      icon: Icons.card_membership_outlined,
                      label: 'Scholarship',
                      value:
                          _hasScholarship == true &&
                                  _selectedScholarship != 'N/A' &&
                                  _selectedScholarship != null
                              ? _selectedScholarship!
                              : 'None',
                      fontSize: fontSize,
                    ),
                  ],
                  // GRADUATE DETAILS
                  if (_studentType == 'graduate') ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _buildSummaryItem(
                      icon: Icons.school,
                      label: 'Graduate Status',
                      value:
                          _graduateType == 'masteral'
                              ? 'Taking Masteral'
                              : 'Already Graduated',
                      fontSize: fontSize,
                    ),
                    if (_graduateType == 'masteral') ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _buildSummaryItem(
                        icon: Icons.account_balance_outlined,
                        label: 'College',
                        value: _selectedCollege,
                        fontSize: fontSize,
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _buildSummaryItem(
                        icon: Icons.book_outlined,
                        label: 'Masteral Program',
                        value: _selectedProgram,
                        fontSize: fontSize,
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _buildSummaryItem(
                        icon: Icons.account_balance_outlined,
                        label: 'Graduated College',
                        value: _graduatedCollege,
                        fontSize: fontSize,
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _buildSummaryItem(
                        icon: Icons.book_outlined,
                        label: 'Graduated Program',
                        value: _graduatedProgram,
                        fontSize: fontSize,
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  if (_enrollmentStatus == 'not_enrolled') {
                    if (_isIncomingFreshman == true) {
                      _lrn = '';
                      _lrnConfirmed = false;
                    } else if (_selectedAffiliation == 'Others') {
                      _customAffiliation = '';
                      _customAffiliationConfirmed = false;
                    } else {
                      _selectedAffiliation = null;
                    }
                  } else {
                    // For enrolled, go back based on student type
                    if (_studentType == 'undergraduate') {
                      _hasScholarship = null;
                      _selectedScholarship = null;
                    } else if (_studentType == 'graduate') {
                      if (_graduateType == 'masteral') {
                        _selectedProgram = '';
                      } else {
                        _graduatedProgram = '';
                      }
                    }
                  }
                });
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'Edit Information',
                style: TextStyle(fontSize: fontSize * 0.9),
              ),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
    required IconData icon,
    required double fontSize,
  }) {
    final uniqueItems = items.toSet().toList();
    final validValue =
        (value != null && value.isNotEmpty && uniqueItems.contains(value))
            ? value
            : null;

    if (uniqueItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading options...',
              style: TextStyle(
                fontSize: fontSize * 0.85,
                color: textSecondaryColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: validValue,
      isExpanded: true,
      menuMaxHeight: 300, // Add max height for scrolling
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: fontSize * 0.85,
          color: textSecondaryColor.withOpacity(0.6),
        ),
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      style: TextStyle(fontSize: fontSize * 0.85, color: textPrimaryColor),
      items:
          uniqueItems.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize * 0.85),
              ),
            );
          }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildYesNoSection({
    required String title,
    required bool? value,
    required ValueChanged<bool> onChanged,
    String? dropdownValue,
    List<String>? dropdownItems,
    String? dropdownHint,
    IconData? dropdownIcon,
    ValueChanged<String?>? onDropdownChanged,
    required double fontSize,
    VoidCallback? onPrevious,
    bool isLast = false,
  }) {
    // Add debug logging
    print('=== _buildYesNoSection Debug ===');
    print('Title: $title');
    print('value (bool?): $value');
    print('dropdownValue: $dropdownValue');
    print('dropdownItems length: ${dropdownItems?.length ?? 0}');
    print('dropdownItems: $dropdownItems');

    // Determine if this section is completed
    bool isCompleted = false;
    if (value == true &&
        dropdownValue != null &&
        dropdownValue != 'N/A' &&
        dropdownValue.isNotEmpty) {
      isCompleted = true;
    } else if (value == false) {
      isCompleted = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, fontSize),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRadioOption(
                title: 'Yes',
                value: 'yes',
                groupValue: value == null ? null : (value ? 'yes' : 'no'),
                onChanged: (val) {
                  print('Yes selected, val: $val');
                  onChanged(val == 'yes');
                  if (val == 'yes' &&
                      onDropdownChanged != null &&
                      dropdownValue == 'N/A') {
                    print('Clearing N/A value');
                    onDropdownChanged(null);
                  }
                },
                fontSize: fontSize,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRadioOption(
                title: 'No',
                value: 'no',
                groupValue: value == null ? null : (value ? 'yes' : 'no'),
                onChanged: (val) {
                  print('No selected, val: $val');
                  onChanged(val == 'yes');
                  if (val == 'no' && onDropdownChanged != null) {
                    print('Setting N/A value');
                    onDropdownChanged('N/A');
                  }
                },
                fontSize: fontSize,
              ),
            ),
          ],
        ),
        // Debug: Always show what condition evaluates to
        if (value == true) ...[
          const SizedBox(height: 12),

          // Add a debug text to see if we reach here
          if (dropdownItems != null && dropdownItems.isNotEmpty)
            _buildDropdownField(
              value:
                  (dropdownValue != null &&
                          dropdownValue != 'N/A' &&
                          dropdownValue.isNotEmpty &&
                          dropdownItems.contains(dropdownValue))
                      ? dropdownValue
                      : null,
              items: dropdownItems,
              onChanged: onDropdownChanged!,
              hint: dropdownHint ?? 'Select option',
              icon: dropdownIcon ?? Icons.arrow_drop_down,
              fontSize: fontSize,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading options... (or empty list)',
                    style: TextStyle(
                      fontSize: fontSize * 0.85,
                      color: textSecondaryColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
        ] else ...[
          const SizedBox(height: 12),
        ],
        // Show completion message for last section
        if (isLast && isCompleted) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All set! You can now proceed to the next step.',
                    style: TextStyle(
                      fontSize: fontSize * 0.85,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Previous button
        if (onPrevious != null) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  'Previous',
                  style: TextStyle(fontSize: fontSize * 0.85),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize * 0.85,
                  color: textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: fontSize * 0.95,
                  color: textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesPage(
    UserOnboardingPage page,
    double iconSize,
    double titleFontSize,
    double descriptionFontSize,
  ) {
    final features = [
      FeatureHighlight(
        icon: Icons.smart_toy,
        title: "AI Chat Assistant",
        description: "Get instant answers to your academic questions",
      ),
      FeatureHighlight(
        icon: Icons.school,
        title: "Student Services",
        description: "Access admission, scholarship, and placement info",
      ),
      FeatureHighlight(
        icon: Icons.notifications_active,
        title: "Real-time Updates",
        description: "Stay informed with latest announcements",
      ),
      FeatureHighlight(
        icon: Icons.support_agent,
        title: "24/7 Support",
        description: "Help available whenever you need it",
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: iconSize * 0.9,
            height: iconSize * 0.9,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: iconSize * 0.4, color: primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            page.title,
            style: TextStyle(
              fontSize: titleFontSize * 0.85,
              fontWeight: FontWeight.w800,
              color: textPrimaryColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            page.description,
            style: TextStyle(
              fontSize: descriptionFontSize * 0.9,
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
              return _buildFeatureCard(features[index], descriptionFontSize);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(FeatureHighlight feature, double fontSize) {
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
            child: Icon(feature.icon, color: primaryColor, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            feature.title,
            style: TextStyle(
              fontSize: fontSize * 0.9,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            feature.description,
            style: TextStyle(
              fontSize: fontSize * 0.75,
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
  }

  Widget _buildCompletePage(
    UserOnboardingPage page,
    double iconSize,
    double titleFontSize,
    double descriptionFontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                width: iconSize * 0.85,
                height: iconSize * 0.85,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  page.icon,
                  size: iconSize * 0.4,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            page.title,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w800,
              color: textPrimaryColor,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: TextStyle(
              fontSize: descriptionFontSize,
              color: textSecondaryColor,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, double fontSize) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize * 0.95,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String value,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
    required double fontSize,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            groupValue == value
                ? primaryColor.withOpacity(0.05)
                : Colors.grey[50],
        border: Border.all(
          color: groupValue == value ? primaryColor : Colors.grey[300]!,
          width: groupValue == value ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile<String>(
        title: Text(
          title,
          style: TextStyle(
            fontSize: fontSize * 0.85,
            fontWeight: FontWeight.w600,
            color: groupValue == value ? primaryColor : textPrimaryColor,
          ),
        ),
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: primaryColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  // Mobile Layout
  Widget _buildMobileLayout() {
    return SafeArea(
      child: _buildContent(
        maxWidth: double.infinity,
        horizontalPadding: 12,
        iconSize: 80,
        titleFontSize: 24,
        descriptionFontSize: 14,
        buttonHeight: 16,
      ),
    );
  }

  // Tablet Layout
  Widget _buildTabletLayout() {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _buildContent(
            maxWidth: 550,
            horizontalPadding: 28,
            iconSize: 110,
            titleFontSize: 28,
            descriptionFontSize: 16,
            buttonHeight: 18,
          ),
        ),
      ),
    );
  }

  // Desktop Layout
  Widget _buildDesktopLayout() {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: _buildContent(
            maxWidth: 480,
            horizontalPadding: 36,
            iconSize: 120,
            titleFontSize: 32,
            descriptionFontSize: 17,
            buttonHeight: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ResponsiveLayout(
        mobileBody: _buildMobileLayout(),
        tabletBody: _buildTabletLayout(),
        desktopBody: _buildDesktopLayout(),
      ),
    );
  }
}

class UserOnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final UserOnboardingType type;

  UserOnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.type,
  });
}

enum UserOnboardingType { welcome, profile, features, complete }

class FeatureHighlight {
  final IconData icon;
  final String title;
  final String description;

  FeatureHighlight({
    required this.icon,
    required this.title,
    required this.description,
  });
}
