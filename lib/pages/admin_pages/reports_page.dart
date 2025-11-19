import 'package:capstone_project/pages/data/chatbot_usage_charts.dart';
import 'package:capstone_project/pages/data/chatbot_usage_data.dart';
import 'package:capstone_project/pages/data/inquiry_trends_charts.dart';
import 'package:capstone_project/pages/data/inquiry_trends_data.dart';
import 'package:capstone_project/pages/data/user_demographics_charts.dart';
import 'package:capstone_project/pages/data/user_demographics_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/pages/admin_pages/widgets/custom_dropdown_button.dart';
import 'package:capstone_project/pages/admin_pages/widgets/refresh_button.dart';
import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/reports.dart';
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
  String? userName;

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
            );
            if (!mounted) return;
            setState(() {
              inq = data;
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
    setState(() {
      selectedTimeFrame = newValue;

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
    // Only show loading spinner while user name is loading
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
        userName: userName!,
        startDate: startDate,
        timeCategoryCounts: timeCategoryCounts,
        timeFrame: timeFrame,
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
        userName: userName!,
        startDate: startDate,
        timeCategoryCounts: timeCategoryCounts,
        timeFrame: timeFrame,
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
        userName: userName!,
        startDate: startDate,
        timeCategoryCounts: timeCategoryCounts,
        timeFrame: timeFrame,
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
  final String userName;
  final DateTime startDate;
  final String timeFrame;
  final Map<String, Map<String, int>> timeCategoryCounts;

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
    required this.userName,
    required this.startDate,
    required this.timeCategoryCounts,
    required this.timeFrame,
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
            ),
            const SizedBox(height: 32),

            // ✅ Show skeleton loader for current report
            if (isLoading)
              ...buildSkeletonReport(selectedReportType, isMobile: false)
            else
              ...ReportsHelper.buildReportContent(
                selectedReportType,
                inq,
                cb,
                selectedTimeFrame,
                ud,
                startDate,
                timeFrame,
                timeCategoryCounts,
                isMobile: false,
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
  final String userName;
  final DateTime startDate;
  final String timeFrame;
  final Map<String, Map<String, int>> timeCategoryCounts;

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
    required this.startDate,
    required this.timeCategoryCounts,
    required this.timeFrame,
    required this.userName,
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
            ),
            const SizedBox(height: 32),

            if (isLoading)
              ...buildSkeletonReport(selectedReportType, isMobile: false)
            else
              ...ReportsHelper.buildReportContent(
                selectedReportType,
                inq,
                cb,
                selectedTimeFrame,
                ud,
                startDate,
                timeFrame,
                timeCategoryCounts,
                isMobile: false,
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
  final String userName;
  final DateTime startDate;
  final String timeFrame;
  final Map<String, Map<String, int>> timeCategoryCounts;

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
    required this.userName,
    required this.startDate,
    required this.timeCategoryCounts,
    required this.timeFrame,
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
            ),
            const SizedBox(height: 24),

            if (isLoading)
              ...buildSkeletonReport(selectedReportType, isMobile: true)
            else
              ...ReportsHelper.buildReportContent(
                selectedReportType,
                inq,
                cb,
                selectedTimeFrame,
                ud,
                startDate,
                timeFrame,
                timeCategoryCounts,
                isMobile: true,
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
    ChatbotUsageReportsData? cb,
    String selectedTimeFrame,
    UserDemographicsReportsData? ud,
    DateTime startDate,
    String timeFrame,
    Map<String, Map<String, int>> timeCategoryCounts, {
    bool isMobile = false,
  }) {
    switch (reportType) {
      case 'Inquiry Trends':
        return buildInquiryTrendsReport(
          inq,
          selectedTimeFrame: selectedTimeFrame,
          isMobile: isMobile,
        );
      case 'Chatbot Usage':
        return buildChatbotUsageReport(
          cb,
          startDate,
          timeCategoryCounts,
          timeFrame,
          isMobile: isMobile,
        );
      case 'User Demographics':
        return buildUserDemographicsReport(ud, isMobile: isMobile);
      default:
        return buildInquiryTrendsReport(inq, isMobile: isMobile);
    }
  }
}

List<Widget> buildInquiryTrendsReport(
  InquiryReportsData? data, {
  String? selectedTimeFrame,
  bool isMobile = false,
}) {
  if (isMobile) {
    return [
      Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Total Messages',
              '${data?.totalMessages ?? 0}',
              Colors.blue,
              Icons.message,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: buildStatCard(
              'Answered Messages',
              '${data?.answeredMessages ?? 0}',
              Colors.green,
              Icons.check_circle,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Unanswered Messages',
              '${data?.unAnsweredMessages ?? 0}',
              Colors.red,
              Icons.people,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: buildStatCard(
              'Escalated Messages',
              data?.escalatedMessages.toString() ?? '0',
              Colors.orange,
              Icons.help,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 400,
        child: buildInquiryTrendCard(
          data?.inquiryTrend ?? [],
          selectedTimeFrame.toString(),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildCategoryDistributionCard(data?.categoryDistribution ?? {}),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildHighestFAQCard(data?.highestFAQs ?? {}),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildSeasonalTrendsCard(data?.seasonalTrends ?? {}),
      ),
    ];
  }

  return [
    SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Total Messages',
              '${data?.totalMessages ?? 0}',
              Colors.blue,
              Icons.message,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildStatCard(
              'Answered Messages',
              '${data?.answeredMessages ?? 0}',
              Colors.green,
              Icons.check_circle,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildStatCard(
              'Unanswered Messages',
              '${data?.unAnsweredMessages ?? 0}',
              Colors.red,
              Icons.people,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildStatCard(
              'Escalated Messages',
              data?.escalatedMessages.toString() ?? '0',
              Colors.orange,
              Icons.help,
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
              selectedTimeFrame.toString(),
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
            child: buildCategoryDistributionCard(
              data?.categoryDistribution ?? {},
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: buildHighestFAQCard(data?.highestFAQs ?? {})),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(child: buildSeasonalTrendsCard(data?.seasonalTrends ?? {})),
        ],
      ),
    ),
  ];
}

List<Widget> buildChatbotUsageReport(
  ChatbotUsageReportsData? data,
  DateTime start,
  Map<String, Map<String, int>> timeCategoryCounts,
  String timeFrame, {
  bool isMobile = false,
}) {
  List<ChartData> getConversationTrendData() {
    if (data == null) return <ChartData>[];

    switch (timeFrame) {
      case 'Today':
        return data.dailySessions ?? <ChartData>[];
      case 'This Week':
        return data.weeklySessions ?? <ChartData>[];
      case 'This Month':
        return data.monthlySessions ?? <ChartData>[];
      case 'This Year':
        return data.monthlySessions ?? <ChartData>[];
      default:
        return data.dailySessions ?? <ChartData>[];
    }
  }

  final conversationTrend = getConversationTrendData();

  //  Format response time display
  String formatResponseTime(double seconds) {
    if (seconds == 0) return 'N/A';

    if (seconds < 1) {
      return '${(seconds * 1000).toInt()}ms';
    } else if (seconds < 10) {
      return '${seconds.toStringAsFixed(2)}s';
    } else {
      return '${seconds.toStringAsFixed(1)}s';
    }
  }

  //  Format session length display
  String formatSessionLength(double seconds) {
    if (seconds == 0) return 'N/A';

    if (seconds < 60) {
      return '${seconds.toInt()}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = (seconds % 60).toInt();
      return '${minutes}m ${remainingSeconds}s';
    } else {
      final hours = seconds ~/ 3600;
      final remainingMinutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${remainingMinutes}m';
    }
  }

  if (isMobile) {
    return [
      Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Average Response Time',
              formatResponseTime(data?.averageResponseTime ?? 0),
              Colors.blue,
              Icons.timer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: buildStatCard(
              'Total Sessions',
              '${data?.totalSessions ?? 0}',
              Colors.green,
              Icons.chat,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Avg Messages/User',
              '${(data?.averageMessagesPerUser ?? 0).toStringAsFixed(1)}',
              Colors.orange,
              Icons.person,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: buildStatCard(
              'Avg Session Length',
              formatSessionLength(data?.averageSessionLength ?? 0),
              Colors.purple,
              Icons.trending_up,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 400,
        child: buildConversationsOverTimeCard(conversationTrend, timeFrame),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 350,
        child: buildPeakUsageHoursCard(data?.peakUsageByHour ?? <int, int>{}),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildUsersByCourseCard(data?.usersByCourse ?? <String, int>{}),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildUsersByYearLevelCard(
          data?.usersByYearLevel ?? <String, int>{},
          isMobile: true,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildResponseTimeTrendCard(
          data?.responseTimeTrend ?? <ChartData>[],
        ),
      ),
    ];
  }

  return [
    SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Average Response Time',
              formatResponseTime(data?.averageResponseTime ?? 0),
              Colors.blue,
              Icons.timer,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildStatCard(
              'Total Sessions',
              '${data?.totalSessions ?? 0}',
              Colors.green,
              Icons.chat,
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
              formatSessionLength(data?.averageSessionLength ?? 0),
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
      child: buildConversationsOverTimeCard(conversationTrend, timeFrame),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 350,
      child: buildPeakUsageHoursCard(data?.peakUsageByHour ?? <int, int>{}),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            child: buildUsersByCourseCard(
              data?.usersByCourse ?? <String, int>{},
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildUsersByYearLevelCard(
              data?.usersByYearLevel ?? <String, int>{},
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: buildResponseTimeTrendCard(
        data?.responseTimeTrend ?? <ChartData>[],
      ),
    ),
  ];
}

List<Widget> buildUserDemographicsReport(
  UserDemographicsReportsData? data, {
  bool isMobile = false,
}) {
  if (isMobile) {
    return [
      Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Total Users',
              '${data?.totalUsers ?? 0}',
              Colors.blue,
              Icons.people,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: buildStatCard(
              'Enrolled Users',
              '${data?.activeUsers ?? 0}',
              Colors.green,
              Icons.person_outline,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Users with Scholarships',
              '${data?.newlyRegisteredUsers ?? 0}',
              Colors.orange,
              Icons.person_add,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: buildStatCard(
              'Affiliated Users',
              '${data?.affiliatedUsers ?? 0}',
              Colors.purple,
              Icons.business,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 400,
        child: buildUsersByYearCard(data?.usersByYear ?? {}),
      ),

      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildUsersByProgramCard(data?.usersByProgram ?? {}),
      ),
      const SizedBox(height: 16),

      SizedBox(
        height: 400,
        child: buildUserAffiliationsCard(data?.userAffiliations ?? {}),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 400,
        child: buildScholarshipTypesCard(data?.scholarshipTypes ?? {}),
      ),
    ];
  }

  return [
    SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Total Users',
              '${data?.totalUsers ?? 0}',
              Colors.blue,
              Icons.people,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildStatCard(
              'Enrolled Users',
              '${data?.activeUsers ?? 0}',
              Colors.green,
              Icons.person_outline,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildStatCard(
              'Users with Scholarships',
              '${data?.newlyRegisteredUsers ?? 0}',
              Colors.orange,
              Icons.person_add,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildStatCard(
              'Affiliated Users',
              '${data?.affiliatedUsers ?? 0}',
              Colors.purple,
              Icons.business,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(height: 400, child: buildUsersByYearCard(data?.usersByYear ?? {})),

    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(child: buildUsersByProgramCard(data?.usersByProgram ?? {})),
          const SizedBox(width: 20),
          Expanded(
            child: buildUserAffiliationsCard(data?.userAffiliations ?? {}),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: buildScholarshipTypesCard(data?.scholarshipTypes ?? {}),
    ),
  ];
}

Widget buildHeader(
  String selectedTimeFrame,
  String selectedReportType,
  ValueChanged<String> onTimeFrameChanged,
  ValueChanged<String> onReportTypeChanged,
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
                      const SizedBox(width: 8),
                      RefreshButton(
                        onRefresh: onRefresh,
                        isRefreshing: isRefreshing,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
            _getReportDescription(selectedReportType, selectedTimeFrame),
            style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey),
          ),
        ],
      );
    },
  );
}

String _getReportDescription(String reportType, String timeFrame) {
  switch (reportType) {
    case 'Inquiry Trends':
      return "Detailed analysis of inquiry patterns and trends for $timeFrame.";
    case 'Chatbot Usage':
      return "Chatbot performance metrics and usage statistics for $timeFrame.";
    case 'User Demographics':
      return "User demographics and engagement patterns for $timeFrame.";
    default:
      return "Here's a complete reports and analytics of OASP Assist for $timeFrame.";
  }
}
