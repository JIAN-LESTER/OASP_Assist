import 'package:capstone_project/pages/data/charts.dart';
import 'package:capstone_project/pages/data/reports.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';



double _getGridInterval(List<ChartData> trendData) {
  if (trendData.isEmpty) return 1.0;

  int maxCount = 0;
  for (var data in trendData) {
    for (var count in data.categoryBreakdown.values) {
      if (count > maxCount) maxCount = count;
    }
  }

  if (maxCount <= 5) return 1.0;
  if (maxCount <= 10) return 2.0;
  if (maxCount <= 25) return 5.0;
  if (maxCount <= 50) return 10.0;
  return (maxCount / 5).ceil().toDouble();
}

double _getBottomTitleInterval(int dataLength) {
  if (dataLength <= 7) return 1.0;
  if (dataLength <= 14) return 2.0;
  if (dataLength <= 30) return 5.0;
  return (dataLength / 6).ceil().toDouble();
}

String _formatBottomTitle(String date) {
  // Format the date for display on x-axis
  if (date.contains(":")) {
    // Hour format (e.g., "14:00" -> "2PM")
    int hour = int.tryParse(date.split(":")[0]) ?? 0;
    if (hour == 0) return "12AM";
    if (hour < 12) return "${hour}AM";
    if (hour == 12) return "12PM";
    return "${hour - 12}PM";
  } else if (date.startsWith("Week")) {
    // Week format (e.g., "Week 1" -> "W1")
    return date.replaceAll("Week ", "W");
  } else if (date.length <= 3) {
    // Already short format (Mon, Jan, etc.)
    return date;
  }
  return date;
}

Color _getProgramColor(int index) {
  final colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
  ];
  return colors[index % colors.length];
}





Widget buildAverageResponseTimeCard(double responseTime) {
  final color =
      responseTime <= 1
          ? Colors.green
          : responseTime <= 3
          ? Colors.orange
          : Colors.red;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.speed, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${responseTime.toStringAsFixed(1)}s',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const Text(
                    'Average Response Time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _getResponseTimeDescription(responseTime),
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    ),
  );
}

Color _getYearLevelColor(int index) {
  final colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
  ];
  return colors[index % colors.length];
}

double _getMaxYValue(List<ChartData> data) {
  if (data.isEmpty) return 10;
  final maxValue = data.map((e) => e.count).reduce((a, b) => a > b ? a : b);
  return (maxValue * 1.2).toDouble();
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


String _getResponseTimeDescription(double responseTime) {
  if (responseTime <= 1) return 'Excellent response time';
  if (responseTime <= 2) return 'Good response time';
  if (responseTime <= 3) return 'Fair response time';
  return 'Response time needs improvement';
}


Widget buildResponseTimeTrendCard(List<ChartData> responseTimeTrend) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Response Time Trend',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Average chatbot response time over time',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: responseTimeTrend.isEmpty
              ? Center(
                  child: Text(
                    'No response time data available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toStringAsFixed(1)}s',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < responseTimeTrend.length) {
                              return Text(
                                formatBottomTitle(responseTimeTrend[value.toInt()].date),
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: responseTimeTrend.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value.count.toDouble());
                        }).toList(),
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}

Widget buildPeakUsageHoursCard(Map<int, int> hourlyData) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Peak Usage Hours',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Messages sent by hour of day',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              hourlyData.isEmpty
                  ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          hourlyData.values.isNotEmpty
                              ? hourlyData.values
                                      .reduce((a, b) => a > b ? a : b)
                                      .toDouble() *
                                  1.2
                              : 10,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            int hour = group.x.toInt();
                            String timeLabel =
                                hour == 0
                                    ? '12 AM'
                                    : hour < 12
                                    ? '$hour AM'
                                    : hour == 12
                                    ? '12 PM'
                                    : '${hour - 12} PM';
                            return BarTooltipItem(
                              '$timeLabel\n${rod.toY.round()} messages',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget:
                                (value, meta) => Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
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
                                String label =
                                    hour == 0
                                        ? '12A'
                                        : hour < 12
                                        ? '${hour}A'
                                        : hour == 12
                                        ? '12P'
                                        : '${hour - 12}P';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(24, (hour) {
                        return BarChartGroupData(
                          x: hour,
                          barRods: [
                            BarChartRodData(
                              toY: (hourlyData[hour] ?? 0).toDouble(),
                              color: DashboardWidgets.getHeatmapColor(
                                hourlyData[hour] ?? 0,
                                hourlyData.length - 1,
                              ),
                              width: 12,
                              borderRadius: BorderRadius.circular(2),
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

Widget buildConversationsOverTimeCard(
  List<ChartData> conversationTrend,
  String timeFrame,
) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conversations Over Time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chat session frequency - ${_getTimeFrameDescription(timeFrame)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                timeFrame,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              conversationTrend.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No conversation data available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                  : Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: _getMaxYValue(conversationTrend),
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final dataPoint =
                                    conversationTrend[spot.x.toInt()];
                                final count = spot.y.toInt();
                                return LineTooltipItem(
                                  '${dataPoint.date}\n$count conversations',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _getGridInterval(
                            conversationTrend,
                          ),
                          getDrawingHorizontalLine:
                              (value) => FlLine(
                                color: Colors.grey.withOpacity(0.2),
                                strokeWidth: 1,
                              ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: _getGridInterval(conversationTrend),
                              getTitlesWidget:
                                  (value, meta) => Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: _getBottomTitleInterval(
                                conversationTrend.length,
                              ),
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() < conversationTrend.length) {
                                  final dataPoint =
                                      conversationTrend[value.toInt()];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _formatBottomTitle(dataPoint.date),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: const Border(
                            left: BorderSide(color: Colors.black12),
                            bottom: BorderSide(color: Colors.black12),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots:
                                conversationTrend.asMap().entries.map((entry) {
                                  return FlSpot(
                                    entry.key.toDouble(),
                                    entry.value.count.toDouble(),
                                  );
                                }).toList(),
                            isCurved: true,
                            curveSmoothness: 0.3,
                            color: Colors.blue[600]!,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            gradient: LinearGradient(
                              colors: [Colors.blue[400]!, Colors.blue[600]!],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue[100]!.withOpacity(0.3),
                                  Colors.blue[50]!.withOpacity(0.1),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.blue[600]!,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
        ),
      ],
    ),
  );
}

Widget buildUsersByCourseCard(Map<String, int> usersByCourse) {
  final sortedEntries = usersByCourse.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topCourses = sortedEntries.take(10).toList();
  
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top 10 Courses by Usage',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Most active courses using the chatbot',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: topCourses.isEmpty
              ? Center(
                  child: Text(
                    'No course data available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: topCourses.isNotEmpty 
                        ? topCourses.first.value.toDouble() + 5
                        : 10,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
              
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final course = DashboardWidgets.shortenProgram(topCourses[group.x.toInt()].key);
                          return BarTooltipItem(
                            '$course\n${rod.toY.round()} users',
                            const TextStyle(color: Colors.white, fontSize: 12),
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
                              final courseName = DashboardWidgets.shortenProgram(topCourses[value.toInt()].key);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  courseName,
                                  style: const TextStyle(fontSize: 9),
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
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
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
                    gridData: const FlGridData(show: true),
                    barGroups: topCourses.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.value.toDouble(),
                            color: _getProgramColor(entry.key),
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
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

Widget buildUsersByYearLevelCard(Map<String, int> usersByYearLevel) {
  final entries = usersByYearLevel.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Users by Year Level',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Distribution of chatbot users across year levels',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    'No year level data available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: entries.asMap().entries.map((entry) {
                      final total = usersByYearLevel.values.fold(0, (a, b) => a + b);
                      final percentage = ((entry.value.value / total) * 100);
                      
                      return PieChartSectionData(
                        color: _getYearLevelColor(entry.key),
                        value: entry.value.value.toDouble(),
                        title: '${percentage.toStringAsFixed(1)}%',
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: entries.map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getYearLevelColor(entries.indexOf(entry)),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${entry.key} (${entry.value})',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    ),
  );
}





