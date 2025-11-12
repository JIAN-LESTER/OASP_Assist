import 'package:capstone_project/pages/admin_pages/admission_management.dart';
import 'package:capstone_project/pages/admin_pages/affiliation.dart';
import 'package:capstone_project/pages/admin_pages/announcement_page.dart';
import 'package:capstone_project/pages/admin_pages/dashboard_page.dart';
import 'package:capstone_project/pages/admin_pages/faq_page.dart';
import 'package:capstone_project/pages/admin_pages/human_escalation.dart';
import 'package:capstone_project/pages/admin_pages/information_bank_page.dart';
import 'package:capstone_project/pages/admin_pages/message_logs.dart';
import 'package:capstone_project/pages/admin_pages/placement_management.dart';
import 'package:capstone_project/pages/admin_pages/programs.dart';
import 'package:capstone_project/pages/admin_pages/reports_page.dart';
import 'package:capstone_project/pages/admin_pages/scholarship_management.dart';
import 'package:capstone_project/pages/admin_pages/system_logs_page.dart';
import 'package:capstone_project/pages/admin_pages/user_management_page.dart';


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

  @override
  void initState() {
    super.initState();
    
    // ✅ Set initial tab if provided
    if (widget.initialTabIndex != null) {
      _selectedIndex = widget.initialTabIndex!;
      print('🎯 Admin initial tab set to: $_selectedIndex');
    }
    
    // ✅ Handle escalation auto-open after build
    if (widget.autoOpen && widget.escalationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleEscalationAutoOpen();
      });
    }
  }

  void _handleEscalationAutoOpen() {
    print('🔓 Auto-opening escalation: ${widget.escalationId}');
    // Add your escalation auto-open logic here
    // This would typically involve opening a dialog or navigating to detail
  }

  // Create a method to handle navigation
  void _navigateToPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Update the _pages list to pass the callback and handle escalation
  List<Widget> get _pages => [
    const DashboardPage(),        
    const ReportsPage(),
    const InformationBankPage(),
    const FaqManagementPage(),
    const AnnouncementPage(),
    
    // ✅ Pass escalation parameters to HumanEscalation page
    HumanEscalation(
      initialEscalationId: widget.escalationId,
      autoOpen: widget.autoOpen,
    ),
    
    UserManagementPage(
      onNavigateToPage: _navigateToPage,
    ),
    const UserActivityLogsPage(),
    const AdminMessageLogsPage(),
    const AdmissionManagementPage(),
    const ScholarshipManagementPage(),
    const PlacementManagementPage(),
    const AffiliationManagementPage(),
    const ProgramManagementPage()
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
    'Admission',
    'Scholarship',
    'Placement',
    'Affiliations',
    'Programs'
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