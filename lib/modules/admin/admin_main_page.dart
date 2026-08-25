import 'package:capstone_project/modules/admin/colleges_programs_managament/college.dart';
import 'package:capstone_project/modules/admin/colleges_programs_managament/programs.dart';

import 'package:capstone_project/modules/admin/announcement/announcement_page.dart';

import 'package:capstone_project/modules/admin/dashboard_and_reports/dashboard_page.dart';
import 'package:capstone_project/modules/admin/faqs/faq_page.dart';
import 'package:capstone_project/modules/admin/human_escalation/human_escalation.dart';
import 'package:capstone_project/modules/admin/information_bank/information_bank_page.dart';
import 'package:capstone_project/modules/admin/logs/message_logs.dart';

import 'package:capstone_project/modules/admin/dashboard_and_reports/reports_page.dart';

import 'package:capstone_project/modules/admin/logs/system_logs_page.dart';
import 'package:capstone_project/modules/admin/user_management/user_management_page.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/responsive/widgets/menu.dart';

class AdminMainPage extends StatefulWidget {
  final int? initialTabIndex;
  final String? escalationId;
  final String? conversationId;
  final bool autoOpen;

  const AdminMainPage({
    super.key,
    this.initialTabIndex,
    this.escalationId,
    this.conversationId,
    this.autoOpen = false,
  });

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  bool _isNavigating = false;

  //  Add state variables to track escalation parameters
  String? _currentEscalationId;
  bool _shouldAutoOpen = false;

  @override
  void initState() {
    super.initState();

    //  Set initial tab if provided
    if (widget.initialTabIndex != null) {
      _selectedIndex = widget.initialTabIndex!;
      print(' Admin initial tab set to: $_selectedIndex');
    }

    //  Copy escalation parameters to state (they'll be cleared after use)
    if (widget.autoOpen && widget.escalationId != null) {
      _currentEscalationId = widget.escalationId;
      _shouldAutoOpen = true;
    }
  }

  // Create a method to handle navigation
  Future<void> _navigateToPage(int index) async {
    if (!mounted ||
        _isNavigating ||
        index == _selectedIndex ||
        index < 0 ||
        index >= _pages.length) {
      return;
    }

    setState(() {
      _isNavigating = true;
      _selectedIndex = index;
      //  Clear escalation parameters when navigating away from escalation page
      if (index != 5) {
        // 5 is the index of HumanEscalation page
        _currentEscalationId = null;
        _shouldAutoOpen = false;
      }
    });

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    setState(() {
      _isNavigating = false;
    });
  }

  // Update the _pages list to use state variables
  List<Widget> get _pages => [
    const DashboardPage(),
    const ReportsPage(),
    const InformationBankPage(),
    const FaqManagementPage(),
    const AnnouncementPage(),

    //  Pass state variables instead of widget properties
    HumanEscalation(
      key: ValueKey(
        'escalation_${_currentEscalationId}_$_shouldAutoOpen',
      ), //  Add key to force rebuild
      initialEscalationId: _currentEscalationId,
      autoOpen: _shouldAutoOpen,
    ),

    UserManagementPage(onNavigateToPage: _navigateToPage),
    const UserActivityLogsPage(),
    const AdminMessageLogsPage(),
    const CollegeManagementPage(),
    const ProgramManagementPage(),
  ];

  final List<String> _pageTitles = [
    'Dashboard',
    'Reports',
    'Information Bank',
    'FAQs',
    'Announcement',
    'Human Escalation',
    'Users',
    'System Activity Logs',
    'Message Logs',
    'Colleges',
    'Programs',
  ];

  void _onNavigationItemTap(int index) {
    _navigateToPage(index);
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
        userRole: UserRole.admin,
        title: _pageTitles[_selectedIndex],
      ),
      drawer: UniversalUIComponents.buildDrawer(
        context: context,
        userRole: UserRole.admin,
        selectedIndex: _selectedIndex,
        onItemTap: _onNavigationItemTap,
      ),
      body: Stack(
        children: [
          _pages[_selectedIndex],
        ],
      ),
    );
  }

  Widget _buildTabletDesktopLayout() {
    return Scaffold(
      backgroundColor: UniversalUIComponents.backgroundGrey,
      appBar: UniversalUIComponents.buildAppBar(
        context: context,
        userRole: UserRole.admin,
        title: _pageTitles[_selectedIndex],
        showBackButton: false,
        onLeadingPressed: _toggleSidebar,
      ),
      body: Row(
        children: [
          UniversalUIComponents.buildPersistentDrawer(
            context: context,
            userRole: UserRole.admin,
            selectedIndex: _selectedIndex,
            onItemTap: _onNavigationItemTap,
            isExpanded: _isSidebarExpanded,
          ),
          Expanded(
            child: Stack(
              children: [
                _pages[_selectedIndex],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
