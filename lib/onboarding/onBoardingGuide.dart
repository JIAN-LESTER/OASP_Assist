import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OnboardingStep {
  sidebar,
  sidebarContent,
  notifications,
  profile,
  // Removed bottomNav step
}

class OnboardingGuide extends StatefulWidget {
  final Widget child;
  final GlobalKey? sidebarKey;
  final GlobalKey? notificationKey;
  final GlobalKey? profileKey;
  final GlobalKey? bottomNavKey;
  final VoidCallback? onFinished; // ✅ NEW: Callback when guide finishes

  const OnboardingGuide({
    super.key,
    required this.child,
    this.sidebarKey,
    this.notificationKey,
    this.profileKey,
    this.bottomNavKey,
    this.onFinished, // ✅ NEW
  });

  @override
  State<OnboardingGuide> createState() => _OnboardingGuideState();

  static _OnboardingGuideState? of(BuildContext context) {
    return context.findAncestorStateOfType<_OnboardingGuideState>();
  }
}

class _OnboardingGuideState extends State<OnboardingGuide>
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
      // ✅ Fetch the user's field from Firestore FIRST
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final dbHasSeenOnboarding =
          userDoc.data()?['hasSeenOnboardingGuide'] ?? false;

      // ✅ If user has seen onboarding in Firestore, don't show it (even on new device)
      if (dbHasSeenOnboarding) {
        // Sync local SharedPreferences with Firestore value
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasSeenOnboarding_${user.uid}', true);
        // Also prevent welcome dialog from showing on new devices
        await prefs.setBool('should_show_welcome_dialog', false);
        return; // Don't show onboarding
      }

      // ✅ Check local SharedPreferences only if Firestore says false
      final prefs = await SharedPreferences.getInstance();
      final hasSeenLocal =
          prefs.getBool('hasSeenOnboarding_${user.uid}') ?? false;

      // ✅ Show onboarding only if both Firestore and local say false
      if (!hasSeenLocal && !dbHasSeenOnboarding) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          setState(() {
            _showOnboarding = true;
          });
          _showOverlay();
        }
      }
    } catch (e) {
      print('Error checking onboarding status: $e');
      // On error, don't show onboarding to be safe
    }
  }

  void _showOverlay() {
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

  void _nextStep() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_isMobile(context)) {
        switch (_currentStep) {
          case OnboardingStep.sidebar:
            _currentStep = OnboardingStep.sidebarContent;
            break;
          case OnboardingStep.sidebarContent:
            _currentStep = OnboardingStep.notifications;
            break;
          case OnboardingStep.notifications:
            _currentStep = OnboardingStep.profile;
            break;
          case OnboardingStep.profile:
            _finishOnboarding();
            return;
        }
      } else {
        switch (_currentStep) {
          case OnboardingStep.sidebar:
            _currentStep = OnboardingStep.sidebarContent;
            break;
          case OnboardingStep.sidebarContent:
            _currentStep = OnboardingStep.notifications;
            break;
          case OnboardingStep.notifications:
            _currentStep = OnboardingStep.profile;
            break;
          case OnboardingStep.profile:
            _finishOnboarding();
            return;
        }
      }
    });

    _removeOverlay();
    _showOverlay();
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_isMobile(context)) {
        switch (_currentStep) {
          case OnboardingStep.sidebar:
            return;
          case OnboardingStep.sidebarContent:
            _currentStep = OnboardingStep.sidebar;
            break;
          case OnboardingStep.notifications:
            _currentStep = OnboardingStep.sidebarContent;
            break;
          case OnboardingStep.profile:
            _currentStep = OnboardingStep.notifications;
            break;
        }
      } else {
        switch (_currentStep) {
          case OnboardingStep.sidebar:
            return;
          case OnboardingStep.sidebarContent:
            _currentStep = OnboardingStep.sidebar;
            break;
          case OnboardingStep.notifications:
            _currentStep = OnboardingStep.sidebarContent;
            break;
          case OnboardingStep.profile:
            _currentStep = OnboardingStep.notifications;
            break;
        }
      }
    });

    _removeOverlay();
    _showOverlay();
  }

  Future<void> _skipOnboarding() async {
    HapticFeedback.mediumImpact();
    await _finishOnboarding();
  }

  Future<void> _finishOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasSeenOnboarding_${user.uid}', true);

        // ✅ Update Firestore so it syncs across devices
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'hasSeenOnboardingGuide': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // ✅ Set flag to show welcome dialog
        await prefs.setBool('should_show_welcome_dialog', true);
      } catch (e) {
        print('Error finishing onboarding: $e');
      }
    }

    _removeOverlay();
    setState(() {
      _showOnboarding = false;
    });

    // ✅ Trigger callback after guide completes
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

  // void restartOnboarding() {
  //   setState(() {
  //     _currentStep = OnboardingStep.sidebar;
  //     _showOnboarding = true;
  //   });
  //   _showOverlay();
  // }

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
    final isTablet = _isTablet(context);
    final isDesktop = _isDesktop(context);
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
            _buildBulletPoint('Services - Admission, Scholarships, Placement'),
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
    final isMobile = _isMobile(context);
    final totalSteps = 4; // Changed from 5 to 4
    final currentStepIndex = _getCurrentStepIndex();

    return Row(
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
    switch (currentStep) {
      case OnboardingStep.sidebar:
        return 0;
      case OnboardingStep.sidebarContent:
        return 1;
      case OnboardingStep.notifications:
        return 2;
      case OnboardingStep.profile:
        return 3;
    }
  }

  bool _isLastStep(BuildContext context) {
    return currentStep == OnboardingStep.profile;
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
