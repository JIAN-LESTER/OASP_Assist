import 'package:flutter/material.dart';

class FaqCategoryDropdownButton extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String>? onChanged;

  const FaqCategoryDropdownButton({Key? key, this.initialValue, this.onChanged})
    : super(key: key);

  @override
  State<FaqCategoryDropdownButton> createState() =>
      _CategoryDropdownButtonState();
}

class _CategoryDropdownButtonState extends State<FaqCategoryDropdownButton> {
  String selectedValue = 'All Categories';

  final List<String> dropdownItems = [
    'All Categories',
    'Admission',
    'Scholarship',
    'Placement',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null &&
        dropdownItems.contains(widget.initialValue)) {
      selectedValue = widget.initialValue!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;

        // Using the same breakpoints as ResponsiveLayout
        bool isMobile = screenWidth < 600;
        bool isTablet = screenWidth >= 600 && screenWidth < 1100;
        bool isDesktop = screenWidth >= 1100;

        // Responsive dimensions
        double width = isMobile ? double.infinity : (isTablet ? 160 : 170);
        double height = isMobile ? 50 : 45;
        double fontSize = isMobile ? 14 : (isTablet ? 15 : 16);
        double horizontalPadding = isMobile ? 12 : (isTablet ? 14 : 16);
        double iconSize = isMobile ? 20 : (isTablet ? 22 : 24);
        double borderRadius = isMobile ? 8 : 8;
        double borderWidth = 1.0;

        return PopupMenuButton<String>(
          initialValue: selectedValue,
          onSelected: (String value) {
            setState(() {
              selectedValue = value;
            });
            widget.onChanged?.call(value);
          },
          offset: Offset(
            0,
            height + 8,
          ), // Position dropdown below the button with margin
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          color: Colors.white,
          elevation: isMobile ? 4 : 8,
          constraints: BoxConstraints(
            minWidth: width == double.infinity ? screenWidth - 32 : width,
            maxWidth: width == double.infinity ? screenWidth - 32 : width,
          ),
          itemBuilder: (BuildContext context) {
            return dropdownItems.map((String item) {
              return PopupMenuItem<String>(
                value: item,
                child: Container(
                  width: width == double.infinity
                      ? screenWidth - 32
                      : width - (horizontalPadding * 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    item,
                    style: TextStyle(color: Colors.black87, fontSize: fontSize),
                  ),
                ),
              );
            }).toList();
          },
          child: Container(
            width: width,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.grey[300]!, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: isMobile ? 2 : 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedValue,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.black87,
                  size: iconSize,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
