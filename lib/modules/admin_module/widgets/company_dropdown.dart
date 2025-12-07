import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlacementCompanyDropdown extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final List<DocumentSnapshot> allPlacements;

  const PlacementCompanyDropdown({
    Key? key,
    this.initialValue,
    this.onChanged,
    required this.allPlacements,
  }) : super(key: key);

  @override
  State<PlacementCompanyDropdown> createState() =>
      _PlacementCompanyDropdownState();
}

class _PlacementCompanyDropdownState
    extends State<PlacementCompanyDropdown> {
  String selectedValue = 'All Companies';

  List<String> get companyOptions {
    final companys = <String>{};

    for (var doc in widget.allPlacements) {
      final data = doc.data() as Map<String, dynamic>;
      final company = data['partnerCompany']?.toString();
      if (company != null && company.isNotEmpty && company != '-') {
        companys.add(company);
      }
    }

    final sortedcompanys = companys.toList()..sort();
    return ['All Companies', ...sortedcompanys];
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null &&
        companyOptions.contains(widget.initialValue)) {
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
            return companyOptions.map((String item) {
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
