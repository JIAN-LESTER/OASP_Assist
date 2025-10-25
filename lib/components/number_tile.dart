import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NumberTile extends StatefulWidget {
  final String imagePath;
  const NumberTile({super.key, required this.imagePath});

  @override
  State<NumberTile> createState() => _NumberTileState();
}

class _NumberTileState extends State<NumberTile> {
  bool _isLoading = false;

  String? _verificationId;

  Future<void> signInWithPhoneFlow() async {
    final phoneController = TextEditingController();
    final codeController = TextEditingController();

    // Step 1: Ask for phone number
    final phoneNumber = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Enter Phone Number"),
            content: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '+63xxxxxxxxxx'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, phoneController.text),
                child: const Text("Continue"),
              ),
            ],
          ),
    );

    if (phoneNumber == null || phoneNumber.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await signInWithPhone(phoneNumber, (verificationId) async {
        _verificationId = verificationId;

        // Step 2: Ask for OTP
        final smsCode = await showDialog<String>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Enter OTP Code"),
                content: TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '123456'),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        () => Navigator.pop(context, codeController.text),
                    child: const Text("Verify"),
                  ),
                ],
              ),
        );

        if (smsCode != null && _verificationId != null) {
          await confirmOTP(_verificationId!, smsCode);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Phone Sign-in successful")),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> signInWithPhone(
    String phoneNumber,
    Function(String) onCodeSent,
  ) async {
    FirebaseAuth auth = FirebaseAuth.instance;

    if (kIsWeb) {
      ConfirmationResult result = await auth.signInWithPhoneNumber(phoneNumber);
      onCodeSent(result.verificationId);
    } else {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          throw Exception('Phone verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    }
  }

  Future<UserCredential> confirmOTP(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : signInWithPhoneFlow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 65.0),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                _isLoading
                    ? Colors.grey.shade300
                    : const Color.fromARGB(255, 216, 216, 216),
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
          children: [
            if (_isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color.fromARGB(255, 8, 121, 11),
                ),
              )
            else
              Image.asset(
                widget.imagePath,
                height: 24,
                width: 24,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.phone, size: 24, color: Colors.red);
                },
              ),
            const SizedBox(width: 16),
            Text(
              _isLoading ? 'Signing in...' : 'Continue with Phone',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _isLoading ? Colors.grey.shade600 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
