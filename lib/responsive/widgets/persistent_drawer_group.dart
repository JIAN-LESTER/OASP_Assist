import 'package:capstone_project/responsive/widgets/persistent_drawer_item.dart';
import 'package:flutter/material.dart';

// State management class for persistent drawer expansion
class PersistentDrawerState extends ChangeNotifier {
  static bool _isLogsExpanded = false;
  static bool _isUserManagementExpanded = false;

  static final List<VoidCallback> _stateListeners = [];

  static bool get isLogsExpanded => _isLogsExpanded;
  static bool get isUserManagementExpanded => _isUserManagementExpanded;

  static void setLogsExpanded(bool expanded) {
    _isLogsExpanded = expanded;
    _notifyAllListeners();
  }

  static void setUserManagementExpanded(bool expanded) {
    _isUserManagementExpanded = expanded;
    _notifyAllListeners();
  }

  static bool getExpansionState(int groupIndex) {
    switch (groupIndex) {
      case -1:
        return _isUserManagementExpanded;
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
      case -3:
        _isLogsExpanded = expanded;
        break;
    }
    _notifyAllListeners();
  }

  static void resetExpansionStates() {
    _isLogsExpanded = false;
    _isUserManagementExpanded = false;
    _notifyAllListeners();
  }

  static void addStateListener(VoidCallback listener) {
    _stateListeners.add(listener);
  }

  static void removeStateListener(VoidCallback listener) {
    _stateListeners.remove(listener);
  }

  static void _notifyAllListeners() {
    for (var listener in _stateListeners) {
      listener();
    }
  }
}

Widget buildPersistentDrawerGroup({
  required BuildContext context,
  required IconData icon,
  required String title,
  required int groupIndex,
  required int selectedIndex,
  required Function(int) onTap,
  required bool isExpanded,
  required List<Widget> children,
  required bool isGroupExpanded,
}) {
  return _PersistentDrawerGroupWidget(
    icon: icon,
    title: title,
    groupIndex: groupIndex,
    selectedIndex: selectedIndex,
    onTap: onTap,
    isExpanded: isExpanded,
    children: children,
  );
}

class _PersistentDrawerGroupWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final int groupIndex;
  final int selectedIndex;
  final Function(int) onTap;
  final bool isExpanded;
  final List<Widget> children;

  const _PersistentDrawerGroupWidget({
    required this.icon,
    required this.title,
    required this.groupIndex,
    required this.selectedIndex,
    required this.onTap,
    required this.isExpanded,
    required this.children,
  });

  @override
  State<_PersistentDrawerGroupWidget> createState() =>
      _PersistentDrawerGroupWidgetState();
}

class _PersistentDrawerGroupWidgetState
    extends State<_PersistentDrawerGroupWidget> {
  @override
  void initState() {
    super.initState();
    PersistentDrawerState.addStateListener(_onStateChanged);
  }

  @override
  void dispose() {
    PersistentDrawerState.removeStateListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTap() {
    bool currentState = PersistentDrawerState.getExpansionState(
      widget.groupIndex,
    );

    // Close ALL OTHER groups first
    if (widget.groupIndex != -1)
      PersistentDrawerState.setUserManagementExpanded(false);
    if (widget.groupIndex != -3) PersistentDrawerState.setLogsExpanded(false);

    // Toggle current group
    PersistentDrawerState.setExpansionState(widget.groupIndex, !currentState);
  }

  @override
  Widget build(BuildContext context) {
    bool isGroupExpanded = PersistentDrawerState.getExpansionState(
      widget.groupIndex,
    );

    if (!widget.isExpanded) {
      // Collapsed drawer (icon only) - Show dropdown inline below icon
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon button with dropdown indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            constraints: const BoxConstraints(minHeight: 44),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _handleTap,
                child: Tooltip(
                  message: widget.title,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(widget.icon, color: Colors.grey[600], size: 20),
                        // Small dropdown arrow indicator
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isGroupExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Show children below icon when expanded
          if (isGroupExpanded)
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.children,
              ),
            ),
        ],
      );
    }

    // Expanded drawer (with text) - Full dropdown functionality
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _handleTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        widget.icon,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      isGroupExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isGroupExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.children,
              ),
            ),
        ],
      ),
    );
  }
}
