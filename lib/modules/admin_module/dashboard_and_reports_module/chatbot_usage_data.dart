import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/reports.dart';

class ChatbotUsageReportsData {
  // Stat Cards
 final double averageResponseTime; // in seconds
  final int totalConversations;
  final double averageMessagesPerUser;
  final double averageConversationTime; // in seconds
  
  // Charts
  final List<ChartData> conversationsOverTime; // renamed from dailySessions
  final Map<int, int> peakUsageByHour; // Hour (0-23) -> conversation count
  final Map<String, int>? peakUsageByDay; // Day name -> conversation count (for weekly)
  final Map<String, int>? peakUsageByMonth; // Month name -> conversation count (for yearly)
  final List<ChartData> responseTimeTrend; // Response time over selected period
  final Map<String, int> unansweredReasonsDistribution; // Reason -> count
  
  const ChatbotUsageReportsData({
    required this.averageResponseTime,
    required this.totalConversations,
    required this.averageMessagesPerUser,
    required this.averageConversationTime,
    required this.conversationsOverTime,
    required this.peakUsageByHour,
    this.peakUsageByDay,
    this.peakUsageByMonth,
    required this.responseTimeTrend,
    required this.unansweredReasonsDistribution,
  });

  String get formattedAverageResponseTime {
    if (averageResponseTime < 1) {
      return '${(averageResponseTime * 1000).toStringAsFixed(0)}ms';
    }
    return '${averageResponseTime.toStringAsFixed(2)}s';
  }

  String get formattedAverageConversationTime {
    final seconds = averageConversationTime.round();
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  ChatbotUsageReportsData copyWith({
    double? averageResponseTime,
    int? totalConversations,
    double? averageMessagesPerUser,
    double? averageConversationTime,
    List<ChartData>? conversationsOverTime,
    Map<int, int>? peakUsageByHour,
    Map<String, int>? peakUsageByDay,
    Map<String, int>? peakUsageByMonth,
    List<ChartData>? responseTimeTrend,
    Map<String, int>? unansweredReasonsDistribution,
  }) {
    return ChatbotUsageReportsData(
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
      totalConversations: totalConversations ?? this.totalConversations,
      averageMessagesPerUser: averageMessagesPerUser ?? this.averageMessagesPerUser,
      averageConversationTime: averageConversationTime ?? this.averageConversationTime,
      conversationsOverTime: conversationsOverTime ?? this.conversationsOverTime,
      peakUsageByHour: peakUsageByHour ?? this.peakUsageByHour,
      peakUsageByDay: peakUsageByDay ?? this.peakUsageByDay,
      peakUsageByMonth: peakUsageByMonth ?? this.peakUsageByMonth,
      responseTimeTrend: responseTimeTrend ?? this.responseTimeTrend,
      unansweredReasonsDistribution: unansweredReasonsDistribution ?? this.unansweredReasonsDistribution,
    );
  }
}

ChatbotUsageReportsData getEmptyChatbotUsageReportsData() {
  return ChatbotUsageReportsData(
    averageResponseTime: 0.0,
    totalConversations: 0,
    averageMessagesPerUser: 0.0,
    averageConversationTime: 0.0,
    conversationsOverTime: <ChartData>[],
    peakUsageByHour: <int, int>{},
    peakUsageByDay: <String, int>{},
    peakUsageByMonth: <String, int>{},
    responseTimeTrend: <ChartData>[],
    unansweredReasonsDistribution: <String, int>{},
  );
}
