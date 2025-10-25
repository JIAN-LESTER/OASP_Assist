import 'package:capstone_project/pages/staff_pages/staff_dashboard_page.dart';
import 'package:capstone_project/pages/staff_pages/human_escalation.dart';
import 'package:capstone_project/pages/staff_pages/staff_reports_page.dart';
import 'package:capstone_project/pages/staff_pages/staff_announcement_page.dart';

import 'package:capstone_project/pages/staff_pages/staff_message_logs.dart';

// import 'package:capstone_project/responsive/staff_constant.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

import 'package:capstone_project/responsive/widgets/menu.dart';

class StaffMainPage extends StatefulWidget {
  const StaffMainPage({super.key});

  @override
  State<StaffMainPage> createState() => _StaffMainPageState();
}

class _StaffMainPageState extends State<StaffMainPage> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded =
      true; // Track whether sidebar is expanded or collapsed (always visible)

  final List<Widget> _pages = const [
    StaffDashboardPage(),
    StaffReportsPage(),
    HumanEscalation(),
    StaffAnnouncementPage(),

    StaffMessageLogsPage(),
  ];

  final List<String> _pageTitles = const [
    'Dashboard',
    'Reports',
    'Human Escalation',
    'Announcement',

    'Message Logs',
  ];

  void _onNavigationItemTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded =
          !_isSidebarExpanded; // Simply toggle between expanded and collapsed
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

  // Mobile layout with traditional drawer
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
      body: _pages[_selectedIndex],
    );
  }

  // Tablet and Desktop layout with collapsible sidebar
  Widget _buildTabletDesktopLayout() {
    return Scaffold(
      backgroundColor: UniversalUIComponents.backgroundGrey,
      appBar: UniversalUIComponents.buildAppBar(
        context: context,
        userRole: UserRole.staff,
        title: _pageTitles[_selectedIndex],
        showBackButton: false,
        onLeadingPressed: _toggleSidebar, // Custom hamburger menu functionality
      ),
      body: Row(
        children: [
          UniversalUIComponents.buildPersistentDrawer(
            context: context,
            userRole: UserRole.staff,
            selectedIndex: _selectedIndex,
            onItemTap: _onNavigationItemTap,
            isExpanded: _isSidebarExpanded, // Pass the expanded state
          ),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
