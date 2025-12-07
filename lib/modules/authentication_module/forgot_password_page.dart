import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  bool _isLoading = false;

  // Error state variables
  String? _emailError;
  String? _generalError;

  // Timers for error handling
  Timer? _emailErrorTimer;
  Timer? _generalErrorTimer;

  // FONT CONFIGURATION (matching LoginPage)
  static const String primaryFontFamily = 'Poppins';

  // Font sizes
  static const double baseTitleFontSize = 24.0;
  static const double baseSubtitleFontSize = 16.0;
  static const double baseButtonFontSize = 15.0;
  static const double baseLinkFontSize = 14.0;

  static const double baseErrorFontSize = 12.0;
  static const double baseTipTitleFontSize = 14.0;
  static const double baseTipDescFontSize = 12.0;

  // Font weights
  static const FontWeight titleFontWeight = FontWeight.w600;
  static const FontWeight subtitleFontWeight = FontWeight.w400;
  static const FontWeight buttonFontWeight = FontWeight.w500;


  // Color scheme (matching LoginPage)
  static const Color primaryColor = Color.fromARGB(255, 8, 121, 11);
  static const Color linkColor = Color.fromARGB(255, 0, 81, 255);
  static final Color textPrimaryColor = Colors.grey[800]!;
  static final Color textSecondaryColor = Colors.grey[600]!;
  static final Color errorColor = Colors.red[400]!;
  static const Color successColor = Color.fromARGB(255, 8, 121, 11);

  // Error duration constant
  static const Duration errorDuration = Duration(seconds: 10);

  // Set error with timer methods
  void _setEmailError(String error) {
    _emailErrorTimer?.cancel();
    setState(() => _emailError = error);
    _emailErrorTimer = Timer(errorDuration, () {
      if (mounted) {
        setState(() => _emailError = null);
      }
    });
  }

  void _setGeneralError(String error) {
    _generalErrorTimer?.cancel();
    setState(() => _generalError = error);
    _generalErrorTimer = Timer(errorDuration, () {
      if (mounted) {
        setState(() => _generalError = null);
      }
    });
  }

  // Clear all errors and timers
  void _clearErrors() {
    _emailErrorTimer?.cancel();
    _generalErrorTimer?.cancel();
    setState(() {
      _emailError = null;
      _generalError = null;
    });
  }

  // Validate email
  bool _validateEmail(String email) {
    if (email.trim().isEmpty) {
      _setEmailError('Please enter your email address');
      return false;
    }

    if (!_isValidEmail(email.trim())) {
      _setEmailError('Please enter a valid email address');
      return false;
    }

    _emailErrorTimer?.cancel();
    setState(() => _emailError = null);
    return true;
  }

  // Send password reset email
  void sendPasswordResetEmail() async {
    _clearErrors();

    // Validate email
    bool isEmailValid = _validateEmail(emailController.text);

    if (!isEmailValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      // Clear the email field
      emailController.clear();

      // Show success dialog
      if (mounted) {
        _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _setEmailError('No account found with this email address');
          break;
        case 'invalid-email':
          _setEmailError('Invalid email address format');
          break;
        case 'too-many-requests':
          _setGeneralError('Too many requests. Please try again later');
          break;
        case 'network-request-failed':
          _setGeneralError('Network error. Please check your connection');
          break;
        default:
          _setGeneralError(
            e.message ?? 'Failed to send reset email. Please try again',
          );
      }
    } catch (e) {
      _setGeneralError('An unexpected error occurred. Please try again');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Email validation helper
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Build error text widget with animation
  Widget _buildErrorText(String? error, double fontSizeMultiplier) {
    if (error == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(left: 20, top: 8, right: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: errorColor, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontFamily: primaryFontFamily,
                fontSize: baseErrorFontSize * fontSizeMultiplier,
                fontWeight: FontWeight.w500,
                color: errorColor,
                height: 1.4,
              ),
            ),
          ),
          // Dismiss button
          GestureDetector(
            onTap: () {
              if (error == _emailError) {
                _emailErrorTimer?.cancel();
                setState(() => _emailError = null);
              }
            },
            child: Icon(
              Icons.close,
              color: errorColor.withOpacity(0.7),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Build general error widget with animation
  Widget _buildGeneralError(double fontSizeMultiplier) {
    if (_generalError == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: errorColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.warning_rounded, color: errorColor, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _generalError!,
              style: TextStyle(
                fontFamily: primaryFontFamily,
                fontSize: baseErrorFontSize * fontSizeMultiplier + 1,
                fontWeight: FontWeight.w600,
                color: errorColor,
                height: 1.4,
              ),
            ),
          ),
          // Dismiss button
          GestureDetector(
            onTap: () {
              _generalErrorTimer?.cancel();
              setState(() => _generalError = null);
            },
            child: Icon(
              Icons.close,
              color: errorColor.withOpacity(0.7),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced Success Dialog with Professional UI Design
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder:
          (context) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420, minWidth: 320),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.grey.shade50],
                    stops: const [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: successColor.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      spreadRadius: 0,
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: successColor.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Success Icon with Enhanced Design
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              successColor.withOpacity(0.1),
                              successColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: successColor.withOpacity(0.2),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: successColor.withOpacity(0.15),
                              spreadRadius: 0,
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.mark_email_read_rounded,
                          color: successColor,
                          size: 40,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Success Title with Enhanced Typography
                      Text(
                        'Reset Link Sent!',
                        style: TextStyle(
                          fontFamily: primaryFontFamily,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textPrimaryColor,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      // Success Subtitle
                      Text(
                        'Check Your Email',
                        style: TextStyle(
                          fontFamily: primaryFontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: successColor,
                          letterSpacing: 0.1,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      // Enhanced Message with Better Styling
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: textSecondaryColor,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'We\'ve sent a password reset link to your email address. Please check your inbox and follow the instructions to reset your password.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: primaryFontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: textSecondaryColor,
                                height: 1.5,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Don\'t forget to check your spam folder!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: primaryFontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange.shade700,
                                height: 1.4,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Enhanced Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: successColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: successColor.withOpacity(0.4),
                            overlayColor: Colors.white.withOpacity(0.1),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            Navigator.pop(context); // Go back to login page
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_back_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Back to Sign In',
                                style: TextStyle(
                                  fontFamily: primaryFontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Secondary Action - Resend Email Button
                      // TextButton(
                      //   onPressed: () {
                      //     Navigator.pop(context); // Close dialog
                      //     //  implement a resend functionality here or dili na need
                      //   },
                      //   style: TextButton.styleFrom(
                      //     foregroundColor: textSecondaryColor,
                      //     padding: const EdgeInsets.symmetric(
                      //       horizontal: 24,
                      //       vertical: 12,
                      //     ),
                      //     shape: RoundedRectangleBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //     ),
                      //   ),
                      //   child: Row(
                      //     mainAxisAlignment: MainAxisAlignment.center,
                      //     mainAxisSize: MainAxisSize.min,
                      //     children: [
                      //       Icon(
                      //         Icons.refresh_rounded,
                      //         size: 16,
                      //         color: textSecondaryColor,
                      //       ),
                      //       const SizedBox(width: 8),
                      //       Text(
                      //         'Resend Email',
                      //         style: TextStyle(
                      //           fontFamily: primaryFontFamily,
                      //           fontSize: 14,
                      //           fontWeight: FontWeight.w500,
                      //           letterSpacing: 0.1,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    // Cancel all timers
    _emailErrorTimer?.cancel();
    _generalErrorTimer?.cancel();

    emailController.dispose();
    super.dispose();
  }

  Widget _buildForgotPasswordForm({
    double maxWidth = double.infinity,
    double horizontalPadding = 16.0,
    double iconSize = 80,
    double fontSizeMultiplier = 1.0,
    double buttonPadding = 16,
    bool showSecurityTips = true,
    required double availableHeight,
  }) {
    // Calculate responsive spacing based on available height
    final baseSpacing = availableHeight * 0.02; // 2% of screen height
    final sectionSpacing = availableHeight * 0.025; // 2.5% of screen height
    final largeSpacing = availableHeight * 0.04; // 4% of screen height

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top spacing
            SizedBox(height: largeSpacing),

            // Lock reset icon
            Icon(Icons.lock_reset, size: iconSize, color: primaryColor),

            SizedBox(height: sectionSpacing),

            // Title
            Text(
              "Forgot Your Password?",
              style: TextStyle(
                fontFamily: primaryFontFamily,
                fontSize: baseTitleFontSize * fontSizeMultiplier,
                fontWeight: titleFontWeight,
                color: textPrimaryColor,
                letterSpacing: -0.3,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: baseSpacing),

            // Subtitle
            Text(
              "Enter your email address and we'll send you a link to reset your password.",
              style: TextStyle(
                fontFamily: primaryFontFamily,
                fontSize: baseSubtitleFontSize * fontSizeMultiplier,
                fontWeight: subtitleFontWeight,
                color: textSecondaryColor,
                letterSpacing: 0.1,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: sectionSpacing * 1.5),

            // General error message
            _buildGeneralError(fontSizeMultiplier),

            // Email Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  fontFamily: primaryFontFamily,
                  fontSize: baseSubtitleFontSize * fontSizeMultiplier,
                  fontWeight: subtitleFontWeight,
                  color: textPrimaryColor,
                  letterSpacing: 0.1,
                ),
                decoration: InputDecoration(
                  hintText: "Enter your email",
                  hintStyle: TextStyle(
                    fontFamily: primaryFontFamily,
                    fontSize: baseSubtitleFontSize * fontSizeMultiplier,
                    fontWeight: subtitleFontWeight,
                    color: textSecondaryColor,
                    letterSpacing: 0.1,
                  ),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: textSecondaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: buttonPadding,
                  ),
                ),
              ),
            ),
            _buildErrorText(_emailError, fontSizeMultiplier),

            SizedBox(height: sectionSpacing),

            // Reset Password Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    textStyle: TextStyle(
                      fontFamily: primaryFontFamily,
                      fontSize: baseButtonFontSize * fontSizeMultiplier,
                      fontWeight: buttonFontWeight,
                      letterSpacing: 0.3,
                      height: 1.2,
                    ),
                    elevation: 2,
                    shadowColor: primaryColor.withOpacity(0.3),
                  ),
                  onPressed: _isLoading ? null : sendPasswordResetEmail,
                  child:
                      _isLoading
                          ? SizedBox(
                            width: 20 * fontSizeMultiplier,
                            height: 20 * fontSizeMultiplier,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.0,
                            ),
                          )
                          : const Text("Send Reset Link"),
                ),
              ),
            ),

            SizedBox(height: sectionSpacing),

            // Remember Password Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Remember your password? ",
                  style: TextStyle(
                    fontFamily: primaryFontFamily,
                    color: textSecondaryColor,
                    fontSize: baseLinkFontSize * fontSizeMultiplier,
                    fontWeight: subtitleFontWeight,
                    height: 1.3,
                    letterSpacing: 0.1,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    "Back to Login",
                    style: TextStyle(
                      fontFamily: primaryFontFamily,
                      color: linkColor,
                      fontWeight: buttonFontWeight,
                      fontSize: baseLinkFontSize * fontSizeMultiplier,
                      letterSpacing: 0.2,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),

            if (showSecurityTips) ...[
              SizedBox(height: sectionSpacing * 1.5),

              // Security Tips Section (only show on larger screens)
              _buildSecurityTipsSection(fontSizeMultiplier),
            ],

            // Bottom spacing
            SizedBox(height: largeSpacing),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTipsSection(double fontSizeMultiplier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  "Password Security Tips",
                  style: TextStyle(
                    fontFamily: primaryFontFamily,
                    fontSize: (baseTipTitleFontSize + 4) * fontSizeMultiplier,
                    fontWeight: titleFontWeight,
                    color: Colors.blue[800],
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tip 1
            _buildSecurityTip(
              icon: Icons.lock_outline,
              title: "Use Strong Passwords",
              description:
                  "Create passwords with at least 8 characters, including uppercase, lowercase, numbers, and special characters.",
              fontSizeMultiplier: fontSizeMultiplier,
            ),

            const SizedBox(height: 12),

            // Tip 2
            _buildSecurityTip(
              icon: Icons.vpn_key_outlined,
              title: "Don’t Share Passwords",
              description:
                  "Keep your password private and avoid sharing it with anyone.",
              fontSizeMultiplier: fontSizeMultiplier,
            ),

            const SizedBox(height: 12),

            // Tip 3
            _buildSecurityTip(
              icon: Icons.refresh,
              title: "Update Passwords Regularly",
              description:
                  "Change your passwords periodically and avoid reusing the same password across multiple accounts.",
              fontSizeMultiplier: fontSizeMultiplier,
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for security tips
  Widget _buildSecurityTip({
    required IconData icon,
    required String title,
    required String description,
    required double fontSizeMultiplier,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[700], size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: primaryFontFamily,
                  fontSize: baseTipTitleFontSize * fontSizeMultiplier,
                  fontWeight: buttonFontWeight,
                  color: Colors.blue[800],
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontFamily: primaryFontFamily,
                  fontSize: baseTipDescFontSize * fontSizeMultiplier,
                  color: Colors.grey[700],
                  height: 1.3,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Mobile Screen
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: _buildForgotPasswordForm(
                    availableHeight: constraints.maxHeight,
                    iconSize: constraints.maxHeight * 0.08,
                    fontSizeMultiplier: 0.95,
                    buttonPadding: 18,
                    showSecurityTips: true,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Tablet Screen
  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight * 0.9,
                  ),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(32.0),
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            spreadRadius: 2,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildForgotPasswordForm(
                        maxWidth: 480,
                        horizontalPadding: 0,
                        availableHeight: constraints.maxHeight * 0.8,
                        iconSize: constraints.maxHeight * 0.1,
                        fontSizeMultiplier: 1.0,
                        buttonPadding: 20,
                        showSecurityTips: true,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Desktop Screen
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight * 0.9,
                  ),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(40.0),
                      padding: const EdgeInsets.only(
                        left: 50.0,
                        right: 50.0,
                        bottom: 40,
                        top: 20,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 3,
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _buildForgotPasswordForm(
                        maxWidth: 420,
                        horizontalPadding: 0,
                        availableHeight: constraints.maxHeight * 0.8,
                        iconSize: constraints.maxHeight * 0.12,
                        fontSizeMultiplier: 1.0,
                        buttonPadding: 22,
                        showSecurityTips: true,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBody: _buildMobileLayout(),
      tabletBody: _buildTabletLayout(),
      desktopBody: _buildDesktopLayout(),
    );
  }
}
