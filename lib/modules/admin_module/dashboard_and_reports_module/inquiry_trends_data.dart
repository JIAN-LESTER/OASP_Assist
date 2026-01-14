import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/reports.dart';

class InquiryReportsData {
  final int totalMessages;
  final int answeredMessages;
  final int unAnsweredMessages;
  final int escalatedMessages;
  final int resolvedEscalatedMessages;
  final String mostFrequentCategory;
  final Map<String, int> categoryDistribution;
  final List<ChartData> inquiryTrend;
  final Map<String, int> highestFAQs;

  final List<SystemLog> recentLogs;
  final List<MessageLogs> msgLogs;


  const InquiryReportsData({
    required this.totalMessages,
    required this.answeredMessages,
    required this.unAnsweredMessages,
    required this.escalatedMessages,
    required this.resolvedEscalatedMessages,
    required this.mostFrequentCategory,
    required this.categoryDistribution,
    required this.inquiryTrend,
    required this.highestFAQs,

    required this.recentLogs,
    required this.msgLogs,
   

  });
}

InquiryReportsData getEmptyInquiryReportsData() {
    return const InquiryReportsData(
      totalMessages: 0,
      answeredMessages: 0,
      unAnsweredMessages: 0,
      escalatedMessages: 0,
      resolvedEscalatedMessages: 0,
      mostFrequentCategory: 'Unknown',
      categoryDistribution: {},
      inquiryTrend: [],
      highestFAQs: {},
      recentLogs: [],
      msgLogs: [],
     
    );
  }