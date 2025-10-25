import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/colors.dart';

import 'package:capstone_project/pages/admin_pages/widgets/custom_dropdown_button.dart';
import 'package:capstone_project/pages/data/charts.dart';

import 'package:capstone_project/pages/data/reports.dart';
import 'package:capstone_project/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  String selectedTimeFrame = 'This Month';
  final currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseService _firebaseService = FirebaseService();
  InquiryReportsData? inq;
  ChatbotUsageReportsData? cb;
  UserDemographicsReportsData? ud;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadreportsData();
    fetchUserName();
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
      if (!mounted) return; // <== ✅ add this

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

  Future<void> _loadreportsData() async {
    if (!mounted) return; // <== ✅ safety check
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
    _loadreportsData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || isNameLoading || userName == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ResponsiveLayout(
      mobileBody: MobileDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        inq: inq,
        cb: cb,
        ud: ud,

        userName: userName!, // <- added
      ),
      tabletBody: TabletDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        inq: inq,
        cb: cb,
        ud: ud,

        userName: userName!, // <- added
      ),
      desktopBody: DesktopDashboard(
        selectedTimeFrame: selectedTimeFrame,
        onTimeFrameChanged: _onTimeFrameChanged,
        inq: inq,
        cb: cb,
        ud: ud,

        userName: userName!, // <- added
      ),
    );
  }
}

// Desktop Dashboard
class DesktopDashboard extends StatelessWidget {
  final String selectedTimeFrame;
  final ValueChanged<String> onTimeFrameChanged;
  final InquiryReportsData? inq;
  final ChatbotUsageReportsData? cb;
  final UserDemographicsReportsData? ud;
  final String userName;

  const DesktopDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,

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

  final InquiryReportsData? inq;
  final ChatbotUsageReportsData? cb;
  final UserDemographicsReportsData? ud;
  final String userName;

  const TabletDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
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

  final InquiryReportsData? inq;
  final ChatbotUsageReportsData? cb;
  final UserDemographicsReportsData? ud;
  final String userName;

  const MobileDashboard({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
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
          _buildHeader(selectedTimeFrame, onTimeFrameChanged, userName),
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
                  'Unanswered Messages',
                  '${inq?.unAnsweredMessages ?? 0}',
                  Colors.red,
                  Icons.people,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: buildStatCard(
                  'Escalated Messages',
                  '${inq?.escalatedMessages ?? 0}',
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
          Expanded(flex: 1, child: buildMessageLogsCard(inq?.msgLogs ?? [])),
        ],
      ),
    ),
  );
}

// Updated responsive header
// Updated responsive header
Widget _buildHeader(
  String selectedTimeFrame,
  ValueChanged<String> onTimeFrameChanged,
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
                  Text(
                    'Welcome back, $userName!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
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
