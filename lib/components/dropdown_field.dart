import 'package:flutter/material.dart';

class DropdownField extends StatefulWidget {
  final String hintText;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;
  final String? Function(String?)? validator; // Optional validation

  const DropdownField({
    super.key,
    required this.hintText,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  State<DropdownField> createState() => _DropdownFieldState();
}

class _DropdownFieldState extends State<DropdownField> {
  String? _errorText;

  void _validateField(String? value) {
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;

        // Using the same breakpoints as CategoryDropdownButton
        bool isMobile = screenWidth < 600;
        bool isTablet = screenWidth >= 600 && screenWidth < 1100;
        bool isDesktop = screenWidth >= 1100;

        // Responsive dimensions - smaller sizes
        double fontSize = isMobile ? 13 : (isTablet ? 14 : 15);
        double horizontalPadding = isMobile ? 10 : (isTablet ? 12 : 14);
        double verticalPadding = isMobile ? 12 : (isTablet ? 13 : 14);
        double borderRadius = isMobile ? 8 : 8;
        double iconSize = isMobile ? 18 : (isTablet ? 20 : 22);
        double fieldHeight = isMobile ? 45 : (isTablet ? 47 : 49);

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 0, // Remove horizontal padding when used in a row
            vertical: 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PopupMenuButton<String>(
                initialValue: widget.value,
                onSelected: (String value) {
                  widget.onChanged(value);
                  _validateField(value);
                },
                offset: Offset(
                  0,
                  fieldHeight + 8,
                ), // Position dropdown below the button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                color: Colors.white,
                elevation: isMobile ? 4 : 8,
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  maxWidth: constraints.maxWidth,
                  maxHeight: isMobile ? 200 : (isTablet ? 250 : 300),
                ),
                itemBuilder: (BuildContext context) {
                  return widget.items.map((String item) {
                    return PopupMenuItem<String>(
                      value: item,
                      child: Container(
                        width: constraints.maxWidth - (horizontalPadding * 2),
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 8,
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: fontSize,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.1,
                            height: 1.4,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  width: double.infinity,
                  height: fieldHeight,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color:
                          _errorText != null ? Colors.red : Colors.grey[400]!,
                      width: 1.5,
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.value ?? widget.hintText,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color:
                                widget.value != null
                                    ? Colors.black87
                                    : Colors.grey[500],
                            fontSize: fontSize,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.1,
                            height: 1.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey[600],
                        size: iconSize,
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorText != null)
                Padding(
                  padding: EdgeInsets.only(left: horizontalPadding, top: 6),
                  child: Text(
                    _errorText!,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.red,
                      fontSize: fontSize - 2,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
