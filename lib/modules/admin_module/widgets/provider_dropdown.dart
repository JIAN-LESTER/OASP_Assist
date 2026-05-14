import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScholarshipProviderDropdown extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final List<DocumentSnapshot> allScholarships;

  const ScholarshipProviderDropdown({
    Key? key,
    this.initialValue,
    this.onChanged,
    required this.allScholarships,
  }) : super(key: key);

  @override
  State<ScholarshipProviderDropdown> createState() =>
      _ScholarshipProviderDropdownState();
}

class _ScholarshipProviderDropdownState
    extends State<ScholarshipProviderDropdown> {
  String selectedValue = 'All Providers';

  List<String> get providerOptions {
    final providersByNormalized = <String, String>{};

    for (var doc in widget.allScholarships) {
      final data = doc.data() as Map<String, dynamic>;
      final provider = data['scholarshipProvider']?.toString().trim();
      final normalizedProvider = provider?.toLowerCase();
      if (provider != null &&
          provider.isNotEmpty &&
          provider != '-' &&
          normalizedProvider != null &&
          normalizedProvider.isNotEmpty) {
        providersByNormalized.putIfAbsent(normalizedProvider, () => provider);
      }
    }

    final sortedProviders = providersByNormalized.values.toList()..sort();
    return ['All Providers', ...sortedProviders];
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null &&
        providerOptions.contains(widget.initialValue)) {
      selectedValue = widget.initialValue!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;

        bool isMobile = screenWidth < 600;
        bool isTablet = screenWidth >= 600 && screenWidth < 1100;

        double width = isMobile ? double.infinity : (isTablet ? 150 : 160);
        double height = isMobile ? 48 : 45;
        double fontSize = isMobile ? 12 : (isTablet ? 12 : 14);
        double horizontalPadding = isMobile ? 14 : (isTablet ? 12 : 14);
        double iconSize = isMobile ? 20 : (isTablet ? 14 : 16);
        double borderRadius = 8;
        double borderWidth = 1.0;

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
            minWidth: width == double.infinity ? screenWidth - 32 : width,
            maxWidth: width == double.infinity ? screenWidth - 32 : width,
          ),
          itemBuilder: (BuildContext context) {
            return providerOptions.map((String item) {
              return PopupMenuItem<String>(
                value: item,
                child: Container(
                  width:
                      width == double.infinity
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
