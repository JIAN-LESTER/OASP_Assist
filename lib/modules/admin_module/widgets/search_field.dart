import 'package:flutter/material.dart';

Widget buildSearchField(
  String message,
  TextEditingController controller, {
  VoidCallback? onSearchChanged,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;

      return Container(
        height: isMobile ? 50 : 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          enabled: true,
          onChanged: (value) {
            // Trigger rebuild when search text changes
            if (onSearchChanged != null) {
              onSearchChanged();
            }
          },
          decoration: InputDecoration(
            hintText: 'Search by $message...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: isMobile ? 14 : 15,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey[400],
              size: isMobile ? 20 : 22,
            ),
            suffixIcon:
                controller.text.isNotEmpty
                    ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey[400],
                        size: isMobile ? 18 : 20,
                      ),
                      onPressed: () {
                        controller.clear();
                        if (onSearchChanged != null) {
                          onSearchChanged();
                        }
                      },
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isMobile ? 15 : 12,
            ),
          ),
        ),
      );
    },
  );
}