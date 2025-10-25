import 'package:flutter/material.dart';

class CustomDropdownButton extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final List<String> items;

  const CustomDropdownButton({
    Key? key,
    this.initialValue,
    this.onChanged,
    required this.items,
  }) : super(key: key);

  @override
  State<CustomDropdownButton> createState() => _CustomDropdownButtonState();
}

class _CustomDropdownButtonState extends State<CustomDropdownButton> {
  late String selectedValue;

  @override
  void initState() {
    super.initState();
    selectedValue = widget.initialValue ?? widget.items.first;
  }

  @override
  void didUpdateWidget(CustomDropdownButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selectedValue if initialValue changed and it's valid
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != null &&
        widget.items.contains(widget.initialValue)) {
      selectedValue = widget.initialValue!;
    }
  }

  /// Calculate the width needed to fit the widest item without ellipsis
  double _calculateDropdownWidth(BuildContext context, double fontSize, double horizontalPadding, double iconSize) {
    final textScale = MediaQuery.of(context).textScaleFactor;
    final TextStyle style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );

    double maxWidth = 0;
    for (var item in widget.items) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: item, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaleFactor: textScale,
      )..layout();

      if (painter.width > maxWidth) {
        maxWidth = painter.width;
      }
    }

    // Add padding on both sides + icon width + spacing between text and icon + extra buffer
    return maxWidth + (horizontalPadding * 2) + iconSize + 8 + 12; // Added 12px buffer
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;

        bool isMobile = screenWidth < 600;
        bool isTablet = screenWidth >= 600 && screenWidth < 1100;

        double height = isMobile ? 50 : 45;
        double fontSize = isMobile ? 14 : (isTablet ? 15 : 16);
        double horizontalPadding = isMobile ? 12 : (isTablet ? 14 : 16);
        double iconSize = isMobile ? 20 : (isTablet ? 22 : 24);
        double borderRadius = isMobile ? 10 : 8;
        double borderWidth = isMobile ? 1.0 : 1.5;

        // Calculate width based on content
        double calculatedWidth = _calculateDropdownWidth(
          context, 
          fontSize, 
          horizontalPadding, 
          iconSize
        );

        // Set minimum and maximum constraints for width
        double minWidth = isMobile ? 120 : 140;
        double maxWidth = screenWidth * 0.4; // Don't take more than 40% of screen

        double width = calculatedWidth.clamp(minWidth, maxWidth);

        return PopupMenuButton<String>(
          initialValue: selectedValue,
          onSelected: (String value) {
            setState(() {
              selectedValue = value;
            });
            widget.onChanged?.call(value);
          },
          offset: Offset(0, height + 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          color: Colors.white,
          elevation: isMobile ? 4 : 8,
          constraints: BoxConstraints(
            minWidth: width,
            maxWidth: width,
          ),
          itemBuilder: (BuildContext context) {
            return widget.items.map((String item) {
              return PopupMenuItem<String>(
                value: item,
                child: Container(
                  width: width - (horizontalPadding * 2),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.black87, 
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                // Use Flexible to prevent overflow
                Flexible(
                  child: Text(
                    selectedValue,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: 8), // Add spacing between text and icon
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