
import 'package:capstone_project/modules/staff_module/announcement_module/staff_announcement_page.dart';
import 'package:capstone_project/modules/staff_module/dashboard_and_reports_module/staff_dashboard_page.dart';
import 'package:capstone_project/modules/staff_module/dashboard_and_reports_module/staff_reports_page.dart';
import 'package:capstone_project/modules/staff_module/human_escalation_module/human_escalation.dart';
import 'package:capstone_project/modules/staff_module/logs_module/staff_message_logs.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  
  String? _escalationId;
  String? _conversationId;
  bool _shouldAutoOpen = false;

  String _serviceUnit = "";
  bool _isLoadingServiceUnit = true;

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
    
    _selectedIndex = widget.initialTabIndex ?? 0;
    _escalationId = widget.escalationId;
    _conversationId = widget.conversationId;
    _shouldAutoOpen = widget.autoOpen;

    _fetchStaffServiceUnit();
    
    print('🎯 StaffMainPage initState:');
    print('   - initialTabIndex: ${widget.initialTabIndex}');
    print('   - escalationId: ${widget.escalationId}');
    print('   - conversationId: ${widget.conversationId}');
    print('   - autoOpen: ${widget.autoOpen}');
    print('   - _selectedIndex: $_selectedIndex');
  }

  Future<void> _fetchStaffServiceUnit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No user logged in');
        setState(() {
          _isLoadingServiceUnit = false;
        });
        return;
      }

      print('📡 Fetching service unit for user: ${user.uid}');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final fetchedServiceUnit = data?['serviceUnit'] as String?;
        
        print('📦 User document data: $data');
        print('📦 Service unit field: $fetchedServiceUnit');
        
        setState(() {
          _serviceUnit = fetchedServiceUnit ?? "";
          _isLoadingServiceUnit = false;
        });
        
        print('✅ Staff service unit loaded: "$_serviceUnit"');
        
        if (_serviceUnit.isEmpty) {
          print('⚠️ WARNING: Service unit is empty!');
        }
      } else {
        print('⚠️ User document not found');
        setState(() {
          _isLoadingServiceUnit = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching service unit: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoadingServiceUnit = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    print('📦 didChangeDependencies called');
    print('   - _handledInitialArgs: $_handledInitialArgs');

    if (!_handledInitialArgs) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      
      print('📦 Checking for route arguments...');
      print('   - args: $args');
      
      if (args != null) {
        print('📦 ✅ Received navigation arguments:');
        args.forEach((key, value) {
          print('     - $key: $value');
        });
        
        final initialTab = args['initialTab'] as int?;
        final escalationId = args['escalationId'] as String?;
        final conversationId = args['conversationId'] as String?;
        final autoOpen = args['autoOpen'] as bool? ?? false;

        print('📦 Processing arguments:');
        print('   - initialTab: $initialTab');
        print('   - escalationId: $escalationId');
        print('   - conversationId: $conversationId');
        print('   - autoOpen: $autoOpen');

        setState(() {
          if (initialTab != null) {
            _selectedIndex = initialTab;
            print('✅ Updated _selectedIndex to: $_selectedIndex');
          }
          
          if (escalationId != null) {
            _escalationId = escalationId;
            _conversationId = conversationId;
            _shouldAutoOpen = autoOpen;
            print('✅ Updated escalation details:');
            print('   - _escalationId: $_escalationId');
            print('   - _conversationId: $_conversationId');
            print('   - _shouldAutoOpen: $_shouldAutoOpen');
          }
        });

        print('📦 State updated successfully');
      } else {
        print('📦 ❌ No navigation arguments found');
      }
      
      _handledInitialArgs = true;
      print('📦 Set _handledInitialArgs to true');
    } else {
      print('📦 ⏭️ Skipping - already handled initial args');
    }
  }

  List<Widget> _getPages() {
    if (_isLoadingServiceUnit) {
      print('⏳ Service unit still loading...');
      return [
        const Center(child: CircularProgressIndicator()),
        const Center(child: CircularProgressIndicator()),
        const Center(child: CircularProgressIndicator()),
        const Center(child: CircularProgressIndicator()),
        const Center(child: CircularProgressIndicator()),
      ];
    }

    print('🏗️ Building pages:');
    print('   - _serviceUnit: "$_serviceUnit"');
    print('   - _selectedIndex: $_selectedIndex');
    print('   - _escalationId: $_escalationId');
    print('   - _shouldAutoOpen: $_shouldAutoOpen');
    print('   - Is on escalation tab (index 2): ${_selectedIndex == 2}');
    print('   - Will auto-open: ${_shouldAutoOpen && _selectedIndex == 2}');

    final humanEscalationWidget = HumanEscalation(
      key: ValueKey('escalation_${_escalationId}_${_shouldAutoOpen}'),
      initialEscalationId: _escalationId,
      autoOpen: _shouldAutoOpen && _selectedIndex == 2,
      serviceUnit: _serviceUnit,
    );

    print('✅ HumanEscalation widget created with:');
    print('   - key: escalation_${_escalationId}_${_shouldAutoOpen}');
    print('   - initialEscalationId: $_escalationId');
    print('   - autoOpen: ${_shouldAutoOpen && _selectedIndex == 2}');
    print('   - serviceUnit: "$_serviceUnit"');

    return [
      const StaffDashboardPage(),
      const StaffReportsPage(),
      humanEscalationWidget,
      const StaffAnnouncementPage(),
      const StaffMessageLogsPage(),
    ];
  }

  void _onNavigationItemTap(int index) {
    print('🔄 Navigation item tapped: $index');
    setState(() {
      _selectedIndex = index;
      
      if (index != 2) {
        print('🔄 Clearing escalation details (not on escalation tab)');
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
    print('🎨 Building StaffMainPage - selectedIndex: $_selectedIndex');
    
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