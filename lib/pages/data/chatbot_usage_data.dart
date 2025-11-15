import 'package:capstone_project/pages/data/reports.dart';

class ChatbotUsageReportsData {
  final int totalSessions;
  final double averageResponseTime;
  final List<ChartData>? usageTrendByTimeOfDay;

  final Map<int, int> peakUsageByHour;
  final double averageMessagesPerUser;
  final double averageSessionLength;
  final List<ChartData>? dailySessions;
  final List<ChartData>? weeklySessions;
  final List<ChartData>? monthlySessions;
  final Map<String, int>? usersByYearLevel;
  final Map<String, int>? usersByCourse;
  final List<ChartData>? responseTimeTrend;

  const ChatbotUsageReportsData({
    required this.totalSessions,
    required this.averageResponseTime,
    required this.usageTrendByTimeOfDay,
    required this.peakUsageByHour,
    required this.averageMessagesPerUser,
    required this.averageSessionLength,
    
    required this.dailySessions,
    required this.weeklySessions,
    required this.monthlySessions,
    required this.usersByYearLevel,
    required this.usersByCourse,
    required this.responseTimeTrend,
  });
}

  ChatbotUsageReportsData getEmptyChatbotUsageReportsData() {
    return ChatbotUsageReportsData(
      totalSessions: 0,
      averageResponseTime: 0.0,
      usageTrendByTimeOfDay: <ChartData>[],
      averageMessagesPerUser: 0.0,
      averageSessionLength: 0.0,
      dailySessions: <ChartData>[],
      weeklySessions: <ChartData>[],
      monthlySessions: <ChartData>[],
      peakUsageByHour: <int, int>{},
      usersByYearLevel: <String, int>{},
      usersByCourse: <String, int>{},
      responseTimeTrend: <ChartData>[],
    );
  }