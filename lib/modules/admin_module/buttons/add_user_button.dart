import 'package:capstone_project/modules/admin_module/user_management_module/add_user_modal.dart';
import 'package:flutter/material.dart';

class AddUserButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Function(int)? onNavigateToPage; // Add this parameter

  const AddUserButton({
    Key? key,
    this.onPressed,
    this.onNavigateToPage, // Add this to constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;

        // Using the same breakpoints as ResponsiveLayout
        bool isMobile = screenWidth < 600;
        bool isTablet = screenWidth >= 600 && screenWidth < 1100;

        // Responsive dimensions
        double height = isMobile ? 44 : (isTablet ? 46 : 48);
        double fontSize = isMobile ? 13 : (isTablet ? 14 : 15);
        double horizontalPadding = isMobile ? 16 : (isTablet ? 18 : 20);
        double iconSize = isMobile ? 18 : (isTablet ? 20 : 22);
        double borderRadius = 8;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: isMobile ? 2 : 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: onPressed ?? () => _showAddUserModal(context),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: iconSize),
                    const SizedBox(width: 8),
                    Text(
                      'Add New User',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddUserModal(BuildContext context) {
    showAddUserModal(
      context,
      onNavigateToPage: onNavigateToPage, // Pass the callback
    );
  }
}