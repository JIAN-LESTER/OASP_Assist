import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:capstone_project/pages/admin_pages/widgets/custom_dropdown_button.dart';
import 'package:capstone_project/pages/admin_pages/widgets/refresh_button.dart';
import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/reports.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String selectedTimeFrame = 'This Month';
  final currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseService _firebaseService = FirebaseService();

  InquiryReportsData? inq;
  ChatbotUsageReportsData? cb;
  UserDemographicsReportsData? ud;
  String? userName;

  bool isLoading = true;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ✅ OPTIMIZED: Load all data in parallel
  Future<void> _loadAllData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final results = await Future.wait([
        _fetchUserName(),
        _firebaseService.getInquiryReportsData(selectedTimeFrame),
        _firebaseService.getChatbotUsageReportsData(selectedTimeFrame),
        _firebaseService.getUserDemographicsReportsData(selectedTimeFrame),
      ]);

      if (!mounted) return;

      setState(() {
        userName = results[0] as String?;
        inq = results[1] as InquiryReportsData;
        cb = results[2] as ChatbotUsageReportsData;
        ud = results[3] as UserDemographicsReportsData;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  //  OPTIMIZED: Refresh function for the refresh button

  Future<void> _refreshData() async {
    if (!mounted || isRefreshing) return;

    setState(() {
      isRefreshing = true;
    });

    try {
      final results = await Future.wait([
        _firebaseService.getInquiryReportsData(selectedTimeFrame),
        _firebaseService.getChatbotUsageReportsData(selectedTimeFrame),
        _firebaseService.getUserDemographicsReportsData(selectedTimeFrame),
      ]);

      if (!mounted) return;

      setState(() {
        inq = results[0] as InquiryReportsData;
        cb = results[1] as ChatbotUsageReportsData;
        ud = results[2] as UserDemographicsReportsData;
        isRefreshing = false;
      });

      // Show success feedback with responsive sizing
      if (mounted) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1100;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_outlined,
                  color: Colors.white,
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Flexible(
                  child: Text(
                    'Dashboard refreshed successfully',
                    style: TextStyle(
                      fontSize: isMobile ? 15 : (isTablet ? 16 : 17),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 14 : 16,
            ),
            margin: EdgeInsets.only(
              bottom: 20,
              right: 20,
              left: isMobile ? 20 : (screenWidth - (isTablet ? 380 : 420)),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            elevation: 6,
          ),
        );
      }
    } catch (e) {
      print('Error refreshing dashboard data: $e');
      if (!mounted) return;
      setState(() {
        isRefreshing = false;
      });

      // Show error feedback with responsive sizing
      if (mounted) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1100;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Flexible(
                  child: Text(
                    'Failed to refresh dashboard',
                    style: TextStyle(
                      fontSize: isMobile ? 15 : (isTablet ? 16 : 17),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red[600],
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 14 : 16,
            ),
            margin: EdgeInsets.only(
              bottom: 20,
              right: 20,
              left: isMobile ? 20 : (screenWidth - (isTablet ? 380 : 420)),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
            ),
            elevation: 6,
          ),
        );
      }
    }
  }

  Future<String?> _fetchUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'User';

    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      return userDoc.exists ? (userDoc.data()?['name'] ?? 'User') : 'User';
    } catch (e) {
      print('Error fetching user name: $e');
      return 'User';
    }
  }

  void _onTimeFrameChanged(String newValue) {
    setState(() {
      selectedTimeFrame = newValue;
    });
    _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || userName == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ResponsiveLayout(
      mobileBody: MobileDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        inq: inq,
        cb: cb,
        ud: ud,
        userName: userName!,
      ),
      tabletBody: TabletDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        inq: inq,
        cb: cb,
        ud: ud,
        userName: userName!,
      ),
      desktopBody: DesktopDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        inq: inq,
        cb: cb,
        ud: ud,
        userName: userName!,
      ),
    );
  }
}

// Desktop Dashboard
class DesktopDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final InquiryReportsData? inq;
  final ChatbotUsageReportsData? cb;
  final UserDemographicsReportsData? ud;
  final String userName;

  const DesktopDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    this.inq,
    this.cb,
    this.ud,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return dashboardContents(
      selectedTimeFrame,
      onTimeFrameChanged,
      onRefresh,
      isRefreshing,
      inq,
      cb,
      ud,
      userName,
    );
  }
}

// Tablet Dashboard
class TabletDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final InquiryReportsData? inq;
  final ChatbotUsageReportsData? cb;
  final UserDemographicsReportsData? ud;
  final String userName;

  const TabletDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    this.inq,
    this.cb,
    this.ud,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return dashboardContents(
      selectedTimeFrame,
      onTimeFrameChanged,
      onRefresh,
      isRefreshing,
      inq,
      cb,
      ud,
      userName,
    );
  }
}

// Mobile Dashboard
class MobileDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final InquiryReportsData? inq;
  final ChatbotUsageReportsData? cb;
  final UserDemographicsReportsData? ud;
  final String userName;

  const MobileDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    this.inq,
    this.cb,
    this.ud,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return dashboardContents(
      selectedTimeFrame,
      onTimeFrameChanged,
      onRefresh,
      isRefreshing,
      inq,
      cb,
      ud,
      userName,
    );
  }
}

Widget dashboardContents(
  final String selectedTimeFrame,
  final ValueChanged<String> onTimeFrameChanged,
  final VoidCallback onRefresh,
  final bool isRefreshing,
  final InquiryReportsData? inq,
  final ChatbotUsageReportsData? cb,
  final UserDemographicsReportsData? ud,
  final String userName,
) {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            selectedTimeFrame,
            onTimeFrameChanged,
            onRefresh,
            isRefreshing,
            userName,
          ),
          const SizedBox(height: 32),

          // Top row with 4 stat cards
          Row(
            children: [
              Expanded(
                child: buildStatCard(
                  'Total Messages',
                  '${inq?.totalMessages ?? 0}',
                  Colors.blue,
                  Icons.message,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: buildStatCard(
                  'Answered Messages',
                  '${inq?.answeredMessages ?? 0}',
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: buildStatCard(
                  'Total Users',
                  '${ud?.totalUsers ?? 0}',
                  Colors.red,
                  Icons.people,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: buildStatCard(
                  'Most Frequent Category',
                  inq?.mostFrequentCategory ?? 'Unknown',
                  Colors.orange,
                  Icons.help,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Second row with 2 larger boxes
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: buildCategoryDistributionCard(
                    inq?.categoryDistribution ?? {},
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: buildInquiryTrendCard(inq?.inquiryTrend ?? [])),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Bottom section - Recent System Logs
          Expanded(flex: 1, child: buildSystemLogsCard(inq?.recentLogs ?? [])),
        ],
      ),
    ),
  );
}

Widget _buildHeader(
  String selectedTimeFrame,
  ValueChanged<String> onTimeFrameChanged,
  VoidCallback onRefresh,
  bool isRefreshing,
  String userName,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $userName!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CustomDropdownButton(
                        items: [
                          'All',
                          'Today',
                          'This Week',
                          'This Month',
                          'This Year',
                        ],
                        initialValue: selectedTimeFrame,
                        onChanged: onTimeFrameChanged,
                      ),
                      const SizedBox(width: 12),
                      RefreshButton(
                        onRefresh: onRefresh,
                        isRefreshing: isRefreshing,
                      ),
                    ],
                  ),
                ],
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Welcome back, $userName!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Row(
                    children: [
                      CustomDropdownButton(
                        items: [
                          'All',
                          'Today',
                          'This Week',
                          'This Month',
                          'This Year',
                        ],
                        initialValue: selectedTimeFrame,
                        onChanged: onTimeFrameChanged,
                      ),
                      const SizedBox(width: 12),
                      RefreshButton(
                        onRefresh: onRefresh,
                        isRefreshing: isRefreshing,
                      ),
                    ],
                  ),
                ],
              ),
          SizedBox(height: isMobile ? 12 : 8),
          Text(
            "Here's an overview of recent student inquiries for $selectedTimeFrame.",
            style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey),
          ),
        ],
      );
    },
  );
}
