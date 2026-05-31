// import 'package:capstone_project/icon_and_color.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/escalation_data.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/inquiry_trends_dialog.dart';
import 'package:capstone_project/modules/admin/dashboard_and_reports/reports.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// Helper function to get bar colors with gradient effect
Color _getFAQBarColor(int index, int total) {
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

Color _getColorForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'admission':
      return const Color(0xff3b82f6); // Blue
    case 'scholarship':
      return const Color(0xff10b981); // Green
    case 'placement':
      return const Color(0xfff59e0b); // Amber
    case 'general':
      return const Color(0xff8b5cf6); // Purple
    default:
      return const Color(0xff6b7280); // Gray
  }
}

Widget buildCategoryDistributionCard(
  Map<String, int> categoryData,
  String timeFrame,
  BuildContext context,
) {
  final total = categoryData.values.fold(0, (sum, count) => sum + count);

  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final isTablet = screenWidth >= 600 && screenWidth < 1100;

      final padding = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
      final iconSize = isMobile ? 18.0 : 20.0;
      final titleFontSize = isMobile ? 16.0 : 18.0;
      final subtitleFontSize = isMobile ? 11.0 : 13.0;
      final borderRadius = isMobile ? 12.0 : 16.0;
      final pieRadius = isMobile ? 50.0 : 50.0;
      final centerSpaceRadius = isMobile ? 35.0 : 50.0;

      return Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xff8b5cf6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.pie_chart_rounded,
                    color: const Color(0xff8b5cf6),
                    size: iconSize,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category Distribution',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff1a1a1a),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Breakdown by inquiry type',
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // See More Button
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => CategoryDistributionDetailDialog(
                            categoryData: categoryData,
                            timeFrame: timeFrame,
                          ),
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward,
                    size: isMobile ? 14 : 16,
                    color: const Color(0xff8b5cf6),
                  ),
                  label: Text(
                    'See more',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: const Color(0xff8b5cf6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 20),
            Expanded(
              child:
                  categoryData.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.donut_small,
                              size: isMobile ? 40 : 48,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            Text(
                              'No category data available',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                      : isMobile
                      ? Column(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: centerSpaceRadius,
                                sections:
                                    categoryData.entries.map((entry) {
                                      return PieChartSectionData(
                                        color: _getColorForCategory(entry.key),
                                        value: entry.value.toDouble(),
                                        title: '',
                                        radius: pieRadius,
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...categoryData.entries.map((entry) {
                            final percentage = (entry.value / total * 100)
                                .toStringAsFixed(1);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getColorForCategory(entry.key),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${entry.value} ($percentage%)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      )
                      : Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: centerSpaceRadius,
                                sections:
                                    categoryData.entries.map((entry) {
                                      return PieChartSectionData(
                                        color: _getColorForCategory(entry.key),
                                        value: entry.value.toDouble(),
                                        title: '',
                                        radius: pieRadius,
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                          SizedBox(width: isTablet ? 12 : 20),
                          Expanded(
                            flex: 2,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  categoryData.entries.map((entry) {
                                    final percentage = (entry.value /
                                            total *
                                            100)
                                        .toStringAsFixed(1);
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: isTablet ? 4 : 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: isTablet ? 12 : 14,
                                            height: isTablet ? 12 : 14,
                                            decoration: BoxDecoration(
                                              color: _getColorForCategory(
                                                entry.key,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                          SizedBox(width: isTablet ? 6 : 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  entry.key,
                                                  style: TextStyle(
                                                    fontSize:
                                                        isTablet ? 11 : 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '${entry.value} ($percentage%)',
                                                  style: TextStyle(
                                                    fontSize:
                                                        isTablet ? 10 : 11,
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
    },
  );
}

Widget buildHighestFAQCard(Map<String, int> highestFAQ) {
  final sortedFAQ =
      highestFAQ.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final topFAQ = sortedFAQ.take(10).toList();
  final maxValue = topFAQ.isNotEmpty ? topFAQ.first.value.toDouble() : 0.0;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),

      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xfff59e0b).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.question_answer_rounded,
                color: Color(0xfff59e0b),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Questions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1a1a1a),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Most frequently asked inquiries',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child:
              topFAQ.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No FAQ data available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                  : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxValue * 1.15,
                      minY: 0,
                      groupsSpace: 12,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => const Color(0xff1a1a1a),
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          tooltipBorderRadius: BorderRadius.circular(8),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex < topFAQ.length) {
                              final entry = topFAQ[groupIndex];
                              return BarTooltipItem(
                                '${entry.key}\n',
                                const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${entry.value} times',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
                            reservedSize: 70,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < topFAQ.length) {
                                final entry = topFAQ[value.toInt()];
                                final question =
                                    entry.key.length > 20
                                        ? '${entry.key.substring(0, 17)}...'
                                        : entry.key;

                                return Transform.rotate(
                                  angle:
                                      -0.5, // slant angle (negative = tilt left)
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: SizedBox(
                                      width: 90,
                                      child: Text(
                                        question,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                            final Color barColor = _getFAQBarColor(
                              index,
                              topFAQ.length,
                            );

                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: data.value.toDouble(),
                                  width: 32,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      barColor,
                                      barColor.withOpacity(0.7),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 600),
                    swapAnimationCurve: Curves.easeInOutCubic,
                  ),
        ),
      ],
    ),
  );
}

Widget buildInquiryTrendCard(
  List<ChartData> trendData,
  String timeFrame,
  BuildContext context, {
  DateTime? startDate,
  DateTime? endDate,
}) {
  Set<String> allCategories = {};
  for (var data in trendData) {
    allCategories.addAll(data.categoryBreakdown.keys);
  }

  double maxY = 0;
  for (var data in trendData) {
    for (var count in data.categoryBreakdown.values) {
      if (count > maxY) maxY = count.toDouble();
    }
  }
  maxY = maxY * 1.2;

  Map<String, int> categoryTotals = {};
  for (var data in trendData) {
    for (var entry in data.categoryBreakdown.entries) {
      categoryTotals[entry.key] =
          (categoryTotals[entry.key] ?? 0) + entry.value;
    }
  }

  final sortedCategories =
      categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.grey[50]!],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
      border: Border.all(color: Colors.grey[200]!, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xff10b981), const Color(0xff059669)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff10b981).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inquiry Trends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff0f172a),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Category performance over $timeFrame',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xff10b981).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) =>
                              InquiryTrendsDetailDialog(
                                timeFrame: timeFrame,
                                startDate: startDate,
                                endDate: endDate,
                              ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xff10b981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Color(0xff10b981),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (allCategories.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children:
                sortedCategories.map((entry) {
                  final category = entry.key;
                  final count = entry.value;
                  final color = getColorForCategory(category);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            count.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ],

        const SizedBox(height: 24),

        Expanded(
          child:
              trendData.isEmpty
                  ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.insights_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No data available',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Inquiry trends will appear here',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : Container(
                    padding: const EdgeInsets.only(
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        lineBarsData: _generateLineChartBars(
                          trendData,
                          allCategories.toList(),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _getGridInterval(trendData),
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey[200]!,
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: _getYAxisInterval(maxY),
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: getBottomTitleInterval(
                                trendData.length,
                                timeFrame,
                                startDate,
                                endDate,
                              ),
                              getTitlesWidget: (value, meta) {
                                if (value < 0 || value >= trendData.length) {
                                  return const SizedBox.shrink();
                                }

                                //  IMPORTANT: Only show labels at interval positions
                                final interval = getBottomTitleInterval(
                                  trendData.length,
                                  timeFrame,
                                  startDate,
                                  endDate,
                                );

                                // Skip labels that aren't at interval positions
                                if (value % interval != 0 && value != 0) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    formatBottomTitle(
                                      trendData[value.toInt()].date,
                                      timeFrame,
                                      startDate,
                                      endDate,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            left: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            bottom: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBorderRadius: BorderRadius.circular(8),
                            tooltipPadding: const EdgeInsets.all(12),
                            tooltipBorder: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final category = allCategories.elementAt(
                                  spot.barIndex,
                                );
                                final color = getColorForCategory(category);
                                return LineTooltipItem(
                                  '$category\n${spot.y.toInt()}',
                                  TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                          getTouchedSpotIndicator: (barData, spotIndexes) {
                            return spotIndexes.map((index) {
                              return TouchedSpotIndicatorData(
                                FlLine(
                                  color: barData.color ?? Colors.transparent,
                                  strokeWidth: 2,
                                  dashArray: [5, 5],
                                ),
                                FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, bar, index) {
                                    return FlDotCirclePainter(
                                      radius: 6,
                                      color: bar.color ?? Colors.transparent,
                                      strokeWidth: 3,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
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
        curveSmoothness: 0.4,
        color: color,
        barWidth: 3.5,
        isStrokeCapRound: true,
        shadow: Shadow(
          color: color.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.05),
              color.withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 5,
              color: color,
              strokeWidth: 2.5,
              strokeColor: Colors.white,
            );
          },
        ),
      ),
    );
  }

  return lineBars;
}

Color getColorForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'admission':
      return const Color(0xff3b82f6);
    case 'scholarship':
      return const Color(0xff10b981);
    case 'placement':
      return const Color(0xfff59e0b);
    case 'general':
      return const Color(0xff8b5cf6);
    default:
      return const Color(0xff6b7280);
  }
}

double _getYAxisInterval(double maxValue) {
  if (maxValue <= 5) return 1;
  if (maxValue <= 10) return 2;
  if (maxValue <= 20) return 5;
  if (maxValue <= 50) return 10;
  if (maxValue <= 100) return 20;
  return (maxValue / 5).ceil().toDouble();
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

double getBottomTitleInterval(
  int dataLength,
  String timeFrame, [
  DateTime? startDate,
  DateTime? endDate,
]) {
  // Handle custom date ranges
  if (timeFrame == 'Custom' && startDate != null && endDate != null) {
    final daysDiff = endDate.difference(startDate).inDays;

    if (daysDiff == 0) {
      // Hourly: show every 3-4 hours
      return dataLength <= 24 ? 3.0 : 4.0;
    } else if (daysDiff <= 7) {
      // Daily: show all days if 7 or fewer
      return 1.0;
    } else if (daysDiff <= 31) {
      // Weekly: show all weeks
      return 1.0;
    } else {
      // Monthly: show every other month if more than 6 months
      return dataLength <= 6 ? 1.0 : 2.0;
    }
  }

  // Existing preset timeframe logic
  switch (timeFrame) {
    case 'All':
      return 1.0;
    case 'Today':
      return dataLength <= 12 ? 2.0 : 4.0;
    case 'This Week':
      return 1.0;
    case 'This Month':
      return dataLength <= 5 ? 1.0 : 1.0;
    case 'This Year':
      return dataLength <= 6 ? 1.0 : 2.0;
    default:
      if (dataLength <= 7) return 1.0;
      if (dataLength <= 14) return 2.0;
      return (dataLength / 6).ceil().toDouble();
  }
}

String formatBottomTitle(
  String date,
  String timeFrame, [
  DateTime? startDate,
  DateTime? endDate,
]) {
  // Handle custom date ranges
  if (timeFrame == 'Custom' && startDate != null && endDate != null) {
    final daysDiff = endDate.difference(startDate).inDays;

    if (daysDiff == 0) {
      // Hourly format: "12AM", "3PM", etc.
      if (date.contains(":")) {
        int hour = int.tryParse(date.split(":")[0]) ?? 0;
        if (hour == 0) return "12AM";
        if (hour < 12) return "${hour}AM";
        if (hour == 12) return "12PM";
        return "${hour - 12}PM";
      }
      return date;
    } else if (daysDiff <= 7) {
      // Daily format: already formatted as "Mon", "Tue", etc.
      return date;
    } else if (daysDiff <= 31) {
      // Weekly format: "W1", "W2", etc.

      return date;
    } else {
      // Monthly format: "Jan", "Feb", etc.
      return date;
    }
  }

  // Existing preset timeframe logic
  switch (timeFrame) {
    case 'All':
      return date;
    case 'Today':
      if (date.contains(":")) {
        int hour = int.tryParse(date.split(":")[0]) ?? 0;
        if (hour == 0) return "12AM";
        if (hour < 12) return "${hour}AM";
        if (hour == 12) return "12PM";
        return "${hour - 12}PM";
      }
      return date;
    case 'This Week':
      return date;
    case 'This Month':
      return date;
    case 'This Year':
      return date;
    default:
      return date.length <= 3 ? date : date.substring(0, 6);
  }
}

// String _getTimeFrameDescription(String timeFrame, [DateTime? startDate, DateTime? endDate]) {
//   if (timeFrame == 'Custom' && startDate != null && endDate != null) {
//     final daysDiff = endDate.difference(startDate).inDays;

//     if (daysDiff == 0) return 'by hour';
//     if (daysDiff <= 7) return 'by day';
//     if (daysDiff <= 31) return 'by week';
//     return 'by month';
//   }

//   switch (timeFrame) {
//     case 'Today':
//       return 'by hour';
//     case 'This Week':
//       return 'by day';
//     case 'This Month':
//       return 'by week';
//     case 'This Year':
//       return 'by month';
//     default:
//       return 'over time';
//   }
// }

Widget buildEscalatedMessagesList(
  List<EscalatedMessage> data,
  String timeFrame,
  BuildContext context,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final padding = isMobile ? 16.0 : 20.0;
      final iconSize = isMobile ? 18.0 : 20.0;
      final titleFontSize = isMobile ? 16.0 : 18.0;

      return Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xffef4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.priority_high_rounded,
                    color: const Color(0xffef4444),
                    size: iconSize,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Escalated Messages',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff1a1a1a),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Recent escalations requiring attention',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Expanded(
              child:
                  data.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No escalated messages',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.separated(
                        itemCount: data.length,
                        separatorBuilder:
                            (context, index) => Divider(
                              height: isMobile ? 16 : 20,
                              color: Colors.grey[200],
                            ),
                        itemBuilder: (context, index) {
                          final message = data[index];
                          final categoryColor = _getColorForCategory(
                            message.category,
                          );

                          return Container(
                            padding: EdgeInsets.all(isMobile ? 10 : 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    message.status == 'pending'
                                        ? const Color(
                                          0xffef4444,
                                        ).withOpacity(0.3)
                                        : Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: categoryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        message.category,
                                        style: TextStyle(
                                          fontSize: isMobile ? 10 : 11,
                                          fontWeight: FontWeight.w600,
                                          color: categoryColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            message.status == 'pending'
                                                ? const Color(
                                                  0xffef4444,
                                                ).withOpacity(0.1)
                                                : const Color(
                                                  0xff10b981,
                                                ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        message.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: isMobile ? 9 : 10,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              message.status == 'pending'
                                                  ? const Color(0xffef4444)
                                                  : const Color(0xff10b981),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message.userMessage,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    color: Colors.grey[800],
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDateTime(message.escalatedAt),
                                      style: TextStyle(
                                        fontSize: isMobile ? 10 : 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (message.resolvedBy != null) ...[
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.person,
                                        size: 12,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'By ${message.resolvedBy}',
                                          style: TextStyle(
                                            fontSize: isMobile ? 10 : 11,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
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
    },
  );
}

// Helper for status badge to keep code clean
Widget _buildStatusBadge(String status, bool isMobile) {
  final isPending = status.toLowerCase() == 'pending';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: (isPending ? Colors.red : Colors.green).withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      status.toUpperCase(),
      style: TextStyle(
        fontSize: isMobile ? 9 : 10,
        fontWeight: FontWeight.w700,
        color: isPending ? Colors.red : Colors.green,
      ),
    ),
  );
}

// Widget buildEscalatedMessagesList(
//   List<EscalatedMessage> data, // Accept dynamic list (can be List<EscalatedMessage> or List<MessageLogs>)
//   String timeFrame,
//   BuildContext context,
// ) {
//   // Convert data to List<EscalatedMessage> if needed
//   final List<EscalatedMessage> escalatedMessages = [];

//   // If data is already List<EscalatedMessage>, use it directly
//   if (data.isNotEmpty) {
//     escalatedMessages.addAll(data.cast<EscalatedMessage>());
//   }

//   return LayoutBuilder(
//     builder: (context, constraints) {
//       final screenWidth = MediaQuery.of(context).size.width;
//       final isMobile = screenWidth < 600;
//       final padding = isMobile ? 16.0 : 20.0;
//       final iconSize = isMobile ? 18.0 : 20.0;
//       final titleFontSize = isMobile ? 16.0 : 18.0;

//       return Container(
//         padding: EdgeInsets.all(padding),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.08),
//               blurRadius: 12,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding: EdgeInsets.all(isMobile ? 8 : 10),
//                   decoration: BoxDecoration(
//                     color: const Color(0xffef4444).withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Icon(
//                     Icons.priority_high_rounded,
//                     color: const Color(0xffef4444),
//                     size: iconSize,
//                   ),
//                 ),
//                 SizedBox(width: isMobile ? 8 : 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Escalated Messages',
//                         style: TextStyle(
//                           fontSize: titleFontSize,
//                           fontWeight: FontWeight.bold,
//                           color: const Color(0xff1a1a1a),
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         'Recent escalations requiring attention',
//                         style: TextStyle(
//                           fontSize: isMobile ? 11 : 13,
//                           color: Colors.grey[600],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: isMobile ? 12 : 16),
//             Expanded(
//               child: escalatedMessages.isEmpty
//                   ? Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.check_circle_outline,
//                             size: 48,
//                             color: Colors.grey[300],
//                           ),
//                           const SizedBox(height: 12),
//                           Text(
//                             'No escalated messages',
//                             style: TextStyle(
//                               fontSize: 14,
//                               color: Colors.grey[400],
//                             ),
//                           ),
//                         ],
//                       ),
//                     )
//                   : ListView.separated(
//                       itemCount:
//                         escalatedMessages.length, // Limit to top 5
//                       separatorBuilder: (context, index) => Divider(
//                         height: isMobile ? 16 : 20,
//                         color: Colors.grey[200],
//                       ),
//                       itemBuilder: (context, index) {
//                         final message = escalatedMessages[index];
//                         final categoryColor = _getColorForCategory(message.category);

//                         return Container(
//                           padding: EdgeInsets.all(isMobile ? 10 : 12),
//                           decoration: BoxDecoration(
//                             color: Colors.grey[50],
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(
//                               color: message.status == 'pending'
//                                   ? const Color(0xffef4444).withOpacity(0.3)
//                                   : Colors.grey[300]!,
//                               width: 1.5,
//                             ),
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 8,
//                                       vertical: 4,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: categoryColor.withOpacity(0.1),
//                                       borderRadius: BorderRadius.circular(6),
//                                     ),
//                                     child: Text(
//                                       message.category,
//                                       style: TextStyle(
//                                         fontSize: isMobile ? 10 : 11,
//                                         fontWeight: FontWeight.w600,
//                                         color: categoryColor,
//                                       ),
//                                     ),
//                                   ),
//                                   const Spacer(),
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 8,
//                                       vertical: 4,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: message.status == 'pending'
//                                           ? const Color(0xffef4444).withOpacity(0.1)
//                                           : const Color(0xff10b981).withOpacity(0.1),
//                                       borderRadius: BorderRadius.circular(6),
//                                     ),
//                                     child: Text(
//                                       message.status.toUpperCase(),
//                                       style: TextStyle(
//                                         fontSize: isMobile ? 9 : 10,
//                                         fontWeight: FontWeight.w700,
//                                         color: message.status == 'pending'
//                                             ? const Color(0xffef4444)
//                                             : const Color(0xff10b981),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 message.userMessage,
//                                 style: TextStyle(
//                                   fontSize: isMobile ? 12 : 13,
//                                   color: Colors.grey[800],
//                                   height: 1.4,
//                                 ),
//                                 maxLines: 2,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                               const SizedBox(height: 6),
//                               Row(
//                                 children: [
//                                   Icon(
//                                     Icons.access_time,
//                                     size: 12,
//                                     color: Colors.grey[500],
//                                   ),
//                                   const SizedBox(width: 4),
//                                   Text(
//                                     _formatDateTime(message.escalatedAt),
//                                     style: TextStyle(
//                                       fontSize: isMobile ? 10 : 11,
//                                       color: Colors.grey[600],
//                                     ),
//                                   ),
//                                   if (message.resolvedBy != null) ...[
//                                     const SizedBox(width: 12),
//                                     Icon(
//                                       Icons.person,
//                                       size: 12,
//                                       color: Colors.grey[500],
//                                     ),
//                                     const SizedBox(width: 4),
//                                     Flexible(
//                                       child: Text(
//                                         'By ${message.resolvedBy}',
//                                         style: TextStyle(
//                                           fontSize: isMobile ? 10 : 11,
//                                           color: Colors.grey[600],
//                                         ),
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                     ),
//                                   ],
//                                 ],
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
//             ),
//           ],
//         ),
//       );
//     },
//   );
// }

// ============================================================================
// ESCALATIONS OVER TIME (WITH CATEGORY BREAKDOWN)
// ============================================================================
Widget buildEscalationsOverTimeCard(
  List<ChartData> escalationsData,
  String timeFrame,
  BuildContext context, {
  DateTime? startDate,
  DateTime? endDate,
}) {
  Set<String> allCategories = {};
  for (var data in escalationsData) {
    allCategories.addAll(data.categoryBreakdown.keys);
  }

  double maxY = 0;
  for (var data in escalationsData) {
    for (var count in data.categoryBreakdown.values) {
      if (count > maxY) maxY = count.toDouble();
    }
  }
  maxY = maxY * 1.2;

  // Calculate bottom title interval
  final bottomInterval = getBottomTitleInterval(
    escalationsData.length,
    timeFrame,
    startDate,
    endDate,
  );

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.grey[50]!],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(color: Colors.grey[200]!, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xffef4444), const Color(0xffdc2626)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffef4444).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Escalations Over Time',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff0f172a),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Escalation trends by category',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (allCategories.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children:
                allCategories.map((category) {
                  final color = _getColorForCategory(category);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ],
        const SizedBox(height: 24),
        Expanded(
          child:
              escalationsData.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No escalations in this period',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                  : Container(
                    padding: const EdgeInsets.only(
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        lineBarsData: _generateEscalationLineChartBars(
                          escalationsData,
                          allCategories.toList(),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine:
                              (value) => FlLine(
                                color: Colors.grey[200]!,
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget:
                                  (value, meta) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: getBottomTitleInterval(
                                escalationsData.length,
                                timeFrame,
                                startDate,
                                endDate,
                              ),
                              getTitlesWidget: (value, meta) {
                                if (value < 0 ||
                                    value >= escalationsData.length) {
                                  return const SizedBox.shrink();
                                }

                                //  IMPORTANT: Only show labels at interval positions
                                final interval = getBottomTitleInterval(
                                  escalationsData.length,
                                  timeFrame,
                                  startDate,
                                  endDate,
                                );

                                // Skip labels that aren't at interval positions
                                if (value % interval != 0 && value != 0) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    formatBottomTitle(
                                      escalationsData[value.toInt()].date,
                                      timeFrame,
                                      startDate,
                                      endDate,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            left: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            bottom: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBorderRadius: BorderRadius.circular(8),
                            tooltipPadding: const EdgeInsets.all(12),
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final category = allCategories.elementAt(
                                  spot.barIndex,
                                );
                                final color = _getColorForCategory(category);
                                return LineTooltipItem(
                                  '$category\n${spot.y.toInt()}',
                                  TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
        ),
      ],
    ),
  );
}

// ============================================================================
// STAFF PERFORMANCE (RESOLUTION RATE)
// ============================================================================
Widget buildStaffPerformanceCard(
  Map<String, double> staffPerformance,
  String timeFrame,
  BuildContext context,
) {
  final sortedStaff =
      staffPerformance.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff8b5cf6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.people_rounded,
                color: Color(0xff8b5cf6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff Performance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1a1a1a),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Average resolution rate by staff ($timeFrame)',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child:
              sortedStaff.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No staff data available for $timeFrame',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.separated(
                    itemCount: sortedStaff.length,
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = sortedStaff[index];
                      final maxRate = sortedStaff.first.value;
                      final percentage = (entry.value / maxRate * 100).clamp(
                        0,
                        100,
                      );

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(
                                    0xff8b5cf6,
                                  ).withOpacity(0.1),
                                  child: Text(
                                    entry.key.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xff8b5cf6),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff1a1a1a),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${entry.value.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 8,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xff8b5cf6),
                                ),
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

// ============================================================================
// BOT VS HUMAN ANSWERS
// ============================================================================
Widget buildBotVsHumanCard(
  Map<String, int> botVsHumanAnswers,
  String timeFrame,
) {
  final botCount = botVsHumanAnswers['bot'] ?? 0;
  final humanCount = botVsHumanAnswers['human'] ?? 0;
  final total = botCount + humanCount;

  final botPercentage = total > 0 ? (botCount / total * 100) : 0.0;
  final humanPercentage = total > 0 ? (humanCount / total * 100) : 0.0;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff3b82f6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Color(0xff3b82f6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bot vs Human Answers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1a1a1a),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Answer distribution ($timeFrame)',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child:
              total == 0
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No answer data available for $timeFrame',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                  : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 50,
                            sections: [
                              PieChartSectionData(
                                color: const Color(0xff3b82f6),
                                value: botCount.toDouble(),
                                title: '${botPercentage.toStringAsFixed(1)}%',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xff10b981),
                                value: humanCount.toDouble(),
                                title: '${humanPercentage.toStringAsFixed(1)}%',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem(
                              'Bot Answers',
                              botCount,
                              botPercentage,
                              const Color(0xff3b82f6),
                            ),
                            const SizedBox(height: 16),
                            _buildLegendItem(
                              'Human Answers',
                              humanCount,
                              humanPercentage,
                              const Color(0xff10b981),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ],
    ),
  );
}

// ============================================================================
// HELPER METHODS
// ============================================================================

List<LineChartBarData> _generateEscalationLineChartBars(
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
    final color = _getColorForCategory(category);

    List<FlSpot> spots = [];
    for (int i = 0; i < trendData.length; i++) {
      final count = trendData[i].categoryBreakdown[category] ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    lineBars.add(
      LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.4,
        color: color,
        barWidth: 3.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 5,
              color: color,
              strokeWidth: 2.5,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.05),
              color.withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }

  return lineBars;
}

Widget _buildLegendItem(
  String label,
  int count,
  double percentage,
  Color color,
) {
  return Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '$count (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    ],
  );
}

String _formatDateTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
