import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../components/square_tile.dart';
import '../components/textfield.dart';
import '../responsive/responsive_layout.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final List<String> _programs = ['N/A'];

  bool _isLoading = false;

  // Error state variables
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _generalError;

  // Timers for error handling
  Timer? _emailErrorTimer;
  Timer? _passwordErrorTimer;
  Timer? _confirmPasswordErrorTimer;
  Timer? _generalErrorTimer;

  //  FONT CONFIGURATION - Updated to match login page exactly
  static const String primaryFontFamily = 'Poppins';

  //  font sizes - Updated to match login page
  static const double baseTitleFontSize = 28.0;
  static const double baseSubtitleFontSize = 16.0;
  static const double baseButtonFontSize = 15.0;
  static const double baseLinkFontSize = 14.0;
  static const double baseLabelFontSize = 13.0;
  static const double baseErrorFontSize = 12.0;

  // Professional font weights - Updated to match login page
  static const FontWeight titleFontWeight = FontWeight.w600;
  static const FontWeight subtitleFontWeight = FontWeight.w400;
  static const FontWeight buttonFontWeight = FontWeight.w500;
  static const FontWeight linkFontWeight = FontWeight.w500;
  static const FontWeight labelFontWeight = FontWeight.w400;

  // Color scheme - Updated to match login page
  static const Color primaryColor = Color.fromARGB(255, 8, 121, 11);
  static const Color linkColor = Color.fromARGB(255, 0, 81, 255);
  static final Color textPrimaryColor = Colors.grey[800]!;
  static final Color textSecondaryColor = Colors.grey[600]!;
  static final Color errorColor = Colors.red[400]!;
  static const Color successColor = Color.fromARGB(255, 8, 121, 11);

  final List<String> yearOptions = [
    'N/A',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  void _setPasswordError(String error) {
    _passwordErrorTimer?.cancel();
    setState(() => _passwordError = error);
    _passwordErrorTimer = Timer(errorDuration, () {
      if (mounted) {
        setState(() => _passwordError = null);
      }
    });
  }

  void _setConfirmPasswordError(String error) {
    _confirmPasswordErrorTimer?.cancel();
    setState(() => _confirmPasswordError = error);
    _confirmPasswordErrorTimer = Timer(errorDuration, () {
      if (mounted) {
        setState(() => _confirmPasswordError = null);
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
    _passwordErrorTimer?.cancel();
    _confirmPasswordErrorTimer?.cancel();
    _generalErrorTimer?.cancel();
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _generalError = null;
    });
  }

  void _submitWithEnter() {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    registerUser();
  }

  Future<bool> _isEmailTaken(String email) async {
    try {
      // Check Firebase Auth first (most authoritative source)
      try {
        // Use dynamic invocation to remain compatible with different firebase_auth SDK versions
        List<String> signInMethods = [];
        try {
          final result = await (FirebaseAuth.instance as dynamic)
              .fetchSignInMethodsForEmail(email.trim())
              .timeout(const Duration(seconds: 5));
          signInMethods = List<String>.from(result as List);
        } on NoSuchMethodError {
          // Method not available in this firebase_auth SDK version
          print(
            '⚠️ fetchSignInMethodsForEmail not available in firebase_auth SDK',
          );
        }

        // If Auth returns sign-in methods, email is actively used
        if (signInMethods.isNotEmpty) {
          print('✅ Email found in Firebase Auth: $email');
          return true;
        }

        print('⚠️ Email NOT in Firebase Auth: $email');
      } on FirebaseAuthException catch (e) {
        // If we get 'invalid-email', the email format is wrong
        if (e.code == 'invalid-email') {
          print('❌ Invalid email format: $email');
          return false;
        }
        // Other Auth errors - continue to Firestore check
        print('⚠️ Auth check error: ${e.code}');
      } catch (e) {
        print('⚠️ Auth check timeout/error: $e');
      }

      // If not in Auth, check Firestore (might be orphaned data)
      print('🔍 Checking Firestore for: $email');
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2))
          .catchError((_) async {
            return await _firestore
                .collection('users')
                .where('email', isEqualTo: email.trim())
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 3));
          });

      if (querySnapshot.docs.isNotEmpty) {
        print('⚠️ Email found in Firestore but not in Auth (orphaned): $email');

        // OPTIONAL: Clean up orphaned document
        try {
          final docId = querySnapshot.docs.first.id;
          await _firestore.collection('users').doc(docId).delete();
          print('🗑️ Cleaned up orphaned Firestore document for: $email');
          return false; // Email is now available
        } catch (e) {
          print('❌ Failed to cleanup orphaned doc: $e');
          // If we can't clean it up, consider it taken to be safe
          return true;
        }
      }

      print('✅ Email is available: $email');
      return false;
    } catch (e) {
      print('❌ Error checking email: $e');
      // On error, assume email is available to allow registration attempt
      return false;
    }
  }

  // Validate email
  Future<bool> _validateEmail(String email) async {
    if (email.trim().isEmpty) {
      _setEmailError('Please enter your email');
      return false;
    }

    if (!_isValidEmail(email.trim())) {
      _setEmailError('Please enter a valid email address');
      return false;
    }

    final isTaken = await _isEmailTaken(email.trim());
    if (isTaken) {
      _setEmailError('This email is already taken');
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

    if (password.length < 6) {
      _setPasswordError('Password must be at least 6 characters long');
      return false;
    }

    _passwordErrorTimer?.cancel();
    setState(() => _passwordError = null);
    return true;
  }

  // Validate confirm password
  bool _validateConfirmPassword(String password, String confirmPassword) {
    if (confirmPassword.isEmpty) {
      _setConfirmPasswordError('Please confirm your password');
      return false;
    }

    if (password != confirmPassword) {
      _setConfirmPasswordError('Passwords do not match');
      return false;
    }

    _confirmPasswordErrorTimer?.cancel();
    setState(() => _confirmPasswordError = null);
    return true;
  }

  @override
  void initState() {
    super.initState();
    _fetchPrograms(); // Fetch programs when modal is initialized
  }

  void _fetchPrograms() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('programs')
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2));

      if (snapshot.docs.isEmpty) {
        final serverSnapshot = await FirebaseFirestore.instance
            .collection('programs')
            .get()
            .timeout(const Duration(seconds: 3));

        setState(() {
          _programs.addAll(
            serverSnapshot.docs.map((doc) => doc['name'] as String),
          );
        });
      } else {
        setState(() {
          _programs.addAll(snapshot.docs.map((doc) => doc['name'] as String));
        });
      }
    } catch (e) {
      print('Error fetching programs: $e');
    }
  }

  // FULLY OPTIMIZED REGISTRATION METHOD
  void registerUser() async {
    _clearErrors();
    print('🟢 Starting registration process...');

    // Validate fields
    bool isEmailValid = await _validateEmail(emailController.text);
    bool isPasswordValid = _validatePassword(passwordController.text);
    bool isConfirmPasswordValid = _validateConfirmPassword(
      passwordController.text,
      confirmPasswordController.text,
    );

    if (!isEmailValid || !isPasswordValid || !isConfirmPasswordValid) {
      print('🔴 Validation failed');
      return;
    }

    setState(() => _isLoading = true);
    print('⏳ Loading state enabled');

    try {
      print('👤 Creating user account...');

      // Step 1: Create Firebase Auth user (fastest operation)
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          )
          .timeout(const Duration(seconds: 10));

      final user = userCredential.user;
      if (user == null) throw Exception("User creation failed");

      print('✅ User created: ${user.uid}');

      final name = emailController.text.split('@').first;

      // Prepare user data
      final userData = {
        'uid': user.uid,
        'email': user.email ?? '',
        'name': name,
        'role': 'user',
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'firstLogin': true,
        'isActive': true,
        'profileCompleted': false,
        'onboardingCompleted': false,
        'hasSeenOnboardingGuide': false,
        'isVerified': false,
        'linkedProviders': ['password'],
        'dailyMessageCount': 0,
        'lastMessageResetDate': FieldValue.serverTimestamp(),
      };

      // Step 2: Run ALL operations in parallel (MAXIMUM SPEED)
      print('🚀 Running parallel operations...');

      await Future.wait([
        // Operation 1: Save to Firestore
        _firestore
            .collection('users')
            .doc(user.uid)
            .set(userData, SetOptions(merge: false))
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => throw TimeoutException('Firestore timeout'),
            ),

        // Operation 2: Send verification email (non-blocking)
        user
            .sendEmailVerification()
            .timeout(
              const Duration(seconds: 6),
              onTimeout: () {
                print('⚠️ Email timeout (continuing)');
                return;
              },
            )
            .catchError((e) {
              print('⚠️ Email error (continuing): $e');
              return;
            }),
      ], eagerError: false); // Don't stop if one fails

      print('✅ Parallel operations completed');

      // Step 3: Fire-and-forget logging (don't wait)
      _firestore
          .collection('logs')
          .add({
            'user': name,
            'action': 'Registered account (pending verification)',
            'time': Timestamp.now(),
            'userId': user.uid,
          })
          .catchError((e) => print('⚠️ Log error: $e'));

      // Step 4: Show dialog immediately
      if (mounted) {
        setState(() => _isLoading = false);
        print('🟢 Registration complete');
        _showVerificationDialog(user);
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Auth Error: ${e.code}');

      if (mounted) setState(() => _isLoading = false);

      switch (e.code) {
        case 'weak-password':
          _setPasswordError('The password provided is too weak');
          break;
        case 'email-already-in-use':
          // More helpful message
          _setEmailError(
            'This email is already registered. Try signing in instead.',
          );
          break;
        case 'invalid-email':
          _setEmailError('Invalid email address');
          break;
        case 'operation-not-allowed':
          _setGeneralError('Email/password accounts are not enabled');
          break;
        case 'network-request-failed':
          _setGeneralError('Network error. Please check your connection');
          break;
        default:
          _setGeneralError(
            e.message ?? 'Registration failed. Please try again.',
          );
      }
    } on TimeoutException catch (e) {
      print('❌ Timeout: $e');

      if (mounted) setState(() => _isLoading = false);

      _setGeneralError('Connection timeout. Check your internet and retry');
    } catch (e) {
      print('❌ Error: $e');

      if (mounted) setState(() => _isLoading = false);

      _setGeneralError('Registration failed. Please try again');
    }
  }

  // ✅ FIXED: Email verification dialog with proper keyboard handling
  void _showVerificationDialog(User user) {
    final userEmail = user.email ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => WillPopScope(
            onWillPop: () async => false,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              // ✅ CRITICAL FIX: Wrap in MediaQuery to handle keyboard properly
              child: MediaQuery.removeViewInsets(
                removeBottom: false,
                context: context,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // ✅ Get screen size and keyboard height
                    final screenHeight = MediaQuery.of(context).size.height;
                    final keyboardHeight =
                        MediaQuery.of(context).viewInsets.bottom;
                    final isKeyboardVisible = keyboardHeight > 0;

                    // ✅ Calculate available height considering keyboard
                    final availableHeight = screenHeight - keyboardHeight;

                    final isSmallScreen =
                        MediaQuery.of(context).size.width < 400;

                    // ✅ ADAPTIVE sizing based on available height
                    final horizontalPadding = isSmallScreen ? 16.0 : 32.0;
                    final verticalPadding =
                        isKeyboardVisible
                            ? (isSmallScreen ? 16.0 : 20.0)
                            : (isSmallScreen ? 24.0 : 32.0);

                    final iconSize =
                        isKeyboardVisible
                            ? (isSmallScreen ? 48.0 : 56.0)
                            : (isSmallScreen ? 64.0 : 80.0);

                    final titleSize = isSmallScreen ? 18.0 : 22.0;
                    final bodySize = isSmallScreen ? 13.0 : 14.0;
                    final buttonHeight = isSmallScreen ? 46.0 : 52.0;

                    return SingleChildScrollView(
                      // ✅ CRITICAL: Allow scrolling when keyboard appears
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isSmallScreen ? 340 : 440,
                          // ✅ CRITICAL: Limit max height to prevent overflow
                          maxHeight: availableHeight * 0.9,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Success Icon - hide when keyboard is visible on small screens
                            if (!isKeyboardVisible || !isSmallScreen)
                              Container(
                                width: iconSize,
                                height: iconSize,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    iconSize / 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.mark_email_read_rounded,
                                  color: primaryColor,
                                  size: iconSize * 0.5,
                                ),
                              ),

                            SizedBox(
                              height:
                                  isKeyboardVisible
                                      ? 12
                                      : (isSmallScreen ? 20 : 24),
                            ),

                            // Title
                            Text(
                              'Verify Your Email',
                              style: TextStyle(
                                fontFamily: primaryFontFamily,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w600,
                                color: textPrimaryColor,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(height: isSmallScreen ? 6 : 10),

                            // Subtitle
                            Text(
                              'A verification email has been sent to:',
                              style: TextStyle(
                                fontFamily: primaryFontFamily,
                                fontSize: bodySize,
                                color: textSecondaryColor,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(height: isSmallScreen ? 12 : 16),

                            // Email display
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 14,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    color: primaryColor,
                                    size: isSmallScreen ? 16 : 18,
                                  ),
                                  SizedBox(width: isSmallScreen ? 8 : 10),
                                  Expanded(
                                    child: Text(
                                      userEmail,
                                      style: TextStyle(
                                        fontFamily: primaryFontFamily,
                                        fontSize: bodySize,
                                        color: textPrimaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 12 : 16),

                            // Info message - make more compact when keyboard visible
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.1),
                                ),
                              ),
                              child: Text(
                                'Please check your inbox or spam folder and click the verification link before signing in.',
                                style: TextStyle(
                                  fontFamily: primaryFontFamily,
                                  fontSize: bodySize - 1,
                                  color: textSecondaryColor,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            SizedBox(
                              height:
                                  isKeyboardVisible
                                      ? 16
                                      : (isSmallScreen ? 20 : 28),
                            ),

                            // Primary button - Continue to Sign In
                            SizedBox(
                              width: double.infinity,
                              height: buttonHeight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  print('🔵 Continue to Sign In pressed');

                                  try {
                                    // Sign out user
                                    await FirebaseAuth.instance.signOut();
                                    print('✅ User signed out');

                                    // Clear form fields
                                    emailController.clear();
                                    passwordController.clear();
                                    confirmPasswordController.clear();

                                    // Close dialog
                                    if (mounted) {
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop();

                                      // Navigate back to login
                                      await Future.delayed(
                                        const Duration(milliseconds: 150),
                                      );

                                      if (mounted) {
                                        Navigator.of(
                                          context,
                                        ).pop(); // return to login page

                                        // Show success message
                                        await Future.delayed(
                                          const Duration(milliseconds: 200),
                                        );

                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: const [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'Account created! Please verify your email.',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: const Duration(
                                                seconds: 5,
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    print('❌ Navigation error: $e');
                                    if (mounted) {
                                      try {
                                        Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).pop();
                                      } catch (_) {}
                                      try {
                                        Navigator.of(
                                          context,
                                        ).pop(); // return to login page
                                      } catch (_) {}
                                    }
                                  }
                                },
                                child: Text(
                                  'Continue to Sign In',
                                  style: TextStyle(
                                    fontFamily: primaryFontFamily,
                                    fontSize: bodySize + 1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 8 : 10),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
    );
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
          GestureDetector(
            onTap: () {
              if (error == _emailError) {
                _emailErrorTimer?.cancel();
                setState(() => _emailError = null);
              } else if (error == _passwordError) {
                _passwordErrorTimer?.cancel();
                setState(() => _passwordError = null);
              } else if (error == _confirmPasswordError) {
                _confirmPasswordErrorTimer?.cancel();
                setState(() => _confirmPasswordError = null);
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

  Future<void> sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
      print(
        'Verification email sent to ${user.email}. Please check your inbox or spam folder.',
      );
    }
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
    _emailErrorTimer?.cancel();
    _passwordErrorTimer?.cancel();
    _confirmPasswordErrorTimer?.cancel();
    _generalErrorTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildRegisterForm({
    double maxWidth = double.infinity,
    double horizontalPadding = 16.0,
    double iconSize = 100,
    double fontSizeMultiplier = 1.0,
    double buttonPadding = 16,
    required double availableHeight,
  }) {
    final baseSpacing = availableHeight * 0.015;
    final sectionSpacing = availableHeight * 0.02;
    final largeSpacing = availableHeight * 0.03;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              "Create Account",
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
              "Sign up to get started",
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
            _buildGeneralError(fontSizeMultiplier),
            Textfield(
              controller: emailController,
              hintText: "Email",
              obscureText: false,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _submitWithEnter(),
            ),
            _buildErrorText(_emailError, fontSizeMultiplier),

            SizedBox(height: baseSpacing * 0.5),

            Textfield(
              controller: passwordController,
              hintText: "Password",
              obscureText: true,
              isPasswordField: true,
              onSubmitted: (_) => _submitWithEnter(),
            ),
            _buildErrorText(_passwordError, fontSizeMultiplier),

            SizedBox(height: baseSpacing * 0.5),

            Textfield(
              controller: confirmPasswordController,
              hintText: "Confirm Password",
              obscureText: true,
              isPasswordField: true,
              onSubmitted: (_) => _submitWithEnter(),
            ),
            _buildErrorText(_confirmPasswordError, fontSizeMultiplier),

            SizedBox(height: baseSpacing * 0.5),
            SizedBox(height: sectionSpacing),

            // Sign Up Button
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
                  onPressed: _isLoading ? null : registerUser,
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
                          : const Text("Sign Up"),
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

            SizedBox(height: sectionSpacing),

            // Sign In Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Already have an account? ",
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
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Sign In",
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
                child: _buildRegisterForm(
                  availableHeight: constraints.maxHeight,
                  iconSize: constraints.maxHeight * 0.07,
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
                    child: _buildRegisterForm(
                      maxWidth: 480,
                      horizontalPadding: 0,
                      availableHeight: constraints.maxHeight * 0.8,
                      iconSize: constraints.maxHeight * 0.09,
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
                    child: _buildRegisterForm(
                      maxWidth: 420,
                      horizontalPadding: 0,
                      availableHeight: constraints.maxHeight * 0.8,
                      iconSize: constraints.maxHeight * 0.11,
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
