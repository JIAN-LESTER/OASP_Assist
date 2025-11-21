import 'package:capstone_project/responsive/widgets/persistent_drawer_group.dart';
import 'package:flutter/material.dart';

Widget buildPersistentDrawerItem({
  required BuildContext context,
  required IconData icon,
  required String title,
  required int index,
  required int selectedIndex,
  required Function(int) onTap,
  required bool isExpanded,
  bool isLogout = false,
  bool isServiceGroup = false,
  bool isSubItem = false,
}) {
  final bool isSelected = selectedIndex == index && !isLogout;
  final bool isServiceSelected =
      (selectedIndex >= 8 && selectedIndex <= 10) && isServiceGroup;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    constraints: const BoxConstraints(minHeight: 44),
    child: Material(
      color:
          isLogout
              ? Colors.red[50]
              : (isSelected || isServiceSelected
                  ? Colors.green[50]
                  : Colors.transparent),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
  borderRadius: BorderRadius.circular(8),
  onTap: () {
    // ✅ Close all groups when clicking any item
    if (index >= 0) {
      PersistentDrawerState.resetExpansionStates();
    }
    onTap(index);
  },
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.symmetric(
            horizontal: isSubItem ? 8 : 8,
            vertical: 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Green vertical line for selected state
              Container(
                width: 3,
                height: 20,
                margin: EdgeInsets.only(left: isSubItem ? 4 : 4, right: 8),
                decoration: BoxDecoration(
                  color:
                      (isSelected || isServiceSelected)
                          ? Colors.green[700]
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),

              // Icon
              Container(
                width: 20,
                height: 20,
                margin: EdgeInsets.only(left: isSubItem ? 0 : 0, right: 8),
                child: Icon(
                  icon,
                  color:
                      isLogout
                          ? Colors.red[600]
                          : (isSelected || isServiceSelected
                              ? Colors.green[700]
                              : Colors.grey[600]),
                  size: isSubItem ? 18 : 20,
                ),
              ),

              // Text with proper expansion
              if (isExpanded)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      title,
                      style: TextStyle(
                        color:
                            isLogout
                                ? Colors.red[600]
                                : (isSelected || isServiceSelected
                                    ? Colors.green[700]
                                    : Colors.grey[700]),
                        fontWeight:
                            (isSelected || isServiceSelected)
                                ? FontWeight.w600
                                : FontWeight.w400,
                        fontSize: isSubItem ? 13 : 14,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      maxLines: null,
                    ),
                  ),
                ),

              // Tooltip for collapsed state
              if (!isExpanded)
                Expanded(
                  child: Tooltip(message: title, child: Container(height: 44)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}