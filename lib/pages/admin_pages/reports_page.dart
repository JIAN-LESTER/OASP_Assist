import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:capstone_project/colors.dart';
import 'package:capstone_project/pages/admin_pages/widgets/custom_dropdown_button.dart';
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
  String selectedReportType = 'Inquiry Trends'; // ADD THIS
  final currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseService _firebaseService = FirebaseService();
  InquiryReportsData? inq;
  ChatbotUsageReportsData? cb;
  UserDemographicsReportsData? ud;
  bool isLoading = true;

  DateTime startDate = DateTime.now();
  String timeFrame = "This Month";
  final timeCategoryCounts = <String, Map<String, int>>{};

  @override
  void initState() {
    super.initState();
    _loadReportsdData();
    fetchUserName();
  }

  void _onReportTypeChanged(String newValue) {
    // ADD THIS METHOD
    setState(() {
      selectedReportType = newValue;
    });
    // No need to reload data, just filter display
  }

  String? userName;
  bool isNameLoading = true;

  Future<void> fetchUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
      if (userDoc.exists) {
        setState(() {
          userName = userDoc.data()?['name'] ?? 'User';
          isNameLoading = false;
        });
      } else {
        setState(() {
          userName = 'User';
          isNameLoading = false;
        });
      }
    }
  }

  Future<void> _loadReportsdData() async {
    setState(() {
      isLoading = true;
    });

    try {
      InquiryReportsData inqData = await _firebaseService.getInquiryReportsData(
        selectedTimeFrame,
      );

      ChatbotUsageReportsData cbData = await _firebaseService
          .getChatbotUsageReportsData(selectedTimeFrame);

      UserDemographicsReportsData udData = await _firebaseService
          .getUserDemographicsReportsData(selectedTimeFrame);

      if (!mounted) return; // <== ✅ safety check
      setState(() {
        inq = inqData;
        cb = cbData;
        ud = udData;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (!mounted) return; // <== ✅ safety check
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onTimeFrameChanged(String newValue) {
    setState(() {
      selectedTimeFrame = newValue;
    });
    _loadReportsdData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || isNameLoading || userName == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ResponsiveLayout(
      mobileBody: MobileDashboard(
        selectedTimeFrame: selectedTimeFrame,
        selectedReportType: selectedReportType, // ADD THIS
        onTimeFrameChanged: _onTimeFrameChanged,
        onReportTypeChanged: _onReportTypeChanged, // ADD THIS
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
        selectedReportType: selectedReportType, // ADD THIS
        onTimeFrameChanged: _onTimeFrameChanged,
        onReportTypeChanged: _onReportTypeChanged, // ADD THIS
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
        selectedReportType: selectedReportType, // ADD THIS
        onTimeFrameChanged: _onTimeFrameChanged,
        onReportTypeChanged: _onReportTypeChanged, // ADD THIS
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

// Desktop Dashboard
class DesktopDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final String selectedReportType; // ADD THIS
  final ValueChanged<String> onTimeFrameChanged;
  final ValueChanged<String> onReportTypeChanged; // ADD THIS
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
    required this.selectedReportType, // ADD THIS
    required this.onTimeFrameChanged,
    required this.onReportTypeChanged, // ADD THIS

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
            // Header - Fixed at top
            buildHeader(
              selectedTimeFrame,
              selectedReportType, // ADD THIS
              onTimeFrameChanged,
              onReportTypeChanged, // ADD THIS
              userName,
            ),
            const SizedBox(height: 32),

            ...ReportsHelper.buildReportContent(
              selectedReportType,
              inq,
              cb,
              ud,
              startDate,
              timeFrame,
              timeCategoryCounts,
              isDesktop: true,
            ),
          ],
        ),
      ),
    );
  }
}

// Tablet Dashboard
class TabletDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final String selectedReportType; // ADD THIS
  final ValueChanged<String> onTimeFrameChanged;
  final ValueChanged<String> onReportTypeChanged; // ADD THIS
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
    required this.selectedReportType, // ADD THIS
    required this.onTimeFrameChanged,
    required this.onReportTypeChanged, // ADD THIS
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
              selectedReportType, // ADD THIS
              onTimeFrameChanged,
              onReportTypeChanged, // ADD THIS
              userName,
            ),
            const SizedBox(height: 32),

            // Top row with 4 stat cards
            ...ReportsHelper.buildReportContent(
              selectedReportType,
              inq,
              cb,
              ud,
              startDate,
              timeFrame,
              timeCategoryCounts,
              isDesktop: true,
            ),
          ],
        ),
      ),
    );
  }
}

// Mobile Dashboard
class MobileDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final String selectedReportType; // ADD THIS
  final ValueChanged<String> onTimeFrameChanged;
  final ValueChanged<String> onReportTypeChanged; // ADD THIS
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
    required this.selectedReportType, // ADD THIS
    required this.onTimeFrameChanged,
    required this.onReportTypeChanged, // ADD THIS
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
              selectedReportType, // ADD THIS
              onTimeFrameChanged,
              onReportTypeChanged, // ADD THIS
              userName,
            ),
            const SizedBox(height: 32),

            ...ReportsHelper.buildReportContent(
              selectedReportType,
              inq,
              cb,
              ud,
              startDate,
              timeFrame,
              timeCategoryCounts,
              isDesktop: true,
            ),
            const SizedBox(height: 32),
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
    UserDemographicsReportsData? ud,
    DateTime startDate,
    String timeFrame,
    Map<String, Map<String, int>> timeCategoryCounts, {
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    switch (reportType) {
      case 'Inquiry Trends':
        return buildInquiryTrendsReport(inq, isDesktop: isDesktop);
      case 'Chatbot Usage':
        return buildChatbotUsageReport(
          cb,
          startDate,
          timeCategoryCounts,
          timeFrame,
          isDesktop: isDesktop,
        );
      case 'User Demographics':
        return buildUserDemographicsReport(ud, isDesktop: isDesktop);
      default:
        return buildInquiryTrendsReport(inq, isDesktop: isDesktop);
    }
  }
}


List<Widget> buildInquiryTrendsReport(
  InquiryReportsData? data, {
  bool isDesktop = false,
}) {
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

    // Inquiry Pattern
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(child: buildInquiryTrendCard(data?.inquiryTrend ?? [])),
        ],
      ),
    ),
    const SizedBox(height: 16),

    // Category Distribution and FAQs
    
   
    SizedBox(
      height: 400,
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
          Expanded(
            child: buildResponseDistributionCard(
              data?.responseDistribution ?? {},
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: buildSeasonalTrendsCard(data?.seasonalTrends ?? {})),
        ],
      ),
    ),

    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            child: buildTop5UnansweredCard(data?.top5UnansweredInquiries ?? []),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildTop5EscalatedCard(data?.top5EscalatedInquiries ?? []),
          ),
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
  bool isDesktop = false,
}) {
  // Safe way to get trend data with null checks
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

  final conversationTrend = getConversationTrendData(
    // start,
    // timeFrame,
    // timeCategoryCounts,
  );

  return [
  

    // Usage Stats
    SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: buildStatCard(
              'Average Response Time',
              '${(data?.averageResponseTime ?? 0).toStringAsFixed(2)}s',
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
              '${(data?.averageSessionLength ?? 0).toStringAsFixed(0)}s',
              Colors.purple,
              Icons.trending_up,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 32),

    // Usage Patterns
  
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            child: buildConversationsOverTimeCard(conversationTrend, timeFrame),
          ),
         
        ],
      ),
    ),

    const SizedBox(height: 16),
    SizedBox(
      height: 350,
      child: Row(
        children: [
              Expanded(child: buildUsersByCourseCard(data?.usersByCourse ?? <String, int>{})),
          const SizedBox(width: 20),
          Expanded(child: buildPeakUsageHoursCard(data?.peakUsageByHour ?? <int, int>{})),
        ],
      ),
    ),

  
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            child: buildTop10ActiveUsersCard(data?.top10ActiveUsers ?? <MapEntry<String, int>>[]),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: buildUsersByYearLevelCard(data?.usersByYearLevel ?? <String, int>{}),
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
            child: buildResponseTimeTrendCard(data?.responseTimeTrend ?? <ChartData>[]), // Fixed null issue
          ),
        ],
      ),
    ),
  ];
}

List<Widget> buildUserDemographicsReport(
  UserDemographicsReportsData? data, {
  bool isDesktop = false,
}) {
  return [
    

    // Demographics Stats
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
      child: Row(
        children: [
          Expanded(
            child: buildUserAffiliationsCard(data?.userAffiliations ?? {}),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(child: buildUsersByYearCard(data?.usersByYear ?? {})),
          const SizedBox(width: 20),
    
        ],
      ),
    ),

    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
      //  Expanded(
      //       child: buildEnrollmentStatusCard(data?.enrollmentStatus ?? {}),
      //     ),
      //     const SizedBox(width: 20),
      //    Expanded(
      //       child: buildScholarshipStatusCard(data?.scholarshipStatus ?? {}),
      //     ),
            Expanded(child: buildUsersByProgramCard(data?.usersByProgram ?? {})),
        ],
      ),
    ),

    
    const SizedBox(height: 16),
    SizedBox(
      height: 400,
      child: Row(
        children: [
       
      
          Expanded(
            child: buildScholarshipTypesCard(data?.scholarshipTypes ?? {}),
          ),
        ],
      ),
    ),
  ];
}



Widget buildHeader(
  String selectedTimeFrame,
  String selectedReportType, // ADD THIS
  ValueChanged<String> onTimeFrameChanged,
  ValueChanged<String> onReportTypeChanged, // ADD THIS
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
                  CustomDropdownButton(
                    items: [
                      'Inquiry Trends',
                      'Chatbot Usage',
                      'User Demographics',
                    ],
                    initialValue: selectedReportType,
                    onChanged: onReportTypeChanged, // MODIFY THIS
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
                        onChanged: onReportTypeChanged, // MODIFY THIS
                      ),
                      const SizedBox(width: 16),
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
                  ),
                ],
              ),
          SizedBox(height: isMobile ? 12 : 8),
          Text(
            _getReportDescription(
              selectedReportType,
              selectedTimeFrame,
            ), // MODIFY THIS
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
