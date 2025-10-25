import 'package:flutter/material.dart';


enum AlertType { success, error, warning, info }

// Top right alert widget
class TopRightAlert extends StatefulWidget {
  final String message;
  final AlertType type;
  final VoidCallback onDismiss;
  final bool isMobile;
  final bool isTablet;

  const TopRightAlert({
    Key? key,
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.isMobile,
    required this.isTablet,
  }) : super(key: key);

  @override
  State<TopRightAlert> createState() => _TopRightAlertState();
}

class _TopRightAlertState extends State<TopRightAlert>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF047857);
      case AlertType.error:
        return const Color(0xFFDC2626);
      case AlertType.warning:
        return const Color(0xFFD97706);
      case AlertType.info:
        return const Color(0xFF2563EB);
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case AlertType.success:
        return Icons.check_circle;
      case AlertType.error:
        return Icons.error;
      case AlertType.warning:
        return Icons.warning;
      case AlertType.info:
        return Icons.info;
    }
  }

  void _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    double topPadding = widget.isMobile ? 80 : 100;
    double rightPadding =
        widget.isMobile
            ? 20
            : widget.isTablet
            ? 32
            : 40;
    double maxWidth =
        widget.isMobile
            ? screenSize.width * 0.85
            : widget.isTablet
            ? 400
            : 450;
    double minWidth = widget.isMobile ? 320 : 360;

    return Positioned(
      top: topPadding,
      right: rightPadding,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                minWidth: minWidth,
              ),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.isMobile ? 16 : 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        _getIcon(),
                        color: Colors.white,
                        size: widget.isMobile ? 18 : 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.isMobile ? 14 : 15,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.9),
                          size: 16,
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