import 'dart:async';

import 'package:capstone_project/models/message.dart';
import 'package:capstone_project/onboarding/onBoardingGuide.dart';
import 'package:capstone_project/reusable_widgets/loading_overlay.dart';

import 'package:circle_nav_bar/circle_nav_bar.dart' show CircleNavBar;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:capstone_project/pages/user_pages/home.dart';

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
  final bool? loadExisting;
  final bool? fromNotification;

  const UserMainPage({
    Key? key,
    this.initialTabIndex,
    this.conversationId,
    this.loadExisting,
    this.fromNotification,
  }) : super(key: key);

  @override
  State<UserMainPage> createState() => _UserMainPageState();
}

class _UserMainPageState extends State<UserMainPage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _currentIndex = 0;
  late TabController _tabController;
  bool _isChatSidebarExpanded = true;
  bool _isBottomNavExpanded = true;
  String? _pendingConversationId;
  bool? loadExistingConversation;
  bool _isLoading = false;
  bool _isNavigating = false;

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

    // Initialize controllers
    final validatedInitialTab = widget.initialTabIndex ?? 0;
    _currentIndex = validatedInitialTab.clamp(0, 5); // Pages are 0-5
    _selectedIndex = _currentIndex;
    _tabController = TabController(
      length: 6, // ✅ Make sure this matches your pages list length
      vsync: this,
      initialIndex: _currentIndex,
    );

    // Store the conversation ID if provided
    _pendingConversationId = widget.conversationId;
    loadExistingConversation = widget.loadExisting ?? false;

    print('🏠 UserMainPage initialized:');
    print('   - Initial tab: $_currentIndex');
    print('   - Conversation ID: $_pendingConversationId');
    print('   - Load existing: $loadExistingConversation');
    print('   - From notification: ${widget.fromNotification}');

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });

    // ✅ FIX: Only load conversation if passed, don't create new one
    if (widget.conversationId != null &&
        widget.conversationId!.isNotEmpty &&
        widget.conversationId != 'null') {
      print(
        '✅ Initializing with passed conversation: ${widget.conversationId}',
      );
      _conversationId = widget.conversationId;
      _initFuture = _loadExistingConversation(widget.conversationId!);
      _showFAQs = false; // Never show FAQs when loading from notification
    } else {
      print('ℹ️ No conversation passed, looking for active conversation');
      _initFuture = _initializeConversationId();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      UserConstant.initializeChatSession(context, setState);

      // ✅ FIX: Don't create new conversation on navigation
      // Only handle chat navigation if we're on chat tab and have a conversation
      if (_selectedIndex == 1 && _conversationId != null) {
        print('📱 Already on chat tab with conversation: $_conversationId');
      }
    });
  }

  String _loadingText = "Loading...";

  bool _handledInitialArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_handledInitialArgs) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        print('📍 Route arguments in didChangeDependencies: $args');

        final initialTab = args['initialTab'] as int?;
        final conversationId = args['conversationId'] as String?;
        final loadExisting = args['loadExisting'] as bool?;

        if (conversationId != null &&
            conversationId.isNotEmpty &&
            conversationId != 'null') {
          print('✅ Received conversationId from route: $conversationId');

          setState(() {
            _pendingConversationId = conversationId;
            loadExistingConversation = loadExisting ?? true;
            _conversationId = conversationId;
            _showFAQs = false;

            // ✅ Validate tab index
            if (initialTab != null) {
              _selectedIndex = initialTab.clamp(0, 5);
            }
          });

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            print('🔄 Loading conversation from notification: $conversationId');
            await _loadExistingConversation(conversationId);

            // ✅ Navigate to chat tab safely
            if (_selectedIndex != 1 && mounted) {
              setState(() {
                _selectedIndex = 1;
              });

              try {
                _tabController.animateTo(1);
              } catch (e) {
                print('❌ Error animating to chat tab: $e');
              }
            }
          });
        } else if (initialTab != null) {
          // ✅ Validate and clamp tab index
          final validatedTab = initialTab.clamp(0, 5);

          setState(() {
            _selectedIndex = validatedTab;
          });

          if (validatedTab == 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleChatNavigation();
            });
          }
        }
      }
      _handledInitialArgs = true;
    }
  }

  bool _isValidTabIndex(int index) {
    return index >= 0 && index < _tabController.length;
  }

  void _safeNavigateToTab(int index) {
    if (!_isValidTabIndex(index)) {
      print('⚠️ Invalid tab index: $index, clamping to valid range');
      index = index.clamp(0, _tabController.length - 1);
    }

    _onNavigationItemTap(index);
  }

  Future<void> _loadExistingConversation(String conversationId) async {
    try {
      print('📥 Loading existing conversation: $conversationId');

      // Verify conversation exists
      final convDoc =
          await _firestore
              .collection('conversations')
              .doc(conversationId)
              .get();

      if (!convDoc.exists) {
        print('❌ Conversation not found: $conversationId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversation not found'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _showFAQs = true;
            _conversationId = null;
            _pendingConversationId = null;
          });
        }
        return;
      }

      print('✅ Conversation exists, loading...');

      // Update the global state
      await UserConstant.setSelectedConversation(conversationId);

      // Load the conversation in the chat provider
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.setConversationId(conversationId);

      // Wait for messages to load
      await Future.delayed(const Duration(milliseconds: 800));

      print('✅ Messages loaded: ${chatProvider.messages.length}');

      // ✅ CRITICAL: Check for escalation responses and add them to chat
      await _checkAndAddEscalationResponses(conversationId, chatProvider);

      // ✅ Always hide FAQs when loading from notification
      if (mounted) {
        setState(() {
          _showFAQs = false;
          _conversationId = conversationId;
          _pendingConversationId = conversationId;
        });
      }

      print(
        '✅ Conversation fully loaded with ${chatProvider.messages.length} messages',
      );
    } catch (e) {
      print('❌ Error loading conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _showFAQs = true;
          _conversationId = null;
          _pendingConversationId = null;
        });
      }
    }
  }

  Future<void> _checkAndAddEscalationResponses(
    String conversationId,
    ChatProvider chatProvider,
  ) async {
    try {
      print('🔍 Initial escalation check for: $conversationId');

      final escalationsSnapshot =
          await _firestore
              .collection('escalations')
              .where('conversationId', isEqualTo: conversationId)
              .where('status', isEqualTo: 'resolved')
              .get();

      if (escalationsSnapshot.docs.isEmpty) {
        print('ℹ️ No resolved escalations found');
        return;
      }

      print('✅ Found ${escalationsSnapshot.docs.length} resolved escalations');

      for (var escalationDoc in escalationsSnapshot.docs) {
        final escalation = escalationDoc.data();
        final staffResponse = escalation['staffResponse'] as String?;
        final respondedBy = escalation['respondedBy'] as String? ?? 'Staff';
        final escalationId = escalationDoc.id;

        if (staffResponse == null || staffResponse.isEmpty) continue;

        final staffMessageContent =
            '**Staff Response from $respondedBy:**\n\n$staffResponse';

        // Check Firestore first
        final existingStaffMessages =
            await _firestore
                .collection('conversations')
                .doc(conversationId)
                .collection('messages')
                .where('sender', isEqualTo: 'staff')
                .where('content', isEqualTo: staffMessageContent)
                .limit(1)
                .get();

        if (existingStaffMessages.docs.isNotEmpty) {
          print(
            'ℹ️ Staff response already exists for escalation $escalationId',
          );
          continue;
        }

        // Check in-memory
        final existingInMemory = chatProvider.messages.any(
          (msg) => msg.content.contains(staffResponse) && msg.sender == 'staff',
        );

        if (existingInMemory) {
          print(
            'ℹ️ Staff response already in memory for escalation $escalationId',
          );
          continue;
        }

        print('📝 Adding staff response for escalation $escalationId');

        final staffMessageRef =
            _firestore
                .collection('conversations')
                .doc(conversationId)
                .collection('messages')
                .doc();

        final staffMessage = Message(
          id: staffMessageRef.id,
          conversationId: conversationId,
          content: staffMessageContent,
          sender: 'staff',
          status: 'sent',
          type: 'text',
          sentAt: DateTime.now(),
        );

        await chatProvider.saveMessageToFirebase(conversationId, staffMessage);
      }

      await chatProvider.loadExistingMessages();
    } catch (e) {
      print('❌ Error checking escalation responses: $e');
    }
  }

  Future<void> _initializeConversationId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ✅ Check if we already have a conversationId from widget/navigation
      if (_conversationId != null && _conversationId!.isNotEmpty) {
        print(
          '✅ Already have conversationId: $_conversationId, skipping initialization',
        );
        return;
      }

      // ✅ Check if we have a conversationId passed from navigation
      if (widget.conversationId != null &&
          widget.conversationId!.isNotEmpty &&
          widget.conversationId != 'null') {
        print('✅ Using passed conversationId: ${widget.conversationId}');

        final convDoc =
            await _firestore
                .collection('conversations')
                .doc(widget.conversationId!)
                .get();

        if (convDoc.exists) {
          print('✅ Conversation exists, loading it');
          if (mounted) {
            setState(() {
              _conversationId = widget.conversationId;
              _pendingConversationId = widget.conversationId;
            });
          }

          await _loadExistingConversation(widget.conversationId!);
          return;
        } else {
          print(
            '⚠️ Passed conversationId not found, falling back to active conversation',
          );
        }
      }

      print('🔍 Looking for active conversations...');
      final activeConversations =
          await _firestore
              .collection('conversations')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'active')
              .orderBy('lastActivity', descending: true)
              .limit(1)
              .get();

      if (activeConversations.docs.isNotEmpty) {
        print(
          '✅ Found active conversation: ${activeConversations.docs.first.id}',
        );
        if (mounted) {
          setState(() {
            _conversationId = activeConversations.docs.first.id;
            _pendingConversationId = activeConversations.docs.first.id;
            _showFAQs = false;
          });
        }
      } else {
        print('ℹ️ No active conversations found');
        if (mounted) {
          setState(() {
            _conversationId = null;
            _pendingConversationId = null;
            _showFAQs = true;
          });
        }
      }
    } catch (e) {
      print('❌ Error in _initializeConversationId: $e');
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

  String _navigationLoadingTextForIndex(int index) {
    if (index == 0) return 'Loading home...';
    if (index == 1) return 'Loading chat...';
    if (index == 2) return 'Loading announcements...';
    if (index == 3) return 'Loading admission info...';
    if (index == 4) return 'Loading scholarships...';
    if (index == 5) return 'Loading placement info...';

    return 'Loading...';
  }

  void _onNavigationItemTap(int index) async {
    print('📱 Navigation tap to index: $index');

    if (!mounted || _isNavigating) return;

    if (index < 0 || index >= _tabController.length) {
      print('⚠️ Invalid tab index: $index');
      return;
    }

    // 🎯 Update wording BEFORE overlay shows
    _loadingText = _navigationLoadingTextForIndex(index);

    // 🔥 Show loading overlay
    setState(() {
      _isNavigating = true;
    });

    try {
      await Future.delayed(Duration(milliseconds: 80));

      if (index == 1) {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);

        if (_conversationId == null || _conversationId!.isEmpty) {
          print('📝 No conversation → show FAQs');
          setState(() {
            _showFAQs = true;
            _selectedIndex = 1;
          });
        } else {
          print('🔄 Loading existing conversation $_conversationId');
          await chatProvider.setConversationId(_conversationId!);
          await Future.delayed(Duration(milliseconds: 400));

          final hasMessages = chatProvider.messages.isNotEmpty;

          setState(() {
            _showFAQs = !hasMessages;
            _selectedIndex = 1;
          });
        }

        _tabController.animateTo(1);
        await Future.delayed(Duration(milliseconds: 250));
      } else {
        print('➡️ Navigating to tab: $index');

        setState(() {
          _showFAQs = false;
          _selectedIndex = index;
        });

        _tabController.animateTo(index);
        await Future.delayed(Duration(milliseconds: 250));
      }
    } catch (e) {
      print('❌ Navigation error: $e');
      if (mounted) _showErrorSnackBar("Navigation failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  // void _startBottomNavTimer() {
  //   _bottomNavTimer?.cancel();
  //   _bottomNavTimer = Timer(const Duration(seconds: 5), () {
  //     if (mounted) {
  //       setState(() {
  //         _isBottomNavExpanded = false;
  //       });
  //     }
  //   });
  // }

  void _onNewChatPressed() async {
    HapticFeedback.mediumImpact();

    print('🆕 _onNewChatPressed called');

    if (_isLoading) {
      print('⚠️ Already creating new chat, ignoring duplicate call');
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showErrorSnackBar('Please log in to start a chat');
      return;
    }

    try {
      // ✅ STEP 1: Show loading overlay FIRST
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // ✅ STEP 2: Backend operations (before navigation)
      print('📝 Ending active conversations...');
      await UserConstant.endAllActiveConversations(userId);

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.clearMessages();

      await Future.delayed(Duration(milliseconds: 200));

      print('✨ Creating new conversation...');
      final newConversationId = await UserConstant.createNewConversation(
        userId,
      );
      print('✅ Created: $newConversationId');

      // ✅ STEP 3: Set up conversation completely
      print('🔧 Setting up conversation...');
      await chatProvider.setConversationId(newConversationId);
      await UserConstant.setSelectedConversation(newConversationId);

      // ✅ STEP 4: Wait for everything to settle
      await Future.delayed(Duration(milliseconds: 500));

      // ✅ STEP 5: Update state with conversation ready
      if (mounted) {
        setState(() {
          _conversationId = newConversationId;
          _pendingConversationId = newConversationId;
          _showFAQs = true;
        });
      }

      // ✅ STEP 6: NOW navigate to chat tab
      if (mounted) {
        await Future.delayed(Duration(milliseconds: 100));

        setState(() {
          _selectedIndex = 1;
        });

        _tabController.animateTo(1);

        // ✅ STEP 7: Hide loading only after navigation complete
        await Future.delayed(Duration(milliseconds: 400));

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }

      print('✅ New chat navigation complete: $newConversationId');
    } catch (e) {
      print('❌ Error in _onNewChatPressed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showFAQs = true;
        });
        _showErrorSnackBar('Failed to create new chat: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleChatNavigation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_conversationId == null) {
        final newConversationId = await UserConstant.createNewConversation(
          user.uid,
        );
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

    print('📝 Conversation selected: $conversationId');

    if (_isLoading || _isNavigating) {
      print('⚠️ Already loading, ignoring duplicate selection');
      return;
    }

    final isSameConversation = _conversationId == conversationId;

    if (_selectedIndex == 1 && isSameConversation) {
      print('ℹ️ Already viewing this conversation');
      return;
    }

    try {
      // ✅ Show loading overlay
      if (mounted) {
        setState(() {
          _isNavigating = true;
          _showFAQs = false;
        });
      }

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // Clear only if different conversation
      if (!isSameConversation) {
        chatProvider.clearMessages();

        if (mounted) {
          setState(() {
            _conversationId = null;
            _pendingConversationId = null;
          });
        }

        await Future.delayed(Duration(milliseconds: 200));
      }

      // Update global state
      await UserConstant.setSelectedConversation(conversationId);

      // Load conversation
      print('🔧 Loading conversation: $conversationId');
      await chatProvider.setConversationId(conversationId);

      // Wait for messages to load
      await Future.delayed(Duration(milliseconds: 800));

      final hasMessages = chatProvider.messages.isNotEmpty;
      print('✅ Messages loaded: ${chatProvider.messages.length}');

      // Update UI
      if (mounted) {
        setState(() {
          _conversationId = conversationId;
          _pendingConversationId = conversationId;
          _showFAQs = !hasMessages;
        });

        await Future.delayed(Duration(milliseconds: 100));

        // Navigate if needed
        if (_selectedIndex != 1 && mounted) {
          setState(() {
            _selectedIndex = 1;
          });
          _tabController.animateTo(1);
        }

        // Wait for navigation animation
        await Future.delayed(Duration(milliseconds: 300));
      }

      print('✅ Conversation selection complete');
    } catch (e) {
      print('❌ Error selecting conversation: $e');
      if (mounted) {
        setState(() {
          _showFAQs = true;
        });
        _showErrorSnackBar('Failed to load conversation: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

@override
Widget build(BuildContext context) {
  // ✅ Move pages list OUTSIDE FutureBuilder so it has proper context
  final List<Widget> _pages = [
    const HomeDashboard(),
    ChatPage(
      key: ValueKey(_conversationId ?? 'empty_${_isLoading ? 'loading' : 'idle'}'),
      conversationId: _conversationId ?? '',
      showFAQs: _showFAQs,
      onFAQToggle: _toggleFAQs,
    ),
    const UserAnnouncementPage(),
    const AdmissionInfo(),
    const ScholarshipList(),
    const PlacementInfo(),
  ];

  return FutureBuilder<void>(
    future: _initFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      assert(_tabController.length == _pages.length, 
        'Tab controller length (${_tabController.length}) must match pages length (${_pages.length})');

      if (_selectedIndex >= _pages.length) {
        print('⚠️ Selected index $_selectedIndex out of range, resetting to 0');
        _selectedIndex = 0;
      }

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

// Keep your existing _buildMobileLayout - it's correct:
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
      onLeadingPressed: isChatPage ? () => Scaffold.of(context).openDrawer() : null,
      customLeading: isChatPage
          ? Builder(
              builder: (context) => IconButton(
                key: _sidebarKey,
                icon: const Icon(Icons.menu, color: Colors.black54),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : null,
      notificationKey: _notificationKey,
      profileKey: _profileKey,
    ),
    drawer: isChatPage ? _buildMobileChatDrawer() : null,
    body: Stack(
      children: [
        pages[_selectedIndex],
        if (_isNavigating || _isLoading)
          buildContentLoadingOverlay(_navigationLoadingTextForIndex(_selectedIndex)),
      ],
    ),
    bottomNavigationBar: Container(
      key: _bottomNavKey,
      child: _buildBottomNavigationBar(),
    ),
  );
}

  // ✅ Update tablet/desktop layout
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
            onNewChat: _onNewChatPressed,
          ),
          // ✅ FIX: Wrap only the page content in Stack
          Expanded(
            child: Stack(
              children: [
                pages[_selectedIndex],
                // ✅ Only white out the content area
                if (_isNavigating || _isLoading)
                  buildContentLoadingOverlay(
                    _navigationLoadingTextForIndex(_selectedIndex),
                  ),
              ],
            ),
          ),
        ],
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

  Widget _buildBottomNavigationBar() {
  int getActualIndex() {
    if (_selectedIndex == 0) return 0; 
    if (_selectedIndex == 1) return 1;
    if (_selectedIndex == 2) return 2; 
    if (_selectedIndex >= 3) return 3; 
    return 0;
  }

  return Stack(
    clipBehavior: Clip.none,
    children: [
      // Main navigation bar - slides off to the right
      
      AnimatedSlide(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        offset: _isBottomNavExpanded ? Offset.zero : const Offset(0, 1.2),

        child: GestureDetector(
          onTap: _resetBottomNavTimer,
          child: CircleNavBar(
            activeIcons: const [
              Icon(Icons.home, color: Colors.green),
              Icon(Icons.chat, color: Colors.green),
              Icon(Icons.announcement, color: Colors.green),
              Icon(Icons.apps, color: Colors.green),
            ],
            inactiveIcons: const [
              Text("Home", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              Text("Chat", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              Text("Announcements", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
              Text("Services", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            ],
            color: Colors.white,
            circleColor: UniversalUIComponents.primaryGreen,
            height: 60,
            circleWidth: 60,
            activeIndex: getActualIndex(),
            onTap: (index) {
              HapticFeedback.mediumImpact();
              _resetBottomNavTimer();
              
              if (index == 3) {
                _showServicesMenu();
              } else {
                _onNavigationItemTap(index);
              }
            },
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
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
        ),
      ),
if (_isBottomNavExpanded)
  Positioned(
    bottom: -5, // slight overlap under navbar
    left: 0,
    right: 0,
    child: GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _isBottomNavExpanded = false;
        });
        _startBottomNavTimer();
      },
      child: Center(
        child: Container(
          width: 60,
          height: 26,
          decoration: BoxDecoration(
            color: UniversalUIComponents.primaryGreen,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    ),
  ),
   
     // Pull-out tab (visible when collapsed)
// Small pull-tab centered under the bottom nav bar
if (!_isBottomNavExpanded)
  Positioned(
    bottom: -5, // slight overlap under navbar
    left: 0,
    right: 0,
    child: GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _isBottomNavExpanded = true;
        });
        _startBottomNavTimer();
      },
      child: Center(
        child: Container(
          width: 60,
          height: 26,
          decoration: BoxDecoration(
            color: UniversalUIComponents.primaryGreen,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.keyboard_arrow_up,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    ),
  ),

    ],
  );
}

  void _startBottomNavTimer() {
    _bottomNavTimer?.cancel();
    _bottomNavTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _isBottomNavExpanded = false;
        });
      }
    });
  }

  void _resetBottomNavTimer() {
    if (!_isBottomNavExpanded) {
      setState(() {
        _isBottomNavExpanded = true;
      });
    }
    _startBottomNavTimer();
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
                    // ✅ Navigate to actual page index
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
                    // ✅ Navigate to actual page index
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
                    // ✅ Navigate to actual page index
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
