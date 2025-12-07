import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/reports.dart';


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

  // ✅ Optional: Add helper methods for formatted display
  String get formattedAverageResponseTime {
    if (averageResponseTime < 1) {
      return '${(averageResponseTime * 1000).toStringAsFixed(0)}ms';
    }
    return '${averageResponseTime.toStringAsFixed(2)}s';
  }

  String get formattedAverageSessionLength {
    final seconds = averageSessionLength.round();
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  // ✅ Optional: Copy with method for immutability
  ChatbotUsageReportsData copyWith({
    int? totalSessions,
    double? averageResponseTime,
    List<ChartData>? usageTrendByTimeOfDay,
    Map<int, int>? peakUsageByHour,
    double? averageMessagesPerUser,
    double? averageSessionLength,
    List<ChartData>? dailySessions,
    List<ChartData>? weeklySessions,
    List<ChartData>? monthlySessions,
    Map<String, int>? usersByYearLevel,
    Map<String, int>? usersByCourse,
    List<ChartData>? responseTimeTrend,
  }) {
    return ChatbotUsageReportsData(
      totalSessions: totalSessions ?? this.totalSessions,
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
      usageTrendByTimeOfDay: usageTrendByTimeOfDay ?? this.usageTrendByTimeOfDay,
      peakUsageByHour: peakUsageByHour ?? this.peakUsageByHour,
      averageMessagesPerUser: averageMessagesPerUser ?? this.averageMessagesPerUser,
      averageSessionLength: averageSessionLength ?? this.averageSessionLength,
      dailySessions: dailySessions ?? this.dailySessions,
      weeklySessions: weeklySessions ?? this.weeklySessions,
      monthlySessions: monthlySessions ?? this.monthlySessions,
      usersByYearLevel: usersByYearLevel ?? this.usersByYearLevel,
      usersByCourse: usersByCourse ?? this.usersByCourse,
      responseTimeTrend: responseTimeTrend ?? this.responseTimeTrend,
    );
  }
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