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

  // Color scheme - matching first onboarding
  static const Color primaryColor = Color.fromARGB(255, 8, 121, 11);
  static const Color backgroundColor = Colors.white;
  static final Color textPrimaryColor = Colors.grey[800]!;
  static final Color textSecondaryColor = Colors.grey[600]!;

  // Form controllers
  final _nameController = TextEditingController();

  // User profile data
  String? _role;
  String _selectedCourse = '';
  String _selectedYear = '';
  String? _enrollmentStatus;

  bool? _hasScholarship;
  bool? _hasAffiliation;
  String? _selectedAffiliation;
  String _selectedProgram = '';
  String? _selectedScholarship;
  // Add flag to track if summary should be shown
  bool _showSummary = false;

  // Data lists
  final _customAffiliationController = TextEditingController();
  bool _showCustomAffiliationField = false;

  // Data lists
  List<String> _programs = [];
  final List<String> _affiliations = [
    'Incoming Freshman Applicant',
    'Parent',
    'Faculty',
    'CMU Staff',
    'Employer',
    'Alumni',
  ];

  List<String> _scholarships = [];

  final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

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

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _nameController.dispose();
    _customAffiliationController.dispose();
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

  Future<void> _loadDropdownData() async {
    try {
      final futures = await Future.wait([
        _getDropdownItems('programs'),
        _getDropdownItems('scholarships'),
      ]);

      setState(() {
        _programs = [...futures[0]];
        _scholarships = [...futures[1], 'Others'];
      });
    } catch (e) {
      print('Error loading dropdown data: $e');
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
      builder: (context) => WillPopScope(
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
      print('✅ Created initial conversation after onboarding: $newConversationId');
    } catch (e) {
      print('⚠️ Could not create conversation: $e');
    }

    if (mounted) Navigator.of(context).pop();
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      // ✅ Navigate with flag to trigger guide
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => UserMainPage(
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

  Future<void> _saveUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'profileCompleted': true,
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_role == 'user') {
        updateData['isEnrolled'] = _enrollmentStatus == 'enrolled';

        if (_enrollmentStatus == 'not_enrolled') {
          String finalAffiliation = _selectedAffiliation ?? '';

          updateData.addAll({
            'affiliation': finalAffiliation,
            'year': null,
            'program': null,
            'scholarship': null,
          });
        } else {
          // ENROLLED: Save year, program, scholarship, and auto-set affiliation as "Student"
          updateData.addAll({
            'year': _selectedYear,
            'program':
                (_selectedYear == 'Incoming' || _selectedYear == 'Graduate')
                    ? null
                    : _selectedCourse,
            'scholarship':
                _hasScholarship == true ? _selectedScholarship : null,
            'affiliation':
                'Student', // Automatically set to "Student" for enrolled users
          });
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      final verifyDoc =
          await FirebaseFirestore.instance
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

  bool _canProceed() {
    switch (_pages[_currentPage].type) {
      case UserOnboardingType.welcome:
        return _nameController.text.trim().isNotEmpty;

      case UserOnboardingType.profile:
        if (_role == 'user') {
          // Must have enrollment status
          if (_enrollmentStatus == null) return false;

          if (_enrollmentStatus == 'not_enrolled') {
            // NOT ENROLLED: Only need affiliation
            if (_selectedAffiliation == null || _selectedAffiliation!.isEmpty) {
              return false;
            }
            // If "Others" is selected, must have custom input

            return true;
          } else {
            // ENROLLED: Need year, program, and scholarship
            if (_selectedYear.isEmpty) return false;

            // Check if program is required based on year
            if (_selectedYear != 'Incoming' &&
                _selectedYear != 'Graduate' &&
                _selectedCourse.isEmpty) {
              return false;
            }

            // Must answer scholarship question
            if (_hasScholarship == null) return false;
            if (_hasScholarship == true &&
                (_selectedScholarship == null ||
                    _selectedScholarship == 'N/A' ||
                    _selectedScholarship!.isEmpty)) {
              return false;
            }
            return true;
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
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Your Full Name',
              hintText: 'Enter your full name',
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
    // Check if all required fields are completed
    bool allFieldsCompleted = false;

    if (_role == 'user' && _enrollmentStatus != null) {
      if (_enrollmentStatus == 'not_enrolled') {
        // NOT ENROLLED: Only check affiliation
        if (_selectedAffiliation != null && _selectedAffiliation!.isNotEmpty) {
          // If "Others" is selected, check custom input

          allFieldsCompleted = true;
        }
      } else {
        // ENROLLED: Check year, program, and scholarship
        bool yearComplete = _selectedYear.isNotEmpty;
        bool programComplete =
            (_selectedYear == 'Incoming' || _selectedYear == 'Graduate') ||
            _selectedCourse.isNotEmpty;
        bool scholarshipComplete =
            _hasScholarship != null &&
            (_hasScholarship == false ||
                (_hasScholarship == true &&
                    _selectedScholarship != null &&
                    _selectedScholarship != 'N/A' &&
                    _selectedScholarship!.isNotEmpty));

        allFieldsCompleted =
            yearComplete && programComplete && scholarshipComplete;
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
            'Hello ${_nameController.text.isNotEmpty ? _nameController.text.split(' ').first : 'there'}!',
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
                      _selectedYear = '';
                      _selectedCourse = '';
                      // Clear fields not needed for enrolled
                      _selectedAffiliation = null;
                      _customAffiliationController.clear();
                      _showCustomAffiliationField = false;
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
                      // Clear fields not needed for not enrolled
                      _selectedYear = '';
                      _selectedCourse = '';
                      _hasScholarship = null;
                      _selectedScholarship = null;
                    }),
                fontSize: descriptionFontSize,
              ),
            ]
            // FOR NOT ENROLLED: Show affiliation dropdown
            else if (_enrollmentStatus == 'not_enrolled') ...[
              if (_selectedAffiliation == null ||
                  _selectedAffiliation!.isEmpty) ...[
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
                    });
                  },
                  hint: 'Select your association',
                  icon: Icons.people_outline,
                  fontSize: descriptionFontSize,
                ),

                // Show custom input field if "Others" is selected
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedAffiliation = null;
                          _customAffiliationController.clear();
                          _showCustomAffiliationField = false;
                          _enrollmentStatus = null;
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
              ],
            ]
            // FOR ENROLLED: Show year, program, scholarship
            else if (_enrollmentStatus == 'enrolled') ...[
              // Step 2: Year and Program
              if (_selectedYear.isEmpty ||
                  (_selectedYear.isNotEmpty &&
                      _selectedYear != 'Incoming' &&
                      _selectedYear != 'Graduate' &&
                      _selectedCourse.isEmpty)) ...[
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'What year are you in?',
                  descriptionFontSize,
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  value:
                      _selectedYear.isEmpty || !years.contains(_selectedYear)
                          ? null
                          : _selectedYear,
                  items: years,
                  onChanged:
                      (value) => setState(() {
                        _selectedYear = value ?? '';
                        if (value == 'Incoming' || value == 'Graduate') {
                          _selectedCourse = 'N/A';
                        } else {
                          _selectedCourse = '';
                        }
                      }),
                  hint: 'Select your year level',
                  icon: Icons.school_outlined,
                  fontSize: descriptionFontSize,
                ),

                if (_selectedYear.isNotEmpty &&
                    _selectedYear != 'Incoming' &&
                    _selectedYear != 'Graduate') ...[
                  const SizedBox(height: 16),
                  _buildSectionTitle(
                    'What program are you taking?',
                    descriptionFontSize,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    value:
                        _selectedCourse.isEmpty ||
                                !_programs.contains(_selectedCourse)
                            ? null
                            : _selectedCourse,
                    items: _programs,
                    onChanged:
                        (value) =>
                            setState(() => _selectedCourse = value ?? ''),
                    hint: 'Select your program',
                    icon: Icons.book_outlined,
                    fontSize: descriptionFontSize,
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedYear = '';
                          _selectedCourse = '';
                          _enrollmentStatus = null;
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
              // Step 3: Scholarship (only for enrolled)
              else if ((_selectedYear == 'Incoming' ||
                      _selectedYear == 'Graduate' ||
                      _selectedCourse.isNotEmpty) &&
                  (_hasScholarship == null ||
                      (_hasScholarship == true &&
                          (_selectedScholarship == null ||
                              _selectedScholarship!.isEmpty ||
                              _selectedScholarship == 'N/A')))) ...[
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
                  dropdownValue:
                      _hasScholarship == true ? _selectedScholarship : null,
                  dropdownItems: _scholarships,
                  dropdownHint: 'Select your scholarship',
                  dropdownIcon: Icons.card_membership_outlined,
                  onDropdownChanged:
                      (value) => setState(() => _selectedScholarship = value),
                  fontSize: descriptionFontSize,
                  onPrevious: () {
                    setState(() {
                      _hasScholarship = null;
                      _selectedScholarship = null;
                      _selectedYear = '';
                      _selectedCourse = '';
                    });
                  },
                  isLast: true,
                ),
              ],
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  // ALSO update the _buildProfileSummary to have a proper "Edit" button that goes back:

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
                  value: _nameController.text.trim(),
                  fontSize: fontSize,
                ),

                // NOT ENROLLED: Show only Name + Affiliation
                if (_enrollmentStatus == 'not_enrolled') ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildSummaryItem(
                    icon: Icons.people_outline,
                    label: 'Organizational Affiliation',
                    // FIX: Check _selectedAffiliation instead of _hasAffiliation
                    value:
                        _selectedAffiliation == 'Others'
                            ? _customAffiliationController.text.trim()
                            : (_selectedAffiliation ?? 'None'),
                    fontSize: fontSize,
                  ),
                ],

                // ENROLLED: Show Name + Affiliation (CMU Student) + Year + Program + Scholarship
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
                    icon: Icons.calendar_today_outlined,
                    label: 'Year Level',
                    value: _selectedYear,
                    fontSize: fontSize,
                  ),
                  if (_selectedYear != 'Incoming' &&
                      _selectedYear != 'Graduate') ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _buildSummaryItem(
                      icon: Icons.book_outlined,
                      label: 'Program',
                      value: _selectedCourse,
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
              ],
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  if (_enrollmentStatus == 'not_enrolled') {
                    // FIX: Reset the correct variables
                    _selectedAffiliation = null;
                    _customAffiliationController.clear();
                    _showCustomAffiliationField = false;
                  } else {
                    _hasScholarship = null;
                    _selectedScholarship = null;
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
