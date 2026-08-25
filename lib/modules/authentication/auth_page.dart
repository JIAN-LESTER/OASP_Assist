import 'package:capstone_project/modules/admin/admin_main_page.dart';
import 'package:capstone_project/modules/staff/staff_main_page.dart';
import 'package:capstone_project/modules/user/user_main_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:capstone_project/modules/authentication/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:capstone_project/modules/authentication/onboarding/userOnboarding.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static const String _webClientId =
      '13855273820-72hpqqhplltklr09mb40lqk84pn7ktke.apps.googleusercontent.com';

  /// Attempt silent login with Google
  Future<void> _trySilentGoogleLogin() async {
    try {
      print(' Silent Google login initialize with serverClientId=$_webClientId');
      await _googleSignIn.initialize(serverClientId: _webClientId);
      print(' Silent Google login initialized');
      final attempt = _googleSignIn.attemptLightweightAuthentication();
      print(' Silent Google login attempt available: ${attempt != null}');
      final googleUser = attempt == null ? null : await attempt;
      if (googleUser != null) {
        print(' Silent Google login account: ${googleUser.email}');
        final googleAuth = googleUser.authentication;
        print(' Silent Google login idToken present: ${googleAuth.idToken != null}');
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        print(' Silent Firebase signInWithCredential starting');
        await FirebaseAuth.instance.signInWithCredential(credential);
        print(' Silent Firebase signInWithCredential successful');
      } else {}
    } on FirebaseAuthException catch (e) {
      print(' Silent FirebaseAuthException: ${e.code} - ${e.message}');
    } catch (e, st) {
      print(' Silent Google login error: $e\n$st');
    }
  }

  @override
  void initState() {
    super.initState();
    _trySilentGoogleLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final user = snapshot.data!;

            // CHECK EMAIL VERIFICATION FIRST
            if (!user.emailVerified) {
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }

            // Email is verified, proceed to role-based routing
            return RoleBasedRouter();
          } else {
            // User is not logged in
            return const LoginPage();
          }
        },
      ),
    );
  }
}

class RoleBasedRouter extends StatelessWidget {
  RoleBasedRouter({super.key});

  final user = fb_auth.FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserData>(
      future: _getUserDataAndLogEvent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        (context as Element).markNeedsBuild();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final userData = snapshot.data!;

        switch (userData.role) {
          case 'admin':
            return AdminMainPage();
          case 'staff':
            return StaffMainPage();
          case 'user':
            //  FIXED: Check BOTH onboardingCompleted AND profileCompleted
            if (!userData.isOnboardingCompleted ||
                !userData.isProfileCompleted) {
              return UserOnboardingScreen(
                userId: user?.uid ?? '',
                userName: userData.name,
              );
            } else {
              return UserMainPage();
            }
          default:
            return UserMainPage();
        }
      },
    );
  }

  Future<UserData> _getUserDataAndLogEvent() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      String role = 'user';
      String name = user.displayName ?? user.email?.split('@')[0] ?? 'User';
      bool profileCompleted = false;
      bool onboardingCompleted = false;

      if (doc.exists) {
        final data = doc.data()!;

        //  READ ALL FIELDS
        role = data['role'] ?? 'user';
        name = data['name'] ?? name;
        profileCompleted = data['profileCompleted'] ?? false;
        onboardingCompleted = data['onboardingCompleted'] ?? false;

        //  DETAILED DEBUG OUTPUT

        //  UPDATE LAST LOGIN (with error handling)
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'lastLoginAt': FieldValue.serverTimestamp()});
        } catch (e) {}
      } else {
        //  CREATE NEW DOCUMENT (only if it doesn't exist)
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'name': name,
          'photoURL': user.photoURL ?? '',
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'firstLogin': true,
          'isActive': true,
          'profileCompleted': false,
          'onboardingCompleted': false,
          'hasSeenOnboardingGuide': false,
          'isVerified': user.emailVerified,
          'linkedProviders': ['password'],
          'dailyMessageCount': 0,
          'lastMessageResetDate': FieldValue.serverTimestamp(),
        });
      }

      //  LOG LOGIN EVENT
      try {
        await _logLogin(user.uid, name);
      } catch (e) {}

      //  RETURN USER DATA

      return UserData(
        role: role,
        name: name,
        isProfileCompleted: profileCompleted,
        isOnboardingCompleted: onboardingCompleted,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _logLogin(String userId, String userName) async {
    try {
      final logRef = FirebaseFirestore.instance.collection('logs').doc();
      await logRef.set({
        'logId': logRef.id,
        'user': userName,
        'action': 'Logged In',
        'time': Timestamp.now(),
        'userId': userId,
      });
    } catch (e) {}
  }
}

//  FIXED: Added isOnboardingCompleted field
class UserData {
  final String role;
  final String name;
  final bool isProfileCompleted;
  final bool isOnboardingCompleted;

  UserData({
    required this.role,
    required this.name,
    required this.isProfileCompleted,
    required this.isOnboardingCompleted,
  });
}
