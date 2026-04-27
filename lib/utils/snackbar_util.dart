import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ToastLocation {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

enum AlertType { success, error, warning, info }

class SnackbarUtil {
  /// Shows a success snackbar
  static void showSuccess(
    BuildContext context,
    String message, {
    String? subtitle,
    bool showTimestamp = true,
    Duration duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onActionPressed,
    ToastLocation location = ToastLocation.topRight,
  }) {
    _showAlert(
      context,
      message: message,
      subtitle: subtitle,
      showTimestamp: showTimestamp,
      type: AlertType.success,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      location: location,
    );
  }

  /// Shows an error snackbar
  static void showError(
    BuildContext context,
    String message, {
    String? subtitle,
    bool showTimestamp = true,
    Duration duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onActionPressed,
    ToastLocation location = ToastLocation.topRight,
  }) {
    _showAlert(
      context,
      message: message,
      subtitle: subtitle,
      showTimestamp: showTimestamp,
      type: AlertType.error,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      location: location,
    );
  }

  /// Shows an info snackbar
  static void showInfo(
    BuildContext context,
    String message, {
    String? subtitle,
    bool showTimestamp = true,
    Duration duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onActionPressed,
    ToastLocation location = ToastLocation.topRight,
  }) {
    _showAlert(
      context,
      message: message,
      subtitle: subtitle,
      showTimestamp: showTimestamp,
      type: AlertType.info,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      location: location,
    );
  }

  /// Shows a warning snackbar
  static void showWarning(
    BuildContext context,
    String message, {
    String? subtitle,
    bool showTimestamp = true,
    Duration duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onActionPressed,
    ToastLocation location = ToastLocation.topRight,
  }) {
    _showAlert(
      context,
      message: message,
      subtitle: subtitle,
      showTimestamp: showTimestamp,
      type: AlertType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      location: location,
    );
  }

  /// Internal method to show alert overlay
  static void _showAlert(
    BuildContext context, {
    required String message,
    String? subtitle,
    bool showTimestamp = true,
    required AlertType type,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
    required ToastLocation location,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // Generate timestamp
    final now = DateTime.now();
    final formattedTimestamp = DateFormat(
      'EEEE, MMMM dd, yyyy \'at\' h:mm a',
    ).format(now);

    overlayEntry = OverlayEntry(
      builder:
          (context) => ToastAlert(
            message: message,
            subtitle: subtitle ?? (showTimestamp ? formattedTimestamp : null),
            type: type,
            onDismiss: () => overlayEntry.remove(),
            isMobile: isMobile,
            isTablet: isTablet,
            duration: duration,
            actionLabel: actionLabel,
            onActionPressed:
                onActionPressed != null
                    ? () {
                      onActionPressed();
                      overlayEntry.remove();
                    }
                    : null,
            location: location,
          ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(duration, () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }
}

class ToastAlert extends StatefulWidget {
  final String message;
  final String? subtitle;
  final AlertType type;
  final VoidCallback onDismiss;
  final bool isMobile;
  final bool isTablet;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Duration duration;
  final ToastLocation location;

  const ToastAlert({
    super.key,
    required this.message,
    this.subtitle,
    required this.type,
    required this.onDismiss,
    this.isMobile = false,
    this.isTablet = false,
    this.actionLabel,
    this.onActionPressed,
    this.duration = const Duration(seconds: 5),
    required this.location,
  });

  @override
  State<ToastAlert> createState() => _ToastAlertState();
}

class _ToastAlertState extends State<ToastAlert>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Determine slide direction based on location
    Offset slideBegin;
    switch (widget.location) {
      case ToastLocation.topLeft:
      case ToastLocation.topCenter:
      case ToastLocation.topRight:
        slideBegin = const Offset(0, -0.5); // Slide down from top
        break;
      case ToastLocation.bottomLeft:
      case ToastLocation.bottomCenter:
      case ToastLocation.bottomRight:
        slideBegin = const Offset(0, 0.5); // Slide up from bottom
        break;
    }

    _slideAnimation = Tween<Offset>(
      begin: slideBegin,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  Color _getIconBackgroundColor() {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF10B981);
      case AlertType.error:
        return const Color(0xFFEF4444);
      case AlertType.warning:
        return const Color(0xFFF59E0B);
      case AlertType.info:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case AlertType.success:
        return Icons.check_circle;
      case AlertType.error:
        return Icons.error;
      case AlertType.warning:
        return Icons.warning_amber_rounded;
      case AlertType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    double alertWidth;
    double? top;
    double? bottom;
    double? left;
    double? right;

    // Determine width
    if (widget.isMobile) {
      alertWidth = screenWidth - 32;
    } else if (widget.isTablet) {
      alertWidth = 420;
    } else {
      alertWidth = 460;
    }

    // Determine position based on location
    const padding = 24.0;
    const mobilePadding = 16.0;
    final actualPadding = widget.isMobile ? mobilePadding : padding;

    switch (widget.location) {
      case ToastLocation.topLeft:
        top = actualPadding;
        left = actualPadding;
        break;
      case ToastLocation.topCenter:
        top = actualPadding;
        left = (screenWidth - alertWidth) / 2;
        break;
      case ToastLocation.topRight:
        top = actualPadding;
        right = actualPadding;
        break;
      case ToastLocation.bottomLeft:
        bottom = actualPadding;
        left = actualPadding;
        break;
      case ToastLocation.bottomCenter:
        bottom = actualPadding;
        left = (screenWidth - alertWidth) / 2;
        break;
      case ToastLocation.bottomRight:
        bottom = actualPadding;
        right = actualPadding;
        break;
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: alertWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getIconBackgroundColor(),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(_getIcon(), color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    // Message and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action Button (if provided)
                    if (widget.actionLabel != null &&
                        widget.onActionPressed != null) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onActionPressed,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.actionLabel!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Close Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: _dismiss,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
