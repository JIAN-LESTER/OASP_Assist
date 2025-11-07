import 'package:flutter/material.dart';
import 'package:capstone_project/pages/user_pages/user_main_page.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  bool? _hasAffiliation;
  bool? _hasScholarship;
  String? _selectedAffiliation;
  String? _selectedScholarship;

  // Add flag to track if summary should be shown
  bool _showSummary = false;

  // Data lists
  List<String> _programs = [];
  List<String> _affiliations = [];
  List<String> _scholarships = [];

  final List<String> courses = [
    'Computer Science',
    'Information Technology',
    'Engineering',
    'Business Administration',
    'Education',
    'Other',
  ];

  final List<String> years = [
    'Incoming',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'Graduate',
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

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _nameController.dispose();
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
        _getDropdownItems('affiliations'),
        _getDropdownItems('scholarships'),
      ]);

      setState(() {
        _programs = [...futures[0]];
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

      if (mounted) Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const UserMainPage(initialTabIndex: 1),
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
  updateData.addAll({
    'isEnrolled': _enrollmentStatus == 'enrolled',
    'affiliation': _hasAffiliation == true ? _selectedAffiliation : null,
    'scholarship': _hasScholarship == true ? _selectedScholarship : null,
  });

        if (_enrollmentStatus == 'enrolled') {
          updateData.addAll({
            'year': _selectedYear,
            'program': _selectedCourse,
          });
        } else {
          updateData.addAll({'year': 'Incoming', 'program': null});
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
        if (_enrollmentStatus == null) return false;

        if (_enrollmentStatus == 'enrolled') {
          if (_selectedYear.isEmpty) return false;
          // Only require program if year is not "Incoming"
          if (_selectedYear != 'Incoming' && _selectedCourse.isEmpty) {
            return false;
          }
        }

        if (_selectedAffiliation == null) return false;
        if (_hasAffiliation == true && _selectedAffiliation == 'N/A') return false;

        if (_selectedScholarship == null) return false;
        if (_hasScholarship == true && _selectedScholarship == 'N/A') return false;

        return true;
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
                            onPressed: () {
                              if (_showSummary) {
                                setState(() => _showSummary = false);
                              } else {
                                _previousPage();
                              }
                            },
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

 Widget _buildProfilePage(
  UserOnboardingPage page,
  double iconSize,
  double titleFontSize,
  double descriptionFontSize,
  double maxWidth,
) {
  // Show summary if all required fields are filled
  if (_showSummary && _canProceed()) {
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
          if (_enrollmentStatus == null) ...[
            _buildSectionTitle(
                'Are you currently enrolled?', descriptionFontSize),
            const SizedBox(height: 12),
            _buildRadioOption(
              title: 'Yes, I am enrolled',
              value: 'enrolled',
              groupValue: _enrollmentStatus,
              onChanged: (value) => setState(() => _enrollmentStatus = value),
              fontSize: descriptionFontSize,
            ),
            const SizedBox(height: 12),
            _buildRadioOption(
              title: 'No, not yet enrolled',
              value: 'not_enrolled',
              groupValue: _enrollmentStatus,
              onChanged: (value) {
                setState(() {
                  _enrollmentStatus = value;
                  _selectedYear = '';
                  _selectedCourse = '';
                });
              },
              fontSize: descriptionFontSize,
            ),
          ],
          if (_enrollmentStatus == 'enrolled' &&
              (_selectedYear.isEmpty || (_selectedYear != 'Incoming' && _selectedCourse.isEmpty))) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('What year are you in?', descriptionFontSize),
            const SizedBox(height: 12),
            _buildDropdownField(
              value: _selectedYear.isEmpty ? null : _selectedYear,
              items: years,
              onChanged: (value) => setState(() => _selectedYear = value ?? ''),
              hint: 'Select your year level',
              icon: Icons.school_outlined,
              fontSize: descriptionFontSize,
            ),
            if (_selectedYear.isNotEmpty && _selectedYear != 'Incoming') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedYear = '';
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      // Just continue to course selection
                    },
                    label: Text(
                      'Next',
                      style: TextStyle(fontSize: descriptionFontSize * 0.85),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _buildSectionTitle(
                'What program are you taking?', descriptionFontSize),
            const SizedBox(height: 12),
            _buildDropdownField(
              value: _selectedCourse.isEmpty ? null : _selectedCourse,
              items: _programs.isEmpty ? courses : _programs,
              onChanged:
                  (value) => setState(() => _selectedCourse = value ?? ''),
              hint: 'Select your program',
              icon: Icons.book_outlined,
              fontSize: descriptionFontSize,
            ),
            if (_selectedCourse.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCourse = '';
                        if (_selectedYear == 'Incoming') {
                          _selectedYear = '';
                        }
                      });
                    },
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: Text(
                      'Previous',
                      style: TextStyle(fontSize: descriptionFontSize * 0.85),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      // Continue to affiliation
                    },
                    label: Text(
                      'Next',
                      style: TextStyle(fontSize: descriptionFontSize * 0.85),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (_enrollmentStatus != null &&
              (_enrollmentStatus == 'not_enrolled' ||
                  (_selectedYear.isNotEmpty &&
                      (_selectedYear == 'Incoming' || _selectedCourse.isNotEmpty))) &&
              _selectedAffiliation == null) ...[
            const SizedBox(height: 24),
            _buildYesNoSection(
              title: 'Do you have any organizational affiliation?',
              value: _hasAffiliation,
              onChanged: (value) {
                setState(() {
                  _hasAffiliation = value;
                  if (!value) _selectedAffiliation = 'N/A';
                });
              },
            dropdownValue: _hasAffiliation == true &&
                 _selectedAffiliation != null &&
                 _selectedAffiliation != 'N/A'
      ? _selectedAffiliation
      : null,
              dropdownItems: _affiliations.isEmpty ? ['None'] : _affiliations,
              dropdownHint: 'Select your affiliation',
              dropdownIcon: Icons.people_outline,
              onDropdownChanged:
                  (value) => setState(() => _selectedAffiliation = value),
              fontSize: descriptionFontSize,
              onPrevious: () {
                setState(() {
                  _selectedAffiliation = null;
                  _hasAffiliation = null;
                  if (_enrollmentStatus == 'enrolled') {
                    _selectedCourse = '';
                  } else {
                    _enrollmentStatus = null;
                  }
                });
              },
              onNext: _selectedAffiliation != null
                  ? () {}
                  : null,
            ),
          ],
          if (_selectedAffiliation != null &&
              _selectedScholarship == null) ...[
            const SizedBox(height: 24),
            _buildYesNoSection(
              title: 'Do you have any scholarship?',
              value: _hasScholarship,
              onChanged: (value) {
                setState(() {
                  _hasScholarship = value;
                  if (!value) _selectedScholarship = 'N/A';
                });
              },
              dropdownValue: _hasScholarship == true &&
                 _selectedScholarship != null &&
                 _selectedScholarship != 'N/A'
      ? _selectedScholarship
      : null,
              dropdownItems: _scholarships.isEmpty ? ['None'] : _scholarships,
              dropdownHint: 'Select your scholarship',
              dropdownIcon: Icons.card_membership_outlined,
              onDropdownChanged:
                  (value) => setState(() => _selectedScholarship = value),
              fontSize: descriptionFontSize,
              onPrevious: () {
                setState(() {
                  _selectedScholarship = null;
                  _hasScholarship = null;
                  _selectedAffiliation = null;
                });
              },
              onNext: _selectedScholarship != null
                  ? () {
                      setState(() => _showSummary = true);
                    }
                  : null,
            ),
          ],
        ],
        const SizedBox(height: 32),
      ],
    ),
  );
}

  // Add this new method to build the profile summary
  Widget _buildProfileSummary(double fontSize) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Header
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

          // Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
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
                // Name
                _buildSummaryItem(
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: _nameController.text.trim(),
                  fontSize: fontSize,
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Enrollment Status
                _buildSummaryItem(
                  icon: Icons.school_outlined,
                  label: 'Enrollment Status',
                  value: _enrollmentStatus == 'enrolled'
                      ? 'Currently Enrolled'
                      : 'Not Yet Enrolled',
                  fontSize: fontSize,
                ),

                // Year and Program (if enrolled)
                if (_enrollmentStatus == 'enrolled') ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildSummaryItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Year Level',
                    value: _selectedYear,
                    fontSize: fontSize,
                  ),
                  if (_selectedYear != 'Incoming') ...[
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
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Affiliation
                _buildSummaryItem(
                  icon: Icons.people_outline,
                  label: 'Organizational Affiliation',
                  value: _hasAffiliation == true && _selectedAffiliation != 'N/A'
                      ? _selectedAffiliation!
                      : 'None',
                  fontSize: fontSize,
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Scholarship
                _buildSummaryItem(
                  icon: Icons.card_membership_outlined,
                  label: 'Scholarship',
                  value: _hasScholarship == true && _selectedScholarship != 'N/A'
                      ? _selectedScholarship!
                      : 'None',
                  fontSize: fontSize,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Edit Button
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showSummary = false;
                  _selectedScholarship = null;
                  _hasScholarship = null;
                });
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'Edit Information',
                style: TextStyle(fontSize: fontSize * 0.9),
              ),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
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

    Widget _buildDropdownField({
      required String? value,
      required List<String> items,
      required ValueChanged<String?> onChanged,
      required String hint,
      required IconData icon,
      required double fontSize,
    }) {
      return DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
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
            items.map((item) {
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
    required bool? value,  // Changed to nullable bool
    required ValueChanged<bool> onChanged,
    String? dropdownValue,
    List<String>? dropdownItems,
    String? dropdownHint,
    IconData? dropdownIcon,
    ValueChanged<String?>? onDropdownChanged,
    required double fontSize,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    bool isLast = false,
  }) {
    // Determine if this section is completed
    bool isCompleted = false;
    if (value == true && dropdownValue != null && dropdownValue != 'N/A') {
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
                  onChanged(val == 'yes');
                  if (val == 'yes' && onDropdownChanged != null) {
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
                  onChanged(val == 'yes');
                  if (val == 'no' && onDropdownChanged != null) {
                    onDropdownChanged('N/A');
                  }
                },
                fontSize: fontSize,
              ),
            ),
          ],
        ),
        if (value == true && dropdownItems != null && dropdownItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDropdownField(
            value: dropdownValue != 'N/A' ? dropdownValue : null,
            items: dropdownItems,
            onChanged: onDropdownChanged!,
            hint: dropdownHint ?? 'Select option',
            icon: dropdownIcon ?? Icons.arrow_drop_down,
            fontSize: fontSize,
          ),
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
        // Add navigation buttons
        if (onNext != null || onPrevious != null) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onPrevious != null)
                TextButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(
                    'Previous',
                    style: TextStyle(fontSize: fontSize * 0.85),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                )
              else
                const SizedBox.shrink(),
              if (onNext != null)
                TextButton.icon(
                  onPressed: onNext,
                  label: Text(
                    'Next',
                    style: TextStyle(fontSize: fontSize * 0.85),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ],
      ],
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
