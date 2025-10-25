import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget tabletBody;
  final Widget desktopBody;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    required this.tabletBody,
    required this.desktopBody,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;

        if (width < 600) {
          // Mobile layout
          return mobileBody;
        } else if (width >= 600 && width < 1100) {
          // Tablet layout
          return tabletBody;
        } else {
          // Desktop layout
          return desktopBody;
        }
      },
    );
  }
}
