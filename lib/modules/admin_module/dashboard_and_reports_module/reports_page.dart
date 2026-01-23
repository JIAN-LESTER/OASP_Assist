import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/admin_dashboard_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/export_button.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/paginated_list.dart';
import 'package:capstone_project/modules/admin_module/widgets/custom_dropdown_button.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/charts.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/chatbot_usage_charts.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/chatbot_usage_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/inquiry_trends_charts.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/inquiry_trends_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/reports.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/user_demographics_charts.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/user_demographics_data.dart';
import 'package:capstone_project/modules/admin_module/widgets/date_range_filter.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String selectedTimeFrame = 'This Month';
  String selectedReportType = 'Inquiry Trends';
  final currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseService _firebaseService = FirebaseService();

  // Separate data for each report type
  InquiryReportsData? inq;
  ChatbotUsageReportsData? cb;
  UserDemographicsReportsData? ud;
  AdminDashboardData? ad;
  String? userName;

  DateTimeRange? customDateRange;
  bool showDateRangePicker = false;

  // Separate loading states for each report type
  bool isLoadingUser = true;
  bool isLoadingInquiry = false;
  bool isLoadingChatbot = false;
  bool isLoadingDemographics = false;
  bool isRefreshing = false;

  // Track which data has been loaded
  bool inquiryDataLoaded = false;
  bool chatbotDataLoaded = false;
  bool demographicsDataLoaded = false;

  DateTime startDate = DateTime.now();
  String timeFrame = "This Month";
  final timeCategoryCounts = <String, Map<String, int>>{};

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadDataForSelectedReport();
  }

  // ✅ Load user name first (always needed)
  Future<void> _loadUserName() async {
    if (!mounted) return;

    final name = await _fetchUserName();
    if (!mounted) return;

    setState(() {
      userName = name;
      isLoadingUser = false;
    });
  }

  // ✅ LAZY LOADING: Only load data for the selected report type
  Future<void> _loadDataForSelectedReport() async {
    if (!mounted) return;

    switch (selectedReportType) {
      case 'Inquiry Trends':
        if (!inquiryDataLoaded) {
          setState(() => isLoadingInquiry = true);
          try {
            final data = await _firebaseService.getInquiryReportsData(
              selectedTimeFrame,
              customDateRange, // Pass custom date range
            );

            final escalatedData = await _firebaseService.getAdminDashboardData(
              selectedTimeFrame,
              customDateRange,
            );
            if (!mounted) return;
            setState(() {
              inq = data;
              ad = escalatedData;
              isLoadingInquiry = false;
              inquiryDataLoaded = true;
            });
          } catch (e) {
            print('Error loading inquiry data: $e');
            if (!mounted) return;
            setState(() => isLoadingInquiry = false);
          }
        }
        break;

      case 'Chatbot Usage':
        if (!chatbotDataLoaded) {
          setState(() => isLoadingChatbot = true);
          try {
            final data = await _firebaseService.getChatbotUsageReportsData(
              selectedTimeFrame,
              customDateRange, // Pass custom date range
            );
            if (!mounted) return;
            setState(() {
              cb = data;
              isLoadingChatbot = false;
              chatbotDataLoaded = true;
            });
          } catch (e) {
            print('Error loading chatbot data: $e');
            if (!mounted) return;
            setState(() => isLoadingChatbot = false);
          }
        }
        break;

      case 'User Demographics':
        if (!demographicsDataLoaded) {
          setState(() => isLoadingDemographics = true);
          try {
            final data = await _firebaseService.getUserDemographicsReportsData(
              selectedTimeFrame,
              customDateRange, // Pass custom date range
            );
            if (!mounted) return;
            setState(() {
              ud = data;
              isLoadingDemographics = false;
              demographicsDataLoaded = true;
            });
          } catch (e) {
            print('Error loading demographics data: $e');
            if (!mounted) return;
            setState(() => isLoadingDemographics = false);
          }
        }
        break;
    }
  }

  // ✅ When report type changes, load only that data
  void _onReportTypeChanged(String newValue) {
    setState(() {
      selectedReportType = newValue;
    });
    _loadDataForSelectedReport();
  }

  // ✅ When timeframe changes, invalidate and reload current report
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

    setState(() {
      selectedTimeFrame = newValue;
      customDateRange = null; // Clear custom range

      // Invalidate loaded data flags to force reload
      switch (selectedReportType) {
        case 'Inquiry Trends':
          inquiryDataLoaded = false;
          break;
        case 'Chatbot Usage':
          chatbotDataLoaded = false;
          break;
        case 'User Demographics':
          demographicsDataLoaded = false;
          break;
      }
    });
    _loadDataForSelectedReport();
  }

  // Add this new method to handle date range changes:
  void _onDateRangeChanged(DateTimeRange? range) {
    if (range == null) {
      // User cleared the date range, revert to "This Month"
      setState(() {
        customDateRange = null;
        selectedTimeFrame = 'This Month';

        // Invalidate current report data
        switch (selectedReportType) {
          case 'Inquiry Trends':
            inquiryDataLoaded = false;
            break;
          case 'Chatbot Usage':
            chatbotDataLoaded = false;
            break;
          case 'User Demographics':
            demographicsDataLoaded = false;
            break;
        }
      });
    } else {
      // User selected a custom date range
      setState(() {
        customDateRange = range;
        selectedTimeFrame = 'Custom';

        // Invalidate current report data
        switch (selectedReportType) {
          case 'Inquiry Trends':
            inquiryDataLoaded = false;
            break;
          case 'Chatbot Usage':
            chatbotDataLoaded = false;
            break;
          case 'User Demographics':
            demographicsDataLoaded = false;
            break;
        }
      });
    }

    _loadDataForSelectedReport();
  }

  // ✅ Refresh only the currently visible report
  Future<void> _refreshData() async {
    if (!mounted || isRefreshing) return;

    setState(() => isRefreshing = true);

    try {
      // Only refresh the selected report type
      switch (selectedReportType) {
        case 'Inquiry Trends':
          final data = await _firebaseService.getInquiryReportsData(
            selectedTimeFrame,
            customDateRange, // Pass custom date range
          );
          if (!mounted) return;
          setState(() {
            inq = data;
            isRefreshing = false;
          });
          break;

        case 'Chatbot Usage':
          final data = await _firebaseService.getChatbotUsageReportsData(
            selectedTimeFrame,
            customDateRange, // Pass custom date range
          );
          if (!mounted) return;
          setState(() {
            cb = data;
            isRefreshing = false;
          });
          break;

        case 'User Demographics':
          final data = await _firebaseService.getUserDemographicsReportsData(
            selectedTimeFrame,
            customDateRange, // Pass custom date range
          );
          if (!mounted) return;
          setState(() {
            ud = data;
            isRefreshing = false;
          });
          break;
      }

      // Show success feedback
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

  // ✅ Check if current report is loading
  bool get isCurrentReportLoading {
    switch (selectedReportType) {
      case 'Inquiry Trends':
        return isLoadingInquiry;
      case 'Chatbot Usage':
        return isLoadingChatbot;
      case 'User Demographics':
        return isLoadingDemographics;
      default:
        return false;
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
        selectedReportType: selectedReportType,
        onTimeFrameChanged: _onTimeFrameChanged,
        onReportTypeChanged: _onReportTypeChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        isLoading: isCurrentReportLoading,
        inq: inq,
        cb: cb,
        ud: ud,
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
        selectedReportType: selectedReportType,
        onTimeFrameChanged: _onTimeFrameChanged,
        onReportTypeChanged: _onReportTypeChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        isLoading: isCurrentReportLoading,
        inq: inq,
        cb: cb,
        ud: ud,
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
        selectedReportType: selectedReportType,
        onTimeFrameChanged: _onTimeFrameChanged,
        onReportTypeChanged: _onReportTypeChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        isLoading: isCurrentReportLoading,
        inq: inq,
        cb: cb,
        ud: ud,
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

// ✅ Skeleton Loader Widget
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

// ✅ Skeleton for Stat Cards
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

// ✅ Skeleton for Chart Cards
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

// Updated widget signatures to include isLoading
class DesktopDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final String selectedReportType;
  final ValueChanged<String> onTimeFrameChanged;
  final ValueChanged<String> onReportTypeChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool isLoading;
  final InquiryReportsData? inq;
  final ChatbotUsageReportsData? cb;
  final UserDemographicsReportsData? ud;
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
    required this.selectedReportType,
    required this.onTimeFrameChanged,
    required this.onReportTypeChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.isLoading,
    this.inq,
    this.cb,
    this.ud,
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
            buildHeader(
              selectedTimeFrame,
              selectedReportType,
              onTimeFrameChanged,
              onReportTypeChanged,
              onRefresh,
              isRefreshing,
              userName,
              customDateRange,
              onDateRangeChanged,
                    inq,
              cb,
              ud,
              ad,
            ),
            const SizedBox(height: 32),

            if (isLoading)
              ...buildSkeletonReport(selectedReportType, isMobile: false)
            else
              ...ReportsHelper.buildReportContent(
                selectedReportType,
                inq,
                ad,
                cb,
                selectedTimeFrame,
                ud,
                startDate,
                timeFrame,
                timeCategoryCounts,
                customDateRange,
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
  final String selectedReportType;
  final ValueChanged<String> onTimeFrameChanged;
  final ValueChanged<String> onReportTypeChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool isLoading;
  final InquiryReportsData? inq;
  final ChatbotUsageReportsData? cb;
  final UserDemographicsReportsData? ud;
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
    required this.selectedReportType,
    required this.onTimeFrameChanged,
    required this.onReportTypeChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.isLoading,
    this.inq,
    this.cb,
    this.ud,
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
              selectedReportType,
              onTimeFrameChanged,
              onReportTypeChanged,
              onRefresh,
              isRefreshing,
              userName,
              customDateRange,
              onDateRangeChanged,
              inq,
              cb,
              ud,
              ad,
            ),
            const SizedBox(height: 32),

            if (isLoading)
              ...buildSkeletonReport(selectedReportType, isMobile: false)
            else
              ...ReportsHelper.buildReportContent(
                selectedReportType,
                inq,
                ad,
                cb,
                selectedTimeFrame,
                ud,
                startDate,
                timeFrame,
                timeCategoryCounts,
                customDateRange,
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
  final String selectedReportType;
  final ValueChanged<String> onTimeFrameChanged;
  final ValueChanged<String> onReportTypeChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool isLoading;
  final InquiryReportsData? inq;
  final ChatbotUsageReportsData? cb;
  final UserDemographicsReportsData? ud;
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
    required this.selectedReportType,
    required this.onTimeFrameChanged,
    required this.onReportTypeChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.isLoading,
    this.inq,
    this.cb,
    this.ud,
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
              selectedReportType,
              onTimeFrameChanged,
              onReportTypeChanged,
              onRefresh,
              isRefreshing,
              userName,
              customDateRange,
              onDateRangeChanged,
                    inq,
              cb,
              ud,
              ad,
            ),
            const SizedBox(height: 24),

            if (isLoading)
              ...buildSkeletonReport(selectedReportType, isMobile: true)
            else
              ...ReportsHelper.buildReportContent(
                selectedReportType,
                inq,
                ad,
                cb,
                selectedTimeFrame,
                ud,
                startDate,
                timeFrame,
                timeCategoryCounts,
                customDateRange,
                isMobile: true,
                context: context,
              ),
          ],
        ),
      ),
    );
  }
}

// ✅ Build Skeleton based on Report Type
List<Widget> buildSkeletonReport(String reportType, {bool isMobile = false}) {
  if (isMobile) {
    return [
      // Stat cards row 1
      Row(
        children: [
          Expanded(child: buildStatCardSkeleton(isMobile: true)),
          const SizedBox(width: 12),
          Expanded(child: buildStatCardSkeleton(isMobile: true)),
        ],
      ),
      const SizedBox(height: 12),
      // Stat cards row 2
      Row(
        children: [
          Expanded(child: buildStatCardSkeleton(isMobile: true)),
          const SizedBox(width: 12),
          Expanded(child: buildStatCardSkeleton(isMobile: true)),
        ],
      ),
      const SizedBox(height: 24),
      // Chart cards
      SizedBox(height: 400, child: buildChartCardSkeleton(isMobile: true)),
      const SizedBox(height: 16),
      SizedBox(height: 400, child: buildChartCardSkeleton(isMobile: true)),
      const SizedBox(height: 16),
      SizedBox(height: 400, child: buildChartCardSkeleton(isMobile: true)),
    ];
  }

  // Desktop/Tablet skeleton
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

class ReportsHelper {
  static List<Widget> buildReportContent(
    String reportType,
    InquiryReportsData? inq,
    AdminDashboardData? ad,
    ChatbotUsageReportsData? cb,
    String selectedTimeFrame,
    UserDemographicsReportsData? ud,
    DateTime startDate,
    String timeFrame,
    Map<String, Map<String, int>> timeCategoryCounts,
    DateTimeRange? customDateRange, // ADD THIS PARAMETER
    {
    bool isMobile = false,
    required BuildContext context,
  }) {
    switch (reportType) {
      case 'Inquiry Trends':
        return buildInquiryTrendsReport(
          inq,
          ad,
          selectedTimeFrame: selectedTimeFrame,
          isMobile: isMobile,
          context: context,
        );
      case 'Chatbot Usage':
        return buildChatbotUsageReport(
          cb,
          startDate,
          selectedTimeFrame,
          customDateRange, // PASS IT HERE
          timeCategoryCounts,
          timeFrame,
          isMobile: isMobile,
        );
      case 'User Demographics':
        return buildUserDemographicsReport(
          ud,
          selectedTimeFrame: selectedTimeFrame,
          context: context,
          isMobile: isMobile,
        );
      default:
        return buildInquiryTrendsReport(
          inq,
          ad,
          isMobile: isMobile,
          context: context,
        );
    }
  }
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

List<Widget> buildChatbotUsageReport(
  ChatbotUsageReportsData? data,
  DateTime startDate,
  String selectedTimeFrame, // Changed parameter name for clarity
  DateTimeRange? customDateRange, // ADD THIS PARAMETER
  Map<String, Map<String, int>> timeCategoryCounts,
  String timeFrame, {
  bool isMobile = false,
}) {
  String formatResponseTime(double seconds) {
    if (seconds == 0) return 'N/A';
    if (seconds < 1) return '${(seconds * 1000).toInt()}ms';
    if (seconds < 10) return '${seconds.toStringAsFixed(2)}s';
    return '${seconds.toStringAsFixed(1)}s';
  }

  String formatSessionLength(double seconds) {
    if (seconds == 0) return 'N/A';
    if (seconds < 60) return '${seconds.toInt()}s';
    if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = (seconds % 60).toInt();
      return '${minutes}m ${remainingSeconds}s';
    }
    final hours = seconds ~/ 3600;
    final remainingMinutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${remainingMinutes}m';
  }

  // Calculate endDate from customDateRange or use null
  final endDate = customDateRange?.end;

  /// =======================
  /// 📱 MOBILE LAYOUT
  /// =======================
  if (isMobile) {
    return [
      Row(
        children: [
          Expanded(
            child: Builder(
              builder: (context) => buildStatCard(
                'Average Response Time',
                formatResponseTime(data?.averageResponseTime ?? 0),
                Colors.blue,
                Icons.timer,
                onTap: () => _showResponseTimeDetailsDialog(
                  context,
                  selectedTimeFrame,
                  data,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(
              builder: (context) => buildStatCard(
                'Total Conversations',
                '${data?.totalConversations ?? 0}',
                Colors.green,
                Icons.chat,
                onTap: () => _showConversationsDialog(context, selectedTimeFrame),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),

      // FIXED: Pass all required parameters
      SizedBox(
        height: 400,
        child: buildPeakUsageCard(
          data!,
          selectedTimeFrame,
          startDate,
          endDate, // Now properly passed
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildConversationsOverTimeCard(
          data?.conversationsOverTime ?? [],
          selectedTimeFrame,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildChatLimitReachTrendCard(data?.chatLimitReachTrend ?? []),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildResponseTimeTrendCard(
          data?.responseTimeTrend ?? [],
          timeFrame: selectedTimeFrame,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildEscalationLimitReachTrendCard(
          data?.escalationLimitReachTrend ?? [],
        ),
      ),
    ];
  }

  /// =======================
  /// 🖥 DESKTOP LAYOUT
  /// =======================
  return [
    SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: Builder(
              builder: (context) => buildStatCard(
                'Average Response Time',
                formatResponseTime(data?.averageResponseTime ?? 0),
                Colors.blue,
                Icons.timer,
                onTap: () => _showResponseTimeDetailsDialog(
                  context,
                  selectedTimeFrame,
                  data,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Builder(
              builder: (context) => buildStatCard(
                'Total Conversations',
                '${data?.totalConversations ?? 0}',
                Colors.green,
                Icons.chat,
                onTap: () => _showConversationsDialog(context, selectedTimeFrame),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildStatCard(
              'Avg Messages/User',
              '${(data?.averageMessagesPerUser ?? 0).toStringAsFixed(1)}',
              Colors.orange,
              Icons.person,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildStatCard(
              'Avg Session Length',
              formatSessionLength(data?.averageConversationTime ?? 0),
              Colors.purple,
              Icons.trending_up,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: buildPeakUsageCard(
        data!,
        selectedTimeFrame,
        startDate,
        endDate,
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: buildChatLimitReachTrendCard(
              data?.chatLimitReachTrend ?? [],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: buildConversationsOverTimeCard(
              data?.conversationsOverTime ?? [],
              selectedTimeFrame,
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
            flex: 2,
            child: buildResponseTimeTrendCard(
              data?.responseTimeTrend ?? [],
              timeFrame: selectedTimeFrame,
              startDate: startDate,
              endDate: endDate,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 1,
            child: buildEscalationLimitReachTrendCard(
              data?.escalationLimitReachTrend ?? [],
            ),
          ),
        ],
      ),
    ),
  ];
}


List<Widget> buildUserDemographicsReport(
  UserDemographicsReportsData? data, {
  String? selectedTimeFrame,
  required BuildContext context,
  bool isMobile = false,
}) {
  /// =======================
  /// 📱 MOBILE LAYOUT
  /// =======================
  if (isMobile) {
    return [
      Row(
        children: [
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'Total Users',
                    '${data?.totalUsers ?? 0}',
                    Colors.blue,
                    Icons.people,
                    onTap: () => _showAllUsersDialog(context),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'New Users for this $selectedTimeFrame',
                    '${data?.newUsers ?? 0}',
                    Colors.green,
                    Icons.person_outline,
                    onTap: () => _showEnrolledUsersDialog(context),
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
                    'Active and Inactive User',
                    '${data?.activeUserRatio ?? 0}',
                    Colors.orange,
                    Icons.school,
                    onTap: () => _showScholarshipUsersDialog(context),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'Enrolled Student and Incoming Freshman Applicant',
                    '${data?.enrolledRatio ?? 0}',
                    Colors.purple,
                    Icons.business,
                    onTap: () => _showFreshmanUsersDialog(context),
                  ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 400,
        child: buildUserGrowthCard( data?.userGrowthOverTime ?? [],
        selectedTimeFrame ?? 'This Month',
        context,),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildUsersByProgramCard(data?.usersByProgram ?? {}),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildUsersByYearLevelCard(data?.usersByYear ?? {}),
      ),
      const SizedBox(height: 16),
            SizedBox(
        height: 400,
        child: buildUserAffiliationsCard(data?.userAffiliations ?? {}),
      ),
      SizedBox(width: 16,),
      SizedBox(
        height: 400,
        child: buildScholarshipDistributionCard(
          data?.usersWithScholarship,
          data?.usersWithoutScholarship,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildScholarshipTypesCard(data?.scholarshipDistribution ?? {}),
      ),
    ];
  }

  /// =======================
  /// 🖥 DESKTOP LAYOUT
  /// =======================
  return [
    SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'Total Users',
                    '${data?.totalUsers ?? 0}',
                    Colors.blue,
                    Icons.people,
                    onTap: () => _showAllUsersDialog(context),
                  ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'New users this $selectedTimeFrame',
                    '${data?.newUsers ?? 0}',
                    Colors.green,
                    Icons.person_outline,
                    onTap: () => _showEnrolledUsersDialog(context),
                  ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'Active and Inactive User',
                    '${data?.activeUserRatio ?? 0}',
                    Colors.orange,
                    Icons.school,
                    onTap: () => _showScholarshipUsersDialog(context),
                  ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Builder(
              builder:
                  (context) => buildStatCard(
                    'Enrolled Students and Incoming Freshman Applicants',
                    '${data?.enrolledRatio ?? 0}',
                    Colors.purple,
                    Icons.business,
                    onTap: () => _showFreshmanUsersDialog(context),
                  ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,

      child: buildUserGrowthCard(
        data?.userGrowthOverTime ?? [],
        selectedTimeFrame ?? 'This Month',
        context,
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(child: buildUsersByProgramCard(data?.usersByProgram ?? {})),
          const SizedBox(width: 20),
          Expanded(child: buildUsersByYearLevelCard(data?.usersByYear ?? {})),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
          child: buildUserAffiliationsCard(data?.userAffiliations ?? {}),
    ),
   const SizedBox(height: 16),

    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: buildScholarshipDistributionCard(
              data?.usersWithScholarship,
              data?.usersWithoutScholarship,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: buildScholarshipTypesCard(
              data?.scholarshipDistribution ?? {},
            ),
          ),
        ],
      ),
    ),
  ];
}

Widget buildPeakUsageCard(
  ChatbotUsageReportsData data,
  String timeFrame,
  DateTime startDate,
  DateTime? endDate,
) {
  // Show the most relevant peak usage based on timeframe
  switch (timeFrame) {
    case 'Today':
      // Show hourly breakdown
      return buildPeakUsageHoursCard(
        data.peakUsageByHour,
        timeFrame,
        startDate,
        endDate,
      );

    case 'This Week':
      // Show daily breakdown (Mon-Sun)
      return buildPeakUsageByDayCard(
        data.peakUsageByDay,
        timeFrame,
        startDate,
        endDate,
      );

    case 'This Month':
      // Show weekly breakdown or daily
      return buildPeakUsageByMonthCard(
        data.peakUsageByMonth,
        timeFrame,
        startDate,
        endDate,
      );

    case 'This Year':
      // Show monthly breakdown
      return buildPeakUsageByYearCard(
        data.peakUsageByYear,
        timeFrame,
        startDate,
        endDate,
      );

    case 'All':
      // Show monthly or yearly breakdown
      return buildPeakUsageByAllYearsCard(
        data.peakUsageByAllYears,
        timeFrame,
        startDate,
        endDate,
      );

    default:
      return buildPeakUsageByMonthCard(
        data.peakUsageByMonth,
        timeFrame,
        startDate,
        endDate,
      );
  }
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

void _showUsersDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Total Users',
          headerColor: Colors.red,
          dataFetcher: (page, pageSize) async {
            Query query = FirebaseFirestore.instance.collection('users');

            if (timeFrame != 'All') {
              final startDate = _getStartDateForDialog(timeFrame);
              query = query.where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              );
            }

            final snapshot =
                await query
                    .orderBy('createdAt', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = data['createdAt'] as Timestamp?;
              return {
                'Name': data['name'] ?? 'N/A',
                'Email': data['email'] ?? 'N/A',
                'Program': data['program'] ?? 'N/A',
                'Year': data['year']?.toString() ?? 'N/A',
                'Joined':
                    timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
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

// Additional dialog methods for Reports page:

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

void _showSessionsDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Chat Sessions',
          headerColor: Colors.green,
          dataFetcher: (page, pageSize) async {
            final startDate = _getStartDateForDialog(timeFrame);
            Query query = FirebaseFirestore.instance
                .collection('conversations')
                .where(
                  'createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
                );

            final snapshot =
                await query
                    .orderBy('createdAt', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = data['createdAt'] as Timestamp?;
              final endedAt = data['endedAt'] as Timestamp?;
              final status = data['status'] ?? 'active';

              String duration = 'N/A';
              if (createdAt != null && endedAt != null) {
                final diff = endedAt.toDate().difference(createdAt.toDate());
                duration = '${diff.inMinutes}m ${diff.inSeconds % 60}s';
              }

              return {
                'User ID': data['userId'] ?? 'N/A',
                'Status': status,
                'Duration': duration,
                'Started':
                    createdAt != null ? _formatTimestamp(createdAt) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}

void _showResponseTimeDetailsDialog(
  BuildContext context,
  String timeFrame,
  ChatbotUsageReportsData? data,
) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Response Time Details',
          headerColor: Colors.blue,
          dataFetcher: (page, pageSize) async {
            final startDate = _getStartDateForDialog(timeFrame);
            final snapshot =
                await FirebaseFirestore.instance
                    .collectionGroup('messages')
                    .where('sender', isEqualTo: 'bot')
                    .where(
                      'sent_at',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
                    )
                    .orderBy('sent_at', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['sent_at'] as Timestamp?;
              final responseTimeMs = data['responseTimeMs'];

              String responseTime = 'N/A';
              if (responseTimeMs != null && responseTimeMs is num) {
                final seconds = responseTimeMs / 1000;
                if (seconds < 1) {
                  responseTime = '${responseTimeMs.toInt()}ms';
                } else {
                  responseTime = '${seconds.toStringAsFixed(2)}s';
                }
              }

              return {
                'Response':
                    (data['text'] ?? 'N/A').toString().substring(
                      0,
                      (data['text'] ?? 'N/A').toString().length > 50
                          ? 50
                          : (data['text'] ?? 'N/A').toString().length,
                    ) +
                    '...',
                'Time': responseTime,
                'Date': timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}

void _showAllUsersDialog(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'All Users',
          headerColor: Colors.blue,
          dataFetcher: (page, pageSize) async {
            final snapshot =
                await FirebaseFirestore.instance
                    .collection('users')
                    .orderBy('createdAt', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['createdAt'] as Timestamp?;
              return {
                'Name': data['name'] ?? 'N/A',
                'Email': data['email'] ?? 'N/A',
                'Program': data['program'] ?? 'N/A',
                'Year': data['year']?.toString() ?? 'N/A',
                'Joined':
                    timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}

void _showEnrolledUsersDialog(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Enrolled Users',
          headerColor: Colors.green,
          dataFetcher: (page, pageSize) async {
            final snapshot =
                await FirebaseFirestore.instance
                    .collection('users')
                    .where('isEnrolled', isEqualTo: true)
                    .orderBy('createdAt', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['createdAt'] as Timestamp?;
              return {
                'Name': data['name'] ?? 'N/A',
                'Email': data['email'] ?? 'N/A',
                'Program': data['program'] ?? 'N/A',
                'Year': data['year']?.toString() ?? 'N/A',
                'Joined':
                    timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}

void _showScholarshipUsersDialog(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Users with Scholarships',
          headerColor: Colors.orange,
          dataFetcher: (page, pageSize) async {
            final snapshot =
                await FirebaseFirestore.instance
                    .collection('users')
                    .where('scholarship', isNotEqualTo: null)
                    .orderBy('scholarship')
                    .orderBy('createdAt', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs
                .where((doc) {
                  final scholarship = doc.data()['scholarship'];
                  return scholarship != null &&
                      scholarship.toString().trim().isNotEmpty &&
                      scholarship.toString().toLowerCase() != 'null';
                })
                .map((doc) {
                  final data = doc.data();
                  final timestamp = data['createdAt'] as Timestamp?;
                  return {
                    'Name': data['name'] ?? 'N/A',
                    'Scholarship': data['scholarship'] ?? 'N/A',
                    'Program': data['program'] ?? 'N/A',
                    'Year': data['year']?.toString() ?? 'N/A',
                    'Joined':
                        timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
                  };
                })
                .toList();
          },
        ),
  );
}

void _showFreshmanUsersDialog(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Incoming Freshman Users',
          headerColor: Colors.purple,
          dataFetcher: (page, pageSize) async {
            final snapshot =
                await FirebaseFirestore.instance
                    .collection('users')
                    .where(
                      'affiliation',
                      isEqualTo: 'Incoming Freshman Applicant',
                    )
                    .orderBy('createdAt', descending: true)
                    .limit(pageSize)
                    // .offset(page * pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['createdAt'] as Timestamp?;
              return {
                'Name': data['name'] ?? 'N/A',
                'Email': data['email'] ?? 'N/A',
                'Program': data['program'] ?? 'N/A',
                'Joined':
                    timestamp != null ? _formatTimestamp(timestamp) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}

String _formatTimestamp(Timestamp timestamp) {
  final date = timestamp.toDate();
  return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}

// ✅ UPDATED buildHeader function for Reports page
Widget buildHeader(
  String selectedTimeFrame,
  String selectedReportType,
  ValueChanged<String> onTimeFrameChanged,
  ValueChanged<String> onReportTypeChanged,
  VoidCallback onRefresh,
  bool isRefreshing,
  String userName,
  DateTimeRange? customDateRange,
  ValueChanged<DateTimeRange?> onDateRangeChanged,
  // ✅ ADD THESE PARAMETERS FOR EXPORT
  InquiryReportsData? inq,
  ChatbotUsageReportsData? cb,
  UserDemographicsReportsData? ud,
  AdminDashboardData? ad,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double screenWidth = MediaQuery.of(context).size.width;
      bool isMobile = screenWidth < 600;

      // ✅ Determine page type based on selected report
      String pageType = selectedReportType == 'Inquiry Trends'
          ? 'inquiry'
          : selectedReportType == 'Chatbot Usage'
              ? 'chatbot'
              : 'demographics';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reports and Analytics',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CustomDropdownButton(
                          items: [
                            'Inquiry Trends',
                            'Chatbot Usage',
                            'User Demographics',
                          ],
                          initialValue: selectedReportType,
                          onChanged: onReportTypeChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                      // ✅ ADD EXPORT BUTTON
                      const SizedBox(width: 8),
                      ExportButton(
                        pageType: pageType,
                        timeFrame: selectedTimeFrame,
                        userName: userName,
                        inq: inq,
                        cb: cb,
                        ud: ud,
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
                    'Reports and Analytics',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CustomDropdownButton(
                        items: [
                          'Inquiry Trends',
                          'Chatbot Usage',
                          'User Demographics',
                        ],
                        initialValue: selectedReportType,
                        onChanged: onReportTypeChanged,
                      ),
                      const SizedBox(width: 12),
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
                      // ✅ ADD EXPORT BUTTON
                      const SizedBox(width: 12),
                      ExportButton(
                        pageType: pageType,
                        timeFrame: selectedTimeFrame,
                        userName: userName,
                        inq: inq,
                        cb: cb,
                        ud: ud,
                        ad: ad,
                      ),
                    ],
                  ),
                ],
              ),
          SizedBox(height: isMobile ? 12 : 8),
          Text(
            _getReportDescription(
              selectedReportType,
              selectedTimeFrame,
              customDateRange,
            ),
            style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey),
          ),
        ],
      );
    },
  );
}


// Update _getReportDescription to handle custom date range:
String _getReportDescription(
  String reportType,
  String timeFrame,
  DateTimeRange? customDateRange,
) {
  String timeFrameText = timeFrame;

  if (timeFrame == 'Custom' && customDateRange != null) {
    timeFrameText =
        'from ${_formatDate(customDateRange.start)} to ${_formatDate(customDateRange.end)}';
  }

  switch (reportType) {
    case 'Inquiry Trends':
      return "Detailed analysis of inquiry patterns and trends $timeFrameText.";
    case 'Chatbot Usage':
      return "Chatbot performance metrics and usage statistics $timeFrameText.";
    case 'User Demographics':
      return "User demographics and engagement patterns $timeFrameText.";
    default:
      return "Here's a complete reports and analytics of OASP Assist $timeFrameText.";
  }
}

// Helper function to format dates
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

void _showConversationsDialog(BuildContext context, String timeFrame) {
  showDialog(
    context: context,
    builder:
        (context) => PaginatedListDialog(
          title: 'Conversations',
          headerColor: Colors.green,
          dataFetcher: (page, pageSize) async {
            final startDate = _getStartDateForDialog(timeFrame);
            Query query = FirebaseFirestore.instance
                .collection('conversations')
                .where(
                  'createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
                );

            final snapshot =
                await query
                    .orderBy('createdAt', descending: true)
                    .limit(pageSize)
                    .get();

            return snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = data['createdAt'] as Timestamp?;
              final endedAt = data['endedAt'] as Timestamp?;
              final status = data['status'] ?? 'active';

              String duration = 'N/A';
              if (createdAt != null && endedAt != null) {
                final diff = endedAt.toDate().difference(createdAt.toDate());
                duration = '${diff.inMinutes}m ${diff.inSeconds % 60}s';
              }

              return {
                'User ID': data['userId'] ?? 'N/A',
                'Status': status,
                'Duration': duration,
                'Started':
                    createdAt != null ? _formatTimestamp(createdAt) : 'N/A',
              };
            }).toList();
          },
        ),
  );
}
