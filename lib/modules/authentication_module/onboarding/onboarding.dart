import 'package:flutter/material.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_desktop.dart';
import 'onboarding_tablet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
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

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.school_rounded,
      title: "Welcome to OASP Assist",
      description:
          "Your intelligent companion for navigating OASP services. Get instant answers about admissions, scholarships, and placements—all powered by AI.",
      color: primaryColor,
    ),
    OnboardingPage(
      icon: Icons.chat_bubble_outline_rounded,
      title: "Your Personal Assistant",
      description:
          "Ask questions naturally and get accurate, instant responses. Available 24/7 to help you with admissions, scholarships, and placements services.",
      color: primaryColor,
      isFeaturePage: true,
    ),
    OnboardingPage(
      icon: Icons.security_rounded,
      title: "Your Privacy Matters",
      description:
          "We're committed to protecting your data. Here's what we collect and why:",
      color: primaryColor,
      isPrivacyPage: true,
    ),
    OnboardingPage(
      icon: Icons.login_rounded,
      title: "Let's Get Started",
      description:
          "Sign in to unlock personalized assistance, save your conversations, and access all OASP services in one place.",
      color: primaryColor,
      isStepsPage: true,
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
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

  void _skipToEnd() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  void _finishOnboarding() async {
    // Set app onboarding as completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_onboarding_completed', true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/auth');
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
            // Header with Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
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
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _skipToEnd,
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: descriptionFontSize * 0.85,
                          fontWeight: FontWeight.w600,
                        ),
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
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final isFirstPage = index == 0;

                  if (isFirstPage) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildPage(
                          _pages[index],
                          iconSize,
                          titleFontSize,
                          descriptionFontSize,
                        ),
                      ),
                    );
                  } else {
                    return _buildPage(
                      _pages[index],
                      iconSize,
                      titleFontSize,
                      descriptionFontSize,
                    );
                  }
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
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: backgroundColor,
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
                                    ? 'Get Started'
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
                                    ? Icons.rocket_launch_rounded
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
    OnboardingPage page,
    double iconSize,
    double titleFontSize,
    double descriptionFontSize,
  ) {
    if (page.isFeaturePage) {
      return _buildFeaturePage(
        page,
        iconSize,
        titleFontSize,
        descriptionFontSize,
      );
    } else if (page.isStepsPage) {
      return _buildStepsPage(
        page,
        iconSize,
        titleFontSize,
        descriptionFontSize,
      );
    } else if (page.isPrivacyPage) {
      return _buildPrivacyPage(
        page,
        iconSize,
        titleFontSize,
        descriptionFontSize,
      );
    } else {
      return _buildWelcomePage(
        page,
        iconSize,
        titleFontSize,
        descriptionFontSize,
      );
    }
  }

  Widget _buildWelcomePage(
    OnboardingPage page,
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
              fontWeight: FontWeight.w700,
              color: textPrimaryColor,
              height: 1.2,
              letterSpacing: -0.3,
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

  Widget _buildFeaturePage(
    OnboardingPage page,
    double iconSize,
    double titleFontSize,
    double descriptionFontSize,
  ) {
    final features = [
      FeatureItem(
        icon: Icons.smart_toy_outlined,
        title: "AI-Powered",
        description: "Advanced chatbot provides instant accurate answers.",
      ),
      FeatureItem(
        icon: Icons.schedule_rounded,
        title: "24/7 Available",
        description: "Get help anytime—no waiting in line.",
      ),
      FeatureItem(
        icon: Icons.trending_up_rounded,
        title: "Always Learning",
        description: "Our AI continuously improves to serve you better.",
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              fontWeight: FontWeight.w700,
              color: textPrimaryColor,
              letterSpacing: -0.3,
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
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: features.length,
              itemBuilder:
                  (context, index) =>
                      _buildFeatureCard(features[index], descriptionFontSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPage(
    OnboardingPage page,
    double iconSize,
    double titleFontSize,
    double descriptionFontSize,
  ) {
    final dataItems = [
      DataCollectionItem(
        icon: Icons.account_circle_outlined,
        title: "Profile Information",
        description:
            "Name, email, year level, program, affiliation, student ID, LRN, and scholarship for authentication and user profile.",
        color: Colors.green,
      ),
      DataCollectionItem(
        icon: Icons.message_outlined,
        title: "Chat History",
        description:
            "Conversations to improve AI responses and your experience.",
        color: Colors.green,
      ),
      DataCollectionItem(
        icon: Icons.analytics_outlined,
        title: "Usage Data",
        description: "App interactions to enhance features and performance.",
        color: Colors.green,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              fontWeight: FontWeight.w700,
              color: textPrimaryColor,
              letterSpacing: -0.3,
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
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dataItems.length,
              itemBuilder:
                  (context, index) => _buildDataCollectionCard(
                    dataItems[index],
                    descriptionFontSize,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Your data will remain confidential and never shared with third parties.",
                    style: TextStyle(
                      fontSize: descriptionFontSize * 0.75,
                      color: textSecondaryColor,
                      fontWeight: FontWeight.w500,
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

  Widget _buildFeatureCard(FeatureItem feature, double fontSize) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.icon, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: fontSize * 0.9,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: fontSize * 0.75,
                    color: textSecondaryColor,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCollectionCard(DataCollectionItem item, double fontSize) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: item.color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: fontSize * 0.9,
                    fontWeight: FontWeight.w600,
                    color: item.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: fontSize * 0.75,
                    color: textSecondaryColor,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsPage(
    OnboardingPage page,
    double iconSize,
    double titleFontSize,
    double descriptionFontSize,
  ) {
    final steps = [
      StepItem(
        number: "1",
        title: "Sign In",
        description: "Log in with your OASP Assist credentials.",
        icon: Icons.login_rounded,
      ),
      StepItem(
        number: "2",
        title: "Start Chatting",
        description:
            "Ask questions about admissions, scholarships, or placements.",
        icon: Icons.chat_rounded,
      ),
      StepItem(
        number: "3",
        title: "Explore Services",
        description: "Browse resources and access OASP Assist features.",
        icon: Icons.explore_rounded,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              fontWeight: FontWeight.w700,
              color: textPrimaryColor,
              letterSpacing: -0.3,
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
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: steps.length,
              itemBuilder:
                  (context, index) => _buildStepItem(
                    steps[index],
                    index == steps.length - 1,
                    descriptionFontSize,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(StepItem step, bool isLast, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(step.icon, color: backgroundColor, size: 24),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  margin: const EdgeInsets.only(top: 6),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Step ${step.number}',
                    style: TextStyle(
                      fontSize: fontSize * 0.65,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: fontSize * 1.0,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.description,
                  style: TextStyle(
                    fontSize: fontSize * 0.8,
                    color: textSecondaryColor,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mobile Layout
  Widget _buildMobileLayout() {
    return Container(
      color: Colors.grey[50],
      child: SafeArea(
        child: _buildContent(
          maxWidth: double.infinity,
          horizontalPadding: 12,
          iconSize: 80,
          titleFontSize: 24,
          descriptionFontSize: 14,
          buttonHeight: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Match desktop
      body: ResponsiveLayout(
        mobileBody: _buildMobileLayout(),
        tabletBody: const OnboardingTablet(),
        desktopBody: const OnboardingDesktop(),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool isFeaturePage;
  final bool isStepsPage;
  final bool isPrivacyPage;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.isFeaturePage = false,
    this.isStepsPage = false,
    this.isPrivacyPage = false,
  });
}

class FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class DataCollectionItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  DataCollectionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class StepItem {
  final String number;
  final String title;
  final String description;
  final IconData icon;

  StepItem({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });
}
