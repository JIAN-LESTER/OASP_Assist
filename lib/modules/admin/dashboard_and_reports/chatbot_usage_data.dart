import 'package:capstone_project/modules/admin/dashboard_and_reports/reports.dart';

class ChatbotUsageReportsData {
  final double averageResponseTime;
  final int totalConversations;
  final double averageMessagesPerUser;
  final double averageConversationTime;
  final double chatLimitReachRate;
  final double escalationLimitReachRate;
  final List<ChartData> conversationsOverTime;
  final Map<int, int> peakUsageByHour;
  final Map<String, int>? peakUsageByDay;
  final Map<String, int>? peakUsageByMonth;
  final Map<String, int>? peakUsageByYear; // NEW
  final Map<String, int>? peakUsageByAllYears; // NEW
  final List<ChartData> responseTimeTrend;
  final Map<String, int> unansweredReasonsDistribution;
  final List<ChartData> chatLimitReachTrend;
  final List<ChartData> escalationLimitReachTrend;

  ChatbotUsageReportsData({
    required this.averageResponseTime,
    required this.totalConversations,
    required this.averageMessagesPerUser,
    required this.averageConversationTime,
    required this.chatLimitReachRate,
    required this.escalationLimitReachRate,
    required this.conversationsOverTime,
    required this.peakUsageByHour,
    this.peakUsageByDay,
    this.peakUsageByMonth,
    this.peakUsageByYear, // NEW
    this.peakUsageByAllYears, // NEW
    required this.responseTimeTrend,
    required this.unansweredReasonsDistribution,
    required this.chatLimitReachTrend,
    required this.escalationLimitReachTrend,
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

  String get formattedChatLimitReachRate {
    return '${chatLimitReachRate.toStringAsFixed(1)}%';
  }

  String get formattedEscalationLimitReachRate {
    return '${escalationLimitReachRate.toStringAsFixed(1)}%';
  }

  ChatbotUsageReportsData copyWith({
    double? averageResponseTime,
    int? totalConversations,
    double? averageMessagesPerUser,
    double? averageConversationTime,
    double? chatLimitReachRate,
    double? escalationLimitReachRate,
    List<ChartData>? conversationsOverTime,
    Map<int, int>? peakUsageByHour,
    Map<String, int>? peakUsageByDay,
    Map<String, int>? peakUsageByMonth,
    List<ChartData>? responseTimeTrend,
    Map<String, int>? unansweredReasonsDistribution,
    List<ChartData>? chatLimitReachTrend,
    List<ChartData>? escalationLimitReachTrend,
  }) {
    return ChatbotUsageReportsData(
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
      totalConversations: totalConversations ?? this.totalConversations,
      averageMessagesPerUser: averageMessagesPerUser ?? this.averageMessagesPerUser,
      averageConversationTime: averageConversationTime ?? this.averageConversationTime,
      chatLimitReachRate: chatLimitReachRate ?? this.chatLimitReachRate,
      escalationLimitReachRate: escalationLimitReachRate ?? this.escalationLimitReachRate,
      conversationsOverTime: conversationsOverTime ?? this.conversationsOverTime,
      peakUsageByHour: peakUsageByHour ?? this.peakUsageByHour,
      peakUsageByDay: peakUsageByDay ?? this.peakUsageByDay,
      peakUsageByMonth: peakUsageByMonth ?? this.peakUsageByMonth,
      responseTimeTrend: responseTimeTrend ?? this.responseTimeTrend,
      unansweredReasonsDistribution: unansweredReasonsDistribution ?? this.unansweredReasonsDistribution,
      chatLimitReachTrend: chatLimitReachTrend ?? this.chatLimitReachTrend,
      escalationLimitReachTrend: escalationLimitReachTrend ?? this.escalationLimitReachTrend,
    );
  }
}

ChatbotUsageReportsData getEmptyChatbotUsageReportsData() {
  return ChatbotUsageReportsData(
    averageResponseTime: 0.0,
    totalConversations: 0,
    averageMessagesPerUser: 0.0,
    averageConversationTime: 0.0,
    chatLimitReachRate: 0.0,
    escalationLimitReachRate: 0.0,
    conversationsOverTime: [],
    peakUsageByHour: {},
    peakUsageByDay: {},
    peakUsageByMonth: {},
    peakUsageByYear: {}, // NEW
    peakUsageByAllYears: {}, // NEW
    responseTimeTrend: [],
    unansweredReasonsDistribution: {},
    chatLimitReachTrend: [],
    escalationLimitReachTrend: [],
  );
}