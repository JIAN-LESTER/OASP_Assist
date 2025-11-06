import 'dart:async';

import 'package:capstone_project/onboarding/onBoardingGuide.dart';
import 'package:circle_nav_bar/circle_nav_bar.dart' show CircleNavBar;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:capstone_project/pages/user_pages/home.dart';
import 'package:capstone_project/pages/user_pages/user_dashboard.dart';
import 'package:provider/provider.dart';

import 'package:capstone_project/pages/user_pages/admission_info.dart';
import 'package:capstone_project/pages/user_pages/chat_page.dart';
import 'package:capstone_project/pages/user_pages/placement_info.dart';
import 'package:capstone_project/pages/user_pages/scholarship_list.dart';
import 'package:capstone_project/pages/user_pages/user_announcement.dart';
import 'package:capstone_project/provider/chat_provider.dart';

import 'package:capstone_project/responsive/user_constant.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/responsive/widgets/menu.dart';
import 'package:capstone_project/services/cohere_service.dart';

class UserMainPage extends StatefulWidget {
  final int? initialTabIndex;
  final String? conversationId;

  const UserMainPage({super.key, this.initialTabIndex, this.conversationId});

  @override
  State<UserMainPage> createState() => _UserMainPageState();
}

class _UserMainPageState extends State<UserMainPage> {
  int _selectedIndex = 0;
  bool _isChatSidebarExpanded = true;
  bool _isBottomNavExpanded = true;

  // 🔑 Onboarding Keys
  final GlobalKey _sidebarKey = GlobalKey();
  final GlobalKey _notificationKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();

  final CohereService _cohere = CohereService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _conversationId;
  late Future<void> _initFuture;

  bool _isSidebarExpanded = true;

  Timer? _bottomNavTimer;

  bool _showFAQs = false;

  void _toggleFAQs() {
    setState(() {
      _showFAQs = !_showFAQs;
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }

  @override
  void initState() {
    super.initState();

    _selectedIndex = widget.initialTabIndex ?? 0;

    // CRITICAL FIX: Use the passed conversationId if available
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      _conversationId = widget.conversationId;
      _initFuture = _loadExistingConversation(widget.conversationId!);
      _showFAQs = false; // Don't show FAQs for existing conversations
    } else {
      _initFuture = _initializeConversationId();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      UserConstant.initializeChatSession(context, setState);

      if (_selectedIndex == 1 && widget.conversationId == null) {
        _handleChatNavigation();
      }
    });
  }

  bool _handledInitialArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_handledInitialArgs) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['initialTab'] != null) {
        final initialTab = args['initialTab'] as int;
        setState(() {
          _selectedIndex = initialTab;
        });

        if (initialTab == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleChatNavigation();
          });
        }
      }
      _handledInitialArgs = true;
    }
  }

  // NEW METHOD: Load an existing conversation
  Future<void> _loadExistingConversation(String conversationId) async {
    try {
      print('DEBUG: Loading existing conversation: $conversationId');

      // Update the global state
      await UserConstant.setSelectedConversation(conversationId);

      // Load the conversation in the chat provider
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.setConversationId(conversationId);

      // Wait for messages to load
      await Future.delayed(Duration(milliseconds: 300));

      // Check if conversation has messages
      final hasMessages = chatProvider.messages.isNotEmpty;

      setState(() {
        _showFAQs = !hasMessages; // Show FAQs only if no messages
      });

      print(
        'DEBUG: Conversation loaded. Messages: ${chatProvider.messages.length}',
      );
    } catch (e) {
      print('DEBUG: Error loading conversation: $e');
      setState(() {
        _showFAQs = true;
      });
    }
  }

  Future<void> _initializeConversationId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final activeConversations =
            await _firestore
                .collection('conversations')
                .where('userId', isEqualTo: user.uid)
                .where('status', isEqualTo: 'active')
                .limit(1)
                .get();

        if (activeConversations.docs.isNotEmpty) {
          _conversationId = activeConversations.docs.first.id;
        } else {
          _conversationId = null;
        }
      } catch (e) {
        print('DEBUG: Error loading conversation: $e');
      }
    }
  }

  final List<String> _pageTitles = const [
    'Home',
    'Chat with OASP Assist',
    'Announcements',
    'Admission Information',
    'Scholarship List',
    'Placement Information',
  ];

  void _onNavigationItemTap(int index) {
    setState(() {
      _selectedIndex = index;

      _isBottomNavExpanded = true;

      if (index == 1) {
        if (_conversationId == null) {
          _showFAQs = true;
        } else {
          _showFAQs = false;
        }
      } else {
        _showFAQs = false;
      }
    });
    _startBottomNavTimer();

    if (index == 1) {
      _handleChatNavigation();
    }
  }

  void _startBottomNavTimer() {
    _bottomNavTimer?.cancel();
    _bottomNavTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isBottomNavExpanded = false;
        });
      }
    });
  }

  void _onNewChatPressed() async {
    setState(() {
      _selectedIndex = 1;
      _showFAQs = true;
    });

    await UserConstant.startNewChat(context, null, false);

    final newId = UserConstant.selectedConversationId;
    if (newId != null) {
      setState(() {
        _conversationId = newId;
      });
    }
  }

  Future<void> _handleChatNavigation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_conversationId == null) {
        final newConversationId = await UserConstant.createNewConversation();
        setState(() {
          _conversationId = newConversationId;
        });
      }
    } catch (e) {
      print('DEBUG: Error handling chat navigation: $e');
    }
  }

  void _onConversationSelected(
    BuildContext context,
    String? conversationId,
  ) async {
    if (conversationId == null) return;

    print('DEBUG: Conversation selected: $conversationId');

    try {
      // IMMEDIATE UPDATE: Switch to chat page first with new conversation ID
      if (mounted) {
        setState(() {
          _selectedIndex = 1;
          _conversationId = conversationId;
        });
      }

      // Update the global state
      await UserConstant.setSelectedConversation(conversationId);

      // Load the conversation in the chat provider
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.setConversationId(conversationId);

      // Wait for messages to load completely
      await Future.delayed(Duration(milliseconds: 500));

      // Check if conversation has messages
      final hasMessages = chatProvider.messages.isNotEmpty;

      print('DEBUG: Messages loaded: ${chatProvider.messages.length}');
      print('DEBUG: Has messages: $hasMessages');
      print('DEBUG: Should show FAQs: ${!hasMessages}');

      // Update FAQ state after loading is complete
      if (mounted) {
        setState(() {
          _showFAQs = !hasMessages;
        });

        print(
          'DEBUG: FAQ state updated. Show FAQs: $_showFAQs (Messages count: ${chatProvider.messages.length})',
        );
      }
    } catch (e) {
      print('DEBUG: Error selecting conversation: $e');
      if (mounted) {
        setState(() {
          _showFAQs = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final List<Widget> _pages = [
          const HomeDashboard(),
          ChatPage(
            conversationId: _conversationId ?? '',
            showFAQs: _showFAQs,
            onFAQToggle: _toggleFAQs,
          ),
          const UserAnnouncementPage(),
          const AdmissionInfo(),
          const ScholarshipList(),
          const PlacementInfo(),
        ];

        // WRAPPED WITH ONBOARDING GUIDE
        return OnboardingGuide(
          sidebarKey: _sidebarKey,
          notificationKey: _notificationKey,
          profileKey: _profileKey,
          bottomNavKey: _bottomNavKey,
          child: ResponsiveLayout(
            mobileBody: _buildMobileLayout(_pages),
            tabletBody: _buildTabletDesktopLayout(_pages),
            desktopBody: _buildTabletDesktopLayout(_pages),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(List<Widget> pages) {
    final isChatPage = _selectedIndex == 1;

    return Scaffold(
      backgroundColor: UniversalUIComponents.backgroundGrey,
      appBar: UniversalUIComponents.buildAppBar(
        context: context,
        userRole: UserRole.user,
        title: _pageTitles[_selectedIndex],
        isChatPage: isChatPage,
        hasActiveConversation: _conversationId != null,
        showBackButton: false,
        onLeadingPressed:
            isChatPage ? () => Scaffold.of(context).openDrawer() : null,
        customLeading:
            isChatPage
                ? Builder(
                  builder:
                      (context) => IconButton(
                        key: _sidebarKey, // 🔑 KEY FOR SIDEBAR
                        icon: const Icon(Icons.menu, color: Colors.black54),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                )
                : null,
        // 🔑 PASS KEYS TO APP BAR
        notificationKey: _notificationKey,
        profileKey: _profileKey,
      ),
      drawer: isChatPage ? _buildMobileChatDrawer() : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        key: _bottomNavKey, // 🔑 KEY FOR BOTTOM NAV
        child: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildMobileChatDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chat',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _onNewChatPressed();
                      },
                      icon: const Icon(Icons.add_comment_rounded, size: 20),
                      label: const Text(
                        'New Chat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UniversalUIComponents.primaryGreen,
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
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Conversations',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
            Expanded(child: _buildDrawerConversationsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerConversationsList() {
    if (UserConstant.recentConversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_outlined, color: Colors.grey[400], size: 40),
            const SizedBox(height: 12),
            Text(
              'No conversations yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: UserConstant.recentConversations.length,
      itemBuilder: (context, index) {
        final conv = UserConstant.recentConversations[index];
        final isSelected = conv['id'] == _conversationId;
        final isActive = conv['status'] == 'active';

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                isSelected
                    ? UniversalUIComponents.primaryGreen.withOpacity(0.1)
                    : Colors.transparent,
            border:
                isSelected
                    ? Border.all(
                      color: UniversalUIComponents.primaryGreen.withOpacity(
                        0.3,
                      ),
                      width: 1,
                    )
                    : null,
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? UniversalUIComponents.primaryGreen.withOpacity(0.2)
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
                color: isSelected ? Colors.green[700] : Colors.grey[500],
                size: 18,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    conv['title'] ?? 'Untitled',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.green[800] : Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _onConversationSelected(context, conv['id']);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabletDesktopLayout(List<Widget> pages) {
    return Scaffold(
      backgroundColor: UniversalUIComponents.backgroundGrey,
      appBar: UniversalUIComponents.buildAppBar(
        context: context,
        userRole: UserRole.user,
        title: _pageTitles[_selectedIndex],
        isChatPage: _selectedIndex == 1,
        showFAQToggle: _selectedIndex == 1,
        showFAQs: _showFAQs,
        showBackButton: false,
        onFAQToggle: _toggleFAQs,
        onLeadingPressed: _toggleSidebar,
        hasActiveConversation: _conversationId != null,
        // 🔑 PASS KEYS TO APP BAR
        sidebarKey: _sidebarKey,
        notificationKey: _notificationKey,
        profileKey: _profileKey,
      ),
      body: Row(
        children: [
          UniversalUIComponents.buildPersistentDrawer(
            context: context,
            userRole: UserRole.user,
            selectedIndex: _selectedIndex,
            onItemTap: _onNavigationItemTap,
            isExpanded: _isSidebarExpanded,
            onConversationSelected: _onConversationSelected,
          ),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
      drawer: UniversalUIComponents.buildDrawer(
        context: context,
        userRole: UserRole.user,
        selectedIndex: _selectedIndex,
        onItemTap: _onNavigationItemTap,
        setState: setState,
        recentConversations: UserConstant.recentConversations,
        selectedConversationId: UserConstant.selectedConversationId,
        onConversationSelected: _onConversationSelected,
        onNewChat: _onNewChatPressed,
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    int getActualIndex() {
      if (_selectedIndex == 0) return 0;
      if (_selectedIndex == 1) return 1;
      if (_selectedIndex == 2) return 2;
      return 3;
    }

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -5) {
          setState(() {
            _isBottomNavExpanded = true;
          });
          _startBottomNavCollapseTimer();
        } else if (details.primaryDelta! > 5) {
          setState(() {
            _isBottomNavExpanded = false;
          });
          _bottomNavTimer?.cancel();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isBottomNavExpanded ? 80 : 30,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_isBottomNavExpanded)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleNavBar(
                    activeIcons: const [
                      Icon(Icons.home, color: Colors.green),
                      Icon(Icons.chat, color: Colors.green),
                      Icon(Icons.announcement, color: Colors.green),
                      Icon(Icons.apps, color: Colors.green),
                    ],
                    inactiveIcons: const [
                      Text(
                        "Home",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "Chat",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "Announcements",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "Services",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    color: Colors.white,
                    circleColor: UniversalUIComponents.primaryGreen,
                    height: 60,
                    circleWidth: 60,
                    activeIndex: getActualIndex(),
                    onTap: (index) {
                      HapticFeedback.mediumImpact();
                      _startBottomNavCollapseTimer();
                      if (index == 3) {
                        _showServicesMenu();
                      } else {
                        _onNavigationItemTap(index);
                      }
                    },
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 20,
                    ),
                    cornerRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                    ),
                    shadowColor: Colors.grey.shade300,
                    circleShadowColor: Colors.grey.shade400,
                    elevation: 8,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.grey.shade50],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 25,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isBottomNavExpanded = false;
                          });
                          _bottomNavTimer?.cancel();
                          HapticFeedback.lightImpact();
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (!_isBottomNavExpanded)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isBottomNavExpanded = true;
                  });
                  _startBottomNavCollapseTimer();
                },
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 2,
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Colors.grey[500],
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _startBottomNavCollapseTimer() {
    _bottomNavTimer?.cancel();
    _bottomNavTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isBottomNavExpanded = false;
        });
      }
    });
  }

  void _showServicesMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Services',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 20),
                _buildServiceTile(
                  icon: Icons.school,
                  title: 'Admission Information',
                  subtitle: 'View admission requirements',
                  onTap: () {
                    Navigator.pop(context);
                    _onNavigationItemTap(3);
                  },
                ),
                const SizedBox(height: 12),
                _buildServiceTile(
                  icon: Icons.card_giftcard,
                  title: 'Scholarship List',
                  subtitle: 'Browse available scholarships',
                  onTap: () {
                    Navigator.pop(context);
                    _onNavigationItemTap(4);
                  },
                ),
                const SizedBox(height: 12),
                _buildServiceTile(
                  icon: Icons.work,
                  title: 'Placement Information',
                  subtitle: 'Career placement details',
                  onTap: () {
                    Navigator.pop(context);
                    _onNavigationItemTap(5);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Widget _buildServiceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UniversalUIComponents.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: UniversalUIComponents.primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bottomNavTimer?.cancel();
    UserConstant.dispose();
    super.dispose();
  }
}
