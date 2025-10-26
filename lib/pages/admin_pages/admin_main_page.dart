import 'package:capstone_project/pages/admin_pages/admission_management.dart';
import 'package:capstone_project/pages/admin_pages/announcement_page.dart';
import 'package:capstone_project/pages/admin_pages/dashboard_page.dart';
import 'package:capstone_project/pages/admin_pages/faq_page.dart';
import 'package:capstone_project/pages/admin_pages/information_bank_page.dart';
import 'package:capstone_project/pages/admin_pages/message_logs.dart';
import 'package:capstone_project/pages/admin_pages/placement_management.dart';
import 'package:capstone_project/pages/admin_pages/reports_page.dart';
import 'package:capstone_project/pages/admin_pages/scholarship_management.dart';
import 'package:capstone_project/pages/admin_pages/system_logs_page.dart';
import 'package:capstone_project/pages/admin_pages/user_management_page.dart';


import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/responsive/widgets/menu.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;

  final List<Widget> _pages = [
    const DashboardPage(),        
    const ReportsPage(),          // 1
    const InformationBankPage(),  // 2
    const FaqManagementPage(),    // 3
    const AnnouncementPage(),     // 4
    const UserManagementPage(),   // 5
    const UserActivityLogsPage(), // 6
    const AdminMessageLogsPage(), // 7
    const AdmissionManagementPage(), // 8
    const ScholarshipManagementPage(), // 9
    const PlacementManagementPage(), // 10
  ];

  final List<String> _pageTitles = [
    'Dashboard',                  // 0
    'Reports',                   // 1
    'Information Bank',          // 2
    'FAQs',                     // 3
    'Announcement',             // 4
    'User Management',          // 5
    'System Activity Logs',     // 6
    'Message Logs',             // 7
    'Admission',                // 8
    'Scholarship',              // 9
    'Placement',                // 10
  ];

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
        userRole: UserRole.admin,
        title: _pageTitles[_selectedIndex],
      ),
      drawer: UniversalUIComponents.buildDrawer(
        context: context,
        userRole: UserRole.admin,
        selectedIndex: _selectedIndex,
        onItemTap: _onNavigationItemTap,
      ),
      body: _pages[_selectedIndex],
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
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}