import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/escalation_data.dart';
import 'package:capstone_project/modules/admin_module/dashboard_and_reports_module/reports.dart';

class StaffDashboardData {
  // Stat Cards
  final int totalMessages; // Bot + User messages
  final int pendingEscalations;
  final int resolvedEscalations;
  final int escalationsResponded; // By this staff member
  final double escalationRate;
  final double resolutionRate;
  
  // Charts
  final List<ChartData> inquiryTrend;
  final List<EscalatedMessage> topEscalatedMessages; // Top 5
  final List<ChartData> escalationsOverTime;
  
  // Logs
  final List<MessageLogs> messageLogs;

  const StaffDashboardData({
    required this.totalMessages,
    required this.pendingEscalations,
    required this.resolvedEscalations,
    required this.escalationsResponded,
    required this.escalationRate,
    required this.resolutionRate,
    required this.inquiryTrend,
    required this.topEscalatedMessages,
    required this.escalationsOverTime,
    required this.messageLogs,
  });
}

StaffDashboardData getEmptyStaffDashboardData() {
  return const StaffDashboardData(
    totalMessages: 0,
    pendingEscalations: 0,
    resolvedEscalations: 0,
    escalationsResponded: 0,
    escalationRate: 0.0,
    resolutionRate: 0.0,
    inquiryTrend: [],
    topEscalatedMessages: [],
    escalationsOverTime: [],
    messageLogs: [],
  );
}