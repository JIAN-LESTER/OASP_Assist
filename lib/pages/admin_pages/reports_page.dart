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

  InquiryReportsData? inq;
  ChatbotUsageReportsData? cb;
  UserDemographicsReportsData? ud;
  String? userName;

  bool isLoading = true;
  bool isRefreshing = false;

  DateTime startDate = DateTime.now();
  String timeFrame = "This Month";
  final timeCategoryCounts = <String, Map<String, int>>{};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _onReportTypeChanged(String newValue) {
    setState(() {
      selectedReportType = newValue;
    });
  }

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
      print('Error loading reports data: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

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
                    'Reports refreshed successfully',
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
      print('Error refreshing reports data: $e');
      if (!mounted) return;
      setState(() {
        isRefreshing = false;
      });

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
                    'Failed to refresh reports',
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
        selectedReportType: selectedReportType,
        onTimeFrameChanged: _onTimeFrameChanged,
        onReportTypeChanged: _onReportTypeChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
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

class DesktopDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final String selectedReportType;
  final ValueChanged<String> onTimeFrameChanged;
  final ValueChanged<String> onReportTypeChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
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
      Container(
        height: 400,
        child: buildInquiryTrendCard(
          data?.inquiryTrend ?? [],
          selectedTimeFrame.toString(),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        height: 400,
        child: buildCategoryDistributionCard(data?.categoryDistribution ?? {}),
      ),
      const SizedBox(height: 16),
      Container(
        height: 400,
        child: buildHighestFAQCard(data?.highestFAQs ?? {}),
      ),
      const SizedBox(height: 16),
      Container(
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
          Expanded(child: buildInquiryTrendCard(data?.inquiryTrend ?? [], selectedTimeFrame.toString())),
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

  // ✅ Format response time display
  String formatResponseTime(double seconds) {
    if (seconds == 0) return 'N/A';
    
    if (seconds < 1) {
      // Show in milliseconds if less than 1 second
      return '${(seconds * 1000).toInt()}ms';
    } else if (seconds < 10) {
      // Show with 2 decimal places for 1-10 seconds
      return '${seconds.toStringAsFixed(2)}s';
    } else {
      // Show with 1 decimal place for 10+ seconds
      return '${seconds.toStringAsFixed(1)}s';
    }
  }

  // ✅ Format session length display
  String formatSessionLength(double seconds) {
    if (seconds == 0) return 'N/A';
    
    if (seconds < 60) {
      // Show in seconds if less than 1 minute
      return '${seconds.toInt()}s';
    } else if (seconds < 3600) {
      // Show in minutes and seconds
      final minutes = seconds ~/ 60;
      final remainingSeconds = (seconds % 60).toInt();
      return '${minutes}m ${remainingSeconds}s';
    } else {
      // Show in hours and minutes
      final hours = seconds ~/ 3600;
      final remainingMinutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${remainingMinutes}m';
    }
  }

  return [
    SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Average Response Time',
              formatResponseTime(data?.averageResponseTime ?? 0), // ✅ Fixed
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
              formatSessionLength(data?.averageSessionLength ?? 0), // ✅ Fixed
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
      Container(
        height: 400,
        child: buildUserAffiliationsCard(data?.userAffiliations ?? {}),
      ),
      const SizedBox(height: 16),
      Container(
        height: 400,
        child: buildUsersByYearCard(data?.usersByYear ?? {}),
      ),
      const SizedBox(height: 16),
      Container(
        height: 400,
        child: buildUsersByProgramCard(data?.usersByProgram ?? {}),
      ),
      const SizedBox(height: 16),
      Container(
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
    SizedBox(
      height: 400,
      child: buildUserAffiliationsCard(data?.userAffiliations ?? {}),
    ),
    const SizedBox(height: 16),
    SizedBox(height: 400, child: buildUsersByYearCard(data?.usersByYear ?? {})),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: buildUsersByProgramCard(data?.usersByProgram ?? {}),
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
