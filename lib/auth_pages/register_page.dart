import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const double baseTitleFontSize = 28.0; // Slightly smaller
  static const double baseSubtitleFontSize = 16.0; // More readable
  static const double baseButtonFontSize = 15.0; // Professional button text
  static const double baseLinkFontSize = 14.0; // Consistent with inputs
  static const double baseLabelFontSize = 13.0; // Subtle labels
  static const double baseErrorFontSize = 12.0; // Clear error messages

  // Professional font weights - Updated to match login page
  static const FontWeight titleFontWeight =
      FontWeight.w600; // Less bold, more refined
  static const FontWeight subtitleFontWeight = FontWeight.w400;
  static const FontWeight buttonFontWeight = FontWeight.w500; // Medium weight
  static const FontWeight linkFontWeight = FontWeight.w500;
  static const FontWeight labelFontWeight = FontWeight.w400;
  // ======================================================

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
        .get(const GetOptions(source: Source.cache)); // Try cache first
    
    if (snapshot.docs.isEmpty) {
      // If cache is empty, fetch from server
      // Note: You may need to update Firestore rules to allow public read for programs
      final serverSnapshot = await FirebaseFirestore.instance
          .collection('programs')
          .get();
      
      setState(() {
        _programs.addAll(serverSnapshot.docs.map((doc) => doc['name'] as String));
      });
    } else {
      setState(() {
        _programs.addAll(snapshot.docs.map((doc) => doc['name'] as String));
      });
    }
  } catch (e) {
    print('Error fetching programs: $e');
    // Don't block registration if programs can't be fetched
    // Programs list will just show 'N/A'
  }
}

void registerUser() async {
  _clearErrors();
  print('🟢 Starting registration process...');

  // Validate fields
  bool isEmailValid = _validateEmail(emailController.text);
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
    print('👤 Step 1: Creating user account...');
    
    // Create the user account
    UserCredential userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text,
        );

    print('✅ Firebase user created successfully');
    
    final user = userCredential.user;
    if (user == null) throw Exception("User creation failed");

    print('🔑 User UID: ${user.uid}');
    print('📧 User Email: ${user.email}');

    final name = emailController.text.split('@').first;
    print('📝 User name extracted: $name');

    // Step 2: Save to Firestore IMMEDIATELY (while user is still authenticated)
    print('📁 Step 2: Saving user data to Firestore...');
    
    // First, ensure user is fully authenticated
    await Future.delayed(const Duration(milliseconds: 500));
    await user.reload();
    
    final userData = {
      'uid': user.uid,
      'email': user.email ?? '',
      'name': name,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
      'firstLogin': true,
      'isActive': true,
      'profileCompleted': false,
      'onboardingCompleted': false,
      'isVerified': false, // Set to false initially
    };

    print('📦 Data to save: $userData');
    print('🔐 Auth token check: ${user.uid}');

    try {
      // Test Firestore connection first
      print('🔍 Testing Firestore connection...');
      
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      
      print('📝 Writing to Firestore...');
      
      await docRef.set(userData, SetOptions(merge: false)).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Firestore write operation timed out after 20 seconds');
        },
      );
      
      print('✅ Successfully wrote to Firestore');
      
      // Verify the write
      print('🔍 Verifying write...');
      final snapshot = await docRef.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Firestore read verification timed out'),
      );
      
      if (snapshot.exists) {
        print('✅ Write verified - document exists');
      } else {
        print('⚠️ Warning: Document write may not have completed');
      }
      
    } catch (firestoreError) {
      print('❌ Firestore write error: $firestoreError');
      print('❌ Error type: ${firestoreError.runtimeType}');
      
      if (firestoreError is FirebaseException) {
        print('❌ Firebase error code: ${firestoreError.code}');
        print('❌ Firebase error message: ${firestoreError.message}');
        print('❌ Firebase error plugin: ${firestoreError.plugin}');
      }
      
      if (firestoreError is TimeoutException) {
        print('⚠️ This is a network/connectivity timeout issue');
        print('⚠️ Check: 1) Internet connection 2) Firestore rules 3) Firebase initialization');
      }
      
      rethrow;
    }

    // Step 3: Send verification email (with better error handling)
    print('📧 Step 3: Sending verification email...');
    bool emailSent = false;
    try {
      await user.sendEmailVerification().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ Email send timed out after 10 seconds');
          throw TimeoutException('Email verification timed out');
        },
      );
      print('✅ Verification email sent to: ${user.email}');
      emailSent = true;
    } catch (emailError) {
      print('⚠️ Email send error (continuing anyway): $emailError');
      print('⚠️ Error type: ${emailError.runtimeType}');
      // Continue even if email fails - user can resend later
    }

    // Step 4: Log registration event
    print('🪵 Step 4: Logging registration event...');
    try {
      await FirebaseFirestore.instance.collection('logs').add({
        'user': name,
        'action': 'Registered account (pending verification)',
        'time': Timestamp.now(),
        'userId': user.uid,
      });
      print('✅ Registration event logged');
    } catch (logError) {
      print('⚠️ Logging error (continuing anyway): $logError');
    }

    // Step 5: Show dialog BEFORE signing out
    if (mounted) {
      setState(() => _isLoading = false);
      print('🟢 Registration complete — showing verification dialog');
      _showVerificationDialog(user);
    }

  } on FirebaseAuthException catch (e) {
    print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
    
    if (mounted) setState(() => _isLoading = false);
    
    switch (e.code) {
      case 'weak-password':
        _setPasswordError('The password provided is too weak');
        break;
      case 'email-already-in-use':
        _setEmailError('An account already exists for this email');
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
        _setGeneralError(e.message ?? 'Registration failed. Please try again');
    }
  } on FirebaseException catch (e) {
    print('❌ Firestore Error: ${e.code} - ${e.message}');
    
    if (mounted) setState(() => _isLoading = false);
    
    _setGeneralError('Failed to save user data. Please try again');
  } catch (e) {
    print('💥 General Error: $e');
    
    if (mounted) setState(() => _isLoading = false);
    
    _setGeneralError('An unexpected error occurred. Please try again');
  }
}

void _showVerificationDialog(User user) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: Colors.blue[700], size: 28),
            const SizedBox(width: 12),
            const Text('Verify Your Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A verification email has been sent to:',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, color: Colors.grey[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user.email ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please check your inbox or spam folder and click the verification link before signing in.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Resend Email'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
            onPressed: () async {
              try {
                await user.sendEmailVerification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('Verification email sent!')),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              } catch (e) {
                print('❌ Error resending email: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('Failed to resend email.')),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              }
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Continue to Sign In'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            onPressed: () async {
              print('🔵 Continue to Sign In button pressed');
              
              try {
                // Step 1: Close dialog first
                Navigator.of(context).pop();
                print('✅ Dialog closed');
                
                // Step 2: Sign out the user
                await FirebaseAuth.instance.signOut();
                print('✅ User signed out successfully');
                
                // Step 3: Clear form fields
                emailController.clear();
                passwordController.clear();
                confirmPasswordController.clear();
                print('✅ Form fields cleared');
                
                // Step 4: Small delay to let auth state settle
                await Future.delayed(const Duration(milliseconds: 300));
                
                if (context.mounted) {
                  // Step 5: Navigate back to login
                  Navigator.of(context).pop();
                  print('✅ Navigated back to login');
                  
                  // Step 6: Show success message
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Account created! Please verify your email before signing in.',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 6),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  });
                }
              } catch (e) {
                print('❌ Error during sign out process: $e');
                
                // Force sign out even on error
                try {
                  await FirebaseAuth.instance.signOut();
                } catch (signOutError) {
                  print('❌ Failed to force sign out: $signOutError');
                }
                
                // Still try to navigate
                if (context.mounted) {
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Account created but there was an issue. Please try signing in.'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
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
          // Dismiss button
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
      print('Verification email sent to ${user.email}');
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
  void _showSuccessDialog(String message) {
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
                          Icons.check_circle_rounded,
                          color: successColor,
                          size: 40,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Success Title with Enhanced Typography
                      Text(
                        'Welcome Aboard!',
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
                        'Account Created Successfully',
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
                        child: Text(
                          message,
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
                                Icons.login_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Continue to Sign In',
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
    // Calculate responsive spacing based on available height
    final baseSpacing = availableHeight * 0.015; // 1.5% of screen height
    final sectionSpacing = availableHeight * 0.02; // 2% of screen height
    final largeSpacing = availableHeight * 0.03; // 3% of screen height

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top spacing (flexible)
            SizedBox(height: largeSpacing),

            Icon(Icons.person_add, size: iconSize, color: primaryColor),

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

            // General error message
            _buildGeneralError(fontSizeMultiplier),

            // Email field
            Textfield(
              controller: emailController,
              hintText: "Email",
              obscureText: false,
              keyboardType: TextInputType.emailAddress,
            ),
            _buildErrorText(_emailError, fontSizeMultiplier),

            SizedBox(height: baseSpacing * 0.5),

            // Password field
            Textfield(
              controller: passwordController,
              hintText: "Password",
              obscureText: true,
              isPasswordField: true, // This enables the eye icon
            ),
            _buildErrorText(_passwordError, fontSizeMultiplier),

            SizedBox(height: baseSpacing * 0.5),

            // Confirm Password field
            Textfield(
              controller: confirmPasswordController,
              hintText: "Confirm Password",
              obscureText: true,
              isPasswordField: true, // This enables the eye icon
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

            // Google Sign-In Button
            const SquareTile(imagePath: 'lib/images/google.png'),
           

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
                    Navigator.pop(context); // Go back to login page
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

            // Bottom spacing (flexible)
            SizedBox(height: largeSpacing),
          ],
        ),
      ),
    );
  }

  // Mobile Screen - Updated with responsive layout
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
                  iconSize: constraints.maxHeight * 0.07, // 7% of screen height
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

  // Tablet Screen - Updated with responsive layout
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

  // Desktop Screen - Updated with responsive layout
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