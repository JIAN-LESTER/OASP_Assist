
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/admin_dashboard_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/charts.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/export_button.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/inquiry_trends_charts.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/inquiry_trends_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/paginated_list.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/reports.dart';
import 'package:capstone_project/modules/admin_module/widgets/custom_dropdown_button.dart';
import 'package:capstone_project/modules/admin_module/widgets/date_range_filter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

class StaffReportsPage extends StatefulWidget {
  const StaffReportsPage({super.key});

  @override
  State<StaffReportsPage> createState() => _StaffReportsPageState();
}

class _StaffReportsPageState extends State<StaffReportsPage> {
  String selectedTimeFrame = 'This Month';
  final currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseService _firebaseService = FirebaseService();

  InquiryReportsData? inq;
  AdminDashboardData? ad;
  String? userName;

  // ✅ ADD THESE MISSING VARIABLES
  DateTimeRange? customDateRange;

  bool isLoadingUser = true;
  bool isLoadingInquiry = false;
  bool isRefreshing = false;

  DateTime startDate = DateTime.now();
  String timeFrame = "This Month";
  final timeCategoryCounts = <String, Map<String, int>>{};

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadInquiryData();
  }

  Future<void> _loadUserName() async {
    if (!mounted) return;

    final name = await _fetchUserName();
    if (!mounted) return;

    setState(() {
      userName = name;
      isLoadingUser = false;
    });
  }

  Future<void> _loadInquiryData() async {
  if (!mounted) return;

  setState(() => isLoadingInquiry = true);
  try {
    // ✅ Pass customDateRange to both fetchers
    final results = await Future.wait([
      _firebaseService.getInquiryReportsData(
        selectedTimeFrame,
        customDateRange, // ✅ ADD THIS
      ),
      _firebaseService.getAdminDashboardData(
        selectedTimeFrame,
        customDateRange, // ✅ ADD THIS
      ),
    ]);

    if (!mounted) return;
    
    setState(() {
      inq = results[0] as InquiryReportsData;
      ad = results[1] as AdminDashboardData;
      isLoadingInquiry = false;
    });

    print('📊 Staff Reports Data Loaded:');
    print('   Inquiry Data: ${inq?.totalMessages ?? 0} messages');
    print('   Admin Data: ${ad?.topEscalatedMessages.length ?? 0} escalations');
    
  } catch (e) {
    print('❌ Error loading inquiry data: $e');
    if (!mounted) return;
    setState(() => isLoadingInquiry = false);
  }
}

void _onTimeFrameChanged(String newValue) {
  // If Custom is selected, just update the UI to show the DateRangeFilter
  if (newValue == 'Custom') {
    if (mounted) {
      setState(() {
        selectedTimeFrame = 'Custom';
        // Keep existing customDateRange if any
      });
    }
    // Don't load data yet - wait for user to select a date range
    return;
  }

  // Normal timeframe selection
  setState(() {
    selectedTimeFrame = newValue;
    customDateRange = null; // Clear custom range when selecting preset
  });
  
  _loadInquiryData();
}

void _onDateRangeChanged(DateTimeRange? range) {
  if (range == null) {
    // User cleared the date range, revert to "This Month"
    setState(() {
      customDateRange = null;
      selectedTimeFrame = 'This Month';
    });
  } else {
    // User selected a custom date range
    setState(() {
      customDateRange = range;
      selectedTimeFrame = 'Custom';
    });
  }

  _loadInquiryData();
}

  Future<void> _refreshData() async {
    if (!mounted || isRefreshing) return;

    setState(() => isRefreshing = true);

    try {
      final data = await _firebaseService.getInquiryReportsData(
        selectedTimeFrame,
      );
      if (!mounted) return;
      setState(() {
        inq = data;
        isRefreshing = false;
      });

      if (mounted) {
        _showSnackBar(
          message: 'Reports refreshed successfully',
          isError: false,
        );
      }
    } catch (e) {
      print('Error refreshing reports data: $e');
      if (!mounted) return;
      setState(() => isRefreshing = false);

      if (mounted) {
        _showSnackBar(message: 'Failed to refresh reports', isError: true);
      }
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : Icons.check_circle_outline_outlined,
              color: Colors.white,
              size: isMobile ? 20 : 24,
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Flexible(
              child: Text(
                message,
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
        backgroundColor: isError ? Colors.red[600] : null,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 14 : 16,
        ),
        margin: EdgeInsets.only(
          bottom: 20,
          right: 20,
          left: isMobile ? 20 : (screenWidth - (isTablet ? 380 : 420)),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 6,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (isLoadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ResponsiveLayout(
      mobileBody: MobileDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        isLoading: isLoadingInquiry,
        inq: inq,
        ad: ad,
        userName: userName!,
        startDate: startDate,
        timeCategoryCounts: timeCategoryCounts,
        timeFrame: timeFrame,
                customDateRange: customDateRange,
        onDateRangeChanged: _onDateRangeChanged,
      ),
      tabletBody: TabletDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        isLoading: isLoadingInquiry,
        inq: inq,
        ad: ad,
        userName: userName!,
        startDate: startDate,
        timeCategoryCounts: timeCategoryCounts,
        timeFrame: timeFrame,
                customDateRange: customDateRange,
        onDateRangeChanged: _onDateRangeChanged,
      ),
      desktopBody: DesktopDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        isLoading: isLoadingInquiry,
        inq: inq,
        ad: ad,
        userName: userName!,
        startDate: startDate,
        timeCategoryCounts: timeCategoryCounts,
        timeFrame: timeFrame,
                customDateRange: customDateRange,
        onDateRangeChanged: _onDateRangeChanged,
      ),
    );
  }
}

// Skeleton Loader Widget
class SkeletonLoader extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
              stops:
                  [
                    _animation.value - 0.3,
                    _animation.value,
                    _animation.value + 0.3,
                  ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

// Skeleton for Stat Cards
Widget buildStatCardSkeleton({bool isMobile = false}) {
  return Container(
    padding: EdgeInsets.all(isMobile ? 12 : 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 4,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonLoader(
              height: isMobile ? 14 : 16,
              width: isMobile ? 80 : 100,
            ),
            SkeletonLoader(
              height: isMobile ? 24 : 32,
              width: isMobile ? 24 : 32,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SkeletonLoader(height: isMobile ? 24 : 32, width: isMobile ? 60 : 80),
      ],
    ),
  );
}

// Skeleton for Chart Cards
Widget buildChartCardSkeleton({bool isMobile = false}) {
  return Container(
    padding: EdgeInsets.all(isMobile ? 12 : 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 4,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonLoader(height: isMobile ? 18 : 20, width: isMobile ? 120 : 150),
        const SizedBox(height: 16),
        Expanded(
          child: SkeletonLoader(
            height: double.infinity,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    ),
  );
}

class DesktopDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool isLoading;
  final InquiryReportsData? inq;
  final AdminDashboardData? ad;
  final String userName;
  final DateTime startDate;
  final String timeFrame;
  final Map<String, Map<String, int>> timeCategoryCounts;
    final DateTimeRange? customDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  const DesktopDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.isLoading,
    this.inq,
    this.ad,
    required this.userName,
    required this.startDate,
    required this.timeCategoryCounts,
    required this.timeFrame,
    required this.customDateRange,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
  padding: const EdgeInsets.all(24.0),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: EdgeInsets.all( 20),
        child: buildHeader(
          selectedTimeFrame,
          onTimeFrameChanged,
          onRefresh,
          isRefreshing,
          userName,
          customDateRange,
          onDateRangeChanged,
          inq,
          ad,
        ),
      ),
      const SizedBox(height: 32),
      if (isLoading)
        ...buildSkeletonReport(isMobile: false)
      else
        ...buildInquiryTrendsReport(
          inq,
          ad,
          selectedTimeFrame: selectedTimeFrame,
          isMobile: false,
          context: context,
        ),
    ],
  ),
),
    );
  }
}

class TabletDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool isLoading;
  final InquiryReportsData? inq;
  final AdminDashboardData? ad;
  final String userName;
  final DateTime startDate;
  final String timeFrame;
  final Map<String, Map<String, int>> timeCategoryCounts;
    final DateTimeRange? customDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  const TabletDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.isLoading,
    this.inq,
    this.ad,
    required this.startDate,
    required this.timeCategoryCounts,
    required this.timeFrame,
    required this.userName,
    required this.customDateRange,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildHeader(
              selectedTimeFrame,
              onTimeFrameChanged,
              onRefresh,
              isRefreshing,
              userName,
                         customDateRange,
              onDateRangeChanged,
              inq, 
              ad, 
   
              
            ),
            const SizedBox(height: 32),

            if (isLoading)
              ...buildSkeletonReport(isMobile: false)
            else
              ...buildInquiryTrendsReport(
                inq,
                ad,
                selectedTimeFrame: selectedTimeFrame,
                isMobile: false,
                context: context,
              ),
          ],
        ),
      ),
    );
  }
}

class MobileDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool isLoading;
  final InquiryReportsData? inq;
  final AdminDashboardData? ad;
  final String userName;

  final DateTime startDate;
  final String timeFrame;
  final Map<String, Map<String, int>> timeCategoryCounts;
    final DateTimeRange? customDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  const MobileDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.isLoading,
    this.inq,
    this.ad,
    required this.userName,
    required this.startDate,
    required this.timeCategoryCounts,
    required this.timeFrame,
    required this.customDateRange,
    required this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildHeader(
              selectedTimeFrame,
              onTimeFrameChanged,
              onRefresh,
              isRefreshing,
              userName,
              customDateRange,
              onDateRangeChanged,
              inq,
              ad,
            ),
            const SizedBox(height: 24),

            if (isLoading)
              ...buildSkeletonReport(isMobile: true)
            else
              ...buildInquiryTrendsReport(
                inq,
                ad,
                selectedTimeFrame: selectedTimeFrame,
                isMobile: true,
                context: context,
              ),
          ],
        ),
      ),
    );
  }
}

List<Widget> buildSkeletonReport({bool isMobile = false}) {
  if (isMobile) {
    return [
      Row(
        children: [
          Expanded(child: buildStatCardSkeleton(isMobile: true)),
          const SizedBox(width: 12),
          Expanded(child: buildStatCardSkeleton(isMobile: true)),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: buildStatCardSkeleton(isMobile: true)),
          const SizedBox(width: 12),
          Expanded(child: buildStatCardSkeleton(isMobile: true)),
        ],
      ),
      const SizedBox(height: 24),
      SizedBox(height: 400, child: buildChartCardSkeleton(isMobile: true)),
      const SizedBox(height: 16),
      SizedBox(height: 400, child: buildChartCardSkeleton(isMobile: true)),
      const SizedBox(height: 16),
      SizedBox(height: 400, child: buildChartCardSkeleton(isMobile: true)),
    ];
  }

  return [
    SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(child: buildStatCardSkeleton()),
          const SizedBox(width: 20),
          Expanded(child: buildStatCardSkeleton()),
          const SizedBox(width: 20),
          Expanded(child: buildStatCardSkeleton()),
          const SizedBox(width: 20),
          Expanded(child: buildStatCardSkeleton()),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(height: 400, child: buildChartCardSkeleton()),
    const SizedBox(height: 16),
    SizedBox(height: 400, child: buildChartCardSkeleton()),
  ];
}

List<Widget> buildInquiryTrendsReport(
  InquiryReportsData? data,
  AdminDashboardData? ad, {
  String? selectedTimeFrame,
  bool isMobile = false,
  required BuildContext context,
}) {
  // Provide default values for all required fields
  final userMessages = data?.userMessages ?? 0;
  final botMessages = data?.botMessages ?? 0;
  final escalatedMessages = data?.escalatedMessages ?? 0;
  final resolvedMessages = data?.resolvedMessages ?? 0;
  final escalationRate = data?.escalationRate ?? 0.0;
  final resolutionRate = data?.resolutionRate ?? 0.0;

  if (isMobile) {
    return [
      Row(
        children: [
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'User Messages',
                    '$userMessages',
                    Colors.blue,
                    Icons.message,
                    onTap:
                        () => _showMessagesDialog(
                          context,
                          selectedTimeFrame ?? 'This Month',
                        ),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'Bot Messages',
                    '$botMessages',
                    Colors.green,
                    Icons.check_circle,
                    onTap:
                        () => _showAnsweredMessagesDialog(
                          context,
                          selectedTimeFrame ?? 'This Month',
                        ),
                  ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'Pending Escalated Messages',
                    '$escalatedMessages',
                    Colors.red,
                    Icons.warning_amber_rounded,
                    onTap:
                        () => _showEscalatedMessagesDialog(
                          context,
                          selectedTimeFrame ?? 'This Month',
                        ),
                    rateLabel: 'Rate',
                    rateValue: escalationRate,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'Resolved Messages',
                    '$resolvedMessages',
                    Colors.orange,
                    Icons.check_circle_outline,
                    onTap:
                        () => _showResolvedMessagesDialog(
                          context,
                          selectedTimeFrame ?? 'This Month',
                        ),
                    rateLabel: 'Rate',
                    rateValue: resolutionRate.remainder(1),
                  ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 400,
        child: buildInquiryTrendCard(
          data?.inquiryTrend ?? [],
          selectedTimeFrame ?? 'This Month',
          context,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildCategoryDistributionCard(
          data?.categoryDistribution ?? {},
          selectedTimeFrame ?? 'This Month',
          context,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildHighestFAQCard(data?.topQuestions ?? {}),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildEscalationsOverTimeCard(
          data?.escalationsOverTime ?? [],
          selectedTimeFrame ?? 'This Month',
          context,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildStaffPerformanceCard(
          data?.staffPerformance ?? {},
          selectedTimeFrame ?? 'This Month',
          context,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildEscalatedMessagesList(
          ad?.topEscalatedMessages ?? [],
          selectedTimeFrame ?? 'This Month',
          context,
        ),
      ),
    ];
  }

  // Desktop layout
return [
  SizedBox(
    height: 120,
    child: Row(
      children: [
        Expanded(
          child: Builder(
            builder: (context) => buildStatCard(
              'User Messages',  // Clean title
              '$userMessages',
              Colors.blue,
              Icons.message,
              onTap: () => _showMessagesDialog(
                context,
                selectedTimeFrame ?? 'This Month',
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Builder(
            builder: (context) => buildStatCard(
              'Bot Messages',  // Clean title
              '$botMessages',
              Colors.green,
              Icons.check_circle,
              onTap: () => _showAnsweredMessagesDialog(
                context,
                selectedTimeFrame ?? 'This Month',
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Builder(
            builder: (context) => buildStatCard(
              'Pending Escalated Messages',  // ✅ FIXED: Clean title, rate shown separately
              '$escalatedMessages',
              Colors.red,
              Icons.warning_amber_rounded,
              onTap: () => _showEscalatedMessagesDialog(
                context,
                selectedTimeFrame ?? 'This Month',
              ),
              rateLabel: 'Rate',     // ✅ FIXED: Pass rate as parameter
              rateValue: escalationRate,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Builder(
            builder: (context) => buildStatCard(
              'Resolved Messages',  // ✅ FIXED: Clean title, rate shown separately
              '$resolvedMessages',
              Colors.orange,
              Icons.check_circle_outline,
              onTap: () => _showResolvedMessagesDialog(
                context,
                selectedTimeFrame ?? 'This Month',
              ),
              rateLabel: 'Rate',     
              rateValue: resolutionRate,
            ),
          ),
        ),
      ],
    ),
  ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            child: buildInquiryTrendCard(
              data?.inquiryTrend ?? [],
              selectedTimeFrame ?? 'This Month',
              context,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 350,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: buildCategoryDistributionCard(
              data?.categoryDistribution ?? {},
              selectedTimeFrame ?? 'This Month',
              context,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: buildHighestFAQCard(data?.topQuestions ?? {}),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            child: buildEscalationsOverTimeCard(
              data?.escalationsOverTime ?? [],
              selectedTimeFrame ?? 'This Month',
              context,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 350,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: buildStaffPerformanceCard(
              data?.staffPerformance ?? {},
              selectedTimeFrame ?? 'This Month',
              context,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 1,
            child: buildEscalatedMessagesList(
              ad?.topEscalatedMessages ?? [],
              selectedTimeFrame ?? 'This Month',
              context,
            ),
          ),
        ],
      ),
    ),
  ];
}

Widget buildHeader(
  String selectedTimeFrame,
  ValueChanged<String> onTimeFrameChanged,
  VoidCallback onRefresh,
  bool isRefreshing,
  String userName,
  DateTimeRange? customDateRange,
  ValueChanged<DateTimeRange?> onDateRangeChanged,
  InquiryReportsData? inq,
  AdminDashboardData? ad,
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
                  const Text(
                    'Inquiry Trends Report',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CustomDropdownButton(
                          items: [
                            'All',
                            'Today',
                            'This Week',
                            'This Month',
                            'This Year',
                            'Custom',
                          ],
                          initialValue: selectedTimeFrame,
                          onChanged: onTimeFrameChanged,
                        ),
                      ),
                      if (selectedTimeFrame == 'Custom') ...[
                        const SizedBox(width: 8),
                        DateRangeFilter(
                          selectedDateRange: customDateRange,
                          onDateRangeChanged: onDateRangeChanged,
                        ),
                      ],
                      const SizedBox(width: 8),
                      ExportButton(
                        pageType: 'inquiry',
                        timeFrame: selectedTimeFrame,
                        userName: userName,
                        inq: inq,
                        ad: ad,
                      ),
                    ],
                  ),
                ],
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Inquiry Trends Report',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                          'Custom',
                        ],
                        initialValue: selectedTimeFrame,
                        onChanged: onTimeFrameChanged,
                      ),
                      if (selectedTimeFrame == 'Custom') ...[
                        const SizedBox(width: 12),
                        DateRangeFilter(
                          selectedDateRange: customDateRange,
                          onDateRangeChanged: onDateRangeChanged,
                        ),
                      ],
                      const SizedBox(width: 12),
                      ExportButton(
                        pageType: 'inquiry',
                        timeFrame: selectedTimeFrame,
                        userName: userName,
                        inq: inq,
                        ad: ad,
                      ),
                    ],
                  ),
                ],
              ),
          SizedBox(height: isMobile ? 12 : 8),
          Text(
            _getReportDescription(selectedTimeFrame, customDateRange),
            style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey),
          ),
        ],
      );
    },
  );
}

String _getReportDescription(
  String timeFrame,
  DateTimeRange? customDateRange,
) {
  if (timeFrame == 'Custom' && customDateRange != null) {
    return 'Detailed analysis of inquiry patterns and trends from ${_formatDate(customDateRange.start)} to ${_formatDate(customDateRange.end)}.';
  }

  return 'Detailed analysis of inquiry patterns and trends for $timeFrame.';
}


String _formatDate(DateTime date) {
  const months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month]} ${date.year}';
}

String _formatTimestamp(Timestamp timestamp) {
  final date = timestamp.toDate();
  return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}

DateTime _getStartDateForDialog(
  String timeFrame, [
  DateTimeRange? customRange,
]) {
  if (timeFrame == 'Custom' && customRange != null) {
    return DateTime(
      customRange.start.year,
      customRange.start.month,
      customRange.start.day,
      0,
      0,
      0,
    );
  }

  final now = DateTime.now();
  return switch (timeFrame) {
    'All' => DateTime(2000, 1, 1),
    'Today' => DateTime(now.year, now.month, now.day),
    'This Week' => now.subtract(Duration(days: now.weekday - 1)),
    'This Month' => DateTime(now.year, now.month, 1),
    'This Year' => DateTime(now.year, 1, 1),
    _ => DateTime(now.year, now.month, 1),
  };
}

DateTime? _getEndDateForDialog(String timeFrame, [DateTimeRange? customRange]) {
  if (timeFrame == 'Custom' && customRange != null) {
    return DateTime(
      customRange.end.year,
      customRange.end.month,
      customRange.end.day,
      23,
      59,
      59,
      999,
    );
  }
  return null;
}


void _showMessagesDialog(
  BuildContext context,
  String timeFrame, [
  DateTimeRange? customRange,
]) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Total Messages',
          headerColor: Colors.blue,
          dataFetcher: (page, pageSize) async {
            final startDate = _getStartDateForDialog(timeFrame, customRange);
            final endDate = _getEndDateForDialog(timeFrame, customRange);

            Query query = FirebaseFirestore.instance
                .collectionGroup('messages')
                .where('sender', isEqualTo: 'user')
                .where('sent_at', isGreaterThanOrEqualTo: startDate);

            if (endDate != null) {
              query = query.where('sent_at', isLessThanOrEqualTo: endDate);
            }

            final snapshot =
                await query
                    .orderBy('sent_at', descending: true)
                    .limit(pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final timestamp = data?['sent_at'] as Timestamp?;
              return {
                'Message': data?['text'] ?? 'N/A',
                'Category': data?['category'] ?? 'General',
                'Date': timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}


void _showEscalatedMessagesDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Escalated Messages',
          headerColor: Colors.red,
          dataFetcher: (page, pageSize) async {
            final snapshot =
                await FirebaseFirestore.instance
                    .collection('escalations')
                    .orderBy('createdAt', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['createdAt'] as Timestamp?;
              return {
                'Message': data['content'] ?? 'N/A',
                'User': data['name'] ?? 'N/A',
                'Status': data['status'] ?? 'N/A',
                'Date': timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}


void _showResolvedMessagesDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Resolved Escalated Messages',
          headerColor: Colors.orange,
          dataFetcher: (page, pageSize) async {
            final snapshot =
                await FirebaseFirestore.instance
                    .collection('escalations')
                    .where('status', isEqualTo: 'resolved')
                    .orderBy('resolvedAt', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['resolvedAt'] as Timestamp?;
              return {
                'Message': data['question'] ?? 'N/A',
                'User': data['userId']['name'] ?? 'N/A',
                'Resolved By': data['resolvedBy'] ?? 'N/A',
                'Date': timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}

void _showAnsweredMessagesDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Answered Messages',
          headerColor: Colors.green,
          dataFetcher: (page, pageSize) async {
            final startDate = _getStartDateForDialog(timeFrame);
            final snapshot =
                await FirebaseFirestore.instance
                    .collectionGroup('messages')
                    .where('sender', isEqualTo: 'user')
                    .where('isAnswered', isEqualTo: true)
                    .where('sent_at', isGreaterThanOrEqualTo: startDate)
                    .orderBy('sent_at', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['sent_at'] as Timestamp?;
              return {
                'Message': data['content'] ?? 'N/A',
                'Category': data['category'] ?? 'General',
                'Date': timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}