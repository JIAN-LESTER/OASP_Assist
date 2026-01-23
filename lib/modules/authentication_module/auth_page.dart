import 'package:capstone_project/modules/admin_module/admin_main_page.dart';
import 'package:capstone_project/modules/staff_module/staff_main_page.dart';
import 'package:capstone_project/modules/user_module/user_main_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:capstone_project/modules/authentication_module/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:capstone_project/modules/authentication_module/onboarding/userOnboarding.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Attempt silent login with Google
  Future<void> _trySilentGoogleLogin() async {
    try {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        print("✅ Silent Google login successful: ${googleUser.email}");
      } else {
        print("ℹ️ No Google account found for silent sign-in");
      }
    } catch (e) {
      print("⚠️ Silent Google login failed: $e");
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
              print('⚠️ Email not verified for ${user.email}');
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
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  SizedBox(height: 16),
                  Text('Loading...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          print('❌ Error in RoleBasedRouter: ${snapshot.error}');

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
        print('✅ Routing user: ${userData.name}');
        print('📌 Role: ${userData.role}');
        print('📋 Profile Completed: ${userData.isProfileCompleted}');
        print('📋 Onboarding Completed: ${userData.isOnboardingCompleted}');
        
        switch (userData.role) {
          case 'admin':
            return AdminMainPage();
          case 'staff':
            return StaffMainPage();
          case 'user':
            // ✅ FIXED: Check BOTH onboardingCompleted AND profileCompleted
            if (!userData.isOnboardingCompleted || !userData.isProfileCompleted) {
              print('📝 Onboarding/Profile incomplete - showing onboarding');
              return UserOnboardingScreen(
                userId: user?.uid ?? '',
                userName: userData.name,
              );
            } else {
              print('✅ Onboarding and profile complete - going to main page');
              return UserMainPage();
            }
          default:
            print('⚠️ Unknown role: ${userData.role}, defaulting to user');
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

    print('🔍 Fetching user data for: ${user.uid}');
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String role = 'user';
    String name = user.displayName ?? user.email?.split('@')[0] ?? 'User';
    bool profileCompleted = false;
    bool onboardingCompleted = false;

    if (doc.exists) {
      final data = doc.data()!;
      
      // ✅ READ ALL FIELDS
      role = data['role'] ?? 'user';
      name = data['name'] ?? name;
      profileCompleted = data['profileCompleted'] ?? false;
      onboardingCompleted = data['onboardingCompleted'] ?? false;

      // ✅ DETAILED DEBUG OUTPUT
      print('📊 User document EXISTS:');
      print('   - Document ID: ${doc.id}');
      print('   - Role: $role');
      print('   - Name: $name');
      print('   - profileCompleted (read): $profileCompleted');
      print('   - onboardingCompleted (read): $onboardingCompleted');
      print('   - RAW profileCompleted: ${data['profileCompleted']}');
      print('   - RAW onboardingCompleted: ${data['onboardingCompleted']}');
      print('   - Document has fields: ${data.keys.toList()}');

      // ✅ UPDATE LAST LOGIN (with error handling)
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'lastLoginAt': FieldValue.serverTimestamp()});
      } catch (e) {
        print('⚠️ Failed to update last login: $e');
      }
    } else {
      print('⚠️ User document DOES NOT EXIST - creating new one');

      // ✅ CREATE NEW DOCUMENT (only if it doesn't exist)
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

      print('✅ New user document created');
    }

    // ✅ LOG LOGIN EVENT
    try {
      await _logLogin(user.uid, name);
    } catch (e) {
      print('⚠️ Failed to log login: $e');
    }

    // ✅ RETURN USER DATA
    print('🎯 Returning UserData:');
    print('   - role: $role');
    print('   - name: $name');
    print('   - isProfileCompleted: $profileCompleted');
    print('   - isOnboardingCompleted: $onboardingCompleted');

    return UserData(
      role: role,
      name: name,
      isProfileCompleted: profileCompleted,
      isOnboardingCompleted: onboardingCompleted,
    );
  } catch (e) {
    print('❌ Error getting user data: $e');
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
      print('📝 Login event logged');
    } catch (e) {
      print('⚠️ Failed to log login event: $e');
    }
  }
}

// ✅ FIXED: Added isOnboardingCompleted field
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