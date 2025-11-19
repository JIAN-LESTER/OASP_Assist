import 'package:capstone_project/pages/staff_pages/staff_dashboard_page.dart';
import 'package:capstone_project/pages/staff_pages/human_escalation.dart';
import 'package:capstone_project/pages/staff_pages/staff_reports_page.dart';
import 'package:capstone_project/pages/staff_pages/staff_announcement_page.dart';
import 'package:capstone_project/pages/staff_pages/staff_message_logs.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/responsive/widgets/menu.dart';

class StaffMainPage extends StatefulWidget {
  final int? initialTabIndex;
  final String? escalationId;
  final String? conversationId;
  final bool autoOpen;

  const StaffMainPage({
    super.key,
    this.initialTabIndex,
    this.escalationId,
    this.conversationId,
    this.autoOpen = false,
  });

  @override
  State<StaffMainPage> createState() => _StaffMainPageState();
}

class _StaffMainPageState extends State<StaffMainPage> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  bool _handledInitialArgs = false;
  
  // ✅ Store escalation details to pass to HumanEscalation
  String? _escalationId;
  String? _conversationId;
  bool _shouldAutoOpen = false;

  final List<String> _pageTitles = const [
    'Dashboard',
    'Reports',
    'Human Escalation',
    'Announcement',
    'Message Logs',
  ];

  @override
  void initState() {
    super.initState();
    
    // Set initial values from constructor
    _selectedIndex = widget.initialTabIndex ?? 0;
    _escalationId = widget.escalationId;
    _conversationId = widget.conversationId;
    _shouldAutoOpen = widget.autoOpen;
    
    print('🎯 StaffMainPage initialized with:');
    print('   - initialTabIndex: ${widget.initialTabIndex}');
    print('   - escalationId: ${widget.escalationId}');
    print('   - conversationId: ${widget.conversationId}');
    print('   - autoOpen: ${widget.autoOpen}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_handledInitialArgs) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      
      if (args != null) {
        print('📦 Received navigation arguments: $args');
        
        final initialTab = args['initialTab'] as int?;
        final escalationId = args['escalationId'] as String?;
        final conversationId = args['conversationId'] as String?;
        final autoOpen = args['autoOpen'] as bool? ?? false;

        setState(() {
          if (initialTab != null) {
            _selectedIndex = initialTab;
          }
          
          // ✅ Store escalation details
          if (escalationId != null) {
            _escalationId = escalationId;
            _conversationId = conversationId;
            _shouldAutoOpen = autoOpen;
          }
        });

        print('✅ State updated:');
        print('   - selectedIndex: $_selectedIndex');
        print('   - escalationId: $_escalationId');
        print('   - shouldAutoOpen: $_shouldAutoOpen');
      }
      
      _handledInitialArgs = true;
    }
  }

  List<Widget> _getPages() {
    return [
      const StaffDashboardPage(),
      const StaffReportsPage(),
   
      HumanEscalation(
        key: ValueKey('escalation_$_escalationId'), // ✅ Force rebuild when escalationId changes
        initialEscalationId: _escalationId,
        autoOpen: _shouldAutoOpen && _selectedIndex == 2,
      ),
      const StaffAnnouncementPage(),
      const StaffMessageLogsPage(),
    ];
  }

  void _onNavigationItemTap(int index) {
    setState(() {
      _selectedIndex = index;
      
      // ✅ Reset escalation details when navigating away
      if (index != 2) {
        _escalationId = null;
        _conversationId = null;
        _shouldAutoOpen = false;
      }
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBody: _buildMobileLayout(),
      tabletBody: _buildTabletDesktopLayout(),
      desktopBody: _buildTabletDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: UniversalUIComponents.backgroundGrey,
      appBar: UniversalUIComponents.buildAppBar(
        context: context,
        userRole: UserRole.staff,
        title: _pageTitles[_selectedIndex],
      ),
      drawer: UniversalUIComponents.buildDrawer(
        context: context,
        userRole: UserRole.staff,
        selectedIndex: _selectedIndex,
        onItemTap: _onNavigationItemTap,
      ),
      body: _getPages()[_selectedIndex],
    );
  }

  Widget _buildTabletDesktopLayout() {
    return Scaffold(
      backgroundColor: UniversalUIComponents.backgroundGrey,
      appBar: UniversalUIComponents.buildAppBar(
        context: context,
        userRole: UserRole.staff,
        title: _pageTitles[_selectedIndex],
        showBackButton: false,
        onLeadingPressed: _toggleSidebar,
      ),
      body: Row(
        children: [
          UniversalUIComponents.buildPersistentDrawer(
            context: context,
            userRole: UserRole.staff,
            selectedIndex: _selectedIndex,
            onItemTap: _onNavigationItemTap,
            isExpanded: _isSidebarExpanded,
          ),
          Expanded(child: _getPages()[_selectedIndex]),
        ],
      ),
    );
  }
}