import 'dart:async';
import 'package:capstone_project/notifications.dart';
import 'package:capstone_project/profile.dart';
import 'package:capstone_project/responsive/user_constant.dart';
import 'package:capstone_project/responsive/widgets/logout.dart';
import 'package:capstone_project/responsive/widgets/persistent_drawer_group.dart';
import 'package:capstone_project/responsive/widgets/persistent_drawer_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

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
                  if (menuConfig.showLogoutButton) _buildLogoutSection(context),
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
    Function(BuildContext, String?)?
    onConversationSelected, // Optional parameter
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
                  onConversationSelected:
                      onConversationSelected, // Pass it down (can be null)
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
                    MenuItem(
              icon: Icons.announcement_outlined,
              title: 'Human Escalation',
              index: 5,
            ),
            

            MenuItem(
              icon: Icons.person_outline,
              title: 'User Management',
              index: -1,
              isExpandable: true,
              subItems: [
                MenuItem(icon: Icons.person, title: "Users", index: 6),
                MenuItem(icon: Icons.book, title: "Affiliations", index: 12),
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
            Icon(Icons.favorite, color: Colors.grey[300], size: 28),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop();
                  if (selectedIndex != 1) {
                    onItemTap?.call(1);
                  } else {
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
        child: Icon(Icons.favorite, color: Colors.grey[300], size: 28),
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
        child: Icon(Icons.favorite, size: 28, color: Colors.grey[300]),
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
              recentConversations ?? [],
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
          ),
        );
      }
    }

    return Column(children: menuItems);
  }

  static Widget _buildRegularMenuItem(
    BuildContext context,
    MenuItem item,
    int selectedIndex,
    Function(int) onItemTap,
    UserRole userRole,
  ) {
    final isSelected = selectedIndex == item.index;

    return ListTile(
      leading: Icon(
        item.icon,
        color: isSelected ? Colors.green[700] : Colors.grey[600],
        size: 20,
      ),
      title: Text(
        item.title,
        style: TextStyle(
          color: isSelected ? Colors.green[800] : Colors.grey[700],
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      tileColor: isSelected ? Colors.green[50] : null,
      onTap: () {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        onItemTap(item.index);
      },
    );
  }

  // 🔹 Add this at the top of your drawer widget (or as static map if inside a class)
  static final Map<String, bool> _expandedState = {
    'Services': false,
    'Logs': false,
    'User Management': false,
  };

  static Widget _buildExpandableMenuItem(
    BuildContext context,
    MenuItem item,
    int selectedIndex,
    Function(int) onItemTap,
    StateSetter setDrawerState,
    UserRole userRole,
  ) {
    final bool isAnySubItemSelected =
        item.subItems?.any((subItem) => subItem.index == selectedIndex) ??
        false;

    // ✅ Get expansion state from the shared map
    bool isExpanded = _expandedState[item.title] ?? false;

    return Theme(
      data: ThemeData(
        expansionTileTheme: ExpansionTileThemeData(
          expansionAnimationStyle: AnimationStyle(duration: Duration.zero),
        ),
      ),
      child: ExpansionTile(
        leading: Icon(
          item.icon,
          color: isAnySubItemSelected ? Colors.green[700] : Colors.grey[600],
          size: 20,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: isAnySubItemSelected ? Colors.green[800] : Colors.grey[700],
            fontSize: 14,
            fontWeight:
                isAnySubItemSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        backgroundColor: isAnySubItemSelected ? Colors.green[50] : null,
        collapsedBackgroundColor:
            isAnySubItemSelected ? Colors.green[50] : null,
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          setDrawerState(() {
            _expandedState[item.title] = expanded; // ✅ Persist state
          });
        },
        children:
            item.subItems
                ?.map(
                  (subItem) => Container(
                    margin: const EdgeInsets.only(left: 16),
                    child: ListTile(
                      leading: Icon(
                        subItem.icon,
                        color:
                            selectedIndex == subItem.index
                                ? Colors.green[700]
                                : Colors.grey[500],
                        size: 18,
                      ),
                      title: Text(
                        subItem.title,
                        style: TextStyle(
                          color:
                              selectedIndex == subItem.index
                                  ? Colors.green[800]
                                  : Colors.grey[600],
                          fontSize: 13,
                          fontWeight:
                              selectedIndex == subItem.index
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                        ),
                      ),
                      tileColor:
                          selectedIndex == subItem.index
                              ? Colors.green[50]
                              : null,
                      onTap: () {
                        if (context.mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        onItemTap(subItem.index);
                      },
                    ),
                  ),
                )
                .toList() ??
            [],
      ),
    );
  }

  static Widget _buildNewChatAndHistorySection(
    BuildContext context,
    List<Map<String, dynamic>> recentConversations,
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
                    Navigator.of(context).pop();
                    await UserConstant.startNewChat(context);
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

            // Chat History Dropdown
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
                      },
                      children: [
                        _buildChatHistoryList(
                          context,
                          recentConversations,
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

  static Widget _buildChatHistoryList(
    BuildContext context,
    List<Map<String, dynamic>> conversations,
    String? selectedConversationId,
    Function(BuildContext, String?)? onConversationSelected,
  ) {
    if (conversations.isEmpty) {
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

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conv = conversations[index];
          final isSelected = conv['id'] == selectedConversationId;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color:
                  isSelected
                      ? primaryGreen.withOpacity(0.1)
                      : Colors.transparent,
              border:
                  isSelected
                      ? Border.all(
                        color: primaryGreen.withOpacity(0.3),
                        width: 1,
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

                  // Set the selected conversation
                  await UserConstant.setSelectedConversation(conv['id']);

                  // SAFELY call the parent's callback - only if provided
                  if (onConversationSelected != null && context.mounted) {
                    await Future.delayed(Duration(milliseconds: 100));
                    onConversationSelected(context, conv['id']);
                  } else {
                    // Fallback: If no callback provided, just log
                    print('DEBUG: No conversation selection callback provided');
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
                              isSelected ? Colors.green[700] : Colors.grey[500],
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
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color:
                                isSelected
                                    ? Colors.green[800]
                                    : Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteConversation(context, conv['id']);
                          }
                        },
                        itemBuilder:
                            (context) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
  }

  static Future<void> _deleteConversation(
    BuildContext context,
    String conversationId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: const Text(
              'Are you sure you want to delete this conversation and all its messages?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final firestore = FirebaseFirestore.instance;
        final messagesRef = firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages');

        // 🧹 Delete all messages first
        final messagesSnapshot = await messagesRef.get();
        for (final doc in messagesSnapshot.docs) {
          await doc.reference.delete();
        }

        // 🗑️ Then delete the conversation document itself
        await firestore
            .collection('conversations')
            .doc(conversationId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Conversation and messages deleted'),
              backgroundColor: primaryGreen,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  static Widget _buildLogoutSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            await showLogoutDialog(context);
          },
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text(
            'Logout',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
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
            groupIndex: menuItem.index, // -1 for Services, -2 for Logs
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
                    isSubItem: true, // Add this to indicate it's a sub-item
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
              onConversationSelected:
                  onConversationSelected, // Can be null, that's OK
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

  // // Persistent chat menu item
  // static Widget _buildPersistentChatMenuItem({
  //   required BuildContext context,
  //   required MenuItem menuItem,
  //   required int selectedIndex,
  //   required Function(int) onItemTap,
  //   required bool isExpanded,
  // }) {
  //   final isSelected = selectedIndex == menuItem.index;

  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  //     constraints: const BoxConstraints(minHeight: 44),
  //     child: Material(
  //       color: isSelected ? Colors.green[50] : Colors.transparent,
  //       borderRadius: BorderRadius.circular(8),
  //       child: InkWell(
  //         borderRadius: BorderRadius.circular(8),
  //         onTap: () => onItemTap(menuItem.index),
  //         child: Container(
  //           width: double.infinity,
  //           constraints: const BoxConstraints(minHeight: 44),
  //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
  //           child: Row(
  //             crossAxisAlignment: CrossAxisAlignment.center,
  //             children: [
  //               // Green vertical line
  //               Container(
  //                 width: 3,
  //                 height: 20,
  //                 margin: const EdgeInsets.only(left: 4, right: 8),
  //                 decoration: BoxDecoration(
  //                   color: isSelected ? Colors.green[700] : Colors.transparent,
  //                   borderRadius: BorderRadius.circular(1.5),
  //                 ),
  //               ),
  //               // Icon
  //               Container(
  //                 width: 20,
  //                 height: 20,
  //                 margin: const EdgeInsets.only(right: 8),
  //                 child: Icon(
  //                   menuItem.icon,
  //                   color: isSelected ? Colors.green[700] : Colors.grey[600],
  //                   size: 20,
  //                 ),
  //               ),
  //               // Text
  //               if (isExpanded)
  //                 Expanded(
  //                   child: Container(
  //                     padding: const EdgeInsets.only(left: 8),
  //                     child: Text(
  //                       menuItem.title,
  //                       style: TextStyle(
  //                         color:
  //                             isSelected ? Colors.green[700] : Colors.grey[700],
  //                         fontWeight:
  //                             isSelected ? FontWeight.w600 : FontWeight.w400,
  //                         fontSize: 14,
  //                       ),
  //                       softWrap: true,
  //                       overflow: TextOverflow.visible,
  //                       maxLines: null,
  //                     ),
  //                   ),
  //                 ),
  //               if (!isExpanded)
  //                 Expanded(
  //                   child: Tooltip(
  //                     message: menuItem.title,
  //                     child: Container(height: 44),
  //                   ),
  //                 ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Persistent New Chat and Chat History Section
  static Widget _buildPersistentNewChatAndHistory(
    BuildContext context,
    bool isExpanded, {
    Function(BuildContext, String?)? onConversationSelected,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isChatHistoryExpanded = UserConstant.isOASPAssistExpanded;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // New Chat Button (existing code stays the same)
            if (isExpanded)
              Container(
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                height: 44,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await UserConstant.startNewChat(context);
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

            // Chat History with callback
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
                        await UserConstant.startNewChat(context);
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
    if (UserConstant.recentConversations.isEmpty) {
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

    return StatefulBuilder(
      builder: (context, setHistoryState) {
        return Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: UserConstant.recentConversations.length,
            itemBuilder: (context, index) {
              final conv = UserConstant.recentConversations[index];
              final isSelected =
                  conv['id'] == UserConstant.selectedConversationId;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color:
                      isSelected
                          ? primaryGreen.withOpacity(0.1)
                          : Colors.transparent,
                  border:
                      isSelected
                          ? Border.all(
                            color: primaryGreen.withOpacity(0.3),
                            width: 1,
                          )
                          : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      HapticFeedback.lightImpact();

                      // Set the selected conversation immediately
                      await UserConstant.setSelectedConversation(conv['id']);

                      // Update the UI to show highlight
                      setHistoryState(() {});

                      // SAFELY use the callback - only if it's not null
                      if (onConversationSelected != null && context.mounted) {
                        await Future.delayed(Duration(milliseconds: 100));
                        onConversationSelected(context, conv['id']);
                      } else {
                        // Fallback behavior if no callback is provided
                        print('DEBUG: No conversation callback provided');
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
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteConversation(context, conv['id']);
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                            color: primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: primaryGreen,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'View Profile',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1B5E20),
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
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            color: Colors.red.shade600,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade600,
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
                  Container(
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => NotificationModal(role: roleToString(userRole)),
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
