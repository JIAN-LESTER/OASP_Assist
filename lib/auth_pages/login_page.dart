import 'dart:io';

import 'package:capstone_project/components/number_tile.dart';
import 'package:capstone_project/components/textfield.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../components/square_tile.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _generalError;
  String? _verificationError;

  // Timers for error handling
  Timer? _emailErrorTimer;
  Timer? _passwordErrorTimer;
  Timer? _generalErrorTimer;
  Timer? _verificationErrorTimer;

  // FONT CONFIGURATION
  static const String primaryFontFamily = 'Poppins';

  //  font sizes
  static const double baseTitleFontSize = 28.0;
  static const double baseSubtitleFontSize = 16.0;
  static const double baseButtonFontSize = 15.0;
  static const double baseLinkFontSize = 14.0;
  static const double baseLabelFontSize = 13.0;
  static const double baseErrorFontSize = 12.0;

  // font weights
  static const FontWeight titleFontWeight = FontWeight.w600;
  static const FontWeight subtitleFontWeight = FontWeight.w400;
  static const FontWeight buttonFontWeight = FontWeight.w500;
  static const FontWeight linkFontWeight = FontWeight.w500;
  static const FontWeight labelFontWeight = FontWeight.w400;

  // Color scheme
  static const Color primaryColor = Color.fromARGB(255, 8, 121, 11);
  static const Color linkColor = Color.fromARGB(255, 0, 81, 255);
  static final Color textPrimaryColor = Colors.grey[800]!;
  static final Color textSecondaryColor = Colors.grey[600]!;
  static final Color errorColor = Colors.red[400]!;

  // Error duration constant
  static const Duration errorDuration = Duration(seconds: 10);

  // Set error with timer
  void _setEmailError(String error) {
    _emailErrorTimer?.cancel();
    setState(() => _emailError = error);
    _emailErrorTimer = Timer(errorDuration, () {
      if (mounted) {
        setState(() => _emailError = null);
      }
    });
  }

  void _setPasswordError(String error) {
    _passwordErrorTimer?.cancel();
    setState(() => _passwordError = error);
    _passwordErrorTimer = Timer(errorDuration, () {
      if (mounted) {
        setState(() => _passwordError = null);
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

  void _setVerificationError(String error) {
    _verificationErrorTimer?.cancel();
    setState(() => _verificationError = error);
    _verificationErrorTimer = Timer(errorDuration, () {
      if (mounted) {
        setState(() => _verificationError = null);
      }
    });
  }

  // Clear all errors and timers
  void _clearErrors() {
    _emailErrorTimer?.cancel();
    _passwordErrorTimer?.cancel();
    _generalErrorTimer?.cancel();
    _verificationErrorTimer?.cancel();
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
      _verificationError = null;
    });
  }

  // Validate email
  bool _validateEmail(String email) {
    if (email.trim().isEmpty) {
      _setEmailError('Please enter your email');
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

  // Validate password
  bool _validatePassword(String password) {
    if (password.isEmpty) {
      _setPasswordError('Please enter your password');
      return false;
    }

    _passwordErrorTimer?.cancel();
    setState(() => _passwordError = null);
    return true;
  }

  // Sign in Method
  void signUserIn() async {
    _clearErrors();

    bool isEmailValid = _validateEmail(emailController.text);
    bool isPasswordValid = _validatePassword(passwordController.text);

    if (!isEmailValid || !isPasswordValid) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );

      final user = userCredential.user;
      if (user == null) {
        throw Exception("Sign in failed - no user returned");
      }

      // Check email verification
      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() => _isLoading = false);
          _setVerificationError(
            'Please verify your email before signing in. Check your inbox or spam folder.',
          );
        }
        return;
      }

      // Update Firestore verification status
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'isVerified': true,
            'emailVerified': true,
            'verifiedAt': FieldValue.serverTimestamp(),
          });

      print("Sign in successful");
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");

      switch (e.code) {
        case 'user-not-found':
          _setEmailError('No user found with this email');
          break;
        case 'wrong-password':
          _setPasswordError('Incorrect password');
          break;
        case 'invalid-email':
          _setEmailError('Invalid email address');
          break;
        case 'user-disabled':
          _setGeneralError('This account has been disabled');
          break;
        case 'too-many-requests':
          _setGeneralError('Too many failed attempts. Try again later');
          break;
        case 'invalid-credential':
          _setGeneralError('Invalid email or password');
          break;
        case 'network-request-failed':
          _setGeneralError('Network error. Please check your connection');
          break;
        default:
          _setGeneralError(e.message ?? 'Login failed. Please try again');
      }
    } catch (e) {
      print("General Error: $e");
      _setGeneralError('An unexpected error occurred. Please try again');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
              } else if (error == _passwordError) {
                _passwordErrorTimer?.cancel();
                setState(() => _passwordError = null);
              } else if (error == _verificationError) {
                _verificationErrorTimer?.cancel();
                setState(() => _verificationError = null);
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

  @override
  void dispose() {
    // Cancel all timers
    _emailErrorTimer?.cancel();
    _passwordErrorTimer?.cancel();
    _generalErrorTimer?.cancel();
    _verificationErrorTimer?.cancel();

    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Widget _buildLoginForm({
    double maxWidth = double.infinity,
    double horizontalPadding = 16.0,
    double iconSize = 100,
    double fontSizeMultiplier = 1.0,
    double buttonPadding = 16,
    required double availableHeight,
  }) {
    // Calculate responsive spacing based on available height
    final baseSpacing = availableHeight * 0.02;
    final sectionSpacing = availableHeight * 0.025;
    final largeSpacing = availableHeight * 0.04;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top spacing (flexible)
            SizedBox(height: largeSpacing),

            SizedBox(
              width: 120,
              height: 120,
              child: Image.asset(
                'lib/images/oasp.png',
                fit: BoxFit.contain, // or BoxFit.cover / BoxFit.fitWidth
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.smart_toy_outlined,
                    color: Color(0xFF2E7D32),
                    size: 100, // optional smaller icon size
                  );
                },
              ),
            ),
            SizedBox(height: sectionSpacing),

            Text(
              "Welcome to OASP Assist",
              style: TextStyle(
                fontFamily: primaryFontFamily,
                fontSize: baseTitleFontSize * fontSizeMultiplier,
                fontWeight: titleFontWeight,
                color: textPrimaryColor,
                letterSpacing: -0.3,
                height: 1.2,
              ),
            ),

            SizedBox(height: baseSpacing * 0.5),

            Text(
              "Sign in to continue",
              style: TextStyle(
                fontFamily: primaryFontFamily,
                fontSize: baseSubtitleFontSize * fontSizeMultiplier,
                fontWeight: subtitleFontWeight,
                color: textSecondaryColor,
                letterSpacing: 0.1,
                height: 1.3,
              ),
            ),

            SizedBox(height: sectionSpacing),

            // General error message
            _buildGeneralError(fontSizeMultiplier),

            // Verification error message (above email field)
            _buildErrorText(_verificationError, fontSizeMultiplier),

            // Email field
            Textfield(
              controller: emailController,
              hintText: "Email",
              obscureText: false,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => signUserIn(),
            ),
            _buildErrorText(_emailError, fontSizeMultiplier),

            SizedBox(height: baseSpacing * 0.5),

            Textfield(
              controller: passwordController,
              hintText: "Password",
              obscureText: true,
              isPasswordField: true,
              onSubmitted: (_) => signUserIn(),
            ),
            _buildErrorText(_passwordError, fontSizeMultiplier),

            SizedBox(height: baseSpacing),

            // Forgot Password
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        fontFamily: primaryFontFamily,
                        color: linkColor,
                        fontWeight: linkFontWeight,
                        fontSize: baseLinkFontSize * fontSizeMultiplier,
                        letterSpacing: 0.1,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: sectionSpacing),

            // Sign In Button
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  onPressed: _isLoading ? null : signUserIn,
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
                          : const Text("Sign In"),
                ),
              ),
            ),

            SizedBox(height: sectionSpacing),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(thickness: 1, color: Colors.grey[350]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "OR",
                      style: TextStyle(
                        fontFamily: primaryFontFamily,
                        color: textSecondaryColor,
                        fontSize: baseLabelFontSize * fontSizeMultiplier,
                        fontWeight: labelFontWeight,
                        letterSpacing: 1.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(thickness: 1, color: Colors.grey[350]),
                  ),
                ],
              ),
            ),

            SizedBox(height: baseSpacing),
            if (!(!kIsWeb &&
                (Platform.isWindows ||
                    Platform.isLinux ||
                    Platform.isMacOS))) ...[
              const SquareTile(imagePath: 'lib/images/google.png'),
              SizedBox(height: sectionSpacing),
            ],

            // Sign Up Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  child: Text(
                    "Sign Up",
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

            // Bottom spacing (flexible)
            SizedBox(height: largeSpacing),
          ],
        ),
      ),
    );
  }

  // Mobile Screen
  Widget _buildMobileLayout() {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: _buildLoginForm(
                  availableHeight: constraints.maxHeight,
                  iconSize: constraints.maxHeight * 0.08,
                  fontSizeMultiplier: 0.95,
                  buttonPadding: 18,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Tablet Screen
  Widget _buildTabletLayout() {
    return SafeArea(
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
                      border: Border.all(color: Colors.grey.shade300, width: 1),
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
                    child: _buildLoginForm(
                      maxWidth: 480,
                      horizontalPadding: 0,
                      availableHeight: constraints.maxHeight * 0.8,
                      iconSize: constraints.maxHeight * 0.1,
                      fontSizeMultiplier: 1.0,
                      buttonPadding: 20,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Desktop Screen
  Widget _buildDesktopBody() {
    return SafeArea(
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
                      border: Border.all(color: Colors.grey.shade300, width: 1),
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
                    child: _buildLoginForm(
                      maxWidth: 420,
                      horizontalPadding: 0,
                      availableHeight: constraints.maxHeight * 0.8,
                      iconSize: constraints.maxHeight * 0.12,
                      fontSizeMultiplier: 1.0,
                      buttonPadding: 22,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
        desktopBody: _buildDesktopBody(),
      ),
    );
  }
}
