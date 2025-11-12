import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/colors.dart';

import 'package:capstone_project/pages/data/reports.dart';
// import 'package:capstone_project/pages/data/reports.dart';

Widget buildStatCard(String title, String value, Color color, IconData icon) {
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              // Only use Expanded here, inside the card
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20, // Adjusted font size
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

Widget buildResponseDistributionCard(Map<String, double> responseDistribution) {
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
          'Response Distribution',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Answered vs Unanswered vs Escalated',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              responseDistribution.isEmpty
                  ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : PieChart(
                    PieChartData(
                      sections:
                          responseDistribution.entries.map((entry) {
                            return PieChartSectionData(
                              color: _getResponseColor(entry.key),
                              value: entry.value,
                              title:
                                  '${entry.key}\n${entry.value.toStringAsFixed(1)}%',
                              radius: 80,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children:
              responseDistribution.keys.map((key) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getResponseColor(key),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      key,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                );
              }).toList(),
        ),
      ],
    ),
  );
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

Widget buildTop5UnansweredCard(List<String> unansweredInquiries) {
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
          children: [
            Icon(Icons.help_outline, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            const Text(
              'Top 5 Unanswered Inquiries',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Text(
          'Recent questions that need attention',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              unansweredInquiries.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green[400],
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All inquiries answered!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: unansweredInquiries.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.orange[200],
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                unansweredInquiries[index],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    ),
  );
}

Widget buildTop5EscalatedCard(List<String> escalatedInquiries) {
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
          children: [
            Icon(Icons.priority_high, color: Colors.red[700], size: 20),
            const SizedBox(width: 8),
            const Text(
              'Top 5 Escalated Inquiries',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Text(
          'High-priority issues requiring attention',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              escalatedInquiries.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.trending_down,
                          color: Colors.green[400],
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No escalated inquiries',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: escalatedInquiries.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red[200],
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                escalatedInquiries[index],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    ),
  );
}

Widget buildGrowthRateCard(double growthRate) {
  final isPositive = growthRate >= 0;
  final color = isPositive ? Colors.green : Colors.red;
  final icon = isPositive ? Icons.trending_up : Icons.trending_down;

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
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isPositive ? '+' : ''}${growthRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const Text(
                    'Growth Rate',
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
          isPositive
              ? 'Inquiries are increasing month-over-month'
              : 'Inquiries have decreased month-over-month',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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

Widget buildSessionTypesCard(Map<String, int> sessionTypes) {
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
          'Session Types',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Multi-turn vs Single-turn conversations',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              sessionTypes.isEmpty
                  ? Center(
                    child: Text(
                      'No session data available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : PieChart(
                    PieChartData(
                      sections:
                          sessionTypes.entries.map((entry) {
                            return PieChartSectionData(
                              color:
                                  entry.key == 'Multi-turn'
                                      ? Colors.blue[600]!
                                      : Colors.orange[600]!,
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
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
        ),
      ],
    ),
  );
}

Widget buildBotAccuracyCard(double accuracy) {
  final color =
      accuracy >= 80
          ? Colors.green
          : accuracy >= 60
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
              child: Icon(Icons.smart_toy, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${accuracy.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const Text(
                    'Bot Accuracy Rate',
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
        LinearProgressIndicator(
          value: accuracy / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 8),
        Text(
          _getAccuracyDescription(accuracy),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    ),
  );
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

Widget buildTop10ActiveUsersCard(List<MapEntry<String, int>> top10Users) {
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
          'Top 10 Most Active Users',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Users with most chatbot sessions',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: top10Users.isEmpty
              ? Center(
                  child: Text(
                    'No user activity data available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: top10Users.isNotEmpty 
                          ? top10Users.first.value.toDouble() + 5
                          : 10,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                     
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final username = _getMaskedUsername(top10Users[group.x.toInt()].key);
                            return BarTooltipItem(
                              '$username\n${rod.toY.round()} sessions',
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
                              if (value.toInt() >= 0 && value.toInt() < top10Users.length) {
                                final username = _getMaskedUsername(top10Users[value.toInt()].key);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    username,
                                    style: const TextStyle(fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                      barGroups: top10Users.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.value.toDouble(),
                              color: _getUserActivityColor(entry.key),
                              width: 16,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
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
                          final course = _shortenProgramName(topCourses[group.x.toInt()].key);
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
                              final courseName = _shortenProgramName(topCourses[value.toInt()].key);
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

// For User Demographics Report

Widget buildScholarshipStatusCard(Map<String, int> scholarshipStatus) {
  final entries = scholarshipStatus.entries.toList();
  
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
          'Scholarship Status Distribution',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Users with vs without scholarships',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    'No scholarship data available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: entries.asMap().entries.map((entry) {
                      final total = scholarshipStatus.values.fold(0, (a, b) => a + b);
                      final percentage = ((entry.value.value / total) * 100);
                      
                      return PieChartSectionData(
                        color: entry.value.key == 'Has Scholarship' ? Colors.green : Colors.orange,
                        value: entry.value.value.toDouble(),
                        title: '${percentage.toStringAsFixed(1)}%',
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 14,
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
                    color: entry.key == 'Has Scholarship' ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${entry.key}: ${entry.value}',
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

Widget buildScholarshipTypesCard(Map<String, int> scholarshipTypes) {
  final filteredEntries = scholarshipTypes.entries
      .where((entry) => entry.value > 0)
      .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  
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
          'Scholarship Types',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Distribution by scholarship categories',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filteredEntries.isEmpty
              ? Center(
                  child: Text(
                    'No scholarship type data available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: filteredEntries.isNotEmpty 
                        ? filteredEntries.first.value.toDouble() + 5
                        : 10,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
           
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final type = filteredEntries[group.x.toInt()].key;
                          return BarTooltipItem(
                            '$type\n${rod.toY.round()} users',
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
                            if (value.toInt() >= 0 && value.toInt() < filteredEntries.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  filteredEntries[value.toInt()].key,
                                  style: const TextStyle(fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                    barGroups: filteredEntries.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.value.toDouble(),
                            color: _getScholarshipTypeColor(entry.key),
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

Widget buildEnrollmentStatusCard(Map<String, int> enrollmentStatus) {
  final entries = enrollmentStatus.entries.toList();
  
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
          'Enrollment Status',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Currently enrolled vs not enrolled students',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    'No enrollment data available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: entries.asMap().entries.map((entry) {
                      final total = enrollmentStatus.values.fold(0, (a, b) => a + b);
                      final percentage = ((entry.value.value / total) * 100);
                      
                      return PieChartSectionData(
                        color: entry.value.key == 'Enrolled' ? Colors.blue : Colors.red,
                        value: entry.value.value.toDouble(),
                        title: '${percentage.toStringAsFixed(1)}%',
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 14,
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
                    color: entry.key == 'Enrolled' ? Colors.blue : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${entry.key}: ${entry.value}',
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


String _getMaskedUsername(String userId) {
  // Mask user ID for privacy - show first 3 and last 2 characters
  if (userId.length <= 5) return 'User***';
  return 'User${userId.substring(0, 3)}***${userId.substring(userId.length - 2)}';
}

Color _getUserActivityColor(int index) {
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

Color _getScholarshipTypeColor(int index) {
  final colors = [
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];
  return colors[index % colors.length];
}

Widget buildUserAffiliationsCard(Map<String, int> userAffiliations) {
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
          'User Affiliations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Distribution by affiliation type',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              userAffiliations.isEmpty
                  ? Center(
                    child: Text(
                      'No affiliation data available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : PieChart(
                    PieChartData(
                      sections:
                          userAffiliations.entries.map((entry) {
                            return PieChartSectionData(
                              color: _getAffiliationColor(entry.key),
                              value: entry.value.toDouble(),
                              title:
                                  '${_shortenAffiliation(entry.key)}\n${entry.value}',
                              radius: 70,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                    ),
                  ),
        ),
        // Legend
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children:
              userAffiliations.keys.map((key) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getAffiliationColor(key),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      key,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                );
              }).toList(),
        ),
      ],
    ),
  );
}

Widget buildUserStatsOverviewCard(UserDemographicsReportsData data) {
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
          'User Statistics Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Key user metrics at a glance',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Column(
            children: [
              _buildMetricRow(
                'Total Users',
                data.totalUsers.toString(),
                Icons.people,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildMetricRow(
                'Active Users',
                data.activeUsers.toString(),
                Icons.person,
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildMetricRow(
                'New Registrations',
                data.newlyRegisteredUsers.toString(),
                Icons.person_add,
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildMetricRow(
                'Affiliated Users',
                data.affiliatedUsers.toString(),
                Icons.school,
                Colors.purple,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildChatbotMetricsCard(ChatbotUsageReportsData data) {
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
          'Chatbot Performance Metrics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Key chatbot usage statistics',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Column(
            children: [
              _buildMetricRow(
                'Total Sessions',
                data.totalSessions.toString(),
                Icons.chat,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildMetricRow(
                'Avg Response Time',
                '${data.averageResponseTime.toStringAsFixed(1)}s',
                Icons.speed,
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildMetricRow(
                'Bot Accuracy',
                '${data.botAccuracyRate.toStringAsFixed(1)}%',
                Icons.smart_toy,
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildMetricRow(
                'Avg Messages/User',
                data.averageMessagesPerUser.toStringAsFixed(1),
                Icons.message,
                Colors.purple,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildUsersByYearCard(Map<String, int> yearData) {
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
          'Active Users by Year Level',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Students who sent messages',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              yearData.isEmpty
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
                          yearData.values.isNotEmpty
                              ? yearData.values
                                      .reduce((a, b) => a > b ? a : b)
                                      .toDouble() *
                                  1.2
                              : 10,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            String year = yearData.keys.elementAt(
                              group.x.toInt(),
                            );
                            return BarTooltipItem(
                              '$year\n${rod.toY.round()} students',
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
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < yearData.length) {
                                String year = yearData.keys.elementAt(
                                  value.toInt(),
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    year,
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
                      borderData: FlBorderData(show: false),
                      barGroups:
                          yearData.entries.map((entry) {
                            int index = yearData.keys.toList().indexOf(
                              entry.key,
                            );
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.toDouble(),
                                  color: Colors.indigo,
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

// NEW: Widget for Users by Program
Widget buildUsersByProgramCard(Map<String, int> programData) {
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
          'Active Users by Program',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Students who sent messages',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        Expanded(
          child:
              programData.isEmpty
                  ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : PieChart(
                    PieChartData(
                      sections:
                          programData.entries.map((entry) {
                            return PieChartSectionData(
                              color: DashboardWidgets.getProgramColor(
                                entry.key,
                              ),
                              value: entry.value.toDouble(),
                              title:
                                  '${DashboardWidgets.shortenProgram(entry.key)}\n${entry.value}',
                              radius: 70,
                              titleStyle: const TextStyle(
                                fontSize: 11,
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

// NEW: Widget for Peak Usage Hours
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

// NEW: Widget for Usage Metrics
Widget buildUsageMetricsCard(
  // double avgMessages,
  int totalMessages,
  int totalUsers,
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
        const Text(
          '',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'User engagement statistics',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // buildMetricRow(
              //   'Average Messages per User',
              //   avgMessages.toStringAsFixed(1),
              //   Icons.trending_up,
              //   Colors.blue,
              // ),
              buildMetricRow(
                'Total Messages',
                totalMessages.toString(),
                Icons.message,
                Colors.green,
              ),
              buildMetricRow(
                'Active Users',
                totalUsers.toString(),
                Icons.people,
                Colors.orange,
              ),
              buildMetricRow(
                'Engagement Rate',
                totalUsers > 0
                    ? '${((totalMessages / totalUsers) * 10).toStringAsFixed(0)}%'
                    : '0%',
                Icons.show_chart,
                Colors.purple,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildMetricRow(String label, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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

// Helper functions
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

class DashboardWidgets {
  // Simplified color scheme
  static const _categoryColors = {
    'admission': Color(0xFF2196F3),
    'scholarship': Color(0xFF4CAF50),
    'placement': Color(0xFFFF9800),
    'general': Color(0xFF9C27B0),
  };

  static const _programColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFF44336),
    Color(0xFF009688),
    Color(0xFF3F51B5),
    Color(0xFFE91E63),
  ];

  static Color getCategoryColor(String category) {
    return _categoryColors[category.toLowerCase()] ?? Colors.grey;
  }

  static Color getProgramColor(String program) {
    return _programColors[program.hashCode % _programColors.length];
  }

  static String shortenProgram(String program) {
    return program
        .split(' ')
        .where(
          (word) =>
              word.isNotEmpty && !{'of', 'in'}.contains(word.toLowerCase()),
        )
        .map((word) => word[0].toUpperCase())
        .join();
  }

  // Simplified chart interval calculations
  static double getChartInterval(List<int> values) {
    if (values.isEmpty) return 1.0;
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    if (maxValue <= 5) return 1.0;
    if (maxValue <= 10) return 2.0;
    if (maxValue <= 25) return 5.0;
    if (maxValue <= 50) return 10.0;
    return (maxValue / 5).ceil().toDouble();
  }

  static Color getHeatmapColor(int value, int maxValue) {
    if (maxValue == 0) return Colors.grey[300]!;

    final intensity = value / maxValue;
    if (intensity > 0.8) return Colors.red[700]!;
    if (intensity > 0.6) return Colors.red[500]!;
    if (intensity > 0.4) return Colors.orange[500]!;
    if (intensity > 0.2) return Colors.yellow[600]!;
    if (intensity > 0) return Colors.blue[300]!;
    return Colors.grey[300]!;
  }
}

Widget buildSystemLogsCard(List<SystemLog> logs) {
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
          'Recent System Logs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child:
              logs.isEmpty
                  ? Center(
                    child: Text(
                      'No recent logs available',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  )
                  : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              getLogIcon(log.action),
                              size: 16,
                              color: getLogColor(log.action),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.action,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'By: ${log.user}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat(
                                'MMMM d, yyyy, hh:mm a',
                              ).format(log.time),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    ),
  );
}



Widget buildMessageLogsCard(List<MessageLogs> msgLogs) {
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
          'Recent Message Logs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: msgLogs.isEmpty
              ? Center(
                  child: Text(
                    'No recent logs available',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : ListView.builder(
                  itemCount: msgLogs.length,
                  itemBuilder: (context, index) {
                    final log = msgLogs[index];

                    // Parse timestamp safely (assuming ISO8601 or millis)
                    DateTime parsedTime;
                    try {
                      parsedTime = DateTime.parse(log.time.toIso8601String());
                    } catch (_) {
                      parsedTime = DateTime.now();
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "User: ${log.user}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Message: ${log.message}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (log.reply.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "Reply: ${log.reply}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy\nhh:mm a').format(parsedTime),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

// Widget buildFeedbackBarChart(ReportsData data) {
//   final feedbackData = {
//     "Liked": data.totalLikes,
//     "Neutral": data.totalNeutral,
//     "Disliked": data.totalDislikes,
//   };

//   final labels = feedbackData.keys.toList();
//   final values = feedbackData.values.toList();

//   return AspectRatio(
//     aspectRatio: 1.3,
//     child: BarChart(
//       BarChartData(
//         alignment: BarChartAlignment.spaceAround,
//         maxY: (values.isEmpty
//                 ? 0
//                 : values.reduce((a, b) => a > b ? a : b) + 5)
//             .toDouble(),
//         barTouchData: BarTouchData(enabled: true),
//         titlesData: FlTitlesData(
//           leftTitles: AxisTitles(
//             sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 5),
//           ),
//           // bottomTitles: AxisTitles(
//           //   sideTitles: SideTitles(
//           //     showTitles: true,
//           //     getTitlesWidget: (double value, TitleMeta meta) {
//           //       final index = value.toInt();
//           //       if (index < 0 || index >= labels.length) return const SizedBox();
//           //       return SideTitleWidget(
//           //         side: meta.axisSide,
//           //         child: Text(
//           //           labels[index],
//           //           style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
//           //         ),
//           //       );
//           //     },
//           //   ),
//           // ),
//         ),
//         gridData: FlGridData(show: true),
//         borderData: FlBorderData(show: false),
//         barGroups: List.generate(
//           labels.length,
//           (index) => BarChartGroupData(
//             x: index,
//             barRods: [
//               BarChartRodData(
//                 toY: values[index].toDouble(),
//                 gradient: LinearGradient(colors: getbar(labels[index])),
//                 width: 22,
//                 borderRadius: BorderRadius.circular(6),
//               ),
//             ],
//           ),
//         ),
//       ),
//     ),
//   );
// }

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

Widget _buildMetricRow(String label, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Color _getResponseColor(String responseType) {
  switch (responseType.toLowerCase()) {
    case 'answered':
      return Colors.green[600]!;
    case 'unanswered':
      return Colors.orange[600]!;
    case 'escalated':
      return Colors.red[600]!;
    default:
      return Colors.grey[600]!;
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

Color _getAffiliationColor(String affiliation) {
  switch (affiliation.toLowerCase()) {
    case 'user':
      return Colors.blue[600]!;
    case 'faculty':
      return Colors.green[600]!;
    case 'staff':
      return Colors.orange[600]!;
    case 'alumni':
      return Colors.purple[600]!;
    default:
      return Colors.grey[600]!;
  }
}

String _shortenProgramName(String program) {
  if (program.length <= 30) return program;
  return '${program.substring(0, 27)}...';
}

String _shortenAffiliation(String affiliation) {
  final words = affiliation.split(' ');
  if (words.length > 1) {
    return words.map((word) => word[0].toUpperCase()).join();
  }
  return affiliation.length > 8
      ? '${affiliation.substring(0, 8)}...'
      : affiliation;
}

String _getAccuracyDescription(double accuracy) {
  if (accuracy >= 90) return 'Excellent accuracy rate';
  if (accuracy >= 80) return 'Good accuracy rate';
  if (accuracy >= 70) return 'Fair accuracy rate';
  if (accuracy >= 60) return 'Needs improvement';
  return 'Poor accuracy - requires attention';
}

String _getResponseTimeDescription(double responseTime) {
  if (responseTime <= 1) return 'Excellent response time';
  if (responseTime <= 2) return 'Good response time';
  if (responseTime <= 3) return 'Fair response time';
  return 'Response time needs improvement';
}

// ==================== UTILITY FUNCTIONS FOR EXISTING CHARTS ====================

Color getColorForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'admission':
      return Colors.blue[600]!;
    case 'scholarship':
      return Colors.green[600]!;
    case 'placement':
      return Colors.orange[600]!;
    case 'general':
      return Colors.purple[600]!;
    case 'academic':
      return Colors.teal[600]!;
    case 'financial':
      return Colors.amber[600]!;
    default:
      return Colors.grey[600]!;
  }
}

IconData getLogIcon(String action) {
  switch (action.toLowerCase()) {
    case 'login':
      return Icons.login;
    case 'logout':
      return Icons.logout;
    case 'create':
      return Icons.add;
    case 'update':
      return Icons.edit;
    case 'delete':
      return Icons.delete;
    case 'view':
      return Icons.visibility;
    default:
      return Icons.info;
  }
}

Color getLogColor(String action) {
  switch (action.toLowerCase()) {
    case 'login':
      return Colors.green;
    case 'logout':
      return Colors.orange;
    case 'create':
      return Colors.blue;
    case 'update':
      return Colors.amber;
    case 'delete':
      return Colors.red;
    case 'view':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

List<Color> getbar(String type) {
  switch (type.toLowerCase()) {
    case 'liked':
      return [Colors.green[400]!, Colors.green[600]!];
    case 'neutral':
      return [Colors.grey[400]!, Colors.grey[600]!];
    case 'disliked':
      return [Colors.red[400]!, Colors.red[600]!];
    default:
      return [Colors.blue[400]!, Colors.blue[600]!];
  }
}