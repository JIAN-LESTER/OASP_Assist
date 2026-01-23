import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/admin_dashboard_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/inquiry_trends_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/chatbot_usage_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/user_demographics_data.dart';
import 'package:flutter/services.dart';

class ExportService {
  // ============================================================================
  // PDF EXPORT
  // ============================================================================

  /// Export Dashboard to PDF
  static Future<String> exportDashboardToPDF({
    required String userName,
    required String timeFrame,
    required InquiryReportsData? inq,
    required UserDemographicsReportsData? ud,
    required AdminDashboardData? ad,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('MMMM dd, yyyy - hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          _buildPDFHeader('Dashboard Report', userName, timeFrame, dateFormat.format(now)),
          pw.SizedBox(height: 20),

          // Overview Stats
          _buildPDFSection('Overview Statistics'),
          _buildStatsTable([
            ['Total Messages', '${inq?.totalMessages ?? 0}'],
            ['Total Users', '${ud?.totalUsers ?? 0}'],
            ['Pending Escalations', '${ad?.pendingEscalations ?? 0}'],
            ['Resolved Escalations', '${ad?.resolvedEscalations ?? 0}'],
            ['Escalation Rate', '${inq?.escalationRate.toStringAsFixed(1) ?? 0}%'],
            ['Resolution Rate', '${inq?.resolutionRate.toStringAsFixed(1) ?? 0}%'],
          ]),
          pw.SizedBox(height: 20),

          // Category Distribution
          if (inq?.categoryDistribution.isNotEmpty ?? false) ...[
            _buildPDFSection('Category Distribution'),
            _buildKeyValueTable(inq!.categoryDistribution),
            pw.SizedBox(height: 20),
          ],

          // Top Questions
          if (inq?.topQuestions.isNotEmpty ?? false) ...[
            _buildPDFSection('Top Questions'),
            _buildKeyValueTable(inq!.topQuestions),
            pw.SizedBox(height: 20),
          ],

          // Staff Performance
          if (inq?.staffPerformance.isNotEmpty ?? false) ...[
            _buildPDFSection('Staff Performance'),
            _buildKeyValueTable(
              inq!.staffPerformance.map((k, v) => MapEntry(k, v.toStringAsFixed(1) + '%')),
            ),
          ],
        ],
      ),
    );

   return await _savePDF(pdf, 'Dashboard_Report_$timeFrame');
  }

  /// Export Inquiry Trends Report to PDF
  static Future<String> exportInquiryTrendsToPDF({
    required String timeFrame,
    required InquiryReportsData? data,
    required AdminDashboardData? ad,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('MMMM dd, yyyy - hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildPDFHeader('Inquiry Trends Report', 'Admin', timeFrame, dateFormat.format(now)),
          pw.SizedBox(height: 20),

          // Key Metrics
          _buildPDFSection('Key Metrics'),
          _buildStatsTable([
            ['User Messages', '${data?.userMessages ?? 0}'],
            ['Bot Messages', '${data?.botMessages ?? 0}'],
            ['Pending Escalations', '${data?.escalatedMessages ?? 0}'],
            ['Resolved Messages', '${data?.resolvedMessages ?? 0}'],
            ['Escalation Rate', '${data?.escalationRate.toStringAsFixed(1) ?? 0}%'],
            ['Resolution Rate', '${data?.resolutionRate.toStringAsFixed(1) ?? 0}%'],
          ]),
          pw.SizedBox(height: 20),

          // Category Distribution
          if (data?.categoryDistribution.isNotEmpty ?? false) ...[
            _buildPDFSection('Category Distribution'),
            _buildKeyValueTable(data!.categoryDistribution),
            pw.SizedBox(height: 20),
          ],

          // Top FAQs
          if (data?.topQuestions.isNotEmpty ?? false) ...[
            _buildPDFSection('Top Questions'),
            ...data!.topQuestions.entries.map((e) => 
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text('• ${e.key} (${e.value} times)', style: pw.TextStyle(fontSize: 10)),
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          // Staff Performance
          if (data?.staffPerformance.isNotEmpty ?? false) ...[
            _buildPDFSection('Staff Performance'),
            _buildKeyValueTable(
              data!.staffPerformance.map((k, v) => MapEntry(k, v.toStringAsFixed(1) + '%')),
            ),
          ],
        ],
      ),
    );

    return await _savePDF(pdf, 'Inquiry_Trends_$timeFrame');
  }

  /// Export Chatbot Usage Report to PDF
  static Future<String> exportChatbotUsageToPDF({
    required String timeFrame,
    required ChatbotUsageReportsData? data,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('MMMM dd, yyyy - hh:mm a');

    String formatTime(double seconds) {
      if (seconds == 0) return 'N/A';
      if (seconds < 1) return '${(seconds * 1000).toInt()}ms';
      return '${seconds.toStringAsFixed(2)}s';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildPDFHeader('Chatbot Usage Report', 'Admin', timeFrame, dateFormat.format(now)),
          pw.SizedBox(height: 20),

          _buildPDFSection('Performance Metrics'),
          _buildStatsTable([
            ['Average Response Time', formatTime(data?.averageResponseTime ?? 0)],
            ['Total Conversations', '${data?.totalConversations ?? 0}'],
            ['Avg Messages/User', '${data?.averageMessagesPerUser.toStringAsFixed(1) ?? 0}'],
            ['Chat Limit Reach Rate', '${data?.chatLimitReachRate.toStringAsFixed(1) ?? 0}%'],
            ['Escalation Limit Rate', '${data?.escalationLimitReachRate.toStringAsFixed(1) ?? 0}%'],
          ]),
          pw.SizedBox(height: 20),

          // Unanswered Reasons
          if (data?.unansweredReasonsDistribution.isNotEmpty ?? false) ...[
            _buildPDFSection('Unanswered Reasons Distribution'),
            _buildKeyValueTable(data!.unansweredReasonsDistribution),
          ],
        ],
      ),
    );

    return await _savePDF(pdf, 'Chatbot_Usage_$timeFrame');
  }

  /// Export User Demographics Report to PDF
  static Future<String> exportUserDemographicsToPDF({
    required String timeFrame,
    required UserDemographicsReportsData? data,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('MMMM dd, yyyy - hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildPDFHeader('User Demographics Report', 'Admin', timeFrame, dateFormat.format(now)),
          pw.SizedBox(height: 20),

          _buildPDFSection('User Statistics'),
          _buildStatsTable([
            ['Total Users', '${data?.totalUsers ?? 0}'],
            ['New Users', '${data?.newUsers ?? 0}'],
            ['Active Users', '${data?.activeUsers ?? 0}'],
            ['Inactive Users', '${data?.inactiveUsers ?? 0}'],
            ['Enrolled Students', '${data?.enrolledStudents ?? 0}'],
            ['Incoming Freshmen', '${data?.incomingFreshmen ?? 0}'],
            ['With Scholarship', '${data?.usersWithScholarship ?? 0}'],
            ['Without Scholarship', '${data?.usersWithoutScholarship ?? 0}'],
          ]),
          pw.SizedBox(height: 20),

          // Users by Program
          if (data?.usersByProgram.isNotEmpty ?? false) ...[
            _buildPDFSection('Users by Program'),
            _buildKeyValueTable(data!.usersByProgram),
            pw.SizedBox(height: 20),
          ],

          // Users by Year
          if (data?.usersByYear.isNotEmpty ?? false) ...[
            _buildPDFSection('Users by Year Level'),
            _buildKeyValueTable(data!.usersByYear),
            pw.SizedBox(height: 20),
          ],

          // Affiliations
          if (data?.userAffiliations.isNotEmpty ?? false) ...[
            _buildPDFSection('User Affiliations'),
            _buildKeyValueTable(data!.userAffiliations),
            pw.SizedBox(height: 20),
          ],

          // Scholarship Distribution
          if (data?.scholarshipDistribution.isNotEmpty ?? false) ...[
            _buildPDFSection('Scholarship Distribution'),
            _buildKeyValueTable(data!.scholarshipDistribution),
          ],
        ],
      ),
    );

    return await _savePDF(pdf, 'User_Demographics_$timeFrame');
  }

  // ============================================================================
  // CSV EXPORT
  // ============================================================================

  /// Export Dashboard to CSV
  static Future<String> exportDashboardToCSV({
    required String timeFrame,
    required InquiryReportsData? inq,
    required UserDemographicsReportsData? ud,
    required AdminDashboardData? ad,
  }) async {
    List<List<dynamic>> rows = [
      ['Dashboard Report - $timeFrame'],
      ['Generated:', DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())],
      [],
      ['Metric', 'Value'],
      ['Total Messages', inq?.totalMessages ?? 0],
      ['Total Users', ud?.totalUsers ?? 0],
      ['Pending Escalations', ad?.pendingEscalations ?? 0],
      ['Resolved Escalations', ad?.resolvedEscalations ?? 0],
      ['Escalation Rate', '${inq?.escalationRate.toStringAsFixed(1) ?? 0}%'],
      ['Resolution Rate', '${inq?.resolutionRate.toStringAsFixed(1) ?? 0}%'],
      [],
      ['Category Distribution'],
      ['Category', 'Count'],
    ];

    // Add category data
    if (inq?.categoryDistribution.isNotEmpty ?? false) {
      rows.addAll(inq!.categoryDistribution.entries.map((e) => [e.key, e.value]));
    }

   return  await _saveCSV(rows, 'Dashboard_Report_$timeFrame');
  }

  /// Export Inquiry Trends to CSV
  static Future<String> exportInquiryTrendsToCSV({
    required String timeFrame,
    required InquiryReportsData? data,
  }) async {
    List<List<dynamic>> rows = [
      ['Inquiry Trends Report - $timeFrame'],
      ['Generated:', DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())],
      [],
      ['Metric', 'Value'],
      ['User Messages', data?.userMessages ?? 0],
      ['Bot Messages', data?.botMessages ?? 0],
      ['Pending Escalations', data?.escalatedMessages ?? 0],
      ['Resolved Messages', data?.resolvedMessages ?? 0],
      ['Escalation Rate', '${data?.escalationRate.toStringAsFixed(1) ?? 0}%'],
      ['Resolution Rate', '${data?.resolutionRate.toStringAsFixed(1) ?? 0}%'],
      [],
      ['Inquiry Trend Data'],
      ['Date', 'Count'],
    ];

    // Add trend data
    if (data?.inquiryTrend.isNotEmpty ?? false) {
      rows.addAll(data!.inquiryTrend.map((d) => [d.date, d.count]));
    }

    rows.addAll([
      [],
      ['Category Distribution'],
      ['Category', 'Count'],
    ]);

    if (data?.categoryDistribution.isNotEmpty ?? false) {
      rows.addAll(data!.categoryDistribution.entries.map((e) => [e.key, e.value]));
    }

    return await _saveCSV(rows, 'Inquiry_Trends_$timeFrame');
  }

  /// Export Chatbot Usage to CSV
  static Future<String> exportChatbotUsageToCSV({
    required String timeFrame,
    required ChatbotUsageReportsData? data,
  }) async {
    List<List<dynamic>> rows = [
      ['Chatbot Usage Report - $timeFrame'],
      ['Generated:', DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())],
      [],
      ['Metric', 'Value'],
      ['Average Response Time', '${data?.averageResponseTime.toStringAsFixed(2) ?? 0}s'],
      ['Total Conversations', data?.totalConversations ?? 0],
      ['Avg Messages/User', data?.averageMessagesPerUser.toStringAsFixed(1) ?? 0],
      ['Chat Limit Reach Rate', '${data?.chatLimitReachRate.toStringAsFixed(1) ?? 0}%'],
      ['Escalation Limit Rate', '${data?.escalationLimitReachRate.toStringAsFixed(1) ?? 0}%'],
      [],
      ['Conversations Over Time'],
      ['Date', 'Count'],
    ];

    if (data?.conversationsOverTime.isNotEmpty ?? false) {
      rows.addAll(data!.conversationsOverTime.map((d) => [d.date, d.count]));
    }

  return await _saveCSV(rows, 'Chatbot_Usage_$timeFrame');
  }

  /// Export User Demographics to CSV
  static Future<String> exportUserDemographicsToCSV({
    required String timeFrame,
    required UserDemographicsReportsData? data,
  }) async {
    List<List<dynamic>> rows = [
      ['User Demographics Report - $timeFrame'],
      ['Generated:', DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())],
      [],
      ['Metric', 'Value'],
      ['Total Users', data?.totalUsers ?? 0],
      ['New Users', data?.newUsers ?? 0],
      ['Active Users', data?.activeUsers ?? 0],
      ['Inactive Users', data?.inactiveUsers ?? 0],
      ['Enrolled Students', data?.enrolledStudents ?? 0],
      ['Incoming Freshmen', data?.incomingFreshmen ?? 0],
      [],
      ['Users by Program'],
      ['Program', 'Count'],
    ];

    if (data?.usersByProgram.isNotEmpty ?? false) {
      rows.addAll(data!.usersByProgram.entries.map((e) => [e.key, e.value]));
    }

    rows.addAll([
      [],
      ['Users by Year Level'],
      ['Year', 'Count'],
    ]);

    if (data?.usersByYear.isNotEmpty ?? false) {
      rows.addAll(data!.usersByYear.entries.map((e) => [e.key, e.value]));
    }

   return await _saveCSV(rows, 'User_Demographics_$timeFrame');
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  static pw.Widget _buildPDFHeader(String title, String userName, String timeFrame, String date) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Generated by: $userName', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Time Frame: $timeFrame', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(thickness: 2),
      ],
    );
  }

  static pw.Widget _buildPDFSection(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _buildStatsTable(List<List<String>> data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: data.map((row) {
        return pw.TableRow(
          children: row.map((cell) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(cell, style: const pw.TextStyle(fontSize: 10)),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildKeyValueTable(Map<dynamic, dynamic> data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: data.entries.map((e) {
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(e.key.toString(), style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(e.value.toString(), style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        );
      }).toList(),
    );
  }

  static Future<String> _savePDF(pw.Document pdf, String filename) async {
    try {
      final bytes = await pdf.save();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename.pdf');
      await file.writeAsBytes(bytes);
      
      // Try to open file, but don't throw if it fails
      try {
        await OpenFile.open(file.path);
      } catch (openError) {
        print('Could not auto-open file: $openError');
        // File is still saved, just not auto-opened
      }
      
      return file.path;
    } catch (e) {
      print('Error saving PDF: $e');
      rethrow;
    }
  }

  static Future<String> _saveCSV(List<List<dynamic>> rows, String filename) async {
    try {
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename.csv');
      await file.writeAsString(csv);
      
      // Try to open file, but don't throw if it fails
      try {
        await OpenFile.open(file.path);
      } catch (openError) {
        print('Could not auto-open file: $openError');
        // File is still saved, just not auto-opened
      }
      
      return file.path;
    } catch (e) {
      print('Error saving CSV: $e');
      rethrow;
    }
  }
}