import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:capstone_project/auth_pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:capstone_project/onboarding/userOnboarding.dart';
import 'package:capstone_project/pages/staff_pages/staff_main_page.dart';
import 'package:capstone_project/pages/user_pages/user_main_page.dart';
import 'package:capstone_project/pages/admin_pages/admin_main_page.dart';

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
      print("❌ Silent Google login failed: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _trySilentGoogleLogin(); // Run once when widget mounts
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // User is logged in, check their role and first login status
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
          return UserMainPage();
        }

        final userData = snapshot.data!;
        print('🔄 Routing user: ${userData.name}');
        print('📋 Role: ${userData.role}');
        print('🧩 Profile Completed: ${userData.isProfileCompleted}');

        // Route based on role and profile completion
        switch (userData.role) {
          case 'admin':
            return AdminMainPage();
          case 'staff':
            return StaffMainPage();
          case 'user':
            if (!userData.isProfileCompleted) {
              print('🎉 Profile incomplete - showing onboarding');
              return UserOnboardingScreen(
                userId: user?.uid ?? '',
                userName: userData.name,
              );
            } else {
              print('✅ Profile complete - going to main page');
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
      if (user == null) throw Exception('No authenticated user found');

      print('🔍 Fetching user data for: ${user.uid}');
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      String role = 'user';
      String name = user.displayName ?? user.email?.split('@')[0] ?? 'User';
      bool profileCompleted = false;

      if (doc.exists) {
        final data = doc.data()!;
        role = data['role'] ?? 'user';
        name = data['name'] ?? name;
        profileCompleted = data['profileCompleted'] ?? false;

        // Update last login
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'lastLoginAt': FieldValue.serverTimestamp()});
      } else {
        // Create a user doc if not existing
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
  'uid': user.uid,
  'email': user.email ?? '',
  'name': name,
  'photoURL': user.photoURL ?? '',
  'role': 'user',
  'profileCompleted': false,
  'createdAt': FieldValue.serverTimestamp(),
  'isActive': true,
  'isVerified': user.emailVerified,
  'linkedProviders': ['password'], // ADD THIS LINE - default to password for fallback cases
});
      }

      // Log login
      await _logLogin(user.uid, name);

      return UserData(
        role: role,
        name: name,
        isProfileCompleted: profileCompleted,
      );
    } catch (e) {
      print('❌ Error getting user data: $e');
      return UserData(
        role: 'user',
        name: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
        isProfileCompleted: false,
      );
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
      print('❌ Failed to log login event: $e');
    }
  }
}

// Helper class to hold user data
class UserData {
  final String role;
  final String name;
  final bool isProfileCompleted;

  UserData({
    required this.role,
    required this.name,
    required this.isProfileCompleted,
  });
}
