import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/pages/data/reports.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';



// Helper function to get bar colors with gradient effect
Color _getFAQBarColor(int index, int total) {
  // Create a gradient from most vibrant (first) to less vibrant (last)
  final colors = [
    const Color(0xfff59e0b), // Amber
    const Color(0xffef4444), // Red
    const Color(0xff3b82f6), // Blue
    const Color(0xff10b981), // Green
    const Color(0xff8b5cf6), // Purple
    const Color(0xfff97316), // Orange
    const Color(0xff06b6d4), // Cyan
    const Color(0xffec4899), // Pink
    const Color(0xff84cc16), // Lime
    const Color(0xff6366f1), // Indigo
  ];

  return colors[index % colors.length];
}

// Helper function to calculate Y-axis interval
double _getYAxisInterval(double maxValue) {
  if (maxValue <= 5) return 1;
  if (maxValue <= 10) return 2;
  if (maxValue <= 20) return 5;
  if (maxValue <= 50) return 10;
  if (maxValue <= 100) return 20;
  return (maxValue / 5).ceil().toDouble();
}


List<LineChartBarData> _generateLineChartBars(
  List<ChartData> trendData,
  List<String> categories,
) {
  List<LineChartBarData> lineBars = [];

  for (
    int categoryIndex = 0;
    categoryIndex < categories.length;
    categoryIndex++
  ) {
    final category = categories[categoryIndex];
    final color = getColorForCategory(category);

    List<FlSpot> spots = [];
    for (int i = 0; i < trendData.length; i++) {
      final count = trendData[i].categoryBreakdown[category] ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    lineBars.add(
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        belowBarData: BarAreaData(
          show: false, // Don't show area fill to avoid overlap
        ),
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 3,
              color: color,
              strokeWidth: 1,
              strokeColor: Colors.white,
            );
          },
        ),
      ),
    );
  }

  return lineBars;
}

Color _getColorForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'admission':
      return Colors.blue;
    case 'scholarship':
      return Colors.green;
    case 'placement':
      return Colors.orange;
    case 'general':
      return Colors.purple;
    default:
      return Colors.grey;
  }
}


Color _getSeasonColor(String season) {
  switch (season.toLowerCase()) {
    case 'spring':
      return Colors.green[500]!;
    case 'summer':
      return Colors.orange[500]!;
    case 'fall':
    case 'autumn':
      return Colors.brown[500]!;
    case 'winter':
      return Colors.blue[500]!;
    default:
      return Colors.grey[500]!;
  }
}

int _getSeasonOrder(String season) {
  switch (season.toLowerCase()) {
    case 'spring':
      return 1;
    case 'summer':
      return 2;
    case 'fall':
    case 'autumn':
      return 3;
    case 'winter':
      return 4;
    default:
      return 5;
  }
}

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



Widget buildSeasonalTrendsCard(Map<String, int> seasonalTrends) {
  final sortedData =
      seasonalTrends.entries.toList()..sort(
        (a, b) => _getSeasonOrder(a.key).compareTo(_getSeasonOrder(b.key)),
      );

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
          'Seasonal Inquiry Trends',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Inquiry patterns by season',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              seasonalTrends.isEmpty
                  ? Center(
                    child: Text(
                      'No seasonal data available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          (sortedData.isEmpty
                                  ? 10
                                  : sortedData
                                          .map((e) => e.value)
                                          .reduce((a, b) => a > b ? a : b) *
                                      1.2)
                              .toDouble(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex < sortedData.length) {
                              final entry = sortedData[groupIndex];
                              return BarTooltipItem(
                                '${entry.key}\n${entry.value} inquiries',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
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
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < sortedData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    sortedData[value.toInt()].key,
                                    style: const TextStyle(fontSize: 12),
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
                      barGroups:
                          sortedData.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: data.value.toDouble(),
                                  color: _getSeasonColor(data.key),
                                  width: 32,
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


Widget buildCategoryDistributionCard(Map<String, int> categoryData) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inquiry Category Distribution',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Based on Category',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        Expanded(
          child:
              categoryData.isEmpty
                  ? Center(
                    child: Text(
                      'No data available for this time period',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : PieChart(
                    PieChartData(
                      sections:
                          categoryData.entries.map((entry) {
                            return PieChartSectionData(
                              color: _getColorForCategory(entry.key),
                              value: entry.value.toDouble(),
                              title: '${entry.key}\n${entry.value}',
                              radius: 75,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                    ),
                  ),
        ),
      ],
    ),
  );
}

Widget buildHighestFAQCard(Map<String, int> highestFAQ) {
  // Sort FAQ data by count (highest first) and take top 10
  final sortedFAQ =
      highestFAQ.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  final topFAQ = sortedFAQ.take(10).toList();
  final maxValue = topFAQ.isNotEmpty ? topFAQ.first.value.toDouble() : 0.0;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently Asked Question',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Based on Questions',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),

        Expanded(
          child:
              topFAQ.isEmpty
                  ? Center(
                    child: Text(
                      'No data available for this time period',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxValue * 1.2, // Add 20% padding to top
                      minY: 0,
                      groupsSpace: 12,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex < topFAQ.length) {
                              final entry = topFAQ[groupIndex];
                              return BarTooltipItem(
                                '${entry.key}\n${entry.value} questions',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < topFAQ.length) {
                                final entry = topFAQ[value.toInt()];
                                final question =
                                    entry.key.length > 20
                                        ? '${entry.key.substring(0, 17)}...'
                                        : entry.key;

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SizedBox(
                                    width: 80,
                                    child: Text(
                                      question,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: _getYAxisInterval(maxValue),
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _getYAxisInterval(maxValue),
                        getDrawingHorizontalLine:
                            (value) => FlLine(
                              color: Colors.grey.withOpacity(0.15),
                              strokeWidth: 1,
                            ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!, width: 1),
                          bottom: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                      ),
                      barGroups:
                          topFAQ.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;

                            // Create gradient colors based on position (highest gets most vibrant)
                            final Color barColor = _getFAQBarColor(
                              index,
                              topFAQ.length,
                            );

                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: data.value.toDouble(),
                                  color: barColor,
                                  width: 28,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      barColor,
                                      barColor.withOpacity(0.7),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  rodStackItems: [
                                    BarChartRodStackItem(
                                      0,
                                      data.value.toDouble(),
                                      barColor,
                                    ),
                                  ],
                                ),
                              ],
                              showingTooltipIndicators: [],
                            );
                          }).toList(),
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 600),
                    swapAnimationCurve: Curves.easeInOutCubic,
                  ),
        ),

        if (topFAQ.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.amber[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Question',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topFAQ.first.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff1a1a1a),
                        ),
                      ),
                      Text(
                        'Asked ${topFAQ.first.value} times',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}


Widget buildInquiryTrendCard(List<ChartData> trendData) {
  Set<String> allCategories = {};
  for (var data in trendData) {
    allCategories.addAll(data.categoryBreakdown.keys);
  }
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
                  'Inquiry Trend by Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Distribution of user inquiries over time',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            // Legend toggle button
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.grey[600]),
              onPressed: () {
                // Could show a legend dialog
              },
            ),
          ],
        ),

        // Category Legend
        if (allCategories.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children:
                allCategories.map((category) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: getColorForCategory(category),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ],

        const SizedBox(height: 16),
        Expanded(
          child:
              trendData.isEmpty
                  ? Center(
                    child: Text(
                      'No data available for this time period',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots
                                  .map((spot) {
                                    final categoryIndex = spot.barIndex;
                                    final categories = allCategories.toList();

                                    if (categoryIndex < categories.length) {
                                      final category =
                                          categories[categoryIndex];
                                      final count = spot.y.toInt();
                                      return LineTooltipItem(
                                        '$category: $count',
                                        TextStyle(
                                          color: getColorForCategory(category),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    }
                                    return null;
                                  })
                                  .where((item) => item != null)
                                  .cast<LineTooltipItem>()
                                  .toList();
                            },
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _getGridInterval(trendData),
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
                              interval: _getGridInterval(trendData),
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
                                trendData.length,
                              ),
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() < trendData.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _formatBottomTitle(
                                        trendData[value.toInt()].date,
                                      ),
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
                        lineBarsData: _generateLineChartBars(
                          trendData,
                          allCategories.toList(),
                        ),
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
