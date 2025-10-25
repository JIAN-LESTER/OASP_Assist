import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:capstone_project/auth_pages/login_page.dart';
import 'package:capstone_project/notifications.dart';
import 'package:capstone_project/pages/user_pages/chat_page.dart';
import 'package:capstone_project/profile.dart'
    show ProfileModal, ProfilePage;
import 'package:capstone_project/provider/chat_provider.dart';
import 'package:capstone_project/services/cohere_service.dart';
import 'package:capstone_project/models/message.dart';
import 'package:provider/provider.dart';

class AdminConstant {
  static final TextEditingController _controller = TextEditingController();
  static final ScrollController _scrollController = ScrollController();

  static bool _isOASPAassistExpanded = false;
  static String _selectedMenuItem = 'OASP Assist';
  static String? _expandedCategory;

  static List<Map<String, dynamic>> _recentConversations = [];
  static String? _selectedConversationId;
  static StreamSubscription<QuerySnapshot>? _conversationsSubscription;
  static bool _isServicesExpanded = false;
  static bool _isLogsExpanded = false;

  static bool _isInitializing = false;
  static bool _isInitialized = false;

  static var myDefaultBackground = Colors.grey[50];

  // Fixed logout method that handles both Firebase Auth and Google Sign In
  static Future<void> signUserOut() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String name = 'Unknown';

      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          name = userData['name'] ?? user.email ?? 'Unknown';

          // Create log before signing out
          final logRef = FirebaseFirestore.instance.collection('logs').doc();
          final logData = {
            'logId': logRef.id,
            'user': name,
            'action': 'Logged Out',
            'time': Timestamp.now(),
          };

          await logRef.set(logData);
        }
      }

      // Sign out from Google if not on Windows
      if (!Platform.isWindows) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } else {
        print("DEBUG: Skipping Google sign-out on Windows.");
      }

      // Always sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();
      print('DEBUG: User signed out successfully');
    } catch (e) {
      print('Error signing out: $e');

      // Optional: ensure Firebase signout even on error
      try {
        await FirebaseAuth.instance.signOut();
      } catch (inner) {
        print('Error forcing Firebase signout: $inner');
      }
    }
  }

  // Fixed logout dialog method
  static Future<void> showLogoutDialog(BuildContext context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Logout Confirmation',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _LogoutDialogContent(isMobile: isMobile);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  // Fixed AppBar method
  static AppBar myAppBar({
    required BuildContext context,
    String title = '',
    bool showBackButton = true,
    Widget? customLeading,
    VoidCallback? onLeadingPressed,
  }) {
    // Helper method to get user data
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
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF424242),
            size: 22,
          ),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => const NotificationModal(role: 'admin'),
            );
          },
        ),

        // User name with dropdown
        FutureBuilder<Map<String, dynamic>?>(
          future: getUserData(),
          builder: (context, snapshot) {
            final userName = snapshot.data?['name'] ?? 'User';

            return Container(
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
                                color: const Color(0xFF2E7D32).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF2E7D32),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile Avatar
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
                      // User Name
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
                      // Dropdown Arrow
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
        ),

        const SizedBox(width: 13),
      ],
      iconTheme: const IconThemeData(color: Colors.black54),
      automaticallyImplyLeading: showBackButton && customLeading == null,
      leading:
          customLeading ??
          (onLeadingPressed != null
              ? IconButton(
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

  // Fixed Drawer method
  static Drawer myDrawer(
    BuildContext context,
    int selectedIndex,
    Function(int) onItemTap,
  ) {
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
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: null,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.favorite,
                        color: Colors.grey[300],
                        size: 28,
                      ),
                    ),
                  ),

                  // Menu Items
                  Expanded(
                    child: Column(
                      children: [
                        // Dashboard Page
                        ListTile(
                          leading: Icon(
                            Icons.home_outlined,
                            color:
                                selectedIndex == 0
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                            size: 20,
                          ),
                          title: Text(
                            "Dashboard",
                            style: TextStyle(
                              color:
                                  selectedIndex == 0
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                              fontSize: 14,
                              fontWeight:
                                  selectedIndex == 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                          tileColor:
                              selectedIndex == 0 ? Colors.green[50] : null,
                          onTap: () {
                            Navigator.pop(context);
                            onItemTap(0);
                          },
                        ),

                        // Report Page
                        ListTile(
                          leading: Icon(
                            Icons.analytics_outlined,
                            color:
                                selectedIndex == 1
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                            size: 20,
                          ),
                          title: Text(
                            "Reports",
                            style: TextStyle(
                              color:
                                  selectedIndex == 1
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                              fontSize: 14,
                              fontWeight:
                                  selectedIndex == 1
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                          tileColor:
                              selectedIndex == 1 ? Colors.green[50] : null,
                          selected: selectedIndex == 1,
                          onTap: () {
                            Navigator.pop(context);
                            onItemTap(1);
                          },
                        ),

                        // Information Bank Page
                        ListTile(
                          leading: Icon(
                            Icons.book_outlined,
                            color:
                                selectedIndex == 2
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                            size: 20,
                          ),
                          title: Text(
                            "Information Bank",
                            style: TextStyle(
                              color:
                                  selectedIndex == 2
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                              fontSize: 14,
                              fontWeight:
                                  selectedIndex == 2
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                          tileColor:
                              selectedIndex == 2 ? Colors.green[50] : null,
                          selected: selectedIndex == 2,
                          onTap: () {
                            Navigator.pop(context);
                            onItemTap(2);
                          },
                        ),

                        // FAQs Page
                        ListTile(
                          leading: Icon(
                            Icons.help_outline,
                            color:
                                selectedIndex == 3
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                            size: 20,
                          ),
                          title: Text(
                            "FAQs",
                            style: TextStyle(
                              color:
                                  selectedIndex == 3
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                              fontSize: 14,
                              fontWeight:
                                  selectedIndex == 3
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                          tileColor:
                              selectedIndex == 3 ? Colors.green[50] : null,
                          selected: selectedIndex == 3,
                          onTap: () {
                            Navigator.pop(context);
                            onItemTap(3);
                          },
                        ),

                        // Services ExpansionTile
                        ExpansionTile(
                          leading: Icon(
                            Icons.miscellaneous_services_outlined,
                            color:
                                (selectedIndex >= 8 && selectedIndex <= 10)
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                            size: 20,
                          ),
                          title: Text(
                            "Services",
                            style: TextStyle(
                              color:
                                  (selectedIndex >= 8 && selectedIndex <= 10)
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                              fontSize: 14,
                              fontWeight:
                                  (selectedIndex >= 8 && selectedIndex <= 10)
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                          backgroundColor:
                              (selectedIndex >= 8 && selectedIndex <= 10)
                                  ? Colors.green[50]
                                  : null,
                          collapsedBackgroundColor:
                              (selectedIndex >= 8 && selectedIndex <= 10)
                                  ? Colors.green[50]
                                  : null,
                          initiallyExpanded: _isServicesExpanded,
                          onExpansionChanged: (expanded) {
                            setDrawerState(() {
                              _isServicesExpanded = expanded;
                            });
                          },
                          children: [
                            // Admission sub-item
                            Container(
                              margin: const EdgeInsets.only(left: 16),
                              child: ListTile(
                                leading: Icon(
                                  Icons.school_outlined,
                                  color:
                                      selectedIndex == 8
                                          ? Colors.green[700]
                                          : Colors.grey[500],
                                  size: 18,
                                ),
                                title: Text(
                                  "Admission",
                                  style: TextStyle(
                                    color:
                                        selectedIndex == 8
                                            ? Colors.green[800]
                                            : Colors.grey[600],
                                    fontSize: 13,
                                    fontWeight:
                                        selectedIndex == 8
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                  ),
                                ),
                                tileColor:
                                    selectedIndex == 8
                                        ? Colors.green[50]
                                        : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  onItemTap(8);
                                },
                              ),
                            ),
                            // Scholarship sub-item
                            Container(
                              margin: const EdgeInsets.only(left: 16),
                              child: ListTile(
                                leading: Icon(
                                  Icons.card_giftcard_outlined,
                                  color:
                                      selectedIndex == 9
                                          ? Colors.green[700]
                                          : Colors.grey[500],
                                  size: 18,
                                ),
                                title: Text(
                                  "Scholarship",
                                  style: TextStyle(
                                    color:
                                        selectedIndex == 9
                                            ? Colors.green[800]
                                            : Colors.grey[600],
                                    fontSize: 13,
                                    fontWeight:
                                        selectedIndex == 9
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                  ),
                                ),
                                tileColor:
                                    selectedIndex == 9
                                        ? Colors.green[50]
                                        : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  onItemTap(9);
                                },
                              ),
                            ),
                            // Placement sub-item
                            Container(
                              margin: const EdgeInsets.only(left: 16),
                              child: ListTile(
                                leading: Icon(
                                  Icons.work_outline,
                                  color:
                                      selectedIndex == 10
                                          ? Colors.green[700]
                                          : Colors.grey[500],
                                  size: 18,
                                ),
                                title: Text(
                                  "Placement",
                                  style: TextStyle(
                                    color:
                                        selectedIndex == 10
                                            ? Colors.green[800]
                                            : Colors.grey[600],
                                    fontSize: 13,
                                    fontWeight:
                                        selectedIndex == 10
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                  ),
                                ),
                                tileColor:
                                    selectedIndex == 10
                                        ? Colors.green[50]
                                        : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  onItemTap(10);
                                },
                              ),
                            ),
                          ],
                        ),

                        // Announcement Page
                        ListTile(
                          leading: Icon(
                            Icons.announcement_outlined,
                            color:
                                selectedIndex == 4
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                            size: 20,
                          ),
                          title: Text(
                            "Announcement",
                            style: TextStyle(
                              color:
                                  selectedIndex == 4
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                              fontSize: 14,
                              fontWeight:
                                  selectedIndex == 4
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                          tileColor:
                              selectedIndex == 4 ? Colors.green[50] : null,
                          selected: selectedIndex == 4,
                          onTap: () {
                            Navigator.pop(context);
                            onItemTap(4);
                          },
                        ),

                        // User Management Page
                        ListTile(
                          leading: Icon(
                            Icons.person_outline,
                            color:
                                selectedIndex == 5
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                            size: 20,
                          ),
                          title: Text(
                            "User Management",
                            style: TextStyle(
                              color:
                                  selectedIndex == 5
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                              fontSize: 14,
                              fontWeight:
                                  selectedIndex == 5
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                          tileColor:
                              selectedIndex == 5 ? Colors.green[50] : null,
                          selected: selectedIndex == 5,
                          onTap: () {
                            Navigator.pop(context);
                            onItemTap(5);
                          },
                        ),

                        // System Logs Page
                        ExpansionTile(
                          leading: Icon(
                            Icons.list_alt_outlined,
                            color:
                                (selectedIndex >= 6 && selectedIndex <= 7)
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                            size: 20,
                          ),
                          title: Text(
                            "Logs",
                            style: TextStyle(
                              color:
                                  (selectedIndex >= 6 && selectedIndex <= 7)
                                      ? Colors.green[800]
                                      : Colors.grey[700],
                              fontSize: 14,
                              fontWeight:
                                  (selectedIndex >= 6 && selectedIndex <= 7)
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                          backgroundColor:
                              (selectedIndex >= 6 && selectedIndex <= 7)
                                  ? Colors.green[50]
                                  : null,
                          collapsedBackgroundColor:
                              (selectedIndex >= 6 && selectedIndex <= 7)
                                  ? Colors.green[50]
                                  : null,
                          initiallyExpanded: _isLogsExpanded,
                          onExpansionChanged: (expanded) {
                            setDrawerState(() {
                              _isLogsExpanded = expanded;
                            });
                          },
                          children: [
                            // System Activity Logs sub-item
                            Container(
                              margin: const EdgeInsets.only(left: 16),
                              child: ListTile(
                                leading: Icon(
                                  Icons.history_outlined,
                                  color:
                                      selectedIndex == 6
                                          ? Colors.green[700]
                                          : Colors.grey[500],
                                  size: 18,
                                ),
                                title: Text(
                                  "System Activity Logs",
                                  style: TextStyle(
                                    color:
                                        selectedIndex == 6
                                            ? Colors.green[800]
                                            : Colors.grey[600],
                                    fontSize: 13,
                                    fontWeight:
                                        selectedIndex == 6
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                  ),
                                ),
                                tileColor:
                                    selectedIndex == 6
                                        ? Colors.green[50]
                                        : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  onItemTap(6);
                                },
                              ),
                            ),
                            // Message Logs sub-item
                            Container(
                              margin: const EdgeInsets.only(left: 16),
                              child: ListTile(
                                leading: Icon(
                                  Icons.chat_bubble_outline,
                                  color:
                                      selectedIndex == 7
                                          ? Colors.green[700]
                                          : Colors.grey[500],
                                  size: 18,
                                ),
                                title: Text(
                                  "Message Logs",
                                  style: TextStyle(
                                    color:
                                        selectedIndex == 7
                                            ? Colors.green[800]
                                            : Colors.grey[600],
                                    fontSize: 13,
                                    fontWeight:
                                        selectedIndex == 7
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                  ),
                                ),
                                tileColor:
                                    selectedIndex == 7
                                        ? Colors.green[50]
                                        : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  onItemTap(7);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  // Persistent drawer for tablet/desktop with collapsible functionality
  static Widget myPersistentDrawer(
    BuildContext context,
    int selectedIndex,
    Function(int) onItemTap,
    bool isExpanded,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
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
          // Header
          Container(
            height: 80,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, border: null),
            child: Center(
              child: Icon(Icons.favorite, size: 28, color: Colors.grey[300]),
            ),
          ),

          // Menu items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildPersistentDrawerItem(
                    context: context,
                    icon: Icons.home_outlined,
                    title: 'Dashboardajshdvasjhodv',
                    index: 0,
                    selectedIndex: selectedIndex,
                    onTap: onItemTap,
                    isExpanded: isExpanded,
                  ),
                  _buildPersistentDrawerItem(
                    context: context,
                    icon: Icons.analytics_outlined,
                    title: 'Reports',
                    index: 1,
                    selectedIndex: selectedIndex,
                    onTap: onItemTap,
                    isExpanded: isExpanded,
                  ),
                  _buildPersistentDrawerItem(
                    context: context,
                    icon: Icons.book_outlined,
                    title: 'Information Bank',
                    index: 2,
                    selectedIndex: selectedIndex,
                    onTap: onItemTap,
                    isExpanded: isExpanded,
                  ),
                  _buildPersistentDrawerItem(
                    context: context,
                    icon: Icons.help_outline,
                    title: 'FAQs',
                    index: 3,
                    selectedIndex: selectedIndex,
                    onTap: onItemTap,
                    isExpanded: isExpanded,
                  ),
                  _buildPersistentDrawerItem(
                    context: context,
                    icon: Icons.announcement_outlined,
                    title: 'Announcement',
                    index: 4,
                    selectedIndex: selectedIndex,
                    onTap: onItemTap,
                    isExpanded: isExpanded,
                  ),
                  _buildPersistentDrawerItem(
                    context: context,
                    icon: Icons.person_outline,
                    title: 'User Management',
                    index: 5,
                    selectedIndex: selectedIndex,
                    onTap: onItemTap,
                    isExpanded: isExpanded,
                  ),
                  _buildPersistentDrawerGroup(
                    context: context,
                    icon: Icons.miscellaneous_services_outlined,
                    title: "Services",
                    groupIndex: -1,
                    selectedIndex: selectedIndex,
                    onTap: onItemTap,
                    isExpanded: isExpanded,
                    children: [
                      _buildPersistentDrawerItem(
                        context: context,
                        icon: Icons.school_outlined,
                        title: 'Admission Information',
                        index: 8,
                        selectedIndex: selectedIndex,
                        onTap: onItemTap,
                        isExpanded: isExpanded,
                        isSubItem: true,
                      ),
                      _buildPersistentDrawerItem(
                        context: context,
                        icon: Icons.card_giftcard_outlined,
                        title: 'Scholarship List',
                        index: 9,
                        selectedIndex: selectedIndex,
                        onTap: onItemTap,
                        isExpanded: isExpanded,
                        isSubItem: true,
                      ),
                      _buildPersistentDrawerItem(
                        context: context,
                        icon: Icons.work_outline,
                        title: 'Placement Information',
                        index: 10,
                        selectedIndex: selectedIndex,
                        onTap: onItemTap,
                        isExpanded: isExpanded,
                        isSubItem: true,
                      ),
                    ],
                  ),
                  _buildPersistentDrawerGroup(
                    context: context,
                    icon: Icons.list_alt_outlined,
                    title: "Logs",
                    groupIndex: -2,
                    selectedIndex: selectedIndex,
                    onTap: onItemTap,
                    isExpanded: isExpanded,
                    children: [
                      _buildPersistentDrawerItem(
                        context: context,
                        icon: Icons.list_alt_outlined,
                        title: 'System Activity Logs',
                        index: 6,
                        selectedIndex: selectedIndex,
                        onTap: onItemTap,
                        isExpanded: isExpanded,
                        isSubItem: true,
                      ),
                      _buildPersistentDrawerItem(
                        context: context,
                        icon: Icons.message_outlined,
                        title: 'Message Logs',
                        index: 7,
                        selectedIndex: selectedIndex,
                        onTap: onItemTap,
                        isExpanded: isExpanded,
                        isSubItem: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPersistentDrawerGroup({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int groupIndex,
    required int selectedIndex,
    required Function(int) onTap,
    required bool isExpanded,
    required List<Widget> children,
  }) {
    final bool isGroupSelected =
        groupIndex == -1
            ? (selectedIndex >= 8 && selectedIndex <= 10)
            : groupIndex == -2
            ? (selectedIndex >= 6 && selectedIndex <= 7)
            : false;

    return isExpanded
        ? Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              expansionTileTheme: ExpansionTileThemeData(
                backgroundColor:
                    isGroupSelected ? Colors.green[50] : Colors.transparent,
                collapsedBackgroundColor:
                    isGroupSelected ? Colors.green[50] : Colors.transparent,
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 0,
                ),
                childrenPadding: const EdgeInsets.only(left: 4, top: 4),
                iconColor:
                    isGroupSelected ? Colors.green[700] : Colors.grey[600],
                collapsedIconColor:
                    isGroupSelected ? Colors.green[700] : Colors.grey[600],
                textColor:
                    isGroupSelected ? Colors.green[700] : Colors.grey[700],
                collapsedTextColor:
                    isGroupSelected ? Colors.green[700] : Colors.grey[700],
              ),
            ),
            child: Material(
              color: isGroupSelected ? Colors.green[50] : Colors.transparent,
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
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      color:
                          isGroupSelected
                              ? Colors.green[700]
                              : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      color:
                          isGroupSelected
                              ? Colors.green[700]
                              : Colors.grey[700],
                      fontWeight:
                          isGroupSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                  initiallyExpanded:
                      groupIndex == -1 ? _isServicesExpanded : _isLogsExpanded,
                  onExpansionChanged: (expanded) {
                    if (groupIndex == -1) {
                      _isServicesExpanded = expanded;
                    } else if (groupIndex == -2) {
                      _isLogsExpanded = expanded;
                    }
                  },
                  children:
                      children
                          .map(
                            (child) => Container(
                              margin: const EdgeInsets.symmetric(vertical: 1),
                              child: child,
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
          ),
        )
        : _buildPersistentDrawerItem(
          context: context,
          icon: icon,
          title: title,
          index: groupIndex,
          selectedIndex: selectedIndex,
          onTap: onTap,
          isExpanded: isExpanded,
          isServiceGroup: true,
        );
  }

  static Widget _buildPersistentDrawerItem({
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
      height: 44,
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
          onTap: () => onTap(index),
          child: Container(
            width: double.infinity,
            height: 44,
            padding: EdgeInsets.symmetric(
              horizontal: isSubItem ? 16 : 8,
              vertical: 8,
            ),
            child: Stack(
              children: [
                // Green vertical line for selected state
                if (isSelected || isServiceSelected)
                  Positioned(
                    left: isSubItem ? 8 : 4,
                    top: 6,
                    bottom: 6,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                // Icon stays in the same position always
                Positioned(
                  left: isSubItem ? 20 : 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
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
                ),
                // Text appears/disappears but doesn't affect icon position
                if (isExpanded)
                  Positioned(
                    left: isSubItem ? 56 : 48,
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: Center(
                      child: Align(
                        alignment: Alignment.centerLeft,
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                // Tooltip for collapsed state
                if (!isExpanded)
                  Positioned.fill(
                    child: Tooltip(message: title, child: Container()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Separate StatefulWidget for the dialog content
class _LogoutDialogContent extends StatefulWidget {
  final bool isMobile;

  const _LogoutDialogContent({required this.isMobile});

  @override
  State<_LogoutDialogContent> createState() => _LogoutDialogContentState();
}

class _LogoutDialogContentState extends State<_LogoutDialogContent> {
  bool _isLoading = false;

  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Call the existing signUserOut method directly
      await AdminConstant.signUserOut();

      if (mounted) {
        // Close logout dialog
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Logout failed: $error'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(widget.isMobile ? 16 : 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header logout
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFECACA).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFDC2626),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: widget.isMobile ? 20 : 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Are you sure you want to logout from your account?',
                    style: TextStyle(
                      fontSize: widget.isMobile ? 14 : 16,
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You will be logged out',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 13 : 14,
                                  color: const Color(0xFF1F2937),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'You\'ll need to login again to access your account',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 12 : 13,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: widget.isMobile ? 40 : 46,
                          child: OutlinedButton(
                            onPressed:
                                _isLoading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6B7280),
                              side: const BorderSide(
                                color: Color(0xFFD1D5DB),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.isMobile ? 16 : 20,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: widget.isMobile ? 14 : 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: widget.isMobile ? 40 : 46,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(
                                0xFFDC2626,
                              ).withOpacity(0.7),
                              disabledForegroundColor: Colors.white.withOpacity(
                                0.7,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.isMobile ? 16 : 20,
                              ),
                            ),
                            child:
                                _isLoading
                                    ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white.withOpacity(0.8),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Logging out...',
                                          style: TextStyle(
                                            fontSize: widget.isMobile ? 14 : 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.logout_rounded,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Logout',
                                          style: TextStyle(
                                            fontSize: widget.isMobile ? 14 : 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
