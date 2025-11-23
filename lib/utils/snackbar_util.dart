import 'package:flutter/material.dart';

class SnackbarUtil {
  /// Shows a success snackbar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    _showTopRightAlert(
      context,
      message: message,
      type: AlertType.success,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  /// Shows an error snackbar
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    _showTopRightAlert(
      context,
      message: message,
      type: AlertType.error,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  /// Shows an info snackbar
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    _showTopRightAlert(
      context,
      message: message,
      type: AlertType.info,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  /// Shows a warning snackbar
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    _showTopRightAlert(
      context,
      message: message,
      type: AlertType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  /// Internal method to show top-right alert overlay
  static void _showTopRightAlert(
    BuildContext context, {
    required String message,
    required AlertType type,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    overlayEntry = OverlayEntry(
      builder:
          (context) => TopRightAlert(
            message: message,
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
          ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(duration, () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }
}

enum AlertType { success, error, warning, info }

class TopRightAlert extends StatefulWidget {
  final String message;
  final AlertType type;
  final VoidCallback onDismiss;
  final bool isMobile;
  final bool isTablet;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Duration duration;

  const TopRightAlert({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
    this.isMobile = false,
    this.isTablet = false,
    this.actionLabel,
    this.onActionPressed,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<TopRightAlert> createState() => _TopRightAlertState();
}

class _TopRightAlertState extends State<TopRightAlert>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Progress animation for the underline
    _progressController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );

    _progressController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF1E3A32);
      case AlertType.error:
        return const Color(0xFF3A2327);
      case AlertType.warning:
        return const Color(0xFF3A3227);
      case AlertType.info:
        return const Color(0xFF2D2D2D);
    }
  }

  LinearGradient _getProgressGradient() {
    switch (widget.type) {
      case AlertType.success:
        return const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case AlertType.error:
        return const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case AlertType.warning:
        return const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case AlertType.info:
        return const LinearGradient(
          colors: [Color(0xFF4B5563), Color(0xFF6B7280)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    }
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
        return const Color(0xFF6B7280);
    }
  }

  Color _getActionButtonColor() {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF059669);
      case AlertType.error:
        return const Color(0xFF991B1B);
      case AlertType.warning:
        return const Color(0xFF92400E);
      case AlertType.info:
        return const Color(0xFF4B5563);
    }
  }

  Color _getActionTextColor() {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF6EE7B7);
      case AlertType.error:
        return const Color(0xFFFCA5A5);
      case AlertType.warning:
        return const Color(0xFFFCD34D);
      case AlertType.info:
        return Colors.white70;
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
    double alertWidth;
    double topPosition;
    double rightPosition;

    if (widget.isMobile) {
      alertWidth = screenWidth - 32;
      topPosition = 16;
      rightPosition = 16;
    } else if (widget.isTablet) {
      alertWidth = 420;
      topPosition = 24;
      rightPosition = 24;
    } else {
      alertWidth = 460;
      topPosition = 24;
      rightPosition = 24;
    }

    return Positioned(
      top: topPosition,
      right: rightPosition,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: alertWidth,
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Content
                  Padding(
                    padding: EdgeInsets.all(widget.isMobile ? 16 : 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getIconBackgroundColor(),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                _getIcon(),
                                color: Colors.white,
                                size: widget.isMobile ? 20 : 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: widget.isMobile ? 15 : 16,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _dismiss,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white.withOpacity(0.7),
                                    size: widget.isMobile ? 18 : 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Action Buttons
                        if (widget.actionLabel != null ||
                            widget.onActionPressed != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (widget.actionLabel != null &&
                                  widget.onActionPressed != null)
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: widget.onActionPressed,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getActionButtonColor(),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          widget.actionLabel!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _getActionTextColor(),
                                            fontSize: widget.isMobile ? 14 : 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _dismiss,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'Dismiss',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: widget.isMobile ? 14 : 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Progress indicator at bottom
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: SizedBox(
                      height: 4,
                      child: Stack(
                        children: [
                          // Background
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ),
                          // Progress bar with gradient
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: _progressAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: _getProgressGradient(),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
