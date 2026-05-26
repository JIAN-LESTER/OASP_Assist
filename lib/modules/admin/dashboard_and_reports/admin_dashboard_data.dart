import 'package:capstone_project/modules/admin/dashboard_and_reports/escalation_data.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/reports.dart';

class AdminDashboardData {
  final int totalMessages;
  final int totalUsers;
  final int pendingEscalations;
  final int resolvedEscalations;
  final double escalationRate;
  final double resolutionRate;
  final List<ChartData> inquiryTrend;
  final List<EscalatedMessage> topEscalatedMessages;  // ✅ This should be List<EscalatedMessage>
  final List<ChartData> escalationsOverTime;
  final List<SystemLog> systemLogs;
  final List<MessageLogs> messageLogs;

  const AdminDashboardData({
    required this.totalMessages,
    required this.totalUsers,
    required this.pendingEscalations,
    required this.resolvedEscalations,
    required this.escalationRate,
    required this.resolutionRate,
    required this.inquiryTrend,
    required this.topEscalatedMessages,
    required this.escalationsOverTime,
    required this.systemLogs,
    required this.messageLogs,
  });
}

AdminDashboardData getEmptyAdminDashboardData() {
  return const AdminDashboardData(
    totalMessages: 0,
    totalUsers: 0,
    pendingEscalations: 0,
    resolvedEscalations: 0,
    escalationRate: 0.0,
    resolutionRate: 0.0,
    inquiryTrend: [],
    topEscalatedMessages: [],
    escalationsOverTime: [],
    systemLogs: [],
    messageLogs: [],
  );
}
