import 'dart:async';
import 'package:capstone_project/notifications.dart';
import 'package:capstone_project/profile.dart';
import 'package:capstone_project/provider/chat_provider.dart';
import 'package:capstone_project/responsive/user_constant.dart';
import 'package:capstone_project/responsive/widgets/logout.dart';
import 'package:capstone_project/responsive/widgets/persistent_drawer_group.dart';
import 'package:capstone_project/responsive/widgets/persistent_drawer_item.dart';
import 'package:capstone_project/utils/snackbar_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Enums for different user roles and menu configurations
enum UserRole { admin, user, staff }

// Data models for menu items
class MenuItem {
  final IconData icon;
  final String title;
  final int index;
  final List<MenuItem>? subItems;
  final bool isExpandable;
  final VoidCallback? onTap;

  MenuItem({
    required this.icon,
    required this.title,
    required this.index,
    this.subItems,
    this.isExpandable = false,
    this.onTap,
  });
}

class MenuConfig {
  final List<MenuItem> items;
  final bool showNewChatButton;
  final bool showConversationList;
  final bool showLogoutButton;

  MenuConfig({
    required this.items,
    this.showNewChatButton = false,
    this.showConversationList = false,
    this.showLogoutButton = false,
  });
}

// Main reusable components class
class UniversalUIComponents {
  static Color get primaryGreen => const Color(0xFF2E7D32);
  static Color get lightGreen => const Color(0xFF4CAF50);
  static Color get backgroundGrey => Colors.grey[50]!;

  static AppBar buildAppBar({
    required BuildContext context,
    required UserRole userRole,
    String title = '',
    bool showBackButton = true,
    Widget? customLeading,
    VoidCallback? onLeadingPressed,
    bool showFAQToggle = false,
    bool? showFAQs,
    VoidCallback? onFAQToggle,
    bool? hasActiveConversation,
    bool isChatPage = false,
    List<Widget>? actions,
    GlobalKey? sidebarKey, // ADD THIS
    GlobalKey? notificationKey, // ADD THIS
    GlobalKey? profileKey, // ADD THIS
  }) {
    List<Widget> appBarActions = [];

    appBarActions.add(
      _buildNotificationButton(
        context,
        userRole,
        notificationKey: notificationKey,
      ),
    );

    // Add custom actions if provided
    if (actions != null) {
      appBarActions.addAll(actions);
    }

    // User profile dropdown
    appBarActions.add(
      _buildUserProfileDropdown(context, profileKey: profileKey),
    );
    appBarActions.add(const SizedBox(width: 13));

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: appBarActions,
      iconTheme: const IconThemeData(color: Colors.black54),
      automaticallyImplyLeading: showBackButton && customLeading == null,
      leading:
          customLeading ??
          (onLeadingPressed != null
              ? IconButton(
                key: sidebarKey,
                icon: const Icon(Icons.menu, color: Colors.black54),
                onPressed: onLeadingPressed,
              )
              : null),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: Colors.grey[300], height: 1.0),
      ),
    );
  }

  static Widget buildAppBarNewChatButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await UserConstant.startNewChat(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'New',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Universal Drawer
  static Drawer buildDrawer({
    required BuildContext context,
    required UserRole userRole,
    required int selectedIndex,
    required Function(int) onItemTap,
    Function? setState,
    List<Map<String, dynamic>>? recentConversations,
    String? selectedConversationId,
    Function(BuildContext, String?)?
    onConversationSelected, // This callback is key!
    VoidCallback? onNewChat,
  }) {
    final menuConfig = _getMenuConfig(userRole);

    return Drawer(
      backgroundColor: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
        ),
        child: StatefulBuilder(
          builder:
              (context, setDrawerState) => Column(
                children: [
                  _buildDrawerHeader(
                    context,
                    userRole,
                    onNewChat: onNewChat,
                    onItemTap: onItemTap,
                    selectedIndex: selectedIndex,
                  ),
                  Expanded(
                    child: _buildMenuItems(
                      context,
                      userRole,
                      menuConfig,
                      selectedIndex,
                      onItemTap,
                      setDrawerState,
                      setState: setState,
                      recentConversations: recentConversations,
                      selectedConversationId: selectedConversationId,
                      onConversationSelected:
                          onConversationSelected, // Pass it down
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  static Widget buildPersistentDrawer({
    required BuildContext context,
    required UserRole userRole,
    required int selectedIndex,
    required Function(int) onItemTap,
    required bool isExpanded,
    Function(BuildContext, String?)? onConversationSelected,
    VoidCallback? onNewChat, // ✅ ADD THIS PARAMETER
  }) {
    final menuConfig = _getMenuConfig(userRole);

    return Container(
      width: isExpanded ? 250 : 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPersistentDrawerHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: _buildPersistentMenuItems(
                  context,
                  userRole,
                  menuConfig,
                  selectedIndex,
                  onItemTap,
                  isExpanded,
                  onConversationSelected: onConversationSelected,
                  onNewChat: onNewChat, // ✅ PASS IT HERE
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Private helper methods
  static MenuConfig _getMenuConfig(UserRole userRole) {
    switch (userRole) {
      case UserRole.admin:
        return MenuConfig(
          items: [
            MenuItem(icon: Icons.home_outlined, title: 'Dashboard', index: 0),
            MenuItem(
              icon: Icons.analytics_outlined,
              title: 'Reports',
              index: 1,
            ),
            MenuItem(
              icon: Icons.book_outlined,
              title: 'Information Bank',
              index: 2,
            ),
            MenuItem(icon: Icons.help_outline, title: 'FAQs', index: 3),
            MenuItem(
              icon: Icons.announcement_outlined,
              title: 'Announcement',
              index: 4,
            ),
            MenuItem(icon: Icons.people, title: 'Human Escalation', index: 5),

            MenuItem(
              icon: Icons.person_outline,
              title: 'User Management',
              index: -1,
              isExpandable: true,
              subItems: [
                MenuItem(icon: Icons.person, title: "Users", index: 6),
                MenuItem(
                  icon: Icons.account_balance_outlined,
                  title: "Colleges",
                  index: 12,
                ),
                MenuItem(icon: Icons.book, title: "Programs", index: 13),
              ],
            ),
            MenuItem(
              icon: Icons.miscellaneous_services_outlined,
              title: 'Services',
              index: -2,
              isExpandable: true,
              subItems: [
                MenuItem(
                  icon: Icons.school_outlined,
                  title: 'Admission',
                  index: 9,
                ),
                MenuItem(
                  icon: Icons.card_giftcard_outlined,
                  title: 'Scholarship',
                  index: 10,
                ),
                MenuItem(
                  icon: Icons.work_outline,
                  title: 'Placement',
                  index: 11,
                ),
              ],
            ),
            MenuItem(
              icon: Icons.list_alt_outlined,
              title: 'Logs',
              index: -3,
              isExpandable: true,
              subItems: [
                MenuItem(
                  icon: Icons.history_outlined,
                  title: 'System Activity Logs',
                  index: 7,
                ),
                MenuItem(
                  icon: Icons.chat_bubble_outline,
                  title: 'Message Logs',
                  index: 8,
                ),
              ],
            ),
          ],
        );

      case UserRole.user:
        return MenuConfig(
          items: [
            MenuItem(
              icon: Icons.announcement_outlined,
              title: 'Home',
              index: 0,
            ),
            MenuItem(
              icon: Icons.chat_outlined,
              title: 'Chat with OASP Assist',
              index: 1,
            ),
            MenuItem(
              icon: Icons.announcement_outlined,
              title: 'Announcements',
              index: 2,
            ),
            MenuItem(
              icon: Icons.miscellaneous_services_outlined,
              title: 'Services',
              index: -1,
              isExpandable: true,
              subItems: [
                MenuItem(
                  icon: Icons.school_outlined,
                  title: 'Admission Information',
                  index: 3,
                ),
                MenuItem(
                  icon: Icons.card_giftcard_outlined,
                  title: 'Scholarship List',
                  index: 4,
                ),
                MenuItem(
                  icon: Icons.work_outline,
                  title: 'Placement Information',
                  index: 5,
                ),
              ],
            ),
          ],
          showNewChatButton: true,
          showConversationList: true,
        );

      case UserRole.staff:
        return MenuConfig(
          items: [
            MenuItem(icon: Icons.home_outlined, title: 'Dashboard', index: 0),
            MenuItem(
              icon: Icons.analytics_outlined,
              title: 'Reports',
              index: 1,
            ),
            MenuItem(
              icon: Icons.people_outline,
              title: 'Human Escalation',
              index: 2,
            ),
            MenuItem(
              icon: Icons.announcement_outlined,
              title: 'Announcement',
              index: 3,
            ),
            MenuItem(
              icon: Icons.list_alt_outlined,
              title: 'Message Logs',
              index: 4,
            ),
          ],
          showLogoutButton: true,
        );
    }
  }

  static Widget _buildDrawerHeader(
    BuildContext context,
    UserRole userRole, {
    VoidCallback? onNewChat,
    Function(int)? onItemTap,
    int? selectedIndex,
  }) {
    if (userRole == UserRole.user && onNewChat != null) {
      return DrawerHeader(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/images/oasp.png',
              width: 72,
              height: 72,
              // color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop(); // Close drawer first

                  // ✅ FIX: Wait for drawer to close
                  await Future.delayed(Duration(milliseconds: 300));

                  // ✅ Then call the callback
                  if (context.mounted) {
                    onNewChat();
                  }
                },
                icon: const Icon(Icons.add_comment_rounded, size: 20),
                label: const Text(
                  'New Chat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DrawerHeader(
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            userRole == UserRole.staff
                ? null
                : Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
      ),
      child: Center(
        child: Image.asset('lib/images/oasp.png', width: 80, height: 80),
      ),
    );
  }

  static Widget _buildPersistentDrawerHeader() {
    return Container(
      height: 80,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white),
      child: Center(
        child: Image.asset('lib/images/oasp.png', width: 90, height: 90),
      ),
    );
  }

  static Widget _buildMenuItems(
    BuildContext context,
    UserRole userRole,
    MenuConfig menuConfig,
    int selectedIndex,
    Function(int) onItemTap,
    StateSetter setDrawerState, {
    Function? setState,
    List<Map<String, dynamic>>? recentConversations,
    String? selectedConversationId,
    Function(BuildContext, String?)? onConversationSelected,
  }) {
    List<Widget> menuItems = [];

    for (final item in menuConfig.items) {
      if (item.isExpandable) {
        menuItems.add(
          _buildExpandableMenuItem(
            context,
            item,
            selectedIndex,
            onItemTap,
            setDrawerState,
            userRole,
          ),
        );

        // Add horizontal line and New Chat + Chat History after Services for user role
        if (userRole == UserRole.user && item.title == 'Services') {
          // Add horizontal line separator
          menuItems.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(color: Colors.grey[300], thickness: 1, height: 1),
            ),
          );

          // Add New Chat and Chat History section
          menuItems.add(
            _buildNewChatAndHistorySection(
              context,
              selectedConversationId,
              onConversationSelected,
              setDrawerState,
            ),
          );
        }
      } else {
        menuItems.add(
          _buildRegularMenuItem(
            context,
            item,
            selectedIndex,
            onItemTap,
            userRole,
            setDrawerState: setDrawerState, // ✅ ADD THIS
          ),
        );
      }
    }

    // ✅ CRITICAL FIX: Wrap in SingleChildScrollView to prevent overflow
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Column(children: menuItems),
    );
  }

  static Widget _buildRegularMenuItem(
    BuildContext context,
    MenuItem item,
    int selectedIndex,
    Function(int) onItemTap,
    UserRole userRole, {
    StateSetter? setDrawerState, // ✅ ADD THIS
  }) {
    final isSelected = selectedIndex == item.index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? Colors.green[50] : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            _handleItemTap(
              context: context,
              index: item.index,
              onItemTap: onItemTap,
              setDrawerState: setDrawerState,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  margin: const EdgeInsets.only(left: 4, right: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green[700] : Colors.transparent,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 8),
                  child: Icon(
                    item.icon,
                    color: isSelected ? Colors.green[700] : Colors.grey[600],
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.green[800] : Colors.grey[700],
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 Add this at the top of your drawer widget (or as static map if inside a class)
  static final Map<String, bool> _expandedState = {
    'Services': false,
    'Logs': false,
    'User Management': false,
  };

  // ✅ Add this counter to force rebuild
  static int _rebuildCounter = 0;

  // Replace the entire _buildExpandableMenuItem method with this:

  static Widget _buildExpandableMenuItem(
    BuildContext context,
    MenuItem item,
    int selectedIndex,
    Function(int) onItemTap,
    StateSetter setDrawerState,
    UserRole userRole,
  ) {
    // Get expansion state from the shared map
    bool isExpanded = _expandedState[item.title] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          expansionTileTheme: ExpansionTileThemeData(
            expansionAnimationStyle: AnimationStyle(duration: Duration.zero),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ExpansionTile(
              // ✅ Use counter to force unique key on every rebuild
              key: ValueKey('${item.title}_$isExpanded\_$_rebuildCounter'),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 0,
              ),
              childrenPadding: EdgeInsets.zero,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    margin: const EdgeInsets.only(left: 4, right: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    child: Icon(item.icon, color: Colors.grey[600], size: 20),
                  ),
                ],
              ),
              title: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              iconColor: Colors.grey[600],
              collapsedIconColor: Colors.grey[600],
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                // Close ALL groups first
                _expandedState['Services'] = false;
                _expandedState['Logs'] = false;
                _expandedState['User Management'] = false;

                PersistentDrawerState.setUserManagementExpanded(false);
                PersistentDrawerState.setServicesExpanded(false);
                PersistentDrawerState.setLogsExpanded(false);

                // Then open the clicked one if expanding
                if (expanded) {
                  _expandedState[item.title] = true;

                  if (item.title == 'User Management') {
                    PersistentDrawerState.setUserManagementExpanded(true);
                  } else if (item.title == 'Services') {
                    PersistentDrawerState.setServicesExpanded(true);
                  } else if (item.title == 'Logs') {
                    PersistentDrawerState.setLogsExpanded(true);
                  }
                }

                // ✅ Increment counter to force all tiles to rebuild
                _rebuildCounter++;

                // Force UI update
                setDrawerState(() {});
              },
              children:
                  item.subItems?.map((subItem) {
                    final isSubItemSelected = selectedIndex == subItem.index;

                    return Container(
                      margin: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        bottom: 2,
                      ),
                      child: Material(
                        color:
                            isSubItemSelected
                                ? Colors.green[50]
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            _handleItemTap(
                              context: context,
                              index: subItem.index,
                              onItemTap: onItemTap,
                              groupIndex: item.index,
                              setDrawerState: setDrawerState,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 18,
                                  margin: const EdgeInsets.only(
                                    left: 12,
                                    right: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSubItemSelected
                                            ? Colors.green[700]
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                                Container(
                                  width: 18,
                                  height: 18,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    subItem.icon,
                                    color:
                                        isSubItemSelected
                                            ? Colors.green[700]
                                            : Colors.grey[500],
                                    size: 18,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      subItem.title,
                                      style: TextStyle(
                                        color:
                                            isSubItemSelected
                                                ? Colors.green[800]
                                                : Colors.grey[600],
                                        fontSize: 13,
                                        fontWeight:
                                            isSubItemSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList() ??
                  [],
            ),
          ),
        ),
      ),
    );
  }

  static int? _getGroupIndexForItem(int itemIndex) {
    // Admin role
    if (itemIndex == 6 || itemIndex == 12 || itemIndex == 13) {
      return -1; // User Management group
    }
    if (itemIndex == 9 || itemIndex == 10 || itemIndex == 11) {
      return -2; // Services group
    }
    if (itemIndex == 7 || itemIndex == 8) {
      return -3; // Logs group
    }

    // User role
    if (itemIndex == 3 || itemIndex == 4 || itemIndex == 5) {
      return -1; // Services group for user
    }

    return null; // Not in any group
  }

  static Widget _buildNewChatAndHistorySection(
    BuildContext context,
    String? selectedConversationId,
    Function(BuildContext, String?)? onConversationSelected,
    StateSetter? setDrawerState,
  ) {
    bool isExpanded = UserConstant.isOASPAssistExpanded;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Column(
          children: [
            // New Chat Button
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              height: 44,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop();
                    await Future.delayed(Duration(milliseconds: 300));

                    if (context.mounted) {
                      final parentState =
                          context.findAncestorStateOfType<State>();
                      if (parentState != null) {
                        if (parentState.widget.runtimeType.toString() ==
                            '_UserMainPageState') {
                          await (parentState as dynamic)._onNewChatPressed();
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'New Chat',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UniversalUIComponents.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),

            // Chat History with StreamBuilder
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  expansionTileTheme: ExpansionTileThemeData(
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    childrenPadding: const EdgeInsets.only(left: 0, top: 4),
                    iconColor: Colors.grey[600],
                    collapsedIconColor: Colors.grey[600],
                    textColor: Colors.grey[700],
                    collapsedTextColor: Colors.grey[700],
                    expansionAnimationStyle: AnimationStyle(
                      duration: Duration.zero,
                    ),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ExpansionTile(
                      minTileHeight: 44,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      leading: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(left: 12),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.history,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                      title: Container(
                        margin: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Chat History',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      initiallyExpanded: isExpanded,
                      onExpansionChanged: (expanded) {
                        setDrawerState?.call(() {
                          UserConstant.isOASPAssistExpanded = expanded;
                        });
                        setLocalState(() {
                          isExpanded = expanded;
                        });
                      }, // <-- **Missing closing parenthesis and semicolon added here**
                      children: [
                        _buildChatHistoryList(
                          context,
                          [], // Empty list since StreamBuilder handles data
                          selectedConversationId,
                          onConversationSelected,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _handleItemTap({
    required BuildContext context,
    required int index,
    required Function(int) onItemTap,
    int? groupIndex,
    StateSetter? setDrawerState,
  }) {
    // Determine which group the clicked item belongs to
    int? itemGroupIndex = _getGroupIndexForItem(index);

    // Close all expansion groups EXCEPT the one containing the clicked item
    if (index >= 0) {
      // Reset persistent drawer states (desktop sidebar)
      if (itemGroupIndex != -1) {
        PersistentDrawerState.setUserManagementExpanded(false);
      }
      if (itemGroupIndex != -2) {
        PersistentDrawerState.setServicesExpanded(false);
      }
      if (itemGroupIndex != -3) {
        PersistentDrawerState.setLogsExpanded(false);
      }

      // Keep the current item's group open
      if (itemGroupIndex == -1) {
        PersistentDrawerState.setUserManagementExpanded(true);
      } else if (itemGroupIndex == -2) {
        PersistentDrawerState.setServicesExpanded(true);
      } else if (itemGroupIndex == -3) {
        PersistentDrawerState.setLogsExpanded(true);
      }

      // Clear mobile drawer expansion states except current group
      if (itemGroupIndex != -1) {
        _expandedState['User Management'] = false;
      }
      if (itemGroupIndex != -2) {
        _expandedState['Services'] = false;
      }
      if (itemGroupIndex != -3) {
        _expandedState['Logs'] = false;
      }

      // Keep current group open in mobile drawer
      if (itemGroupIndex == -1) {
        _expandedState['User Management'] = true;
      } else if (itemGroupIndex == -2) {
        _expandedState['Services'] = true;
      } else if (itemGroupIndex == -3) {
        _expandedState['Logs'] = true;
      }

      // Update mobile drawer UI
      if (setDrawerState != null) {
        setDrawerState(() {});
      }
    }

    // Close the drawer if it's mobile
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    onItemTap(index);
  }

  static Widget _buildChatHistoryList(
    BuildContext context,
    List<Map<String, dynamic>> conversations,
    String? selectedConversationId,
    Function(BuildContext, String?)? onConversationSelected,
  ) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Center(
          child: Text(
            'Please log in',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('conversations')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_outlined, color: Colors.grey[400], size: 30),
                  const SizedBox(height: 8),
                  Text(
                    'No conversations yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        final conversations =
            snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'title': data['title'] ?? 'Untitled',
                'createdAt': data['createdAt'],
              };
            }).toList();

        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              final isSelected =
                  conv['id'] == UserConstant.selectedConversationId;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color:
                      isSelected
                          ? primaryGreen.withOpacity(0.15)
                          : Colors.transparent,
                  border:
                      isSelected
                          ? Border.all(
                            color: primaryGreen.withOpacity(0.4),
                            width: 1.5,
                          )
                          : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(); // Close drawer

                      await UserConstant.setSelectedConversation(conv['id']);

                      if (onConversationSelected != null && context.mounted) {
                        await Future.delayed(Duration(milliseconds: 100));
                        onConversationSelected(context, conv['id']);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? primaryGreen.withOpacity(0.2)
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color:
                                  isSelected
                                      ? Colors.green[700]
                                      : Colors.grey[500],
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              conv['title'] ?? 'Untitled',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                color:
                                    isSelected
                                        ? Colors.green[800]
                                        : Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.grey[500],
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed:
                                () => _deleteConversation(context, conv['id']),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Future<void> _deleteConversation(
    BuildContext context,
    String conversationId, {
    String? conversationTitle,
  }) async {
    if (!context.mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // ✅ CRITICAL: Close drawer FIRST on mobile before showing dialog
    if (isMobile && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      // Wait for drawer animation to complete
      await Future.delayed(const Duration(milliseconds: 350));
      if (!context.mounted) return;
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Delete Conversation Confirmation',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 24 : 32,
                    isMobile ? 32 : 40,
                    isMobile ? 24 : 32,
                    isMobile ? 16 : 20,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFEF4444),
                          size: 32,
                        ),
                      ),
                      SizedBox(height: isMobile ? 16 : 20),
                      const Text(
                        'Delete Conversation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.all(isMobile ? 24 : 32),
                  child: Column(
                    children: [
                      const Text(
                        'Are you sure you want to delete this conversation?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (conversationTitle != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            conversationTitle,
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Action Buttons
                      _buildDeleteActionButtons(
                        context,
                        conversationId,
                        isMobile,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  // 2. REPLACE _buildDeleteActionButtons method (around line 620-680)
  static Widget _buildDeleteActionButtons(
    BuildContext context,
    String conversationId,
    bool isMobile,
  ) {
    // Use ValueNotifier for delete loading state
    final isDeleting = ValueNotifier<bool>(false);

    double buttonHeight = 48;
    double fontSize = isMobile ? 15 : 16;
    double borderRadius = 8;

    return ValueListenableBuilder<bool>(
      valueListenable: isDeleting,
      builder: (context, deleting, _) {
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: buttonHeight,
                child: OutlinedButton(
                  onPressed:
                      deleting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    backgroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey.shade400,
                    side: BorderSide(
                      color:
                          deleting
                              ? const Color(0xFFE5E7EB)
                              : const Color(0xFFD1D5DB),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: buttonHeight,
                child: ElevatedButton(
                  onPressed:
                      deleting
                          ? null
                          : () async {
                            isDeleting.value = true;

                            try {
                              // Check if this is the currently selected conversation
                              final wasSelected =
                                  UserConstant.selectedConversationId ==
                                  conversationId;

                              // Clear selection if deleting current conversation
                              if (wasSelected) {
                                await UserConstant.setSelectedConversation('');
                                UserConstant.shouldShowFAQs = true;

                                // Clear chat provider messages
                                if (context.mounted) {
                                  final chatProvider =
                                      Provider.of<ChatProvider>(
                                        context,
                                        listen: false,
                                      );
                                  chatProvider.clearMessages();
                                }
                              }

                              // Delete from Firestore
                              final firestore = FirebaseFirestore.instance;
                              final batch = firestore.batch();

                              final messagesSnapshot =
                                  await firestore
                                      .collection('conversations')
                                      .doc(conversationId)
                                      .collection('messages')
                                      .get();

                              for (final doc in messagesSnapshot.docs) {
                                batch.delete(doc.reference);
                              }
                              batch.delete(
                                firestore
                                    .collection('conversations')
                                    .doc(conversationId),
                              );

                              await batch.commit();

                              if (context.mounted) {
                                Navigator.of(context).pop(); // Close dialog
                                SnackbarUtil.showSuccess(
                                  context,
                                  'Conversation Deleted',
                                );
                              }
                            } catch (e) {
                              print('❌ Delete error: $e');
                              if (context.mounted) {
                                Navigator.of(context).pop(); // Close dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                isDeleting.value = false;
                              }
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        deleting
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFFCA5A5),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child:
                      deleting
                          ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Deleting...',
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                          : Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static List<Widget> _buildPersistentMenuItems(
    BuildContext context,
    UserRole userRole,
    MenuConfig menuConfig,
    int selectedIndex,
    Function(int) onItemTap,
    bool isExpanded, {
    Function(BuildContext, String?)? onConversationSelected,
    VoidCallback? onNewChat, // ✅ ADD THIS PARAMETER
  }) {
    List<Widget> items = [];

    for (final menuItem in menuConfig.items) {
      // Handle expandable items (Services, Logs)
      if (menuItem.isExpandable && menuItem.subItems != null) {
        items.add(
          buildPersistentDrawerGroup(
            context: context,
            icon: menuItem.icon,
            title: menuItem.title,
            groupIndex: menuItem.index,
            selectedIndex: selectedIndex,
            onTap: onItemTap,
            isExpanded: isExpanded,
            isServicesExpanded: PersistentDrawerState.getExpansionState(
              menuItem.index,
            ),
            children:
                menuItem.subItems!.map((subItem) {
                  return buildPersistentDrawerItem(
                    context: context,
                    icon: subItem.icon,
                    title: subItem.title,
                    index: subItem.index,
                    selectedIndex: selectedIndex,
                    onTap: onItemTap,
                    isExpanded: isExpanded,
                    isSubItem: true,
                  );
                }).toList(),
          ),
        );

        // Add New Chat and History section after Services for user role
        if (userRole == UserRole.user && menuItem.title == 'Services') {
          if (isExpanded) {
            items.add(
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Divider(
                  color: Colors.grey[300],
                  thickness: 1,
                  height: 1,
                ),
              ),
            );
          }

          items.add(
            _buildPersistentNewChatAndHistory(
              context,
              isExpanded,
              onConversationSelected: onConversationSelected,
              onNewChat: onNewChat, // ✅ PASS IT HERE
            ),
          );
        }
      } else {
        // Handle regular (non-expandable) items
        items.add(
          buildPersistentDrawerItem(
            context: context,
            icon: menuItem.icon,
            title: menuItem.title,
            index: menuItem.index,
            selectedIndex: selectedIndex,
            onTap: onItemTap,
            isExpanded: isExpanded,
          ),
        );
      }
    }

    return items;
  }

  // Persistent New Chat and Chat History Section
  static Widget _buildPersistentNewChatAndHistory(
    BuildContext context,
    bool isExpanded, {
    Function(BuildContext, String?)? onConversationSelected,
    VoidCallback? onNewChat,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isChatHistoryExpanded = UserConstant.isOASPAssistExpanded;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // New Chat Button (expanded state)
            if (isExpanded)
              Container(
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                height: 44,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();

                      // ✅ FIX: Call the callback with proper async handling
                      if (onNewChat != null && context.mounted) {
                        onNewChat();
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'New Chat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),

            // Chat History section
            if (isExpanded)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    expansionTileTheme: ExpansionTileThemeData(
                      backgroundColor: Colors.transparent,
                      collapsedBackgroundColor: Colors.transparent,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      childrenPadding: const EdgeInsets.only(left: 0, top: 4),
                      iconColor: Colors.grey[600],
                      collapsedIconColor: Colors.grey[600],
                      textColor: Colors.grey[700],
                      collapsedTextColor: Colors.grey[700],
                      expansionAnimationStyle: AnimationStyle(
                        duration: Duration.zero,
                      ),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ExpansionTile(
                        minTileHeight: 44,
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        leading: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(left: 12),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.history,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ),
                        title: Container(
                          margin: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Chat History',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        initiallyExpanded: isChatHistoryExpanded,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            UserConstant.isOASPAssistExpanded = expanded;
                          });
                        },
                        children: [
                          _buildPersistentChatHistoryList(
                            context,
                            onConversationSelected: onConversationSelected,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Collapsed state icon
            if (!isExpanded)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Tooltip(
                  message: 'New Chat',
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        HapticFeedback.mediumImpact();

                        // ✅ FIX: Use callback for collapsed state
                        if (onNewChat != null && context.mounted) {
                          onNewChat();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 44,
                        child: Center(
                          child: Icon(
                            Icons.add_comment_rounded,
                            color: primaryGreen,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static Widget _buildPersistentChatHistoryList(
    BuildContext context, {
    Function(BuildContext, String?)? onConversationSelected,
  }) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Center(
          child: Text(
            'Please log in',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('conversations')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_outlined, color: Colors.grey[400], size: 30),
                  const SizedBox(height: 8),
                  Text(
                    'No conversations yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        final conversations =
            snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {'id': doc.id, 'title': data['title'] ?? 'Untitled'};
            }).toList();

        return Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              final convId = conv['id'] as String;
              final isSelected = convId == UserConstant.selectedConversationId;

              return _buildConversationTile(
                context: context,
                convId: convId,
                title: conv['title'] as String,
                isSelected: isSelected,
                onConversationSelected: onConversationSelected,
              );
            },
          ),
        );
      },
    );
  }

  // 1. REPLACE _buildConversationTile method (around line 800-850)
  static Widget _buildConversationTile({
    required BuildContext context,
    required String convId,
    required String title,
    required bool isSelected,
    Function(BuildContext, String?)? onConversationSelected,
  }) {
    // Use ValueNotifier to track loading state per conversation
    final isDeleting = ValueNotifier<bool>(false);

    return ValueListenableBuilder<bool>(
      valueListenable: isDeleting,
      builder: (context, deleting, _) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color:
                isSelected
                    ? UniversalUIComponents.primaryGreen.withOpacity(0.15)
                    : Colors.transparent,
            border:
                isSelected
                    ? Border.all(
                      color: UniversalUIComponents.primaryGreen.withOpacity(
                        0.4,
                      ),
                      width: 1.5,
                    )
                    : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap:
                  deleting
                      ? null
                      : () async {
                        HapticFeedback.lightImpact();
                        await UserConstant.setSelectedConversation(convId);
                        if (onConversationSelected != null && context.mounted) {
                          onConversationSelected(context, convId);
                        }
                      },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? UniversalUIComponents.primaryGreen
                                    .withOpacity(0.2)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        color:
                            isSelected ? Colors.green[700] : Colors.grey[500],
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color:
                              isSelected ? Colors.green[800] : Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Show loading indicator or delete button
                    if (deleting)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              UniversalUIComponents.primaryGreen,
                            ),
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.grey[500],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () async {
                          isDeleting.value = true;
                          await _deleteConversation(
                            context,
                            convId,
                            conversationTitle: title,
                          );
                          if (context.mounted) {
                            isDeleting.value = false;
                          }
                        },
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

  static Widget _buildUserProfileDropdown(
    BuildContext context, {
    GlobalKey? profileKey,
  }) {
    Future<Map<String, dynamic>?> getUserData() async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final doc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
          if (doc.exists) {
            return doc.data() as Map<String, dynamic>;
          }
        }
      } catch (e) {
        print('Error getting user data: $e');
      }
      return null;
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: getUserData(),
      builder: (context, snapshot) {
        final userName = snapshot.data?['name'] ?? 'User';

        return Container(
          key: profileKey,

          margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
          child: PopupMenuButton<String>(
            tooltip: '',
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            elevation: 8,
            offset: const Offset(0, 53),
            onSelected: (String value) async {
              if (value == 'profile') {
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,

                  barrierLabel: 'Profile',
                  barrierColor: Colors.black.withOpacity(0.5),

                  pageBuilder: (context, animation, secondaryAnimation) {
                    return const ProfileModal();
                  },
                );
              } else if (value == 'logout') {
                await showLogoutDialog(context);
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white, // white background
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: Colors.black, // black icon
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'View Profile',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black, // black text
                          ),
                        ),
                      ],
                    ),
                  ),

                  const PopupMenuDivider(),

                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white, // white background
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            color: Colors.red.shade600, // red icon
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade600, // red text
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF424242),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Text(
                      userName,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF757575),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.user:
        return 'user';
      case UserRole.staff:
        return 'staff';
      case UserRole.admin:
        return 'admin';
    }
  }

  static void _showNotifications(BuildContext context, UserRole userRole) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: Duration.zero, // ✅ No animation
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(
              top: 56,
              right: 10,
              left: 10,
            ), //  position
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 420, //  width
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: NotificationModal(role: roleToString(userRole)),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildNotificationButton(
    BuildContext context,
    UserRole userRole, {
    GlobalKey? notificationKey,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return IconButton(
        icon: const Icon(
          Icons.notifications_outlined,
          color: Color(0xFF424242),
          size: 24,
        ),
        onPressed: () => _showNotifications(context, userRole),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: currentUserId) // ✅ Filter by userId
              .where('targetRole', isEqualTo: roleToString(userRole))
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final readBy = data['readBy'] as List<dynamic>? ?? [];
            if (!readBy.contains(currentUserId)) unreadCount++;
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            //  Main notification icon
            IconButton(
              key: notificationKey,
              icon: Icon(
                unreadCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color:
                    unreadCount > 0
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF424242),
                size: 26,
              ),
              tooltip: "Notifications",
              onPressed: () => _showNotifications(context, userRole),
            ),

            // 🔴 Small badge
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 14,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
