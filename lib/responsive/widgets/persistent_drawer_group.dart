import 'package:flutter/material.dart';
import 'package:capstone_project/responsive/widgets/persistent_drawer_item.dart';

// State management class for persistent drawer expansion
class PersistentDrawerState extends ChangeNotifier {
  static bool _isServicesExpanded =
      false; // Changed from true to false para d mag cgeg open ang services dropdown once mo login or refresh the page
  static bool _isLogsExpanded = false;
  static bool _isUserManagementExpanded = false;

  static bool get isServicesExpanded => _isServicesExpanded;
  static bool get isLogsExpanded => _isLogsExpanded;
  static bool get isUserManagementExpanded => _isUserManagementExpanded;

  static void setServicesExpanded(bool expanded) {
    _isServicesExpanded = expanded;
  }

  static void setLogsExpanded(bool expanded) {
    _isLogsExpanded = expanded;
  }

  static void setUserManagementExpanded(bool expanded) {
    _isUserManagementExpanded = expanded;
  }

  static bool getExpansionState(int groupIndex) {
    switch (groupIndex) {
      case -1: // Services
        return _isUserManagementExpanded;
      case -2: // Logs
        return _isServicesExpanded;
      case -3:
        return _isLogsExpanded;
      default:
        return false;
    }
  }

  static void setExpansionState(int groupIndex, bool expanded) {
    switch (groupIndex) {
      case -1:
        _isUserManagementExpanded = expanded;
        break;
      case -2: // Services
        _isServicesExpanded = expanded;
        break;
      case -3: // Logs
        _isLogsExpanded = expanded;
        break;
    }
  }

  // Optional: Add a method to reset all expansion states to default (collapsed)
  static void resetExpansionStates() {
    _isServicesExpanded = false;
    _isLogsExpanded = false;
    _isUserManagementExpanded = false;
  }
}

Widget buildPersistentDrawerGroup({
  required BuildContext context,
  required IconData icon,
  required String title,
  required int groupIndex, // like -1 for Services, -2 for Logs
  required int selectedIndex,
  required Function(int) onTap,
  required bool isExpanded,
  required List<Widget> children,
  required bool isServicesExpanded,
}) {
  return isExpanded
      ? _buildExpandedGroupItem(
        context: context,
        icon: icon,
        title: title,
        groupIndex: groupIndex,
        children: children,
      )
      : _buildCollapsedGroupItem(
        context: context,
        icon: icon,
        title: title,
        groupIndex: groupIndex,
        selectedIndex: selectedIndex,
        onTap: onTap,
        children: children,
      );
}

Widget _buildExpandedGroupItem({
  required BuildContext context,
  required IconData icon,
  required String title,
  required int groupIndex,
  required List<Widget> children,
}) {
  // Get current expansion state from the state manager
  bool currentlyExpanded = PersistentDrawerState.getExpansionState(groupIndex);

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        expansionTileTheme: ExpansionTileThemeData(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          childrenPadding: const EdgeInsets.only(left: 0, top: 4),
          iconColor: Colors.grey[600],
          collapsedIconColor: Colors.grey[600],
          textColor: Colors.grey[700],
          collapsedTextColor: Colors.grey[700],
          expansionAnimationStyle: AnimationStyle(duration: Duration.zero),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ExpansionTile(
            minTileHeight: 44,
            key: ValueKey('${groupIndex}_${PersistentDrawerState.getExpansionState(groupIndex)}'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            leading: Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(left: 12),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.grey[600], size: 20),
            ),
            title: Container(
              margin: const EdgeInsets.only(left: 4),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
            initiallyExpanded: currentlyExpanded,
            onExpansionChanged: (expanded) {
              PersistentDrawerState.setExpansionState(groupIndex, expanded);
            },
            children:
                children.map((child) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    child: child,
                  );
                }).toList(),
          ),
        ),
      ),
    ),
  );
}

Widget _buildCollapsedGroupItem({
  required BuildContext context,
  required IconData icon,
  required String title,
  required int groupIndex,
  required int selectedIndex,
  required Function(int) onTap,
  required List<Widget> children,
}) {
  return StatefulBuilder(
    builder: (context, setState) {
      bool isExpanded = PersistentDrawerState.getExpansionState(groupIndex);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header with expansion toggle
          Stack(
            children: [
              // Base item using buildPersistentDrawerItem
              buildPersistentDrawerItem(
                context: context,
                icon: icon,
                title: title,
                index: groupIndex,
                selectedIndex: selectedIndex,
                onTap: (index) {
                  // Toggle expansion state
                  setState(() {
                    bool newState =
                        !PersistentDrawerState.getExpansionState(groupIndex);
                    PersistentDrawerState.setExpansionState(
                      groupIndex,
                      newState,
                    );
                  });
                },
                isExpanded: false, // Always false for collapsed drawer
              ),

              // Expansion indicator
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[500],
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

          // Children items (shown vertically below when expanded)
          if (isExpanded) ...[
            Container(
              width: 80, // collapsed drawer width
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    children.map((child) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 1,
                        ),
                        child: child,
                      );
                    }).toList(),
              ),
            ),
          ],
        ],
      );
    },
  );
}
