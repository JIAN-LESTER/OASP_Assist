import 'dart:io';
import 'dart:convert' show utf8;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/admin_dashboard_data.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/inquiry_trends_data.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/chatbot_usage_data.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/user_demographics_data.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

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
        _buildPDFHeader('Dashboard Report', userName, timeFrame, dateFormat.format(now)),
        pw.SizedBox(height: 20),

        // Overview Stats
        _buildPDFSection('Overview Statistics'),
        _buildStatsTable([
          ['Total Messages', '${inq?.totalMessages ?? 0}'],
          ['Total Users', '${ud?.totalUsers ?? 0}'],
          ['All Escalations', '${inq?.allEscalations ?? 0}'],
          ['Pending Escalations', '${ad?.pendingEscalations ?? 0}'],
          ['Resolved Escalations', '${ad?.resolvedEscalations ?? 0}'],
          ['Escalation Rate', '${inq?.escalationRate.toStringAsFixed(1) ?? 0}%'],
          ['Resolution Rate', '${inq?.resolutionRate.toStringAsFixed(1) ?? 0}%'],
        ]),
        pw.SizedBox(height: 20),

        // Inquiry Trends Over Time
        if (inq?.inquiryTrend.isNotEmpty ?? false) ...[
          _buildPDFSection('Inquiry Trends Over Time'),
          _buildKeyValueTable(
            Map.fromEntries(inq!.inquiryTrend.map((e) => MapEntry(e.date, e.count))),
          ),
          pw.SizedBox(height: 20),
        ],

        // System Logs
        if (inq?.recentLogs.isNotEmpty ?? false) ...[
          _buildPDFSection('Recent System Logs'),
          ...inq!.recentLogs.take(10).map((log) => 
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                '${log.time}: ${log.action}',
                style: pw.TextStyle(fontSize: 9),
              ),
            ),
          ),
          pw.SizedBox(height: 20),
        ],

        // Message Logs
        if (inq?.msgLogs.isNotEmpty ?? false) ...[
          _buildPDFSection('Recent Message Logs'),
          ...inq!.msgLogs.take(10).map((log) => 
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                '${log.time}: ${log.user} - ${log.message}',
                style: pw.TextStyle(fontSize: 9),
              ),
            ),
          ),
          pw.SizedBox(height: 20),
        ],

        // Escalations Over Time
        if (inq?.escalationsOverTime.isNotEmpty ?? false) ...[
          _buildPDFSection('Escalations Over Time'),
          _buildKeyValueTable(
            Map.fromEntries(inq!.escalationsOverTime.map((e) => MapEntry(e.date, e.count))),
          ),
          pw.SizedBox(height: 20),
        ],

        // Escalated Messages List
        if (ad?.topEscalatedMessages.isNotEmpty ?? false) ...[
          _buildPDFSection('Top Escalated Messages'),
          ...ad!.topEscalatedMessages.take(10).map((msg) => 
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                '• ${msg.userMessage} (${msg.status})',
                style: pw.TextStyle(fontSize: 9),
              ),
            ),
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

        // Inquiry Trends Over Time
        if (data?.inquiryTrend.isNotEmpty ?? false) ...[
          _buildPDFSection('Inquiry Trends Over Time'),
          _buildKeyValueTable(
            Map.fromEntries(data!.inquiryTrend.map((e) => MapEntry(e.date, e.count))),
          ),
          pw.SizedBox(height: 20),
        ],

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

        // Escalations Over Time
        if (data?.escalationsOverTime.isNotEmpty ?? false) ...[
          _buildPDFSection('Escalations Over Time'),
          _buildKeyValueTable(
            Map.fromEntries(data!.escalationsOverTime.map((e) => MapEntry(e.date, e.count))),
          ),
          pw.SizedBox(height: 20),
        ],

        // Staff Performance
        if (data?.staffPerformance.isNotEmpty ?? false) ...[
          _buildPDFSection('Staff Performance'),
          _buildKeyValueTable(
            data!.staffPerformance.map((k, v) => MapEntry(k, v.toStringAsFixed(1) + '%')),
          ),
          pw.SizedBox(height: 20),
        ],

        // Escalated Messages List
        if (ad?.topEscalatedMessages.isNotEmpty ?? false) ...[
          _buildPDFSection('Top Escalated Messages'),
          ...ad!.topEscalatedMessages.take(10).map((msg) => 
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                '• ${msg.userMessage} (${msg.status})',
                style: pw.TextStyle(fontSize: 9),
              ),
            ),
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

          // Peak Usage by Hour
          if (data?.peakUsageByHour.isNotEmpty ?? false) ...[
            _buildPDFSection('Peak Usage by Hour'),
            _buildKeyValueTable(
              data!.peakUsageByHour.map((k, v) => MapEntry('${k}:00', v)),
            ),
            pw.SizedBox(height: 20),
          ],

          // Conversations Over Time
          if (data?.conversationsOverTime.isNotEmpty ?? false) ...[
            _buildPDFSection('Conversations Over Time'),
            _buildKeyValueTable(
              Map.fromEntries(data!.conversationsOverTime.map((e) => MapEntry(e.date, e.count))),
            ),
            pw.SizedBox(height: 20),
          ],

          // Chat Limit Reach Trend
          if (data?.chatLimitReachTrend.isNotEmpty ?? false) ...[
            _buildPDFSection('Chat Limit Reach Trend'),
            _buildKeyValueTable(
              Map.fromEntries(data!.chatLimitReachTrend.map((e) => MapEntry(e.date, e.count))),
            ),
            pw.SizedBox(height: 20),
          ],

          // Response Time Trend
          if (data?.responseTimeTrend.isNotEmpty ?? false) ...[
            _buildPDFSection('Response Time Trend'),
            _buildKeyValueTable(
              Map.fromEntries(data!.responseTimeTrend.map((e) => MapEntry(e.date, e.count))),
            ),
            pw.SizedBox(height: 20),
          ],

          // Escalation Limit Reach Trend
          if (data?.escalationLimitReachTrend.isNotEmpty ?? false) ...[
            _buildPDFSection('Escalation Limit Reach Trend'),
            _buildKeyValueTable(
              Map.fromEntries(data!.escalationLimitReachTrend.map((e) => MapEntry(e.date, e.count))),
            ),
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
            ['Active/Inactive Ratio', data?.activeUserRatio ?? 'N/A'],
            ['Enrolled Students', '${data?.enrolledStudents ?? 0}'],
            ['Incoming Freshmen', '${data?.incomingFreshmen ?? 0}'],
            ['Enrolled/Freshman Ratio', data?.enrolledRatio ?? 'N/A'],
            ['With Scholarship', '${data?.usersWithScholarship ?? 0}'],
            ['Without Scholarship', '${data?.usersWithoutScholarship ?? 0}'],
          ]),
          pw.SizedBox(height: 20),

          // User Growth Over Time
          if (data?.userGrowthOverTime.isNotEmpty ?? false) ...[
            _buildPDFSection('User Growth Over Time'),
            _buildKeyValueTable(
              Map.fromEntries(data!.userGrowthOverTime.map((e) => MapEntry(e.date, e.count))),
            ),
            pw.SizedBox(height: 20),
          ],

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

          // User Affiliations
          if (data?.userAffiliations.isNotEmpty ?? false) ...[
            _buildPDFSection('User Affiliations'),
            _buildKeyValueTable(data!.userAffiliations),
            pw.SizedBox(height: 20),
          ],

          // Scholarship Distribution
          if (data?.scholarshipDistribution.isNotEmpty ?? false) ...[
            _buildPDFSection('Scholarship Types Distribution'),
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
    ['Overview Statistics'],
    ['Metric', 'Value'],
    ['Total Messages', inq?.totalMessages ?? 0],
    ['Total Users', ud?.totalUsers ?? 0],
    ['All Escalations', inq?.allEscalations ?? 0],
    ['Pending Escalations', ad?.pendingEscalations ?? 0],
    ['Resolved Escalations', ad?.resolvedEscalations ?? 0],
    ['Escalation Rate', '${inq?.escalationRate.toStringAsFixed(1) ?? 0}%'],
    ['Resolution Rate', '${inq?.resolutionRate.toStringAsFixed(1) ?? 0}%'],
    [],
    ['Inquiry Trends Over Time'],
    ['Date', 'Count'],
  ];

  if (inq?.inquiryTrend.isNotEmpty ?? false) {
    rows.addAll(inq!.inquiryTrend.map((d) => [d.date, d.count]));
  }

  rows.addAll([
    [],
    ['Recent System Logs'],
    ['Timestamp', 'Action', 'Details'],
  ]);

  if (inq?.recentLogs.isNotEmpty ?? false) {
    rows.addAll(inq!.recentLogs.take(10).map((log) => [
      log.time,
      log.action,
 
    ]));
  }

  rows.addAll([
    [],
    ['Recent Message Logs'],
    ['Timestamp', 'Sender', 'Message'],
  ]);

  if (inq?.msgLogs.isNotEmpty ?? false) {
    rows.addAll(inq!.msgLogs.take(10).map((log) => [
      log.time,
      log.user,
      log.message,
    ]));
  }

  rows.addAll([
    [],
    ['Escalations Over Time'],
    ['Date', 'Count'],
  ]);

  if (inq?.escalationsOverTime.isNotEmpty ?? false) {
    rows.addAll(inq!.escalationsOverTime.map((d) => [d.date, d.count]));
  }

  rows.addAll([
    [],
    ['Top Escalated Messages'],
    ['Question', 'Status'],
  ]);

  if (ad?.topEscalatedMessages.isNotEmpty ?? false) {
    rows.addAll(ad!.topEscalatedMessages.take(10).map((msg) => [
      msg.userMessage,
      msg.status,
    ]));
  }

  return await _saveCSV(rows, 'Dashboard_Report_$timeFrame');
}


  /// Export Inquiry Trends to CSV
static Future<String> exportInquiryTrendsToCSV({
  required String timeFrame,
  required InquiryReportsData? data,
  required AdminDashboardData? ad,
}) async {
  List<List<dynamic>> rows = [
    ['Inquiry Trends Report - $timeFrame'],
    ['Generated:', DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())],
    [],
    ['Key Metrics'],
    ['Metric', 'Value'],
    ['User Messages', data?.userMessages ?? 0],
    ['Bot Messages', data?.botMessages ?? 0],
    ['Pending Escalations', data?.escalatedMessages ?? 0],
    ['Resolved Messages', data?.resolvedMessages ?? 0],
    ['Escalation Rate', '${data?.escalationRate.toStringAsFixed(1) ?? 0}%'],
    ['Resolution Rate', '${data?.resolutionRate.toStringAsFixed(1) ?? 0}%'],
    [],
    ['Inquiry Trends Over Time'],
    ['Date', 'Count'],
  ];

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

  rows.addAll([
    [],
    ['Top Questions'],
    ['Question', 'Count'],
  ]);

  if (data?.topQuestions.isNotEmpty ?? false) {
    rows.addAll(data!.topQuestions.entries.map((e) => [e.key, e.value]));
  }

  rows.addAll([
    [],
    ['Escalations Over Time'],
    ['Date', 'Count'],
  ]);

  if (data?.escalationsOverTime.isNotEmpty ?? false) {
    rows.addAll(data!.escalationsOverTime.map((d) => [d.date, d.count]));
  }

  rows.addAll([
    [],
    ['Staff Performance'],
    ['Staff', 'Resolution Rate %'],
  ]);

  if (data?.staffPerformance.isNotEmpty ?? false) {
    rows.addAll(data!.staffPerformance.entries.map((e) => [e.key, e.value.toStringAsFixed(1)]));
  }

  rows.addAll([
    [],
    ['Top Escalated Messages'],
    ['Question', 'Status'],
  ]);

  if (ad?.topEscalatedMessages.isNotEmpty ?? false) {
    rows.addAll(ad!.topEscalatedMessages.take(10).map((msg) => [
      msg.userMessage,
      msg.status,
    ]));
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
      ['Peak Usage by Hour'],
      ['Hour', 'Count'],
    ];

    if (data?.peakUsageByHour.isNotEmpty ?? false) {
      rows.addAll(data!.peakUsageByHour.entries.map((e) => ['${e.key}:00', e.value]));
    }

    rows.addAll([
      [],
      ['Conversations Over Time'],
      ['Date', 'Count'],
    ]);

    if (data?.conversationsOverTime.isNotEmpty ?? false) {
      rows.addAll(data!.conversationsOverTime.map((d) => [d.date, d.count]));
    }

    rows.addAll([
      [],
      ['Chat Limit Reach Trend'],
      ['Date', 'Count'],
    ]);

    if (data?.chatLimitReachTrend.isNotEmpty ?? false) {
      rows.addAll(data!.chatLimitReachTrend.map((d) => [d.date, d.count]));
    }

    rows.addAll([
      [],
      ['Response Time Trend'],
      ['Date', 'Response Time (ms)'],
    ]);

    if (data?.responseTimeTrend.isNotEmpty ?? false) {
      rows.addAll(data!.responseTimeTrend.map((d) => [d.date, d.count]));
    }

    rows.addAll([
      [],
      ['Escalation Limit Reach Trend'],
      ['Date', 'Count'],
    ]);

    if (data?.escalationLimitReachTrend.isNotEmpty ?? false) {
      rows.addAll(data!.escalationLimitReachTrend.map((d) => [d.date, d.count]));
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
      ['Active/Inactive Ratio', data?.activeUserRatio ?? 'N/A'],
      ['Enrolled Students', data?.enrolledStudents ?? 0],
      ['Incoming Freshmen', data?.incomingFreshmen ?? 0],
      ['Enrolled/Freshman Ratio', data?.enrolledRatio ?? 'N/A'],
      [],
      ['User Growth Over Time'],
      ['Date', 'Count'],
    ];

    if (data?.userGrowthOverTime.isNotEmpty ?? false) {
      rows.addAll(data!.userGrowthOverTime.map((d) => [d.date, d.count]));
    }

    rows.addAll([
      [],
      ['Users by Program'],
      ['Program', 'Count'],
    ]);

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

    rows.addAll([
      [],
      ['User Affiliations'],
      ['Affiliation', 'Count'],
    ]);

    if (data?.userAffiliations.isNotEmpty ?? false) {
      rows.addAll(data!.userAffiliations.entries.map((e) => [e.key, e.value]));
    }

    rows.addAll([
      [],
      ['Scholarship Distribution'],
      ['With Scholarship', data?.usersWithScholarship ?? 0],
      ['Without Scholarship', data?.usersWithoutScholarship ?? 0],
      [],
      ['Scholarship Types'],
      ['Type', 'Count'],
    ]);

    if (data?.scholarshipDistribution.isNotEmpty ?? false) {
      rows.addAll(data!.scholarshipDistribution.entries.map((e) => [e.key, e.value]));
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
      
      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', '$filename.pdf')
          ..click();
        html.Url.revokeObjectUrl(url);
        return 'Downloaded: $filename.pdf';
      } else {
        Directory? dir;
        
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
          if (!await dir.exists()) {
            dir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          dir = await getApplicationDocumentsDirectory();
        } else {
          if (Platform.isWindows) {
            final home = Platform.environment['USERPROFILE'];
            dir = Directory('$home\\Downloads');
          } else if (Platform.isMacOS || Platform.isLinux) {
            final home = Platform.environment['HOME'];
            dir = Directory('$home/Downloads');
          } else {
            dir = await getApplicationDocumentsDirectory();
          }
        }
        
        if (dir == null || !await dir.exists()) {
          throw Exception('Could not access storage directory');
        }
        
        final file = File('${dir.path}/$filename.pdf');
        await file.writeAsBytes(bytes);
        
        print('✅ PDF saved to: ${file.path}');
        
        try {
          await OpenFile.open(file.path);
        } catch (openError) {
          print('Could not auto-open file: $openError');
        }
        
        return file.path;
      }
    } catch (e) {
      print('❌ Error saving PDF: $e');
      rethrow;
    }
  }

  static Future<String> _saveCSV(List<List<dynamic>> rows, String filename) async {
    try {
      final csvContent = csv.encode(rows);
      
      if (kIsWeb) {
        final bytes = utf8.encode(csvContent);
        final blob = html.Blob([bytes], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', '$filename.csv')
          ..click();
        html.Url.revokeObjectUrl(url);
        return 'Downloaded: $filename.csv';
      } else {
        Directory? dir;
        
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
          if (!await dir.exists()) {
            dir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          dir = await getApplicationDocumentsDirectory();
        } else {
          if (Platform.isWindows) {
            final home = Platform.environment['USERPROFILE'];
            dir = Directory('$home\\Downloads');
          } else if (Platform.isMacOS || Platform.isLinux) {
            final home = Platform.environment['HOME'];
            dir = Directory('$home/Downloads');
          } else {
            dir = await getApplicationDocumentsDirectory();
          }
        }
        
        if (dir == null || !await dir.exists()) {
          throw Exception('Could not access storage directory');
        }
        
        final file = File('${dir.path}/$filename.csv');
        await file.writeAsString(csvContent);
        
        print('✅ CSV saved to: ${file.path}');
        
        try {
          await OpenFile.open(file.path);
        } catch (openError) {
          print('Could not auto-open file: $openError');
        }
        
        return file.path;
      }
    } catch (e) {
      print('❌ Error saving CSV: $e');
      rethrow;
    }
  }
}
