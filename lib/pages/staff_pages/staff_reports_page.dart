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
  String? userName;

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
      final data = await _firebaseService.getInquiryReportsData(selectedTimeFrame);
      if (!mounted) return;
      setState(() {
        inq = data;
        isLoadingInquiry = false;
      });
    } catch (e) {
      print('Error loading inquiry data: $e');
      if (!mounted) return;
      setState(() => isLoadingInquiry = false);
    }
  }

  void _onTimeFrameChanged(String newValue) {
    setState(() {
      selectedTimeFrame = newValue;
    });
    _loadInquiryData();
  }

  Future<void> _refreshData() async {
    if (!mounted || isRefreshing) return;

    setState(() => isRefreshing = true);

    try {
      final data = await _firebaseService.getInquiryReportsData(selectedTimeFrame);
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
        _showSnackBar(
          message: 'Failed to refresh reports',
          isError: true,
        );
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
              isError ? Icons.error_outline : Icons.check_circle_outline_outlined,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        elevation: 6,
      ),
    );
  }

  Future<String?> _fetchUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'User';

    try {
      final userDoc = await FirebaseFirestore.instance
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ResponsiveLayout(
      mobileBody: MobileDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        isLoading: isLoadingInquiry,
        inq: inq,
        userName: userName!,
        startDate: startDate,
        timeCategoryCounts: timeCategoryCounts,
        timeFrame: timeFrame,
      ),
      tabletBody: TabletDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        isLoading: isLoadingInquiry,
        inq: inq,
        userName: userName!,
        startDate: startDate,
        timeCategoryCounts: timeCategoryCounts,
        timeFrame: timeFrame,
      ),
      desktopBody: DesktopDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        isLoading: isLoadingInquiry,
        inq: inq,
        userName: userName!,
        startDate: startDate,
        timeCategoryCounts: timeCategoryCounts,
        timeFrame: timeFrame,
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
    
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
              stops: [
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
        SkeletonLoader(
          height: isMobile ? 24 : 32,
          width: isMobile ? 60 : 80,
        ),
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
        SkeletonLoader(
          height: isMobile ? 18 : 20,
          width: isMobile ? 120 : 150,
        ),
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
  final String userName;
  final DateTime startDate;
  final String timeFrame;
  final Map<String, Map<String, int>> timeCategoryCounts;

  const DesktopDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.isLoading,
    this.inq,
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
              onTimeFrameChanged,
              onRefresh,
              isRefreshing,
              userName,
            ),
            const SizedBox(height: 32),
            
            if (isLoading)
              ...buildSkeletonReport(isMobile: false)
            else
              ...buildInquiryTrendsReport(
                inq,
                selectedTimeFrame: selectedTimeFrame,
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
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool isLoading;
  final InquiryReportsData? inq;
  final String userName;
  final DateTime startDate;
  final String timeFrame;
  final Map<String, Map<String, int>> timeCategoryCounts;

  const TabletDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.isLoading,
    this.inq,
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
              onTimeFrameChanged,
              onRefresh,
              isRefreshing,
              userName,
            ),
            const SizedBox(height: 32),
            
            if (isLoading)
              ...buildSkeletonReport(isMobile: false)
            else
              ...buildInquiryTrendsReport(
                inq,
                selectedTimeFrame: selectedTimeFrame,
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
  final ValueChanged<String> onTimeFrameChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool isLoading;
  final InquiryReportsData? inq;
  final String userName;
  final DateTime startDate;
  final String timeFrame;
  final Map<String, Map<String, int>> timeCategoryCounts;

  const MobileDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.isLoading,
    this.inq,
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
              onTimeFrameChanged,
              onRefresh,
              isRefreshing,
              userName,
            ),
            const SizedBox(height: 24),
            
            if (isLoading)
              ...buildSkeletonReport(isMobile: true)
            else
              ...buildInquiryTrendsReport(
                inq,
                selectedTimeFrame: selectedTimeFrame,
                isMobile: true,
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
              'Escalated Messages',
              '${data?.escalatedMessages ?? 0}',
              Colors.red,
              Icons.people,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: buildStatCard(
              'Resolved Escalated Messages',
              data?.resolvedEscalatedMessages.toString() ?? '0',
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

Widget buildHeader(
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
                          ],
                          initialValue: selectedTimeFrame,
                          onChanged: onTimeFrameChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  const Text(
                    'Inquiry Trends Report',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
            "Detailed analysis of inquiry patterns and trends for $selectedTimeFrame.",
            style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey),
          ),
        ],
      );
    },
  );
}