// ignore_for_file: public_member_api_docs, sort_constructors_first
// Separate StatefulWidget for the dialog content
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/reusable_widgets/loading_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LogoutDialogContent extends StatefulWidget {
  final bool isMobile;

  const LogoutDialogContent({Key? key, required this.isMobile})
    : super(key: key);

  @override
  State<LogoutDialogContent> createState() => LogoutDialogContentState();
}

class LogoutDialogContentState extends State<LogoutDialogContent> {
  bool _isLoading = false;

  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Perform logout
      await signUserOut();

      if (mounted) {
        // Close logout dialog first
        Navigator.of(context).pop();

        // Small delay to ensure dialog is closed
        await Future.delayed(const Duration(milliseconds: 100));

        // Navigate to root and clear all routes
        // This ensures clean navigation after onboarding
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/auth', // Navigate to root (AuthPage will handle redirect to LoginPage)
            (route) => false, // Remove all routes
          );
        }
      }
    } catch (error) {
      print(' Logout error: $error');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Logout failed: ${error.toString()}')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(widget.isMobile ? 16 : 32),
          child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with professional red theme for logout
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFECACA).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFDC2626),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: widget.isMobile ? 20 : 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Are you sure you want to logout from your account?',
                    style: TextStyle(
                      fontSize: widget.isMobile ? 14 : 16,
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You will be logged out',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 13 : 14,
                                  color: const Color(0xFF1F2937),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'You\'ll need to login again to access your account',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 12 : 13,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: widget.isMobile ? 40 : 46,
                          child: OutlinedButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6B7280),
                              side: const BorderSide(
                                color: Color(0xFFD1D5DB),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.isMobile ? 16 : 20,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: widget.isMobile ? 14 : 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: widget.isMobile ? 40 : 46,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(
                                0xFFDC2626,
                              ).withOpacity(0.7),
                              disabledForegroundColor: Colors.white.withOpacity(
                                0.7,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.isMobile ? 16 : 20,
                              ),
                            ),
                            child:
                                _isLoading
                                    ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white.withOpacity(0.8),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Logging out...',
                                          style: TextStyle(
                                            fontSize: widget.isMobile ? 14 : 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.logout_rounded,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Logout',
                                          style: TextStyle(
                                            fontSize: widget.isMobile ? 14 : 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: buildContentLoadingOverlay('Logging out...'),
          ),
      ],
    );
  }

  static Future<void> signUserOut() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String name = 'Unknown';

      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          name = userData['name'] ?? user.email ?? 'Unknown';

          // Create log before signing out
          try {
            final logRef = FirebaseFirestore.instance.collection('logs').doc();
            final logData = {
              'logId': logRef.id,
              'user': name,
              'action': 'Logged Out',
              'time': Timestamp.now(),
              'userId': user.uid,
            };

            await logRef.set(logData);
            print(' Logout logged successfully');
          } catch (e) {
            print(' Failed to log logout event: $e');
            // Continue with logout even if logging fails
          }
        }
      }

      // Sign out from Google if not on Windows
      try {
        if (!Platform.isWindows) {
          final GoogleSignIn googleSignIn = GoogleSignIn.instance;
          await googleSignIn.signOut();
          print('Google sign-out successful');
        } else {
          print(' Skipping Google sign-out on Windows');
        }
      } catch (e) {
        print(' Google sign-out error (non-critical): $e');
        // Continue with Firebase logout even if Google logout fails
      }

      // Always sign out from Firebase Auth - THIS IS THE CRITICAL PART
      await FirebaseAuth.instance.signOut();
      print(' Firebase sign-out successful');
    } catch (e) {
      print(' Error during logout: $e');

      // Force Firebase signout even on error
      try {
        await FirebaseAuth.instance.signOut();
        print(' Forced Firebase sign-out successful');
      } catch (inner) {
        print(' Critical: Failed to force Firebase signout: $inner');
        rethrow; // Rethrow to show error to user
      }
    }
  }
}

Future<void> showLogoutDialog(BuildContext context) async {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Logout Confirmation',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return LogoutDialogContent(isMobile: isMobile);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}
