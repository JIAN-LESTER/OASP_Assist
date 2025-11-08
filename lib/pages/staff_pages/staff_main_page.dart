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
  final bool autoOpen;

  const StaffMainPage({
    super.key,
    this.initialTabIndex,
    this.escalationId,
    this.autoOpen = false,
  });

  @override
  State<StaffMainPage> createState() => _StaffMainPageState();
}

class _StaffMainPageState extends State<StaffMainPage> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  bool _handledInitialArgs = false;

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
    // Set initial tab if provided
    _selectedIndex = widget.initialTabIndex ?? 0;
    
    print('🎯 StaffMainPage initialized with:');
    print('   - initialTabIndex: ${widget.initialTabIndex}');
    print('   - escalationId: ${widget.escalationId}');
    print('   - autoOpen: ${widget.autoOpen}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_handledInitialArgs) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      
      if (args != null) {
        final initialTab = args['initialTab'] as int?;
        final escalationId = args['escalationId'] as String?;
        final autoOpen = args['autoOpen'] as bool? ?? false;

        if (initialTab != null) {
          setState(() {
            _selectedIndex = initialTab;
          });
        }

        // If navigating to escalations tab with specific escalation
        if (_selectedIndex == 2 && escalationId != null) {
          // The HumanEscalation widget will handle opening the specific escalation
          print('📍 Staff navigated to escalation: $escalationId');
        }
      }
      _handledInitialArgs = true;
    }
  }

  List<Widget> _getPages() {
    return [
      const StaffDashboardPage(),
      const StaffReportsPage(),
      HumanEscalation(
        initialEscalationId: widget.escalationId,
        autoOpen: widget.autoOpen || _selectedIndex == 2,
      ),
      const StaffAnnouncementPage(),
      const StaffMessageLogsPage(),
    ];
  }

  void _onNavigationItemTap(int index) {
    setState(() {
      _selectedIndex = index;
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