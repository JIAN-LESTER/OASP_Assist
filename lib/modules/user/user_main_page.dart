import 'dart:async';

import 'package:capstone_project/models/message.dart';
import 'package:capstone_project/modules/user/announcement/user_announcement.dart';
import 'package:capstone_project/modules/user/chat/chat_page.dart';

import 'package:capstone_project/modules/user/home/home.dart';
import 'package:capstone_project/modules/user/services/admission_info.dart';
import 'package:capstone_project/modules/user/services/placement_info.dart';
import 'package:capstone_project/modules/user/services/scholarship_list.dart';
import 'package:capstone_project/modules/authentication/onboarding/onBoardingGuide.dart';
import 'package:capstone_project/reusable_widgets/loading_overlay.dart';
import 'package:capstone_project/utils/snackbar_util.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'package:capstone_project/provider/chat_provider.dart';

import 'package:capstone_project/responsive/user_constant.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/responsive/widgets/menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserMainPage extends StatefulWidget {
  final int? initialTabIndex;
  final String? conversationId;
  final bool? loadExisting;
  final bool? fromNotification;
  final bool? shouldShowGuide;

  const UserMainPage({
    Key? key,
    this.initialTabIndex,
    this.conversationId,
    this.loadExisting,
    this.fromNotification,
    this.shouldShowGuide,
  }) : super(key: key);

  @override
  State<UserMainPage> createState() => _UserMainPageState();
}

class _UserMainPageState extends State<UserMainPage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _currentIndex = 0;
  late TabController _tabController;

  String? _pendingConversationId;
  bool? loadExistingConversation;
  bool _isLoading = false;
  bool _isNavigating = false;

  // 🔑 Onboarding Keys
  final GlobalKey _sidebarKey = GlobalKey();
  final GlobalKey _notificationKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();
  final GlobalKey _faqButtonKey = GlobalKey();
  final GlobalKey _audioButtonKey = GlobalKey();

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
      _showFAQs = false;
    } else {
      print('ℹ️ No conversation passed, checking for active conversation');
      _initFuture = _initializeConversationOrShowFAQs(); // ✅ NEW method
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      UserConstant.initializeChatSession(context, setState);

      if (_selectedIndex == 1 && _conversationId != null) {
        print('📱 Already on chat tab with conversation: $_conversationId');
      }

      // ✅ Check if we should trigger the OnboardingGuide
      if (widget.shouldShowGuide == true) {
        await _checkAndShowOnboardingGuide();
      }
      // ✅ Welcome dialog will be triggered by OnboardingGuide completion (no need to check here)
    });
  }

  Future<void> _checkAndShowOnboardingGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldShow = prefs.getBool('should_show_guide') ?? false;

      if (shouldShow && mounted) {
        await prefs.setBool('should_show_guide', false);

        //  REMOVED DELAY - Show immediately
        if (mounted) {
          final onboardingGuide = OnboardingGuide.of(context);
          if (onboardingGuide != null) {
            print('✅ Triggering OnboardingGuide after user onboarding');
            onboardingGuide.showGuide();
          }
        }
      }
    } catch (e) {
      print('❌ Error checking onboarding guide: $e');
    }
  }

  // ✅ NEW METHOD: Show welcome dialog
  Future<void> _showWelcomeDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const FirstTimeWelcomeDialog(),
    );
  }

  Future<void> _initializeConversationOrShowFAQs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      print('🔍 Looking for active conversations...');

      // ✅ Keep FAQs hidden during check
      if (mounted) {
        setState(() {
          _showFAQs = false; // ❌ Don't show yet
        });
      }

      final activeConversations =
          await _firestore
              .collection('conversations')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'active')
              .orderBy('lastActivity', descending: true)
              .limit(1)
              .get();

      if (activeConversations.docs.isNotEmpty) {
        final conversationId = activeConversations.docs.first.id;
        print('✅ Found active conversation: $conversationId');

        await _loadExistingConversation(conversationId);

        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        final hasMessages = chatProvider.messages.isNotEmpty;

        if (mounted) {
          setState(() {
            _conversationId = conversationId;
            _showFAQs = !hasMessages; // ✅ Only show if no messages
          });
        }
      } else {
        print('ℹ️ No active conversations found - showing FAQs');

        if (mounted) {
          setState(() {
            _conversationId = null;
            _showFAQs = true; // ✅ Safe to show now
          });
        }
      }
    } catch (e) {
      print('❌ Error in initialization: $e');
      if (mounted) {
        setState(() {
          _showFAQs = true;
        });
      }
    }
  }

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

  final List<String> _pageTitles = const [
    'Home',
    'Chat with OASP Assist',
    'Announcements',
    'Admission Information',
    'Scholarship List',
    'Placement Information',
  ];

  String _navigationLoadingTextForIndex(int index) {
    return 'Loading...';
  }

  void _onNavigationItemTap(int index) async {
    print('📱 Navigation tap to index: $index');

    if (!mounted || _isNavigating) return;

    if (index < 0 || index >= _tabController.length) {
      print('⚠️ Invalid tab index: $index');
      return;
    }

    // ✅ Only show loading for index 1 (Chat)
    final shouldShowLoading =
        index == 1 && (_conversationId != null && _conversationId!.isNotEmpty);

    if (shouldShowLoading) {
      setState(() {
        _isNavigating = true;
      });
    }

    try {
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

          final hasMessages = chatProvider.messages.isNotEmpty;

          setState(() {
            _showFAQs = !hasMessages;
            _selectedIndex = 1;
          });
        }

        _tabController.animateTo(1, duration: Duration.zero); // ✅ Instant
      } else {
        print('➡️ Navigating to tab: $index');

        setState(() {
          _showFAQs = false;
          _selectedIndex = index;
        });

        _tabController.animateTo(index, duration: Duration.zero); // ✅ Instant
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
        key: ValueKey(
          _conversationId ?? 'empty_${_isLoading ? 'loading' : 'idle'}',
        ),
        conversationId: _conversationId ?? '',
        showFAQs: _showFAQs,
        onFAQToggle: _toggleFAQs,
        faqButtonKey: _faqButtonKey,
        audioButtonKey: _audioButtonKey,
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

        assert(
          _tabController.length == _pages.length,
          'Tab controller length (${_tabController.length}) must match pages length (${_pages.length})',
        );

        if (_selectedIndex >= _pages.length) {
          print(
            '⚠️ Selected index $_selectedIndex out of range, resetting to 0',
          );
          _selectedIndex = 0;
        }

        return OnboardingGuide(
          sidebarKey: _sidebarKey,
          notificationKey: _notificationKey,
          profileKey: _profileKey,
          bottomNavKey: _bottomNavKey,
          faqButtonKey: _faqButtonKey,
          audioButtonKey: _audioButtonKey,
          onFinished: () {
            //  Callback when guide finishes
            print(' Onboarding guide completed');
            //  Show welcome dialog immediately after onboarding
            _showWelcomeDialog();
          },
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
        onLeadingPressed:
            isChatPage ? () => Scaffold.of(context).openDrawer() : null,
        customLeading:
            isChatPage
                ? Builder(
                  builder:
                      (context) => IconButton(
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
            buildContentLoadingOverlay(
              _navigationLoadingTextForIndex(_selectedIndex),
            ),
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
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_outlined, color: Colors.grey[400], size: 40),
            const SizedBox(height: 12),
            Text(
              'Please log in',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
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
          return Center(
            child: CircularProgressIndicator(
              color: UniversalUIComponents.primaryGreen,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

        final conversations =
            snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {'id': doc.id, 'title': data['title'] ?? 'Untitled'};
            }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conv = conversations[index];
            final convId = conv['id'] as String;
            final isSelected = convId == _conversationId;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? UniversalUIComponents.primaryGreen.withOpacity(
                              0.2,
                            )
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: isSelected ? Colors.green[700] : Colors.grey[500],
                    size: 18,
                  ),
                ),
                title: Text(
                  conv['title'] ?? 'Untitled',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.green[800] : Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.grey[500],
                  ),
                  onPressed:
                      () => _showDeleteConversationDialog(
                        context,
                        convId,
                        conv['title'] ?? 'Untitled',
                      ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _onConversationSelected(context, convId);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteConversationDialog(
    BuildContext context,
    String conversationId,
    String conversationTitle,
  ) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // ValueNotifier for delete loading state
    final isDeleting = ValueNotifier<bool>(false);

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
                      const SizedBox(height: 24),

                      // Action Buttons
                      ValueListenableBuilder<bool>(
                        valueListenable: isDeleting,
                        builder: (context, deleting, _) {
                          return Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed:
                                        deleting
                                            ? null
                                            : () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF6B7280),
                                      backgroundColor: Colors.white,
                                      disabledForegroundColor:
                                          Colors.grey.shade400,
                                      side: BorderSide(
                                        color:
                                            deleting
                                                ? const Color(0xFFE5E7EB)
                                                : const Color(0xFFD1D5DB),
                                        width: 1,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: isMobile ? 15 : 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed:
                                        deleting
                                            ? null
                                            : () async {
                                              isDeleting.value = true;

                                              try {
                                                final wasSelected =
                                                    _conversationId ==
                                                    conversationId;

                                                if (wasSelected) {
                                                  await UserConstant.setSelectedConversation(
                                                    '',
                                                  );
                                                  UserConstant.shouldShowFAQs =
                                                      true;

                                                  if (context.mounted) {
                                                    final chatProvider =
                                                        Provider.of<
                                                          ChatProvider
                                                        >(
                                                          context,
                                                          listen: false,
                                                        );
                                                    chatProvider
                                                        .clearMessages();

                                                    setState(() {
                                                      _conversationId = null;
                                                      _showFAQs = true;
                                                    });
                                                  }
                                                }

                                                final firestore =
                                                    FirebaseFirestore.instance;
                                                final batch = firestore.batch();

                                                final messagesSnapshot =
                                                    await firestore
                                                        .collection(
                                                          'conversations',
                                                        )
                                                        .doc(conversationId)
                                                        .collection('messages')
                                                        .get();

                                                for (final doc
                                                    in messagesSnapshot.docs) {
                                                  batch.delete(doc.reference);
                                                }
                                                batch.delete(
                                                  firestore
                                                      .collection(
                                                        'conversations',
                                                      )
                                                      .doc(conversationId),
                                                );

                                                await batch.commit();

                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                  SnackbarUtil.showSuccess(
                                                    context,
                                                    'Conversation deleted successfully',
                                                  );
                                                }
                                              } catch (e) {
                                                print('❌ Delete error: $e');
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                  SnackbarUtil.showError(
                                                    context,
                                                    'Failed to delete conversation',
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
                                      disabledBackgroundColor: const Color(
                                        0xFFFCA5A5,
                                      ),
                                      disabledForegroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    child:
                                        deleting
                                            ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Deleting...',
                                                  style: TextStyle(
                                                    fontSize:
                                                        isMobile ? 15 : 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : Text(
                                              'Delete',
                                              style: TextStyle(
                                                fontSize: isMobile ? 15 : 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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

  // Widget _buildBottomNavigationBar() {
  //   int getActualIndex() {
  //     if (_selectedIndex == 0) return 0;
  //     if (_selectedIndex == 1) return 1;
  //     if (_selectedIndex == 2) return 2;
  //     if (_selectedIndex >= 3) return 3;
  //     return 0;
  //   }

  //   // Height when expanded vs collapsed
  //   final double expandedHeight = 80; // CircleNavBar height + padding
  //   final double collapsedHeight = 30; // Just enough for the pull tab

  //   return AnimatedContainer(
  //     duration: const Duration(milliseconds: 400),
  //     curve: Curves.easeInOut,
  //     height: _isBottomNavExpanded ? expandedHeight : collapsedHeight,
  //     child: Stack(
  //       clipBehavior: Clip.none,
  //       children: [
  //         // Main navigation bar
  //         if (_isBottomNavExpanded)
  //           Positioned(
  //             left: 0,
  //             right: 0,
  //             bottom: 0,
  //             child: GestureDetector(
  //               onTap: _resetBottomNavTimer,
  //               child: CircleNavBar(
  //                 activeIcons: const [
  //                   Icon(Icons.home, color: Colors.green),
  //                   Icon(Icons.chat, color: Colors.green),
  //                   Icon(Icons.announcement, color: Colors.green),
  //                   Icon(Icons.apps, color: Colors.green),
  //                 ],
  //                 inactiveIcons: const [
  //                   Text(
  //                     "Home",
  //                     style: TextStyle(
  //                       fontSize: 11,
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //                   Text(
  //                     "Chat",
  //                     style: TextStyle(
  //                       fontSize: 11,
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //                   Text(
  //                     "Announcements",
  //                     style: TextStyle(
  //                       fontSize: 10,
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //                   Text(
  //                     "Services",
  //                     style: TextStyle(
  //                       fontSize: 11,
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //                 ],
  //                 color: Colors.white,
  //                 circleColor: UniversalUIComponents.primaryGreen,
  //                 height: 60,
  //                 circleWidth: 60,
  //                 activeIndex: getActualIndex(),
  //                 onTap: (index) {
  //                   HapticFeedback.mediumImpact();
  //                   _resetBottomNavTimer();
  //                   if (index == 3) {
  //                     _showServicesMenu();
  //                   } else {
  //                     _onNavigationItemTap(index);
  //                   }
  //                 },
  //                 padding: const EdgeInsets.only(
  //                   left: 16,
  //                   right: 16,
  //                   bottom: 20,
  //                 ),
  //                 cornerRadius: const BorderRadius.only(
  //                   topLeft: Radius.circular(8),
  //                   topRight: Radius.circular(8),
  //                   bottomRight: Radius.circular(24),
  //                   bottomLeft: Radius.circular(24),
  //                 ),
  //                 shadowColor: Colors.grey.shade300,
  //                 circleShadowColor: Colors.grey.shade400,
  //                 elevation: 8,
  //                 gradient: LinearGradient(
  //                   begin: Alignment.topCenter,
  //                   end: Alignment.bottomCenter,
  //                   colors: [Colors.white, Colors.grey.shade50],
  //                 ),
  //               ),
  //             ),
  //           ),

  //         // Pull tab - always visible, changes icon based on state
  //         Positioned(
  //           bottom: 0,
  //           left: 0,
  //           right: 0,
  //           child: GestureDetector(
  //             onTap: () {
  //               HapticFeedback.mediumImpact();
  //               setState(() {
  //                 _isBottomNavExpanded = !_isBottomNavExpanded;
  //               });
  //               if (_isBottomNavExpanded) {
  //                 _startBottomNavTimer();
  //               }
  //             },
  //             child: Center(
  //               child: Container(
  //                 width: 60,
  //                 height: 26,
  //                 decoration: BoxDecoration(
  //                   color: UniversalUIComponents.primaryGreen,
  //                   borderRadius: BorderRadius.circular(14),
  //                   boxShadow: [
  //                     BoxShadow(
  //                       color: Colors.black.withOpacity(0.15),
  //                       blurRadius: _isBottomNavExpanded ? 6 : 4,
  //                       offset: Offset(0, _isBottomNavExpanded ? 2 : 1),
  //                     ),
  //                   ],
  //                 ),
  //                 child: Center(
  //                   child: Icon(
  //                     _isBottomNavExpanded
  //                         ? Icons.keyboard_arrow_down
  //                         : Icons.keyboard_arrow_up,
  //                     color: Colors.white,
  //                     size: 20,
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Replace the _buildBottomNavigationBar method with this:

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate if we need to use smaller sizes
            final screenWidth = constraints.maxWidth;
            final isVerySmall = screenWidth < 320; // iPhone SE 1st gen
            final isSmall = screenWidth < 375; // Small phones

            return SizedBox(
              height: 65,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildNavItem(
                      icon: Icons.home,
                      label: 'Home',
                      index: 0,
                      isSelected: _selectedIndex == 0,
                      isVerySmall: isVerySmall,
                      isSmall: isSmall,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      icon: Icons.chat_bubble_outline,
                      label: 'Chat',
                      index: 1,
                      isSelected: _selectedIndex == 1,
                      isVerySmall: isVerySmall,
                      isSmall: isSmall,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      icon: Icons.announcement_outlined,
                      label: 'Announcements',
                      index: 2,
                      isSelected: _selectedIndex == 2,
                      isVerySmall: isVerySmall,
                      isSmall: isSmall,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      icon: Icons.apps,
                      label: 'Services',
                      index: 3,
                      isSelected: _selectedIndex >= 3,
                      isVerySmall: isVerySmall,
                      isSmall: isSmall,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    required bool isVerySmall,
    required bool isSmall,
  }) {
    // Map to filled icons when selected
    IconData displayIcon = icon;
    if (isSelected) {
      if (icon == Icons.home) {
        displayIcon = Icons.home;
      } else if (icon == Icons.chat_bubble_outline) {
        displayIcon = Icons.chat_bubble;
      } else if (icon == Icons.announcement_outlined) {
        displayIcon = Icons.announcement;
      } else if (icon == Icons.apps) {
        displayIcon = Icons.apps;
      }
    }

    // Adaptive sizing based on screen width
    final double iconSize = isVerySmall ? 20 : (isSmall ? 22 : 24);
    final double fontSize = isVerySmall ? 8 : (isSmall ? 9 : 10);
    final double spacing = isVerySmall ? 2 : 4;

    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (index == 3) {
          _showServicesMenu();
        } else {
          _onNavigationItemTap(index);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isVerySmall ? 0 : 2,
          vertical: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              displayIcon,
              size: iconSize,
              color:
                  isSelected
                      ? UniversalUIComponents.primaryGreen
                      : Colors.grey.shade400,
            ),
            SizedBox(height: spacing),
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color:
                              isSelected
                                  ? UniversalUIComponents.primaryGreen
                                  : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
