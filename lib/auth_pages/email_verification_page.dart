// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// class VerifyEmailPage extends StatefulWidget {
//   const VerifyEmailPage({super.key});

//   @override
//   State<VerifyEmailPage> createState() => _VerifyEmailPageState();
// }

// class _VerifyEmailPageState extends State<VerifyEmailPage> {
//   bool _isSending = false;
//   bool _isChecking = false;

//   Future<void> _resendVerificationEmail() async {
//     setState(() => _isSending = true);
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null && !user.emailVerified) {
//         await user.sendEmailVerification();
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Verification email resent.')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to resend email: $e')),
//       );
//     } finally {
//       setState(() => _isSending = false);
//     }
//   }
// Future<void> _checkEmailVerified() async {
//   setState(() => _isChecking = true);
//   try {
//     final user = FirebaseAuth.instance.currentUser;
//     await user?.reload(); // refresh user data
//     if (user != null && user.emailVerified) {
//       // ✅ Firestore update for isVerified
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user.uid)
//           .update({'isVerified': true});

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Email verified! Redirecting...')),
//       );

//       // ✅ Navigate to your app's home page
//       Navigator.pushReplacementNamed(context, '/home');
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Email not verified yet.')),
//       );
//     }
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Error: $e')),
//     );
//   } finally {
//     setState(() => _isChecking = false);
//   }
// }
//   Future<void> _signOut() async {
//     await FirebaseAuth.instance.signOut();
//     Navigator.pushReplacementNamed(context, '/login');
//   }

//   @override
//   Widget build(BuildContext context) {
//     final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'your email';

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Verify Email'),
//         actions: [
//           TextButton(
//             onPressed: _signOut,
//             child: const Text('Sign out', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               'A verification email has been sent to:\n\n$userEmail\n\n'
//               'Please check your inbox or spam and verify your email before continuing.',
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 24),
//             ElevatedButton.icon(
//               onPressed: _isSending ? null : _resendVerificationEmail,
//               icon: const Icon(Icons.email),
//               label: Text(_isSending ? 'Sending...' : 'Resend Verification Email'),
//             ),
//             const SizedBox(height: 12),
//             ElevatedButton.icon(
//               onPressed: _isChecking ? null : _checkEmailVerified,
//               icon: const Icon(Icons.check_circle),
//               label: Text(_isChecking ? 'Checking...' : 'I Verified My Email'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
