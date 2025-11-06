import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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
        // Use Firebase Auth web flow for web/desktop
        await _signInWithGoogleWeb();
      } else {
        // Use native Google Sign-In for mobile
        await _signInWithGoogleNative();
      }
    } catch (e, st) {
      print('❌ Error during Google sign-in: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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

    final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithPopup(googleProvider);

    print('✅ Firebase sign-in successful: ${userCredential.user?.email}');

    if (userCredential.user != null) {
      final bool isFirstTime =
          userCredential.additionalUserInfo?.isNewUser ?? false;

      await _createOrUpdateUserDocument(userCredential.user!, isFirstTime);

      if (mounted) {
        _handleSuccessfulSignIn(userCredential.user!, isFirstTime);
      }
    }
  }

  // Native mobile sign-in using google_sign_in package
  Future<void> _signInWithGoogleNative() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: '1008880584715-q015emqallpopqhpme1gqjrmsi72rocu.apps.googleusercontent.com',
    );

    // Force account selection each time
    await googleSignIn.signOut();

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      print("❌ User cancelled sign-in");
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

    final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    print('✅ Firebase sign-in successful: ${userCredential.user?.email}');

    if (userCredential.user != null) {
      final bool isFirstTime =
          userCredential.additionalUserInfo?.isNewUser ?? false;

      await _createOrUpdateUserDocument(userCredential.user!, isFirstTime);

      if (mounted) {
        _handleSuccessfulSignIn(userCredential.user!, isFirstTime);
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

    // Navigate based on first-time status
    if (isFirstTime) {
      Navigator.pushReplacementNamed(context, "/userOnboarding");
    } else {
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  Future<void> _createOrUpdateUserDocument(User user, bool isFirstTime) async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      if (isFirstTime) {
        // ✅ First-time login → create new user record
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
          'isFirstLogin': true,
          'profileCompleted': false,
        });
        print('🎉 Created new user: ${user.email}');
      } else {
        // 🔄 Returning user → just update info
        await userDoc.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'isFirstLogin': false,
        });
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
            boxShadow: _isLoading
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

class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
  }
}