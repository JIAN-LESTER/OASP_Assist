import 'dart:io';

import 'package:capstone_project/components/square_tile.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'forgot_password_page.dart';
import 'onboarding/green_snow_animation.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _snowController;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _generalError;
  String? _verificationError;

  Timer? _emailErrorTimer;
  Timer? _passwordErrorTimer;
  Timer? _generalErrorTimer;
  Timer? _verificationErrorTimer;

  static const String primaryFontFamily = 'Poppins';
  static const Color primaryColor = Color.fromARGB(255, 8, 121, 11);
  static const Color linkColor = Color.fromARGB(255, 0, 81, 255);
  static final Color textPrimaryColor = Colors.grey[800]!;
  static final Color textSecondaryColor = Colors.grey[600]!;
  static final Color errorColor = Colors.red[400]!;
  static const Duration errorDuration = Duration(seconds: 10);

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

  void _setGeneralError(String error) {
    _generalErrorTimer?.cancel();
    setState(() => _generalError = error);
    _generalErrorTimer = Timer(errorDuration, () {
      if (mounted) setState(() => _generalError = null);
    });
  }

  void _setVerificationError(String error) {
    _verificationErrorTimer?.cancel();
    setState(() => _verificationError = error);
    _verificationErrorTimer = Timer(errorDuration, () {
      if (mounted) setState(() => _verificationError = null);
    });
  }

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

  bool _validateEmail(String email) {
    if (email.trim().isEmpty) {
      _setEmailError('Email address is required');
      return false;
    }
    if (!_isValidEmail(email.trim())) {
      _setEmailError('Please enter a valid email address');
      return false;
    }
    if (email.trim().length > 320) {
      _setEmailError('Email address is too long');
      return false;
    }
    _emailErrorTimer?.cancel();
    setState(() => _emailError = null);
    return true;
  }

  bool _validatePassword(String password) {
    if (password.isEmpty) {
      _setPasswordError('Password is required');
      return false;
    }
    _passwordErrorTimer?.cancel();
    setState(() => _passwordError = null);
    return true;
  }

  void signUserIn() async {
    _clearErrors();
    final email = emailController.text.trim();
    final password = passwordController.text;

    bool isEmailValid = _validateEmail(email);
    bool isPasswordValid = _validatePassword(password);

    if (!isEmailValid || !isPasswordValid) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Connection timeout. Please try again.');
            },
          );

      final user = userCredential.user;
      if (user == null) {
        _setGeneralError('Sign in failed. Please try again.');
        setState(() => _isLoading = false);
        return;
      }

      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() => _isLoading = false);
          _setVerificationError(
            'Email not verified. Please check your inbox and verify your email address before signing in.',
          );
        }
        return;
      }

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'isVerified': true,
              'emailVerified': true,
              'verifiedAt': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 10));
      } catch (firestoreError) {
        print(' Failed to update verification status: $firestoreError');
      }

      print(" Sign in successful: ${user.email}");
    } on TimeoutException catch (e) {
      print("⏱️ Timeout Error: $e");
      _setGeneralError(
        'Connection timeout. Please check your internet connection and try again.',
      );
    } on FirebaseAuthException catch (e) {
      print(" Firebase Auth Error: ${e.code} - ${e.message}");

      switch (e.code) {
        case 'user-not-found':
          _setEmailError('No account found with this email address');
          break;
        case 'wrong-password':
          _setPasswordError('Incorrect password. Please try again.');
          break;
        case 'invalid-email':
          _setEmailError('Invalid email address format');
          break;
        case 'user-disabled':
          _setGeneralError(
            'This account has been disabled. Please contact support.',
          );
          break;
        case 'too-many-requests':
          _setGeneralError(
            'Too many failed login attempts. Please try again later or reset your password.',
          );
          break;
        case 'invalid-credential':
          _setGeneralError(
            'Invalid email or password. Please check your credentials.',
          );
          break;
        case 'network-request-failed':
          _setGeneralError(
            'Network error. Please check your internet connection.',
          );
          break;
        default:
          _setGeneralError(
            'Login failed: ${_getFriendlyErrorMessage(e.message ?? 'Unknown error')}',
          );
      }
    } on SocketException catch (e) {
      print("🌐 Network Error: $e");
      _setGeneralError(
        'No internet connection. Please check your network and try again.',
      );
    } catch (e) {
      print(" Unexpected Error: $e");
      _setGeneralError(
        'An unexpected error occurred. Please try again or contact support.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getFriendlyErrorMessage(String technicalMessage) {
    final lowerMessage = technicalMessage.toLowerCase();
    if (lowerMessage.contains('network')) return 'Network connection issue';
    if (lowerMessage.contains('timeout')) return 'Connection timed out';
    if (lowerMessage.contains('permission')) return 'Permission denied';
    if (lowerMessage.contains('not found')) return 'Resource not found';
    if (lowerMessage.contains('already exists')) return 'Already exists';
    return 'Please try again';
  }

  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) return false;
    final parts = email.split('@');
    if (parts.length != 2) return false;
    final localPart = parts[0];
    final domainPart = parts[1];
    if (localPart.isEmpty || localPart.length > 64) return false;
    if (domainPart.isEmpty || !domainPart.contains('.')) return false;
    return true;
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
    if (cardPadding <= 20) {
      // Mobile layout
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
            obscureText: isPassword ? _obscurePassword : obscureText,
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
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: textSecondaryColor,
                        ),
                        onPressed:
                            () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
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

    // Desktop/Tablet layout
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
          obscureText: isPassword ? _obscurePassword : obscureText,
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
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: textSecondaryColor,
                      ),
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
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
    if (_generalError == null && _verificationError == null) {
      return const SizedBox.shrink();
    }

    final errorMessage = _generalError ?? _verificationError;

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
              errorMessage!,
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
              if (_generalError != null) {
                _generalErrorTimer?.cancel();
                setState(() => _generalError = null);
              }
              if (_verificationError != null) {
                _verificationErrorTimer?.cancel();
                setState(() => _verificationError = null);
              }
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
    bool useFormCard = false,
  }) {
    final formContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Sign in",
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
          "Access your OASP Assist account",
          style: TextStyle(
            fontFamily: primaryFontFamily,
            fontSize: descriptionFontSize * 0.95,
            fontWeight: FontWeight.w400,
            color: textSecondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildGeneralError(),
        _buildModernTextField(
          controller: emailController,
          label: 'Email',
          hint: 'Enter your email',
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          cardPadding: cardPadding,
          onSubmitted: (_) => signUserIn(),
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: passwordController,
          label: 'Password',
          hint: 'Enter your password',
          isPassword: true,
          errorText: _passwordError,
          cardPadding: cardPadding,
          onSubmitted: (_) => signUserIn(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
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
                fontWeight: FontWeight.w500,
                fontSize: descriptionFontSize * 0.9,
              ),
            ),
          ),
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
            onPressed: _isLoading ? null : signUserIn,
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
                      "Sign In",
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
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS))) ...[
          const SquareTile(imagePath: 'lib/images/google.png'),
          const SizedBox(height: 24),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(
                fontFamily: primaryFontFamily,
                color: textSecondaryColor,
                fontSize: descriptionFontSize * 0.9,
                fontWeight: FontWeight.w400,
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
        vertical: 10,
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
                    border: Border.all(color: Color(0xFFE0F0E4)),
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
          ],
        ),
      ),
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
          GreenSnowAnimation(animation: _snowController, color: primaryColor),
          child,
        ],
      ),
    );
  }

  Widget _buildMobileBody() {
    return _buildDecoratedBody(
      child: Center(
        child: _buildContent(
          maxWidth: double.infinity,
          horizontalPadding: 20,
          iconSize: 140,
          titleFontSize: 26,
          descriptionFontSize: 14,
          cardPadding: 20,
          useFormCard: true,
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
    )..repeat();
  }

  @override
  void dispose() {
    _snowController.dispose();
    _emailErrorTimer?.cancel();
    _passwordErrorTimer?.cancel();
    _generalErrorTimer?.cancel();
    _verificationErrorTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF1FF),
      body: SafeArea(
        child: ResponsiveLayout(
          mobileBody: _buildMobileBody(),
          tabletBody: _buildDecoratedBody(
            child: Center(
              child: _buildContent(
                maxWidth: 500,
                horizontalPadding: 32,
                iconSize: 145,
                titleFontSize: 28,
                descriptionFontSize: 15,
                cardPadding: 32,
                useFormCard: true,
              ),
            ),
          ),
          desktopBody: _buildDecoratedBody(
            child: Center(
              child: _buildContent(
                maxWidth: 480,
                horizontalPadding: 40,
                iconSize: 155,
                titleFontSize: 32,
                descriptionFontSize: 16,
                cardPadding: 40,
                useFormCard: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
