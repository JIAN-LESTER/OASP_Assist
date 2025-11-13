import 'package:flutter/material.dart';

class SnackbarUtil {
  /// Shows a success snackbar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.check_circle_outline_outlined,
      backgroundColor: const Color(0xFF2E7D32),
      duration: duration,
    );
  }

  /// Shows an error snackbar
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.error_outline,
      backgroundColor: Colors.red,
      duration: duration,
    );
  }

  /// Shows an info snackbar
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.info_outline,
      backgroundColor: Colors.blue,
      duration: duration,
    );
  }

  /// Shows a warning snackbar
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.warning_amber_outlined,
      backgroundColor: Colors.orange,
      duration: duration,
    );
  }

  /// Internal method to show snackbar
  static void _showSnackbar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Duration duration,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: isMobile ? 20 : 24),
            SizedBox(width: isMobile ? 8 : 12),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: isMobile ? 15 : (isTablet ? 16 : 17),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 14 : 16,
        ),
        margin: EdgeInsets.only(
          bottom: 20,
          right: 20,
          left: isMobile ? 20 : (screenWidth - (isTablet ? 380 : 420)),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 6,
      ),
    );
  }
}
