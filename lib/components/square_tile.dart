

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SquareTile extends StatefulWidget {
  final String imagePath;
  const SquareTile({super.key, required this.imagePath});

  @override
  State<SquareTile> createState() => _SquareTileState();
}

class _SquareTileState extends State<SquareTile> {
  bool _isLoading = false;

  Future<void> signInWithGoogleAccountSelection() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('🚀 Starting Google Sign-In...');

      // Platform-specific implementation
      if (kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux))) {
        await _signInWithGoogleWeb();
      } else {
        await _signInWithGoogleNative();
      }
    } catch (e, st) {
      // Check if user cancelled the sign-in
      final errorString = e.toString().toLowerCase();
      final isCancellation =
          errorString.contains('cancel') ||
          errorString.contains('sign_in_cancelled') ||
          errorString.contains('sign_in_failed') ||
          errorString.contains('network_error') ||
          errorString == 'null' ||
          e is PlatformException &&
              (e.code == 'sign_in_canceled' ||
                  e.code == 'sign_in_failed' ||
                  e.code == 'network_error');

      if (!isCancellation) {
        print('❌ Error during Google sign-in: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign-in failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('ℹ️ Sign-in cancelled by user');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Web/Desktop sign-in using Firebase Auth directly
  Future<void> _signInWithGoogleWeb() async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();

    // Force account selection
    googleProvider.setCustomParameters({'prompt': 'select_account'});

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithPopup(googleProvider);

      print('✅ Firebase sign-in successful: ${userCredential.user?.email}');

      if (userCredential.user != null) {
        final bool isFirstTime =
            userCredential.additionalUserInfo?.isNewUser ?? false;

        await _createOrUpdateUserDocument(userCredential.user!, isFirstTime);

        if (mounted) {
          _handleSuccessfulSignIn(userCredential.user!, isFirstTime);
        }
      }
    } on FirebaseAuthException catch (e) {
      // Handle user cancellation on web
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled' ||
          e.code == 'user-cancelled') {
        print('ℹ️ User closed the popup');
        return;
      }
      if (e.code == 'account-exists-with-different-credential') {
        await _handleAccountExistsError(e);
      } else {
        rethrow;
      }
    }
  }

  // Native mobile sign-in using google_sign_in package
  Future<void> _signInWithGoogleNative() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId:
          '1008880584715-q015emqallpopqhpme1gqjrmsi72rocu.apps.googleusercontent.com',
    );

    // OPTIMIZED: Only disconnect if needed, no unnecessary signOut
    // This prevents delays when user cancels immediately
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    // Early return on cancellation - no delay
    if (googleUser == null) {
      print("ℹ️ User cancelled sign-in");
      return;
    }

    // 🔑 Auth tokens
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // 🔥 Firebase Auth
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      print('✅ Firebase sign-in successful: ${userCredential.user?.email}');

      if (userCredential.user != null) {
        final bool isFirstTime =
            userCredential.additionalUserInfo?.isNewUser ?? false;

        await _createOrUpdateUserDocument(userCredential.user!, isFirstTime);

        if (mounted) {
          _handleSuccessfulSignIn(userCredential.user!, isFirstTime);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        await _handleAccountExistsError(e, pendingCredential: credential);
      } else {
        rethrow;
      }
    }
  }

  /// Handle account exists error by linking credentials
  Future<void> _handleAccountExistsError(
    FirebaseAuthException e, {
    AuthCredential? pendingCredential,
  }) async {
    print('⚠️ Account exists with different credential');

    final email = e.email;
    if (email == null) {
      throw Exception('Unable to retrieve email from error');
    }

    print('📧 Conflicting email: $email');

    // Check Firestore to see what provider the user has
    String existingMethod = 'password'; // Default assumption

    try {
      final userQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (userQuery.docs.isNotEmpty) {
        final userData = userQuery.docs.first.data();
        final linkedProviders = userData['linkedProviders'] as List<dynamic>?;

        if (linkedProviders != null && linkedProviders.isNotEmpty) {
          existingMethod = linkedProviders.first.toString();
          print('🔑 Found existing provider in Firestore: $existingMethod');
        }
      }
    } catch (firestoreError) {
      print('⚠️ Could not check Firestore: $firestoreError');
    }

    // Show dialog asking user to sign in with existing method
    if (mounted) {
      await _showAccountLinkingDialog(
        email: email,
        existingMethod: existingMethod,
        pendingCredential: pendingCredential ?? e.credential!,
      );
    }
  }

  /// Show dialog to link accounts
  Future<void> _showAccountLinkingDialog({
    required String email,
    required String existingMethod,
    required AuthCredential pendingCredential,
  }) async {
    final methodName =
        existingMethod == 'password'
            ? 'Email/Password'
            : existingMethod == 'google.com'
            ? 'Google'
            : existingMethod;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.link, color: Color(0xFF2E7D32)),
                SizedBox(width: 12),
                Expanded(child: Text('Link Accounts')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'An account already exists with the email:',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    email,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This account uses $methodName for sign-in. Would you like to link your Google account to this existing account?',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await _linkAccountWithPassword(email, pendingCredential);
                },
                child: const Text('Link Accounts'),
              ),
            ],
          ),
    );
  }

  /// Link Google credential to existing email/password account
  Future<void> _linkAccountWithPassword(
    String email,
    AuthCredential pendingCredential,
  ) async {
    final passwordController = TextEditingController();
    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Enter Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please enter your password for:',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
    );

    if (confirmed != true || passwordController.text.isEmpty) {
      print('ℹ️ User cancelled password entry');
      return;
    }

    try {
      print('🔐 Signing in with email/password...');

      final emailCredential = EmailAuthProvider.credential(
        email: email,
        password: passwordController.text,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(emailCredential);

      print('✅ Signed in with email/password');
      print('🔗 Now linking Google credential...');

      await userCredential.user!.linkWithCredential(pendingCredential);

      print('✅ Google account linked successfully!');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .update({
            'linkedProviders': FieldValue.arrayUnion(['google.com']),
            'lastLoginAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Google account linked successfully!')),
              ],
            ),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );

        Navigator.pushReplacementNamed(context, "/home");
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Linking error: ${e.code} - ${e.message}');

      String errorMessage = 'Failed to link accounts';
      if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'Account not found';
      } else if (e.code == 'provider-already-linked') {
        errorMessage = 'Google account is already linked';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('❌ Unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleSuccessfulSignIn(User user, bool isFirstTime) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFirstTime
              ? '🎉 Welcome for the first time, ${user.displayName ?? 'User'}!'
              : 'Welcome back, ${user.displayName ?? 'User'}!',
        ),
        backgroundColor: isFirstTime ? Colors.blue : Colors.green,
      ),
    );

    if (isFirstTime) {
      Navigator.pushReplacementNamed(context, "/userOnboarding");
    } else {
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  Future<void> _createOrUpdateUserDocument(User user, bool isFirstTime) async {
    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      if (isFirstTime) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'name': user.displayName ?? user.email?.split('@')[0],
          'photoURL': user.photoURL,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'isVerified': user.emailVerified,
          'ProfileCompleted': false,
          'onboardingCompleted': false,
          'hasSeenOnboardingGuide': false,
          'isFirstLogin': true,
          'profileCompleted': false,
          'linkedProviders': ['google.com'],
                   'dailyMessageCount': 0,                       
    'lastMessageResetDate': FieldValue.serverTimestamp(), 
        });
        print('🎉 Created new user: ${user.email}');
      } else {
        final docSnapshot = await userDoc.get();
        final existingData = docSnapshot.data();

        if (existingData != null) {
          final linkedProviders =
              existingData['linkedProviders'] as List<dynamic>?;
          if (linkedProviders == null ||
              !linkedProviders.contains('google.com')) {
            await userDoc.update({
              'lastLoginAt': FieldValue.serverTimestamp(),
              'isActive': true,
              'isFirstLogin': false,
              'linkedProviders': FieldValue.arrayUnion(['google.com']),
            });
          } else {
            await userDoc.update({
              'lastLoginAt': FieldValue.serverTimestamp(),
              'isActive': true,
              'isFirstLogin': false,
            });
          }
        }
        print('🔑 Updated returning user: ${user.email}');
      }
    } catch (e) {
      print('❌ Firestore update error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _isLoading ? null : signInWithGoogleAccountSelection,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            border: Border.all(
              color: _isLoading ? Colors.grey.shade300 : Colors.grey.shade400,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _isLoading ? Colors.grey.shade50 : Colors.white,
            boxShadow:
                _isLoading
                    ? []
                    : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green,
                  ),
                )
              else
                Image.asset(
                  widget.imagePath,
                  height: 24,
                  width: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.g_mobiledata,
                      size: 24,
                      color: Colors.red,
                    );
                  },
                ),
              const SizedBox(width: 16),
              Text(
                _isLoading ? 'Signing in...' : 'Continue with Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _isLoading ? Colors.grey.shade600 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
