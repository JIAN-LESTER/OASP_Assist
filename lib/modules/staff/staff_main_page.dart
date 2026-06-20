import 'package:capstone_project/modules/staff/announcement/staff_announcement_page.dart';
import 'package:capstone_project/modules/staff/dashboard_and_reports/staff_reports_page.dart';
import 'package:capstone_project/modules/staff/dashboard_and_reports/staff_dashboard_page.dart';
import 'package:capstone_project/modules/staff/human_escalation/human_escalation.dart';
import 'package:capstone_project/modules/staff/logs/staff_message_logs.dart';
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
  bool _isNavigating = false;

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

    print(' StaffMainPage initState:');
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
        print(' No user logged in');
        setState(() {
          _isLoadingServiceUnit = false;
        });
        return;
      }

      print(' Fetching service unit for user: ${user.uid}');

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final fetchedServiceUnit = data?['serviceUnit'] as String?;

        print(' User document data: $data');
        print(' Service unit field: $fetchedServiceUnit');

        setState(() {
          _serviceUnit = fetchedServiceUnit ?? "";
          _isLoadingServiceUnit = false;
        });

        print(' Staff service unit loaded: "$_serviceUnit"');

        if (_serviceUnit.isEmpty) {
          print(' WARNING: Service unit is empty!');
        }
      } else {
        print(' User document not found');
        setState(() {
          _isLoadingServiceUnit = false;
        });
      }
    } catch (e, stackTrace) {
      print(' Error fetching service unit: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoadingServiceUnit = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    print(' didChangeDependencies called');
    print('   - _handledInitialArgs: $_handledInitialArgs');

    if (!_handledInitialArgs) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      print(' Checking for route arguments...');
      print('   - args: $args');

      if (args != null) {
        print('  Received navigation arguments:');
        args.forEach((key, value) {
          print('     - $key: $value');
        });

        final initialTab = args['initialTab'] as int?;
        final escalationId = args['escalationId'] as String?;
        final conversationId = args['conversationId'] as String?;
        final autoOpen = args['autoOpen'] as bool? ?? false;

        print(' Processing arguments:');
        print('   - initialTab: $initialTab');
        print('   - escalationId: $escalationId');
        print('   - conversationId: $conversationId');
        print('   - autoOpen: $autoOpen');

        setState(() {
          if (initialTab != null) {
            _selectedIndex = initialTab;
            print(' Updated _selectedIndex to: $_selectedIndex');
          }

          if (escalationId != null) {
            _escalationId = escalationId;
            _conversationId = conversationId;
            _shouldAutoOpen = autoOpen;
            print(' Updated escalation details:');
            print('   - _escalationId: $_escalationId');
            print('   - _conversationId: $_conversationId');
            print('   - _shouldAutoOpen: $_shouldAutoOpen');
          }
        });

        print(' State updated successfully');
      } else {
        print('  No navigation arguments found');
      }

      _handledInitialArgs = true;
      print(' Set _handledInitialArgs to true');
    } else {
      print('  Skipping - already handled initial args');
    }
  }

  List<Widget> _getPages() {
    if (_isLoadingServiceUnit) {
      print(' Service unit still loading...');
      return [
        StaffDashboardPage(),
        const StaffReportsPage(),
        const _HumanEscalationPageSkeleton(),
        const StaffAnnouncementPage(),
        const StaffMessageLogsPage(),
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

    print(' HumanEscalation widget created with:');
    print('   - key: escalation_${_escalationId}_${_shouldAutoOpen}');
    print('   - initialEscalationId: $_escalationId');
    print('   - autoOpen: ${_shouldAutoOpen && _selectedIndex == 2}');
    print('   - serviceUnit: "$_serviceUnit"');

    return [
      StaffDashboardPage(),
      const StaffReportsPage(),
      humanEscalationWidget,
      const StaffAnnouncementPage(),
      const StaffMessageLogsPage(),
    ];
  }

  Future<void> _onNavigationItemTap(int index) async {
    print(' Navigation item tapped: $index');
    if (!mounted ||
        _isNavigating ||
        index == _selectedIndex ||
        index < 0 ||
        index >= _pageTitles.length) {
      return;
    }

    setState(() {
      _isNavigating = true;
    });

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    setState(() {
      _selectedIndex = index;

      if (index != 2) {
        print(' Clearing escalation details (not on escalation tab)');
        _escalationId = null;
        _conversationId = null;
        _shouldAutoOpen = false;
      }
    });

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    setState(() {
      _isNavigating = false;
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
      body: Stack(
        children: [
          _getPages()[_selectedIndex],
        ],
      ),
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
          Expanded(
            child: Stack(
              children: [
                _getPages()[_selectedIndex],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HumanEscalationPageSkeleton extends StatelessWidget {
  const _HumanEscalationPageSkeleton();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 900;
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);
    final verticalPadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

    return Container(
      color: const Color(0xFFF0F4F8),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              verticalPadding,
              horizontalPadding,
              isTablet ? 12 : 8,
            ),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    const _MainSkeletonBox(width: 150, height: 24),
                    const Spacer(),
                    _MainSkeletonBox(
                      width: isTablet ? 44 : 38,
                      height: isTablet ? 44 : 38,
                      radius: 10,
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 24 : 16),
                const _MainSkeletonBox(width: double.infinity, height: 48),
                SizedBox(height: isTablet ? 12 : 8),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      const Expanded(
                        child: _MainSkeletonBox(height: 64, radius: 12),
                      ),
                      if (i != 2) SizedBox(width: isTablet ? 10 : 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(horizontalPadding),
              itemCount: 6,
              separatorBuilder: (_, __) => SizedBox(height: isTablet ? 12 : 10),
              itemBuilder:
                  (_, __) => Container(
                    padding: EdgeInsets.all(isTablet ? 14 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                    ),
                    child: Row(
                      children: [
                        _MainSkeletonBox(
                          width: isTablet ? 44 : 38,
                          height: isTablet ? 44 : 38,
                          radius: 12,
                        ),
                        SizedBox(width: isTablet ? 14 : 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MainSkeletonBox(
                                width: double.infinity,
                                height: 14,
                              ),
                              SizedBox(height: 8),
                              _MainSkeletonBox(width: 180, height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _MainSkeletonBox({
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
