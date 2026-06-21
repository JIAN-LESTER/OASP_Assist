import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../utils/snackbar_util.dart';

class AppDistributionQrButton extends StatelessWidget {
  final bool positioned;
  final bool requireLoginForEmail;

  const AppDistributionQrButton({
    super.key,
    this.positioned = true,
    this.requireLoginForEmail = true,
  });

  static const String appDistributionUrl =
      'https://appdistribution.firebase.google.com/testerapps/1:1008880584715:android:586d0981fcdb06057f5f0e/releases/0j25a9h2agmvo?utm_source=firebase-console';
  static const Color primaryColor = Color.fromARGB(255, 8, 121, 11);
  static const String primaryFontFamily = 'Poppins';

  static bool get isWebOrDesktop {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!isWebOrDesktop) return const SizedBox.shrink();

    final button = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
      ),
      onPressed: () => _showQrDialog(context),
      icon: const Icon(Icons.qr_code_2, size: 20),
      label: const Text(
        'Download App',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );

    if (!positioned) return button;

    return Positioned(
      top: 16,
      right: 16,
      child: button,
    );
  }

  void _showQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: primaryColor,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Install OASP Assist',
                    style: TextStyle(
                      fontFamily: primaryFontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Scan this QR code on your Android phone to download the application.',
                    style: TextStyle(
                      fontFamily: primaryFontFamily,
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: QrImageView(
                          data: appDistributionUrl,
                          version: QrVersions.auto,
                          size: 240,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (requireLoginForEmail)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: primaryColor,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Log in to receive the app invite by email.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _handleEmailAction(context),
                        icon: const Icon(Icons.email_outlined, size: 20),
                        label: const Text(
                          'Receive an email instead',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _handleEmailAction(BuildContext context) {
    if (requireLoginForEmail) {
      SnackbarUtil.showInfo(
        context,
        'You will need to log in to receive the email',
      );
      return;
    }

    _sendInstallEmail(context);
  }

  Future<void> _sendInstallEmail(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      SnackbarUtil.showError(context, 'No logged-in email found');
      return;
    }

    if (!context.mounted) return;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable(
            'sendAppDistributionInvite',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          );
      await callable.call();
      if (!context.mounted) return;
      SnackbarUtil.showSuccess(context, 'App invite sent to $email');
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      SnackbarUtil.showError(
        context,
        e.message ?? 'Failed to send app invite',
      );
    } catch (_) {
      if (!context.mounted) return;
      SnackbarUtil.showError(context, 'Failed to send app invite');
    }
  }
}
