
// import 'package:capstone_project/pages/data/chatbot_usage_data.dart';
// import 'package:capstone_project/pages/data/inquiry_trends_charts.dart';
// import 'package:capstone_project/pages/data/inquiry_trends_data.dart';
// import 'package:capstone_project/pages/data/user_demographics_data.dart';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:capstone_project/icon_and_color.dart';
// import 'package:capstone_project/pages/admin_pages/widgets/custom_dropdown_button.dart';
// import 'package:capstone_project/pages/data/charts.dart';
// import 'package:capstone_project/pages/data/reports.dart';
// import 'package:capstone_project/responsive/responsive_layout.dart';
// import 'package:flutter/material.dart';

// class StaffReportsPage extends StatefulWidget {
//   const StaffReportsPage({super.key});

//   @override
//   State<StaffReportsPage> createState() => _StaffReportsPageState();
// }

// class _StaffReportsPageState extends State<StaffReportsPage> {
//   String selectedTimeFrame = 'This Month';
//   String selectedReportType = 'Inquiry Trends'; // ADD THIS
//   final currentUser = FirebaseAuth.instance.currentUser;
//   final FirebaseService _firebaseService = FirebaseService();
//   InquiryReportsData? inq;
//   ChatbotUsageReportsData? cb;
//   UserDemographicsReportsData? ud;
//   bool isLoading = true;

//   DateTime startDate = DateTime.now();
//   String timeFrame = "This Month";
//   final timeCategoryCounts = <String, Map<String, int>>{};

//   @override
//   void initState() {
//     super.initState();
//     _loadReportsdData();
//     fetchUserName();
//   }

//   void _onReportTypeChanged(String newValue) {
//     // ADD THIS METHOD
//     setState(() {
//       selectedReportType = newValue;
//     });
//     // No need to reload data, just filter display
//   }

//   String? userName;
//   bool isNameLoading = true;

//   Future<void> fetchUserName() async {
//     final currentUser = FirebaseAuth.instance.currentUser;
//     if (currentUser != null) {
//       final userDoc =
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(currentUser.uid)
//               .get();
//       if (userDoc.exists) {
//         setState(() {
//           userName = userDoc.data()?['name'] ?? 'User';
//           isNameLoading = false;
//         });
//       } else {
//         setState(() {
//           userName = 'User';
//           isNameLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _loadReportsdData() async {
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       InquiryReportsData inqData = await _firebaseService.getInquiryReportsData(
//         selectedTimeFrame,
//       );

//       ChatbotUsageReportsData cbData = await _firebaseService
//           .getChatbotUsageReportsData(selectedTimeFrame);

//       UserDemographicsReportsData udData = await _firebaseService
//           .getUserDemographicsReportsData(selectedTimeFrame);

//       if (!mounted) return; // <== ✅ safety check
//       setState(() {
//         inq = inqData;
//         cb = cbData;
//         ud = udData;
//         isLoading = false;
//       });
//     } catch (e) {
//       print('Error loading dashboard data: $e');
//       if (!mounted) return; // <== ✅ safety check
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }

//   void _onTimeFrameChanged(String newValue) {
//     setState(() {
//       selectedTimeFrame = newValue;
//     });
//     _loadReportsdData();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (isLoading || isNameLoading || userName == null) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return ResponsiveLayout(
//       mobileBody: MobileDashboard(
//         selectedTimeFrame: selectedTimeFrame,
//         selectedReportType: selectedReportType, // ADD THIS
//         onTimeFrameChanged: _onTimeFrameChanged,
//         onReportTypeChanged: _onReportTypeChanged, // ADD THIS
//         inq: inq,
//         cb: cb,
//         ud: ud,
//         userName: userName!,
//         startDate: startDate,
//         timeCategoryCounts: timeCategoryCounts,
//         timeFrame: timeFrame,
//       ),
//       tabletBody: TabletDashboard(
//         selectedTimeFrame: selectedTimeFrame,
//         selectedReportType: selectedReportType, // ADD THIS
//         onTimeFrameChanged: _onTimeFrameChanged,
//         onReportTypeChanged: _onReportTypeChanged, // ADD THIS
//         inq: inq,
//         cb: cb,
//         ud: ud,
//         userName: userName!,
//             startDate: startDate,
//         timeCategoryCounts: timeCategoryCounts,
//         timeFrame: timeFrame,
//       ),
//       desktopBody: DesktopDashboard(
//         selectedTimeFrame: selectedTimeFrame,
//         selectedReportType: selectedReportType, // ADD THIS
//         onTimeFrameChanged: _onTimeFrameChanged,
//         onReportTypeChanged: _onReportTypeChanged, // ADD THIS
//         inq: inq,
//         cb: cb,
//         ud: ud,
//         userName: userName!,
//             startDate: startDate,
//         timeCategoryCounts: timeCategoryCounts,
//         timeFrame: timeFrame,
//       ),
//     );
//   }
// }

// // Desktop Dashboard
// class DesktopDashboard extends StatelessWidget {
//   final String selectedTimeFrame;
//   final String selectedReportType; // ADD THIS
//   final ValueChanged<String> onTimeFrameChanged;
//   final ValueChanged<String> onReportTypeChanged; // ADD THIS
//   final InquiryReportsData? inq;
//   final ChatbotUsageReportsData? cb;
//   final UserDemographicsReportsData? ud;
//   final String userName;

//   final DateTime startDate;
//   final String timeFrame;
//   final Map<String, Map<String, int>> timeCategoryCounts;

//   const DesktopDashboard({
//     super.key,
//     required this.selectedTimeFrame,
//     required this.selectedReportType, // ADD THIS
//     required this.onTimeFrameChanged,
//     required this.onReportTypeChanged, // ADD THIS

//     this.inq,
//     this.cb,
//     this.ud,
//     required this.userName,

//     required this.startDate,
//     required this.timeCategoryCounts,
//     required this.timeFrame,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Header - Fixed at top
//             buildHeader(
//               selectedTimeFrame,
//               selectedReportType, // ADD THIS
//               onTimeFrameChanged,
//               onReportTypeChanged, // ADD THIS
//               userName,
//             ),
//             const SizedBox(height: 32),

//             ...ReportsHelper.buildReportContent(
//               selectedReportType,
//               inq,
//               cb,
//               ud,
//               startDate,
//               timeFrame,
//               timeCategoryCounts,
//               isDesktop: true,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Tablet Dashboard
// class TabletDashboard extends StatelessWidget {
//   final String selectedTimeFrame;
//   final String selectedReportType; // ADD THIS
//   final ValueChanged<String> onTimeFrameChanged;
//   final ValueChanged<String> onReportTypeChanged; // ADD THIS
//   final InquiryReportsData? inq;
//   final ChatbotUsageReportsData? cb;
//   final UserDemographicsReportsData? ud;
//   final String userName;

//   final DateTime startDate;
//   final String timeFrame;
//   final Map<String, Map<String, int>> timeCategoryCounts;

//   const TabletDashboard({
//     super.key,
//     required this.selectedTimeFrame,
//     required this.selectedReportType, // ADD THIS
//     required this.onTimeFrameChanged,
//     required this.onReportTypeChanged, // ADD THIS
//     this.inq,
//     this.cb,
//     this.ud,
//     required this.startDate,
//     required this.timeCategoryCounts,
//     required this.timeFrame,
//     required this.userName,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             buildHeader(
//               selectedTimeFrame,
//               selectedReportType, // ADD THIS
//               onTimeFrameChanged,
//               onReportTypeChanged, // ADD THIS
//               userName,
//             ),
//             const SizedBox(height: 32),

//             // Top row with 4 stat cards
//             ...ReportsHelper.buildReportContent(
//               selectedReportType,
//               inq,
//               cb,
//               ud,
//               startDate,
//               timeFrame,
//               timeCategoryCounts,
//               isDesktop: true,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Mobile Dashboard
// class MobileDashboard extends StatelessWidget {
//   final String selectedTimeFrame;
//   final String selectedReportType; // ADD THIS
//   final ValueChanged<String> onTimeFrameChanged;
//   final ValueChanged<String> onReportTypeChanged; // ADD THIS
//   final InquiryReportsData? inq;
//   final ChatbotUsageReportsData? cb;
//   final UserDemographicsReportsData? ud;
//   final String userName;

//   final DateTime startDate;
//   final String timeFrame;
//   final Map<String, Map<String, int>> timeCategoryCounts;

//   const MobileDashboard({
//     super.key,
//     required this.selectedTimeFrame,
//     required this.selectedReportType, // ADD THIS
//     required this.onTimeFrameChanged,
//     required this.onReportTypeChanged, // ADD THIS
//     this.inq,
//     this.cb,
//     this.ud,
//     required this.userName,
//     required this.startDate,
//     required this.timeCategoryCounts,
//     required this.timeFrame,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             buildHeader(
//               selectedTimeFrame,
//               selectedReportType, // ADD THIS
//               onTimeFrameChanged,
//               onReportTypeChanged, // ADD THIS
//               userName,
//             ),
//             const SizedBox(height: 32),

//             ...ReportsHelper.buildReportContent(
//               selectedReportType,
//               inq,
//               cb,
//               ud,
//               startDate,
//               timeFrame,
//               timeCategoryCounts,
//               isDesktop: true,
//             ),
//             const SizedBox(height: 32),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class ReportsHelper {
//   static List<Widget> buildReportContent(
//     String reportType,
//     InquiryReportsData? inq,
//     ChatbotUsageReportsData? cb,
//     UserDemographicsReportsData? ud,
//     DateTime startDate,
//     String timeFrame,
//     Map<String, Map<String, int>> timeCategoryCounts, {
//     bool isDesktop = false,
//     bool isTablet = false,
//     bool isMobile = false,
//   }) {
//     switch (reportType) {
//       case 'Inquiry Trends':
//         return buildInquiryTrendsReport(inq, isDesktop: isDesktop);
//       default:
//         return buildInquiryTrendsReport(inq, isDesktop: isDesktop);
//     }
//   }
// }


// List<Widget> buildInquiryTrendsReport(
//   InquiryReportsData? data, {
//   bool isDesktop = false,
// }) {
//   return [
    
//     SizedBox(
//       height: 120,
//       child: Row(
//         children: [
//           Expanded(
//             child: buildStatCard(
//               'Total Messages',
//               '${data?.totalMessages ?? 0}',
//               Colors.blue,
//               Icons.message,
//             ),
//           ),
//           const SizedBox(width: 20),
//           Expanded(
//             child: buildStatCard(
//               'Answered Messages',
//               '${data?.answeredMessages ?? 0}',
//               Colors.green,
//               Icons.check_circle,
//             ),
//           ),
//           const SizedBox(width: 20),
//           Expanded(
//             child: buildStatCard(
//               'Unanswered Messages',
//               '${data?.unAnsweredMessages ?? 0}',
//               Colors.red,
//               Icons.people,
//             ),
//           ),
//           const SizedBox(width: 20),
//           Expanded(
//             child: buildStatCard(
//               'Escalated Messages',
//               data?.escalatedMessages.toString() ?? '0',
//               Colors.orange,
//               Icons.help,
//             ),
//           ),
//         ],
//       ),
//     ),

//     const SizedBox(height: 16),

//     // Inquiry Pattern
//     SizedBox(
//       height: 400,
//       child: Row(
//         children: [
//           Expanded(child: buildInquiryTrendCard(data?.inquiryTrend ?? [])),
//         ],
//       ),
//     ),
//     const SizedBox(height: 16),

//     // Category Distribution and FAQs
    
   
//     SizedBox(
//       height: 400,
//       child: Row(
//         children: [
//           Expanded(
//             child: buildCategoryDistributionCard(
//               data?.categoryDistribution ?? {},
//             ),
//           ),
//           const SizedBox(width: 20),
//           Expanded(child: buildHighestFAQCard(data?.highestFAQs ?? {})),
//         ],
//       ),
//     ),

//     const SizedBox(height: 16),
//     SizedBox(
//       height: 400,
//       child: Row(
//         children: [
        
//           const SizedBox(width: 20),
//           Expanded(child: buildSeasonalTrendsCard(data?.seasonalTrends ?? {})),
//         ],
//       ),
//     ),

//     const SizedBox(height: 16),
    
//   ];
// }




// Widget buildHeader(
//   String selectedTimeFrame,
//   String selectedReportType, // ADD THIS
//   ValueChanged<String> onTimeFrameChanged,
//   ValueChanged<String> onReportTypeChanged, // ADD THIS
//   String userName,
// ) {
//   return LayoutBuilder(
//     builder: (context, constraints) {
//       double screenWidth = MediaQuery.of(context).size.width;
//       bool isMobile = screenWidth < 600;

//       return Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           isMobile
//               ? Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Reports and Analytics',
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 12),
         
//                   CustomDropdownButton(
//                     items: [
//                       'All',
//                       'Today',
//                       'This Week',
//                       'This Month',
//                       'This Year',
//                     ],
//                     initialValue: selectedTimeFrame,
//                     onChanged: onTimeFrameChanged,
//                   ),
//                 ],
//               )
//               : Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Reports and Analytics',
//                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                   ),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
                     
//                       CustomDropdownButton(
//                         items: [
//                           'All',
//                           'Today',
//                           'This Week',
//                           'This Month',
//                           'This Year',
//                         ],
//                         initialValue: selectedTimeFrame,
//                         onChanged: onTimeFrameChanged,
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//           SizedBox(height: isMobile ? 12 : 8),
//           Text(
//             _getReportDescription(
//               selectedReportType,
//               selectedTimeFrame,
//             ), // MODIFY THIS
//             style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey),
//           ),
//         ],
//       );
//     },
//   );
// }

// String _getReportDescription(String reportType, String timeFrame) {
//   switch (reportType) {
//     case 'Inquiry Trends':
//       return "Detailed analysis of inquiry patterns and trends for $timeFrame.";
//     case 'Chatbot Usage':
//       return "Chatbot performance metrics and usage statistics for $timeFrame.";
//     case 'User Demographics':
//       return "User demographics and engagement patterns for $timeFrame.";
//     default:
//       return "Here's a complete reports and analytics of OASP Assist for $timeFrame.";
//   }
// }
