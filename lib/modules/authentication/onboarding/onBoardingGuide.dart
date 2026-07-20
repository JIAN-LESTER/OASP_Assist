import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OnboardingStep {
  sidebar,
  sidebarContent,
  faqButton,
  faqCards,
  textInput,
  chatBubbles,
  escalationButton,
  audioButton,
  notifications,
  profile,
}

class OnboardingGuide extends StatefulWidget {
  final Widget child;
  final GlobalKey? sidebarKey;
  final GlobalKey? notificationKey;
  final GlobalKey? profileKey;
  final GlobalKey? bottomNavKey;
  final GlobalKey? faqButtonKey;
  final GlobalKey? faqCardsKey;
  final GlobalKey? textInputKey;
  final GlobalKey? audioButtonKey;
  final VoidCallback? onFinished;

  const OnboardingGuide({
    super.key,
    required this.child,
    this.sidebarKey,
    this.notificationKey,
    this.profileKey,
    this.bottomNavKey,
    this.faqButtonKey,
    this.faqCardsKey,
    this.textInputKey,
    this.audioButtonKey,
    this.onFinished,
  });

  @override
  OnboardingGuideState createState() => OnboardingGuideState();

  static OnboardingGuideState? of(BuildContext context) {
    return context.findAncestorStateOfType<OnboardingGuideState>();
  }
}

class OnboardingGuideState extends State<OnboardingGuide>
    with SingleTickerProviderStateMixin {
  bool _showOnboarding = false;
  OnboardingStep _currentStep = OnboardingStep.sidebar;
  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final dbHasSeenOnboarding =
          userDoc.data()?['hasSeenOnboardingGuide'] ?? false;

      if (dbHasSeenOnboarding) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasSeenOnboarding_${user.uid}', true);
        await prefs.setBool('should_show_welcome_dialog', false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final hasSeenLocal =
          prefs.getBool('hasSeenOnboarding_${user.uid}') ?? false;

      if (!hasSeenLocal && !dbHasSeenOnboarding) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted && !_showOnboarding) {
          setState(() {
            _showOnboarding = true;
          });
          _showOverlay();
        }
      }
    } catch (e) {
      print('Error checking onboarding status: $e');
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder:
          (context) => _OnboardingOverlay(
            currentStep: _currentStep,
            sidebarKey: widget.sidebarKey,
            notificationKey: widget.notificationKey,
            profileKey: widget.profileKey,
            bottomNavKey: widget.bottomNavKey,
            faqButtonKey: widget.faqButtonKey,
            faqCardsKey: widget.faqCardsKey,
            textInputKey: widget.textInputKey,
            audioButtonKey: widget.audioButtonKey,
            pulseAnimation: _pulseAnimation,
            onNext: _nextStep,
            onPrevious: _previousStep,
            onSkip: _skipOnboarding,
          ),
    );
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  List<OnboardingStep> _availableSteps() {
    final steps = <OnboardingStep>[
      OnboardingStep.sidebar,
      OnboardingStep.sidebarContent,
      OnboardingStep.faqButton,
    ];

    if (widget.faqCardsKey?.currentContext != null) {
      steps.add(OnboardingStep.faqCards);
    }

    steps.addAll(const [
      OnboardingStep.textInput,
      OnboardingStep.chatBubbles,
      OnboardingStep.escalationButton,
      OnboardingStep.audioButton,
      OnboardingStep.notifications,
      OnboardingStep.profile,
    ]);
    return steps;
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    final steps = _availableSteps();
    final currentIndex = steps.indexOf(_currentStep);

    if (currentIndex == -1 || currentIndex == steps.length - 1) {
      _finishOnboarding();
      return;
    }

    setState(() => _currentStep = steps[currentIndex + 1]);
    _removeOverlay();
    _showOverlay();
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    final steps = _availableSteps();
    final currentIndex = steps.indexOf(_currentStep);

    if (currentIndex <= 0) return;

    setState(() => _currentStep = steps[currentIndex - 1]);
    _removeOverlay();
    _showOverlay();
  }

  Future<void> _skipOnboarding() async {
    HapticFeedback.mediumImpact();
    await _finishOnboarding();
  }

  Widget _buildWelcomeFeature(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //  ADD THIS METHOD (after _buildWelcomeFeature)
  Future<void> _showWelcomeDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.waving_hand,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to OASP!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your AI assistant is ready',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildWelcomeFeature(
                          Icons.chat_outlined,
                          'Chat with OASP Assist',
                          'Ask questions and get guided help',
                        ),
                        const SizedBox(height: 12),
                        _buildWelcomeFeature(
                          Icons.announcement_outlined,
                          'Announcements',
                          'View latest OASP updates',
                        ),
                        const SizedBox(height: 12),
                        _buildWelcomeFeature(
                          Icons.notifications_outlined,
                          'Notifications',
                          'Stay updated on replies and announcements',
                        ),
                      ],
                    ),
                  ),

                  // Button
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _finishOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasSeenOnboarding_${user.uid}', true);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'hasSeenOnboardingGuide': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        //  Mark welcome as seen in prefs
        await prefs.setBool('should_show_welcome_dialog', false);
      } catch (e) {
        print('Error finishing onboarding: $e');
      }
    }

    _removeOverlay();
    setState(() {
      _showOnboarding = false;
    });

    //  Then trigger the original callback
    widget.onFinished?.call();
  }

  void showGuide() {
    if (!_showOnboarding) {
      setState(() {
        _showOnboarding = true;
        _currentStep = OnboardingStep.sidebar;
      });
      _showOverlay();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _OnboardingOverlay extends StatelessWidget {
  final OnboardingStep currentStep;
  final GlobalKey? sidebarKey;
  final GlobalKey? notificationKey;
  final GlobalKey? profileKey;
  final GlobalKey? bottomNavKey;
  final GlobalKey? faqButtonKey;
  final GlobalKey? faqCardsKey;
  final GlobalKey? textInputKey;
  final GlobalKey? audioButtonKey;
  final Animation<double> pulseAnimation;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  const _OnboardingOverlay({
    required this.currentStep,
    this.sidebarKey,
    this.notificationKey,
    this.profileKey,
    this.bottomNavKey,
    this.faqButtonKey,
    this.faqCardsKey,
    this.textInputKey,
    this.audioButtonKey,
    required this.pulseAnimation,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  bool _isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1100;
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1100;
  }

  @override
  Widget build(BuildContext context) {
    if (currentStep == OnboardingStep.sidebarContent) {
      return _buildSidebarContentOverlay(context);
    }

    if (currentStep == OnboardingStep.chatBubbles ||
        currentStep == OnboardingStep.escalationButton) {
      return _buildChatPreviewOverlay(context);
    }

    final targetKey = _getTargetKey();
    if (targetKey == null) return const SizedBox.shrink();

    final renderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(color: Colors.transparent),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _HolePainter(
                holeRect: Rect.fromLTWH(
                  offset.dx - 4,
                  offset.dy - 4,
                  size.width + 8,
                  size.height + 8,
                ),
                holeRadius: _getHoleRadius(),
                fillHoleWithWhite: true,
              ),
              child: Container(),
            ),
          ),
          Positioned(
            left: offset.dx - 8,
            top: offset.dy - 8,
            child: IgnorePointer(
              child: Container(
                width: size.width + 16,
                height: size.height + 16,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF4CAF50), width: 3),
                  borderRadius: BorderRadius.circular(_getHoleRadius() + 8),
                ),
              ),
            ),
          ),
          Positioned(
            left: _getTooltipLeft(context, offset, size),
            top: _getTooltipTop(context, offset, size),
            child: _buildTooltip(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPreviewOverlay(BuildContext context) {
    final isEscalationStep = currentStep == OnboardingStep.escalationButton;

    return Material(
      color: Colors.black.withOpacity(0.72),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chat preview',
                    style: TextStyle(
                      color: Color(0xFF1B5E20),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'How do I apply?',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      'You can submit your application through the admissions portal.',
                      style: TextStyle(color: Color(0xFF374151), height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isEscalationStep
                                ? const Color(0xFFFFF7ED)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isEscalationStep
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey.shade300,
                          width: isEscalationStep ? 3 : 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.support_agent,
                            size: 18,
                            color: Color(0xFF4B5563),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Escalate to Staff',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTooltip(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContentOverlay(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = _isMobile(context);

    if (isMobile) {
      final bottomNavHeight = 80.0;
      final bottomNavRect = Rect.fromLTWH(
        0,
        screenHeight - bottomNavHeight,
        screenWidth,
        bottomNavHeight,
      );

      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(color: Colors.transparent),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _HolePainter(
                  holeRect: bottomNavRect,
                  holeRadius: 0,
                  fillHoleWithWhite: false,
                ),
                child: Container(),
              ),
            ),
            Positioned(
              left: -4,
              top: screenHeight - bottomNavHeight - 4,
              child: IgnorePointer(
                child: Container(
                  width: screenWidth + 8,
                  height: bottomNavHeight + 8,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF4CAF50),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: bottomNavHeight + 40,
              child: Center(child: _buildTooltip(context)),
            ),
          ],
        ),
      );
    } else {
      final sidebarWidth = 250.0;
      final sidebarRect = Rect.fromLTWH(0, 0, sidebarWidth, screenHeight);

      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(color: Colors.transparent),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _HolePainter(
                  holeRect: sidebarRect,
                  holeRadius: 0,
                  fillHoleWithWhite: false,
                ),
                child: Container(),
              ),
            ),
            Positioned(
              left: -4,
              top: -4,
              child: IgnorePointer(
                child: Container(
                  width: sidebarWidth + 8,
                  height: screenHeight + 8,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF4CAF50),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: sidebarWidth + 20,
              top: 100,
              child: _buildTooltip(context),
            ),
          ],
        ),
      );
    }
  }

  GlobalKey? _getTargetKey() {
    switch (currentStep) {
      case OnboardingStep.sidebar:
        return sidebarKey;
      case OnboardingStep.sidebarContent:
        return null;
      case OnboardingStep.faqButton:
        return faqButtonKey;
      case OnboardingStep.faqCards:
        return faqCardsKey;
      case OnboardingStep.textInput:
        return textInputKey;
      case OnboardingStep.chatBubbles:
      case OnboardingStep.escalationButton:
        return null;
      case OnboardingStep.audioButton:
        return audioButtonKey;
      case OnboardingStep.notifications:
        return notificationKey;
      case OnboardingStep.profile:
        return profileKey;
    }
  }

  double _getHoleRadius() {
    switch (currentStep) {
      case OnboardingStep.sidebar:
        return 0;
      case OnboardingStep.sidebarContent:
        return 0;
      case OnboardingStep.faqButton:
        return 8;
      case OnboardingStep.faqCards:
      case OnboardingStep.textInput:
        return 12;
      case OnboardingStep.chatBubbles:
      case OnboardingStep.escalationButton:
        return 0;
      case OnboardingStep.audioButton:
        return 8;
      case OnboardingStep.notifications:
        return 24;
      case OnboardingStep.profile:
        return 0;
    }
  }

  double _getTooltipLeft(BuildContext context, Offset offset, Size size) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = _isMobile(context);

    switch (currentStep) {
      case OnboardingStep.sidebar:
        if (isMobile) {
          return 20;
        } else {
          if (offset.dx + size.width + 320 > screenWidth) {
            return screenWidth - 320 - 20;
          }
          return offset.dx + size.width + 20;
        }
      case OnboardingStep.sidebarContent:
        return 0;
      case OnboardingStep.faqButton:
        // Center tooltip above the button
        final tooltipWidth =
            isMobile ? (screenWidth - 40).clamp(280.0, 340.0) : 340.0;
        final centeredLeft = offset.dx + (size.width / 2) - (tooltipWidth / 2);

        // Keep within screen bounds
        if (centeredLeft < 20) {
          return 20;
        }
        if (centeredLeft + tooltipWidth > screenWidth - 20) {
          return screenWidth - tooltipWidth - 20;
        }
        return centeredLeft;

      case OnboardingStep.faqCards:
      case OnboardingStep.textInput:
        final tooltipWidth =
            isMobile ? (screenWidth - 40).clamp(280.0, 340.0) : 340.0;
        final centeredLeft = offset.dx + (size.width / 2) - (tooltipWidth / 2);
        if (centeredLeft < 20) return 20;
        if (centeredLeft + tooltipWidth > screenWidth - 20) {
          return screenWidth - tooltipWidth - 20;
        }
        return centeredLeft;

      case OnboardingStep.chatBubbles:
      case OnboardingStep.escalationButton:
        return 0;

      case OnboardingStep.audioButton:
        // Center tooltip above the button (positioned to the right)
        final tooltipWidth =
            isMobile ? (screenWidth - 40).clamp(280.0, 340.0) : 340.0;
        final centeredLeft = offset.dx + (size.width / 2) - (tooltipWidth / 2);

        // Keep within screen bounds
        if (centeredLeft < 20) {
          return 20;
        }
        if (centeredLeft + tooltipWidth > screenWidth - 20) {
          return screenWidth - tooltipWidth - 20;
        }
        return centeredLeft;

      case OnboardingStep.notifications:
        if (offset.dx - 300 < 20) {
          return 20;
        }
        return offset.dx - 300;
      case OnboardingStep.profile:
        if (offset.dx - 300 < 20) {
          return 20;
        }
        return offset.dx - 300;
    }
  }

  double _getTooltipTop(BuildContext context, Offset offset, Size size) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = _isMobile(context);

    switch (currentStep) {
      case OnboardingStep.sidebar:
        if (isMobile) {
          return offset.dy + size.height + 20;
        } else {
          return offset.dy;
        }
      case OnboardingStep.sidebarContent:
        return 0;
      case OnboardingStep.faqButton:
        // Position tooltip above the button with better spacing
        final tooltipHeight = 180.0;
        final proposedTop = offset.dy - tooltipHeight - 48; //

        // If too close to top, position below instead
        if (proposedTop < 80) {
          return offset.dy + size.height + 48; //
        }
        return proposedTop;

      case OnboardingStep.faqCards:
      case OnboardingStep.textInput:
        final proposedTop = offset.dy - 210;
        if (proposedTop < 80) return offset.dy + size.height + 24;
        return proposedTop;

      case OnboardingStep.chatBubbles:
      case OnboardingStep.escalationButton:
        return 0;

      case OnboardingStep.audioButton:
        // Position tooltip above the button with better spacing
        final tooltipHeight = 160.0;
        final proposedTop = offset.dy - tooltipHeight - 48; //

        // If too close to top, position below instead
        if (proposedTop < 80) {
          return offset.dy + size.height + 48; //
        }
        return proposedTop;

      case OnboardingStep.notifications:
        final proposedTop = offset.dy + size.height + 20;
        if (proposedTop + 200 > screenHeight) {
          return offset.dy - 220;
        }
        return proposedTop;
      case OnboardingStep.profile:
        final proposedTop = offset.dy + size.height + 20;
        if (proposedTop + 200 > screenHeight) {
          return offset.dy - 220;
        }
        return proposedTop;
    }
  }

  Widget _buildTooltip(BuildContext context) {
    final info = _getStepInfo(context);
    final isMobile = _isMobile(context);
    final isFirstStep = currentStep == OnboardingStep.sidebar;
    final isLastStep = _isLastStep(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      constraints: BoxConstraints(
        maxWidth: isMobile ? screenWidth - 40 : 340,
        minWidth: isMobile ? 280 : 300,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            info.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          if (currentStep == OnboardingStep.sidebarContent) ...[
            const SizedBox(height: 12),
            _buildBulletPoint('Home - Your dashboard'),
            _buildBulletPoint('Chat with OASP Assist - AI assistant'),
            _buildBulletPoint('Announcements - Latest updates'),
          ],
          const SizedBox(height: 20),

          // Updated action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous/Skip button
              if (!isFirstStep)
                TextButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text(
                    'Previous',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Skip Tour',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),

              const Spacer(),

              // Step indicator and Next/Finish button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStepIndicator(context),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLastStep ? 'Finish' : 'Next',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isLastStep
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    final totalSteps = _availableSteps().length;
    final currentStepIndex = _getCurrentStepIndex();

    if (totalSteps > 6) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${currentStepIndex + 1}/$totalSteps',
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStepIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2E7D32) : Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  int _getCurrentStepIndex() {
    return _availableSteps().indexOf(currentStep);
  }

  bool _isLastStep(BuildContext context) {
    return _getCurrentStepIndex() == _availableSteps().length - 1;
  }

  List<OnboardingStep> _availableSteps() {
    final steps = <OnboardingStep>[
      OnboardingStep.sidebar,
      OnboardingStep.sidebarContent,
      OnboardingStep.faqButton,
    ];
    if (faqCardsKey?.currentContext != null) {
      steps.add(OnboardingStep.faqCards);
    }
    steps.addAll(const [
      OnboardingStep.textInput,
      OnboardingStep.chatBubbles,
      OnboardingStep.escalationButton,
      OnboardingStep.audioButton,
      OnboardingStep.notifications,
      OnboardingStep.profile,
    ]);
    return steps;
  }

  _StepInfo _getStepInfo(BuildContext context) {
    final isMobile = _isMobile(context);

    switch (currentStep) {
      case OnboardingStep.sidebar:
        if (isMobile) {
          return _StepInfo(
            title: 'Chat Menu',
            description:
                'When you navigate to Chat, tap the menu icon to access New Chat and your conversation history.',
          );
        } else {
          return _StepInfo(
            title: 'Sidebar Navigation',
            description:
                'Click the menu icon to expand or collapse the sidebar. Use it to navigate between different sections.',
          );
        }

      case OnboardingStep.sidebarContent:
        if (isMobile) {
          return _StepInfo(
            title: 'Bottom Navigation',
            description:
                'Use the bottom navigation bar to quickly switch between sections. Swipe down to collapse it when you need more screen space.',
          );
        } else {
          return _StepInfo(
            title: 'Sidebar Navigation',
            description:
                'Use the sidebar to navigate between different sections:',
          );
        }

      case OnboardingStep.faqButton:
        return _StepInfo(
          title: 'Browse FAQs',
          description:
              'Toggle this button to view frequently asked questions. It\'s a quick way to find answers without typing.',
        );

      case OnboardingStep.faqCards:
        return _StepInfo(
          title: 'FAQ Categories',
          description: 'Choose a category card to browse common questions. ',
        );

      case OnboardingStep.textInput:
        return _StepInfo(
          title: 'Ask a Question',
          description:
              'Type your question here, then use the arrow button or your keyboard to send it.',
        );

      case OnboardingStep.chatBubbles:
        return _StepInfo(
          title: 'Your Chat',
          description:
              'Your messages appear in green and OASP Assist replies in white, so it is easy to follow the conversation.',
        );

      case OnboardingStep.escalationButton:
        return _StepInfo(
          title: 'Escalate to Staff',
          description:
              'If an answer does not resolve your concern, use this button below an OASP Assist reply to ask staff for help.',
        );

      case OnboardingStep.audioButton:
        return _StepInfo(
          title: 'Voice Input',
          description:
              'Use voice input to ask questions. Simply tap the microphone and speak your query.',
        );

      case OnboardingStep.notifications:
        return _StepInfo(
          title: 'Notifications',
          description:
              'Stay updated with important announcements and messages. Tap the bell icon to view all your notifications.',
        );

      case OnboardingStep.profile:
        return _StepInfo(
          title: 'Your Profile',
          description:
              'Access your profile settings, view your information, and logout from here. Tap on your name to see options.',
        );
    }
  }
}

class _StepInfo {
  final String title;
  final String description;

  _StepInfo({required this.title, required this.description});
}

class _HolePainter extends CustomPainter {
  final Rect holeRect;
  final double holeRadius;
  final bool fillHoleWithWhite;

  _HolePainter({
    required this.holeRect,
    required this.holeRadius,
    this.fillHoleWithWhite = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.75)
          ..style = PaintingStyle.fill;

    final holePath =
        Path()
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRRect(
            RRect.fromRectAndRadius(holeRect, Radius.circular(holeRadius)),
          )
          ..fillType = PathFillType.evenOdd;

    canvas.drawPath(holePath, overlayPaint);
  }

  @override
  bool shouldRepaint(_HolePainter oldDelegate) {
    return oldDelegate.holeRect != holeRect ||
        oldDelegate.holeRadius != holeRadius ||
        oldDelegate.fillHoleWithWhite != fillHoleWithWhite;
  }
}

// Future<void> resetOnboarding() async {
//   final prefs = await SharedPreferences.getInstance();
//   await prefs.remove('hasSeenOnboarding');
// }
