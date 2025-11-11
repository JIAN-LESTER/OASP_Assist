import 'package:flutter/material.dart';

class RefreshButton extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool isRefreshing;

  const RefreshButton({
    Key? key,
    required this.onRefresh,
    this.isRefreshing = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;

        bool isMobile = screenWidth < 600;
        bool isTablet = screenWidth >= 600 && screenWidth < 1100;

        double size = isMobile ? 50 : 45;
        double iconSize = isMobile ? 20 : (isTablet ? 22 : 24);
        double borderRadius = isMobile ? 10 : 8;
        double borderWidth = isMobile ? 1.0 : 1.5;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isRefreshing ? null : onRefresh,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: isMobile ? 2 : 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child:
                    isRefreshing
                        ? SizedBox(
                          width: iconSize - 4,
                          height: iconSize - 4,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey[600]!,
                            ),
                          ),
                        )
                        : Icon(
                          Icons.refresh,
                          color: Colors.black87,
                          size: iconSize,
                        ),
              ),
            ),
          ),
        );
      },
    );
  }
}
