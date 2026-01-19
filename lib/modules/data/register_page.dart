import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/square_tile.dart';
import '../../responsive/responsive_layout.dart';

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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _generalError;

  Timer? _emailErrorTimer;
  Timer? _passwordErrorTimer;
  Timer? _confirmPasswordErrorTimer;
  Timer? _generalErrorTimer;

  static const String primaryFontFamily = 'Poppins';
  static const Color primaryColor = Color.fromARGB(255, 8, 121, 11);
  static const Color linkColor = Color.fromARGB(255, 0, 81, 255);
  static final Color textPrimaryColor = Colors.grey[800]!;
  static final Color textSecondaryColor = Colors.grey[600]!;
  static final Color errorColor = Colors.red[400]!;
  static const Duration errorDuration = Duration(seconds: 10);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _setEmailError(String error) {
    _emailErrorTimer?.cancel();
    setState(() => _emailError = error);
    _emailErrorTimer = Timer(errorDuration, () {
      if (mounted) setState(() => _emailError = null);
    });
  }

  void _setPasswordError(String error) {
    _passwordErrorTimer?.cancel();
    setState(() => _passwordError = error);
    _passwordErrorTimer = Timer(errorDuration, () {
      if (mounted) setState(() => _passwordError = null);
    });
  }

  void _setConfirmPasswordError(String error) {
    _confirmPasswordErrorTimer?.cancel();
    setState(() => _confirmPasswordError = error);
    _confirmPasswordErrorTimer = Timer(errorDuration, () {
      if (mounted) setState(() => _confirmPasswordError = null);
    });
  }

  void _setGeneralError(String error) {
    _generalErrorTimer?.cancel();
    setState(() => _generalError = error);
    _generalErrorTimer = Timer(errorDuration, () {
      if (mounted) setState(() => _generalError = null);
    });
  }

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

  Future<bool> _isEmailTaken(String email) async {
    try {
      try {
        List<String> signInMethods = [];
        try {
          final result = await (FirebaseAuth.instance as dynamic)
              .fetchSignInMethodsForEmail(email.trim())
              .timeout(const Duration(seconds: 5));
          signInMethods = List<String>.from(result as List);
        } on NoSuchMethodError {
          print(
            '⚠️ fetchSignInMethodsForEmail not available in firebase_auth SDK',
          );
        }

        if (signInMethods.isNotEmpty) {
          print('✅ Email found in Firebase Auth: $email');
          return true;
        }
        print('⚠️ Email NOT in Firebase Auth: $email');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-email') {
          print('❌ Invalid email format: $email');
          return false;
        }
        print('⚠️ Auth check error: ${e.code}');
      } catch (e) {
        print('⚠️ Auth check timeout/error: $e');
      }

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
        try {
          final docId = querySnapshot.docs.first.id;
          await _firestore.collection('users').doc(docId).delete();
          print('🗑️ Cleaned up orphaned Firestore document for: $email');
          return false;
        } catch (e) {
          print('❌ Failed to cleanup orphaned doc: $e');
          return true;
        }
      }

      print('✅ Email is available: $email');
      return false;
    } catch (e) {
      print('❌ Error checking email: $e');
      return false;
    }
  }

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
    _fetchPrograms();
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

  void registerUser() async {
    _clearErrors();
    print('🟢 Starting registration process...');

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

      print('🚀 Running parallel operations...');

      await Future.wait([
        _firestore
            .collection('users')
            .doc(user.uid)
            .set(userData, SetOptions(merge: false))
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => throw TimeoutException('Firestore timeout'),
            ),
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
      ], eagerError: false);

      print('✅ Parallel operations completed');

      _firestore
          .collection('logs')
          .add({
            'user': name,
            'action': 'Registered account (pending verification)',
            'time': Timestamp.now(),
            'userId': user.uid,
          })
          .catchError((e) => print('⚠️ Log error: $e'));

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
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        Icons.mark_email_read_rounded,
                        color: primaryColor,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Verify Your Email',
                      style: TextStyle(
                        fontFamily: primaryFontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A verification email has been sent to:',
                      style: TextStyle(
                        fontFamily: primaryFontFamily,
                        fontSize: 14,
                        color: textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              userEmail,
                              style: TextStyle(
                                fontFamily: primaryFontFamily,
                                fontSize: 14,
                                color: textPrimaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        'Please check your inbox or spam folder and click the verification link before signing in.',
                        style: TextStyle(
                          fontFamily: primaryFontFamily,
                          fontSize: 13,
                          color: textSecondaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          print('🔵 Continue to Sign In pressed');

                          try {
                            await FirebaseAuth.instance.signOut();
                            print('✅ User signed out');

                            emailController.clear();
                            passwordController.clear();
                            confirmPasswordController.clear();

                            if (!mounted) return;
                            Navigator.pop(context);

                            await Future.delayed(
                              const Duration(milliseconds: 100),
                            );

                            if (!mounted) return;
                            Navigator.pop(context);

                            await Future.delayed(
                              const Duration(milliseconds: 150),
                            );

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
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
                                duration: const Duration(seconds: 5),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          } catch (e) {
                            print('❌ Navigation error: $e');
                            if (mounted) {
                              try {
                                Navigator.of(context).pop();
                              } catch (_) {}

                              await Future.delayed(
                                const Duration(milliseconds: 50),
                              );

                              if (mounted) {
                                try {
                                  Navigator.of(context).pop();
                                } catch (_) {}
                              }
                            }
                          }
                        },
                        child: Text(
                          'Continue to Sign In',
                          style: TextStyle(
                            fontFamily: primaryFontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? errorText,
    double cardPadding = 20,
    ValueChanged<String>? onSubmitted,
  }) {
    final bool isConfirmPassword = controller == confirmPasswordController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText:
              isPassword
                  ? (isConfirmPassword
                      ? _obscureConfirmPassword
                      : _obscurePassword)
                  : obscureText,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}),
          onFieldSubmitted: onSubmitted,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: textSecondaryColor.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
            suffixIcon:
                isPassword
                    ? IconButton(
                      icon: Icon(
                        isConfirmPassword
                            ? (_obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility)
                            : (_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                        color: textSecondaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          if (isConfirmPassword) {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          } else {
                            _obscurePassword = !_obscurePassword;
                          }
                        });
                      },
                    )
                    : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: errorText != null ? errorColor : Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: errorText != null ? errorColor : Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: errorText != null ? errorColor : Colors.grey.shade400,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText,
            style: TextStyle(
              fontSize: 12,
              color: errorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGeneralError() {
    if (_generalError == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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
                fontSize: 13,
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

  Widget _buildContent({
    required double maxWidth,
    required double horizontalPadding,
    required double iconSize,
    required double titleFontSize,
    required double descriptionFontSize,
    required double cardPadding,
  }) {
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
              width: iconSize,
              height: iconSize,
              child: Image.asset(
                'lib/images/oasp.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.smart_toy_outlined,
                    color: primaryColor,
                    size: iconSize * 0.8,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Create Account",
              style: TextStyle(
                fontFamily: primaryFontFamily,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w800,
                color: textPrimaryColor,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Sign up to get started",
              style: TextStyle(
                fontFamily: primaryFontFamily,
                fontSize: descriptionFontSize,
                fontWeight: FontWeight.w400,
                color: textSecondaryColor,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildGeneralError(),
            _buildModernTextField(
              controller: emailController,
              label: 'Email',
              hint: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              cardPadding: cardPadding,
              onSubmitted: (_) => registerUser(),
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: passwordController,
              label: 'Password',
              hint: 'Enter your password',
              isPassword: true,
              errorText: _passwordError,
              cardPadding: cardPadding,
              onSubmitted: (_) => registerUser(),
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              isPassword: true,
              errorText: _confirmPasswordError,
              cardPadding: cardPadding,
              onSubmitted: (_) => registerUser(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: Colors.grey[300],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : registerUser,
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
                          "Sign Up",
                          style: TextStyle(
                            fontFamily: primaryFontFamily,
                            fontSize: descriptionFontSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(thickness: 1, color: Colors.grey[350])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "OR",
                    style: TextStyle(
                      fontFamily: primaryFontFamily,
                      color: textSecondaryColor,
                      fontSize: descriptionFontSize * 0.85,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(child: Divider(thickness: 1, color: Colors.grey[350])),
              ],
            ),
            const SizedBox(height: 24),
            if (!(!kIsWeb &&
                (Platform.isWindows ||
                    Platform.isLinux ||
                    Platform.isMacOS))) ...[
              const SquareTile(imagePath: 'lib/images/google.png'),
              const SizedBox(height: 24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Already have an account? ",
                  style: TextStyle(
                    fontFamily: primaryFontFamily,
                    color: textSecondaryColor,
                    fontSize: descriptionFontSize * 0.9,
                    fontWeight: FontWeight.w400,
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
                      fontWeight: FontWeight.w600,
                      fontSize: descriptionFontSize * 0.9,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: ResponsiveLayout(
          mobileBody: _buildContent(
            maxWidth: double.infinity,
            horizontalPadding: 20,
            iconSize: 100,
            titleFontSize: 24,
            descriptionFontSize: 14,
            cardPadding: 20,
          ),
          tabletBody: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildContent(
                maxWidth: 500,
                horizontalPadding: 0,
                iconSize: 110,
                titleFontSize: 28,
                descriptionFontSize: 15,
                cardPadding: 32,
              ),
            ),
          ),
          desktopBody: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildContent(
                maxWidth: 480,
                horizontalPadding: 0,
                iconSize: 120,
                titleFontSize: 32,
                descriptionFontSize: 16,
                cardPadding: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
