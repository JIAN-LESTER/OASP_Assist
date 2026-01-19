import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/reports.dart';

class InquiryReportsData {
  // Stat Cards
  final int totalMessages;
  final int userMessages;
  final int botMessages;
  final int escalatedMessages;
  final double escalationRate;
  final int resolvedMessages;
  final double resolutionRate;

  // Charts
  final List<ChartData> inquiryTrend; // Long chart
  final Map<String, int> categoryDistribution; // Short chart
  final Map<String, int> topQuestions; // Short chart - top FAQs
  final List<ChartData>
  escalationsOverTime; // Long chart with category breakdown
  final Map<String, double>
  staffPerformance; // Staff name -> avg resolution rate
  final Map<String, int> botVsHumanAnswers; // {'bot': count, 'human': count}

  // Logs
  final List<SystemLog> recentLogs;
  final List<MessageLogs> msgLogs;

  const InquiryReportsData({
    required this.totalMessages,
    required this.userMessages,
    required this.botMessages,
    required this.escalatedMessages,
    required this.escalationRate,
    required this.resolvedMessages,
    required this.resolutionRate,
    required this.inquiryTrend,
    required this.categoryDistribution,
    required this.topQuestions,
    required this.escalationsOverTime,
    required this.staffPerformance,
    required this.botVsHumanAnswers,
    required this.recentLogs,
    required this.msgLogs,
  });
}

InquiryReportsData getEmptyInquiryReportsData() {
  return const InquiryReportsData(
    totalMessages: 0,
    userMessages: 0,
    botMessages: 0,
    escalatedMessages: 0,
    escalationRate: 0.0,
    resolvedMessages: 0,
    resolutionRate: 0.0,
    inquiryTrend: [],
    categoryDistribution: {},
    topQuestions: {},
    escalationsOverTime: [],
    staffPerformance: {},
    botVsHumanAnswers: {'bot': 0, 'human': 0},
    recentLogs: [],
    msgLogs: [],
  );
}
