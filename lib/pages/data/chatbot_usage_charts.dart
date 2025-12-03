import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/reports.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// ============================================
// 🎨 IMPROVED RESPONSE TIME TREND CARD
// ============================================

import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/reports.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// ============================================
// 🎨 IMPROVED RESPONSE TIME TREND CARD
// ============================================
Widget buildResponseTimeTrendCard(List<ChartData> responseTimeTrend) {
  // Calculate statistics - values are in centiseconds, convert to seconds
  double avgResponseTime = 0;
  double minResponseTime = double.infinity;
  double maxResponseTime = 0;
  
  if (responseTimeTrend.isNotEmpty) {
    int validCount = 0;
    for (var data in responseTimeTrend) {
      if (data.count > 0) {  // Only count non-zero values
        final seconds = data.count / 100.0;
        avgResponseTime += seconds;
        if (seconds < minResponseTime) minResponseTime = seconds;
        if (seconds > maxResponseTime) maxResponseTime = seconds;
        validCount++;
      }
    }
    avgResponseTime = validCount > 0 ? avgResponseTime / validCount : 0;
    if (minResponseTime == double.infinity) minResponseTime = 0;
  }

  Color getPerformanceColor(double seconds) {
    if (seconds <= 1.0) return Colors.green;
    if (seconds <= 2.0) return Colors.blue;
    if (seconds <= 3.0) return Colors.orange;
    return Colors.red;
  }

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Response Time Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Average chatbot response time over selected period',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (avgResponseTime > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: getPerformanceColor(avgResponseTime).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: getPerformanceColor(avgResponseTime).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.speed,
                      size: 16,
                      color: getPerformanceColor(avgResponseTime),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${avgResponseTime.toStringAsFixed(1)}s avg',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: getPerformanceColor(avgResponseTime),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        
        if (avgResponseTime > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat('Min', '${minResponseTime.toStringAsFixed(1)}s', Colors.green),
              const SizedBox(width: 16),
              _buildMiniStat('Max', '${maxResponseTime.toStringAsFixed(1)}s', Colors.red),
              const SizedBox(width: 16),
              _buildMiniStat('Data Points', '${responseTimeTrend.where((d) => d.count > 0).length}', Colors.blue),
            ],
          ),
        ],
        
        const SizedBox(height: 20),
        
        Expanded(
          child: responseTimeTrend.isEmpty || avgResponseTime == 0
              ? _buildEmptyState(
                  icon: Icons.timeline,
                  message: 'No response time data available',
                  subtitle: 'Data will appear once users start chatting',
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: _getMaxResponseTime(responseTimeTrend),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: _getResponseTimeInterval(responseTimeTrend),
                        verticalInterval: responseTimeTrend.length > 1 
                            ? (responseTimeTrend.length / 6).ceilToDouble() 
                            : 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.15),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            interval: _getResponseTimeInterval(responseTimeTrend),
                            getTitlesWidget: (value, meta) {
                              final seconds = value / 100.0; // Convert from centiseconds
                              return Container(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '${seconds.toStringAsFixed(1)}s',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: _getBottomTitleInterval(responseTimeTrend.length),
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && 
                                  value.toInt() < responseTimeTrend.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    responseTimeTrend[value.toInt()].date,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!, width: 1),
                          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (group) => const Color(0xff1a1a1a),
                          tooltipRoundedRadius: 8,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final dataPoint = responseTimeTrend[spot.x.toInt()];
                              final seconds = spot.y / 100.0; // Convert from centiseconds
                              final color = getPerformanceColor(seconds);
                              
                              return LineTooltipItem(
                                '${dataPoint.date}\n',
                                const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${seconds.toStringAsFixed(1)}s',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                        getTouchedSpotIndicator: (barData, spotIndexes) {
                          return spotIndexes.map((spotIndex) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: Colors.blue[600]!,
                                strokeWidth: 2,
                                dashArray: [5, 5],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 6,
                                    color: Colors.white,
                                    strokeWidth: 3,
                                    strokeColor: Colors.blue[600]!,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: responseTimeTrend.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              entry.value.count.toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: Colors.blue[600]!,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue[400]!,
                              Colors.blue[600]!,
                              Colors.purple[400]!,
                            ],
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              // Only show dots for non-zero values
                              if (responseTimeTrend[index].count > 0) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: Colors.blue[600]!,
                                );
                              }
                              return FlDotCirclePainter(
                                radius: 0,
                                color: Colors.transparent,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue[100]!.withOpacity(0.4),
                                Colors.blue[50]!.withOpacity(0.1),
                                Colors.transparent,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 250),
                  ),
                ),
        ),
      ],
    ),
  );
}



// Helper functions
Widget _buildMiniStat(String label, String value, Color color) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildEmptyState({
  required IconData icon,
  required String message,
  required String subtitle,
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 48,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}



// ============================================
// 🎨 FIXED CONVERSATIONS OVER TIME CARD
// ============================================
Widget buildConversationsOverTimeCard(
  List<ChartData> conversationTrend,
  String timeFrame,
) {
  // Calculate statistics
  int totalConversations = 0;
  int peakConversations = 0;
  String peakPeriod = '';
  
  if (conversationTrend.isNotEmpty) {
    for (var data in conversationTrend) {
      totalConversations += data.count;
      if (data.count > peakConversations) {
        peakConversations = data.count;
        peakPeriod = data.date;
      }
    }
  }

  double avgConversations = conversationTrend.isNotEmpty 
      ? totalConversations / conversationTrend.length 
      : 0;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conversations Over Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chat session frequency - ${_getTimeFrameDescription(timeFrame)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue[200]!, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Text(
                    timeFrame,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Stats row
        if (conversationTrend.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat('Total', '$totalConversations', Colors.blue),
              const SizedBox(width: 16),
              _buildMiniStat('Average', '${avgConversations.toStringAsFixed(1)}', Colors.green),
              const SizedBox(width: 16),
              _buildMiniStat('Peak', '$peakConversations', Colors.orange),
            ],
          ),
        ],
        
        const SizedBox(height: 20),
        
        // Chart
        Expanded(
          child: conversationTrend.isEmpty
              ? _buildEmptyState(
                  icon: Icons.chat_bubble_outline,
                  message: 'No conversation data available',
                  subtitle: 'Conversations will appear here once users start chatting',
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: _getMaxYValue(conversationTrend),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: _getGridInterval(conversationTrend),
                        verticalInterval: conversationTrend.length > 1 
                            ? (conversationTrend.length / 6).ceilToDouble() 
                            : 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.15),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: _getGridInterval(conversationTrend),
                            getTitlesWidget: (value, meta) {
                              return Container(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: _getConversationBottomInterval(conversationTrend.length, timeFrame),
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < conversationTrend.length) {
                                final dataPoint = conversationTrend[index];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    dataPoint.date,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!, width: 1),
                          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (group) => const Color(0xff1a1a1a),
                          tooltipRoundedRadius: 8,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final dataPoint = conversationTrend[spot.x.toInt()];
                              final count = spot.y.toInt();
                              return LineTooltipItem(
                                '${dataPoint.date}\n',
                                const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: '$count conversation${count != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                        getTouchedSpotIndicator: (barData, spotIndexes) {
                          return spotIndexes.map((spotIndex) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: Colors.blue[600]!,
                                strokeWidth: 2,
                                dashArray: [5, 5],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 6,
                                    color: Colors.white,
                                    strokeWidth: 3,
                                    strokeColor: Colors.blue[600]!,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: conversationTrend.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              entry.value.count.toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: Colors.blue[600]!,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue[400]!,
                              Colors.blue[600]!,
                              Colors.indigo[400]!,
                            ],
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: Colors.blue[600]!,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue[100]!.withOpacity(0.4),
                                Colors.blue[50]!.withOpacity(0.1),
                                Colors.transparent,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 250),
                  ),
                ),
        ),
      ],
    ),
  );
}

// ============================================
// 🎨 HELPER FUNCTIONS FOR CONVERSATION CHART
// ============================================


double _getMaxYValue(List<ChartData> data) {
  if (data.isEmpty) return 10;
  final maxValue = data.map((e) => e.count).reduce((a, b) => a > b ? a : b);
  return (maxValue * 1.2).toDouble();
}

double _getGridInterval(List<ChartData> trendData) {
  if (trendData.isEmpty) return 1.0;
  int maxCount = trendData.map((e) => e.count).reduce((a, b) => a > b ? a : b);
  if (maxCount <= 5) return 1.0;
  if (maxCount <= 10) return 2.0;
  if (maxCount <= 25) return 5.0;
  if (maxCount <= 50) return 10.0;
  return (maxCount / 5).ceil().toDouble();
}

// ✅ NEW: Specific interval calculation for conversation bottom titles
double _getConversationBottomInterval(int dataLength, String timeFrame) {
  switch (timeFrame) {
    case 'Today':
      // Show every 3 hours for 24 hours
      return dataLength <= 24 ? 3.0 : 4.0;
    case 'This Week':
      // Show all 7 days
      return 1.0;
    case 'This Month':
      // Show all weeks
      return 1.0;
    case 'This Year':
      // Show every other month or all months depending on space
      return dataLength <= 12 ? 1.0 : 2.0;
    default:
      if (dataLength <= 7) return 1.0;
      if (dataLength <= 14) return 2.0;
      return (dataLength / 6).ceil().toDouble();
  }
}

String _getTimeFrameDescription(String timeFrame) {
  switch (timeFrame) {
    case 'Today':
      return 'by hour';
    case 'This Week':
      return 'by day';
    case 'This Month':
      return 'by week';
    case 'This Year':
      return 'by month';
    default:
      return 'over time';
  }
}

// ============================================
Widget buildPeakUsageHoursCard(Map<int, int> hourlyData) {
  int totalMessages = hourlyData.values.fold(0, (sum, count) => sum + count);
  int peakHour = 0;
  int peakCount = 0;
  
  hourlyData.forEach((hour, count) {
    if (count > peakCount) {
      peakCount = count;
      peakHour = hour;
    }
  }); 
  
  String getPeakTimeLabel() {
    if (peakHour == 0) return '12 AM';
    if (peakHour < 12) return '$peakHour AM';
    if (peakHour == 12) return '12 PM';
    return '${peakHour - 12} PM';
  }

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
          border: Border(
        
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Peak Usage Hours',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Messages sent by hour of day',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (hourlyData.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange[200]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Peak: ${getPeakTimeLabel()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        
        if (hourlyData.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat('Total', '$totalMessages', Colors.blue),
              const SizedBox(width: 16),
              _buildMiniStat('Peak Count', '$peakCount', Colors.orange),
              const SizedBox(width: 16),
              _buildMiniStat('Active Hours', '${hourlyData.length}', Colors.green),
            ],
          ),
        ],
        
        const SizedBox(height: 20),
        
        Expanded(
          child: hourlyData.isEmpty
              ? _buildEmptyState(
                  icon: Icons.access_time,
                  message: 'No hourly data available',
                  subtitle: 'Usage patterns will appear here over time',
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: hourlyData.values.isNotEmpty
                        ? hourlyData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2
                        : 10,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => const Color(0xff1a1a1a),
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          int hour = group.x.toInt();
                          String timeLabel = hour == 0
                              ? '12 AM'
                              : hour < 12
                                  ? '$hour AM'
                                  : hour == 12
                                      ? '12 PM'
                                      : '${hour - 12} PM';
                          return BarTooltipItem(
                            '$timeLabel\n',
                            const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            children: [
                              TextSpan(
                                text: '${rod.toY.round()} messages',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          getTitlesWidget: (value, meta) => Container(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 4,
                          getTitlesWidget: (value, meta) {
                            int hour = value.toInt();
                            if (hour % 4 == 0) {
                              String label = hour == 0
                                  ? '12A'
                                  : hour < 12
                                      ? '${hour}A'
                                      : hour == 12
                                          ? '12P'
                                          : '${hour - 12}P';
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!, width: 1),
                        bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: hourlyData.values.isNotEmpty
                          ? (hourlyData.values.reduce((a, b) => a > b ? a : b) / 5).ceilToDouble()
                          : 5,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.15),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ),
                    barGroups: List.generate(24, (hour) {
                      final count = hourlyData[hour] ?? 0;
                      final maxCount = hourlyData.values.isNotEmpty
                          ? hourlyData.values.reduce((a, b) => a > b ? a : b)
                          : 1;
                      final intensity = count / maxCount;
                      
                      return BarChartGroupData(
                        x: hour,
                        barRods: [
                          BarChartRodData(
                            toY: count.toDouble(),
                            color: _getHeatmapColor(intensity),
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _getHeatmapColor(intensity).withOpacity(0.7),
                                _getHeatmapColor(intensity),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
        ),
      ],
    ),
  );
}

// ============================================
// 🎨 IMPROVED USERS BY COURSE CARD
// ============================================
Widget buildUsersByCourseCard(Map<String, int> usersByCourse) {
  final sortedEntries = usersByCourse.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topCourses = sortedEntries.take(10).toList();
  
  int totalUsers = topCourses.fold(0, (sum, entry) => sum + entry.value);
  
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
            border: Border(
       
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top 10 Courses by Usage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Most active courses using the chatbot',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (topCourses.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple[200]!, width: 1),
                ),
                child: Text(
                  '$totalUsers users',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: topCourses.isEmpty
              ? _buildEmptyState(
                  icon: Icons.school,
                  message: 'No course data available',
                  subtitle: 'Course distribution will appear here',
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: topCourses.isNotEmpty 
                        ? topCourses.first.value.toDouble() * 1.2
                        : 10,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                           getTooltipColor: (group) => const Color(0xff1a1a1a),
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final course = topCourses[group.x.toInt()].key;
                          return BarTooltipItem(
                            '${DashboardWidgets.shortenProgram(course)}\n',
                            const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            children: [
                              TextSpan(
                                text: '${rod.toY.round()} users',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < topCourses.length) {
                              final courseName = DashboardWidgets.shortenProgram(
                                topCourses[value.toInt()].key
                              );
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  courseName,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Container(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.right,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: topCourses.isNotEmpty
                          ? (topCourses.first.value / 5).ceilToDouble()
                          : 5,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.15),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!, width: 1),
                        bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    barGroups: topCourses.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.value.toDouble(),
                            color: _getProgramColor(entry.key),
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _getProgramColor(entry.key).withOpacity(0.7),
                                _getProgramColor(entry.key),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    ),
  );
}

// ============================================
// 🎨 IMPROVED USERS BY YEAR LEVEL CARD
// ============================================
Widget buildUsersByYearLevelCard(
  Map<String, int> usersByYearLevel, {
  bool isMobile = false,
}) {
  final entries = usersByYearLevel.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  
  int totalUsers = entries.fold(0, (sum, entry) => sum + entry.value);
  
  // ✅ Dynamic sizing based on data volume and screen size
  double chartRadius;
  double sectionRadius;
  double fontSize;
  
  if (isMobile) {
    // Mobile: smaller charts
    if (totalUsers > 100) {
      chartRadius = 40;
      sectionRadius = 70;
      fontSize = 12;
    } else if (totalUsers > 50) {
      chartRadius = 35;
      sectionRadius = 60;
      fontSize = 11;
    } else {
      chartRadius = 30;
      sectionRadius = 50;
      fontSize = 10;
    }
  } else {
    // Desktop/Tablet: larger charts
    if (totalUsers > 100) {
      chartRadius = 50;
      sectionRadius = 90;
      fontSize = 13;
    } else if (totalUsers > 50) {
      chartRadius = 45;
      sectionRadius = 80;
      fontSize = 12;
    } else {
      chartRadius = 40;
      sectionRadius = 70;
      fontSize = 11;
    }
  }
  
  return Container(
    padding: EdgeInsets.all(isMobile ? 16 : 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border(),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Users by Year Level',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Distribution of chatbot users across year levels',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (entries.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.teal[200]!, width: 1),
                ),
                child: Text(
                  '$totalUsers total',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.teal[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: isMobile ? 16 : 20),
        Expanded(
          child: entries.isEmpty
              ? _buildEmptyState(
                  icon: Icons.people_outline,
                  message: 'No year level data available',
                  subtitle: 'Year level distribution will appear here',
                )
              : isMobile
                  ? Column(
                      children: [
                        // Chart takes more space on mobile
                        Expanded(
                          flex: 3,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: chartRadius, // ✅ Dynamic radius
                              sections: entries.asMap().entries.map((entry) {
                                final percentage = ((entry.value.value / totalUsers) * 100);
                                
                                return PieChartSectionData(
                                  color: _getYearLevelColor(entry.key),
                                  value: entry.value.value.toDouble(),
                                  title: '${percentage.toStringAsFixed(1)}%',
                                  radius: sectionRadius, // ✅ Dynamic section radius
                                  titleStyle: TextStyle(
                                    fontSize: fontSize, // ✅ Dynamic font size
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Legend below chart on mobile
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: entries.map((entry) {
                                final percentage = ((entry.value / totalUsers) * 100);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: _getYearLevelColor(entries.indexOf(entry)),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${entry.key}: ${entry.value} (${percentage.toStringAsFixed(1)}%)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Pie Chart
                        Expanded(
                          flex: 3,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: chartRadius, // ✅ Dynamic radius
                              sections: entries.asMap().entries.map((entry) {
                                final percentage = ((entry.value.value / totalUsers) * 100);
                                
                                return PieChartSectionData(
                                  color: _getYearLevelColor(entry.key),
                                  value: entry.value.value.toDouble(),
                                  title: '${percentage.toStringAsFixed(1)}%',
                                  radius: sectionRadius, // ✅ Dynamic section radius
                                  titleStyle: TextStyle(
                                    fontSize: fontSize, // ✅ Dynamic font size
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  badgeWidget: entry.key == 0
                                      ? Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.star,
                                            size: 16,
                                            color: _getYearLevelColor(entry.key),
                                          ),
                                        )
                                      : null,
                                  badgePositionPercentageOffset: 1.2,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Legend
                        Expanded(
                          flex: 2,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: entries.map((entry) {
                              final percentage = ((entry.value / totalUsers) * 100);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: _getYearLevelColor(entries.indexOf(entry)),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getYearLevelColor(entries.indexOf(entry))
                                                .withOpacity(0.3),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    ),
  );
}

// ============================================
// 🎨 HELPER FUNCTIONS
// ============================================


String _formatChartLabel(String date) {
  if (date.contains(":")) {
    int hour = int.tryParse(date.split(":")[0]) ?? 0;
    if (hour == 0) return "12A";
    if (hour < 12) return "${hour}A";
    if (hour == 12) return "12P";
    return "${hour - 12}P";
  } else if (date.startsWith("Week")) {
    return date.replaceAll("Week ", "W");
  } else if (date.length <= 3) {
    return date;
  }
  return date;
}

double _getMaxResponseTime(List<ChartData> data) {
  if (data.isEmpty) return 500;
  final validData = data.where((d) => d.count > 0).toList();
  if (validData.isEmpty) return 500;
  
  final maxValue = validData.map((e) => e.count).reduce((a, b) => a > b ? a : b);
  return (maxValue * 1.2).toDouble();
}

double _getResponseTimeInterval(List<ChartData> data) {
  if (data.isEmpty) return 100;
  final validData = data.where((d) => d.count > 0).toList();
  if (validData.isEmpty) return 100;
  
  final maxValue = validData.map((e) => e.count).reduce((a, b) => a > b ? a : b);
  if (maxValue <= 100) return 20;  // 0.2s intervals
  if (maxValue <= 200) return 50;  // 0.5s intervals
  if (maxValue <= 500) return 100; // 1s intervals
  if (maxValue <= 1000) return 200; // 2s intervals
  return (maxValue / 5).ceilToDouble();
}

double _getBottomTitleInterval(int dataLength) {
  if (dataLength <= 7) return 1.0;
  if (dataLength <= 14) return 2.0;
  if (dataLength <= 30) return 5.0;
  return (dataLength / 6).ceil().toDouble();
}
Color _getHeatmapColor(double intensity) {
  if (intensity >= 0.8) return Colors.red[600]!;
  if (intensity >= 0.6) return Colors.orange[600]!;
  if (intensity >= 0.4) return Colors.amber[600]!;
  if (intensity >= 0.2) return Colors.lightGreen[600]!;
  return Colors.green[400]!;
}

Color _getProgramColor(int index) {
  final colors = [
    Colors.blue[600]!,
    Colors.green[600]!,
    Colors.orange[600]!,
    Colors.purple[600]!,
    Colors.red[600]!,
    Colors.teal[600]!,
    Colors.indigo[600]!,
    Colors.pink[600]!,
    Colors.amber[600]!,
    Colors.cyan[600]!,
  ];
  return colors[index % colors.length];
}

Color _getYearLevelColor(int index) {
  final colors = [
    Colors.blue[600]!,
    Colors.green[600]!,
    Colors.orange[600]!,
    Colors.purple[600]!,
    Colors.red[600]!,
  ];
  return colors[index % colors.length];
}



