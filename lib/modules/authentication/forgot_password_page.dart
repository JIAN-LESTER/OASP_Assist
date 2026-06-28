import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:capstone_project/services/auth_email_service.dart';

import 'onboarding/green_snow_animation.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _snowController;
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
      await AuthEmailService().sendPasswordReset(emailController.text.trim());

      // Clear the email field
      emailController.clear();

      // Show success dialog
      if (mounted) {
        _showSuccessDialog();
      }
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'not-found':
          _setEmailError('No account found with this email address');
          break;
        case 'invalid-argument':
          _setEmailError('Invalid email address format');
          break;
        case 'resource-exhausted':
          _setGeneralError('Too many requests. Please try again later');
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
  void initState() {
    super.initState();
    _snowController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    );
  }

  @override
  void dispose() {
    // Cancel all timers
    _emailErrorTimer?.cancel();
    _generalErrorTimer?.cancel();

    _snowController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Widget _buildForgotPasswordForm({
    required double maxWidth,
    required double horizontalPadding,
    required double iconSize,
    required double titleFontSize,
    required double descriptionFontSize,
    required double cardPadding,
    bool useFormCard = false,
    double buttonPadding = 16,
    bool showSecurityTips = true,
  }) {
    final fontSizeMultiplier = descriptionFontSize / baseButtonFontSize;
    final formContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Forgot Your Password?",
          style: TextStyle(
            fontFamily: primaryFontFamily,
            fontSize: titleFontSize * 0.82,
            fontWeight: FontWeight.w800,
            color: textPrimaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your email address and we'll send you a link to reset your password.",
          style: TextStyle(
            fontFamily: primaryFontFamily,
            fontSize: descriptionFontSize * 0.95,
            fontWeight: FontWeight.w400,
            color: textSecondaryColor,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildGeneralError(fontSizeMultiplier),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => sendPasswordResetEmail(),
          style: TextStyle(
            fontFamily: primaryFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
          decoration: InputDecoration(
            hintText: "Enter your email",
            hintStyle: TextStyle(
              color: textSecondaryColor.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(Icons.email_outlined, color: textSecondaryColor),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _emailError != null ? errorColor : Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _emailError != null ? errorColor : Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _emailError != null ? errorColor : Colors.grey.shade400,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        _buildErrorText(_emailError, fontSizeMultiplier),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              disabledBackgroundColor: Colors.grey[300],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: buttonPadding),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : sendPasswordResetEmail,
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
                      "Send Reset Link",
                      style: TextStyle(
                        fontFamily: primaryFontFamily,
                        fontSize: descriptionFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              "Remember your password? ",
              style: TextStyle(
                fontFamily: primaryFontFamily,
                color: textSecondaryColor,
                fontSize: descriptionFontSize * 0.9,
                fontWeight: FontWeight.w400,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                "Back to Login",
                style: TextStyle(
                  fontFamily: primaryFontFamily,
                  color: linkColor,
                  fontWeight: FontWeight.w600,
                  fontSize: descriptionFontSize * 0.9,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    final maxLogoSize = MediaQuery.sizeOf(context).shortestSide * 0.28;
    final effectiveIconSize = iconSize > maxLogoSize ? maxLogoSize : iconSize;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 40,
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: effectiveIconSize,
              height: effectiveIconSize,
              child: Transform.scale(
                scale: 1.5,
                child: Transform.translate(
                  offset: Offset(0, effectiveIconSize * 0.14),
                  child: Image.asset(
                    'lib/images/oasp.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.smart_toy_outlined,
                        color: primaryColor,
                        size: effectiveIconSize * 0.5,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "OASP Assist",
              style: TextStyle(
                fontFamily: primaryFontFamily,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w800,
                color: textPrimaryColor,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            useFormCard
                ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0F0E4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: formContent,
                )
                : formContent,
            if (showSecurityTips) ...[
              const SizedBox(height: 16),
              _buildSecurityTipsSection(fontSizeMultiplier),
            ],
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

  Widget _buildDecoratedBody({required Widget child}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE7F6EC),
            Color(0xFFF8FAFC),
            Color(0xFFEAF1FF),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -70,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -80,
            child: Container(
              width: 210,
              height: 210,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x223B82F6),
              ),
            ),
          ),
          GreenSnowAnimation(
            animation: _snowController,
            color: primaryColor,
            flakeCount: 18,
          ),
          child,
        ],
      ),
    );
  }

  // Mobile Screen
  Widget _buildMobileLayout() {
    return _buildDecoratedBody(
      child: Center(
        child: _buildForgotPasswordForm(
          maxWidth: double.infinity,
          horizontalPadding: 20,
          iconSize: 140,
          titleFontSize: 26,
          descriptionFontSize: 14,
          cardPadding: 20,
          buttonPadding: 18,
          useFormCard: true,
          showSecurityTips: true,
        ),
      ),
    );
  }

  // Tablet Screen
  Widget _buildTabletLayout() {
    return _buildDecoratedBody(
      child: Center(
        child: _buildForgotPasswordForm(
          maxWidth: 500,
          horizontalPadding: 32,
          iconSize: 145,
          titleFontSize: 28,
          descriptionFontSize: 15,
          cardPadding: 32,
          buttonPadding: 18,
          useFormCard: true,
          showSecurityTips: true,
        ),
      ),
    );
  }

  // Desktop Screen
  Widget _buildDesktopLayout() {
    return _buildDecoratedBody(
      child: Center(
        child: _buildForgotPasswordForm(
          maxWidth: 480,
          horizontalPadding: 40,
          iconSize: 155,
          titleFontSize: 32,
          descriptionFontSize: 16,
          cardPadding: 40,
          buttonPadding: 18,
          useFormCard: true,
          showSecurityTips: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF1FF),
      body: SafeArea(
        child: ResponsiveLayout(
          mobileBody: _buildMobileLayout(),
          tabletBody: _buildTabletLayout(),
          desktopBody: _buildDesktopLayout(),
        ),
      ),
    );
  }
}
